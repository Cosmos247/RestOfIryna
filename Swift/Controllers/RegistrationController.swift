//
//  RegistrationController.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//
//  Registration is a lore-driven flow (steps 0–7):
//    0 — language selection
//    1 — gender selection (inline buttons; drives feminitive text + estate art)
//    2 — Artanian welcome + name prompt (text input)
//    3 — class selection (inline buttons; class choice also grants starter weapon)
//    4 — King's Oath narrative (inline button "Set out for the estate")
//    5 — rabid-dog encounter on the road (tutorial combat — teaches the fight UI)
//    6 — estate naming (text input)
//    7 — done (user is on the main controller) — see `User.registrationDoneStep`
//

import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Registration Controller Logic
final class Registration: TGControllerBase, @unchecked Sendable {
    typealias T = Registration

    // Allowed character sets for nicknames and estate names. Anything outside
    // these three buckets (emoji, punctuation, symbols, button labels…) is
    // rejected so players can't submit weird or button-sourced names.
    private static let nameDigits: Set<Character> = Set("0123456789")
    private static let nameLatin: Set<Character> = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let nameUkrainian: Set<Character> = Set("АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯабвгґдеєжзиіїйклмнопрстуфхцчшщьюя")

    private enum NameValidationError {
        case edgeSpace
        case consecutiveSpaces
        case tooShort
        case tooLong
        case invalidCharacters
    }

