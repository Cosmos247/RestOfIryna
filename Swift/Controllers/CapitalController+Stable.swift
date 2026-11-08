//
//  CapitalController+Stable.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 08.11.2026.
//
//  The stable on Поділ (2026-11-08, `content/spec/spec-wagon.md`): where the
//  wagon («🫏 Віз») is hired. A place of its own on the street's third row,
//  like the trader's — `Assets/capital/stable.jpg` when it exists, text until
//  then — and every screen after it is a caption edit of that one bubble.
//
//  The screens, each from the approved spec (§4):
//  - the stable: the carter's line, the offer, the wagon while it is yours,
//    one button per length, printed from `stable.json`;
//  - the question: the length and its price, the terms, the price as a
//    `RequirementLine`; only «✅ Найняти» spends;
//  - the hire: a banner, and the stable redrawn with the wagon now yours.
//
//  The answer names what it was asked about: `stable:ok:<index>:<price>`. A
//  `/reload` that moved the length or its price between the question and the
//  tap redraws the stable and takes nothing.
//
//  The question at the estate's door lives here too (§2.11): while a hire runs,
//  «🐎 Верхи» or «🫏 З возом» decides whether the wagon comes along.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

extension CapitalController {

    // MARK: - The road from the estate

    static let roadCallbackPrefix = "road:"
    private static let roadOnHorseback = "road:horse"
    private static let roadWithWagon = "road:wagon"

