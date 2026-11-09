//
//  Horse.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 09.11.2026.
//
//  The Rysak a player hired at the stable («🐴 Рисак»,
//  `content/spec/spec-horse.md`): one row a player who has ever hired one. A
//  hire only changes how long a road takes, so the row is its end and the end
//  the watchman has already announced.
//

import Fluent
import Foundation

final public class Horse: Model, @unchecked Sendable {
    public static let schema = "horses"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// When the hire runs out.
    @Field(key: "ends_at")
    public var endsAt: Date

    /// The end the watchman has announced. Written before the notice goes
    /// out; a new hire moves `endsAt` past it, which arms the next notice.
    @OptionalField(key: "announced_end")
    public var announcedEnd: Date?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(userID: UUID, endsAt: Date) {
        self.$user.id = userID
        self.endsAt = endsAt
        self.announcedEnd = nil
    }

    /// True while the hire runs: a trip set out now rides it.
    public func isRunning(at now: Date = Date()) -> Bool {
        endsAt > now
    }
}
