//
//  AddPassiveRunningReport.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 06.05.2026.
//
//  Phase 3.3 polish: persist a step-by-step running snapshot of the passive
//  expedition's accumulated state (outcome counters + loot totals + the HP /
//  vigor values captured at expedition start) so a bot restart mid-run
//  resumes with a complete picture.
//
//  Without this column the in-memory `runLive` dicts reset on restart and
//  the final report only reflects post-restart events. With it, every step
//  serializes the running totals into `running_report_json` alongside the
//  existing `stepsDeep` write — single save, both fields persisted together.
//
//  Nullable for forward compatibility — active rows stay nil, legacy passive
//  rows created before this migration also stay nil and fall back to the
//  pre-existing lazy-capture-on-first-step behaviour. Cleared together with
//  the rest of the row when the expedition ends.
//

import Fluent

struct AddPassiveRunningReport: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .field("running_report_json", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("exploration_state")
            .deleteField("running_report_json")
            .update()
    }
}
