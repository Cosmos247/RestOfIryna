//
//  GameData.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Holder for the live `GameContent` snapshot.
//
//  The hard constraint: `ItemCatalog.find(_:)` and friends must stay
//  synchronous, non-throwing and nonisolated, because roughly 315 call sites
//  read them from `Sendable`, non-async contexts (`EquipmentService`
//  .contributedStats being the awkward one). So the holder cannot be an actor
//  and cannot be async.
//
//  `nonisolated(unsafe)` + `NSLock` rather than `Synchronization.Mutex`:
//  `Mutex` is macOS 15+, and the package targets macOS 14. A lock acquire is
//  ~20 ns against a bot handling hundreds of updates per second, so the
//  difference is not measurable. This also mirrors the existing `appState` /
//  `AppState.bot` pattern in `configure.swift`.
//
//  NOT `@TaskLocal`: task-locals do not propagate into `Task.detached`, and six
//  long-lived detached tasks read catalogs (`PassiveExpeditionService.runLive`,
//  `TravelService`, `PlotProductionService`, `TavernCleanupService`,
//  `TradeStore`, `ArenaService`).
//

import Foundation

public enum GameData {
    private nonisolated(unsafe) static var _current: GameContent?
    private static let lock = NSLock()

    /// Never nil after bootstrap. Trapping is the correct behaviour: reading a
    /// catalog before `install` is a programmer ordering error, not a runtime
    /// condition a player can reach.
    public static var current: GameContent {
        lock.lock()
        defer { lock.unlock() }
        guard let content = _current else {
            fatalError("GameData read before ContentLoader bootstrap — check ordering in configure.swift")
        }
        return content
    }


    /// Atomic hot-swap. The caller must already have parsed, validated and
    /// built `content` — this step is infallible and must be the last one, so
    /// any earlier failure leaves the previous snapshot untouched.
    public static func install(_ content: GameContent) {
        lock.lock()
        _current = content
        lock.unlock()
    }
}
