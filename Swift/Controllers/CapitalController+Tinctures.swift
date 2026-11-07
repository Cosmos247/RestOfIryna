//
//  CapitalController+Tinctures.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.11.2026.
//
//  The fortune teller's tinctures (2026-11-07, the owner's idea,
//  `content/spec/spec-tinctures.md`): «🧪 Настоянки» on her screen opens this
//  one in the same bubble, and «🔙 Назад» leads back through her own
//  `fortune:show`. Every screen is a caption edit of her photo, so the list is
//  BUTTONS: a caption stops at 1,024.
//
//  The screens, each from the owner's approved sample:
//  - the list: the room, her words, one button per tincture;
//  - the card: what it does, then what it asks — counted in the BAG alone, as
//    the Master's are, because the capital has no warehouse — and her fee;
//    «🧪 Зварити» and «📌 У нотатник» under it;
//  - the brew: a banner, and the card redrawn with what is left. A refusal is a
//    modal and leaves the card standing.
//
//  The brew itself is `TinctureService`.
//

import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

extension CapitalController {

    // MARK: - Dispatch

    /// Every `tincture:` callback, answered exactly once. A shape this build
    /// does not know, or a recipe the content no longer holds, opens the list,
    /// the screen every one of them belongs to.
    static func onTinctureCallback(_ data: String, query: TGCallbackQuery, messageId: Int, isPhoto: Bool,
                                   context: Context) async throws {
        let ctrl = Controllers.capitalController
        let parts = data.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let verb = parts.count > 1 ? parts[1] : ""
        let recipe = parts.count == 3 ? TinctureService.find(parts[2]) : nil
        switch (verb, recipe) {
        case ("brew", let recipe?):
            try await ctrl.handleBrew(recipe, query: query, messageId: messageId, isPhoto: isPhoto, context: context)
        case ("pin", let recipe?):
            if try await RecipeNoteDisplay.toggle(.tincture(recipe.id), query: query, context: context) {
                try await ctrl.editToTinctureCard(recipe, messageId: messageId, isPhoto: isPhoto, context: context)
            }
        case ("card", let recipe?):
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            try await ctrl.editToTinctureCard(recipe, messageId: messageId, isPhoto: isPhoto, context: context)
        default:
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            await ctrl.editToTinctures(messageId: messageId, isPhoto: isPhoto, context: context)
        }
    }

    // MARK: - The list

    func editToTinctures(messageId: Int, isPhoto: Bool, context: Context) async {
        let screen = tinctureScreen(lingo: context.lingo, locale: context.session.locale)
        await editTinctureScreen(screen.text, rows: screen.rows, messageId: messageId, isPhoto: isPhoto, context: context)
    }

