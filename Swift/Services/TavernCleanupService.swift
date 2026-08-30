//
//  TavernCleanupService.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.05.2026.
//
//  Deletes the chat clutter left by tavern dice/darts rounds — but only once
//  it's old enough that Telegram lets us. Telegram's `deleteMessage` refuses
//  to remove a dice message in a private chat until it is more than 24 h old
//  (an anti-cheat measure so bots can't retroactively hide a roll). So we
//  can't collapse a round the moment it ends; instead each round records its
//  message ids (`TavernGameMessage`) and this service sweeps them away as
//  soon as they cross the 24 h line.
//
//  The sweep is a single long-running `Task.detached` (mirrors
//  `PlotProductionService.startTicker`): an initial pass on boot to catch up
//  on anything that aged out during downtime, then every `sweepInterval`.
//

import Fluent
import Foundation
import SwiftTelegramBot

public enum TavernCleanupService {

    /// Telegram won't delete a private-chat dice message younger than this.
    /// 24 h plus a small margin so we never race the boundary and fail.
    ///
    /// A PROTOCOL constant, not a balance number — it lives in `time.json`'s
    /// `realTime` section for exactly that reason. Scaling it with `time.scale`
    /// would not rebalance the tavern, it would break the sweep: every delete
    /// would come back as an error and the rows would pile up forever.
    static var deletableAfter: TimeInterval { Catalogs.current.tuningTime.realTime.tavernDeletableAfter }

    /// How often the background loop scans for aged-out messages.
    static var sweepInterval: TimeInterval { Catalogs.current.tuningTime.realTime.tavernSweepInterval }

    // MARK: - Recording

    /// Persist a round's message ids so the sweep can delete them later.
    /// Called from `CapitalController.runRound` after the result is sent.
    public static func record(messageIds: [Int], telegramId: Int64, on db: any Database) async throws {
        for id in messageIds {
            try await TavernGameMessage(telegramId: telegramId, messageId: id).save(on: db)
        }
    }

    // MARK: - Background sweep

    /// Spawn the long-running cleanup loop. Called from `configure.swift`
    /// after `bot.start()`. Fire-and-forget — lives until process exit.
    public static func startSweeper(on db: any Database, bot: TGBot) {
        Task.detached {
            // Catch-up pass first: rows that aged past 24 h while the bot was
            // down are deletable right now.
            await sweepSafely(on: db, bot: bot)
            while true {
                try? await Task.sleep(nanoseconds: UInt64(sweepInterval * 1_000_000_000))
                await sweepSafely(on: db, bot: bot)
            }
        }
    }

    /// One sweep, errors swallowed so a transient DB blip never kills the
    /// loop.
    private static func sweepSafely(on db: any Database, bot: TGBot) async {
        do {
            try await sweep(on: db, bot: bot)
        } catch {
            // Best-effort; next tick retries.
        }
    }

    /// Delete every recorded message older than `deletableAfter`, then drop
    /// its row. At >24 h Telegram permits deleting the dice too, so this is
    /// where the dice finally disappear. The row is removed regardless of the
    /// delete outcome (a message the player already wiped, or a closed chat,
    /// shouldn't keep the table growing).
    public static func sweep(on db: any Database, bot: TGBot) async throws {
        let cutoff = Date().addingTimeInterval(-deletableAfter)
        let aged = try await TavernGameMessage.query(on: db)
            .filter(\.$createdAt < cutoff)
            .all()

        for row in aged {
            _ = try? await bot.deleteMessage(params: TGDeleteMessageParams(
                chatId: .chat(row.telegramId),
                messageId: row.messageId
            ))
            try? await row.delete(on: db)
        }
    }
}
