//
//  ZlatnykPurchase.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  One row per purchase in the Treasury: who, what, for how many zlatnyks,
//  what it did and when. The owner reads it in DBeaver, and it is the answer to
//  «я заплатив, а нічого не отримав». Written in the same transaction as the
//  purchase itself, so a row exists exactly when the zlatnyks were taken.
//
//  History, like `fight_log`: `item_id` is deliberately NOT in
//  `LiveReferenceQuery`, so a retired entry's old purchases never block a
//  `/reload`.
//

import Fluent
import Foundation

public final class ZlatnykPurchase: Model, @unchecked Sendable {
    public static let schema = "zlatnyk_purchases"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// As it was at the purchase, so «who» needs no join and a later rename
    /// leaves the record as it was.
    @Field(key: "telegram_id")
    public var telegramId: Int64

    @OptionalField(key: "nickname")
    public var nickname: String?

    /// The `treasury.json` id bought.
    @Field(key: "item_id")
    public var itemId: String

    @Field(key: "price")
    public var price: Int

    /// What the purchase did, in the log's own words — `archer → warrior`.
    @Field(key: "detail")
    public var detail: String

    /// The balance left after it.
    @Field(key: "balance_after")
    public var balanceAfter: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(userId: UUID, telegramId: Int64, nickname: String?, itemId: String, price: Int,
                detail: String, balanceAfter: Int) {
        self.$user.id = userId
        self.telegramId = telegramId
        self.nickname = nickname
        self.itemId = itemId
        self.price = price
        self.detail = detail
        self.balanceAfter = balanceAfter
    }
}