    /// The list's text and buttons — no database, so what the player reads is a
    /// value.
    func tinctureScreen(lingo: Lingo, locale: String) -> (text: String, rows: [[TGInlineKeyboardButton]]) {
        let text = "<b>\(lingo.localize("tincture.title", locale: locale))</b>\n\n"
            + lingo.localize("tincture.body", locale: locale) + "\n\n"
            + "<i>\(lingo.localize("tincture.quote", locale: locale))</i>"
        var rows = TinctureService.recipes.map { recipe in
            [TGInlineKeyboardButton(text: itemLabel(recipe.output.itemId, lingo: lingo, locale: locale),
                                    callbackData: "tincture:card:\(recipe.id)")]
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("capital.fortune.button.back", locale: locale),
                                            callbackData: "fortune:show")])
        return (text, rows)
    }

    // MARK: - The card

    func editToTinctureCard(_ recipe: Recipe, messageId: Int, isPhoto: Bool, context: Context) async throws {
        let held = try await TinctureService.held(recipe, for: context.session, on: context.db)
        let pinned = try await RecipeNoteService.isPinned(.tincture(recipe.id), for: context.session, on: context.db)
        guard let card = tinctureCard(recipe, held: held, silver: context.session.silver, pinned: pinned,
                                      lingo: context.lingo, locale: context.session.locale) else {
            await editToTinctures(messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }
        await editTinctureScreen(card.text, rows: card.rows, messageId: messageId, isPhoto: isPhoto, context: context)
    }

    /// A card's text and buttons for what the bag holds and what the purse
    /// holds. Nil when the recipe's output left the content.
    func tinctureCard(_ recipe: Recipe, held: [String: Int], silver: Int, pinned: Bool,
                      lingo: Lingo, locale: String) -> (text: String, rows: [[TGInlineKeyboardButton]])? {
        guard let item = ItemCatalog.find(recipe.output.itemId) else { return nil }
        var lines = ["<b>\(itemLabel(item.id, lingo: lingo, locale: locale))</b>", ""]
        if let description = item.descriptionKey {
            lines += ["<i>\(lingo.localize(description, locale: locale))</i>", ""]
        }
        lines += [BagCard.effectLine(item, lingo: lingo, locale: locale), ""]
        lines += recipe.inputs.map {
            RequirementLine.item($0.itemId, have: held[$0.itemId] ?? 0, need: $0.quantity,
                                 lingo: lingo, locale: locale, indent: "")
        }
        lines.append(RequirementLine.silver(have: silver, need: recipe.silverFee, lingo: lingo, locale: locale, indent: ""))
        let rows: [[TGInlineKeyboardButton]] = [
            [TGInlineKeyboardButton(text: lingo.localize(recipe.category.actionButtonKey, locale: locale),
                                    callbackData: "tincture:brew:\(recipe.id)")],
            RecipeNoteDisplay.pinRow(pinned: pinned, callbackData: "tincture:pin:\(recipe.id)", lingo: lingo, locale: locale),
            [TGInlineKeyboardButton(text: lingo.localize("capital.fortune.button.back", locale: locale),
                                    callbackData: recipe.category.backCallbackData)]
        ]
        return (lines.joined(separator: "\n"), rows)
    }

    // MARK: - The brew

    /// A refusal is a modal, which must be the tap's only answer, so this
    /// answers late, and a throw answers on its way out rather than spinning
    /// the button.
    private func handleBrew(_ recipe: Recipe, query: TGCallbackQuery, messageId: Int, isPhoto: Bool,
                            context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        func alert(_ text: String) async {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: text, showAlert: true))
        }
        let result: TinctureService.BrewResult
        do {
            result = try await TinctureService.brew(recipe, for: context.session, on: context.db)
        } catch {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            throw error
        }
        switch result {
        case .brewed(let itemId, let quantity, let fee):
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            // 🧪 and 🪙 arrive inside values or after the template: Lingo drops
            // a `%{}` that follows an emoji in its template.
            let brewed = lingo.localize(recipe.category.craftedAlertKey, locale: locale, interpolations: [
                "item": itemLabel(itemId, lingo: lingo, locale: locale), "qty": "\(quantity)"
            ])
            await postStatusBanner("✅ \(brewed) · \(FortuneDisplay.silver(-fee))", context: context)
            try await editToTinctureCard(recipe, messageId: messageId, isPhoto: isPhoto, context: context)
        case .missingMaterials(let shortages):
            await alert(RequirementLine.shortageModal(shortages, lingo: lingo, locale: locale))
        case .notEnoughSilver(let have, let need):
            await alert(lingo.localize("capital.trader.not_enough_silver", locale: locale,
                                       interpolations: ["have": "\(have)", "need": "\(need)"]))
        case .noRoom:
            await alert(lingo.localize("tincture.no_room", locale: locale))
        }
    }

    private func editTinctureScreen(_ text: String, rows: [[TGInlineKeyboardButton]], messageId: Int, isPhoto: Bool,
                                    context: Context) async {
        await editScreen(chatId: .chat(context.session.telegramId), messageId: messageId, isPhoto: isPhoto,
                         text: text, replyMarkup: TGInlineKeyboardMarkup(inlineKeyboard: rows), bot: context.bot)
    }
}
