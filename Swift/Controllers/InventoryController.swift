//
//  InventoryController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  Read-only inventory viewer. Loads all InventoryEntry rows for the user,
//  resolves each to its static Item catalog entry, and renders grouped by type.
//  Use/equip flows are out of scope here — planned for Phase 2.2 and 2.3.
//

import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Inventory Controller Logic
final class InventoryController: TGControllerBase, @unchecked Sendable {
    typealias T = InventoryController

    // MARK: - Controller Lifecycle
    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart

            let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
            for button in cancelLocales { router[button.text] = onCancel }

            router.unmatched = unmatched
        }
        await processRouterForEachName(router)
    }

    public func onStart(context: Context) async throws -> Bool {
        let mainController = Controllers.mainController
        try await mainController.showMainMenu(context: context)
        context.session.routerName = mainController.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onCancel(context: Context) async throws -> Bool {
        return try await onStart(context: context)
    }

    override func unmatched(context: Context) async throws -> Bool {
        guard try await super.unmatched(context: context) else { return false }
        try await showInventory(context: context)
        return true
    }

    public func showInventory(context: Context) async throws {
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)
        let text = renderInventory(entries: entries, lingo: context.lingo, locale: context.session.locale)
        let markup = generateControllerKB(session: context.session, lingo: context.lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        let markup = TGReplyKeyboardMarkup(keyboard: [[
            Commands.cancel.button(for: session, lingo)
        ]], resizeKeyboard: true)
        return TGReplyMarkup.replyKeyboardMarkup(markup)
    }

    // MARK: - Rendering

    private func renderInventory(entries: [InventoryEntry], lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("inventory.title", locale: locale)

        guard !entries.isEmpty else {
            let empty = lingo.localize("inventory.empty", locale: locale)
            return "<b>\(title)</b>\n\n\(empty)"
        }

        var bucketed: [ItemType: [(item: Item, quantity: Int)]] = [:]
        for entry in entries {
            guard let item = ItemCatalog.find(entry.itemId) else { continue }
            bucketed[item.type, default: []].append((item, entry.quantity))
        }

        let typeOrder: [ItemType] = [.food, .material, .potion, .gear, .recipe, .artifact]
        var sections: [String] = []
        for type in typeOrder {
            guard let items = bucketed[type], !items.isEmpty else { continue }
            let sectionTitle = lingo.localize("inventory.type.\(type.rawValue)", locale: locale)
            let header = "\(type.icon) <b>\(sectionTitle)</b>"
            let merged = mergeForDisplay(items)
            let lines = merged.map { "• \(lingo.localize($0.item.nameKey, locale: locale)) × \($0.quantity)" }
            sections.append(([header] + lines).joined(separator: "\n"))
        }

        return "<b>\(title)</b>\n\n" + sections.joined(separator: "\n\n")
    }

    /// Non-stackable items live in separate rows; collapse them into one line per item for display.
    private func mergeForDisplay(_ items: [(item: Item, quantity: Int)]) -> [(item: Item, quantity: Int)] {
        var byId: [String: (item: Item, quantity: Int)] = [:]
        for entry in items {
            if let existing = byId[entry.item.id] {
                byId[entry.item.id] = (existing.item, existing.quantity + entry.quantity)
            } else {
                byId[entry.item.id] = entry
            }
        }
        return Array(byId.values).sorted { $0.item.id < $1.item.id }
    }
}
