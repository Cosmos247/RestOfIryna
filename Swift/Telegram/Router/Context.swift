//
//  Context.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
import Dispatch
import Fluent
import Lingo
import SwiftTelegramBot

public class Context {
	typealias T = Context
		
    public let bot: TGBot
    public let db: any Database
    public let lingo: Lingo
	public let update: TGUpdate
	/// `update.message` shortcut. Make sure that the message exists before using it,
	/// otherwise it will be empty. For paths supported by Router the message is guaranteed to exist.
	public var message: TGMessage? {
        return update.message ?? update.editedMessage ??
             update.callbackQuery?.message?.getMessage()
    }

    /// Command starts with slash (useful if you want to skip commands not starting with slash in group chats)
    public let slash: Bool
    public let command: String
    public let args: Arguments

	public var privateChat: Bool {
        guard let message = message else { return false }
        return message.chat.type == .private
    }
	public var chatId: Int64? { return message?.chat.id ??
        update.callbackQuery?.message?.chat.id
    }
	public var fromId: Int64? {
        return update.message?.from?.id ??
            (update.editedMessage?.from?.id ??
            update.callbackQuery?.from.id)
    }
    public var properties: [String: User]
	
    init(bot: TGBot, update: TGUpdate, db: any Database, lingo: Lingo, scanner: Scanner, command: String, startsWithSlash: Bool, properties: [String: User] = [:]) {
		self.bot = bot
        self.db = db
        self.lingo = lingo
		self.update = update
        self.slash = startsWithSlash
        self.command = command
        self.args = Arguments(scanner: scanner)
        self.properties = properties
	}
    
    /// Sends a message to current chat.
    /// - SeeAlso: <https://core.telegram.org/bots/api#sendmessage>
    public func respond(_ text: String,
                        parseMode: TGParseMode? = nil,
                        disableWebPagePreview: Bool? = nil,
                        disableNotification: Bool? = nil,
                        replyToMessageId: Int? = nil,
                        replyMarkup: TGReplyMarkup? = nil,
                        _ parameters: [String: (any Encodable)?] = [:],
                        queue: DispatchQueue = .main) async throws {
        guard let chatId = chatId else {
            assertionFailure("respondAsync() used when update.message is nil")
            return
        }
        let params = TGSendMessageParams(chatId: .chat(chatId), text: text, parseMode: parseMode,
                              disableNotification: disableNotification, replyMarkup: replyMarkup)
        try await bot.sendMessage(params: params)
    }
	
    /// Respond privately also sending a message to a group.
    /// - SeeAlso: <https://core.telegram.org/bots/api#sendmessage>
    public func respondPrivatelyAsync(_ userText: String, groupText: String? = nil) async throws {
        if let fromId = fromId {
            let params = TGSendMessageParams(chatId: .chat(fromId), text: userText)
            try await bot.sendMessage(params: params)
        }
        if !privateChat, let additionalText = groupText {
            if let chatId = chatId {
                let params = TGSendMessageParams(chatId: .chat(chatId), text: additionalText)
                try await bot.sendMessage(params: params)
            } else {
                assertionFailure("respondPrivatelyAsync() used when update.message is nil")
            }
        }
    }
}

extension TGBot {
    /// Text-only convenience send. There is deliberately NO `photo:` parameter:
    /// every player-visible image MUST go through `sendCachedPhoto(...)` so its
    /// Telegram file_id is captured + reused (see PhotoCache + CLAUDE.md). Keeping
    /// a photo path here would be a cache-bypassing loophole.
    func sendMessage(session: User, text: String, disableNotification: Bool? = nil, parseMode: TGParseMode? = nil, replyMarkup: TGReplyMarkup? = nil) async throws {
        let chatId = TGChatId.chat(session.telegramId)
        let params = TGSendMessageParams(chatId: chatId, text: text, parseMode: parseMode, disableNotification: disableNotification, replyMarkup: replyMarkup)
        try await self.sendMessage(params: params)
    }
}
