//
//  BagCard.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.11.2026.
//
//  An item's card, and the five things its buttons do — ONE implementation for
//  both bags (2026-11-01, the owner's design): the bag at home, in town and on
//  the road (`InventoryController`, callbacks `inv:`), and the trail bag on a
//  walk (`ExplorationController`, callbacks `explore:`).
//
//  The card, drawn over the list it was opened from: the description, what a
//  dish restores — or that a raw one is an ingredient — then «🎒 У сумці: N» and
//  a taken job's ⚠️, BEFORE any tap, because the many-portion and the one-unit
//  discard act without a question. Then the buttons:
//    `eat:<id>`              «🍴 Зʼїсти» — one portion;
//    `eatn:<id>:<n>`         «До повної снаги (N)» / «Зʼїсти всі (N)» — `MealMath`,
//                            N asked again on the tap (a moved stack redraws);
//    `drop:<id>`             «🗑 Викинути 1» — at once, the owner's pick;
//    `dropall:<id>:<n>`      «🗑 Викинути всі (N)» — the question first;
//    `dropok:<id>:<n>`       its «🗑 Так, викинути» — only the count it named.
//  Gear never comes here: the workshop's «Розібрати» is the one place a piece is
//  destroyed, and the bag draws gear's own card.
//
//  Every unit a tap takes out of the bag is told to the walk in progress, if
//  there is one (`recordDeparture`): «Принесено» at the manor door nets out what
//  was eaten AND what was thrown away. Both bags report, so neither screen can
//  make the door overcount.
//

import Fluent
import Foundation
import Lingo
import SwiftTelegramBot

enum BagCard {

    /// Which bag a card belongs to: its callbacks' namespace, and where
    /// «🔙 До списку» goes back to.
    enum Route: Sendable {
        /// 🎒 Сумка at home, in town and on the road.
        case bag
        /// 🎒 Сумка on a walk.
        case trail

        var prefix: String {
            switch self {
            case .bag:   return "inv:"
            case .trail: return "explore:"
            }
        }

        func backData(for item: Item) -> String {
            switch self {
            case .bag:   return "inv:cat:\(item.type.rawValue)"
            case .trail: return "explore:items"
            }
        }

        /// Whose banner. The banner itself is the player's one status line,
        /// whichever controller posts it; the route's own keeps it readable.
        var controller: TGControllerBase {
            switch self {
            case .bag:   return Controllers.inventoryController
            case .trail: return Controllers.explorationController
            }
        }
    }

    typealias Screen = (text: String, markup: TGInlineKeyboardMarkup)

    // MARK: - The card

