//
//  ExplorationController+Manor.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.10.2026.
//
//  A holiday's manor on the walk (`content/spec/event-veles-night.md`): the
//  entrance at its km (or, without the scribe's flask, the way to the palace),
//  the gate's question, the step deeper that is always a fight, the step back
//  the gate refuses, and the close that walks the player out. The rules are
//  `ManorService`'s; these are the screens.
//
//  The walk's own reply keyboard stays: «🚶 Крок вперед» goes deeper, «🎒
//  Сумка» eats between fights, «🔙 Крок назад» is refused. `/start` and a stray
//  Cancel redraw the manor like they redraw the forest — the manor is left by
//  dying or by the close, never by a hatch.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

/// What the death screen needs from a manor before the row that holds it goes.
struct ManorDeath: Sendable {
    let event: GameEvent
    /// The blood this descent poured.
    let run: Int

    init?(state: ExplorationState?) {
        guard let state, let eventId = state.manorEventId, let event = EventCatalog.find(eventId) else { return nil }
        self.event = event
        self.run = state.manorRunBlood ?? 0
    }
}

extension ExplorationController {

    // MARK: - The entrance

    /// Show the entrance once per walk, when the walk stands at its km while
    /// the manor is open (`ManorService.entranceDue`). Its own message, under
    /// the step that arrived, with the one button; the button stays in the chat
    /// and works whenever the player stands there again. A walk without the
    /// scribe's flask is shown the manor and the way to the palace instead of
    /// the button (2026-10-30) — it cannot fetch the flask without leaving the
    /// forest, so once per walk is enough for that too.
    func offerManorIfDue(context: Context, state: ExplorationState) async throws {
        guard let event = ManorService.entranceDue(for: state) else { return }
        let hasFlask = try await EventBlood.hasFlask(context.session, eventId: event.id, on: context.db)
        state.manorOffered = event.id
        try await state.save(on: context.db)
        let lingo = context.lingo, locale = context.session.locale
        guard hasFlask else {
            try await context.bot.sendMessage(session: context.session,
                                              text: noFlaskEntrance(event, lingo: lingo, locale: locale), parseMode: .html)
            return
        }
        let (text, markup) = entranceScreen(event, lingo: lingo, locale: locale)
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html,
                                          replyMarkup: .inlineKeyboardMarkup(markup))
    }

    private func entranceScreen(_ event: GameEvent, lingo: Lingo, locale: String) -> (String, TGInlineKeyboardMarkup) {
        let keys = event.keys
        let text = "🏚 " + lingo.localize(keys.entrance, locale: locale)
        let markup = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: lingo.localize(keys.entranceButton, locale: locale),
                                   callbackData: "explore:manor:\(event.id)")
        ]])
        return (text, markup)
    }

    /// The entrance with the way to the palace where its button would be.
    private func noFlaskEntrance(_ event: GameEvent, lingo: Lingo, locale: String) -> String {
        "🏚 " + lingo.localize(event.keys.entrance, locale: locale) + "\n"
            + lingo.localize(event.keys.entranceNoFlask, locale: locale)
    }

    /// The gate's question — what a death would take from the bag, named the
    /// way the death screen names it, and that the flask is not the bag.
    private func confirmScreen(_ event: GameEvent, context: Context) async throws -> (String, TGInlineKeyboardMarkup) {
        let lingo = context.lingo
        let locale = context.session.locale
        let keys = event.keys
        let preview = try await InventoryEntry.deathPreview(for: context.session, on: context.db)
        let bag: String
        if preview.isEmpty {
            bag = lingo.localize(keys.confirmBagEmpty, locale: locale)
        } else {
            let names = preview.map { loss -> String in
                let item = ItemCatalog.find(loss.itemId)
                let icon = item?.icon.map { "\($0) " } ?? ""
                let name = item.map { lingo.localize(ItemDisplay.nameKey(for: $0, tier: loss.tier), locale: locale) } ?? loss.itemId
                return "\(icon)\(name) ×\(loss.quantity)"
            }
            bag = lingo.localize(keys.confirmBag, locale: locale, interpolations: ["loss": names.joined(separator: ", ")])
        }
        let text = [
            "🕯 " + lingo.localize(keys.confirm, locale: locale),
            "🩸 " + lingo.localize(keys.confirmBlood, locale: locale),
            "🎒 " + bag
        ].joined(separator: "\n")
        let markup = TGInlineKeyboardMarkup(inlineKeyboard: [[
            TGInlineKeyboardButton(text: lingo.localize(keys.confirmEnter, locale: locale),
                                   callbackData: "explore:manor_in:\(event.id)"),
            TGInlineKeyboardButton(text: lingo.localize(keys.confirmStay, locale: locale),
                                   callbackData: "explore:manor_stay:\(event.id)")
        ]])
        return (text, markup)
    }

    /// `explore:manor:<event>` (the entrance), `explore:manor_in:<event>` (step
    /// in), `explore:manor_stay:<event>` (back to the entrance). Every tap asks
    /// `ManorService.refusal` first: the buttons outlive the walk that was shown
    /// them, and an old one must not open a gate from the estate or the road.
    func onManorButton(context: Context, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage,
                       data: String) async throws {
        let lingo = context.lingo
        let locale = context.session.locale
        let parts = data.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3, let event = EventCatalog.find(parts[2]) else {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return
        }
        let action = parts[1]
        let keys = event.keys
        // The reads that decide the answer come before the answer, so a throw
        // here is answered before it is rethrown — an unanswered tap spins.
        let state: ExplorationState?
        let hasFlask: Bool
        do {
            state = try await ExplorationState.current(for: context.session, on: context.db)
            hasFlask = try await EventBlood.hasFlask(context.session, eventId: event.id, on: context.db)
        } catch {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            throw error
        }

        switch ManorService.refusal(event: event, state: state, hasFlask: hasFlask) {
        case .closed:
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            _ = await editScreen(message, text: "🏚 " + lingo.localize(keys.entranceGone, locale: locale),
                                 replyMarkup: nil, bot: context.bot)
            return
        case .elsewhere:
            let alert = lingo.localize(keys.entranceElsewhere, locale: locale,
                                       interpolations: ["km": "\(event.dto.entranceKm)"])
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: alert, showAlert: true))
            return
        case .busy:
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            return
        case .noFlask:
            // Only a walk with the flask is ever shown the button, and the
            // flask cannot be lost; should one be tapped without it anyway,
            // the entrance is redrawn as the walk without a flask sees it.
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            _ = await editScreen(message, text: noFlaskEntrance(event, lingo: lingo, locale: locale),
                                 replyMarkup: nil, bot: context.bot)
            return
        case nil:
            break
        }
        guard let state else { return }
        _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))

        switch action {
        case "manor_in":
            ManorService.enter(state, event: event)
            try await state.save(on: context.db)
            // The question stays in the chat as it was asked, without its
            // buttons; the manor arrives as a message of its own, because only
            // a new message can carry the walk's reply keyboard.
            let (question, _) = try await confirmScreen(event, context: context)
            _ = await editScreen(message, text: question, replyMarkup: nil, bot: context.bot)
            if context.session.routerName != routerName {
                context.session.routerName = routerName
                try await context.session.saveAndCache(in: context.db)
            }
            try await showManor(context: context, state: state, lead: nil, art: true)
        case "manor_stay":
            let (text, markup) = entranceScreen(event, lingo: lingo, locale: locale)
            _ = await editScreen(message, text: text, replyMarkup: markup, bot: context.bot)
        default:
            let (text, markup) = try await confirmScreen(event, context: context)
            _ = await editScreen(message, text: text, replyMarkup: markup, bot: context.bot)
        }
    }

    // MARK: - Inside

    /// The manor's screen with the walk's keyboard. At the gate (depth 0) it
    /// carries the first room's line, which is the step through the gate; deeper,
    /// a room's line is said once, when a step enters it (`CombatController`'s
    /// intro), so the screen after every fight stays three lines.
    ///
    /// `art` is the step through the gate (2026-10-30): the holiday's manor
    /// picture under the card, when it ships one. Its caption is the gate's
    /// card, ~220 of the 1,024, and nothing ever edits a manor screen in place —
    /// every later one is a message of its own — so no caption edit can outgrow it.
    func showManor(context: Context, state: ExplorationState, lead: String?, art: Bool = false) async throws {
        guard let eventId = state.manorEventId, let event = EventCatalog.find(eventId), !event.isOver(at: Date()) else {
            try await releaseFromManor(context: context, state: state, lead: lead)
            return
        }
        let card = try await manorCard(user: context.session, state: state, event: event,
                                       lingo: context.lingo, locale: context.session.locale, db: context.db)
        let text = lead.map { "\($0)\n\n\(card)" } ?? card
        let markup = generateControllerKB(session: context.session, lingo: context.lingo)
        if art, let picture = event.artPath(.manor) {
            _ = try await sendCachedPhoto(assetPath: picture, caption: text, replyMarkup: markup,
                                          toUser: context.session, bot: context.bot)
            return
        }
        try await context.bot.sendMessage(session: context.session, text: text, parseMode: .html, replyMarkup: markup)
    }

    func manorCard(user: User, state: ExplorationState, event: GameEvent, lingo: Lingo, locale: String,
                   db: any Database) async throws -> String {
        let keys = event.keys
        let depth = state.manorDepth ?? 0
        var head: String
        if depth == 0 {
            head = "🏚 <b>" + lingo.localize(keys.manorGate, locale: locale) + "</b>"
            if let first = event.dto.rooms.first {
                head += " " + lingo.localize(keys.room(first.id), locale: locale)
            }
        } else {
            head = "🏚 <b>" + lingo.localize(keys.manorTitle, locale: locale, interpolations: ["depth": "\(depth)"]) + "</b>"
        }
        let starving = VigorService.isStarving(user) ? " · " + lingo.localize("vigor.starving", locale: locale) : ""
        let total = try await EventBlood.total(for: user, eventId: event.id, on: db)
        let blood = "🩸 " + lingo.localize(keys.manorBlood, locale: locale, interpolations: [
            "run": "\(state.manorRunBlood ?? 0)", "total": "\(total)"
        ])
        return """
        \(head)
        ❤️ \(user.hp)/\(user.effectiveMaxHp)  🍖 \(user.vigor)/\(user.maxVigor)\(starving)
        \(blood)
        """
    }

    /// «🚶 Крок вперед» inside: one depth deeper, and its creature. Past the
    /// close the step walks the player out instead.
    func manorStepForward(context: Context, state: ExplorationState) async throws {
        guard let eventId = state.manorEventId, let event = EventCatalog.find(eventId), !event.isOver(at: Date()),
              let step = ManorService.step(context.session, state: state, event: event) else {
            try await releaseFromManor(context: context, state: state, lead: nil)
            return
        }
        try await state.save(on: context.db)
        try await context.session.saveAndCache(in: context.db)

        if context.session.hp <= 0 {
            // Hunger finished the step before anything stood there.
            let cause = narrateStarvation(step.starvationHpLost, lingo: context.lingo, locale: context.session.locale) ?? ""
            try await Self.handleDeath(context: context, causeNarrative: cause, manor: ManorDeath(state: state))
            return
        }
        switch step.encounter {
        case .creature(let enemy, _):
            try await handOffToCombat(context: context, state: state, enemy: enemy,
                                      starvationHpLost: step.starvationHpLost)
        case .find(let find, let hp, let vigor):
            try await showManor(context: context, state: state,
                                lead: findLead(event, find: find, step: step, hpRestored: hp, vigorRestored: vigor,
                                               user: context.session, lingo: context.lingo, locale: context.session.locale))
        }
    }

    /// A find's lines above the manor card (2026-10-30): the room's line when
    /// the step entered a new room past the first (as a creature's intro says
    /// it), the hunger tick if the step began starving — before the find, whose
    /// receipt already counts it — then the find and what it put back, phrased
    /// as a meal's is (`vigor.restored`, `hp.restored`, a pool that topped out).
    private func findLead(_ event: GameEvent, find: EventFindDTO, step: ManorService.Step, hpRestored: Int,
                          vigorRestored: Int, user: User, lingo: Lingo, locale: String) -> String {
        var blocks: [String] = []
        if let room = event.dto.room(forDepth: step.depth), step.depth == room.fromDepth, step.depth > 1 {
            blocks.append(lingo.localize(event.keys.room(room.id), locale: locale))
        }
        if let hunger = narrateStarvation(step.starvationHpLost, lingo: lingo, locale: locale) {
            blocks.append(hunger)
        }
        var parts: [String] = []
        if vigorRestored > 0 {
            parts.append(lingo.localize("vigor.restored", locale: locale, interpolations: [
                "amount": "\(vigorRestored)", "current": "\(user.vigor)", "max": "\(user.maxVigor)"
            ]))
        }
        if hpRestored > 0 {
            parts.append(lingo.localize("hp.restored", locale: locale, interpolations: [
                "amount": "\(hpRestored)", "current": "\(user.hp)", "max": "\(user.effectiveMaxHp)"
            ]))
        }
        if user.vigor >= user.maxVigor { parts.append("🍖 " + lingo.localize("vigor.full", locale: locale)) }
        if user.hp >= user.effectiveMaxHp { parts.append("❤️ " + lingo.localize("hp.full", locale: locale)) }
        var block = "\(find.icon) " + lingo.localize(event.keys.findText(find.id), locale: locale)
        if !parts.isEmpty { block += "\n✅ " + parts.joined(separator: ", ") }
        blocks.append(block)
        return blocks.joined(separator: "\n\n")
    }

    /// «🔙 Крок назад» inside: the gate is shut. The refusal redraws the manor,
    /// so the tap that was refused is also the one that repairs the screen.
    func manorRefuseStepBack(context: Context, state: ExplorationState) async throws {
        guard let eventId = state.manorEventId, let event = EventCatalog.find(eventId), !event.isOver(at: Date()) else {
            try await releaseFromManor(context: context, state: state, lead: nil)
            return
        }
        let line = "🔙 " + context.lingo.localize(event.keys.noWayBack, locale: context.session.locale)
        try await showManor(context: context, state: state, lead: line)
    }

    /// The close: back on the forest path at the entrance km, the walk going on.
    /// A holiday dropped from the data walks the player out the same way, with
    /// no line it could no longer say.
    func releaseFromManor(context: Context, state: ExplorationState, lead: String?) async throws {
        let event = state.manorEventId.flatMap(EventCatalog.find)
        ManorService.release(state)
        try await state.save(on: context.db)

        let lingo = context.lingo
        let locale = context.session.locale
        var parts: [String] = []
        if let lead { parts.append(lead) }
        if let event { parts.append("🕯 " + lingo.localize(event.keys.closed, locale: locale)) }
        parts.append(renderStatusCard(user: context.session, state: state, lingo: lingo, locale: locale))
        let markup = generateControllerKB(session: context.session, lingo: lingo)
        try await context.bot.sendMessage(session: context.session, text: parts.joined(separator: "\n\n"),
                                          parseMode: .html, replyMarkup: markup)
    }
}
