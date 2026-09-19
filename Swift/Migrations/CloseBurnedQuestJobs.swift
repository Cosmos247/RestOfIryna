//
//  CloseBurnedQuestJobs.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.09.2026.
//
//  2026-09-19, on the owner's call: a daily job the player has taken no longer
//  burns at noon. It stays open until turned in, and the NPC offers nothing new
//  meanwhile — one open job per NPC.
//
//  The old rule burned a job by simply never reading its row again, so every
//  taken-but-unfinished job since 09-02 is still marked `accepted`: 33 of them
//  across 6 players on the day this landed, one player holding six at the
//  Master and six at the trader. Read under the new rule they would all come
//  back, queued, and hold today's offers behind a week of forgotten errands.
//  A dry run against that data kept 9 (3 from yesterday, 6 from today).
//
//  So, once: per player and NPC the NEWEST open job survives if it was taken
//  today or yesterday, and every other one goes back to being an offer nobody
//  took — `accepted = false`, which is exactly the state the old rule left it
//  in, since nothing ever read a past day's row. The decision is
//  `QuestCarryOver.burned`, which the tests pin; this file only applies it.
//
//  Irreversible in the sense that `accepted` is not remembered, so `revert`
//  can only say so. Progress is left as it was — a closed row is never read.
//

import Fluent
import Foundation
import SQLKit

struct CloseBurnedQuestJobs: AsyncMigration {
    enum CloseError: Error { case notSQL(driver: String) }

    private struct OpenRow: Decodable {
        let id: UUID
        let userID: UUID
        let npc: String
        let dayStamp: String

        enum CodingKeys: String, CodingKey {
            case id
            case userID = "user_id"
            case npc
            case dayStamp = "day_stamp"
        }
    }

    func prepare(on database: any Database) async throws {
        // `throw`, not `return`, for `ResetDeepestKm`'s reason: skipping this
        // would record the migration as done while every old job came back.
        guard let sql = database as? any SQLDatabase else {
            throw CloseError.notSQL(driver: "\(type(of: database))")
        }
        let open = try await sql.select()
            .columns("id", "user_id", "npc", "day_stamp")
            .from(QuestProgress.schema)
            .where("accepted", .equal, true)
            .where("claimed", .equal, false)
            .all(decoding: OpenRow.self)

        let burned = QuestCarryOver.burned(
            open.map { .init(id: $0.id, userId: $0.userID, npc: $0.npc, dayStamp: $0.dayStamp) },
            today: GameDay.stamp()
        )
        if !burned.isEmpty {
            try await sql.update(QuestProgress.schema)
                .set("accepted", to: false)
                .where("id", .in, Array(burned))
                .run()
        }
        database.logger.info("CloseBurnedQuestJobs: \(burned.count) of \(open.count) open jobs closed — only today's and yesterday's newest per NPC stay open")
    }

    func revert(on database: any Database) async throws {
        // Nothing to restore — which rows had been taken is not kept.
    }
}
