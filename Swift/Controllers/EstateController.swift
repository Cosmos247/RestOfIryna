//
//  EstateController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//
//  Estate screen — tree navigation over the manor and the plot of land.
//
//  Layout:
//    Root          — header (estate name + level) + description + artwork placeholder,
//                    two inline buttons: [🏠 House] [🌾 Plot].
//    House         — three inline buttons: [🛠 Workshop] [🍳 Kitchen] [📦 Warehouse],
//                    plus a back button to Root.
//    Workshop/Kitchen/Warehouse/Plot — stubs (coming-soon) with a back button.
//
//  Per-level artwork (Assets/estate/level_<N>.jpg) is optional for now — the code
//  tries to load it but falls back to a text-only message when missing. The user
//  will drop files in as they're drawn.
//

import Foundation
import Fluent
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Estate Controller Logic
final class EstateController: TGControllerBase, @unchecked Sendable {
    typealias T = EstateController

    // MARK: - Controller Lifecycle
    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart

            let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
            for button in cancelLocales { router[button.text] = onCancel }

            // Main-nav pass-through — the main reply keyboard stays visible while the
            // player is in Estate, so presses must continue to navigate correctly.
            let exploreLocales = Commands.explore.buttonsForAllLocales(lingo: lingo)
            for button in exploreLocales { router[button.text] = onExplore }

            let capitalLocales = Commands.capital.buttonsForAllLocales(lingo: lingo)
            for button in capitalLocales { router[button.text] = onCapital }

            let profileLocales = Commands.profile.buttonsForAllLocales(lingo: lingo)
            for button in profileLocales { router[button.text] = onProfile }

            let settingsLocales = Commands.settings.buttonsForAllLocales(lingo: lingo)
            for button in settingsLocales { router[button.text] = onSettings }

            let inventoryLocales = Commands.inventory.buttonsForAllLocales(lingo: lingo)
            for button in inventoryLocales { router[button.text] = onInventory }

            let estateLocales = Commands.estate.buttonsForAllLocales(lingo: lingo)
            for button in estateLocales { router[button.text] = onRefresh }

