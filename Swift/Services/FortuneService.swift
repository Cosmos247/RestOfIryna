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
//  2026-10-10 — two more things for sale, in one order only (`FortuneStage`):
//  `dispel` ends the free card's running effect, and only after it may
//  `drawSecond` deal one more card, which is final. Both deals — the free
//  card and the second — run through `deal`, so a second card is picked and
//  paid out exactly like the free one.
//

import Fluent
import Foundation

public enum FortuneService {

    public enum DrawResult: Sendable {
        case success(card: FortuneCard, oneShotApplied: OneShotApplied)
        case onCooldown(secondsLeft: Int)
        case notEnoughSilver(have: Int, need: Int)
    }

    public enum DispelResult: Sendable {
        /// `paid` is the receipt — what was charged, for the banner.
        case dispelled(card: FortuneCard, paid: Int)
        /// Nothing the question was about is still running — a one-shot, a card
        /// that ran out, the second card, or an answer to an older draw.
        case nothingToDispel
        case notEnoughSilver(have: Int, need: Int)
    }

    public enum SecondDrawResult: Sendable {
        case success(card: FortuneCard, oneShotApplied: OneShotApplied)
        /// No dispel opened it, the second card is already drawn, or the free
        /// card is ready again — the screen redraws to whatever is on offer.
        case notOffered
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

    /// Draw the free card. Validates the wait for the next card
    /// (`User.fortuneAvailableAt`) and silver (must afford
    /// `FortuneCatalog.drawPrice`). On success: debits the draw fee, picks a
    /// card uniformly, applies one-shot effects, stamps `activeFortuneCardId` +
    /// `activeFortuneExpiresAt`, and starts the stage over at `free`.
    public static func draw(for user: User, on db: any Database) async throws -> DrawResult {
        // The wait — the later of the previous card's window and the next
        // 12:00. Asked of the same function the screen and the watchman read:
        // this used to repeat the 24 h arithmetic beside `User`'s copy of it.
        if let left = user.fortuneCooldownRemaining() {
            return .onCooldown(secondsLeft: max(1, left))
        }

        // Silver gate.
        if user.silver < FortuneCatalog.drawPrice {
            return .notEnoughSilver(have: user.silver, need: FortuneCatalog.drawPrice)
        }

        guard let (card, applied) = deal(to: user, price: FortuneCatalog.drawPrice, stage: .free) else {
            // Defensive — catalog is non-empty by construction.
            return .notEnoughSilver(have: user.silver, need: FortuneCatalog.drawPrice)
        }
        try await user.saveAndCache(in: db)
        return .success(card: card, oneShotApplied: applied)
    }

    /// «🕯 Відчарувати» — end the free card's running effect for
    /// `FortuneCatalog.dispelPrice`. `drawnAt` is the draw the question was
    /// asked about (`fortuneDrawToken`): an answer left in chat from an older
    /// card dispels nothing.
    ///
    /// The card id goes and the stamped window STAYS, so the free card comes
    /// exactly when it would have (`User.fortuneAvailableAt`). The stage moves
    /// to `dispelled`, which is what opens the one second card.
    public static func dispel(for user: User, drawnAt token: Int, on db: any Database) async throws -> DispelResult {
        guard let card = user.dispellableFortuneCard(), fortuneDrawToken(of: user) == token else {
            return .nothingToDispel
        }
        let price = FortuneCatalog.dispelPrice
        guard user.silver >= price else {
            return .notEnoughSilver(have: user.silver, need: price)
        }
        user.silver -= price
        user.activeFortuneCardId = nil
        user.fortuneStage = .dispelled
        try await user.saveAndCache(in: db)
        return .dispelled(card: card, paid: price)
    }

    /// «🔮 Друга карта» — the one card a dispel opens, for
    /// `FortuneCatalog.secondDrawPrice`, dealt exactly like the free one. It is
    /// final: the stage moves to `second`, where nothing more is for sale until
    /// the next free card.
    public static func drawSecond(for user: User, on db: any Database) async throws -> SecondDrawResult {
        guard user.maySecondFortune() else { return .notOffered }
        let price = FortuneCatalog.secondDrawPrice
        guard user.silver >= price else {
            return .notEnoughSilver(have: user.silver, need: price)
        }
        guard let (card, applied) = deal(to: user, price: price, stage: .second) else { return .notOffered }
        try await user.saveAndCache(in: db)
        return .success(card: card, oneShotApplied: applied)
    }

    /// What names one draw: its moment, in whole seconds. A card id cannot —
    /// the same card comes back on another day — so a confirmation carries this
    /// and the dispel compares it. Nil before the first draw.
    public static func fortuneDrawToken(of user: User) -> Int? {
        user.lastFortuneDrawAt.map { Int($0.timeIntervalSince1970.rounded()) }
    }

    /// Debit `price`, pick a card uniformly, land its one-shot half, stamp the
    /// card and its window, and set `stage`. The caller has checked the gates
    /// and saves. Nil only for an empty deck, which the validator refuses.
    private static func deal(to user: User, price: Int, stage: FortuneStage) -> (FortuneCard, OneShotApplied)? {
        guard let card = FortuneCatalog.all.randomElement() else { return nil }
        user.silver -= price
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
            user.hp = user.effectiveMaxHp
            applied.hpRestored = true
        }

        if effect.oneShotVigorRestore {
            user.vigor = user.maxVigor
            applied.vigorRestored = true
        }

        // Stamp active card + buff expiry (6h) + draw timestamp (drives
        // the wait for the next card, `User.fortuneAvailableAt`). For pure one-shots `activeFortuneEffect`
        // will return nil even before expiry (hasDurationEffect == false),
        // but we still set both fields so the entry screen renders the
        // "card of the day" reminder + accurate cooldown countdown.
        let now = Date()
        user.activeFortuneCardId = card.id
        user.activeFortuneExpiresAt = now.addingTimeInterval(FortuneCatalog.buffDurationSeconds)
        user.lastFortuneDrawAt = now
        user.fortuneStage = stage

        // Keep what the one-shot half actually handed over, so the entry
        // screen can say it hours later. Written unconditionally — a pure
        // duration card zeroes the record rather than leaving the previous
        // draw's numbers standing under a new card's name.
        user.lastFortuneSilverDelta = applied.silverDelta
        user.lastFortuneXpGain = applied.xpGained
        user.lastFortuneHpRestored = applied.hpRestored
        user.lastFortuneVigorRestored = applied.vigorRestored
        // Re-arm the watchman: this draw starts a fresh cooldown, and its end
        // is worth announcing again.
        user.fortuneReadyNotified = false
        return (card, applied)
    }
}