    private static func validateName(_ text: String, minLength: Int, maxLength: Int) -> NameValidationError? {
        if text.first?.isWhitespace == true || text.last?.isWhitespace == true { return .edgeSpace }
        if text.contains("  ") { return .consecutiveSpaces }
        if text.count < minLength { return .tooShort }
        if text.count > maxLength { return .tooLong }
        for ch in text {
            if ch == " " { continue }
            if nameDigits.contains(ch) || nameLatin.contains(ch) || nameUkrainian.contains(ch) { continue }
            return .invalidCharacters
        }
        return nil
    }

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
        case 2:
            return try await handleNicknameInput(context: context, text: text)
        case 6:
            return try await handleEstateNameInput(context: context, text: text)
        default:
            return try await showCurrentStep(context: context)
        }
    }

    /// Re-show the current registration step prompt
    private func showCurrentStep(context: Context) async throws -> Bool {
        switch context.session.registrationStep {
        case 1:
            try await promptGenderSelection(context: context)
        case 2:
            try await promptNickname(context: context)
        case 3:
            try await promptClassSelection(context: context)
        case 4:
            try await promptKingOath(context: context)
        case 5:
            try await promptJourneyDog(context: context)
        case 6:
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
        // Strip any leftover reply keyboard so button labels can't be typed as
        // nicknames or estate names later in the flow.
        let removeKB = TGReplyMarkup.replyKeyboardRemove(TGReplyKeyboardRemove(removeKeyboard: true))
        try await context.bot.sendMessage(session: context.session, text: "👋 Welcome, \(tgName)!", parseMode: .html, replyMarkup: removeKB)

        var prompt = ""
        var inlineKeyboard: [[TGInlineKeyboardButton]] = []
        for locale in SupportedLocale.allCases {
            if !prompt.isEmpty { prompt.append("\n") }
            prompt.append("- \(context.lingo.localize("registration", locale: locale))")
            let langName = context.lingo.localize("lang.name", locale: locale)
            let button = TGInlineKeyboardButton(text: "\(locale.flag()) \(langName)", callbackData: "set_lang:\(locale.rawValue)")
            inlineKeyboard.append([button])
        }
        let markup = TGReplyMarkup.inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: inlineKeyboard))
        try await context.bot.sendMessage(session: context.session, text: prompt, parseMode: .html, replyMarkup: markup)
    }

    // MARK: - Step 1: Gender Selection

    /// Asked right after language and ahead of the name prompt so every later
    /// string (welcome included) can render the correct feminitive, and the
    /// estate reveal art can pick the matching gender. Mirrors the class-pick
    /// inline-button pattern.
    func promptGenderSelection(context: Context) async throws {
        let locale = context.session.locale
        let prompt = context.lingo.localize("registration.gender.prompt", locale: locale)

        var inlineKeyboard: [[TGInlineKeyboardButton]] = []
        for gender in CharacterGender.allCases {
            let name = context.lingo.localize("registration.gender.\(gender.rawValue)", locale: locale)
            let button = TGInlineKeyboardButton(text: "\(gender.icon()) \(name)", callbackData: "set_gender:\(gender.rawValue)")
            inlineKeyboard.append([button])
        }
        let markup = TGReplyMarkup.inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: inlineKeyboard))
        try await context.bot.sendMessage(session: context.session, text: prompt, parseMode: .html, replyMarkup: markup)
    }

    // MARK: - Step 2: Nickname (Artanian welcome)

    func promptNickname(context: Context) async throws {
        let prompt = context.lingo.localize("registration.welcome", gender: context.session.gender, locale: context.session.locale)
        try await context.bot.sendMessage(session: context.session, text: prompt, parseMode: .html)
    }

    private func handleNicknameInput(context: Context, text: String) async throws -> Bool {
        if let err = Self.validateName(text, minLength: 2, maxLength: 20) {
            let key: String
            switch err {
            case .edgeSpace:          key = "registration.nickname.edge_space"
            case .consecutiveSpaces:  key = "registration.nickname.consecutive_spaces"
            case .tooShort:           key = "registration.nickname.too_short"
            case .tooLong:            key = "registration.nickname.too_long"
            case .invalidCharacters:  key = "registration.nickname.invalid_chars"
            }
            let message = context.lingo.localize(key, locale: context.session.locale)
            try await context.bot.sendMessage(session: context.session, text: message)
            return true
        }

        context.session.nickname = text
        context.session.registrationStep = 3
        try await context.session.saveAndCache(in: context.db)
        try await promptClassSelection(context: context)
        return true
    }

    // MARK: - Step 3: Class Selection

    private func promptClassSelection(context: Context) async throws {
        let locale = context.session.locale
        let nickname = context.session.nickname ?? "?"

        let intro = context.lingo.localize("registration.name_accepted", gender: context.session.gender, locale: locale, interpolations: ["name": nickname])
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

    // MARK: - Step 4: King's Oath

    func promptKingOath(context: Context) async throws {
        let locale = context.session.locale
        let cls = CharacterClass(rawValue: context.session.characterClass ?? "") ?? .warrior
        let weapon = context.lingo.localize("registration.weapon.\(cls.rawValue)", locale: locale)
        let text = context.lingo.localize("registration.king_oath", gender: context.session.gender, locale: locale, interpolations: ["weapon": weapon])

        let buttonLabel = context.lingo.localize("registration.to_estate", locale: locale)
        let inline = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: buttonLabel, callbackData: "reg:to_estate")
        ]])
        let markup = TGReplyMarkup.inlineKeyboardMarkup(inline)

        // file_id cache via `sendCachedPhoto`; kept in chat (lore beat).
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/registration/kings_charter.jpg",
            caption: text,
            replyMarkup: markup,
            toUser: context.session,
            bot: context.bot
        )
    }

    // MARK: - Step 5: Journey & Rabid Dog

    func promptJourneyDog(context: Context) async throws {
        let locale = context.session.locale
        let text = context.lingo.localize("registration.journey_dog", locale: locale)
        let buttonLabel = context.lingo.localize("registration.fight_dog", locale: locale)
        let inline = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: buttonLabel, callbackData: "reg:fight_dog")
        ]])
        let markup = TGReplyMarkup.inlineKeyboardMarkup(inline)

        let cls = CharacterClass(rawValue: context.session.characterClass ?? "") ?? .warrior
        let gender = CharacterGender(rawValue: context.session.gender ?? "") ?? .male

        // Per-class + per-gender journey art (the player's first look at the
        // estate). file_id cache via `sendCachedPhoto`, kept in chat as a lore beat.
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/registration/\(cls.journeyImageName(gender: gender))",
            caption: text,
            replyMarkup: markup,
            toUser: context.session,
            bot: context.bot
        )
    }

    // MARK: - Step 6: Estate Name

    func promptEstateName(context: Context) async throws {
        let nickname = context.session.nickname ?? "?"
        let prompt = context.lingo.localize("registration.estate.prompt", gender: context.session.gender, locale: context.session.locale, interpolations: ["name": nickname])
        // Strip any leftover reply keyboard (combat buttons after the rabid-dog
        // fight) so the player can't tap a button label as their estate name.
        let removeKB = TGReplyMarkup.replyKeyboardRemove(TGReplyKeyboardRemove(removeKeyboard: true))
        try await context.bot.sendMessage(session: context.session, text: prompt, parseMode: .html, replyMarkup: removeKB)
    }

    private func handleEstateNameInput(context: Context, text: String) async throws -> Bool {
        if let err = Self.validateName(text, minLength: 2, maxLength: 30) {
            let key: String
            switch err {
            case .edgeSpace:          key = "registration.estate.edge_space"
            case .consecutiveSpaces:  key = "registration.estate.consecutive_spaces"
            case .tooShort:           key = "registration.estate.too_short"
            case .tooLong:            key = "registration.estate.too_long"
            case .invalidCharacters:  key = "registration.estate.invalid_chars"
            }
            let message = context.lingo.localize(key, locale: context.session.locale)
            try await context.bot.sendMessage(session: context.session, text: message)
            return true
        }

        context.session.estateName = text
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
        context.session.registrationStep = User.registrationDoneStep
        try await context.session.saveAndCache(in: context.db)

        // Phase 5.3c: no starter farm grant — T1 estate has zero plot slots
        // (the wooden hut hasn't cleared any land yet). The first slot opens
        // when the player reaches estate T2 (player L4) and they choose what
        // to plant for themselves. Lore-wise: a fresh-from-the-King noble
        // forages in the wilderness before they own farmland.

        // Phase 5.2.1: starter Kitchen recipes (Baked Potato + Roasted Meat)
        // are always-available — gated through `RecipeCatalog.starterRecipeIds`
        // rather than via a `LearnedRecipe` row, so no per-player setup needed.

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

        // Language selection (step 0 → 1: gender)
        if data.starts(with: "set_lang:") {
            let locale = data.replacingOccurrences(of: "set_lang:", with: "")
            context.session.locale = locale
            context.session.registrationStep = 1
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.registration.promptGenderSelection(context: context)
            return true
        }

        // Gender selection (step 1 → 2: name). Set before the welcome so every
        // later string renders the correct feminitive.
        if data.starts(with: "set_gender:") {
            let gender = data.replacingOccurrences(of: "set_gender:", with: "")
            context.session.gender = CharacterGender(rawValue: gender)?.rawValue ?? CharacterGender.male.rawValue
            context.session.registrationStep = 2
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.registration.promptNickname(context: context)
            return true
        }

        // Class selection (step 3 → 4): applies stats + grants the class's starter weapon
        if data.starts(with: "set_class:") {
            let cls = data.replacingOccurrences(of: "set_class:", with: "")
            context.session.characterClass = cls
            if let charClass = CharacterClass(rawValue: cls) {
                context.session.applyStartingStats(for: charClass)
            }
            context.session.registrationStep = 4
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

        // King's Oath → Set out for the estate (step 4 → 5)
        if data == "reg:to_estate" {
            context.session.registrationStep = 5
            try await context.session.saveAndCache(in: context.db)
            try await Controllers.registration.promptJourneyDog(context: context)
            return true
        }

        // Rabid-dog encounter → Fight! Hand off to CombatController against
        // the tutorial rabid dog. Player stays at registrationStep = 5 until
        // victory; soft-retry on defeat / successful flee. Step → 6 happens
        // inside `Registration.handleCombatEnd(won: true)` after the fight.
        if data == "reg:fight_dog" {
            try await Controllers.registration.startDogFight(context: context)
            return true
        }

        return false
    }
}

