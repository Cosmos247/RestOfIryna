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
        try await ctrl.showStub(context: context)
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
        let text = renderRoot(session: context.session, lingo: context.lingo)
        let inline = rootKeyboard(lingo: context.lingo, locale: context.session.locale)

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

    fileprivate func rootKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let home = lingo.localize("estate.home", locale: locale)
        let plot = lingo.localize("estate.plot", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: home, callbackData: "estate:home"),
            TGInlineKeyboardButton(text: plot, callbackData: "estate:plot")
        ]])
    }

    fileprivate func renderHome(lingo: Lingo, locale: String) -> String {
        let title = lingo.localize("estate.home", locale: locale)
        let description = lingo.localize("estate.home.description", locale: locale)
        return "<b>\(title)</b>\n\n\(description)"
    }

    fileprivate func homeKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let workshop = lingo.localize("estate.workshop", locale: locale)
        let kitchen = lingo.localize("estate.kitchen", locale: locale)
        let warehouse = lingo.localize("estate.warehouse", locale: locale)
        let back = lingo.localize("estate.back_root", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [
            [TGInlineKeyboardButton(text: workshop,  callbackData: "estate:home:workshop")],
            [TGInlineKeyboardButton(text: kitchen,   callbackData: "estate:home:kitchen")],
            [TGInlineKeyboardButton(text: warehouse, callbackData: "estate:home:warehouse")],
            [TGInlineKeyboardButton(text: back,      callbackData: "estate:root")]
        ])
    }

    /// Generic stub renderer for a not-yet-implemented location inside the estate.
    fileprivate func renderStub(titleKey: String, lingo: Lingo, locale: String) -> String {
        let title = lingo.localize(titleKey, locale: locale)
        let msg = lingo.localize("stub.coming_soon", locale: locale)
        return "<b>\(title)</b>\n\n\(msg)"
    }

    fileprivate func backToRootKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let back = lingo.localize("estate.back_root", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: back, callbackData: "estate:root")
        ]])
    }

    fileprivate func backToHomeKeyboard(lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        let back = lingo.localize("estate.back_home", locale: locale)
        return TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: back, callbackData: "estate:home")
        ]])
    }
}

// MARK: - Callback Queries

extension EstateController {
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data, data.hasPrefix("estate:") else { return false }

        let ctrl = Controllers.estateController
        let locale = context.session.locale

        let text: String
        let inline: TGInlineKeyboardMarkup

        switch data {
        case "estate:root":
            text = ctrl.renderRoot(session: context.session, lingo: context.lingo)
            inline = ctrl.rootKeyboard(lingo: context.lingo, locale: locale)
        case "estate:home":
            text = ctrl.renderHome(lingo: context.lingo, locale: locale)
            inline = ctrl.homeKeyboard(lingo: context.lingo, locale: locale)
        case "estate:plot":
            text = ctrl.renderStub(titleKey: "estate.plot", lingo: context.lingo, locale: locale)
            inline = ctrl.backToRootKeyboard(lingo: context.lingo, locale: locale)
        case "estate:home:workshop":
            text = ctrl.renderStub(titleKey: "estate.workshop", lingo: context.lingo, locale: locale)
            inline = ctrl.backToHomeKeyboard(lingo: context.lingo, locale: locale)
        case "estate:home:kitchen":
            text = ctrl.renderStub(titleKey: "estate.kitchen", lingo: context.lingo, locale: locale)
            inline = ctrl.backToHomeKeyboard(lingo: context.lingo, locale: locale)
        case "estate:home:warehouse":
            text = ctrl.renderStub(titleKey: "estate.warehouse", lingo: context.lingo, locale: locale)
            inline = ctrl.backToHomeKeyboard(lingo: context.lingo, locale: locale)
        default:
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return true
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
}
