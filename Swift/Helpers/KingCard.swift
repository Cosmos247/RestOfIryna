//
//  KingCard.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 21.09.2026.
//
//  The open decree as a block of text. ONE renderer, because three screens
//  show the same decree and they must not be able to disagree about it: the
//  palace card, the journal, and the charter the King's own scroll opens with
//  after registration.
//
//  Each screen wraps this in its own header and adds its own footer — the
//  palace puts the report button under it, the journal says where to take it,
//  the charter says where it came from. What the decree IS belongs here.
//
//  Conditions go through `RequirementLine` for the same reason every material
//  list does: "what it asks for / what you have" is one sentence in this game,
//  and a screen that phrases it its own way is a screen that will one day
//  disagree with the button beside it.
//

import Foundation
import Lingo

enum KingCard {

    /// Name, description, every condition, and what it pays.
    static func block(_ standing: KingService.Standing, lingo: Lingo, locale: String) -> String {
        let decree = standing.decree
        var lines = [
            "<b>" + lingo.localize(KingCatalog.nameKey(decree), locale: locale) + "</b>",
            "<i>«" + lingo.localize(KingCatalog.descKey(decree), locale: locale) + "»</i>",
        ]
        for condition in standing.conditions {
            if let itemId = condition.itemId {
                lines.append(RequirementLine.item(itemId, have: condition.have, need: condition.need,
                                                  lingo: lingo, locale: locale))
            } else if let key = condition.labelKey {
                lines.append(RequirementLine.render(label: lingo.localize(key, locale: locale),
                                                    have: condition.have, need: condition.need))
            }
        }
        // 🎁 prepended in Swift — a leading supplementary-plane emoji breaks
        // Lingo's `%{var}` parser. See .memory/localization.md.
        lines.append("🎁 " + lingo.localize("quest.reward", locale: locale, interpolations: [
            "reward": CapitalController.kingRewardPhrase(decree.reward, lingo: lingo, locale: locale)
        ]))
        return lines.joined(separator: "\n")
    }
}
