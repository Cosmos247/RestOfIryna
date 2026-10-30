//
//  CapitalController+Flask.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.10.2026.
//
//  A holiday's reveal and its flask, in the palace (2026-10-30, the owner's
//  rework of Велесова ніч, `content/spec/event-veles-night.md` §4.3). At the
//  opening the watchman only summons everyone to the palace; the story is
//  told HERE, and the scribe hands the flask over in person — a flask nobody
//  collected could not explain itself. The manor's gate refuses a walk
//  without one (`ManorService.Refusal.noFlask`).
//
//  Two messages under the palace card, on every visit while the manor is open
//  and the flask is not taken: the story, then the scribe with «🩸 Взяти
//  флягу». The card itself is untouched — its caption is capped at 1,024 and
//  the story alone is 716 — and so is the decree on it.
//
//  The button is taken wherever it is tapped while the manor is open: the
//  offer was made in the palace, and a player who rode home before tapping
//  has still come for it. Its callback is claimed in `MainController`, where
//  every router's unknown callbacks arrive, so it never falls to that
//  dispatcher's delete-the-message default.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

extension CapitalController {

    /// `event:flask:<event>` — the longest event id leaves it at 36 bytes.
    static let flaskCallbackPrefix = "event:flask:"

    // MARK: - The reveal

    /// The story and the scribe under the palace card, while the manor is open
    /// and the player has not taken its flask.
    func sendFlaskRevealIfDue(context: Context) async throws {
        guard let event = EventCatalog.open(),
              try await !EventBlood.hasFlask(context.session, eventId: event.id, on: context.db) else { return }
        let lingo = context.lingo, locale = context.session.locale
        try await context.bot.sendMessage(session: context.session,
                                          text: "🕯 " + lingo.localize(event.keys.palaceStory, locale: locale),
                                          parseMode: .html)
        try await context.bot.sendMessage(session: context.session,
                                          text: Self.scribeText(event, lingo: lingo, locale: locale),
                                          parseMode: .html,
                                          replyMarkup: .inlineKeyboardMarkup(Self.takeKeyboard(event, lingo: lingo, locale: locale)))
    }

    private static func scribeText(_ event: GameEvent, lingo: Lingo, locale: String) -> String {
        "📜 " + lingo.localize(event.keys.palaceScribe, locale: locale,
                              interpolations: EventNoticeText.timeValues(event, lingo: lingo, locale: locale))
    }

    private static func takeKeyboard(_ event: GameEvent, lingo: Lingo, locale: String) -> TGInlineKeyboardMarkup {
        TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: lingo.localize(event.keys.palaceTake, locale: locale),
                                   callbackData: flaskCallbackPrefix + event.id)
        ]])
    }

    // MARK: - «🩸 Взяти флягу»

    /// Answered exactly once: the write that decides the answer comes first,
    /// and its `catch` answers before rethrowing — an unanswered tap spins.
    /// Every path that knows the holiday takes the button away and leaves the
    /// scribe's words as they were said.
    static func onFlaskCallback(_ data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage,
                                context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        guard let event = EventCatalog.find(String(data.dropFirst(flaskCallbackPrefix.count))) else {
            // The holiday has left the data: there is nothing to hand over,
            // and no line left to say it with.
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return
        }
        let now = Date()
        guard event.isOpen(at: now) else {
            // After the close the offer is over, and the alert says why the
            // button goes. Before the opening it cannot have been shown.
            let alert = event.isOver(at: now) ? lingo.localize(event.keys.entranceGone, locale: locale) : nil
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: alert, showAlert: alert != nil))
            _ = await editScreen(message, text: scribeText(event, lingo: lingo, locale: locale), replyMarkup: nil,
                                 bot: context.bot)
            return
        }
        let issued: Bool
        do {
            issued = try await EventBlood.issueFlask(to: context.session, eventId: event.id, on: context.db)
        } catch {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            throw error
        }
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        _ = await editScreen(message, text: scribeText(event, lingo: lingo, locale: locale), replyMarkup: nil,
                             bot: context.bot)
        // A second scribe's button, under a reveal the player was shown twice,
        // only goes quiet: the flask is already on the belt.
        guard issued else { return }
        let banner = "✅ " + lingo.localize(event.keys.flaskTaken, locale: locale,
                                           interpolations: EventNoticeText.timeValues(event, lingo: lingo, locale: locale))
        await Controllers.capitalController.postStatusBanner(banner, context: context)
    }
}
