//
//  InventoryController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  Inventory viewer with tree navigation.
//
//  UI is a single message whose text and inline keyboard are edited as the player
//  drills in and out:
//    Root view      — category buttons with counts (only non-empty types), + [Close]
//    Category view  — food/potion: row per item [Item × N] [🍽 Use]; others: list in body; + [Back]
//  The message is sent fresh on entry and deleted on [Close], which transitions to main.
//
//  Main-menu reply keyboard stays visible while the player is in inventory. The router
//  registers handlers for each main-nav button text so those presses navigate correctly
//  instead of re-opening inventory via unmatched().
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

            // Main-nav pass-through: reply-keyboard clicks while in inventory should navigate.
            let exploreLocales = Commands.explore.buttonsForAllLocales(lingo: lingo)
            for button in exploreLocales { router[button.text] = onExplore }

            let estateLocales = Commands.estate.buttonsForAllLocales(lingo: lingo)
            for button in estateLocales { router[button.text] = onEstate }

            let capitalLocales = Commands.capital.buttonsForAllLocales(lingo: lingo)
            for button in capitalLocales { router[button.text] = onCapital }

            let profileLocales = Commands.profile.buttonsForAllLocales(lingo: lingo)
            for button in profileLocales { router[button.text] = onProfile }

            let settingsLocales = Commands.settings.buttonsForAllLocales(lingo: lingo)
            for button in settingsLocales { router[button.text] = onSettings }

            let inventoryLocales = Commands.inventory.buttonsForAllLocales(lingo: lingo)
            for button in inventoryLocales { router[button.text] = onRefresh }

            router.unmatched = unmatched
            router[.callback_query(data: nil)] = InventoryController.onCallbackQuery
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

    // MARK: - Main-nav pass-through

    private func onExplore(context: Context) async throws -> Bool {
        let ctrl = Controllers.explorationController
        try await ctrl.showExploration(context: context)
        return true
    }

    private func onEstate(context: Context) async throws -> Bool {
        let ctrl = Controllers.estateController
        try await ctrl.showEstate(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onCapital(context: Context) async throws -> Bool {
        let ctrl = Controllers.capitalController
        try await ctrl.showStub(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onProfile(context: Context) async throws -> Bool {
        let ctrl = Controllers.mainController
        try await ctrl.showProfile(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onSettings(context: Context) async throws -> Bool {
        let ctrl = Controllers.settingsController
        try await ctrl.showSettingsMenu(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onRefresh(context: Context) async throws -> Bool {
        try await showInventory(context: context)
        return true
    }

    // MARK: - Public entry

    public func showInventory(context: Context) async throws {
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)
        let text = renderRoot(entries: entries, lingo: context.lingo, locale: context.session.locale)
        let inline = rootKeyboard(entries: entries, lingo: context.lingo, locale: context.session.locale)
        try await context.bot.sendMessage(
            session: context.session,
            text: text,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(inline)
        )
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        // Reuse main's keyboard so `/buttons` restores nav while in inventory.
        return Controllers.mainController.generateControllerKB(session: session, lingo: lingo)
    }

    // MARK: - Rendering

    fileprivate func renderRoot(entries: [InventoryEntry], lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("inventory.title", locale: locale)
        let slotsUsed = entries.filter { $0.equippedSlot == nil }.count
        let slotsLabel = lingo.localize("inventory.slots_label", locale: locale)
        let header = "<b>\(title)</b>  <i>\(slotsUsed)/\(InventoryEntry.slotCap) \(slotsLabel)</i>"
        if entries.isEmpty {
            return "\(header)\n\n" + lingo.localize("inventory.empty", locale: locale)
        }
        return "\(header)\n\n" + lingo.localize("inventory.choose_category", locale: locale)
    }

    fileprivate func rootKeyboard(entries: [InventoryEntry], lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var countsByType: [ItemType: Int] = [:]
        for entry in entries {
            guard let item = ItemCatalog.find(entry.itemId) else { continue }
            countsByType[item.type, default: 0] += entry.quantity
        }

        // Always render every category — empty ones show (0) and reply with a toast
        // on tap rather than opening an empty drill-down.
        let typeOrder: [ItemType] = [.food, .material, .potion, .gear, .artifact]
        var rows: [[TGInlineKeyboardButton]] = []
        var currentRow: [TGInlineKeyboardButton] = []

        for type in typeOrder {
            let count = countsByType[type, default: 0]
            let name = lingo.localize("inventory.type.\(type.rawValue)", locale: locale)
            let label = "\(type.icon) \(name) (\(count))"
            currentRow.append(TGInlineKeyboardButton(text: label, callbackData: "inv:cat:\(type.rawValue)"))
            if currentRow.count == 2 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    fileprivate func renderCategory(type: ItemType, lingo: Lingo, locale: String) -> String {
        let name = lingo.localize("inventory.type.\(type.rawValue)", locale: locale)
        return "\(type.icon) <b>\(name)</b>"
    }

    fileprivate func categoryKeyboard(type: ItemType, entries: [InventoryEntry], lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let rows: [[TGInlineKeyboardButton]]
        if type == .gear {
            rows = gearRows(entries: entries, lingo: lingo, locale: locale)
        } else {
            rows = genericRows(type: type, entries: entries, lingo: lingo, locale: locale)
        }

        let backLabel = lingo.localize("inventory.back_root", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: rows + [
            [TGInlineKeyboardButton(text: backLabel, callbackData: "inv:root")]
        ])
    }

    /// Gear rows — gear is non-stackable, so every unit is its own physical row
    /// (InventoryEntry). Each row renders as a separate button pair — no `× N`
    /// aggregate since that's always `× 1` anyway. Two unequipped rusty swords
    /// therefore show as two identical buttons. Callbacks stay itemId-based:
    /// the server picks "first matching row" which, for visually identical
    /// gear, is indistinguishable from targeting a specific one.
    private func gearRows(entries: [InventoryEntry], lingo: Lingo, locale: String) -> [[TGInlineKeyboardButton]] {
        let pairs: [(entry: InventoryEntry, item: Item)] = entries.compactMap { entry in
            guard let item = ItemCatalog.find(entry.itemId), item.type == .gear else { return nil }
            return (entry, item)
        }
        // Equipped rows first, then alphabetical by item id for stability across refreshes.
        let sorted = pairs.sorted { lhs, rhs in
            let lhsEquipped = lhs.entry.equippedSlot != nil
            let rhsEquipped = rhs.entry.equippedSlot != nil
            if lhsEquipped != rhsEquipped { return lhsEquipped }
            return lhs.item.id < rhs.item.id
        }

        let equipLabel = lingo.localize("inventory.action.gear", locale: locale)
        let unequipLabel = lingo.localize("inventory.action.gear.unequip", locale: locale)

        return sorted.map { pair in
            let name = lingo.localize(pair.item.nameKey, locale: locale)
            let iconPrefix = pair.item.icon.map { "\($0) " } ?? ""
            let itemLabel = "\(iconPrefix)\(name)"
            let isEquipped = pair.entry.equippedSlot != nil
            let actionLabel = isEquipped ? unequipLabel : equipLabel
            let actionPrefix = isEquipped ? "inv:unequip:" : "inv:equip:"
            return [
                TGInlineKeyboardButton(text: itemLabel, callbackData: "inv:info:\(pair.item.id)"),
                TGInlineKeyboardButton(text: actionLabel, callbackData: "\(actionPrefix)\(pair.item.id)")
            ]
        }
    }

    /// Non-gear rows (food / material / potion / artifact). Materials have no action
    /// button; the others get a type-specific Use button wired to `inv:use:<item_id>`.
    private func genericRows(type: ItemType, entries: [InventoryEntry], lingo: Lingo, locale: String) -> [[TGInlineKeyboardButton]] {
        var items: [(item: Item, quantity: Int)] = []
        for entry in entries {
            guard let item = ItemCatalog.find(entry.itemId), item.type == type else { continue }
            items.append((item, entry.quantity))
        }
        let merged = mergeForDisplay(items)
        let actionLabel = type.actionKey.map { lingo.localize($0, locale: locale) }

        return merged.map { (item, qty) in
            let name = lingo.localize(item.nameKey, locale: locale)
            let itemButton = TGInlineKeyboardButton(text: "\(name) × \(qty)", callbackData: "inv:info:\(item.id)")
            if let actionLabel = actionLabel {
                let actionButton = TGInlineKeyboardButton(text: actionLabel, callbackData: "inv:use:\(item.id)")
                return [itemButton, actionButton]
            } else {
                return [itemButton]
            }
        }
    }

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

// MARK: - Callback Queries

extension InventoryController {
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data else { return false }

        let ctrl = Controllers.inventoryController
        let locale = context.session.locale

        // Back to root
        if data == "inv:root" {
            let entries = try await InventoryEntry.list(for: context.session, on: context.db)
            let text = ctrl.renderRoot(entries: entries, lingo: context.lingo, locale: locale)
            let inline = ctrl.rootKeyboard(entries: entries, lingo: context.lingo, locale: locale)
            let params = TGEditMessageTextParams(
                chatId: .chat(message.chat.id),
                messageId: message.messageId,
                text: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: params)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        // Open category
        if data.starts(with: "inv:cat:") {
            let rawType = String(data.dropFirst("inv:cat:".count))
            guard let type = ItemType(rawValue: rawType) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let entries = try await InventoryEntry.list(for: context.session, on: context.db)

            // Empty category — reply with toast, stay on root.
            let hasItems = entries.contains { ItemCatalog.find($0.itemId)?.type == type }
            if !hasItems {
                let text = context.lingo.localize("inventory.category.empty", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: false))
                return true
            }

            let text = ctrl.renderCategory(type: type, lingo: context.lingo, locale: locale)
            let inline = ctrl.categoryKeyboard(type: type, entries: entries, lingo: context.lingo, locale: locale)
            let params = TGEditMessageTextParams(
                chatId: .chat(message.chat.id),
                messageId: message.messageId,
                text: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: params)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        // Item info — placeholder toast for now; full description view planned later.
        if data.starts(with: "inv:info:") {
            let itemId = String(data.dropFirst("inv:info:".count))
            guard let item = ItemCatalog.find(itemId) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let itemName = context.lingo.localize(item.nameKey, locale: locale)
            let toast = context.lingo.localize("inventory.info.placeholder", locale: locale, interpolations: ["name": itemName])
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: false))
            return true
        }

        // Use — food/potion consume via HungerService; others show "not yet available"
        // until their systems ship (gear = equip Phase 2.3, artifact = activate TBD).
        if data.starts(with: "inv:use:") {
            let itemId = String(data.dropFirst("inv:use:".count))

            guard let item = ItemCatalog.find(itemId) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }

            if !HungerService.isConsumable(item) {
                let text = context.lingo.localize("inventory.use.unavailable", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: false))
                return true
            }

            guard try await InventoryEntry.has(itemId, user: context.session, on: context.db) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            guard let result = HungerService.consume(item, user: context.session) else {
                let text = context.lingo.localize("consume.no_effect", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: false))
                return true
            }
            try await InventoryEntry.remove(itemId, quantity: 1, from: context.session, on: context.db)
            try await context.session.saveAndCache(in: context.db)

            // Toast
            let itemName = context.lingo.localize(item.nameKey, locale: locale)
            var parts: [String] = []
            if result.hungerRestored > 0 {
                parts.append(context.lingo.localize("hunger.restored", locale: locale, interpolations: ["amount": "\(result.hungerRestored)"]))
            }
            if result.hpRestored > 0 {
                parts.append(context.lingo.localize("hp.restored", locale: locale, interpolations: ["amount": "\(result.hpRestored)"]))
            }
            let toast = "\(itemName) — " + parts.joined(separator: ", ")
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: false))

            // Refresh: stay in category if items remain, else pop back to root.
            let entries = try await InventoryEntry.list(for: context.session, on: context.db)
            let stillInCategory = entries.contains { ItemCatalog.find($0.itemId)?.type == item.type }
            let refreshedText: String
            let refreshedInline: TGInlineKeyboardMarkup
            if stillInCategory {
                refreshedText = ctrl.renderCategory(type: item.type, lingo: context.lingo, locale: locale)
                refreshedInline = ctrl.categoryKeyboard(type: item.type, entries: entries, lingo: context.lingo, locale: locale)
            } else {
                refreshedText = ctrl.renderRoot(entries: entries, lingo: context.lingo, locale: locale)
                refreshedInline = ctrl.rootKeyboard(entries: entries, lingo: context.lingo, locale: locale)
            }
            let editParams = TGEditMessageTextParams(
                chatId: .chat(message.chat.id),
                messageId: message.messageId,
                text: refreshedText,
                parseMode: .html,
                replyMarkup: refreshedInline
            )
            _ = try? await context.bot.editMessageText(params: editParams)
            return true
        }

        // Equip gear — finds the first unequipped row of the item and equips it via EquipmentService.
        if data.starts(with: "inv:equip:") {
            let itemId = String(data.dropFirst("inv:equip:".count))
            guard let item = ItemCatalog.find(itemId), item.slot != nil,
                  let userId = context.session.id else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let rows = try await InventoryEntry.query(on: context.db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .all()
            guard let target = rows.first(where: { $0.equippedSlot == nil }) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            try await EquipmentService.equip(target, for: context.session, on: context.db)

            let itemName = context.lingo.localize(item.nameKey, locale: locale)
            let toast = context.lingo.localize("equip.success", locale: locale, interpolations: ["item": itemName])
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: false))

            try await refreshCategory(type: .gear, chatId: .chat(message.chat.id), messageId: message.messageId, context: context)
            return true
        }

        // Unequip gear — finds the equipped row of the item and unequips it.
        if data.starts(with: "inv:unequip:") {
            let itemId = String(data.dropFirst("inv:unequip:".count))
            guard let item = ItemCatalog.find(itemId),
                  let userId = context.session.id else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let rows = try await InventoryEntry.query(on: context.db)
                .filter(\.$user.$id, .equal, userId)
                .filter(\.$itemId, .equal, itemId)
                .all()
            guard let target = rows.first(where: { $0.equippedSlot != nil }) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            try await EquipmentService.unequip(target, for: context.session, on: context.db)

            let itemName = context.lingo.localize(item.nameKey, locale: locale)
            let toast = context.lingo.localize("unequip.success", locale: locale, interpolations: ["item": itemName])
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: false))

            try await refreshCategory(type: .gear, chatId: .chat(message.chat.id), messageId: message.messageId, context: context)
            return true
        }

        return false
    }

    /// Re-render the given category view in place after an equip/unequip.
    private static func refreshCategory(type: ItemType, chatId: TGChatId, messageId: Int, context: Context) async throws {
        let ctrl = Controllers.inventoryController
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)
        let text = ctrl.renderCategory(type: type, lingo: context.lingo, locale: context.session.locale)
        let inline = ctrl.categoryKeyboard(type: type, entries: entries, lingo: context.lingo, locale: context.session.locale)
        let params = TGEditMessageTextParams(
            chatId: chatId,
            messageId: messageId,
            text: text,
            parseMode: .html,
            replyMarkup: inline
        )
        _ = try? await context.bot.editMessageText(params: params)
    }
}
