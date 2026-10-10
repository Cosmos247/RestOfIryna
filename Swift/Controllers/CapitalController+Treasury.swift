//
//  CapitalController+Treasury.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 11.10.2026.
//
//  The palace's Treasury (2026-10-11): what zlatnyks buy, behind «🟡 Канцелярія»
//  (the player's name since the owner's rename the same night; the code keeps
//  `treasury`, as it keeps `tier` for «рівень» — and it is not the guild's
//  «🪙 Скарбниця», `guild.treasury.*`)
//  under the decree card. It opens in the palace's own bubble — every screen is
//  a caption edit of the palace photo, far under Telegram's 1,024 — and leads
//  back to it. The first version sells one thing, the class change
//  (`ClassChangeService`), on the owner's pick; the list and the prices are
//  `treasury.json`.
//
//  The screens, each from the owner's approved sample:
//  - the Treasury: the balance, where zlatnyks come from, one button per entry;
//  - the class change: the class now, the price as a `RequirementLine`, the
//    two other classes;
//  - the preview: every stat now → after, the weapon reforged, the techniques
//    renamed, and the price — computed by the purchase's own transformation;
//  - the purchase: a banner, and the Treasury redrawn with what is left.
//
//  Emoji stay out of the templates' text ahead of a placeholder (Lingo finds a
//  placeholder in UTF-16 and counts its offset in Characters); 🟡 travels in
//  the values or is prepended here.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

extension CapitalController {

    // MARK: - Dispatch

    /// Every `treasury:` callback, answered exactly once: a refusal is the
    /// modal, everything else an empty answer ahead of the redraw. A shape this
    /// build does not know — a button from a later or an earlier build — opens
    /// the Treasury, the screen every one of them belongs to.
    static func onTreasuryCallback(_ data: String, query: TGCallbackQuery, messageId: Int, isPhoto: Bool,
                                   context: Context) async throws {
        let ctrl = Controllers.capitalController
        let parts = data.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let verb = parts.count > 1 ? parts[1] : ""
        if verb == "class_ok", parts.count == 4 {
            try await ctrl.handleClassChange(itemId: parts[2], to: parts[3], query: query,
                                             messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        switch verb {
        case "back":
            try await ctrl.editToPalace(messageId: messageId, isPhoto: isPhoto, context: context)
        case "item" where parts.count == 3:
            try await ctrl.editToTreasuryItem(itemId: parts[2], messageId: messageId, isPhoto: isPhoto, context: context)
        case "class" where parts.count == 4:
            try await ctrl.editToClassPreview(itemId: parts[2], to: parts[3], messageId: messageId,
                                              isPhoto: isPhoto, context: context)
        default:
            try await ctrl.editToTreasury(messageId: messageId, isPhoto: isPhoto, context: context)
        }
    }

    // MARK: - The Treasury

    func editToTreasury(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let balance = (try? await ZlatnykService.balance(of: context.session.requireID(), on: context.db)) ?? 0
        let screen = treasuryScreen(balance: balance, lingo: context.lingo, locale: context.session.locale)
        await editTreasuryScreen(screen.text, rows: screen.rows, messageId: messageId, isPhoto: isPhoto, context: context)
    }

    /// The Treasury's text and buttons for a balance — no database, so a
    /// rehearsal can read the screen exactly as a player will.
    func treasuryScreen(balance: Int, lingo: Lingo, locale: String) -> (text: String, rows: [[TGInlineKeyboardButton]]) {
        let text = "<b>\(lingo.localize("treasury.title", locale: locale))</b>\n\n"
            + lingo.localize("treasury.body", locale: locale) + "\n\n"
            + "🟡 " + lingo.localize("treasury.balance", locale: locale, interpolations: ["balance": "\(balance)"]) + "\n"
            + lingo.localize("treasury.how_to_get", locale: locale)
        var rows: [[TGInlineKeyboardButton]] = TreasuryCatalog.items.map { item in
            [TGInlineKeyboardButton(text: lingo.localize(TreasuryCatalog.nameKey(item), locale: locale) + " · 🟡 \(item.price)",
                                    callbackData: "treasury:item:\(item.id)")]
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("treasury.button.back_to_palace", locale: locale),
                                            callbackData: "treasury:back")])
        return (text, rows)
    }

