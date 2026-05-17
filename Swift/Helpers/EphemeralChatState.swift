//
//  EphemeralChatState.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 23.04.2026.
//
//  In-memory bookkeeping for transient bot state we want to track between
//  updates but never persist:
//
//    • Exploration picker — message ID of the inline picker shown on the
//      first Explore tap so we can delete it when the player navigates away.
//
//    • Warehouse withdraw-N — when the player taps the [✏️ N] button on a
//      warehouse row, we record (itemId + prompt message ID + warehouse
//      screen message ID). The very next text update is then interpreted
//      as the quantity to withdraw; cancel or completion clears the entry.
//
//  Intentionally NOT persisted. If the bot restarts mid-flow, any stale
//  prompt in the chat history is harmless — its inline [Cancel] button is
//  the only live affordance, and the controller treats a missing pending
//  entry as a no-op.
//

import Foundation

public actor EphemeralChatState {
    public static let shared = EphemeralChatState()

    private var pendingPickers: [Int64: Int] = [:]

    public func setPicker(telegramId: Int64, messageId: Int) {
        pendingPickers[telegramId] = messageId
    }

    public func takePicker(telegramId: Int64) -> Int? {
        pendingPickers.removeValue(forKey: telegramId)
    }

    // MARK: - Warehouse transfer-N (two-stage prompt)
    //
    // The `[✏️ N]` button opens a direction picker first (`Where? → To bag /
    // To warehouse`); the bot edits that same prompt into a quantity question
    // once direction is chosen, then awaits the player's typed number. Both
    // stages share one pending record per user, with `direction == nil`
    // representing the direction-picker stage and a set direction
    // representing the awaiting-number stage. Cancel works identically in
    // either stage — clear the entry and delete the prompt.

    public struct PendingWarehouseTransfer: Sendable {
        public enum Direction: String, Sendable { case put, take }
        public let itemId: String
        public let promptMessageId: Int
        public let warehouseMessageId: Int
        public var direction: Direction?
    }

    private var pendingWarehouseTransfers: [Int64: PendingWarehouseTransfer] = [:]

    public func setPendingWarehouseTransfer(
        telegramId: Int64,
        itemId: String,
        promptMessageId: Int,
        warehouseMessageId: Int,
        direction: PendingWarehouseTransfer.Direction? = nil
    ) {
        pendingWarehouseTransfers[telegramId] = PendingWarehouseTransfer(
            itemId: itemId,
            promptMessageId: promptMessageId,
            warehouseMessageId: warehouseMessageId,
            direction: direction
        )
    }

    /// Bump direction on the existing pending entry (called when the player
    /// taps `[⬆️ To warehouse]` / `[⬇️ To bag]`). No-op if no pending entry
    /// exists — guards against stale callbacks where the state has already
    /// been cleared by a parallel cancel.
    public func setPendingWarehouseTransferDirection(
        telegramId: Int64,
        direction: PendingWarehouseTransfer.Direction
    ) {
        guard var current = pendingWarehouseTransfers[telegramId] else { return }
        current.direction = direction
        pendingWarehouseTransfers[telegramId] = current
    }

    public func peekPendingWarehouseTransfer(telegramId: Int64) -> PendingWarehouseTransfer? {
        pendingWarehouseTransfers[telegramId]
    }

    public func takePendingWarehouseTransfer(telegramId: Int64) -> PendingWarehouseTransfer? {
        pendingWarehouseTransfers.removeValue(forKey: telegramId)
    }

    // MARK: - Status banners (separate-message UX, 2026-05-15)
    //
    // Status confirmations (`✅ Crafted ...`, `❌ Not enough ...`, etc.) used
    // to live INSIDE the body of the screen they refreshed. The user reported
    // those banners as easy to miss — buried at the top (or bottom) of a long
    // item list, well above the inline keyboard where their eye sits. We now
    // emit them as standalone messages BELOW the inline-keyboard message and
    // track the latest one per user so a new banner deletes the stale one
    // instead of letting them stack up in chat history.

    private var lastStatusBanners: [Int64: Int] = [:]

    public func setLastStatusBanner(telegramId: Int64, messageId: Int) {
        lastStatusBanners[telegramId] = messageId
    }

    public func takeLastStatusBanner(telegramId: Int64) -> Int? {
        lastStatusBanners.removeValue(forKey: telegramId)
    }

    // MARK: - Scenery photo slot (Phase 6.3 chat-cleanup, 2026-05-17)
    //
    // One "scenery" photo per user lives in chat at a time — the capital
    // welcome, trader/tavern/etc. location entries, and estate landscapes
    // all share this slot. `sendScenicPhoto` deletes the previous entry
    // before sending a new one, so navigation between locations replaces
    // the photo bubble instead of stacking duplicates. Sub-screens that
    // edit the SAME photo via `editMessageCaption` don't touch the slot.

    private var lastSceneryPhotos: [Int64: Int] = [:]

    public func setLastSceneryPhoto(telegramId: Int64, messageId: Int) {
        lastSceneryPhotos[telegramId] = messageId
    }

    public func takeLastSceneryPhoto(telegramId: Int64) -> Int? {
        lastSceneryPhotos.removeValue(forKey: telegramId)
    }

    // MARK: - Trader bulk-N (Phase 6.1 polish)
    //
    // Tap of `[✏️ N]` on a trader buy/sell row opens a prompt asking for
    // a quantity. The next text update from this user is interpreted as
    // that number. Mirrors the warehouse withdraw-N / deposit-N flow:
    // invalid input (non-numeric / ≤0) edits the prompt in place and
    // keeps pending; cancel / successful trade / validation failure all
    // clear the entry.

    public struct PendingTraderTransfer: Sendable {
        public enum Direction: String, Sendable { case buy, sell }
        public let itemId: String
        public let direction: Direction
        public let promptMessageId: Int
        public let traderScreenMessageId: Int
        public let isPhoto: Bool
    }

    private var pendingTraderTransfers: [Int64: PendingTraderTransfer] = [:]

    public func setPendingTraderTransfer(telegramId: Int64, transfer: PendingTraderTransfer) {
        pendingTraderTransfers[telegramId] = transfer
    }

    public func peekPendingTraderTransfer(telegramId: Int64) -> PendingTraderTransfer? {
        pendingTraderTransfers[telegramId]
    }

    public func takePendingTraderTransfer(telegramId: Int64) -> PendingTraderTransfer? {
        pendingTraderTransfers.removeValue(forKey: telegramId)
    }

}
