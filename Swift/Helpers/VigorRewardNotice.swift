//
//  VigorRewardNotice.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.10.2026.
//
//  What a Vigor reward that will not fit says, before and after.
//
//  Both payouts that grant Vigor — a royal decree and an NPC job — clamp it to
//  the pool, so a player who turns one in at full Vigor gets nothing for it.
//  Until 2026-10-04 nothing said so: a decree paying only Vigor (20 of 39)
//  posted «✅ Указ виконано» over an empty «💰», and a part that did not fit
//  vanished from every banner. A tester turned one in at full Vigor and asked
//  where the prize went.
//
//  The owner's answer has three parts, and all three are here so the decree
//  and the job cannot phrase the same loss two ways:
//    • `warning` — the line on the card while the reward would not fit
//      (the palace card and the journal for a decree, the NPC board for a job);
//    • `question` — the screen the turn-in tap shows first in that case, with
//      the choice to report anyway or come back later;
//    • `lostLine` — the banner's line when the player reported anyway.
//
//  The arithmetic is `VigorService.overflow`, the payouts' own clamp asked
//  beforehand.
//

import Foundation
import Lingo

enum VigorRewardNotice {

    /// What carries the reward, which decides the "it can wait" sentence.
    enum Source {
        case decree
        case job

        var waitsKey: String {
            switch self {
            case .decree: return "king.vigor.waits"
            case .job:    return "quest.vigor.waits"
            }
        }
    }

    /// «Снага повна (120/120) — 🍖 60 не вміститься.» or «Вміститься лише 10
    /// з 🍖 60 (снага 110/120).», or nil when the whole reward fits.
    private static func fitSentence(reward: Int, for user: User, lingo: Lingo, locale: String) -> String? {
        let lost = VigorService.overflow(of: reward, for: user)
        guard lost > 0 else { return nil }
        let fit = reward - lost
        let slots: [String: Any] = [
            "reward": "🍖 \(reward)",
            "fit": "\(fit)",
            "current": "\(user.vigor)",
            "max": "\(user.maxVigor)"
        ]
        let key = fit > 0 ? "reward.vigor.some_fits" : "reward.vigor.none_fits"
        return lingo.localize(key, locale: locale, interpolations: slots)
    }

    /// The card's line while a Vigor reward would not fit, nil when it would.
    /// ⚠️ is prepended here — a leading supplementary-plane emoji breaks Lingo's
    /// `%{var}` parser, see `.memory/localization.md`.
    static func warning(reward: Int, from source: Source, for user: User, lingo: Lingo, locale: String) -> String? {
        guard let sentence = fitSentence(reward: reward, for: user, lingo: lingo, locale: locale) else { return nil }
        return "⚠️ " + sentence + " " + lingo.localize(source.waitsKey, locale: locale)
    }

    /// The question the turn-in tap asks first when Vigor would be lost — the
    /// same sentence as the card, on lines of its own. Nil when it would all
    /// fit, which is the caller's cue to pay at once.
    static func question(reward: Int, from source: Source, for user: User, lingo: Lingo, locale: String) -> String? {
        guard let sentence = fitSentence(reward: reward, for: user, lingo: lingo, locale: locale) else { return nil }
        return "⚠️ " + sentence + "\n" + lingo.localize(source.waitsKey, locale: locale)
    }

    /// «🍖 Снага повна (120/120) — 60 не вмістилось», for the banner after a
    /// payout that lost `lost` Vigor; nil when nothing was lost. Read after the
    /// payout, so the pool it quotes is the full one the player now holds.
    static func lostLine(lost: Int, for user: User, lingo: Lingo, locale: String) -> String? {
        guard lost > 0 else { return nil }
        return "🍖 " + lingo.localize("reward.vigor.lost", locale: locale, interpolations: [
            "lost": "\(lost)",
            "current": "\(user.vigor)",
            "max": "\(user.maxVigor)"
        ])
    }
}
