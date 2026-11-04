//
//  NewsBroadcast.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.11.2026.
//
//  `/news` — a developer sends one message to every registered player, at a
//  moment of their choosing and with no restart (2026-11-04, the owner: «хочу
//  писати повідомленням в боті список оновлень для гравців … але не хочу робити
//  це одразу після оновлення»). The owner's picks: every account past
//  registration, and ANY message — text with its formatting, or a photo with
//  its caption — copied as it was sent (`copyMessage`: it arrives as the bot's
//  own message, not «forwarded», and nothing about the player's screen or
//  keyboard changes).
//
//  The flow, for a developer only — anyone else's `/news` goes on to routing
//  like any other text:
//    1. `/news` → «📣 Надішліть повідомлення для гравців…», saying how many get it;
//    2. the next message that is not a command is the news: the bot shows it the
//       way the players will see it and asks «Надіслати N гравцям?» [✅] [❌];
//    3. ✅ copies it to every registered player but the sender, one at a time,
//       and the question becomes the report — sent, and not delivered (a player
//       who blocked the bot or deleted the chat). The draft is taken by the tap
//       that sends, so a second tap sends nothing.
//
//  While a draft waits, the developer's next message that is not a command is
//  taken as the news even if it is a button's text — harmless, because nothing
//  goes out without ✅. A `/news` left half an hour without its message lapses;
//  a question already shown waits for ✅ or ❌ until a restart. One message is
//  one news: of an album, the first photo is taken and the rest are routed.
//
//  It runs at the top of the dispatcher's catch-all, BEFORE routing, because
//  the SDK hands an update to every matching handler at once: a command handler
//  could not stop the developer's own screen from reading the news as a stray
//  message as well. The draft lives in memory — a restart forgets it, and
//  `/news` starts again.
//

import Foundation
import Fluent
@preconcurrency import Lingo
import SwiftTelegramBot