    /// The item's card, or nil when the bag holds none of it any more.
    static func render(_ item: Item, route: Route, context: Context) async throws -> Screen? {
        guard let userId = context.session.id else { return nil }
        let held = try await InventoryEntry.totalQuantity(of: item.id, for: userId, on: context.db)
        guard held > 0 else { return nil }
        let lingo = context.lingo, locale = context.session.locale
        let user = context.session
        let prefix = route.prefix

        let icon = item.icon.map { "\($0) " } ?? ""
        var lines = ["\(icon)<b>\(lingo.localize(item.nameKey, locale: locale))</b>"]
        if let descKey = item.descriptionKey {
            lines.append("")
            lines.append("<i>\(lingo.localize(descKey, locale: locale))</i>")
        }
        lines.append("")

        // A consumable says what it restores; one with no effect is a cooking
        // ingredient, and says so instead of carrying an «Зʼїсти» that could
        // only refuse (2026-11-01, the owner's pick).
        let consumable = VigorService.isConsumable(item)
        let edible = consumable && !item.effects.isEmpty
        if edible {
            lines.append(effectLine(item, lingo: lingo, locale: locale))
        } else if consumable {
            lines.append("🔥 " + lingo.localize("inventory.card.ingredient", locale: locale))
        }
        lines.append("🎒 " + lingo.localize("inventory.card.in_bag", locale: locale,
                                            interpolations: ["count": "\(held)"]))
        lines.append(contentsOf: await QuestWarning.lines(itemId: item.id, for: user, on: context.db,
                                                          lingo: lingo, locale: locale))

        var rows: [[TGInlineKeyboardButton]] = []
        if edible, let actionKey = item.type.actionKey {
            var row = [TGInlineKeyboardButton(text: lingo.localize(actionKey, locale: locale),
                                              callbackData: "\(prefix)eat:\(item.id)")]
            if let bulk = bulk(for: item, held: held, user: user) {
                row.append(TGInlineKeyboardButton(text: bulkLabel(bulk, lingo: lingo, locale: locale),
                                                  callbackData: "\(prefix)eatn:\(item.id):\(bulk.count)"))
            }
            rows.append(row)
        }
        // A recipe scroll — none ship since 2026-09-18, but the field and the
        // learn flow remain, and they are the bag's.
        if route == .bag, item.teachesRecipe != nil {
            rows.append([TGInlineKeyboardButton(text: lingo.localize("inventory.action.learn", locale: locale),
                                                callbackData: "inv:use:\(item.id)")])
        }
        // «Викинути 1» acts at once, «Викинути всі (N)» asks first (the
        // owner's pick); a lone unit gets one «Викинути», which acts at once.
        if held >= 2 {
            rows.append([
                TGInlineKeyboardButton(text: lingo.localize("inventory.action.drop_one", locale: locale),
                                       callbackData: "\(prefix)drop:\(item.id)"),
                TGInlineKeyboardButton(text: "🗑 " + lingo.localize("inventory.action.drop_all", locale: locale,
                                                                    interpolations: ["count": "\(held)"]),
                                       callbackData: "\(prefix)dropall:\(item.id):\(held)")
            ])
        } else {
            rows.append([TGInlineKeyboardButton(text: lingo.localize("inventory.action.drop", locale: locale),
                                                callbackData: "\(prefix)drop:\(item.id)")])
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("inventory.card.back", locale: locale),
                                            callbackData: route.backData(for: item))])
        return (lines.joined(separator: "\n"), TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    /// «🍖 +72 Снаги · ❤️ +18 ОЗ» — read from the item's own `effects`, never
    /// typed, so a re-priced dish changes its card by itself.
    static func effectLine(_ item: Item, lingo: Lingo, locale: String) -> String {
        item.effects.map { effect -> String in
            switch effect {
            case .restoreVigor(let amount):
                return "🍖 " + lingo.localize("inventory.card.vigor", locale: locale, interpolations: ["amount": "\(amount)"])
            case .restoreHP(let amount):
                return "❤️ " + lingo.localize("inventory.card.hp", locale: locale, interpolations: ["amount": "\(amount)"])
            }
        }.joined(separator: " · ")
    }

    /// The many-portion button for this player and this stack, or nil.
    static func bulk(for item: Item, held: Int, user: User) -> MealMath.Bulk? {
        MealMath.bulk(vigor: user.vigor, maxVigor: user.maxVigor,
                      vigorPerPortion: VigorService.vigorPerPortion(of: item), held: held)
    }

    /// «🍴 До повної снаги (N)» or «🍴 Зʼїсти всі (N)» — the 🍴 in Swift,
    /// because Lingo drops a `%{}` that follows an emoji in its template.
    static func bulkLabel(_ bulk: MealMath.Bulk, lingo: Lingo, locale: String) -> String {
        switch bulk {
        case .toFull(let count):
            return "🍴 " + lingo.localize("inventory.action.eat_to_full", locale: locale, interpolations: ["count": "\(count)"])
        case .all(let count):
            return "🍴 " + lingo.localize("inventory.action.eat_all", locale: locale, interpolations: ["count": "\(count)"])
        }
    }

    /// «🥔 Картопля — викинути всі 6? Повернути не вийде.», a taken job's ⚠️
    /// under it, and «🗑 Так, викинути» carrying the count it names — the
    /// bag's as it stands now. Nil under two: there is no «all» to ask about.
    static func dropAllQuestion(_ item: Item, route: Route, context: Context) async throws -> Screen? {
        guard let userId = context.session.id else { return nil }
        let lingo = context.lingo, locale = context.session.locale
        let held = try await InventoryEntry.totalQuantity(of: item.id, for: userId, on: context.db)
        guard held >= 2 else { return nil }
        let name = (item.icon.map { "\($0) " } ?? "") + lingo.localize(item.nameKey, locale: locale)
        var lines = [lingo.localize("inventory.drop_all.question", locale: locale,
                                    interpolations: ["item": name, "count": "\(held)"])]
        lines.append(contentsOf: await QuestWarning.lines(itemId: item.id, for: context.session, on: context.db,
                                                          lingo: lingo, locale: locale))
        let markup = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: lingo.localize("inventory.drop_all.confirm", locale: locale),
                                   callbackData: "\(route.prefix)dropok:\(item.id):\(held)"),
            TGInlineKeyboardButton(text: lingo.localize("inventory.drop_all.cancel", locale: locale),
                                   callbackData: "\(route.prefix)info:\(item.id)")
        ]])
        return (lines.joined(separator: "\n"), markup)
    }

    // MARK: - Gear's card

    /// The text of one gear copy's card — in the bag and in the warehouse alike
    /// (2026-11-01; it was the bag's `gearDetailCard`). Name (+tier for weapons),
    /// lore, the stats it grants at full condition (tier-aware; armour at its
    /// enchant level), and a condition block (durability, broken /
    /// dulled warning, enchant level). Mirrors the workshop recipe-detail layout.
    static func gearText(item: Item, state row: GearState, lingo: Lingo, locale: String) -> String {
        let name = lingo.localize(ItemDisplay.nameKey(for: item, tier: row.tier), locale: locale)
        let icon = ItemDisplay.rarityPrefix(for: item) + (item.icon.map { "\($0) " } ?? "")
        var header = "\(icon)<b>\(name)</b>"
        // «рівень 2», never a Latin «T2» (2026-11-01, the owner): the weapon's
        // rung is «рівень» on every Ukrainian screen.
        if WeaponUpgradeCatalog.isUpgradable(item.id) {
            header += " <i>(" + lingo.localize("inventory.detail.weapon_tier", locale: locale,
                                               interpolations: ["tier": "\(row.tier)"]) + ")</i>"
        }
        var lines: [String] = [header]

        if let descKey = ItemDisplay.descriptionKey(for: item, tier: row.tier) {
            lines.append("")
            lines.append("<i>\(lingo.localize(descKey, locale: locale))</i>")
        }

        // Stats at full condition (so the player sees the piece's real value).
        let s = EquipmentService.stats(ofItem: item.id, tier: row.tier, enchantLevel: row.enchantLevel)
        var statLines: [String] = []
        // Same six stats, in the same order, as `ItemCard` and `GearStats`
        // itself. HP was missing here until 2026-09-11, which hid the whole
        // Forester set's HP everywhere except the shop card the player saw
        // once before buying. `profile.health` rather than a new
        // `workshop.stats.hp`: a sixth duplicated pair is what produced the
        // Влучність / Точність split. Crit carries NO `%` — it is a rating
        // converted through a curve, so "+5%" is 4.2% at level 1 and 1.35% at
        // the cap.
        if s.attack   != 0 { statLines.append("   +\(s.attack) ⚔️ \(lingo.localize("workshop.stats.attack", locale: locale))") }
        if s.defense  != 0 { statLines.append("   +\(s.defense) 🛡 \(lingo.localize("workshop.stats.defense", locale: locale))") }
        if s.hp       != 0 { statLines.append("   +\(s.hp) ❤️ \(lingo.localize("profile.health", locale: locale))") }
        if s.crit     != 0 { statLines.append("   +\(s.crit) 💥 \(lingo.localize("workshop.stats.crit", locale: locale))") }
        if s.dodge    != 0 { statLines.append("   +\(s.dodge) 💨 \(lingo.localize("workshop.stats.dodge", locale: locale))") }
        if s.accuracy != 0 { statLines.append("   +\(s.accuracy) 🎯 \(lingo.localize("workshop.stats.accuracy", locale: locale))") }
        if !statLines.isEmpty {
            lines.append("")
            lines.append("<b>\(lingo.localize("workshop.detail.stats", locale: locale))</b>")
            lines.append(contentsOf: statLines)
        }

        // Condition — only durable gear (armor / weapon).
        let isArmor  = item.slot.map { GearConditionService.armorSlots.contains($0.rawValue) } == true
        let isWeapon = item.slot.map { GearConditionService.weaponSlots.contains($0.rawValue) } == true
        if isArmor || isWeapon {
            lines.append("")
            lines.append("<b>\(lingo.localize("inventory.detail.condition", locale: locale))</b>")
            lines.append("   ⚙️ \(lingo.localize("inventory.detail.durability", locale: locale)): \(row.durability)/\(row.maxDurability)")
            if row.durability <= 0 {
                lines.append("   \(lingo.localize(isWeapon ? "inventory.detail.weapon_dulled" : "inventory.detail.broken", locale: locale))")
            }
            if isArmor && row.enchantLevel > 0 {
                lines.append("   ✨ \(lingo.localize("inventory.detail.enchant", locale: locale)): +\(row.enchantLevel)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Banners

    /// «✅ Бенкет Намісника × 2 — +105 снаги (125/125), +36 ОЗ (96/98), 🍖 снага повна»:
    /// what the meal restored and where each pool stands now, «× N» only for
    /// more than one portion. Topping out is named, because Vigor has no
    /// passive regeneration: every point past full was paid for and lost.
    static func mealBanner(item: Item, eaten: Int, result: ConsumeResult, context: Context) -> String {
        let lingo = context.lingo, locale = context.session.locale, user = context.session
        var parts: [String] = []
        if result.vigorRestored > 0 {
            parts.append(lingo.localize("vigor.restored", locale: locale, interpolations: [
                "amount":  "\(result.vigorRestored)",
                "current": "\(user.vigor)",
                "max":     "\(user.maxVigor)"
            ]))
        }
        if result.hpRestored > 0 {
            parts.append(lingo.localize("hp.restored", locale: locale, interpolations: [
                "amount":  "\(result.hpRestored)",
                "current": "\(user.hp)",
                "max":     "\(user.effectiveMaxHp)"
            ]))
        }
        if user.vigor >= user.maxVigor {
            parts.append("🍖 " + lingo.localize("vigor.full", locale: locale))
        }
        if user.hp >= user.effectiveMaxHp {
            parts.append("❤️ " + lingo.localize("hp.full", locale: locale))
        }
        let count = eaten > 1 ? " × \(eaten)" : ""
        return "✅ \(lingo.localize(item.nameKey, locale: locale))\(count) — " + parts.joined(separator: ", ")
    }

    /// «🗑 Викинуто: 🥔 Картопля × 6» — the 🗑 in Swift, ahead of the template.
    static func droppedBanner(item: Item, count: Int, context: Context) -> String {
        let locale = context.session.locale
        let name = (item.icon.map { "\($0) " } ?? "") + context.lingo.localize(item.nameKey, locale: locale)
        return "🗑 " + context.lingo.localize("inventory.dropped", locale: locale,
                                             interpolations: ["item": name, "count": "\(count)"])
    }

    // MARK: - The actions

    private static let verbs = ["eat:", "eatn:", "drop:", "dropall:", "dropok:"]

    /// True when `data` is one of the card's five verbs under `route`.
    static func isAction(_ data: String, route: Route) -> Bool {
        verbs.contains { data.hasPrefix(route.prefix + $0) }
    }

    /// The card after a tap — or, nothing of the item left, `list`: the list
    /// it was opened from. `statusLine` goes out as the banner under it.
    static func redraw(_ item: Item, route: Route, message: TGMaybeInaccessibleMessage, context: Context,
                       statusLine: String? = nil,
                       list: (Item) async throws -> Screen) async throws {
        let screen: Screen
        if let card = try await render(item, route: route, context: context) {
            screen = card
        } else {
            screen = try await list(item)
        }
        await editScreen(message, text: screen.text, replyMarkup: screen.markup, bot: context.bot)
        if let statusLine {
            await route.controller.postStatusBanner(statusLine, context: context)
        }
    }

    /// A tap on one of the card's five verbs (`isAction`). Refused while the
    /// governor holds the bag — the same modal as every other bag button.
    static func handle(_ data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage,
                       context: Context, route: Route,
                       list: (Item) async throws -> Screen) async throws -> Bool {
        let ack = TGAnswerCallbackQueryParams(callbackQueryId: query.id)
        if let run = try await InventoryController.passiveRun(holding: context.session, on: context.db) {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: InventoryController.passiveLockAlert(run, context: context),
                showAlert: true))
            return true
        }
        let prefix = route.prefix

        if data.hasPrefix(prefix + "eat:") {
            let itemId = String(data.dropFirst((prefix + "eat:").count))
            return try await eat(itemId: itemId, expected: nil, query: query, message: message,
                                 context: context, route: route, list: list)
        }
        if data.hasPrefix(prefix + "eatn:") {
            guard case let (itemId, count)? = idAndCount(data, prefix: prefix + "eatn:") else {
                _ = try? await context.bot.answerCallbackQuery(params: ack)
                return true
            }
            return try await eat(itemId: itemId, expected: count, query: query, message: message,
                                 context: context, route: route, list: list)
        }

        // The three discards answer first: none of them refuses with a modal.
        _ = try? await context.bot.answerCallbackQuery(params: ack)

        if data.hasPrefix(prefix + "dropall:") {
            guard case let (itemId, _)? = idAndCount(data, prefix: prefix + "dropall:"),
                  let item = ItemCatalog.find(itemId), item.type != .gear else { return true }
            try await askDropAll(item, route: route, message: message, context: context, list: list)
            return true
        }
        if data.hasPrefix(prefix + "dropok:") {
            guard case let (itemId, count)? = idAndCount(data, prefix: prefix + "dropok:"),
                  let item = ItemCatalog.find(itemId), item.type != .gear,
                  let userId = context.session.id else { return true }
            // Only the count the question named. A bag that holds a different
            // number by now gets the question again, with that number.
            let held = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: context.db)
            guard held == count else {
                try await askDropAll(item, route: route, message: message, context: context, list: list)
                return true
            }
            try await drop(item, count: count, route: route, message: message, context: context, list: list)
            return true
        }
        if data.hasPrefix(prefix + "drop:") {
            let itemId = String(data.dropFirst((prefix + "drop:").count))
            guard let item = ItemCatalog.find(itemId), item.type != .gear else { return true }
            try await drop(item, count: 1, route: route, message: message, context: context, list: list)
            return true
        }
        return true
    }

    /// `<prefix><itemId>:<count>` → the pair. Item ids carry dots, never a
    /// colon, so the count is whatever follows the last one.
    static func idAndCount(_ data: String, prefix: String) -> (String, Int)? {
        let rest = data.dropFirst(prefix.count)
        guard let colon = rest.lastIndex(of: ":"),
              let count = Int(rest[rest.index(after: colon)...]), count > 0 else { return nil }
        let itemId = String(rest[..<colon])
        return itemId.isEmpty ? nil : (itemId, count)
    }

    /// One portion (`expected` nil), or the many-portion button's N. The N is
    /// asked again here: a stack or a pool that moved since the card was drawn
    /// (a meal in another window) redraws the card with the fresh number and
    /// eats nothing. Every portion goes through `VigorService.consume`, the
    /// single tap's own arithmetic. Answers late — a refusal is a modal — so a
    /// throw answers on its way out rather than spinning the button.
    private static func eat(itemId: String, expected: Int?, query: TGCallbackQuery,
                            message: TGMaybeInaccessibleMessage, context: Context, route: Route,
                            list: (Item) async throws -> Screen) async throws -> Bool {
        let ack = TGAnswerCallbackQueryParams(callbackQueryId: query.id)
        do {
            let user = context.session
            guard let item = ItemCatalog.find(itemId), VigorService.isConsumable(item), !item.effects.isEmpty,
                  let userId = user.id else {
                _ = try? await context.bot.answerCallbackQuery(params: ack)
                return true
            }
            let held = try await InventoryEntry.totalQuantity(of: itemId, for: userId, on: context.db)
            let portions: Int
            if let expected {
                guard let bulk = bulk(for: item, held: held, user: user), bulk.count == expected else {
                    _ = try? await context.bot.answerCallbackQuery(params: ack)
                    try await redraw(item, route: route, message: message, context: context, list: list)
                    return true
                }
                portions = expected
            } else {
                guard held > 0 else {
                    _ = try? await context.bot.answerCallbackQuery(params: ack)
                    try await redraw(item, route: route, message: message, context: context, list: list)
                    return true
                }
                portions = 1
            }

            let before = (vigor: user.vigor, hp: user.hp)
            guard let meal = VigorService.consume(item, portions: portions, user: user) else {
                let text = context.lingo.localize("consume.no_effect", locale: user.locale)
                _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                    callbackQueryId: query.id, text: text, showAlert: true))
                return true
            }
            // The session is the cached `User`: a meal the bag cannot pay for
            // must not stay in it to be saved by the next tap.
            guard try await InventoryEntry.remove(itemId, quantity: meal.eaten, from: user, on: context.db) else {
                user.vigor = before.vigor
                user.hp = before.hp
                _ = try? await context.bot.answerCallbackQuery(params: ack)
                try await redraw(item, route: route, message: message, context: context, list: list)
                return true
            }
            try await user.saveAndCache(in: context.db)
            await recordDeparture(itemId: itemId, eaten: meal.eaten, dropped: 0, context: context)
            _ = try? await context.bot.answerCallbackQuery(params: ack)
            try await redraw(item, route: route, message: message, context: context,
                             statusLine: mealBanner(item: item, eaten: meal.eaten, result: meal.result, context: context),
                             list: list)
            return true
        } catch {
            _ = try? await context.bot.answerCallbackQuery(params: ack)
            throw error
        }
    }

    /// Takes `count` units out of the bag — all or none, `InventoryEntry.remove`
    /// — names them in the banner and redraws.
    private static func drop(_ item: Item, count: Int, route: Route, message: TGMaybeInaccessibleMessage,
                             context: Context, list: (Item) async throws -> Screen) async throws {
        var banner: String?
        if try await InventoryEntry.remove(item.id, quantity: count, from: context.session, on: context.db) {
            await recordDeparture(itemId: item.id, eaten: 0, dropped: count, context: context)
            banner = droppedBanner(item: item, count: count, context: context)
        }
        try await redraw(item, route: route, message: message, context: context, statusLine: banner, list: list)
    }

    private static func askDropAll(_ item: Item, route: Route, message: TGMaybeInaccessibleMessage,
                                   context: Context, list: (Item) async throws -> Screen) async throws {
        if let question = try await dropAllQuestion(item, route: route, context: context) {
            await editScreen(message, text: question.text, replyMarkup: question.markup, bot: context.bot)
        } else {
            try await redraw(item, route: route, message: message, context: context, list: list)
        }
    }

    /// Tells the walk in progress what left the bag, so the manor door's
    /// «Принесено» nets it out. Best-effort, as a meal on the trail always
    /// was: the units are gone already, and a throw here would leave the tap
    /// unanswered. A row with no haul (a passive run, a walk begun before the
    /// haul existed) is left alone by `recordHaul`.
    private static func recordDeparture(itemId: String, eaten: Int, dropped: Int, context: Context) async {
        guard let state = try? await ExplorationState.current(for: context.session, on: context.db),
              state.haul != nil else { return }
        state.recordHaul { haul in
            haul.eat(itemId, quantity: eaten)
            haul.drop(itemId, quantity: dropped)
        }
        try? await state.save(on: context.db)
    }
}
