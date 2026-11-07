//
//  AddVigorThrift.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.11.2026.
//
//  Adds `users.vigor_thrift_percent` and `users.vigor_thrift_until` — Міцна
//  настоянка чебрецю is working: every Vigor cost is that percent lower until
//  then. Two columns with their defaults and no row rewritten: nobody has drunk
//  one yet.
//

import Fluent

struct AddVigorThrift: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("vigor_thrift_percent", .int, .required, .sql(.default(0)))
            .field("vigor_thrift_until", .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("vigor_thrift_percent")
            .deleteField("vigor_thrift_until")
            .update()
    }
}