            router.unmatched = unmatched
            router[.callback_query(data: nil)] = EstateController.onCallbackQuery
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
        try await showEstate(context: context)
        return true
    }

    // MARK: - Main-nav pass-through

    private func onExplore(context: Context) async throws -> Bool {
        let ctrl = Controllers.explorationController
        try await ctrl.showExploration(context: context)
        return true
    }

    private func onCapital(context: Context) async throws -> Bool {
        try await Controllers.capitalController.showStub(context: context)
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

    private func onInventory(context: Context) async throws -> Bool {
        let ctrl = Controllers.inventoryController
        try await ctrl.showInventory(context: context)
        context.session.routerName = ctrl.routerName
        try await context.session.saveAndCache(in: context.db)
        return true
    }

    private func onRefresh(context: Context) async throws -> Bool {
        try await showEstate(context: context)
        return true
    }

    // MARK: - Public entry

    public func showEstate(context: Context) async throws {
        // Guard: estate is inaccessible while the governor is in the field.
        // Same rule for active and passive — if an ExplorationState row
        // exists, the manor is locked until the expedition ends.
        if try await ExplorationState.current(for: context.session, on: context.db) != nil {
            let notice = context.lingo.localize("estate.blocked_by_expedition", locale: context.session.locale)
            try await context.bot.sendMessage(
                session: context.session,
                text: notice,
                parseMode: .html,
                replyMarkup: nil
            )
            return
        }

        // Entering estate — own the routerName transition so callers don't
        // have to (and can't mis-transition when we bail out above).
        context.session.routerName = routerName
        try await context.session.saveAndCache(in: context.db)

        let text = renderRoot(session: context.session, lingo: context.lingo)
        let inline = rootKeyboard(estateLevel: context.session.estateLevel, lingo: context.lingo, locale: context.session.locale)

        // Try to attach per-level artwork. Optional for now — user will add JPEGs later.
        let level = context.session.estateLevel
        let imageURL = URL(fileURLWithPath: "\(projectPath)/Assets/estate/level_\(level).jpg")
        if let imageData = try? Data(contentsOf: imageURL) {
            let inputFile = TGInputFile(filename: "level_\(level).jpg", data: imageData, mimeType: "image/jpeg")
            let params = TGSendPhotoParams(
                chatId: .chat(context.session.telegramId),
                photo: .file(inputFile),
                caption: text,
                parseMode: .html,
                replyMarkup: .inlineKeyboardMarkup(inline)
            )
            _ = try await context.bot.sendPhoto(params: params)
        } else {
            try await context.bot.sendMessage(
                session: context.session,
                text: text,
                parseMode: .html,
                replyMarkup: .inlineKeyboardMarkup(inline)
            )
        }
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        // Reuse main's reply keyboard so `/buttons` restores nav while in estate.
        return Controllers.mainController.generateControllerKB(session: session, lingo: lingo)
    }

    // MARK: - View rendering

    fileprivate func renderRoot(session: User, lingo: Lingo) -> String {
        let locale = session.locale
        let title = lingo.localize("estate.title", locale: locale)
        let estateName = session.estateName ?? "?"
        let level = session.estateLevel
        let levelLabel = lingo.localize("estate.level_label", locale: locale)
        let description = lingo.localize("estate.description", locale: locale)
        return "🏰 <b>\(title) «\(estateName)»</b>\n\(levelLabel): <b>\(level)</b>\n\n\(description)"
    }

    fileprivate func rootKeyboard(estateLevel: Int, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let home = lingo.localize("estate.home", locale: locale)
        let plot = lingo.localize("estate.plot", locale: locale)
        var rows: [[TGInlineKeyboardButton]] = [[
            TGInlineKeyboardButton(text: home, callbackData: "estate:home"),
            TGInlineKeyboardButton(text: plot, callbackData: "estate:plot")
        ]]
        // Phase 5.3c — upgrade button on top, hidden once the estate hits the
        // catalog's max tier. Player still has to pay materials + meet the
        // player-level gate (`EstateUpgradeService` validates both).
        if EstateUpgradeCatalog.canUpgrade(from: estateLevel) {
            let upgrade = lingo.localize("estate.upgrade.button", locale: locale)
            rows.insert([TGInlineKeyboardButton(text: upgrade, callbackData: "estate:upgrade:detail")], at: 0)
        }
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    // MARK: - Estate upgrade views (Phase 5.3c)

    /// Detail screen body for the `[🏠 Upgrade estate]` button. Shows the
    /// current tier name (or "fully upgraded" if at cap), then the next-tier
    /// preview block: tier name, player-level requirement, and a `📜 Materials`
    /// list with per-input have/need indicators pulled from the combined
    /// inventory + warehouse pool.
    fileprivate func renderEstateUpgrade(
        session: User,
        invSnapshot: [String: Int],
        whSnapshot: [String: Int],
        lingo: Lingo,
        locale: String
    ) -> String {
        let title = lingo.localize("estate.upgrade.title", locale: locale)
        let currentTier = session.estateLevel
        let currentName = lingo.localize("estate.tier.\(currentTier).name", locale: locale)
        let currentHeader = lingo.localize("estate.upgrade.current_header", locale: locale, interpolations: [
            "tier": "\(currentTier)",
            "name": currentName
        ])

        var lines: [String] = ["<b>\(title)</b>", "", currentHeader]

        guard let nextStep = EstateUpgradeCatalog.nextStep(from: currentTier) else {
            lines.append("")
            lines.append(lingo.localize("estate.upgrade.max_tier", locale: locale))
            return lines.joined(separator: "\n")
        }

        // Next-tier preview.
        let nextName = lingo.localize("estate.tier.\(nextStep.toTier).name", locale: locale)
        let arrow = lingo.localize("weapon.upgrade.delta_arrow", locale: locale)
        lines.append("")
        lines.append("\(arrow) " + lingo.localize("estate.upgrade.next_header", locale: locale, interpolations: [
            "tier": "\(nextStep.toTier)",
            "name": nextName
        ]))

        // Player-level requirement.
        let levelOK = session.level >= nextStep.requiredPlayerLevel
        let levelMark = levelOK ? "✅" : "⛔"
        lines.append("")
        lines.append("\(levelMark) " + lingo.localize("estate.upgrade.level_required", locale: locale, interpolations: [
            "required": "\(nextStep.requiredPlayerLevel)",
            "current":  "\(session.level)"
        ]))

        // Materials list.
        lines.append("")
        lines.append("<b>" + lingo.localize("estate.upgrade.recipe_header", locale: locale) + "</b>")
        for input in nextStep.inputs {
            let inputItem = ItemCatalog.find(input.itemId)
            let inputIcon = inputItem?.icon ?? ""
            let inputName = inputItem.map { lingo.localize($0.nameKey, locale: locale) } ?? input.itemId
            let have = (invSnapshot[input.itemId, default: 0]) + (whSnapshot[input.itemId, default: 0])
            lines.append("   \(input.quantity)× \(inputIcon) \(inputName)  (\(have)/\(input.quantity))")
        }

        // Phase 5.3c — gold cost line. Hidden when the step is gold-free
        // (early transitions). Drawn outside the materials block so the
        // player sees the wallet check as a separate gate.
        if nextStep.goldCost > 0 {
            let goldOK = session.gold >= nextStep.goldCost
            let goldMark = goldOK ? "✅" : "⛔"
            lines.append("")
            lines.append("\(goldMark) " + lingo.localize("estate.upgrade.gold_required", locale: locale, interpolations: [
                "required": "\(nextStep.goldCost)",
                "have":     "\(session.gold)"
            ]))
        }

        return lines.joined(separator: "\n")
    }

    /// Detail-screen keyboard. At max tier, only Back. Otherwise [🏠 Upgrade]
    /// + Back. Upgrade button is always shown — the handler validates player
    /// level + materials and surfaces a modal alert on failure, so the player
    /// reads exactly what's missing instead of guessing why the button is grey.
    fileprivate func estateUpgradeKeyboard(canUpgrade: Bool, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var rows: [[TGInlineKeyboardButton]] = []
        if canUpgrade {
            let upgrade = lingo.localize("estate.upgrade.button.confirm", locale: locale)
            rows.append([TGInlineKeyboardButton(text: upgrade, callbackData: "estate:upgrade:confirm")])
        }
        let back = lingo.localize("estate.back_root", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "estate:root")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    fileprivate func renderHome(lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("estate.home", locale: locale)
        let description = lingo.localize("estate.home.description", locale: locale)
        return "<b>\(title)</b>\n\n\(description)"
    }

    /// Phase 5.3c — gate House rooms by estate tier. T1 shows only Warehouse
    /// (the starter "shed" inside the wooden hut); Kitchen unlocks at T2, the
    /// Workshop at T3. Locked buttons are simply absent — the callback
    /// handlers also defend with a modal alert if a stale callback fires
    /// (e.g. the player tapped a button rendered before they regressed).
    fileprivate func homeKeyboard(estateLevel: Int, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let workshop = lingo.localize("estate.workshop", locale: locale)
        let kitchen = lingo.localize("estate.kitchen", locale: locale)
        let warehouse = lingo.localize("estate.warehouse", locale: locale)
        let back = lingo.localize("estate.back_root", locale: locale)
        var rows: [[TGInlineKeyboardButton]] = []
        if estateLevel >= 3 {
            rows.append([TGInlineKeyboardButton(text: workshop, callbackData: "estate:home:workshop")])
        }
        if estateLevel >= 2 {
            rows.append([TGInlineKeyboardButton(text: kitchen, callbackData: "estate:home:kitchen")])
        }
        rows.append([TGInlineKeyboardButton(text: warehouse, callbackData: "estate:home:warehouse")])
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "estate:root")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    /// Generic stub renderer for a not-yet-implemented location inside the estate.
    fileprivate func renderStub(titleKey: String, lingo: Lingo, locale: String) -> String {
        let title = lingo.localize(titleKey, locale: locale)
        let msg = lingo.localize("stub.coming_soon", locale: locale)
        return "<b>\(title)</b>\n\n\(msg)"
    }

    // MARK: - Warehouse views

    fileprivate func renderWarehouseRoot(slotsUsed: Int, slotsCap: Int, lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("estate.warehouse", locale: locale)
        let description = lingo.localize("estate.warehouse.description", locale: locale)
        // Phase 5.3c — show capacity. Cap grows with estate tier; existing
        // over-cap warehouses still render the actual count even past the
        // limit so the player sees the full picture.
        let capLine = lingo.localize("estate.warehouse.capacity", locale: locale, interpolations: [
            "used": "\(slotsUsed)",
            "cap": "\(slotsCap)"
        ])
        return "<b>\(title)</b>\n\n\(description)\n\n\(capLine)"
    }

    /// Category grid mirroring the inventory's root layout — all five ItemType
    /// categories, each a button with a live count of what's in the warehouse.
    fileprivate func warehouseRootKeyboard(entries: [WarehouseEntry], lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var countsByType: [ItemType: Int] = [:]
        for entry in entries {
            guard let item = ItemCatalog.find(entry.itemId) else { continue }
            countsByType[item.type, default: 0] += entry.quantity
        }

        let typeOrder: [ItemType] = [.food, .material, .potion, .gear, .artifact]
        var rows: [[TGInlineKeyboardButton]] = []
        var currentRow: [TGInlineKeyboardButton] = []

        for type in typeOrder {
            let count = countsByType[type, default: 0]
            let name = lingo.localize("inventory.type.\(type.rawValue)", locale: locale)
            let label = "\(type.icon) \(name) (\(count))"
            currentRow.append(TGInlineKeyboardButton(text: label, callbackData: "estate:wh:\(type.rawValue)"))
            if currentRow.count == 2 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        let backToHouse = lingo.localize("estate.back_home", locale: locale)
        rows.append([TGInlineKeyboardButton(text: backToHouse, callbackData: "estate:home")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    /// Category drill-down: text header only. The real content lives in the inline
    /// keyboard. Empty-state check is type-aware because gear uses per-row display
    /// while other types use aggregate rows.
    fileprivate func renderWarehouseCategory(type: ItemType, invEntries: [InventoryEntry], whEntries: [WarehouseEntry], lingo: Lingo, locale: String) -> String {
        let warehouse = lingo.localize("estate.warehouse", locale: locale)
        let category = lingo.localize("inventory.type.\(type.rawValue)", locale: locale)
        let header = "<b>\(warehouse) / \(type.icon) \(category)</b>"

        let empty: Bool
        if type == .gear {
            let invHasGear = invEntries.contains {
                ItemCatalog.find($0.itemId)?.type == .gear && $0.equippedSlot == nil
            }
            let whHasGear = whEntries.contains {
                ItemCatalog.find($0.itemId)?.type == .gear
            }
            empty = !(invHasGear || whHasGear)
        } else {
            empty = EstateController.warehouseCategoryRows(type: type, inventory: invEntries, warehouse: whEntries).isEmpty
        }

        if empty {
            let emptyText = lingo.localize("estate.warehouse.empty", locale: locale)
            return "\(header)\n\n\(emptyText)"
        }
        return header
    }

    /// Gear (non-stackable): one button row per physical unit, single-direction action.
    /// Everything else (stackable): one aggregated row per item_id with bidirectional
    /// `🎒 N ⬆️` / `📦 M ⬇️` buttons.
    fileprivate func warehouseCategoryKeyboard(type: ItemType, invEntries: [InventoryEntry], whEntries: [WarehouseEntry], lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var keyboard: [[TGInlineKeyboardButton]] = []

        if type == .gear {
            let invGear: [(entry: InventoryEntry, item: Item)] = invEntries.compactMap { entry in
                guard let item = ItemCatalog.find(entry.itemId), item.type == .gear else { return nil }
                guard entry.equippedSlot == nil else { return nil }
                return (entry, item)
            }.sorted { $0.item.id < $1.item.id }

            let whGear: [(entry: WarehouseEntry, item: Item)] = whEntries.compactMap { entry in
                guard let item = ItemCatalog.find(entry.itemId), item.type == .gear else { return nil }
                return (entry, item)
            }.sorted { $0.item.id < $1.item.id }

            for pair in invGear {
                let name = lingo.localize(pair.item.nameKey, locale: locale)
                let iconPrefix = pair.item.icon.map { "\($0) " } ?? ""
                keyboard.append([
                    TGInlineKeyboardButton(text: "\(iconPrefix)\(name)", callbackData: "estate:wh:info:\(pair.item.id)"),
                    TGInlineKeyboardButton(text: "🎒 ⬆️", callbackData: "estate:wh:deposit:\(pair.item.id)")
                ])
            }
            for pair in whGear {
                let name = lingo.localize(pair.item.nameKey, locale: locale)
                let iconPrefix = pair.item.icon.map { "\($0) " } ?? ""
                keyboard.append([
                    TGInlineKeyboardButton(text: "\(iconPrefix)\(name)", callbackData: "estate:wh:info:\(pair.item.id)"),
                    TGInlineKeyboardButton(text: "📦 ⬇️", callbackData: "estate:wh:withdraw:\(pair.item.id)")
                ])
            }
        } else {
            let rows = EstateController.warehouseCategoryRows(type: type, inventory: invEntries, warehouse: whEntries)
            for row in rows {
                let name = lingo.localize(row.item.nameKey, locale: locale)
                let iconPrefix = row.item.icon.map { "\($0) " } ?? ""
                keyboard.append([
                    TGInlineKeyboardButton(text: "\(iconPrefix)\(name)", callbackData: "estate:wh:info:\(row.item.id)"),
                    TGInlineKeyboardButton(text: "🎒 \(row.inventoryCount) ⬆️", callbackData: "estate:wh:deposit:\(row.item.id)"),
                    TGInlineKeyboardButton(text: "📦 \(row.warehouseCount) ⬇️", callbackData: "estate:wh:withdraw:\(row.item.id)")
                ])
            }
        }

        // Bulk action: deposit every unequipped unit of this category in one tap.
        // Equipped gear is filtered out by the service. Sits below all per-item
        // rows so it doesn't push individual transfers off the screen.
        let depositAllLabel = lingo.localize("estate.warehouse.button.deposit_all", locale: locale)
        keyboard.append([TGInlineKeyboardButton(text: depositAllLabel, callbackData: "estate:wh:depositall:\(type.rawValue)")])

        let back = lingo.localize("estate.back_root", locale: locale)
        keyboard.append([TGInlineKeyboardButton(text: back, callbackData: "estate:home:warehouse")])
        return TGInlineKeyboardMarkup(inlineKeyboard: keyboard)
    }

    /// Combine backpack + warehouse rows into a per-item-id summary. Only the
    /// requested `type` is kept. Inventory count excludes equipped rows because
    /// they can't be deposited. Items with zero on both sides are dropped.
    fileprivate static func warehouseCategoryRows(
        type: ItemType,
        inventory: [InventoryEntry],
        warehouse: [WarehouseEntry]
    ) -> [WarehouseCategoryRow] {
        var invCounts: [String: Int] = [:]
        var whCounts: [String: Int] = [:]
        var items: [String: Item] = [:]

        for row in inventory {
            guard let item = ItemCatalog.find(row.itemId), item.type == type else { continue }
            guard row.equippedSlot == nil else { continue }
            invCounts[item.id, default: 0] += row.quantity
            items[item.id] = item
        }
        for row in warehouse {
            guard let item = ItemCatalog.find(row.itemId), item.type == type else { continue }
            whCounts[item.id, default: 0] += row.quantity
            items[item.id] = item
        }

        let ids = Set(invCounts.keys).union(whCounts.keys)
        return ids.sorted().compactMap { id in
            guard let item = items[id] else { return nil }
            return WarehouseCategoryRow(
                item: item,
                inventoryCount: invCounts[id, default: 0],
                warehouseCount: whCounts[id, default: 0]
            )
        }
    }

    fileprivate func backToRootKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let back = lingo.localize("estate.back_root", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: back, callbackData: "estate:root")
        ]])
    }

    // MARK: - Plot drill-down (Phase 5.1)

    /// Body of the plot drill-down — header + one line per slot. Each
    /// claimed slot shows its current accumulation; empty slots are tagged.
    /// Keyboard `plotListKeyboard` carries the action buttons. Internal
    /// (not fileprivate) so CombatController's training-exit can refresh
    /// the same view after a Back tap.
    func renderPlotList(plots: [Plot], session: User, lingo: Lingo, locale: String) -> String {
        let slotsAllowance = PlotService.slotsForLevel(session.estateLevel)
        let title = lingo.localize("estate.plot.list.title", locale: locale)
        let header = lingo.localize("estate.plot.list.header", locale: locale, interpolations: [
            "claimed":   "\(plots.count)",
            "allowance": "\(slotsAllowance)"
        ])
        var lines: [String] = ["🌾 <b>\(title)</b>", header, ""]
        let plotsBySlot = Dictionary(uniqueKeysWithValues: plots.map { ($0.slotIndex, $0) })
        for slot in 0..<slotsAllowance {
            if let plot = plotsBySlot[slot], let type = PlotType(rawValue: plot.plotType) {
                let icon = PlotCatalog.icon(for: type)
                let typeName = lingo.localize(PlotCatalog.nameKey(for: type), locale: locale)
                if let tuning = PlotCatalog.tuning(for: type, tier: plot.tier) {
                    // Production plot — show accumulated count and ready-mark.
                    let amount = PlotService.accumulated(for: plot)
                    let itemIcon = ItemCatalog.find(tuning.producedItemId)?.icon ?? ""
                    let readyMark = amount >= tuning.capacity ? lingo.localize("estate.plot.ready_mark", locale: locale) : ""
                    // Bonus output (e.g. Mine → iron) shown right after the
                    // primary count: " · <b>3/5</b> 🔩". Empty for plots
                    // with no `bonusOutput` so the row stays clean.
                    var bonusSegment = ""
                    if let bonus = tuning.bonusOutput {
                        let bonusAmount = PlotService.bonusAccumulated(for: plot)
                        let bonusIcon = ItemCatalog.find(bonus.producedItemId)?.icon ?? ""
                        bonusSegment = " · <b>\(bonusAmount)/\(bonus.capacity)</b> \(bonusIcon)"
                    }
                    lines.append(lingo.localize("estate.plot.row.claimed", locale: locale, interpolations: [
                        "icon":  icon,
                        "slot":  "\(slot + 1)",
                        "type":  typeName,
                        "amount": "\(amount)",
                        "cap":   "\(tuning.capacity)",
                        "item":  itemIcon,
                        "bonus": bonusSegment,
                        "ready": readyMark
                    ]))
                } else {
                    // Non-producing plot (Training Ground et al.) — flat row.
                    lines.append(lingo.localize("estate.plot.row.training", locale: locale, interpolations: [
                        "icon": icon,
                        "slot": "\(slot + 1)",
                        "type": typeName
                    ]))
                }
            } else {
                lines.append(lingo.localize("estate.plot.row.empty", locale: locale, interpolations: [
                    "slot": "\(slot + 1)"
                ]))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Keyboard for the plot list: one button per slot (Harvest for claimed,
    /// Claim for empty), paired in rows of 2 to keep the keyboard compact,
    /// plus a Back row at the bottom. Internal so CombatController's
    /// training-exit can rebuild the keyboard.
    func plotListKeyboard(plots: [Plot], session: User, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let slotsAllowance = PlotService.slotsForLevel(session.estateLevel)
        let plotsBySlot = Dictionary(uniqueKeysWithValues: plots.map { ($0.slotIndex, $0) })
        var buttons: [TGInlineKeyboardButton] = []
        for slot in 0..<slotsAllowance {
            if let plot = plotsBySlot[slot], let type = PlotType(rawValue: plot.plotType) {
                if PlotCatalog.tuning(for: type) == nil {
                    // Training plot — leads to combat instead of harvest.
                    let label = "🥋 " + lingo.localize("estate.plot.button.train", locale: locale, interpolations: ["slot": "\(slot + 1)"])
                    buttons.append(TGInlineKeyboardButton(text: label, callbackData: "estate:plot:train:\(slot)"))
                } else {
                    // Production plot — harvest. Emoji prepended in Swift —
                    // Lingo's `%{var}` parser breaks on leading supplementary-
                    // plane emoji (🚜 is U+1F69C).
                    let label = "🚜 " + lingo.localize("estate.plot.button.harvest", locale: locale, interpolations: ["slot": "\(slot + 1)"])
                    buttons.append(TGInlineKeyboardButton(text: label, callbackData: "estate:plot:harvest:\(slot)"))
                }
            } else {
                let label = lingo.localize("estate.plot.button.claim", locale: locale, interpolations: ["slot": "\(slot + 1)"])
                buttons.append(TGInlineKeyboardButton(text: label, callbackData: "estate:plot:claim:\(slot)"))
            }
        }
        var rows: [[TGInlineKeyboardButton]] = stride(from: 0, to: buttons.count, by: 2).map {
            Array(buttons[$0..<min($0 + 2, buttons.count)])
        }
        let back = lingo.localize("estate.back_root", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "estate:root")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    /// Body of the plot-type picker shown after the player taps "Claim slot N".
    /// Phase 5.3c: Training Ground hidden until estate T3.
    fileprivate func renderPlotPicker(slot: Int, estateLevel: Int, lingo: Lingo, locale: String) -> String {
        let header = lingo.localize("estate.plot.picker.header", locale: locale, interpolations: [
            "slot": "\(slot + 1)"
        ])
        var lines: [String] = ["<b>\(header)</b>", ""]
        for type in PlotType.allCases {
            if type == .trainingGround, estateLevel < 3 { continue }
            let icon = PlotCatalog.icon(for: type)
            let typeName = lingo.localize(PlotCatalog.nameKey(for: type), locale: locale)
            if let tuning = PlotCatalog.tuning(for: type) {
                // Production plot — show item, rate, cap.
                let itemName = ItemCatalog.find(tuning.producedItemId).map { lingo.localize($0.nameKey, locale: locale) } ?? tuning.producedItemId
                let intervalLabel = lingo.localize(PlotCatalog.testMode ? "estate.plot.rate.per_minute" : "estate.plot.rate.per_hour", locale: locale)
                lines.append("\(icon) <b>\(typeName)</b> — \(itemName), \(tuning.ratePerInterval) \(intervalLabel), cap \(tuning.capacity)")
            } else {
                // Non-producing plot (Training Ground) — show its lore blurb.
                let desc = lingo.localize(PlotCatalog.descriptionKey(for: type), locale: locale)
                lines.append("\(icon) <b>\(typeName)</b> — \(desc)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Picker keyboard — one button per plot type + Back to plot list. Phase
    /// 5.3c: Training Ground hidden until estate T3.
    fileprivate func plotPickerKeyboard(slot: Int, estateLevel: Int, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var rows: [[TGInlineKeyboardButton]] = []
        var pair: [TGInlineKeyboardButton] = []
        for type in PlotType.allCases {
            if type == .trainingGround, estateLevel < 3 { continue }
            let icon = PlotCatalog.icon(for: type)
            let typeName = lingo.localize(PlotCatalog.nameKey(for: type), locale: locale)
            let label = "\(icon) \(typeName)"
            pair.append(TGInlineKeyboardButton(text: label, callbackData: "estate:plot:type:\(slot):\(type.rawValue)"))
            if pair.count == 2 {
                rows.append(pair)
                pair = []
            }
        }
        if !pair.isEmpty { rows.append(pair) }
        let back = lingo.localize("estate.plot.picker.back", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "estate:plot")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    fileprivate func backToHomeKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let back = lingo.localize("estate.back_home", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: back, callbackData: "estate:home")
        ]])
    }

    // MARK: - Workshop (Phase 5.2)

    /// Compact workshop list — title + atmospheric description. Recipes only
    /// appear as inline buttons; tapping one opens its detail screen
    /// (`craft:detail:<recipe.id>`). Buttons stay grouped by category through
    /// their declaration order in `RecipeCatalog.all`.
    fileprivate func renderWorkshop(lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("estate.workshop", locale: locale)
        let intro = lingo.localize("workshop.description", locale: locale)
        return "<b>\(title)</b>\n\(intro)"
    }

    /// Workshop keyboard — one `[<icon> <name>]` button per recipe (opens detail)
    /// + Back. Buttons are grouped visually by category via their declaration
    /// order in `RecipeCatalog.all`. Phase 5.3c: Tannery sub-category gated by
    /// estate tier (unlocks at T4). Kitchen recipes never appear here (they
    /// live in the Kitchen view, gated by the room's T2 unlock).
    fileprivate func workshopKeyboard(estateLevel: Int, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var rows: [[TGInlineKeyboardButton]] = []
        // Phase 5.2.2 weapon-upgrade entry. One universal button at the top —
        // the player has only one upgradable weapon (their class starter),
        // so the detail screen resolves it dynamically; no class-specific
        // labels needed here.
        let upgradeLabel = lingo.localize("weapon.upgrade.button", locale: locale)
        rows.append([TGInlineKeyboardButton(text: upgradeLabel, callbackData: "weapon:upgrade:detail")])

        for recipe in RecipeCatalog.all {
            // Kitchen recipes belong to the Kitchen view, not the Workshop.
            if recipe.category == .kitchen { continue }
            // Tannery unlocks at estate T4.
            if recipe.category == .tannery, estateLevel < 4 { continue }
            let outputItem = ItemCatalog.find(recipe.output.itemId)
            let outputIcon = outputItem?.icon ?? ""
            let outputName = outputItem.map { lingo.localize($0.nameKey, locale: locale) } ?? recipe.output.itemId
            let iconSegment = outputIcon.isEmpty ? "" : "\(outputIcon) "
            let label = "\(iconSegment)\(outputName)"
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "craft:detail:\(recipe.id)")])
        }
        let back = lingo.localize("estate.back_home", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "estate:home")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    /// Recipe detail body — output header, lore description (when set), recipe
    /// inputs, and stat bonuses (when the output is gear). Used both for the
    /// initial detail view and for the in-place refresh after a successful craft
    /// (the `✅ Crafted ...` banner is appended to the bottom by the caller so
    /// it's visible without scrolling past a tall recipe list).
    fileprivate func renderRecipeDetail(recipe: Recipe, lingo: Lingo, locale: String) -> String {
        let outputItem = ItemCatalog.find(recipe.output.itemId)
        let outputIcon = outputItem?.icon ?? ""
        let outputName = outputItem.map { lingo.localize($0.nameKey, locale: locale) } ?? recipe.output.itemId

        var lines: [String] = ["\(outputIcon) <b>\(outputName)</b>"]

        if let descKey = outputItem?.descriptionKey {
            let desc = lingo.localize(descKey, locale: locale)
            lines.append("")
            lines.append("<i>\(desc)</i>")
        }

        // Recipe section.
        lines.append("")
        lines.append("<b>" + lingo.localize("workshop.detail.recipe", locale: locale) + "</b>")
        for input in recipe.inputs {
            let item = ItemCatalog.find(input.itemId)
            let icon = item?.icon ?? ""
            let name = item.map { lingo.localize($0.nameKey, locale: locale) } ?? input.itemId
            lines.append("   \(input.quantity)× \(icon) \(name)")
        }

        // Stats section — gear (gearStats). Mutually exclusive with effects
        // in v1 (no current item is both equippable and consumable).
        if let stats = outputItem?.gearStats {
            var statLines: [String] = []
            if stats.attack != 0 {
                statLines.append("   +\(stats.attack) ⚔️ \(lingo.localize("workshop.stats.attack", locale: locale))")
            }
            if stats.defense != 0 {
                statLines.append("   +\(stats.defense) 🛡 \(lingo.localize("workshop.stats.defense", locale: locale))")
            }
            if stats.crit != 0 {
                statLines.append("   +\(stats.crit)% 💥 \(lingo.localize("workshop.stats.crit", locale: locale))")
            }
            if stats.dodge != 0 {
                statLines.append("   +\(stats.dodge) 💨 \(lingo.localize("workshop.stats.dodge", locale: locale))")
            }
            if stats.accuracy != 0 {
                statLines.append("   +\(stats.accuracy) 🎯 \(lingo.localize("workshop.stats.accuracy", locale: locale))")
            }
            if !statLines.isEmpty {
                lines.append("")
                lines.append("<b>" + lingo.localize("workshop.detail.stats", locale: locale) + "</b>")
                lines.append(contentsOf: statLines)
            }
        }

        // Effects section — consumables (food/potion). Each `ItemEffect` is
        // rendered as a single line with a per-effect icon.
        if let effects = outputItem?.effects, !effects.isEmpty {
            var effectLines: [String] = []
            for effect in effects {
                switch effect {
                case .restoreVigor(let n):
                    effectLines.append("   +\(n) 🍖 \(lingo.localize("workshop.effect.vigor", locale: locale))")
                case .restoreHP(let n):
                    effectLines.append("   +\(n) ❤️ \(lingo.localize("workshop.effect.hp", locale: locale))")
                }
            }
            if !effectLines.isEmpty {
                lines.append("")
                lines.append("<b>" + lingo.localize("workshop.detail.effects", locale: locale) + "</b>")
                lines.append(contentsOf: effectLines)
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Detail-screen keyboard — primary action (Craft / Cook) + Back-to-room.
    /// Action verb and back target both come from `recipe.category` so the
    /// same keyboard works for Workshop and Kitchen.
    fileprivate func recipeDetailKeyboard(recipe: Recipe, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let action = lingo.localize(recipe.category.actionButtonKey, locale: locale)
        let back = lingo.localize("workshop.detail.button.back", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: action, callbackData: "craft:\(recipe.id)")],
            [TGInlineKeyboardButton(text: back,   callbackData: recipe.category.backCallbackData)]
        ])
    }

    // MARK: - Kitchen (Phase 5.2.1)

    /// Compact kitchen list — title + atmospheric description. Recipes appear
    /// only as inline buttons via `kitchenKeyboard`. If the player has not
    /// learned any kitchen recipes yet, the empty-state hint is shown
    /// instead so the room never looks broken.
    fileprivate func renderKitchen(learnedKitchenCount: Int, lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("estate.kitchen", locale: locale)
        let intro = lingo.localize("kitchen.description", locale: locale)
        var body = "<b>\(title)</b>\n\(intro)"
        if learnedKitchenCount == 0 {
            body += "\n\n" + lingo.localize("kitchen.empty", locale: locale)
        }
        return body
    }

    /// Kitchen keyboard — one `[<icon> <name>]` button per **learned** kitchen
    /// recipe + Back. Empty list (no learned kitchen recipes) just shows the
    /// Back button.
    fileprivate func kitchenKeyboard(learnedRecipeIds: Set<String>, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var rows: [[TGInlineKeyboardButton]] = []
        for recipe in RecipeCatalog.recipes(in: .kitchen) where learnedRecipeIds.contains(recipe.id) {
            let outputItem = ItemCatalog.find(recipe.output.itemId)
            let outputIcon = outputItem?.icon ?? ""
            let outputName = outputItem.map { lingo.localize($0.nameKey, locale: locale) } ?? recipe.output.itemId
            let iconSegment = outputIcon.isEmpty ? "" : "\(outputIcon) "
            let label = "\(iconSegment)\(outputName)"
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "craft:detail:\(recipe.id)")])
        }
        let back = lingo.localize("estate.back_home", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "estate:home")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }
}

/// Summary row for a single item in the warehouse category drill-down.
fileprivate struct WarehouseCategoryRow {
    let item: Item
    let inventoryCount: Int
    let warehouseCount: Int
}

// MARK: - Callback Queries

extension EstateController {
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data else { return false }
        // Phase 5.1: training mode keeps routerName at "estate" so the player
        // can navigate the main reply-keyboard while sparring with the dummy.
        // Combat inline-button callbacks need to forward to CombatController.
        if data.hasPrefix("combat:") {
            return try await CombatController.onCallbackQuery(context: context)
        }
        // Phase 5.2 Workshop crafting. Two callbacks live outside the `estate:`
        // namespace so they must be matched BEFORE the prefix guard below:
        //   craft:detail:<recipe.id>  — opens the recipe's detail screen
        //   craft:<recipe.id>         — performs the craft (issued from the
        //                               detail screen's [🔨 Craft] button)
        if data.hasPrefix("craft:detail:") {
            return try await handleCraftDetail(data: data, query: query, message: message, context: context)
        }
        if data.hasPrefix("craft:") {
            return try await handleCraft(data: data, query: query, message: message, context: context)
        }
        // Phase 5.2.2 weapon upgrade — also lives outside the `estate:` namespace.
        //   weapon:upgrade:detail   — open the upgrade detail screen for the
        //                             player's current weapon
        //   weapon:upgrade:confirm  — perform one upgrade step (issued by the
        //                             [🔨 Upgrade] button on the detail screen)
        if data == "weapon:upgrade:detail" {
            return try await handleWeaponUpgradeDetail(query: query, message: message, context: context)
        }
        if data == "weapon:upgrade:confirm" {
            return try await handleWeaponUpgradeConfirm(query: query, message: message, context: context)
        }
        // Phase 5.3c estate upgrade — own detail / confirm screens.
        if data == "estate:upgrade:detail" {
            return try await handleEstateUpgradeDetail(query: query, message: message, context: context)
        }
        if data == "estate:upgrade:confirm" {
            return try await handleEstateUpgradeConfirm(query: query, message: message, context: context)
        }
        guard data.hasPrefix("estate:") else { return false }

        let ctrl = Controllers.estateController
        let locale = context.session.locale

        let text: String
        let inline: TGInlineKeyboardMarkup

        // Warehouse item info — lore modal if the item has a description,
        // placeholder toast otherwise. Same convention as InventoryController.
        if data.hasPrefix("estate:wh:info:") {
            let itemId = String(data.dropFirst("estate:wh:info:".count))
            guard let item = ItemCatalog.find(itemId) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let answer: TGAnswerCallbackQueryParams
            if let descKey = item.descriptionKey {
                let description = context.lingo.localize(descKey, locale: locale)
                answer = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: description, showAlert: true)
            } else {
                let itemName = context.lingo.localize(item.nameKey, locale: locale)
                let toast = context.lingo.localize("inventory.info.placeholder", locale: locale, interpolations: ["name": itemName])
                answer = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true)
            }
            _ = try? await context.bot.answerCallbackQuery(params: answer)
            return true
        }

        // Bulk deposit — must be matched before the per-item `deposit:` /
        // `withdraw:` prefixes since "depositall" technically starts with
        // "deposit". Order keeps the routing unambiguous.
        if data.hasPrefix("estate:wh:depositall:") {
            return try await handleWarehouseDepositAll(data: data, query: query, message: message, context: context)
        }

        if data.hasPrefix("estate:wh:deposit:") || data.hasPrefix("estate:wh:withdraw:") {
            return try await handleWarehouseTransfer(data: data, query: query, message: message, context: context)
        }

        // Phase 5.1 plot actions: claim a slot, pick a type, or harvest. The
        // claim/type/harvest handlers do their own messaging (modal alerts on
        // failure, inline status banner on success) and return early.
        if data.hasPrefix("estate:plot:claim:") {
            return try await handlePlotClaimPicker(data: data, query: query, message: message, context: context)
        }
        if data.hasPrefix("estate:plot:type:") {
            return try await handlePlotTypeChosen(data: data, query: query, message: message, context: context)
        }
        if data.hasPrefix("estate:plot:harvest:") {
            return try await handlePlotHarvest(data: data, query: query, message: message, context: context)
        }
        if data.hasPrefix("estate:plot:train:") {
            return try await handlePlotTraining(data: data, query: query, message: message, context: context)
        }

        if data.hasPrefix("estate:wh:") {
            // Warehouse category drill-down (e.g. estate:wh:food).
            let typeRaw = String(data.dropFirst("estate:wh:".count))
            guard let type = ItemType(rawValue: typeRaw) else {
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
            let invEntries = try await InventoryEntry.list(for: context.session, on: context.db)
            let whEntries = try await WarehouseEntry.list(for: context.session, on: context.db)
            text = ctrl.renderWarehouseCategory(type: type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)
            inline = ctrl.warehouseCategoryKeyboard(type: type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)
        } else {
            switch data {
            case "estate:root":
                text = ctrl.renderRoot(session: context.session, lingo: context.lingo)
                inline = ctrl.rootKeyboard(estateLevel: context.session.estateLevel, lingo: context.lingo, locale: locale)
            case "estate:home":
                text = ctrl.renderHome(lingo: context.lingo, locale: locale)
                inline = ctrl.homeKeyboard(estateLevel: context.session.estateLevel, lingo: context.lingo, locale: locale)
            case "estate:home:workshop" where context.session.estateLevel < 3:
                // Stale callback: room not unlocked yet. Surface a clean alert
                // and leave the screen as-is.
                let alert = context.lingo.localize("estate.locked.room", locale: locale, interpolations: [
                    "tier": "3"
                ])
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                    callbackQueryId: query.id, text: alert, showAlert: true
                ))
                return true
            case "estate:home:kitchen" where context.session.estateLevel < 2:
                let alert = context.lingo.localize("estate.locked.room", locale: locale, interpolations: [
                    "tier": "2"
                ])
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                    callbackQueryId: query.id, text: alert, showAlert: true
                ))
                return true
            case "estate:plot":
                let plots = try await Plot.list(for: context.session, on: context.db)
                text = ctrl.renderPlotList(plots: plots, session: context.session, lingo: context.lingo, locale: locale)
                inline = ctrl.plotListKeyboard(plots: plots, session: context.session, lingo: context.lingo, locale: locale)
            case "estate:home:workshop":
                text = ctrl.renderWorkshop(lingo: context.lingo, locale: locale)
                inline = ctrl.workshopKeyboard(estateLevel: context.session.estateLevel, lingo: context.lingo, locale: locale)
            case "estate:home:kitchen":
                let learnedIds = try await LearnedRecipe.allIds(for: context.session, on: context.db)
                // Always-available starters union with player-learned recipes.
                let availableIds = learnedIds.union(RecipeCatalog.starterRecipeIds)
                let availableKitchen = RecipeCatalog.recipes(in: .kitchen).filter { availableIds.contains($0.id) }.count
                text = ctrl.renderKitchen(learnedKitchenCount: availableKitchen, lingo: context.lingo, locale: locale)
                inline = ctrl.kitchenKeyboard(learnedRecipeIds: availableIds, lingo: context.lingo, locale: locale)
            case "estate:home:warehouse":
                let entries = try await WarehouseEntry.list(for: context.session, on: context.db)
                let cap = WarehouseService.capForLevel(context.session.estateLevel)
                text = ctrl.renderWarehouseRoot(slotsUsed: entries.count, slotsCap: cap, lingo: context.lingo, locale: locale)
                inline = ctrl.warehouseRootKeyboard(entries: entries, lingo: context.lingo, locale: locale)
            default:
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
                return true
            }
        }

        // If the source message is a photo (level artwork at root), editing the text
        // field would fail — Telegram requires editing the caption instead. Keep both
        // branches so the controller stays correct once user drops in JPEGs.
        let chatId = TGChatId.chat(message.chat.id)
        let isPhoto = (message.getMessage()?.photo) != nil
        if isPhoto {
            let params = TGEditMessageCaptionParams(
                chatId: chatId,
                messageId: message.messageId,
                caption: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageCaption(params: params)
        } else {
            let params = TGEditMessageTextParams(
                chatId: chatId,
                messageId: message.messageId,
                text: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: params)
        }
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        return true
    }

    /// Perform one deposit/withdraw and refresh the current category drill-down
    /// in place. Callback data is either `estate:wh:deposit:<item_id>` or
    /// `estate:wh:withdraw:<item_id>`.
    static func handleWarehouseTransfer(
        data: String,
        query: TGCallbackQuery,
        message: TGMaybeInaccessibleMessage,
        context: Context
    ) async throws -> Bool {
        let locale = context.session.locale
        let isDeposit = data.hasPrefix("estate:wh:deposit:")
        let prefix = isDeposit ? "estate:wh:deposit:" : "estate:wh:withdraw:"
        let itemId = String(data.dropFirst(prefix.count))

        guard let item = ItemCatalog.find(itemId) else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        let itemName = context.lingo.localize(item.nameKey, locale: locale)
        // Classify the outcome: successes get an inline status line in the
        // refreshed view; failures (nothing to move, backpack full) get a
        // modal alert via showAlert: true so the player can't miss the
        // reason their tap did nothing.
        let toastKey: String
        let isSuccess: Bool
        if isDeposit {
            let result = try await WarehouseService.deposit(itemId: itemId, for: context.session, on: context.db)
            switch result {
            case .success:           toastKey = "estate.warehouse.deposited";          isSuccess = true
            case .nothingToDeposit:  toastKey = "estate.warehouse.nothing_to_deposit";  isSuccess = false
            case .notTransferable:   toastKey = "estate.warehouse.not_transferable";    isSuccess = false
            case .warehouseFull:     toastKey = "estate.warehouse.full";                isSuccess = false
            }
        } else {
            let result = try await WarehouseService.withdraw(itemId: itemId, for: context.session, on: context.db)
            switch result {
            case .success:           toastKey = "estate.warehouse.withdrawn";           isSuccess = true
            case .nothingToWithdraw: toastKey = "estate.warehouse.nothing_to_withdraw"; isSuccess = false
            case .inventoryFull:     toastKey = "inventory.full";                       isSuccess = false
            }
        }
        let toast = context.lingo.localize(toastKey, locale: locale, interpolations: ["item": itemName])

        if isSuccess {
            // Silent ack — the inline status line carries the message instead.
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        } else {
            // Modal alert for warnings — player taps OK to dismiss.
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
        }

        // Refresh the currently-open category in place. On success prepend
        // the status line; on failure leave the body unchanged (data didn't
        // move, the modal alert already explains why).
        let ctrl = Controllers.estateController
        let invEntries = try await InventoryEntry.list(for: context.session, on: context.db)
        let whEntries = try await WarehouseEntry.list(for: context.session, on: context.db)
        let body = ctrl.renderWarehouseCategory(type: item.type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)
        let text = isSuccess ? "✅ \(toast)\n\n\(body)" : body
        let inline = ctrl.warehouseCategoryKeyboard(type: item.type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)

        let chatId = TGChatId.chat(message.chat.id)
        if message.getMessage()?.photo != nil {
            let params = TGEditMessageCaptionParams(
                chatId: chatId,
                messageId: message.messageId,
                caption: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageCaption(params: params)
        } else {
            let params = TGEditMessageTextParams(
                chatId: chatId,
                messageId: message.messageId,
                text: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: params)
        }
        return true
    }

    /// `estate:wh:depositall:<type>` — bulk-deposit every unequipped row of the
    /// given category from the bag to the warehouse. On success refreshes the
    /// category view with an inline banner showing how many units moved; if
    /// nothing was movable (empty bag for that type, or only equipped gear),
    /// surfaces a modal alert and leaves the screen unchanged.
    static func handleWarehouseDepositAll(
        data: String,
        query: TGCallbackQuery,
        message: TGMaybeInaccessibleMessage,
        context: Context
    ) async throws -> Bool {
        let locale = context.session.locale
        let typeRaw = String(data.dropFirst("estate:wh:depositall:".count))
        guard let type = ItemType(rawValue: typeRaw) else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }

        let moved = try await WarehouseService.depositAll(category: type, for: context.session, on: context.db)

        if moved == 0 {
            let toast = context.lingo.localize("estate.warehouse.deposit_all.nothing", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        }

        // Silent ack — the inline status line carries the success message.
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

        let banner = "✅ " + context.lingo.localize("estate.warehouse.deposit_all.success", locale: locale, interpolations: [
            "count": "\(moved)"
        ])

        let ctrl = Controllers.estateController
        let invEntries = try await InventoryEntry.list(for: context.session, on: context.db)
        let whEntries = try await WarehouseEntry.list(for: context.session, on: context.db)
        let body = ctrl.renderWarehouseCategory(type: type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)
        let text = "\(banner)\n\n\(body)"
        let inline = ctrl.warehouseCategoryKeyboard(type: type, invEntries: invEntries, whEntries: whEntries, lingo: context.lingo, locale: locale)
        try await editEstateMessage(message: message, text: text, inline: inline, context: context)
        return true
    }

    // MARK: - Plot drill-down handlers (Phase 5.1)

    /// `estate:plot:claim:<slot>` — opens the plot-type picker for the given
    /// empty slot. Refuses if the slot is out of allowance or already taken.
    static func handlePlotClaimPicker(data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage, context: Context) async throws -> Bool {
        let slot = Int(String(data.dropFirst("estate:plot:claim:".count))) ?? -1
        let locale = context.session.locale
        let ctrl = Controllers.estateController
        let allowance = PlotService.slotsForLevel(context.session.estateLevel)
        guard slot >= 0, slot < allowance else {
            let toast = context.lingo.localize("estate.plot.alert.slot_out_of_range", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        }
        if let _ = try await Plot.find(slot: slot, for: context.session, on: context.db) {
            let toast = context.lingo.localize("estate.plot.alert.slot_taken", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        }
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        let estateLevel = context.session.estateLevel
        let body = ctrl.renderPlotPicker(slot: slot, estateLevel: estateLevel, lingo: context.lingo, locale: locale)
        let inline = ctrl.plotPickerKeyboard(slot: slot, estateLevel: estateLevel, lingo: context.lingo, locale: locale)
        try await editEstateMessage(message: message, text: body, inline: inline, context: context)
        return true
    }

    /// `estate:plot:type:<slot>:<typeRaw>` — claim the slot with the chosen
    /// type, then refresh the plot list with an inline `✅` status line.
    static func handlePlotTypeChosen(data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage, context: Context) async throws -> Bool {
        let parts = data.dropFirst("estate:plot:type:".count).split(separator: ":")
        let locale = context.session.locale
        let ctrl = Controllers.estateController
        guard parts.count == 2,
              let slot = Int(parts[0]),
              let type = PlotType(rawValue: String(parts[1])) else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }
        // Phase 5.3c — defensive: stale callback could carry trainingGround
        // before the player hits estate T3. Surface a clean alert.
        if type == .trainingGround, context.session.estateLevel < 3 {
            let alert = context.lingo.localize("estate.plot.type_locked", locale: locale, interpolations: [
                "tier": "3"
            ])
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: alert, showAlert: true))
            return true
        }
        let result = try await PlotService.claim(slot: slot, type: type, for: context.session, on: context.db)
        switch result {
        case .slotOutOfRange:
            let toast = context.lingo.localize("estate.plot.alert.slot_out_of_range", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        case .slotTaken:
            let toast = context.lingo.localize("estate.plot.alert.slot_taken", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        case .success:
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            let typeName = context.lingo.localize(PlotCatalog.nameKey(for: type), locale: locale)
            let icon = PlotCatalog.icon(for: type)
            let statusLine = "✅ " + context.lingo.localize("estate.plot.alert.claimed", locale: locale, interpolations: [
                "icon": icon,
                "type": typeName,
                "slot": "\(slot + 1)"
            ])
            let plots = try await Plot.list(for: context.session, on: context.db)
            let body = ctrl.renderPlotList(plots: plots, session: context.session, lingo: context.lingo, locale: locale)
            let text = "\(statusLine)\n\n\(body)"
            let inline = ctrl.plotListKeyboard(plots: plots, session: context.session, lingo: context.lingo, locale: locale)
            try await editEstateMessage(message: message, text: text, inline: inline, context: context)
            return true
        }
    }

    /// `estate:plot:harvest:<slot>` — moves accumulated yield to the bag,
    /// shows inline status on success, modal alert on empty / bag-full.
    static func handlePlotHarvest(data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage, context: Context) async throws -> Bool {
        let slot = Int(String(data.dropFirst("estate:plot:harvest:".count))) ?? -1
        let locale = context.session.locale
        let ctrl = Controllers.estateController
        guard let plot = try await Plot.find(slot: slot, for: context.session, on: context.db) else {
            let toast = context.lingo.localize("estate.plot.alert.slot_empty", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        }
        let result = try await PlotService.harvest(plot, for: context.session, on: context.db)
        switch result {
        case .empty:
            // 💤 prepended in Swift since Lingo bug fires on leading
            // supplementary-plane emoji + interpolation.
            let toast = "💤 " + context.lingo.localize("estate.plot.alert.harvest_empty", locale: locale, interpolations: ["slot": "\(slot + 1)"])
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        case .success(let primary, let bonus):
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            // Format each yield as "+N <icon> <name>" and join with comma.
            // Bonus is appended only when present (e.g. Mine → iron).
            func formatYield(_ y: PlotService.HarvestYield) -> String {
                let item = ItemCatalog.find(y.itemId)
                let icon = item?.icon ?? ""
                let name = item.map { context.lingo.localize($0.nameKey, locale: locale) } ?? y.itemId
                return "+\(y.amount) \(icon) \(name)"
            }
            var pieces: [String] = []
            if primary.amount > 0 { pieces.append(formatYield(primary)) }
            if let bonus = bonus, bonus.amount > 0 { pieces.append(formatYield(bonus)) }
            let yieldsText = pieces.joined(separator: ", ")
            let statusLine = "✅ " + context.lingo.localize("estate.plot.alert.harvested_multi", locale: locale, interpolations: [
                "slot":   "\(slot + 1)",
                "yields": yieldsText
            ])
            let plots = try await Plot.list(for: context.session, on: context.db)
            let body = ctrl.renderPlotList(plots: plots, session: context.session, lingo: context.lingo, locale: locale)
            let text = "\(statusLine)\n\n\(body)"
            let inline = ctrl.plotListKeyboard(plots: plots, session: context.session, lingo: context.lingo, locale: locale)
            try await editEstateMessage(message: message, text: text, inline: inline, context: context)
            return true
        }
    }

    /// `estate:plot:train:<slot>` — opens combat against a Training Dummy.
    /// Hooks into the existing CombatController by stamping the `enemy.training_dummy`
    /// id on a fresh ExplorationState row. CombatController detects the
    /// training context by enemy id and swaps Flee for a Back button that
    /// returns the player to this plot list.
    static func handlePlotTraining(data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage, context: Context) async throws -> Bool {
        let slot = Int(String(data.dropFirst("estate:plot:train:".count))) ?? -1
        let locale = context.session.locale
        guard let plot = try await Plot.find(slot: slot, for: context.session, on: context.db),
              let type = PlotType(rawValue: plot.plotType),
              type == .trainingGround else {
            let toast = context.lingo.localize("estate.plot.alert.slot_empty", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        }
        guard let dummy = EnemyCatalog.find(CombatService.trainingDummyEnemyId),
              let userId = context.session.id else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
        }
        // Spin up a fresh ExplorationState row holding the training fight.
        // Estate is locked during real expeditions (`showEstate` guard), so
        // there's no concurrent state to clash with.
        // **Note:** unlike real combat, we do NOT flip `routerName` to
        // "combat" — the player should be free to navigate the main
        // reply-keyboard (Profile / Inventory / Estate / Capital / Settings)
        // while training. The combat inline-button callbacks reach
        // `CombatController.onCallbackQuery` via the `combat:*` forwarding
        // installed in every other controller's onCallbackQuery handler.
        let state = ExplorationState(userID: userId, stepsDeep: 0)
        state.beginCombat(enemyId: dummy.id, hp: dummy.hp)
        try await state.save(on: context.db)

        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

        // Hand off to CombatController. `intro: true` shows the encounter
        // banner — flavoured by `combat.encounter.intro` interpolating the
        // dummy's name.
        try await Controllers.combatController.showCombat(context: context, state: state, enemy: dummy, intro: true)
        return true
    }

    // MARK: - Workshop crafting (Phase 5.2)

    /// `craft:detail:<recipe.id>` — opens the recipe detail screen (description,
    /// recipe ingredients, stats / effects, action + Back buttons). Kitchen
    /// recipes are gated by `LearnedRecipe` — opening a stale-callback detail
    /// for an unlearned dish surfaces a modal alert and stays put.
    static func handleCraftDetail(data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage, context: Context) async throws -> Bool {
        let recipeId = String(data.dropFirst("craft:detail:".count))
        let locale = context.session.locale
        let ctrl = Controllers.estateController

        guard let recipe = RecipeCatalog.find(recipeId) else {
            let toast = context.lingo.localize("workshop.alert.unknown_recipe", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        }

        if recipe.category.requiresLearning, !RecipeCatalog.starterRecipeIds.contains(recipeId) {
            let known = try await LearnedRecipe.has(recipeId, for: context.session, on: context.db)
            if !known {
                let toast = context.lingo.localize("kitchen.alert.not_learned", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
                return true
            }
        }

        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        let body = ctrl.renderRecipeDetail(recipe: recipe, lingo: context.lingo, locale: locale)
        let inline = ctrl.recipeDetailKeyboard(recipe: recipe, lingo: context.lingo, locale: locale)
        try await editEstateMessage(message: message, text: body, inline: inline, context: context)
        return true
    }

    /// `craft:<recipe.id>` — performs the craft and refreshes the detail screen
    /// with a status banner at the BOTTOM of the body (so the player sees the
    /// "✅ Crafted ..." line without scrolling past the recipe + stats).
    /// Failures (missing materials / inventory full) raise a modal alert and
    /// leave the screen unchanged.
    static func handleCraft(data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage, context: Context) async throws -> Bool {
        let recipeId = String(data.dropFirst("craft:".count))
        let locale = context.session.locale
        let ctrl = Controllers.estateController

        guard let recipe = RecipeCatalog.find(recipeId) else {
            let toast = context.lingo.localize("workshop.alert.unknown_recipe", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true
        }

        // Kitchen-recipe gate: refuse if the recipe hasn't been learned and
        // isn't an always-available starter. Defense against stale callbacks
        // left in chat after a wipe.
        if recipe.category.requiresLearning, !RecipeCatalog.starterRecipeIds.contains(recipeId) {
            let known = try await LearnedRecipe.has(recipeId, for: context.session, on: context.db)
            if !known {
                let toast = context.lingo.localize("kitchen.alert.not_learned", locale: locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
                return true
            }
        }

        let result = try await CraftingService.craft(recipe, for: context.session, on: context.db)

        switch result {
        case .unknownRecipe, .unknownItem:
            let toast = context.lingo.localize("workshop.alert.unknown_recipe", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .missingMaterials(let shortages):
            // Compose a single multi-line alert: header + one row per missing input.
            let header = context.lingo.localize("workshop.alert.short_header", locale: locale)
            let rows: [String] = shortages.map { shortage in
                let item = ItemCatalog.find(shortage.itemId)
                let icon = item?.icon ?? ""
                let name = item.map { context.lingo.localize($0.nameKey, locale: locale) } ?? shortage.itemId
                let needed = max(0, shortage.need - shortage.have)
                return context.lingo.localize("workshop.alert.short_row", locale: locale, interpolations: [
                    "icon":   icon,
                    "name":   name,
                    "needed": "\(needed)",
                    "have":   "\(shortage.have)",
                    "need":   "\(shortage.need)"
                ])
            }
            let toast = ([header] + rows).joined(separator: "\n")
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .inventoryFull:
            let toast = context.lingo.localize("workshop.alert.bag_full", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .success(let outputItemId, let qty):
            let item = ItemCatalog.find(outputItemId)
            let icon = item?.icon ?? ""
            let name = item.map { context.lingo.localize($0.nameKey, locale: locale) } ?? outputItemId
            let statusLine = "✅ " + context.lingo.localize(recipe.category.craftedAlertKey, locale: locale, interpolations: [
                "qty":  "\(qty)",
                "icon": icon,
                "name": name
            ])
            // Silent ack — the inline banner carries the message.
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            // Stay on the detail screen; banner appended at the BOTTOM so the
            // player sees it without scrolling past the recipe + stats sections.
            let body = ctrl.renderRecipeDetail(recipe: recipe, lingo: context.lingo, locale: locale)
            let text = "\(body)\n\n\(statusLine)"
            let inline = ctrl.recipeDetailKeyboard(recipe: recipe, lingo: context.lingo, locale: locale)
            try await editEstateMessage(message: message, text: text, inline: inline, context: context)
            return true
        }
    }

    // MARK: - Weapon upgrade callback handlers (Phase 5.2.2)

    /// `weapon:upgrade:detail` — open / refresh the weapon upgrade screen.
    /// Resolves the player's equipped main-hand row, takes a snapshot of
    /// inventory + warehouse availability for the next-tier inputs (so the
    /// "have/need" suffix is accurate), and renders.
    static func handleWeaponUpgradeDetail(
        query: TGCallbackQuery,
        message: TGMaybeInaccessibleMessage,
        context: Context
    ) async throws -> Bool {
        let locale = context.session.locale
        let ctrl = Controllers.estateController

        let snapshot = try await weaponUpgradeSnapshot(context: context)

        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        let body = ctrl.renderWeaponUpgrade(
            weaponEntry: snapshot.weaponEntry,
            weaponItem: snapshot.weaponItem,
            userId: context.session.id,
            estateLevel: context.session.estateLevel,
            invSnapshot: snapshot.invHaves,
            whSnapshot: snapshot.whHaves,
            lingo: context.lingo, locale: locale
        )
        let inline = ctrl.weaponUpgradeKeyboard(canUpgrade: snapshot.canUpgrade, lingo: context.lingo, locale: locale)
        try await editEstateMessage(message: message, text: body, inline: inline, context: context)
        return true
    }

    /// `weapon:upgrade:confirm` — perform one upgrade step. Failure modes
    /// (missing materials / estate-level too low / max tier / no weapon)
    /// surface as modal alerts and leave the screen unchanged. On success
    /// the screen refreshes with a `✅ Upgraded ...` banner appended below
    /// the body, mirroring the `craft:` handler's banner placement.
    static func handleWeaponUpgradeConfirm(
        query: TGCallbackQuery,
        message: TGMaybeInaccessibleMessage,
        context: Context
    ) async throws -> Bool {
        let locale = context.session.locale
        let ctrl = Controllers.estateController

        let result = try await WeaponUpgradeService.upgrade(for: context.session, on: context.db)

        switch result {
        case .noWeaponEquipped:
            let toast = context.lingo.localize("weapon.upgrade.no_weapon", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .maxTierReached:
            let toast = context.lingo.localize("weapon.upgrade.max_tier", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .estateLevelTooLow(let required, let current):
            let toast = context.lingo.localize("weapon.upgrade.estate_too_low", locale: locale, interpolations: [
                "required": "\(required)",
                "current":  "\(current)"
            ])
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .missingMaterials(let shortages):
            // Mirror the craft handler: a multi-line modal that lists every
            // input the player still needs.
            let header = context.lingo.localize("workshop.alert.short_header", locale: locale)
            let rows: [String] = shortages.map { shortage in
                let item = ItemCatalog.find(shortage.itemId)
                let icon = item?.icon ?? ""
                let name = item.map { context.lingo.localize($0.nameKey, locale: locale) } ?? shortage.itemId
                let needed = max(0, shortage.need - shortage.have)
                return context.lingo.localize("workshop.alert.short_row", locale: locale, interpolations: [
                    "icon":   icon,
                    "name":   name,
                    "needed": "\(needed)",
                    "have":   "\(shortage.have)",
                    "need":   "\(shortage.need)"
                ])
            }
            let toast = ([header] + rows).joined(separator: "\n")
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .success(let newTier, let outputItemId):
            // Silent ack — the inline banner carries the message.
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

            let item = ItemCatalog.find(outputItemId)
            let icon = item?.icon ?? ""
            let newName = item.map { context.lingo.localize(ItemDisplay.nameKey(for: $0, tier: newTier), locale: locale) } ?? outputItemId
            let banner = "✅ " + context.lingo.localize("weapon.upgrade.banner.success", locale: locale, interpolations: [
                "icon": icon,
                "name": newName,
                "tier": "\(newTier)"
            ])

            // Re-fetch fresh snapshot so the body shows the new "current" tier.
            let snapshot = try await weaponUpgradeSnapshot(context: context)
            let body = ctrl.renderWeaponUpgrade(
                weaponEntry: snapshot.weaponEntry,
                weaponItem: snapshot.weaponItem,
                userId: context.session.id,
                estateLevel: context.session.estateLevel,
                invSnapshot: snapshot.invHaves,
                whSnapshot: snapshot.whHaves,
                lingo: context.lingo, locale: locale
            )
            let text = "\(body)\n\n\(banner)"
            let inline = ctrl.weaponUpgradeKeyboard(canUpgrade: snapshot.canUpgrade, lingo: context.lingo, locale: locale)
            try await editEstateMessage(message: message, text: text, inline: inline, context: context)
            return true
        }
    }

    // MARK: - Estate upgrade callback handlers (Phase 5.3c)

    /// `estate:upgrade:detail` — open / refresh the estate upgrade screen.
    /// Snapshots inventory + warehouse availability for the next-tier inputs
    /// so the "have/need" lines are accurate.
    static func handleEstateUpgradeDetail(
        query: TGCallbackQuery,
        message: TGMaybeInaccessibleMessage,
        context: Context
    ) async throws -> Bool {
        let locale = context.session.locale
        let ctrl = Controllers.estateController

        let (inv, wh) = try await estateUpgradeSnapshot(context: context)
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        let body = ctrl.renderEstateUpgrade(
            session: context.session,
            invSnapshot: inv,
            whSnapshot: wh,
            lingo: context.lingo, locale: locale
        )
        let canUpgrade = EstateUpgradeCatalog.canUpgrade(from: context.session.estateLevel)
        let inline = ctrl.estateUpgradeKeyboard(canUpgrade: canUpgrade, lingo: context.lingo, locale: locale)
        try await editEstateMessage(message: message, text: body, inline: inline, context: context)
        return true
    }

    /// `estate:upgrade:confirm` — perform one tier upgrade. Failure modes
    /// (max tier / player level too low / missing materials) surface as
    /// modal alerts and leave the screen unchanged. Success refreshes the
    /// screen with the new "current" tier and appends a `✅` banner.
    static func handleEstateUpgradeConfirm(
        query: TGCallbackQuery,
        message: TGMaybeInaccessibleMessage,
        context: Context
    ) async throws -> Bool {
        let locale = context.session.locale
        let ctrl = Controllers.estateController

        let result = try await EstateUpgradeService.upgrade(for: context.session, on: context.db)

        switch result {
        case .maxTierReached:
            let toast = context.lingo.localize("estate.upgrade.max_tier", locale: locale)
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .playerLevelTooLow(let required, let current):
            let toast = context.lingo.localize("estate.upgrade.level_too_low", locale: locale, interpolations: [
                "required": "\(required)",
                "current":  "\(current)"
            ])
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .insufficientGold(let required, let current):
            let toast = context.lingo.localize("estate.upgrade.gold_too_low", locale: locale, interpolations: [
                "required": "\(required)",
                "current":  "\(current)"
            ])
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .missingMaterials(let shortages):
            // Reuse the workshop shortage modal format — one row per missing item.
            let header = context.lingo.localize("workshop.alert.short_header", locale: locale)
            let rows: [String] = shortages.map { shortage in
                let item = ItemCatalog.find(shortage.itemId)
                let icon = item?.icon ?? ""
                let name = item.map { context.lingo.localize($0.nameKey, locale: locale) } ?? shortage.itemId
                let needed = max(0, shortage.need - shortage.have)
                return context.lingo.localize("workshop.alert.short_row", locale: locale, interpolations: [
                    "icon":   icon,
                    "name":   name,
                    "needed": "\(needed)",
                    "have":   "\(shortage.have)",
                    "need":   "\(shortage.need)"
                ])
            }
            let toast = ([header] + rows).joined(separator: "\n")
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: toast, showAlert: true))
            return true

        case .success(let newTier):
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            let newName = context.lingo.localize("estate.tier.\(newTier).name", locale: locale)
            let banner = "✅ " + context.lingo.localize("estate.upgrade.banner.success", locale: locale, interpolations: [
                "tier": "\(newTier)",
                "name": newName
            ])

            let (inv, wh) = try await estateUpgradeSnapshot(context: context)
            let body = ctrl.renderEstateUpgrade(
                session: context.session,
                invSnapshot: inv,
                whSnapshot: wh,
                lingo: context.lingo, locale: locale
            )
            let canUpgrade = EstateUpgradeCatalog.canUpgrade(from: context.session.estateLevel)
            let inline = ctrl.estateUpgradeKeyboard(canUpgrade: canUpgrade, lingo: context.lingo, locale: locale)
            let text = "\(body)\n\n\(banner)"
            try await editEstateMessage(message: message, text: text, inline: inline, context: context)
            return true
        }
    }

    /// Per-input availability snapshot from the combined inventory + warehouse
    /// pool. Returns two dictionaries keyed by item id. Empty maps when the
    /// estate is at max tier (no inputs to look up).
    private static func estateUpgradeSnapshot(context: Context) async throws -> (inv: [String: Int], wh: [String: Int]) {
        guard let userId = context.session.id,
              let nextStep = EstateUpgradeCatalog.nextStep(from: context.session.estateLevel) else {
            return ([:], [:])
        }
        var invHaves: [String: Int] = [:]
        var whHaves: [String: Int] = [:]
        for input in nextStep.inputs {
            invHaves[input.itemId] = try await InventoryEntry.totalQuantity(of: input.itemId, for: userId, on: context.db)
            whHaves[input.itemId]  = try await WarehouseEntry.totalQuantity(of: input.itemId, for: userId, on: context.db)
        }
        return (invHaves, whHaves)
    }

    /// Bundle of derived state used by both upgrade callbacks. Keeps the
    /// detail render and confirm handler in sync without re-running queries.
    private struct WeaponUpgradeSnapshot {
        let weaponEntry: InventoryEntry?
        let weaponItem: Item?
        let invHaves: [String: Int]
        let whHaves: [String: Int]
        /// True when the player has a weapon, it's below max tier, and the
        /// catalog has a defined next step. Estate-level gate and material
        /// shortfalls are validated by the service on confirm — the button
        /// stays visible so the player can read the modal alert telling them
        /// exactly what's missing.
        let canUpgrade: Bool
    }

    private static func weaponUpgradeSnapshot(context: Context) async throws -> WeaponUpgradeSnapshot {
        guard let userId = context.session.id else {
            return WeaponUpgradeSnapshot(weaponEntry: nil, weaponItem: nil, invHaves: [:], whHaves: [:], canUpgrade: false)
        }

        let equippedRows = try await InventoryEntry.query(on: context.db)
            .filter(\.$user.$id, .equal, userId)
            .filter(\.$equippedSlot, .equal, EquipmentSlot.mainHand.rawValue)
            .all()
        let weapon = equippedRows.first
        let weaponItem = weapon.flatMap { ItemCatalog.find($0.itemId) }

        var invHaves: [String: Int] = [:]
        var whHaves:  [String: Int] = [:]
        var canUpgrade = false

        if let weapon = weapon, let item = weaponItem,
           let maxTier = WeaponUpgradeCatalog.maxTier(for: item.id) {
            if weapon.tier < maxTier,
               let nextStep = WeaponUpgradeCatalog.step(for: item.id, tier: weapon.tier + 1) {
                canUpgrade = true
                for input in nextStep.inputs {
                    invHaves[input.itemId] = try await InventoryEntry.totalQuantity(of: input.itemId, for: userId, on: context.db)
                    whHaves[input.itemId]  = try await WarehouseEntry.totalQuantity(of: input.itemId, for: userId, on: context.db)
                }
            }
        }

        return WeaponUpgradeSnapshot(
            weaponEntry: weapon, weaponItem: weaponItem,
            invHaves: invHaves, whHaves: whHaves,
            canUpgrade: canUpgrade
        )
    }

    // MARK: - Weapon upgrade (Phase 5.2.2)

    /// Detail screen body for the weapon upgrade flow. Shows the player's
    /// current weapon (icon + tier-N name + current stats), the next tier
    /// (icon + tier-(N+1) name + stats with deltas), required materials,
    /// and the estate-level requirement (with availability indicator). At
    /// max tier, falls back to a "fully upgraded" page.
    fileprivate func renderWeaponUpgrade(
        weaponEntry: InventoryEntry?,
        weaponItem: Item?,
        userId: UUID?,
        estateLevel: Int,
        invSnapshot: [String: Int],
        whSnapshot: [String: Int],
        lingo: Lingo,
        locale: String
    ) -> String {
        let title = lingo.localize("weapon.upgrade.title", locale: locale)

        guard let entry = weaponEntry, let item = weaponItem else {
            let none = lingo.localize("weapon.upgrade.no_weapon", locale: locale)
            return "<b>\(title)</b>\n\n\(none)"
        }
        guard let maxTier = WeaponUpgradeCatalog.maxTier(for: item.id),
              let currentStep = WeaponUpgradeCatalog.step(for: item.id, tier: entry.tier) else {
            // Equipped weapon isn't in the catalog at all — render a clean
            // "no upgrade path" page instead of crashing.
            let none = lingo.localize("weapon.upgrade.no_weapon", locale: locale)
            return "<b>\(title)</b>\n\n\(none)"
        }

        let icon = item.icon ?? ""
        let currentName = lingo.localize(ItemDisplay.nameKey(for: item, tier: entry.tier), locale: locale)
        let currentHeader = "\(icon) <b>\(currentName)</b>"

        var lines: [String] = ["<b>\(title)</b>", "", currentHeader]

        // Current-tier stats block.
        let currentStatLines = formatStatLines(stats: currentStep.stats, lingo: lingo, locale: locale, prefix: "   ")
        if !currentStatLines.isEmpty {
            lines.append(contentsOf: currentStatLines)
        }

        // Already at max tier — show "fully upgraded" message and stop here.
        if entry.tier >= maxTier {
            lines.append("")
            lines.append(lingo.localize("weapon.upgrade.max_tier", locale: locale))
            return lines.joined(separator: "\n")
        }

        // Next-tier preview.
        let nextTier = entry.tier + 1
        guard let nextStep = WeaponUpgradeCatalog.step(for: item.id, tier: nextTier) else {
            lines.append("")
            lines.append(lingo.localize("weapon.upgrade.max_tier", locale: locale))
            return lines.joined(separator: "\n")
        }
        let nextName = lingo.localize(ItemDisplay.nameKey(for: item, tier: nextTier), locale: locale)
        let arrow = lingo.localize("weapon.upgrade.delta_arrow", locale: locale)
        lines.append("")
        lines.append("\(arrow) \(icon) <b>\(nextName)</b>")
        let deltaLines = formatStatDeltas(from: currentStep.stats, to: nextStep.stats, lingo: lingo, locale: locale, prefix: "   ")
        lines.append(contentsOf: deltaLines)

        // Materials.
        lines.append("")
        lines.append("<b>" + lingo.localize("weapon.upgrade.recipe_header", locale: locale) + "</b>")
        for input in nextStep.inputs {
            let inputItem = ItemCatalog.find(input.itemId)
            let inputIcon = inputItem?.icon ?? ""
            let inputName = inputItem.map { lingo.localize($0.nameKey, locale: locale) } ?? input.itemId
            let have = (invSnapshot[input.itemId, default: 0]) + (whSnapshot[input.itemId, default: 0])
            lines.append("   \(input.quantity)× \(inputIcon) \(inputName)  (\(have)/\(input.quantity))")
        }

        // Estate-level gate.
        let gateOK = estateLevel >= nextTier
        let mark = gateOK ? "✅" : "⛔"
        lines.append("")
        lines.append("\(mark) " + lingo.localize("weapon.upgrade.estate_required", locale: locale, interpolations: [
            "required": "\(nextTier)",
            "current":  "\(estateLevel)"
        ]))

        _ = userId  // currently unused but kept for symmetry with future per-user gates
        return lines.joined(separator: "\n")
    }

    /// Detail-screen keyboard. At max tier, only Back. Otherwise [🔨 Upgrade]
    /// + Back. The Upgrade button is always shown — the handler validates
    /// estate level and materials and surfaces a modal alert on failure (so
    /// the player can read exactly what's missing instead of guessing why
    /// the button is greyed out).
    fileprivate func weaponUpgradeKeyboard(canUpgrade: Bool, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        var rows: [[TGInlineKeyboardButton]] = []
        if canUpgrade {
            let upgrade = lingo.localize("weapon.upgrade.button.confirm", locale: locale)
            rows.append([TGInlineKeyboardButton(text: upgrade, callbackData: "weapon:upgrade:confirm")])
        }
        let back = lingo.localize("workshop.detail.button.back", locale: locale)
        rows.append([TGInlineKeyboardButton(text: back, callbackData: "estate:home:workshop")])
        return TGInlineKeyboardMarkup(inlineKeyboard: rows)
    }

    /// Render only the non-zero stat fields of a `GearStats` value as
    /// "+N <icon> <name>" lines. Used for the current-tier block on the
    /// upgrade detail screen.
    private func formatStatLines(stats: GearStats, lingo: Lingo, locale: String, prefix: String) -> [String] {
        var out: [String] = []
        if stats.attack != 0   { out.append("\(prefix)+\(stats.attack) ⚔️ \(lingo.localize("workshop.stats.attack", locale: locale))") }
        if stats.defense != 0  { out.append("\(prefix)+\(stats.defense) 🛡 \(lingo.localize("workshop.stats.defense", locale: locale))") }
        if stats.crit != 0     { out.append("\(prefix)+\(stats.crit)% 💥 \(lingo.localize("workshop.stats.crit", locale: locale))") }
        if stats.dodge != 0    { out.append("\(prefix)+\(stats.dodge) 💨 \(lingo.localize("workshop.stats.dodge", locale: locale))") }
        if stats.accuracy != 0 { out.append("\(prefix)+\(stats.accuracy) 🎯 \(lingo.localize("workshop.stats.accuracy", locale: locale))") }
        return out
    }

    /// Render stat deltas from `from` to `to` as "+N → +M (↑+K) <icon> <name>"
    /// lines. Used for the next-tier preview on the upgrade detail screen.
    private func formatStatDeltas(from: GearStats, to: GearStats, lingo: Lingo, locale: String, prefix: String) -> [String] {
        func line(_ a: Int, _ b: Int, _ unit: String, _ iconLabel: String) -> String? {
            guard a != 0 || b != 0 else { return nil }
            let delta = b - a
            let deltaPart = delta == 0 ? "" : (delta > 0 ? "  (↑+\(delta))" : "  (↓\(delta))")
            return "\(prefix)+\(a)\(unit) → +\(b)\(unit)\(deltaPart) \(iconLabel)"
        }
        var out: [String] = []
        if let l = line(from.attack,   to.attack,   "",  "⚔️ \(lingo.localize("workshop.stats.attack",   locale: locale))") { out.append(l) }
        if let l = line(from.defense,  to.defense,  "",  "🛡 \(lingo.localize("workshop.stats.defense",  locale: locale))") { out.append(l) }
        if let l = line(from.crit,     to.crit,     "%", "💥 \(lingo.localize("workshop.stats.crit",     locale: locale))") { out.append(l) }
        if let l = line(from.dodge,    to.dodge,    "",  "💨 \(lingo.localize("workshop.stats.dodge",    locale: locale))") { out.append(l) }
        if let l = line(from.accuracy, to.accuracy, "",  "🎯 \(lingo.localize("workshop.stats.accuracy", locale: locale))") { out.append(l) }
        return out
    }

    /// Edit the source message in place — text or caption depending on
    /// whether the message is a photo (estate root may be artwork).
    fileprivate static func editEstateMessage(message: TGMaybeInaccessibleMessage, text: String, inline: TGInlineKeyboardMarkup, context: Context) async throws {
        let chatId = TGChatId.chat(message.chat.id)
        let isPhoto = (message.getMessage()?.photo) != nil
        if isPhoto {
            let params = TGEditMessageCaptionParams(
                chatId: chatId,
                messageId: message.messageId,
                caption: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageCaption(params: params)
        } else {
            let params = TGEditMessageTextParams(
                chatId: chatId,
                messageId: message.messageId,
                text: text,
                parseMode: .html,
                replyMarkup: inline
            )
            _ = try? await context.bot.editMessageText(params: params)
        }
    }
}
