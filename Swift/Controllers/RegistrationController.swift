//
//  RegistrationController.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Registration Controller Logic
// Steps: 0 = language, 1 = nickname, 2 = class, 3 = estate name
final class Registration: TGControllerBase, @unchecked Sendable {
    typealias T = Registration

    // MARK: - Controller Lifecycle
    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()]     = onStart
            router.unmatched                     = unmatched
            router[.callback_query(data: nil)]   = Registration.onCallbackQuery
        }
        await processRouterForEachName(router)
    }

    public func onStart(context: Context) async throws -> Bool {
        context.session.registrationStep = 0
        try await context.session.saveAndCache(in: context.db)
        try await showLanguageSelection(context: context)
        return true
    }

    override func unmatched(context: Context) async throws -> Bool {
        guard let text = context.update.message?.text, !text.isEmpty else {
            return try await showCurrentStep(context: context)
        }

        switch context.session.registrationStep {
        case 1:
            return try await handleNicknameInput(context: context, text: text)
        case 3:
            return try await handleEstateNameInput(context: context, text: text)
        default:
            return try await showCurrentStep(context: context)
        }
    }

    /// Re-show the current registration step prompt
    private func showCurrentStep(context: Context) async throws -> Bool {
        switch context.session.registrationStep {
        case 1:
            try await promptNickname(context: context)
        case 2:
            try await promptClassSelection(context: context)
        case 3:
            try await promptEstateName(context: context)
        default:
            try await showLanguageSelection(context: context)
        }
        return true
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        return TGReplyMarkup.replyKeyboardRemove(TGReplyKeyboardRemove(removeKeyboard: true))
    }

    // MARK: - Step 0: Language Selection

    private func showLanguageSelection(context: Context) async throws {
        let tgName = context.session.firstName ?? context.session.name
        var greeting = "👋 Welcome, \(tgName)!\n"
        var inlineKeyboard: [[TGInlineKeyboardButton]] = []
        for locale in SupportedLocale.allCases {
            greeting.append("\n- \(context.lingo.localize("registration", locale: locale))")
            let langName = context.lingo.localize("lang.name", locale: locale)
            let button = TGInlineKeyboardButton(text: "\(locale.flag()) \(langName)", callbackData: "set_lang:\(locale.rawValue)")
            inlineKeyboard.append([button])
        }
        let markup = TGReplyMarkup.inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: inlineKeyboard))
        try await context.bot.sendMessage(session: context.session, text: greeting, parseMode: .html, replyMarkup: markup)
    }

    // MARK: - Step 1: Nickname

    func promptNickname(context: Context) async throws {
        let prompt = context.lingo.localize("registration.nickname.prompt", locale: context.session.locale)
        try await context.bot.sendMessage(session: context.session, text: prompt, parseMode: .html)
    }

    private func handleNicknameInput(context: Context, text: String) async throws -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count < 2 {
            let error = context.lingo.localize("registration.nickname.too_short", locale: context.session.locale)
            try await context.bot.sendMessage(session: context.session, text: error)
            return true
        }
        if trimmed.count > 20 {
            let error = context.lingo.localize("registration.nickname.too_long", locale: context.session.locale)
            try await context.bot.sendMessage(session: context.session, text: error)
            return true
        }

        context.session.nickname = trimmed
        context.session.registrationStep = 2
        try await context.session.saveAndCache(in: context.db)
        try await promptClassSelection(context: context)
        return true
    }

    // MARK: - Step 2: Class Selection

    private func promptClassSelection(context: Context) async throws {
        let locale = context.session.locale
        let prompt = context.lingo.localize("registration.class.prompt", locale: locale)

        var text = "\(prompt)\n"
        var inlineKeyboard: [[TGInlineKeyboardButton]] = []

        for cls in CharacterClass.allCases {
            let name = context.lingo.localize("registration.class.\(cls.rawValue)", locale: locale)
            let desc = context.lingo.localize("registration.class.\(cls.rawValue).desc", locale: locale)
            text += "\n\(cls.icon()) <b>\(name)</b> — \(desc)"
            let button = TGInlineKeyboardButton(text: "\(cls.icon()) \(name)", callbackData: "set_class:\(cls.rawValue)")
            inlineKeyboard.append([button])
        }

        let markup = TGReplyMarkup.inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: inlineKeyboard))
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    // MARK: - Step 3: Estate Name

    func promptEstateName(context: Context) async throws {
        let prompt = context.lingo.localize("registration.estate.prompt", locale: context.session.locale)
        try await context.bot.sendMessage(session: context.session, text: prompt, parseMode: .html)
    }

    private func handleEstateNameInput(context: Context, text: String) async throws -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count < 2 {
            let error = context.lingo.localize("registration.estate.too_short", locale: context.session.locale)
            try await context.bot.sendMessage(session: context.session, text: error)
            return true
        }
        if trimmed.count > 30 {
            let error = context.lingo.localize("registration.estate.too_long", locale: context.session.locale)
            try await context.bot.sendMessage(session: context.session, text: error)
            return true
        }

        context.session.estateName = trimmed
        try await completeRegistration(context: context)
        return true
    }

    // MARK: - Complete Registration

    private func completeRegistration(context: Context) async throws {
        let locale = context.session.locale
        let nickname = context.session.nickname ?? "?"
        let cls = CharacterClass(rawValue: context.session.characterClass ?? "") ?? .warrior
        let clsName = context.lingo.localize("registration.class.\(cls.rawValue)", locale: locale)
        let estate = context.session.estateName ?? "?"

        let complete = context.lingo.localize("registration.complete", locale: locale, interpolations: [
            "nickname": nickname,
            "class": "\(cls.icon()) \(clsName)",
            "estate": estate
        ])

        let mainController = Controllers.mainController
        context.session.routerName = mainController.routerName
        context.session.registrationStep = 4
        try await context.session.saveAndCache(in: context.db)
        try await mainController.showMainMenu(context: context, text: complete)
    }
}

// MARK: - Callback Queries Processing
extension Registration {
    static func onCallbackQuery(context: Context) async throws -> Bool {
        guard let query = context.update.callbackQuery else { return false }
        guard let message = query.message else { return false }
        guard let data = query.data else { return false }

        let chatId = TGChatId.chat(message.chat.id)
        let deleteParams = TGDeleteMessageParams(chatId: chatId, messageId: message.messageId)
        try await context.bot.deleteMessage(params: deleteParams)

        // Language selection callback
        if data.starts(with: "set_lang:") {
            let locale = data.replacingOccurrences(of: "set_lang:", with: "")
            context.session.locale = locale
            context.session.registrationStep = 1
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.registration.promptNickname(context: context)
            return true
        }

        // Class selection callback
        if data.starts(with: "set_class:") {
            let cls = data.replacingOccurrences(of: "set_class:", with: "")
            context.session.characterClass = cls
            context.session.registrationStep = 3
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.registration.promptEstateName(context: context)
            return true
        }

        return false
    }
}
