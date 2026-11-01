//
//  CapitalController+Rewards.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.11.2026.
//
//  A holiday's prizes, in the palace after the close (2026-11-01, the owner —
//  `content/spec/event-veles-night.md` §4.8). Under the palace card, for every
//  holiday whose prize the reader is still owed: the King's words, the place
//  and the blood, a «💰» line naming the prize, and «🎁 Отримати нагороду».
//  The tap pays it all in one transaction (`EventRewardService.claim`); the
//  King's words stay, the button goes, and a banner is the receipt.
//
//  The offer repeats on every palace visit until it is collected — a reader
//  whose bag was full comes back for it. The button's callback is claimed in
//  `MainController`, where every router's unknown callbacks arrive, like the
//  flask's. It pays only in the capital and with the bag in the player's hands:
//  the items go into the bag, which a walk counts and the governor holds.
//

import Fluent
import Foundation
@preconcurrency import Lingo
import SwiftTelegramBot

extension CapitalController {

    /// `event:reward:<event>` — the longest event id leaves it at 37 bytes.
    static let rewardCallbackPrefix = "event:reward:"

    // MARK: - The offer

    /// The King's words under the palace card, for each prize still owed.
    func sendRewardOffersIfDue(context: Context) async throws {
        for owed in try await EventRewardService.allOwed(context.session, on: context.db) {
            let lingo = context.lingo, locale = context.session.locale
            let keyboard = TGInlineKeyboardMarkup(inlineKeyboard: [[
                TGInlineKeyboardButton(text: lingo.localize(EventKeys.rewardButton, locale: locale),
                                       callbackData: Self.rewardCallbackPrefix + owed.event.id)
            ]])
            try await context.bot.sendMessage(session: context.session,
                                              text: Self.offerText(owed, lingo: lingo, locale: locale),
                                              parseMode: .html,
                                              replyMarkup: .inlineKeyboardMarkup(keyboard))
        }
    }

    /// «👑 Король підводиться…» / «🥇 1-ше місце · 666 🩸» / «💰 🟡 100 златників · …».
    static func offerText(_ owed: EventRewardService.Owed, lingo: Lingo, locale: String) -> String {
        let place = owed.prize.place
        let medal = place == 1 ? "🥇 " : place == 2 ? "🥈 " : place == 3 ? "🥉 " : ""
        let placeLine = medal + lingo.localize(EventKeys.rewardPlace, locale: locale, interpolations: [
            "place": EventNoticeText.ordinal(place, locale: locale),
            "blood": "\(owed.blood)"
        ])
        return "👑 " + lingo.localize(owed.event.keys.rewardKing, locale: locale) + "\n"
            + placeLine + "\n"
            + "💰 " + prizeParts(owed.prize, lingo: lingo, locale: locale).joined(separator: " · ")
    }

    /// The prize named part by part — zlatnyks, silver, then the items.
    private static func prizeParts(_ prize: EventPrize, lingo: Lingo, locale: String) -> [String] {
        var parts: [String] = []
        if prize.zlatnyks > 0 {
            parts.append("🟡 \(prize.zlatnyks) " + lingo.localize("unit.zlatnyk", count: prize.zlatnyks, locale: locale))
        }
        if prize.silver > 0 {
            parts.append("🪙 \(prize.silver) " + lingo.localize("unit.silver", count: prize.silver, locale: locale))
        }
        for item in prize.items {
            parts.append(itemPhrase(item, lingo: lingo, locale: locale))
        }
        return parts
    }

    /// «🍽 Бенкет Намісника ×5».
    private static func itemPhrase(_ item: EventRewardItemDTO, lingo: Lingo, locale: String) -> String {
        let found = ItemCatalog.find(item.itemId)
        let icon = found?.icon.map { "\($0) " } ?? ""
        let name = found.map { lingo.localize($0.nameKey, locale: locale) } ?? item.itemId
        return "\(icon)\(name) ×\(item.count)"
    }

    // MARK: - «🎁 Отримати нагороду»

