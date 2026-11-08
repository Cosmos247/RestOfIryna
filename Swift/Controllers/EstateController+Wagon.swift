//
//  EstateController+Wagon.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  The wagon in the estate's yard (`content/spec/spec-wagon.md` §3.3): reached
//  from the warehouse, where it trades with the warehouse alone.
//  - the warehouse's root names it — «🫏 Віз: 150/200 · ще 2год 41хв» and a
//    «🫏 Віз (150/200)» button — while one is hired or still holds cargo;
//  - the wagon's list is everything in the warehouse or on the wagon (the
//    owner, 2026-11-08: anything the warehouse takes): a stackable is one row,
//    «🪵 Сосновий брус · 📦 110 / 🫏 100», opening its card; a piece of gear is
//    one button per COPY, named with its tier, enchant and wear, that moves it
//    at once — «⬆️ 🫏 …» onto the wagon, «⬇️ 📦 …» off it — with its own state,
//    since a gear list names rows; «📦 Розвантажити все» sits under the list;
//  - a stackable's card is the warehouse card's shape: «⬆️ 🫏 1 · Усі (N) · ✏️»
//    loads, «⬇️ 📦 1 · Усі (N) · ✏️» unloads, a side holding one has only its «1».
//
//  Loading needs a running hire (§3.5: a wagon whose hire ran out takes nothing
//  new); unloading never does. The warehouse cap holds on every unload, and a
//  partial move says what stayed. No estate service reads the wagon (§2.8).
//  The typed «✏️» rides the warehouse's own prompt (`PendingWarehouseTransfer`,
//  directions `.load` / `.unload`), so its Cancel and its stray-number handling
//  are the warehouse's.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

extension EstateController {

    // MARK: - The warehouse's root

