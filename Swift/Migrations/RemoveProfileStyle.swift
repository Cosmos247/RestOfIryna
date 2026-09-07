//
//  RemoveProfileStyle.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.09.2026.
//
//  Drops `profile_style` from users. The profile screen used to render three
//  layouts and keep the player's pick here, switched by the `pstyle:` buttons
//  under the message; it now renders one layout — the emoji-bar one that was
//  style 3 — so the column has no reader left.
//
//  `revert` puts the column back exactly as `AddProfileStyle` created it,
//  required with a default of 1, so a restored schema starts every player on
//  the first layout rather than on NULL.
//

import Fluent

struct RemoveProfileStyle: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("profile_style")
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .field("profile_style", .int, .required, .sql(.default(1)))
            .update()
    }
}