    /// Answered exactly once: a refusal is the tap's modal, so it answers
    /// late, and its `catch` answers before rethrowing — an unanswered tap
    /// spins. A refusal keeps the button: the prize is still owed.
    static func onRewardCallback(_ data: String, query: TGCallbackQuery, message: TGMaybeInaccessibleMessage,
                                 context: Context) async throws {
        let lingo = context.lingo, locale = context.session.locale
        func answer(_ alert: String? = nil) async {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(
                callbackQueryId: query.id, text: alert, showAlert: alert != nil))
        }
        // The King's words stay as they were said; only the button goes (the
        // arena's `stripTappedButtons`).
        func stripButton() async {
            _ = try? await context.bot.editMessageReplyMarkup(params: TGEditMessageReplyMarkupParams(
                chatId: .chat(message.chat.id), messageId: message.messageId,
                replyMarkup: TGInlineKeyboardMarkup(inlineKeyboard: [])))
        }
        guard let event = EventCatalog.find(String(data.dropFirst(rewardCallbackPrefix.count))) else {
            // The holiday has left the data: nothing to pay, and no line to say it with.
            await answer()
            await stripButton()
            return
        }
        do {
            // The bag is the governor's while he is out (`InventoryController`).
            if let run = try await InventoryController.passiveRun(holding: context.session, on: context.db) {
                await answer(InventoryController.passiveLockAlert(run, context: context))
                return
            }
            // In person, at the palace: not on the road, not in the forest.
            let travelling = try await TravelState.current(for: context.session, on: context.db) != nil
            if context.session.location != "capital" || travelling {
                await answer("👑 " + lingo.localize(EventKeys.rewardElsewhere, locale: locale))
                return
            }
            let receipt = try await EventRewardService.claim(context.session, event: event, on: context.db)
            await answer()
            await stripButton()
            await Controllers.capitalController.postStatusBanner(
                "✅ " + receiptText(receipt, lingo: lingo, locale: locale), context: context)
        } catch EventRewardService.Refusal.nothingOwed {
            // Collected already — a second tap, or a second offer under it.
            await answer()
            await stripButton()
        } catch EventRewardService.Refusal.bagFull(let need, let free) {
            await answer(bagFullAlert(need: need, free: free, lingo: lingo, locale: locale))
        } catch InventoryError.inventoryFull {
            // The bag filled between the check and the write; nothing was paid.
            let used = (try? await InventoryEntry.slotsUsed(for: context.session, on: context.db)) ?? 0
            let cap = InventoryEntry.slotCap(for: context.session)
            let need = (try? await EventRewardService.owed(context.session, event: event, on: context.db))??.prize.units ?? 0
            await answer(bagFullAlert(need: need, free: Swift.max(0, cap - used), lingo: lingo, locale: locale))
        } catch {
            await answer()
            throw error
        }
    }

    private static func bagFullAlert(need: Int, free: Int, lingo: Lingo, locale: String) -> String {
        "🎒 " + lingo.localize(EventKeys.rewardBagFull, locale: locale,
                              interpolations: ["need": "\(need)", "free": "\(free)"])
    }

    /// «Нагороду отримано: 🟡 +100 (тепер 100) · 🪙 +1000 (тепер 7150) · 🍽 Бенкет Намісника ×5 — у сумці».
    private static func receiptText(_ receipt: EventRewardService.Receipt, lingo: Lingo, locale: String) -> String {
        var parts: [String] = []
        if let balance = receipt.zlatnyks {
            parts.append("🟡 " + lingo.localize(EventKeys.rewardBalance, locale: locale, interpolations: [
                "amount": "\(receipt.prize.zlatnyks)", "balance": "\(balance)"
            ]))
        }
        if let balance = receipt.silver {
            parts.append("🪙 " + lingo.localize(EventKeys.rewardBalance, locale: locale, interpolations: [
                "amount": "\(receipt.prize.silver)", "balance": "\(balance)"
            ]))
        }
        let inBag = lingo.localize(EventKeys.rewardInBag, locale: locale)
        for item in receipt.prize.items {
            parts.append(itemPhrase(item, lingo: lingo, locale: locale) + " — " + inBag)
        }
        return lingo.localize(EventKeys.rewardReceived, locale: locale, interpolations: [
            "parts": parts.joined(separator: " · ")
        ])
    }
}