    /// The warehouse's root screen, the wagon's line and button included while
    /// it stands in the yard.
    static func warehouseRootScreen(context: Context) async throws -> (text: String, markup: TGInlineKeyboardMarkup) {
        let ctrl = Controllers.estateController
        let lingo = context.lingo, locale = context.session.locale
        let entries = try await WarehouseEntry.list(for: context.session, on: context.db)
        let cap = WarehouseService.capForLevel(context.session.estateLevel)
        let usedUnits = entries.reduce(0) { $0 + $1.quantity }
        var text = ctrl.renderWarehouseRoot(slotsUsed: usedUnits, slotsCap: cap, lingo: lingo, locale: locale)
        var rows = ctrl.warehouseRootKeyboard(entries: entries, lingo: lingo, locale: locale).inlineKeyboard
        if let wagon = try await WagonService.atHome(for: context.session, on: context.db) {
            text += "\n" + WagonDisplay.statusLine(wagon, lingo: lingo, locale: locale)
            let button = TGInlineKeyboardButton(text: WagonDisplay.button(wagon, lingo: lingo, locale: locale),
                                                callbackData: "estate:wg:list")
            rows.insert([button], at: max(0, rows.count - 1))
        }
        return (text, TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    // MARK: - The wagon's list and cards

    /// Everything in the warehouse or on the wagon. Nil when there is no wagon
    /// in the yard to show — the warehouse's root is the answer then.
    static func wagonList(context: Context) async throws -> (text: String, markup: TGInlineKeyboardMarkup)? {
        let lingo = context.lingo, locale = context.session.locale
        guard let userId = context.session.id,
              let wagon = try await WagonService.atHome(for: context.session, on: context.db) else { return nil }
        let stored = try await WarehouseEntry.list(for: context.session, on: context.db)
            .filter { WagonService.carries($0.itemId) }
        let cargo = try await WagonService.cargo(for: userId, on: context.db)
        func isGear(_ itemId: String) -> Bool { ItemCatalog.find(itemId)?.stackable == false }
        var inWarehouse: [String: Int] = [:]
        for row in stored where !isGear(row.itemId) {
            inWarehouse[row.itemId, default: 0] += row.quantity
        }
        var onWagon: [String: Int] = [:]
        for pile in cargo where !isGear(pile.itemId) {
            onWagon[pile.itemId, default: 0] += pile.quantity
        }
        let storedGear = stored.filter { isGear($0.itemId) }
            .sorted { ($0.itemId, $1.durability) < ($1.itemId, $0.durability) }
        let carriedGear = cargo.filter { isGear($0.itemId) }
            .sorted { ($0.itemId, $1.durability) < ($1.itemId, $0.durability) }

        let header = "<b>\(lingo.localize("estate.warehouse", locale: locale)) / \(WagonDisplay.icon) \(lingo.localize("wagon.name", locale: locale))</b>"
        var lines = [header, "", WagonDisplay.statusLine(wagon, lingo: lingo, locale: locale)]
        let ids = Set(inWarehouse.keys).union(onWagon.keys).sorted()
        if ids.isEmpty && storedGear.isEmpty && carriedGear.isEmpty {
            lines.append("<i>\(lingo.localize("estate.wagon.empty", locale: locale))</i>")
        } else {
            lines.append("<i>\(lingo.localize(wagon.running ? "estate.wagon.hint" : "estate.wagon.hint_ended", locale: locale))</i>")
        }

        var rows: [[TGInlineKeyboardButton]] = []
        for id in ids {
            guard let item = ItemCatalog.find(id) else { continue }
            let icon = item.icon.map { "\($0) " } ?? ""
            let label = "\(icon)\(lingo.localize(item.nameKey, locale: locale)) · 📦 \(inWarehouse[id] ?? 0) / \(WagonDisplay.icon) \(onWagon[id] ?? 0)"
            rows.append([TGInlineKeyboardButton(text: label, callbackData: "estate:wg:info:\(id)")])
        }
        // Gear, one copy per button: what the warehouse holds goes on while the
        // hire runs, what the wagon holds comes off at any time.
        if wagon.running {
            for row in storedGear {
                guard let id = row.id, let item = ItemCatalog.find(row.itemId) else { continue }
                rows.append([TGInlineKeyboardButton(text: "⬆️ \(WagonDisplay.icon) " + gearLabel(item, row.gearState, lingo: lingo, locale: locale),
                                                    callbackData: "estate:wg:pin:\(id.uuidString)")])
            }
        }
        for pile in carriedGear {
            guard let id = pile.id, let item = ItemCatalog.find(pile.itemId) else { continue }
            rows.append([TGInlineKeyboardButton(text: "⬇️ 📦 " + gearLabel(item, pile.gearState, lingo: lingo, locale: locale),
                                                callbackData: "estate:wg:pout:\(id.uuidString)")])
        }
        if wagon.used > 0 {
            rows.append([TGInlineKeyboardButton(text: lingo.localize("estate.wagon.button.unload_all", locale: locale),
                                                callbackData: "estate:wg:unloadall")])
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("estate.back_root", locale: locale),
                                            callbackData: "estate:home:warehouse")])
        return (lines.joined(separator: "\n"), TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    /// A piece of gear named the way the warehouse's gear list names a copy:
    /// its tier's name, its enchant on armour, its wear where it wears.
    static func gearLabel(_ item: Item, _ state: GearState, lingo: Lingo, locale: String) -> String {
        let icon = item.icon.map { "\($0) " } ?? ""
        let name = lingo.localize(ItemDisplay.nameKey(for: item, tier: state.tier), locale: locale)
        var condition = ""
        if let slot = item.slot, GearConditionService.armorSlots.contains(slot.rawValue), state.enchantLevel > 0 {
            condition += " +\(state.enchantLevel)"
        }
        if let slot = item.slot, GearConditionService.durableSlots.contains(slot.rawValue) {
            condition += " \(state.durability)/\(state.maxDurability)"
        }
        return "\(icon)\(name)\(condition)"
    }

    /// A stackable's card: what the warehouse and the wagon hold, then a row
    /// each way. Nil when neither holds any, or there is no wagon in the yard;
    /// gear has no card here — each copy moves from the list.
    static func wagonCard(for item: Item, context: Context) async throws -> (text: String, markup: TGInlineKeyboardMarkup)? {
        let lingo = context.lingo, locale = context.session.locale
        guard item.stackable, let userId = context.session.id,
              let wagon = try await WagonService.atHome(for: context.session, on: context.db) else { return nil }
        let inWarehouse = try await WarehouseEntry.totalQuantity(of: item.id, for: userId, on: context.db)
        let onWagon = try await WagonService.quantity(of: item.id, for: userId, on: context.db)
        guard inWarehouse + onWagon > 0 else { return nil }

        let icon = item.icon.map { "\($0) " } ?? ""
        var lines = ["\(icon)<b>\(lingo.localize(item.nameKey, locale: locale))</b>"]
        if let descKey = item.descriptionKey {
            lines.append("")
            lines.append("<i>\(lingo.localize(descKey, locale: locale))</i>")
        }
        lines.append("")
        let free = lingo.localize("inventory.free", locale: locale, interpolations: ["free": "\(wagon.free)"])
        lines.append("📦 " + lingo.localize("estate.warehouse.card.in_wh", locale: locale, interpolations: ["count": "\(inWarehouse)"])
                     + " · \(WagonDisplay.icon) "
                     + lingo.localize("estate.wagon.card.on_wagon", locale: locale, interpolations: ["count": "\(onWagon)"])
                     + " (\(free))")

        func row(held: Int, oneKey: String, arrow: String, verb: String) -> [TGInlineKeyboardButton] {
            var buttons = [TGInlineKeyboardButton(text: lingo.localize(oneKey, locale: locale),
                                                  callbackData: "estate:wg:\(verb)1:\(item.id)")]
            if held >= 2 {
                buttons.append(TGInlineKeyboardButton(
                    text: "\(arrow) " + lingo.localize("estate.warehouse.card.all", locale: locale,
                                                       interpolations: ["count": "\(held)"]),
                    callbackData: "estate:wg:\(verb)all:\(item.id)"))
                buttons.append(TGInlineKeyboardButton(text: "\(arrow) ✏️", callbackData: "estate:wg:type\(verb):\(item.id)"))
            }
            return buttons
        }
        var rows: [[TGInlineKeyboardButton]] = []
        if wagon.running, inWarehouse > 0 {
            rows.append(row(held: inWarehouse, oneKey: "estate.wagon.card.load_one", arrow: "⬆️", verb: "in"))
        }
        if onWagon > 0 {
            rows.append(row(held: onWagon, oneKey: "estate.wagon.card.unload_one", arrow: "⬇️", verb: "out"))
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("inventory.card.back", locale: locale),
                                            callbackData: "estate:wg:list")])
        return (lines.joined(separator: "\n"), TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    /// The card while either side holds the item, else the wagon's list, else
    /// the warehouse's root — whichever still has something to show.
    static func redrawWagon(item: Item?, message: TGMaybeInaccessibleMessage, context: Context,
                            statusLine: String? = nil) async throws {
        let screen: (text: String, markup: TGInlineKeyboardMarkup)
        if let item, let card = try await wagonCard(for: item, context: context) {
            screen = card
        } else if let list = try await wagonList(context: context) {
            screen = list
        } else {
            screen = try await warehouseRootScreen(context: context)
        }
        await editScreen(message, text: screen.text, replyMarkup: screen.markup, bot: context.bot)
        if let statusLine {
            await Controllers.estateController.postStatusBanner(statusLine, context: context)
        }
    }

    // MARK: - Dispatch

    /// Every `estate:wg:` callback. A refusal is the tap's modal, so the tap is
    /// answered late, and in the `catch` too.
    static func handleWagonCallback(data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage,
                                    context: Context) async throws -> Bool {
        let lingo = context.lingo, locale = context.session.locale
        func answer(_ alert: String? = nil) async {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: alert, showAlert: alert != nil))
        }
        let parts = data.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
        let verb = parts.count > 2 ? parts[2] : ""
        let itemId = parts.count > 3 ? parts[3] : ""
        do {
            switch verb {
            case "info":
                await answer()
                try await redrawWagon(item: ItemCatalog.find(itemId), message: message, context: context)
            case "in1", "inall", "out1", "outall":
                guard let item = ItemCatalog.find(itemId), let userId = context.session.id else {
                    await answer()
                    try await redrawWagon(item: nil, message: message, context: context)
                    return true
                }
                let loading = verb.hasPrefix("in")
                let held = loading
                    ? try await WarehouseEntry.totalQuantity(of: itemId, for: userId, on: context.db)
                    : try await WagonService.quantity(of: itemId, for: userId, on: context.db)
                let quantity = verb.hasSuffix("all") ? held : 1
                let result = loading
                    ? try await WagonService.load(itemId, quantity: quantity, for: context.session, on: context.db)
                    : try await WagonService.unload(itemId, quantity: quantity, for: context.session, on: context.db)
                if let refusal = try await refusalText(result, context: context) {
                    await answer(refusal)
                    return true
                }
                await answer()
                try await redrawWagon(item: item, message: message, context: context,
                                      statusLine: try await moveBanner(result, loading: loading, item: item, context: context))
            case "pin", "pout":
                // One piece of gear, by its row: onto the wagon from the
                // warehouse, or off the wagon into it, with its own state.
                guard let rowId = UUID(uuidString: itemId) else {
                    await answer()
                    try await redrawWagon(item: nil, message: message, context: context)
                    return true
                }
                let loading = verb == "pin"
                let itemOfRow: Item?
                if loading {
                    itemOfRow = try await WarehouseEntry.find(rowId, on: context.db).flatMap { ItemCatalog.find($0.itemId) }
                } else {
                    itemOfRow = try await WagonCargoEntry.find(rowId, on: context.db).flatMap { ItemCatalog.find($0.itemId) }
                }
                let result = loading
                    ? try await WagonService.loadPiece(warehouseRowId: rowId, for: context.session, on: context.db)
                    : try await WagonService.unloadPiece(cargoRowId: rowId, for: context.session, on: context.db)
                if case .nothingToMove = result {
                    // A copy that is gone (moved by an older button): the list
                    // as it stands is the answer.
                    await answer()
                    try await redrawWagon(item: nil, message: message, context: context)
                    return true
                }
                if let refusal = try await refusalText(result, context: context) {
                    await answer(refusal)
                    return true
                }
                await answer()
                let banner = try await itemOfRow.asyncMap { try await moveBanner(result, loading: loading, item: $0, context: context) } ?? nil
                try await redrawWagon(item: nil, message: message, context: context, statusLine: banner)
            case "typein", "typeout":
                guard ItemCatalog.find(itemId) != nil else {
                    await answer()
                    return true
                }
                try await openWagonPrompt(itemId: itemId, loading: verb == "typein", message: message, context: context)
                await answer()
            case "unloadall":
                guard let moved = try await WagonService.unloadAll(for: context.session, on: context.db) else {
                    await answer(lingo.localize("estate.wagon.not_home", locale: locale))
                    return true
                }
                if moved.moved == 0, moved.left > 0 {
                    await answer(lingo.localize("estate.warehouse.full", locale: locale))
                    return true
                }
                await answer()
                var banner: String?
                if moved.left == 0, moved.moved > 0 {
                    banner = "✅ " + lingo.localize("estate.wagon.unload_all.done", count: moved.moved, locale: locale,
                                                   interpolations: ["count": "\(moved.moved)"]) + " ⬇️"
                } else if moved.moved > 0 {
                    let used = try await WarehouseService.slotsUsed(for: context.session, on: context.db)
                    banner = "📦 " + lingo.localize("estate.wagon.unload_all.partial", locale: locale, interpolations: [
                        "count": "\(moved.moved)", "used": "\(used)",
                        "cap": "\(WarehouseService.capForLevel(context.session.estateLevel))", "left": "\(moved.left)"
                    ])
                }
                try await redrawWagon(item: nil, message: message, context: context, statusLine: banner)
            default:
                await answer()
                try await redrawWagon(item: nil, message: message, context: context)
            }
            return true
        } catch {
            await answer()
            throw error
        }
    }

