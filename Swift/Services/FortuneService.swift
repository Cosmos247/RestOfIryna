//
//  FortuneService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.05.2026.
//
//  Phase 6.4 — pure orchestrator for the tarot draw. Validates cooldown
//  + silver, debits the draw price, picks a card uniformly at random from
//  `FortuneCatalog.all`, applies one-shot components immediately, stamps
//  the User's `activeFortuneCardId` + `activeFortuneExpiresAt` so the
//  duration-based components are visible to later stat computations.
//
//  Outcome enum carries everything the UI needs to render the reveal
//  (card + applied one-shot deltas + Wheel-style random pick result).
//

import Fluent
import Foundation

public enum FortuneService {

    public enum DrawResult: Sendable {
        case success(card: FortuneCard, oneShotApplied: OneShotApplied)
        case onCooldown(secondsLeft: Int)
        case notEnoughSilver(have: Int, need: Int)
    }

    /// Snapshot of what the one-shot side of a draw actually did, so the
    /// reveal text can say "+30s" / "Healed to full" / "Lost 25s" exactly.
    /// Duration-based fields (stat bonuses, multipliers) are NOT here —
    /// the UI reads those from `FortuneCard.effect` directly.
    public struct OneShotApplied: Sendable {
        public var silverDelta: Int     // net change after Wheel roll
        public var xpGained: Int
        public var hpRestored: Bool
        public var vigorRestored: Bool

        public init(silverDelta: Int = 0, xpGained: Int = 0, hpRestored: Bool = false, vigorRestored: Bool = false) {
            self.silverDelta = silverDelta
            self.xpGained = xpGained
            self.hpRestored = hpRestored
            self.vigorRestored = vigorRestored
        }
    }

    /// Draw a card. Validates cooldown (still under the previous card's
    /// expiry) and silver (must afford `FortuneCatalog.drawPrice`). On
    /// success: debits the draw fee, picks a card uniformly, applies
    /// one-shot effects, stamps `activeFortuneCardId` + `activeFortuneExpiresAt`.
    public static func draw(for user: User, on db: any Database) async throws -> DrawResult {
        // Cooldown — gated by `lastFortuneDrawAt` + `cooldownSeconds`
        // (24h). Independent of the 6h buff window — a player whose
        // buff has worn off still has to wait out the rest of the day.
        if let drawn = user.lastFortuneDrawAt {
            let now = Date()
            let elapsed = now.timeIntervalSince(drawn)
            if elapsed < FortuneCatalog.cooldownSeconds {
                let left = FortuneCatalog.cooldownSeconds - elapsed
                return .onCooldown(secondsLeft: max(1, Int(left.rounded())))
            }
        }

        // Silver gate.
        if user.silver < FortuneCatalog.drawPrice {
            return .notEnoughSilver(have: user.silver, need: FortuneCatalog.drawPrice)
        }

        // Debit + pick.
        user.silver -= FortuneCatalog.drawPrice
        guard let card = FortuneCatalog.all.randomElement() else {
            // Defensive — catalog is non-empty by construction.
            return .notEnoughSilver(have: user.silver, need: FortuneCatalog.drawPrice)
        }
        let effect = card.effect

        // Apply one-shot effects + collect applied deltas for the reveal.
        var applied = OneShotApplied()

        if effect.oneShotSilver != 0 {
            // Negative loss is clamped to current silver (never goes below 0).
            if effect.oneShotSilver < 0 {
                let loss = min(user.silver, -effect.oneShotSilver)
                user.silver -= loss
                applied.silverDelta -= loss
            } else {
                user.silver += effect.oneShotSilver
                applied.silverDelta += effect.oneShotSilver
            }
        }

        // Wheel-style: 50/50 between positive gain and negative loss.
        if effect.randomSilverPositive > 0 || effect.randomSilverNegative > 0 {
            if Bool.random() {
                user.silver += effect.randomSilverPositive
                applied.silverDelta += effect.randomSilverPositive
            } else {
                let loss = min(user.silver, effect.randomSilverNegative)
                user.silver -= loss
                applied.silverDelta -= loss
            }
        }

        if effect.oneShotXpGain > 0 {
            _ = user.grantXP(effect.oneShotXpGain)
            applied.xpGained = effect.oneShotXpGain
        }

        if effect.oneShotHpRestore {
            user.hp = user.maxHp
            applied.hpRestored = true
        }

        if effect.oneShotVigorRestore {
            user.vigor = user.maxVigor
            applied.vigorRestored = true
        }

        // Stamp active card + buff expiry (6h) + draw timestamp (drives
        // the 24h cooldown). For pure one-shots `activeFortuneEffect`
        // will return nil even before expiry (hasDurationEffect == false),
        // but we still set both fields so the entry screen renders the
        // "card of the day" reminder + accurate cooldown countdown.
        let now = Date()
        user.activeFortuneCardId = card.id
        user.activeFortuneExpiresAt = now.addingTimeInterval(FortuneCatalog.buffDurationSeconds)
        user.lastFortuneDrawAt = now

        try await user.saveAndCache(in: db)
        return .success(card: card, oneShotApplied: applied)
    }
}