    /// An entry's card. A kind this build does not handle — content ahead of
    /// the binary, which the validator refuses — goes back to the list.
    func editToTreasuryItem(itemId: String, messageId: Int, isPhoto: Bool, context: Context) async throws {
        guard let item = TreasuryCatalog.find(itemId), let kind = TreasuryKind(rawValue: item.kind) else {
            try await editToTreasury(messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }
        switch kind {
        case .classChange:
            try await editToClassChoice(item: item, messageId: messageId, isPhoto: isPhoto, context: context)
        }
    }

    // MARK: - The class change

    func classLabel(_ cls: CharacterClass, lingo: Lingo, locale: String) -> String {
        "\(cls.icon()) " + lingo.localize("registration.class.\(cls.rawValue)", locale: locale)
    }

    private func editToClassChoice(item: TreasuryItemDTO, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let current = CharacterClass(rawValue: context.session.characterClass ?? "") ?? .warrior
        let balance = (try? await ZlatnykService.balance(of: context.session.requireID(), on: context.db)) ?? 0
        let screen = classChoiceScreen(item: item, current: current, balance: balance,
                                       lingo: context.lingo, locale: context.session.locale)
        await editTreasuryScreen(screen.text, rows: screen.rows, messageId: messageId, isPhoto: isPhoto, context: context)
    }

    func classChoiceScreen(item: TreasuryItemDTO, current: CharacterClass, balance: Int, lingo: Lingo,
                           locale: String) -> (text: String, rows: [[TGInlineKeyboardButton]]) {
        let text = "<b>\(lingo.localize(TreasuryCatalog.nameKey(item), locale: locale))</b>\n\n"
            + lingo.localize("treasury.class.body", locale: locale) + "\n\n"
            + lingo.localize("treasury.class.current", locale: locale,
                             interpolations: ["class": classLabel(current, lingo: lingo, locale: locale)]) + "\n"
            + lingo.localize("treasury.price_label", locale: locale) + "\n"
            + RequirementLine.render(label: "🟡 " + lingo.localize("treasury.zlatnyks_label", locale: locale),
                                     have: balance, need: item.price) + "\n\n"
            + lingo.localize("treasury.class.choose", locale: locale)
        let choices = CharacterClass.allCases.filter { $0 != current }.map { cls in
            TGInlineKeyboardButton(text: classLabel(cls, lingo: lingo, locale: locale),
                                   callbackData: "treasury:class:\(item.id):\(cls.rawValue)")
        }
        let rows = [choices, [TGInlineKeyboardButton(text: lingo.localize("treasury.button.back_to_treasury", locale: locale),
                                                     callbackData: "treasury:open")]]
        return (text, rows)
    }

    /// «Now → after» for one class, from `ClassChangeService.preview` — the
    /// purchase's own transformation run on a stand-in, so the screen cannot
    /// quote a number the purchase then disagrees with. Shown whatever the
    /// balance: looking is free, and the confirm refuses with the shortage.
    private func editToClassPreview(itemId: String, to raw: String, messageId: Int, isPhoto: Bool,
                                    context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let item = TreasuryCatalog.find(itemId), TreasuryKind(rawValue: item.kind) == .classChange,
              let target = CharacterClass(rawValue: raw),
              target.rawValue != context.session.characterClass else {
            try await editToTreasuryItem(itemId: itemId, messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }
        let preview = try await ClassChangeService.preview(context.session, to: target, on: context.db)
        let screen = classPreviewScreen(item: item, preview: preview, lingo: lingo, locale: locale)
        await editTreasuryScreen(screen.text, rows: screen.rows, messageId: messageId, isPhoto: isPhoto, context: context)
    }

    func classPreviewScreen(item: TreasuryItemDTO, preview: ClassChangeService.Preview, lingo: Lingo,
                            locale: String) -> (text: String, rows: [[TGInlineKeyboardButton]]) {
        let from = classLabel(preview.from, lingo: lingo, locale: locale)
        let to = classLabel(preview.to, lingo: lingo, locale: locale)
        func stat(_ icon: String, _ key: String, _ before: Int, _ after: Int) -> String {
            "\(icon) " + lingo.localize(key, locale: locale) + ": \(before) → \(after)"
        }
        var lines = [
            "<b>📜 \(from) → \(to)</b>",
            "",
            stat("❤️", "profile.health", preview.before.maxHp, preview.after.maxHp),
            stat("⚔️", "profile.attack", preview.before.attack, preview.after.attack),
            stat("🛡", "profile.defense", preview.before.defense, preview.after.defense),
            stat("🎯", "profile.accuracy", preview.before.accuracy, preview.after.accuracy),
            stat("💨", "profile.dodge", preview.before.dodge, preview.after.dodge),
            stat("💥", "profile.crit", preview.before.crit, preview.after.crit),
            ""
        ]
        if let weapon = preview.weapon {
            func named(_ itemId: String) -> String {
                guard let it = ItemCatalog.find(itemId) else { return itemId }
                let icon = it.icon.map { "\($0) " } ?? ""
                return icon + lingo.localize(ItemDisplay.nameKey(for: it, tier: weapon.tier), locale: locale)
                    + " \(weapon.durability)/\(weapon.maxDurability)"
            }
            lines.append(named(weapon.itemId) + " → " + named(preview.to.starterWeaponId))
        }
        for kind in preview.techniques {
            lines.append(lingo.localize(EstateController.techniqueNameKey(kind: kind, class: preview.from), locale: locale)
                         + " → "
                         + lingo.localize(EstateController.techniqueNameKey(kind: kind, class: preview.to), locale: locale))
        }
        lines.append("")
        lines.append(lingo.localize("treasury.class.confirm", locale: locale, interpolations: ["price": "🟡 \(item.price)"])
                     + " " + lingo.localize("treasury.class.undo.\(preview.from.rawValue)", locale: locale))
        let rows = [
            [TGInlineKeyboardButton(text: lingo.localize("treasury.button.change_class", locale: locale),
                                    callbackData: "treasury:class_ok:\(item.id):\(preview.to.rawValue)")],
            [TGInlineKeyboardButton(text: lingo.localize("treasury.button.pick_other", locale: locale),
                                    callbackData: "treasury:item:\(item.id)")]
        ]
        return (lines.joined(separator: "\n"), rows)
    }

    /// The «✅ Скріпити печаткою» tap. It names the entry and the class it was shown,
    /// so a stale confirm cannot buy something else. A refusal is the tap's
    /// only answer, as a modal; an unexpected throw is answered before it is
    /// rethrown, so the button never spins.
    private func handleClassChange(itemId: String, to raw: String, query: TGCallbackQuery, messageId: Int,
                                   isPhoto: Bool, context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        func ack() async {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        }
        func alert(_ text: String) async {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: text, showAlert: true))
        }
        guard let item = TreasuryCatalog.find(itemId), TreasuryKind(rawValue: item.kind) == .classChange,
              let target = CharacterClass(rawValue: raw) else {
            await ack()
            try await editToTreasury(messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }
        do {
            let outcome = try await ClassChangeService.perform(context.session, to: target, item: item, on: context.db)
            await ack()
            await postStatusBanner("✅ " + lingo.localize("treasury.class.done", locale: locale, interpolations: [
                "class": classLabel(outcome.to, lingo: lingo, locale: locale),
                "paid": "🟡 −\(item.price)",
                "balance": "\(outcome.balanceAfter)"
            ]), context: context)
            try await editToTreasury(messageId: messageId, isPhoto: isPhoto, context: context)
        } catch ClassChangeService.Refusal.notEnough(let have, let need) {
            await alert(lingo.localize("treasury.err.not_enough", locale: locale,
                                       interpolations: ["have": "\(have)", "need": "\(need)"]))
        } catch ClassChangeService.Refusal.inDuel {
            await alert(lingo.localize("treasury.err.in_duel", locale: locale))
        } catch ClassChangeService.Refusal.sameClass {
            // A second tap after the first committed: the banner has said it.
            await ack()
            try await editToTreasury(messageId: messageId, isPhoto: isPhoto, context: context)
        } catch {
            await ack()
            throw error
        }
    }

    // MARK: - Drawing

    private func editTreasuryScreen(_ text: String, rows: [[TGInlineKeyboardButton]], messageId: Int, isPhoto: Bool,
                                    context: Context) async {
        await editScreen(chatId: .chat(context.session.telegramId), messageId: messageId, isPhoto: isPhoto,
                         text: text, replyMarkup: TGInlineKeyboardMarkup(inlineKeyboard: rows), bot: context.bot)
    }
}
