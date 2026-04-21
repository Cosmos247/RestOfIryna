//
//  RegistrationController.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//
//  Registration is a 6-step lore-driven flow:
//    0 — language selection
//    1 — Artanian welcome + name prompt (text input)
//    2 — class selection (inline buttons; class choice also grants starter weapon)
//    3 — King's Oath narrative (inline button "Set out for the estate")
//    4 — wolf encounter on the road (inline button "Continue" — combat stub for now)
//    5 — estate naming (text input)
//    6 — done (user is on the main controller)
//

import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Registration Controller Logic
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
        case 5:
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
            try await promptKingOath(context: context)
        case 4:
            try await promptJourneyWolves(context: context)
        case 5:
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

    // MARK: - Step 1: Nickname (Artanian welcome)

    func promptNickname(context: Context) async throws {
        let prompt = context.lingo.localize("registration.welcome", locale: context.session.locale)
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
        let nickname = context.session.nickname ?? "?"

        let intro = context.lingo.localize("registration.name_accepted", locale: locale, interpolations: ["name": nickname])
        let prompt = context.lingo.localize("registration.class.prompt", locale: locale)

        var text = intro + "\n"
        var inlineKeyboard: [[TGInlineKeyboardButton]] = []

        for cls in CharacterClass.allCases {
            let name = context.lingo.localize("registration.class.\(cls.rawValue)", locale: locale)
            let desc = context.lingo.localize("registration.class.\(cls.rawValue).desc", locale: locale)
            text += "\n\(cls.icon()) <b>\(name)</b> — \(desc)"
            let button = TGInlineKeyboardButton(text: "\(cls.icon()) \(name)", callbackData: "set_class:\(cls.rawValue)")
            inlineKeyboard.append([button])
        }

        text += "\n\n\(prompt)"

        let markup = TGReplyMarkup.inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: inlineKeyboard))
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    // MARK: - Step 3: King's Oath

    func promptKingOath(context: Context) async throws {
        let locale = context.session.locale
        let cls = CharacterClass(rawValue: context.session.characterClass ?? "") ?? .warrior
        let weapon = context.lingo.localize("registration.weapon.\(cls.rawValue)", locale: locale)
        let text = context.lingo.localize("registration.king_oath", locale: locale, interpolations: ["weapon": weapon])

        let buttonLabel = context.lingo.localize("registration.to_estate", locale: locale)
        let inline = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: buttonLabel, callbackData: "reg:to_estate")
        ]])
        let markup = TGReplyMarkup.inlineKeyboardMarkup(inline)

        let imageURL = URL(fileURLWithPath: "\(projectPath)/Assets/registration/kings_charter.jpg")
        if let imageData = try? Data(contentsOf: imageURL) {
            let inputFile = TGInputFile(filename: "kings_charter.jpg", data: imageData, mimeType: "image/jpeg")
            let params = TGSendPhotoParams(
                chatId: .chat(context.session.telegramId),
                photo: .file(inputFile),
                caption: text,
                parseMode: .html,
                replyMarkup: markup
            )
            _ = try await context.bot.sendPhoto(params: params)
        } else {
            // Fallback: text-only if the artwork file is missing.
            try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
        }
    }

    // MARK: - Step 4: Journey & Wolves

    func promptJourneyWolves(context: Context) async throws {
        let locale = context.session.locale
        let text = context.lingo.localize("registration.journey_wolves", locale: locale)
        let buttonLabel = context.lingo.localize("registration.continue", locale: locale)
        let inline = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: buttonLabel, callbackData: "reg:continue")
        ]])
        let markup = TGReplyMarkup.inlineKeyboardMarkup(inline)

        let cls = CharacterClass(rawValue: context.session.characterClass ?? "") ?? .warrior
        let imageURL = URL(fileURLWithPath: "\(projectPath)/Assets/registration/\(cls.journeyImageName)")

        if let imageData = try? Data(contentsOf: imageURL) {
            let inputFile = TGInputFile(filename: cls.journeyImageName, data: imageData, mimeType: "image/jpeg")
            let params = TGSendPhotoParams(
                chatId: .chat(context.session.telegramId),
                photo: .file(inputFile),
                caption: text,
                parseMode: .html,
                replyMarkup: markup
            )
            _ = try await context.bot.sendPhoto(params: params)
        } else {
            // Fallback: text-only if the artwork file is missing for some reason.
            try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
        }
    }

    // MARK: - Step 5: Estate Name

    func promptEstateName(context: Context) async throws {
        let nickname = context.session.nickname ?? "?"
        let prompt = context.lingo.localize("registration.estate.prompt", locale: context.session.locale, interpolations: ["name": nickname])
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
        context.session.registrationStep = 6
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

        // Strip the inline keyboard from the source message so its buttons can't be
        // re-clicked, but keep the message (text + artwork) in chat history — the
        // whole Artanian narrative should read as a scroll.
        let chatId = TGChatId.chat(message.chat.id)
        let emptyMarkup = TGInlineKeyboardMarkup(inlineKeyboard: [])
        let editParams = TGEditMessageReplyMarkupParams(
            chatId: chatId,
            messageId: message.messageId,
            replyMarkup: emptyMarkup
        )
        _ = try? await context.bot.editMessageReplyMarkup(params: editParams)

        // Language selection (step 0 → 1)
        if data.starts(with: "set_lang:") {
            let locale = data.replacingOccurrences(of: "set_lang:", with: "")
            context.session.locale = locale
            context.session.registrationStep = 1
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.registration.promptNickname(context: context)
            return true
        }

        // Class selection (step 2 → 3): applies stats + grants the class's starter weapon
        if data.starts(with: "set_class:") {
            let cls = data.replacingOccurrences(of: "set_class:", with: "")
            context.session.characterClass = cls
            if let charClass = CharacterClass(rawValue: cls) {
                context.session.applyStartingStats(for: charClass)
            }
            context.session.registrationStep = 3
            try await context.session.saveAndCache(in: context.db)

            if let charClass = CharacterClass(rawValue: cls), let userId = context.session.id {
                try await InventoryEntry.add(charClass.starterWeaponId, quantity: 1, to: context.session, on: context.db)
                // Auto-equip the starter weapon so the King's Oath isn't a lie.
                if let weaponEntry = try await InventoryEntry.query(on: context.db)
                    .filter(\.$user.$id, .equal, userId)
                    .filter(\.$itemId, .equal, charClass.starterWeaponId)
                    .first() {
                    try await EquipmentService.equip(weaponEntry, for: context.session, on: context.db)
                }
            }

            try await Controllers.registration.promptKingOath(context: context)
            return true
        }

        // King's Oath → Set out for the estate (step 3 → 4)
        if data == "reg:to_estate" {
            context.session.registrationStep = 4
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.registration.promptJourneyWolves(context: context)
            return true
        }

        // Wolves encounter → Continue (combat stub) (step 4 → 5)
        if data == "reg:continue" {
            context.session.registrationStep = 5
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.registration.promptEstateName(context: context)
            return true
        }

        return false
    }
}
