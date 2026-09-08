//
//  AllowedUser.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.09.2026.
//
//  One Telegram account permitted to talk to the bot.
//
//  This table replaces the hardcoded `allowedUsers` array that used to live in
//  `configure.swift`: the closed test hands out access at run time, and an
//  allow list that needs a recompile and a restart cannot do that. The four
//  founding accounts are seeded by `CreateAllowedUsers` so the move costs
//  nobody their access.
//
//  Rows are added two ways — `.seed` by that migration, `.invite` when someone
//  redeems a `/link` deep link inside its five-minute window. `username` is
//  whatever Telegram reported at the moment of redemption and is stored for
//  the admin's benefit only: it is a display name that its owner can change at
//  will, never an identity. `telegramId` is the identity.
//
//  NOT player state: the row survives `WipeForRebalance` (it is listed in that
//  migration's `preserved` set), because a wipe resets the game, not the
//  guest list.
//

import Fluent
import Foundation

final public class AllowedUser: Model, @unchecked Sendable {
    public static let schema = "allowed_users"

    /// How this account came to be on the list. Stored as a raw string so a
    /// future source can be added without a migration.
    public enum Source: String {
        /// Seeded from the old hardcoded array when the table was created.
        case seed
        /// Redeemed a `/link` invite.
        case invite
        /// Written straight into the table by an admin, outside the bot. Never
        /// produced by this code — it exists so a hand-written row reads as
        /// deliberate rather than as corruption.
        case manual
    }

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "telegram_id")
    public var telegramId: Int64

    /// `@username` at the moment of redemption, without the `@`. Optional
    /// because plenty of Telegram accounts simply do not have one.
    @OptionalField(key: "username")
    public var username: String?

    @Field(key: "source")
    public var source: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(telegramId: Int64, username: String? = nil, source: Source) {
        self.telegramId = telegramId
        self.username = username
        self.source = source.rawValue
    }
}
