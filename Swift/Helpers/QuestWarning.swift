//
//  QuestWarning.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.11.2026.
//
//  "This feeds a job you took" — one `⚠️` line per taken delivery job waiting
//  for an item, for every screen that is about to take that item away.
//
//  Lifted out of `CapitalController` on 2026-11-01, when the bag's item card
//  started to throw items away and to eat several at once: a sale into a job
//  and a discard of the job's berries are the same loss, so they are phrased
//  by one function rather than two. The trader and the market append the lines
//  to their prompts; the bag prints them on the card, before the tap, because
//  its many-portion and discard buttons act without a question of their own.
//
//  Advisory: a failed read prints nothing rather than blocking the screen.
//  The count is what the bag holds (`QuestService.acceptedDeliveries`), so it
//  can read past the target — the same number the trader has always shown.
//

import Fluent
import Foundation
import Lingo

enum QuestWarning {

    /// The warning lines for `itemId`, each starting with `⚠️`. Empty when no
    /// taken job waits for the item.
    static func lines(itemId: String, for user: User, on db: any Database,
                      lingo: Lingo, locale: String) async -> [String] {
        let jobs = (try? await QuestService.acceptedDeliveries(of: itemId, for: user, on: db)) ?? []
        return jobs.map { job in
            "⚠️ " + lingo.localize("capital.trader.bulkN.quest_warning", locale: locale, interpolations: [
                "job": lingo.localize(job.def.titleKey, locale: locale),
                "done": "\(job.done)",
                "target": "\(job.target)"
            ])
        }
    }
}