    /// The question at the estate's door (§2.11). It takes the picker's place,
    /// so asking twice leaves one and the main menu's buttons delete it. Asked
    /// from the estate's or the bag's screen it can stay in chat, which is why
    /// `onRoadCallback` asks the state again.
    func askTheRoad(wagon: WagonService.Status, context: Context) async throws {
        await dismissPendingPicker(context: context)
        let screen = roadQuestion(wagon: wagon, lingo: context.lingo, locale: context.session.locale)
        let sent = try await context.bot.sendMessage(params: TGSendMessageParams(
            chatId: .chat(context.session.telegramId),
            text: screen.text,
            parseMode: .html,
            replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: screen.rows))
        ))
        await EphemeralChatState.shared.setPicker(telegramId: context.session.telegramId, messageId: sent.messageId)
    }

    /// The question's text and buttons — no database, so a rehearsal reads the
    /// screen exactly as a player will. Both times are printed from the data.
    func roadQuestion(wagon: WagonService.Status, lingo: Lingo, locale: String,
                      now: Date = Date()) -> (text: String, rows: [[TGInlineKeyboardButton]]) {
        let road = TravelService.travelSeconds
        let horse = Countdown.format(Int(road), lingo: lingo, locale: locale)
        let cart = Countdown.format(Int(WagonMath.crossing(road: road, wagon: WagonCatalog.travelSeconds, ridesAlong: true)),
                                    lingo: lingo, locale: locale)
        let text = [
            "🐎 <b>\(lingo.localize("travel.choice.title", locale: locale))</b>",
            "",
            WagonDisplay.statusLine(wagon, lingo: lingo, locale: locale, now: now),
            "",
            lingo.localize("travel.choice.horse", locale: locale, interpolations: ["time": horse]),
            lingo.localize("travel.choice.wagon", locale: locale, interpolations: ["time": cart])
        ].joined(separator: "\n")
        let horseLabel = "🐎 " + lingo.localize("travel.choice.button.horse", locale: locale, interpolations: ["time": horse])
        let cartLabel = WagonDisplay.icon + " " + lingo.localize("travel.choice.button.wagon", locale: locale, interpolations: ["time": cart])
        return (text, [[TGInlineKeyboardButton(text: horseLabel, callbackData: Self.roadOnHorseback),
                        TGInlineKeyboardButton(text: cartLabel, callbackData: Self.roadWithWagon)]])
    }

    /// The answer, wherever it is tapped: it arrives through
    /// `MainController.onCallbackQuery`, by name from Settings, which deletes
    /// what it does not know. The buttons go first, then the state is asked
    /// again: a question left in chat can be answered from the road, the forest
    /// or town, and `showCapital` draws whichever of those it is.
    static func onRoadCallback(_ data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage,
                               context: Context) async throws {
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        _ = await EphemeralChatState.shared.takePicker(telegramId: context.session.telegramId)
        _ = try? await context.bot.editMessageReplyMarkup(params: TGEditMessageReplyMarkupParams(
            chatId: .chat(message.chat.id), messageId: message.messageId))
        guard try await WagonService.isHome(context.session, on: context.db) else {
            try await Controllers.capitalController.showCapital(context: context)
            return
        }
        try await beginTrip(destination: .capital, leavingWagon: data == roadOnHorseback, context: context)
    }

    // MARK: - The place

    func showStable(context: Context) async throws {
        let screen = try await stableScreen(context: context)
        _ = try await sendCachedPhoto(
            assetPath: "\(projectPath)/Assets/capital/stable.jpg",
            caption: screen.text,
            replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: screen.rows)),
            toUser: context.session,
            bot: context.bot
        )
    }

    private func stableScreen(context: Context) async throws -> (text: String, rows: [[TGInlineKeyboardButton]]) {
        let status = try await WagonService.status(for: context.session, on: context.db)
        return stableScreen(running: status?.running == true ? status : nil,
                            lingo: context.lingo, locale: context.session.locale)
    }

    /// The stable's text and buttons — no database, so a rehearsal reads the
    /// screen exactly as a player will. `running` is the wagon while its hire
    /// runs; a length bought then adds to it, and its buttons say so.
    func stableScreen(running: WagonService.Status?, lingo: Lingo, locale: String,
                      now: Date = Date()) -> (text: String, rows: [[TGInlineKeyboardButton]]) {
        var lines = [
            "<b>\(lingo.localize(Location.stable.titleKey, locale: locale))</b>",
            "",
            lingo.localize(Location.stable.bodyKey, locale: locale),
            "",
            WagonDisplay.icon + " " + lingo.localize("stable.wagon.offer", locale: locale, interpolations: [
                "cap": "\(WagonCatalog.capacity)",
                "road": Countdown.format(Int(WagonCatalog.travelSeconds), lingo: lingo, locale: locale),
                "base": Countdown.format(Int(TravelService.travelSeconds), lingo: lingo, locale: locale)
            ])
        ]
        if let running {
            lines.append(WagonDisplay.icon + " " + lingo.localize("stable.wagon.yours", locale: locale, interpolations: [
                "time": Countdown.format(running.secondsLeft(now: now), lingo: lingo, locale: locale),
                "used": "\(running.used)", "cap": "\(running.capacity)"
            ]))
        }
        var buttons: [TGInlineKeyboardButton] = []
        for (index, length) in WagonCatalog.lengths.enumerated() {
            let label = WagonDisplay.lengthLabel(minutes: length.minutes, lingo: lingo, locale: locale)
            let text = "\(WagonDisplay.icon) \(running == nil ? "" : "+")\(label) · \(length.silver) 🪙"
            buttons.append(TGInlineKeyboardButton(text: text, callbackData: "stable:hire:\(index)"))
        }
        var rows = stride(from: 0, to: buttons.count, by: 2).map { Array(buttons[$0..<min($0 + 2, buttons.count)]) }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("capital.button.back_to_capital", locale: locale),
                                            callbackData: "capital:back")])
        return (lines.joined(separator: "\n"), rows)
    }

    // MARK: - Dispatch

    /// Every `stable:` callback, answered exactly once: a refusal is the modal,
    /// everything else an empty answer ahead of the redraw. A shape this build
    /// does not know opens the stable, the screen every one of them belongs to.
    static func onStableCallback(_ data: String, query: TGCallbackQuery, messageId: Int, isPhoto: Bool,
                                 context: Context) async throws {
        let ctrl = Controllers.capitalController
        let parts = data.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let verb = parts.count > 1 ? parts[1] : ""
        if verb == "ok", parts.count == 4, let index = Int(parts[2]), let price = Int(parts[3]) {
            try await ctrl.handleStableHire(index: index, price: price, query: query, messageId: messageId,
                                            isPhoto: isPhoto, context: context)
            return
        }
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        if verb == "hire", parts.count == 3, let index = Int(parts[2]), WagonCatalog.length(at: index) != nil {
            try await ctrl.editToStableQuestion(index: index, messageId: messageId, isPhoto: isPhoto, context: context)
        } else {
            try await ctrl.editToStable(messageId: messageId, isPhoto: isPhoto, context: context)
        }
    }

    func editToStable(messageId: Int, isPhoto: Bool, context: Context) async throws {
        let screen = try await stableScreen(context: context)
        await editScreen(chatId: .chat(context.session.telegramId), messageId: messageId, isPhoto: isPhoto,
                         text: screen.text, replyMarkup: TGInlineKeyboardMarkup(inlineKeyboard: screen.rows), bot: context.bot)
    }

    // MARK: - The question

    private func editToStableQuestion(index: Int, messageId: Int, isPhoto: Bool, context: Context) async throws {
        guard let length = WagonCatalog.length(at: index) else {
            try await editToStable(messageId: messageId, isPhoto: isPhoto, context: context)
            return
        }
        let status = try await WagonService.status(for: context.session, on: context.db)
        let screen = stableQuestion(index: index, length: length, extending: status?.running == true,
                                    silver: context.session.silver, lingo: context.lingo, locale: context.session.locale)
        await editScreen(chatId: .chat(context.session.telegramId), messageId: messageId, isPhoto: isPhoto,
                         text: screen.text, replyMarkup: TGInlineKeyboardMarkup(inlineKeyboard: screen.rows), bot: context.bot)
    }

    /// «🫏 Найняти віз на 1 день за 670 срібників?», the terms, and the price as
    /// the silver line every spending question ends with.
    func stableQuestion(index: Int, length: WagonLengthDTO, extending: Bool, silver: Int,
                        lingo: Lingo, locale: String) -> (text: String, rows: [[TGInlineKeyboardButton]]) {
        let label = WagonDisplay.lengthLabel(minutes: length.minutes, lingo: lingo, locale: locale)
        let question = lingo.localize(extending ? "stable.hire.question_more" : "stable.hire.question",
                                      count: length.silver, locale: locale,
                                      interpolations: ["length": label, "price": "\(length.silver)"])
        let text = [
            "\(WagonDisplay.icon) \(question)",
            lingo.localize("stable.hire.terms", locale: locale, interpolations: [
                "road": Countdown.format(Int(WagonCatalog.travelSeconds), lingo: lingo, locale: locale),
                "base": Countdown.format(Int(TravelService.travelSeconds), lingo: lingo, locale: locale)
            ]),
            "",
            RequirementLine.silver(have: silver, need: length.silver, lingo: lingo, locale: locale)
        ].joined(separator: "\n")
        let rows = [[
            TGInlineKeyboardButton(text: lingo.localize("stable.hire.confirm", locale: locale),
                                   callbackData: "stable:ok:\(index):\(length.silver)"),
            TGInlineKeyboardButton(text: lingo.localize("stable.hire.cancel", locale: locale), callbackData: "stable:open")
        ]]
        return (text, rows)
    }

    // MARK: - The hire

    /// `stable:ok:<index>:<price>`. The refusal is the tap's only answer, so
    /// the tap is answered late — in the `catch` too, so a throw never leaves
    /// the button spinning.
    private func handleStableHire(index: Int, price: Int, query: TGCallbackQuery, messageId: Int, isPhoto: Bool,
                                  context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        func answer(_ alert: String? = nil) async {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: alert, showAlert: alert != nil))
        }
        do {
            // The answer names its question: a length or a price a reload moved
            // since is not what the player agreed to.
            guard let length = WagonCatalog.length(at: index), length.silver == price else {
                await answer()
                try await editToStable(messageId: messageId, isPhoto: isPhoto, context: context)
                return
            }
            switch try await WagonService.hire(lengthIndex: index, for: context.session, on: context.db) {
            case .hired(_, let hired, _):
                await answer()
                try await editToStable(messageId: messageId, isPhoto: isPhoto, context: context)
                let label = WagonDisplay.lengthLabel(minutes: hired.minutes, lingo: lingo, locale: locale)
                await postStatusBanner("\(WagonDisplay.icon) " + lingo.localize("stable.hire.done", locale: locale, interpolations: [
                    "length": label, "price": "\(hired.silver)"
                ]), context: context)
            case .notEnoughSilver(let have, let need):
                await answer(lingo.localize("capital.trader.not_enough_silver", locale: locale, interpolations: [
                    "have": "\(have)", "need": "\(need)"
                ]))
            case .notInTown:
                await answer(lingo.localize("stable.hire.not_in_town", locale: locale))
            case .unknownLength:
                await answer()
                try await editToStable(messageId: messageId, isPhoto: isPhoto, context: context)
            }
        } catch {
            await answer()
            throw error
        }
    }
}