    // MARK: - The typed «✏️»

    private static func openWagonPrompt(itemId: String, loading: Bool, message: TGMaybeInaccessibleMessage,
                                        context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        let free: Int
        if loading {
            free = try await WagonService.status(for: context.session, on: context.db)?.free ?? 0
        } else {
            free = try await WagonService.warehouseFree(for: context.session, on: context.db)
        }
        let prompt = lingo.localize(loading ? "estate.wagon.load_n.prompt" : "estate.wagon.unload_n.prompt", locale: locale,
                                    interpolations: ["free": lingo.localize("inventory.free", locale: locale,
                                                                            interpolations: ["free": "\(free)"])])
        let cancelLabel = "❌ " + lingo.localize("estate.warehouse.withdraw_n.cancel_button", locale: locale)
        let sent = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(message.chat.id),
            text: prompt,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: [[
                TGInlineKeyboardButton(text: cancelLabel, callbackData: "estate:wh:cancelN")
            ]]))
        ))
        await EphemeralChatState.shared.setPendingWarehouseTransfer(
            telegramId: context.session.telegramId,
            itemId: itemId,
            promptMessageId: sent.messageId,
            warehouseMessageId: message.messageId,
            warehouseIsPhoto: message.getMessage()?.photo != nil,
            direction: loading ? .load : .unload
        )
    }

    /// The typed number for a `.load` / `.unload` prompt: move it, close the
    /// prompt, redraw the wagon's card and post the outcome — the warehouse's
    /// own shape for its typed moves.
    static func finishWagonTransferN(pending: EphemeralChatState.PendingWarehouseTransfer, loading: Bool,
                                     item: Item, quantity: Int, context: Context) async throws {
        let telegramId = context.session.telegramId
        let chatId = TGChatId.chat(telegramId)
        let result = loading
            ? try await WagonService.load(item.id, quantity: quantity, for: context.session, on: context.db)
            : try await WagonService.unload(item.id, quantity: quantity, for: context.session, on: context.db)
        let banner: String
        if let refusal = try await refusalText(result, context: context) {
            banner = "❌ " + refusal
        } else {
            banner = try await moveBanner(result, loading: loading, item: item, context: context) ?? ""
        }

        _ = await EphemeralChatState.shared.takePendingWarehouseTransfer(telegramId: telegramId)
        _ = try? await context.bot.deleteMessage(params: TGDeleteMessageParams(chatId: chatId, messageId: pending.promptMessageId))

        let screen: (text: String, markup: TGInlineKeyboardMarkup)
        if let card = try await wagonCard(for: item, context: context) {
            screen = card
        } else if let list = try await wagonList(context: context) {
            screen = list
        } else {
            screen = try await warehouseRootScreen(context: context)
        }
        await editScreen(chatId: chatId, messageId: pending.warehouseMessageId, isPhoto: pending.warehouseIsPhoto,
                         text: screen.text, replyMarkup: screen.markup, bot: context.bot)
        if !banner.isEmpty {
            await Controllers.estateController.postStatusBanner(banner, context: context)
        }
    }

    // MARK: - Words for a move

    /// The modal (or, after a typed number, the banner) for a move that moved
    /// nothing. Nil when something moved.
    private static func refusalText(_ result: WagonService.MoveResult, context: Context) async throws -> String? {
        let lingo = context.lingo, locale = context.session.locale
        switch result {
        case .moved, .partial:
            return nil
        case .nothingToMove:
            return lingo.localize("estate.warehouse.nothing_to_deposit", locale: locale)
        case .notRunning:
            return lingo.localize("estate.wagon.not_running", locale: locale)
        case .wagonFull:
            let used = try await WagonService.used(for: try context.session.requireID(), on: context.db)
            return lingo.localize("estate.wagon.full", locale: locale, interpolations: [
                "used": "\(used)", "cap": "\(WagonCatalog.capacity)"
            ])
        case .warehouseFull:
            return lingo.localize("estate.warehouse.full", locale: locale)
        case .notCarried:
            return lingo.localize("estate.wagon.not_carried", locale: locale)
        case .notHere:
            return lingo.localize("estate.wagon.not_home", locale: locale)
        }
    }

    /// «✅ Сосновий брус ×100 — на возі ⬆️», or the partial line naming what
    /// stayed and why — the warehouse's own banners, which name the item
    /// without its icon.
    private static func moveBanner(_ result: WagonService.MoveResult, loading: Bool, item: Item,
                                   context: Context) async throws -> String? {
        let lingo = context.lingo, locale = context.session.locale
        let name = lingo.localize(item.nameKey, locale: locale)
        switch result {
        case .moved(let n):
            return "✅ " + lingo.localize(loading ? "estate.wagon.loaded" : "estate.wagon.unloaded", locale: locale,
                                         interpolations: ["item": name, "n": "\(n)"]) + (loading ? " ⬆️" : " ⬇️")
        case .partial(let moved, let left):
            let userId = try context.session.requireID()
            let used = loading
                ? try await WagonService.used(for: userId, on: context.db)
                : try await WarehouseService.slotsUsed(for: context.session, on: context.db)
            let cap = loading ? WagonCatalog.capacity : WarehouseService.capForLevel(context.session.estateLevel)
            return (loading ? "\(WagonDisplay.icon) " : "📦 ")
                + lingo.localize(loading ? "estate.wagon.load_partial" : "estate.wagon.unload_partial", locale: locale,
                                 interpolations: ["item": name, "n": "\(moved)", "left": "\(left)",
                                                  "used": "\(used)", "cap": "\(cap)"])
        default:
            return nil
        }
    }
}

private extension Optional {
    /// `map` for an async transform.
    func asyncMap<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
        switch self {
        case .some(let value): return try await transform(value)
        case .none: return nil
        }
    }
}
