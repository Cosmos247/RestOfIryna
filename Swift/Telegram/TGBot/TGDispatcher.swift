//
//  TGDispatcher.swift
//  RestOfIryna
//
//  Created by Maxim Lanskoy on 13.06.2025.
//  Maintained by Dmytro Ihnatyuhin from 17.04.2026.
//

import Foundation
import Logging
import Fluent
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Main Unified Dispatcher

final class TGDispatcher: TGDefaultDispatcher, @unchecked Sendable {

    private let db: any Database
    let lingo: Lingo

    init(bot: TGBot, appState: AppState) {
        self.db = appState.db
        self.lingo = appState.lingo
        super.init(bot: bot, logger: appState.logger)
    }

    override func handle() async {
        // Register global commands controller
        let globalCommands = GlobalCommandsController(
            bot: bot,
            db: db,
            lingo: lingo
        )
        await globalCommands.registerHandlers(dispatcher: self)

        // Register catch-all router handler
        await addRouterHandler()
    }

    // MARK: - Router Handler (Lowest Priority - Catch-all)

    private func addRouterHandler() async {
        await add(TGBaseHandler({ [weak self] update in
            guard let self = self else { return }

            let unsafeMessage = update.editedMessage?.from ?? update.message?.from
            guard let entity = unsafeMessage ?? update.callbackQuery?.from else { return }

            // Check authorization
            if !allowedUsers.contains(entity.id) {
                let concern = "[D20] Unauthorized user tried to access: \(entity.id), @\(entity.username ?? "\"No Username\"")."
                print(concern)
                let string = "Sorry, you are not allowed. Your user ID: \(entity.id). Please ask @SixPathsOfMax for an invite."
                let chatId = TGChatId.chat(entity.id)
                let ownerId = TGChatId.chat(mitya)
                let params = TGSendMessageParams(chatId: chatId, text: string, parseMode: .html)
                let backup = TGSendMessageParams(chatId: ownerId, text: concern, parseMode: .html)
                _ = try? await self.bot.sendMessage(params: params)
                _ = try? await self.bot.sendMessage(params: backup)
                return
            }

            // Get user session with caching
            let session = try await User.cachedSession(for: entity, db: self.db)

            // Route to appropriate controller
            let props: [String: Int64] = ["session": session.telegramId]
            let key = session.routerName

            try await store.process(
                key: key,
                update: update,
                properties: props,
                db: self.db,
                lingo: self.lingo
            )
        }))
    }
}
