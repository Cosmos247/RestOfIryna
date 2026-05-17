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
        try await Controllers.estateController.showEstate(context: context)
        return true
    }

    private func onCapital(context: Context) async throws -> Bool {
        try await Controllers.capitalController.showCapital(context: context)
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
        let text = renderRoot(entries: entries, session: context.session, lingo: context.lingo, locale: context.session.locale)
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

    fileprivate func renderRoot(entries: [InventoryEntry], session: User, lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("inventory.title", locale: locale)
        // Per-unit (2026-05-12): sum quantities across all non-equipped rows.
        let slotsUsed = entries.filter { $0.equippedSlot == nil }.reduce(0) { $0 + $1.quantity }
        let slotsLabel = lingo.localize("inventory.slots_label", locale: locale)
        let cap = InventoryEntry.slotCap(for: session)
        let header = "<b>\(title)</b>  <i>\(slotsUsed)/\(cap) \(slotsLabel)</i>"
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
            // Tier-aware name so an upgraded weapon shows e.g. "Sharpened Sword"
            // instead of always "Rusty Sword". Non-tiered gear falls through.
            let name = lingo.localize(ItemDisplay.nameKey(for: pair.item, tier: pair.entry.tier), locale: locale)
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
    /// Recipe-scroll artifacts (`item.teachesRecipe != nil`) override the type label
    /// with "📖 Learn" — same `inv:use:` callback, the handler branches on the field.
    private func genericRows(type: ItemType, entries: [InventoryEntry], lingo: Lingo, locale: String) -> [[TGInlineKeyboardButton]] {
        var items: [(item: Item, quantity: Int)] = []
        for entry in entries {
            guard let item = ItemCatalog.find(entry.itemId), item.type == type else { continue }
            items.append((item, entry.quantity))
        }
        let merged = mergeForDisplay(items)
        let defaultActionLabel = type.actionKey.map { lingo.localize($0, locale: locale) }

        return merged.map { (item, qty) in
            let name = lingo.localize(item.nameKey, locale: locale)
            let iconPrefix = item.icon.map { "\($0) " } ?? ""
            let itemButton = TGInlineKeyboardButton(text: "\(iconPrefix)\(name) × \(qty)", callbackData: "inv:info:\(item.id)")
            let actionLabel: String?
            if item.teachesRecipe != nil {
                actionLabel = lingo.localize("inventory.action.learn", locale: locale)
            } else {
                actionLabel = defaultActionLabel
            }
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

        // Exploration callbacks (e.g. a scheduler-pushed passive report's
        // Close button) can land here if the player was viewing their bag
        // when the expedition completed. Forward to ExplorationController
        // so its full cleanup runs instead of falling through unhandled.
        if data.hasPrefix("explore:") {
            return try await ExplorationController.onCallbackQuery(context: context)
        }
        // Forward combat callbacks (Training Ground keeps routerName at the
        // pre-combat router so reply-keyboard nav stays unblocked).
        if data.hasPrefix("combat:") {
            return try await CombatController.onCallbackQuery(context: context)
        }

        let ctrl = Controllers.inventoryController
        let locale = context.session.locale

        // Back to root
        if data == "inv:root" {
            let entries = try await InventoryEntry.list(for: context.session, on: context.db)
            let text = ctrl.renderRoot(entries: entries, session: context.session, lingo: context.lingo, locale: locale)
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
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: true))
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

        // Item info — if the item has a lore description, show it as a modal
        // alert (readable, dismissable). Otherwise fall back to the generic
        // "description coming soon" toast.
        if data.starts(with: "inv:info:") {
            let itemId = String(data.dropFirst("inv:info:".count))
            guard let item = ItemCatalog.find(itemId) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            // For tiered weapons (3 starter weapons in WeaponUpgradeCatalog) the
            // lore changes per tier — fetch the player's row to know which tier
            // description to render. Non-tiered items just use their static key.
            var resolvedDescKey: String? = item.descriptionKey
            var resolvedNameKey: String = item.nameKey
            if WeaponUpgradeCatalog.isUpgradable(item.id), let userId = context.session.id {
                let row = try await InventoryEntry.query(on: context.db)
                    .filter(\.$user.$id, .equal, userId)
                    .filter(\.$itemId, .equal, item.id)
                    .first()
                let tier = row?.tier ?? 1
                resolvedDescKey = ItemDisplay.descriptionKey(for: item, tier: tier)
                resolvedNameKey = ItemDisplay.nameKey(for: item, tier: tier)
            }
            let answer: TGAnswerCallbackQueryParams
            if let descKey = resolvedDescKey {
                let description = context.lingo.localize(descKey, locale: locale)
                answer = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: description, showAlert: true)
            } else {
                let itemName = context.lingo.localize(resolvedNameKey, locale: locale)
                let toast = context.lingo.localize("inventory.info.placeholder", locale: locale, interpolations: ["name": itemName])
                answer = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true)
            }
            _ = try? await context.bot.answerCallbackQuery(params: answer)
            return true
        }

        // Use — food/potion consume via VigorService; recipe-scroll artifacts
        // route to the Learn flow (Phase 5.2.1); others show "not yet available"
        // until their systems ship (gear = equip Phase 2.3, generic artifact = activate TBD).
        if data.starts(with: "inv:use:") {
            let itemId = String(data.dropFirst("inv:use:".count))

            guard let item = ItemCatalog.find(itemId) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }

            // Recipe scrolls — Learn flow.
            if let recipeId = item.teachesRecipe {
                return try await handleLearnRecipe(itemId: itemId, recipeId: recipeId, item: item, query: query, message: message, context: context)
            }

            if !VigorService.isConsumable(item) {
                let text = context.lingo.localize("inventory.use.unavailable", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: true))
                return true
            }

            // Consumable type but no effects — e.g. raw potato, a cooking
            // ingredient that can't be eaten as-is.
            if item.effects.isEmpty {
                let itemName = context.lingo.localize(item.nameKey, locale: locale)
                let text = context.lingo.localize("consume.not_raw_edible", locale: locale, interpolations: ["name": itemName])
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: true))
                return true
            }

            guard try await InventoryEntry.has(itemId, user: context.session, on: context.db) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            guard let result = VigorService.consume(item, user: context.session) else {
                let text = context.lingo.localize("consume.no_effect", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: true))
                return true
            }
            try await InventoryEntry.remove(itemId, quantity: 1, from: context.session, on: context.db)
            try await context.session.saveAndCache(in: context.db)

            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            // Build the inline status line shown atop the refreshed view.
            // Each restored stat shows the new (current/max) total in parens
            // so the player sees both the gain and the pool state at a glance.
            let itemName = context.lingo.localize(item.nameKey, locale: locale)
            var parts: [String] = []
            if result.vigorRestored > 0 {
                parts.append(context.lingo.localize("vigor.restored", locale: locale, interpolations: [
                    "amount":  "\(result.vigorRestored)",
                    "current": "\(context.session.vigor)",
                    "max":     "\(context.session.maxVigor)"
                ]))
            }
            if result.hpRestored > 0 {
                parts.append(context.lingo.localize("hp.restored", locale: locale, interpolations: [
                    "amount":  "\(result.hpRestored)",
                    "current": "\(context.session.hp)",
                    "max":     "\(context.session.maxHp)"
                ]))
            }
            let statusLine = "✅ \(itemName) — " + parts.joined(separator: ", ")

            // Refresh: stay in category if items remain, else pop back to root.
            let entries = try await InventoryEntry.list(for: context.session, on: context.db)
            let stillInCategory = entries.contains { ItemCatalog.find($0.itemId)?.type == item.type }
            let refreshedBody: String
            let refreshedInline: TGInlineKeyboardMarkup
            if stillInCategory {
                refreshedBody = ctrl.renderCategory(type: item.type, lingo: context.lingo, locale: locale)
                refreshedInline = ctrl.categoryKeyboard(type: item.type, entries: entries, lingo: context.lingo, locale: locale)
            } else {
                refreshedBody = ctrl.renderRoot(entries: entries, session: context.session, lingo: context.lingo, locale: locale)
                refreshedInline = ctrl.rootKeyboard(entries: entries, lingo: context.lingo, locale: locale)
            }
            let editParams = TGEditMessageTextParams(
                chatId: .chat(message.chat.id),
                messageId: message.messageId,
                text: refreshedBody,
                parseMode: .html,
                replyMarkup: refreshedInline
            )
            _ = try? await context.bot.editMessageText(params: editParams)
            await ctrl.postStatusBanner(statusLine, context: context)
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

            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            let itemName = context.lingo.localize(item.nameKey, locale: locale)
            let statusLine = "✅ " + context.lingo.localize("equip.success", locale: locale, interpolations: ["item": itemName])
            try await refreshCategory(type: .gear, chatId: .chat(message.chat.id), messageId: message.messageId, context: context, statusLine: statusLine)
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

            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            let itemName = context.lingo.localize(item.nameKey, locale: locale)
            let statusLine = "✅ " + context.lingo.localize("unequip.success", locale: locale, interpolations: ["item": itemName])
            try await refreshCategory(type: .gear, chatId: .chat(message.chat.id), messageId: message.messageId, context: context, statusLine: statusLine)
            return true
        }

        return false
    }

    /// Handle a tap on `📖 Learn` for a recipe-scroll artifact (Phase 5.2.1).
    /// On a fresh learn the scroll row is deleted and the Artifacts category
    /// is refreshed in place with a `✅ Learned: <recipe>` status line. If the
    /// player already knows the recipe, the scroll is left in the bag and a
    /// modal alert explains why nothing happened.
    private static func handleLearnRecipe(
        itemId: String,
        recipeId: String,
        item: Item,
        query: TGCallbackQuery,
        message: TGMaybeInaccessibleMessage,
        context: Context
    ) async throws -> Bool {
        let locale = context.session.locale

        // Already known → modal, leave scroll in inventory.
        if try await LearnedRecipe.has(recipeId, for: context.session, on: context.db) {
            let toast = context.lingo.localize("learn.already_known", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        }

        // Find the scroll row (non-stackable, so any matching row is fine).
        guard let userId = context.session.id else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }
        let rows = try await InventoryEntry.query(on: context.db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$itemId, .equal, itemId)
            .all()
        guard let scrollRow = rows.first else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        // Add to learned set, then delete the scroll.
        _ = try await LearnedRecipe.add(recipeId, for: context.session, on: context.db)
        try await scrollRow.delete(on: context.db)

        // Build the inline status banner — show the **recipe output's**
        // name so the player sees what they just unlocked, not the scroll's
        // name (which is just "Recipe: X" anyway). Falls back to the scroll's
        // name if the recipe lookup somehow misses.
        let recipeName: String
        if let recipe = RecipeCatalog.find(recipeId),
           let outputItem = ItemCatalog.find(recipe.output.itemId) {
            recipeName = context.lingo.localize(outputItem.nameKey, locale: locale)
        } else {
            recipeName = context.lingo.localize(item.nameKey, locale: locale)
        }
        let outputIcon = RecipeCatalog.find(recipeId).flatMap { ItemCatalog.find($0.output.itemId)?.icon } ?? ""
        let statusLine = "✅ " + context.lingo.localize("learn.success", locale: locale, interpolations: [
            "icon": outputIcon,
            "name": recipeName
        ])

        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

        // Refresh: stay in Artifacts if any rows remain, else pop to root.
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)
        let stillInCategory = entries.contains { ItemCatalog.find($0.itemId)?.type == .artifact }
        let ctrl = Controllers.inventoryController
        if stillInCategory {
            try await refreshCategory(type: .artifact, chatId: .chat(message.chat.id), messageId: message.messageId, context: context, statusLine: statusLine)
        } else {
            let body = ctrl.renderRoot(entries: entries, session: context.session, lingo: context.lingo, locale: locale)
            let inline = ctrl.rootKeyboard(entries: entries, lingo: context.lingo, locale: locale)
            let params = TGEditMessageTextParams(
                chatId: .chat(message.chat.id),
                messageId: message.messageId,
                text: body,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: params)
            await ctrl.postStatusBanner(statusLine, context: context)
        }
        return true
    }

    /// Re-render the given category view in place after an equip/unequip.
    /// `statusLine` is published as a separate banner under the inline
    /// keyboard rather than embedded in the body — see `postStatusBanner`.
    private static func refreshCategory(type: ItemType, chatId: TGChatId, messageId: Int, context: Context, statusLine: String? = nil) async throws {
        let ctrl = Controllers.inventoryController
        let entries = try await InventoryEntry.list(for: context.session, on: context.db)
        let body = ctrl.renderCategory(type: type, lingo: context.lingo, locale: context.session.locale)
        let inline = ctrl.categoryKeyboard(type: type, entries: entries, lingo: context.lingo, locale: context.session.locale)
        let params = TGEditMessageTextParams(
            chatId: chatId,
            messageId: messageId,
            text: body,
            parseMode: .html,
            replyMarkup: inline
        )
        _ = try? await context.bot.editMessageText(params: params)
        if let statusLine {
            await ctrl.postStatusBanner(statusLine, context: context)
        }
    }
}