actor NewsBroadcast {
    static let shared = NewsBroadcast()

    private enum Draft {
        /// `/news` was sent; the next message is the news — for half an hour,
        /// so a draft forgotten for a day does not swallow a later message.
        case awaitingMessage(promptMessageId: Int, since: Date)
        /// The news is shown back; ✅ with this token sends it.
        case awaitingConfirm(sourceMessageId: Int, token: String)
    }

    private var drafts: [Int64: Draft] = [:]

    private func set(_ draft: Draft?, for developer: Int64) { drafts[developer] = draft }

    private static let draftLifetime: TimeInterval = 30 * 60

    /// The waiting prompt, TAKEN: the first message that arrives is the news,
    /// and one arriving beside it (an album's next photo) finds no draft and
    /// goes on to routing — never a second preview and a second question.
    private func takePrompt(for developer: Int64) -> Int? {
        guard case .awaitingMessage(let id, let since)? = drafts[developer] else { return nil }
        drafts[developer] = nil
        return Date().timeIntervalSince(since) <= Self.draftLifetime ? id : nil
    }

    /// The news a ✅ with `token` may send, taken in the same step — the one
    /// tap that sends clears the draft, so a double tap finds nothing.
    private func takeConfirmed(for developer: Int64, token: String) -> Int? {
        guard case .awaitingConfirm(let source, let expected)? = drafts[developer], expected == token else { return nil }
        drafts[developer] = nil
        return source
    }

    // MARK: - The dispatcher's hook

    /// Answers the update when it belongs to a developer's news flow and returns
    /// true; anything else returns false and goes on to routing.
    static func intercept(update: TGUpdate, from entity: TGUser, session: User, bot: TGBot,
                          db: any Database, lingo: Lingo) async -> Bool {
        guard developerUsers.contains(entity.id) else { return false }
        if let query = update.callbackQuery, let data = query.data, data.hasPrefix("news:") {
            await answer(query, data: data, from: entity, session: session, bot: bot, db: db, lingo: lingo)
            return true
        }
        guard let message = update.message else { return false }
        let command = message.text?.split(separator: " ").first.map(String.init)
        if command == "/news" || command?.hasPrefix("/news@") == true {
            await start(chatId: message.chat.id, from: entity, session: session, bot: bot, db: db, lingo: lingo)
            return true
        }
        // A command is never the news: it goes on to its own handler, and the draft waits.
        if message.text?.hasPrefix("/") == true { return false }
        guard let promptId = await shared.takePrompt(for: entity.id) else { return false }
        await capture(message, promptMessageId: promptId, from: entity, session: session, bot: bot, db: db, lingo: lingo)
        return true
    }

    // MARK: - Who gets it

    /// Every account past registration that the gate still lets in, but the
    /// sender — who sees the news already, as its preview.
    static func recipients(excluding sender: Int64, on db: any Database) async throws -> [Int64] {
        let registered = try await User.query(on: db)
            .filter(\.$registrationStep >= User.registrationDoneStep)
            .all()
        var ids: [Int64] = []
        for user in registered where user.telegramId != sender {
            if await accessControl.isAllowed(user.telegramId, on: db) { ids.append(user.telegramId) }
        }
        return ids
    }

    // MARK: - The three steps

    private static func start(chatId: Int64, from entity: TGUser, session: User, bot: TGBot,
                              db: any Database, lingo: Lingo) async {
        let locale = session.locale
        do {
            let count = try await recipients(excluding: entity.id, on: db).count
            // 📣 prepended here: a two-unit emoji ahead of `%{count}` breaks Lingo.
            let text = "📣 " + lingo.localize("news.prompt", count: count, locale: locale,
                                             interpolations: ["count": "\(count)"])
            let sent = try await bot.sendMessage(params: TGSendMessageParams(
                chatId: .chat(chatId), text: text, parseMode: .html,
                replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: [[cancelButton(lingo, locale)]]))
            ))
            await shared.set(.awaitingMessage(promptMessageId: sent.messageId, since: Date()), for: entity.id)
        } catch {
            appState?.logger.error("[NEWS] could not open a draft for \(entity.id): \(error)")
        }
    }

    private static func capture(_ message: TGMessage, promptMessageId: Int, from entity: TGUser, session: User,
                                bot: TGBot, db: any Database, lingo: Lingo) async {
        let chatId = message.chat.id
        let locale = session.locale
        // The preview IS a copy, made exactly the way the players' copies will be.
        do {
            _ = try await bot.copyMessage(params: TGCopyMessageParams(
                chatId: .chat(chatId), fromChatId: .chat(chatId), messageId: message.messageId))
        } catch {
            // A message Telegram cannot copy (a poll, a service message): say so,
            // and keep waiting for one it can.
            _ = try? await bot.sendMessage(params: TGSendMessageParams(
                chatId: .chat(chatId), text: "❌ " + lingo.localize("news.uncopyable", locale: locale), parseMode: .html))
            await shared.set(.awaitingMessage(promptMessageId: promptMessageId, since: Date()), for: entity.id)
            return
        }
        do {
            // The prompt's ❌ goes: the question under the preview replaces it.
            _ = await editScreen(chatId: .chat(chatId), messageId: promptMessageId, isPhoto: false,
                                 text: "📣 " + lingo.localize("news.drafted", locale: locale), replyMarkup: nil, bot: bot)
            let count = try await recipients(excluding: entity.id, on: db).count
            let token = String(UUID().uuidString.prefix(8))
            let send = TGInlineKeyboardButton(text: lingo.localize("news.button.send", locale: locale),
                                              callbackData: "news:send:\(token)")
            _ = try await bot.sendMessage(params: TGSendMessageParams(
                chatId: .chat(chatId),
                text: lingo.localize("news.confirm", count: count, locale: locale, interpolations: ["count": "\(count)"]),
                parseMode: .html,
                replyMarkup: .inlineKeyboardMarkup(TGInlineKeyboardMarkup(inlineKeyboard: [[send, cancelButton(lingo, locale)]]))
            ))
            await shared.set(.awaitingConfirm(sourceMessageId: message.messageId, token: token), for: entity.id)
        } catch {
            appState?.logger.error("[NEWS] could not ask to confirm for \(entity.id): \(error)")
        }
    }

    private static func answer(_ query: TGCallbackQuery, data: String, from entity: TGUser, session: User,
                               bot: TGBot, db: any Database, lingo: Lingo) async {
        let locale = session.locale
        guard let message = query.message else {
            _ = try? await bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return
        }
        let chatId = message.chat.id

        if data == "news:cancel" {
            await shared.set(nil, for: entity.id)
            _ = try? await bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            _ = await editScreen(chatId: .chat(chatId), messageId: message.messageId, isPhoto: false,
                                 text: lingo.localize("news.cancelled", locale: locale), replyMarkup: nil, bot: bot)
            return
        }

        let token = String(data.dropFirst("news:send:".count))
        guard data.hasPrefix("news:send:"),
              let source = await shared.takeConfirmed(for: entity.id, token: token) else {
            // A ✅ from a draft already sent, cancelled or forgotten by a restart.
            _ = try? await bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: lingo.localize("news.stale", locale: locale), showAlert: true))
            _ = await editScreen(chatId: .chat(chatId), messageId: message.messageId, isPhoto: false,
                                 text: lingo.localize("news.stale", locale: locale), replyMarkup: nil, bot: bot)
            return
        }
        _ = try? await bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
        _ = await editScreen(chatId: .chat(chatId), messageId: message.messageId, isPhoto: false,
                             text: "📣 " + lingo.localize("news.sending", locale: locale), replyMarkup: nil, bot: bot)

        // Off the tap: one copy at a time, paced well under Telegram's 30 a
        // second (the SDK's own limiter stays off — `configure`).
        let developer = entity.id
        let confirmId = message.messageId
        Task.detached {
            let ids = (try? await recipients(excluding: developer, on: db)) ?? []
            var sent = 0
            var failed = 0
            for id in ids {
                do {
                    _ = try await bot.copyMessage(params: TGCopyMessageParams(
                        chatId: .chat(id), fromChatId: .chat(chatId), messageId: source))
                    sent += 1
                } catch {
                    failed += 1
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            appState?.logger.info("[NEWS] \(developer) sent message \(source): \(sent) of \(ids.count) delivered, \(failed) not")
            var report = "📣 " + lingo.localize("news.done", locale: locale, interpolations: [
                "sent": "\(sent)", "total": "\(ids.count)"
            ])
            if sent == 0, failed > 0 {
                // Not one copy landed: the likelier cause is the news itself
                // (deleted before ✅) or Telegram, not every player at once.
                report += "\n" + lingo.localize("news.failed_all", locale: locale)
            } else if failed > 0 {
                report += "\n" + lingo.localize("news.failed", locale: locale, interpolations: ["failed": "\(failed)"])
            }
            _ = await editScreen(chatId: .chat(chatId), messageId: confirmId, isPhoto: false,
                                 text: report, replyMarkup: nil, bot: bot)
        }
    }

    private static func cancelButton(_ lingo: Lingo, _ locale: String) -> TGInlineKeyboardButton {
        TGInlineKeyboardButton(text: lingo.localize("news.button.cancel", locale: locale), callbackData: "news:cancel")
    }
}
