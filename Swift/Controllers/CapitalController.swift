//
//  CapitalController.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 19.04.2026.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

// MARK: - Capital Controller Logic (stub)
final class CapitalController: TGControllerBase, @unchecked Sendable {
    typealias T = CapitalController

    // MARK: - Controller Lifecycle
    override public func attachHandlers(to bot: TGBot, lingo: Lingo) async {
        let router = Router(bot: bot) { router in
            router[Commands.start.command()] = onStart

            let cancelLocales = Commands.cancel.buttonsForAllLocales(lingo: lingo)
            for button in cancelLocales { router[button.text] = onCancel }

            router.unmatched = unmatched
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
        try await showStub(context: context)
        return true
    }

    public func showStub(context: Context) async throws {
        // Guard: the capital is two days' ride — the governor can't reach it
        // while they're out on expedition. Same rule for active and passive.
        if try await ExplorationState.current(for: context.session, on: context.db) != nil {
            let notice = context.lingo.localize("capital.blocked_by_expedition", locale: context.session.locale)
            try await context.bot.sendMessage(
                session: context.session,
                text: notice,
                parseMode: .html,
                replyMarkup: nil
            )
            return
        }

        // Entering capital — own the routerName transition so callers don't
        // have to (and can't mis-transition when the guard above bails out).
        context.session.routerName = routerName
        try await context.session.saveAndCache(in: context.db)

        let text = context.lingo.localize("stub.coming_soon", locale: context.session.locale)
        let markup = generateControllerKB(session: context.session, lingo: context.lingo)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    override public func generateControllerKB(session: User, lingo: Lingo) -> TGReplyMarkup? {
        let markup = TGReplyKeyboardMarkup(keyboard: [[
            Commands.cancel.button(for: session, lingo)
        ]], resizeKeyboard: true)
        return TGReplyMarkup.replyKeyboardMarkup(markup)
    }
}
