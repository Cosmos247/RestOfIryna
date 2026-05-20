//
//  TavernGameMessage.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 20.05.2026.
//
//  A single Telegram message sprayed into chat by a tavern dice/darts round
//  (a throw label, an animated die, or the result line). Telegram forbids
//  bots from deleting a dice message in a private chat until it is 24 h old,
//  so each round is left in chat as game history and rows here record what
//  to delete later. `TavernCleanupService` sweeps rows whose `created_at`
//  has aged past the 24 h limit, deletes the underlying Telegram message,
//  then drops the row.
//
//  Keyed by raw `telegram_id` (= private-chat id) rather than a User parent:
//  we only ever need (chatId, messageId) to delete, and avoiding the foreign
//  key keeps the sweep a flat query with no joins.
//

import Fluent
import Foundation

final public class TavernGameMessage: Model, @unchecked Sendable {
    public static let schema = "tavern_game_messages"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "telegram_id")
    public var telegramId: Int64

    @Field(key: "message_id")
    public var messageId: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(telegramId: Int64, messageId: Int) {
        self.telegramId = telegramId
        self.messageId = messageId
    }
}
