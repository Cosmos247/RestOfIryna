//
//  ScreenEdit.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.09.2026.
//
//  The one sanctioned way to redraw an inline screen in place — the mirror of
//  `sendCachedPhoto` for edits.
//
//  Telegram edits a message's TEXT or its CAPTION, never either, and which one
//  a screen has depends on whether it was sent with artwork. `editMessageText`
//  against a photo fails with "there is no text in the message to edit" — 310
//  times in the Pi log covering 2026-09-09 01:51 → 09-10 18:36 — and every call
//  site swallowed it with `try?`. The player tapped, the screen did not change,
//  and nothing anywhere said why. That is the whole of the "sometimes there is
//  just no message" report.
//
//  So the decision lives here, once, and it is not only a decision: `isPhoto` is
//  the caller's expectation and the fast path, but when it turns out to be wrong
//  the other field is tried before giving up. A screen that gains artwork (or
//  loses it) therefore keeps working without anyone having to find its edit call
//  again — and the recovery is logged, so the wrong expectation is visible
//  rather than free.
//

import Foundation
import Logging
import SwiftTelegramBot

/// A Telegram API refusal with the two fields worth branching on kept apart
/// from the prose.
///
/// Thrown by `HummingbirdTGClient` where a `BotError` used to be: the reason
/// the old one was useless is that it carried the code and the description
/// formatted INTO a multi-line human sentence, so the only way to act on a
/// refusal was to re-parse the log line the client had just printed.
public struct TelegramAPIError: Error, CustomStringConvertible {

    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    public var description: String { "Telegram \(code): \(message)" }

    /// The edit was aimed at the wrong field — `editMessageText` at a message
    /// whose body is a caption, or the mirror case. Recoverable: the other
    /// field is the right one.
    public var isWrongEditField: Bool {
        return message.contains("there is no text in the message to edit")
            || message.contains("there is no caption in the message to edit")
    }

    /// The screen already shows exactly what was asked for. Not a failure —
    /// the player is looking at the intended content.
    public var isNotModified: Bool {
        return message.contains("message is not modified")
    }

    /// The message is already gone: deleted by the player, or by a sweeper
    /// that got there first.
    public var isGone: Bool {
        return message.contains("message to delete not found")
            || message.contains("message to edit not found")
            || message.contains("message can't be deleted")
    }

    /// A callback spinner answered after Telegram stopped caring.
    public var isStaleQuery: Bool {
        return message.contains("query is too old")
    }

    /// Refusals that say nothing a reader could act on: the screen is already
    /// right, or the thing being addressed no longer exists.
    public var isBenign: Bool { isNotModified || isGone || isStaleQuery }
}

/// Redraw a message in place, editing whichever of text/caption it actually has.
///
/// - Parameters:
///   - isPhoto: what the caller believes the message is. Wrong is survivable —
///     the other field is tried — but it costs a round trip, so it is worth
///     passing honestly.
///   - origin: the calling function, filled in by the compiler. It is what turns
///     a failure in the log from "an edit failed" into a place to go and look.
/// - Returns: `true` when the screen now shows `text` (including the case where
///   it already did), `false` when it does not.
@discardableResult
public func editScreen(
    chatId: TGChatId,
    messageId: Int,
    isPhoto: Bool,
    text: String,
    parseMode: TGParseMode = .html,
    replyMarkup: TGInlineKeyboardMarkup? = nil,
    bot: TGBot,
    origin: String = #function
) async -> Bool {

    func apply(asCaption: Bool) async throws {
        if asCaption {
            _ = try await bot.editMessageCaption(params: TGEditMessageCaptionParams(
                chatId: chatId,
                messageId: messageId,
                caption: text,
                parseMode: parseMode,
                replyMarkup: replyMarkup
            ))
        } else {
            _ = try await bot.editMessageText(params: TGEditMessageTextParams(
                chatId: chatId,
                messageId: messageId,
                text: text,
                parseMode: parseMode,
                replyMarkup: replyMarkup
            ))
        }
    }

    do {
        try await apply(asCaption: isPhoto)
        return true
    } catch let error as TelegramAPIError where error.isNotModified {
        // Already on screen. A double-tap on the same inline button lands here
        // and the player sees the correct screen either way.
        return true
    } catch let error as TelegramAPIError where error.isWrongEditField {
        do {
            try await apply(asCaption: !isPhoto)
            appState?.logger.info("""
                [SCREEN] \(origin): message \(messageId) carries \
                \(isPhoto ? "text" : "a caption"), not \(isPhoto ? "a caption" : "text") — \
                redrawn through the other field
                """)
            return true
        } catch let retry as TelegramAPIError where retry.isNotModified {
            return true
        } catch {
            appState?.logger.warning("[SCREEN] \(origin): message \(messageId) refused both fields: \(error)")
            return false
        }
    } catch let error as TelegramAPIError where error.isBenign {
        return false
    } catch {
        appState?.logger.warning("[SCREEN] \(origin): message \(messageId) redraw failed: \(error)")
        return false
    }
}

/// Redraw the message a callback query arrived on, reading the chat, the id and
/// the text-vs-caption question straight off it. The shape almost every inline
/// screen wants.
@discardableResult
public func editScreen(
    _ message: TGMaybeInaccessibleMessage,
    text: String,
    parseMode: TGParseMode = .html,
    replyMarkup: TGInlineKeyboardMarkup? = nil,
    bot: TGBot,
    origin: String = #function
) async -> Bool {
    return await editScreen(
        chatId: .chat(message.chat.id),
        messageId: message.messageId,
        isPhoto: message.getMessage()?.photo != nil,
        text: text,
        parseMode: parseMode,
        replyMarkup: replyMarkup,
        bot: bot,
        origin: origin
    )
}