// MARK: - Rabid Dog Fight Bridge

extension Registration {
    /// Begin the registration-step-5 combat against the tutorial rabid dog.
    /// The fight rides on the same `ExplorationState` row we use for normal
    /// expeditions (with `stepsDeep = 0`, combat fields populated) —
    /// `CombatController` detects the registration context via
    /// `session.registrationStep < User.registrationDoneStep` and routes back
    /// here on every end condition instead of falling into the exploration handoff.
    func startDogFight(context: Context) async throws {
        guard let dog = EnemyCatalog.find("enemy.rabid_dog") else { return }

        // Defensive: clear any leftover state row before stamping a fresh one.
        try await ExplorationState.end(for: context.session, on: context.db)

        let state = try await ExplorationState.begin(for: context.session, on: context.db)
        let uses = CombatService.initialUsesForUser(context.session)
        state.beginCombat(enemyId: dog.id, hp: dog.hp, specialAtkUses: uses.atk, specialDefUses: uses.def, superUses: uses.sup)
        try await state.save(on: context.db)

        let combatCtrl = Controllers.combatController
        context.session.routerName = combatCtrl.routerName
        try await context.session.saveAndCache(in: context.db)

        try await combatCtrl.showCombat(context: context, state: state, enemy: dog, intro: true)
    }

    /// Called by `CombatController` once the registration-step-5 fight
    /// resolves. Victory advances to estate naming; defeat / flee soft-retries
    /// the rabid-dog prompt with full HP. The state row is deleted by the
    /// CombatController before this is invoked.
    static func handleCombatEnd(context: Context, won: Bool) async throws {
        let registration = Controllers.registration
        if won {
            context.session.registrationStep = 6
            context.session.routerName = registration.routerName
            try await context.session.saveAndCache(in: context.db)
            try await registration.promptEstateName(context: context)
        } else {
            // Soft retry — full heal, re-show the rabid-dog prompt at step 5.
            context.session.hp = context.session.effectiveMaxHp
            context.session.registrationStep = 5
            context.session.routerName = registration.routerName
            try await context.session.saveAndCache(in: context.db)
            let retryText = context.lingo.localize("registration.dog_retry", gender: context.session.gender, locale: context.session.locale)
            // Clear the combat reply keyboard before the rabid-dog photo
            // (the photo carries an inline button, so it can't also carry
            // ReplyKeyboardRemove on the same message).
            let removeKB = TGReplyMarkup.replyKeyboardRemove(TGReplyKeyboardRemove(removeKeyboard: true))
            try await context.bot.sendMessage(session: context.session, text: retryText, parseMode: .html, replyMarkup: removeKB)
            try await registration.promptJourneyDog(context: context)
        }
    }
}
