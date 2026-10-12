//
//  RecipeNoteDisplay.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 10.10.2026.
//
//  How the journal's recipe notes read: the card's «📌» button and what its tap
//  answers, and each note as the «📌 Рецепти» screen prints it.
//
//  An entry is priced afresh from the catalog step the card prices, counted
//  where the card counts — the Master's notes in the BAG, because he draws from
//  the bag (auto-memory `project-master-draws-from-bag`); the estate's in bag +
//  warehouse through `CraftingService.stock` — and printed through
//  `RequirementLine`, so a note and its card cannot phrase one number two ways.
//
//  The layout is the owner's, approved on real numbers on 2026-10-09 and
//  2026-10-10: a title with where to do it («· Майстер, Поділ», «· Майстерня,
//  маєток»; none for the estate and the ground, whose title IS the place), the
//  card's own subject line, then the gate, the materials and the silver, in
//  that order. A recipe is one line — its product is both title and subject.
//

import Foundation
import Lingo
import SwiftTelegramBot

enum RecipeNoteDisplay {

    struct Entry {
        let lines: [String]
        /// The «❌» button's name for this note, without the ❌.
        let removeLabel: String
    }

    // MARK: - The card

    /// The card's own row, under its action: «📌 У нотатник», or «📌 Прибрати з
    /// нотатника» once pinned.
    static func pinRow(pinned: Bool, callbackData: String, lingo: Lingo, locale: String) -> [TGInlineKeyboardButton] {
        let key = pinned ? "notes.button.unpin" : "notes.button.pin"
        return [TGInlineKeyboardButton(text: lingo.localize(key, locale: locale), callbackData: callbackData)]
    }

    /// Pin or unpin `key` and answer the tap: a toast for a pin or an unpin,
    /// the modal for a full journal. Every path answers — a throw from the
    /// service is answered on the way out, because a tap nothing answers spins
    /// forever. True when the card's button changed and the card wants a redraw.
    static func toggle(_ key: RecipeNote.Key, query: TGCallbackQuery, context: Context) async throws -> Bool {
        let result: RecipeNoteService.ToggleResult
        do {
            result = try await RecipeNoteService.toggle(key, for: context.session, on: context.db)
        } catch {
            _ = try? await context.bot.answerCallbackQuery(params: TGAnswerCallbackQueryParams(callbackQueryId: query.id))
            throw error
        }
        let lingo = context.lingo
        let locale = context.session.locale
        let params: TGAnswerCallbackQueryParams
        switch result {
        case .pinned(let count):
            // 📌 prepended in Swift — Lingo's `%{var}` parser breaks on an
            // emoji ahead of a placeholder.
            let text = "📌 " + lingo.localize("notes.toast.pinned", locale: locale, interpolations: [
                "count": "\(count)", "max": "\(RecipeNoteService.capacity)"
            ])
            params = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text)
        case .unpinned:
            params = TGAnswerCallbackQueryParams(callbackQueryId: query.id,
                                                 text: lingo.localize("notes.toast.unpinned", locale: locale))
        case .full:
            let text = lingo.localize("notes.alert.full", count: RecipeNoteService.capacity, locale: locale, interpolations: [
                "count": "\(RecipeNoteService.capacity)"
            ])
            params = TGAnswerCallbackQueryParams(callbackQueryId: query.id, text: text, showAlert: true)
        }
        _ = try? await context.bot.answerCallbackQuery(params: params)
        return result != .full
    }

    // MARK: - The journal

    /// The journal's button, always shown — at 0 too, so a player learns the
    /// notes exist (the owner's pick).
    static func journalButton(count: Int, lingo: Lingo, locale: String) -> TGInlineKeyboardButton {
        // 📌 prepended in Swift — the count is a placeholder.
        let text = "📌 " + lingo.localize("notes.button.open", locale: locale, interpolations: ["count": "\(count)"])
        return TGInlineKeyboardButton(text: text, callbackData: "notes:open")
    }

    /// The «📌 Рецепти» screen: every note, its «❌» two to a row in the order
    /// the notes stand, and the way back to the journal.
    static func screen(notes: [RecipeNote], user: User, stock: [String: CraftingService.StockLine],
                       lingo: Lingo, locale: String) -> (text: String, keyboard: TGInlineKeyboardMarkup) {
        var blocks: [String] = []
        var removeButtons: [TGInlineKeyboardButton] = []
        for note in notes {
            guard let id = note.id, let entry = entry(note, user: user, stock: stock, lingo: lingo, locale: locale) else { continue }
            blocks.append(entry.lines.joined(separator: "\n"))
            removeButtons.append(TGInlineKeyboardButton(text: "❌ " + entry.removeLabel, callbackData: "notes:del:\(id.uuidString)"))
        }
        let body = blocks.isEmpty
            ? "<i>" + lingo.localize("notes.empty", locale: locale) + "</i>"
            : blocks.joined(separator: "\n\n")
        var rows = stride(from: 0, to: removeButtons.count, by: 2).map {
            Array(removeButtons[$0 ..< min($0 + 2, removeButtons.count)])
        }
        rows.append([TGInlineKeyboardButton(text: lingo.localize("notes.button.back", locale: locale), callbackData: "journal:open")])
        let text = "📌 <b>" + lingo.localize("notes.title", locale: locale) + "</b>\n\n" + body
        return (text, TGInlineKeyboardMarkup(inlineKeyboard: rows))
    }

    /// One note as the screen prints it, or nil when it can no longer be priced
    /// — which `RecipeNoteService.live` has already dropped by the time this runs.
    static func entry(_ note: RecipeNote, user: User, stock: [String: CraftingService.StockLine],
                      lingo: Lingo, locale: String) -> Entry? {
        guard let kind = note.kind else { return nil }
        let master = lingo.localize("notes.place.master", locale: locale)
        let workshop = lingo.localize("notes.place.workshop", locale: locale)
        let arrow = lingo.localize("weapon.upgrade.delta_arrow", locale: locale)
        // Where each place draws from: the estate's rooms from bag + warehouse,
        // the Master from the bag alone.
        func held(_ itemId: String) -> Int { stock[itemId]?.total ?? 0 }
        func inBag(_ itemId: String) -> Int { stock[itemId]?.bag ?? 0 }
        func title(_ text: String, place: String? = nil) -> String {
            "<b>\(text)</b>" + (place.map { " · \($0)" } ?? "")
        }
        func material(_ itemId: String, _ need: Int, have: Int) -> String {
            RequirementLine.item(itemId, have: have, need: need, lingo: lingo, locale: locale)
        }
        func playerLevel(_ need: Int) -> String {
            RequirementLine.render(label: lingo.localize("estate.upgrade.level_label", locale: locale), have: user.level, need: need)
        }
        func silver(_ need: Int) -> String {
            RequirementLine.silver(have: user.silver, need: need, lingo: lingo, locale: locale)
        }

        switch kind {
        case .lesson, .weapon:
            guard let item = ItemCatalog.find(note.ref),
                  let step = WeaponUpgradeCatalog.step(for: note.ref, tier: note.target) else { return nil }
            let icon = item.icon.map { "\($0) " } ?? ""
            let from = lingo.localize(ItemDisplay.nameKey(for: item, tier: note.target - 1), locale: locale)
            let to = lingo.localize(ItemDisplay.nameKey(for: item, tier: note.target), locale: locale)
            let subject = "\(icon)<b>\(from)</b> → <b>\(to)</b>"
            if kind == .lesson {
                // The lesson card's own lines: no gate (the Master offers the
                // lesson only once it is open), materials, then his fee.
                var lines = [title(lingo.localize("capital.master.lesson.title", locale: locale), place: master), subject]
                lines += step.inputs.map { material($0.itemId, $0.quantity, have: inBag($0.itemId)) }
                lines.append(silver(MasterCatalog.weaponLessonSilver))
                return Entry(lines: lines, removeLabel: lingo.localize("notes.remove.lesson", locale: locale))
            }
            var lines = [title(lingo.localize("notes.kind.weapon", locale: locale), place: workshop), subject,
                         playerLevel(step.requiredPlayerLevel)]
            lines += step.inputs.map { material($0.itemId, $0.quantity, have: held($0.itemId)) }
            return Entry(lines: lines, removeLabel: lingo.localize("notes.remove.weapon", locale: locale))

        case .enchant:
            guard let item = ItemCatalog.find(note.ref),
                  let step = MasterCatalog.enchantStep(currentLevel: note.target - 1) else { return nil }
            let label = Controllers.capitalController.itemLabel(note.ref, lingo: lingo, locale: locale)
            return Entry(lines: [
                title(lingo.localize("notes.kind.enchant", locale: locale), place: master),
                "\(label) +\(note.target - 1) → +\(note.target)",
                material(step.materialId, step.materialQty, have: inBag(step.materialId)),
                silver(step.silver)
            ], removeLabel: lingo.localize(item.nameKey, locale: locale))

        case .bag:
            guard let step = BagCatalog.nextStep(from: note.target - 1) else { return nil }
            var lines = [
                title(lingo.localize("bag.upgrade.title", locale: locale), place: workshop),
                "\(arrow) " + lingo.localize("bag.upgrade.next_header", locale: locale, interpolations: [
                    "tier": "\(step.toTier)",
                    "name": lingo.localize("bag.tier.\(step.toTier).name", locale: locale),
                    "capacity": "\(step.capacity)",
                    "delta": "\(step.capacity - BagCatalog.capForTier(step.toTier - 1))"
                ]),
                RequirementLine.render(label: lingo.localize("upgrade.estate_level_label", locale: locale),
                                       have: user.estateLevel, need: step.requiredEstateLevel)
            ]
            lines += step.inputs.map { material($0.itemId, $0.quantity, have: held($0.itemId)) }
            return Entry(lines: lines, removeLabel: lingo.localize("notes.remove.bag", locale: locale))

        case .recipe:
            guard let recipe = RecipeCatalog.find(note.ref), recipe.category.isCraftable,
                  let output = ItemCatalog.find(recipe.output.itemId) else { return nil }
            let name = lingo.localize(output.nameKey, locale: locale)
            let icon = output.icon.map { "\($0) " } ?? ""
            let place = lingo.localize(recipe.category == .kitchen ? "notes.place.kitchen" : "notes.place.workshop", locale: locale)
            var lines = ["\(icon)<b>\(name)</b> · \(place)"]
            lines += recipe.inputs.map { material($0.itemId, $0.quantity, have: held($0.itemId)) }
            return Entry(lines: lines, removeLabel: name)

        case .estate:
            guard let step = EstateUpgradeCatalog.nextStep(from: note.target - 1) else { return nil }
            var lines = [
                title(lingo.localize("estate.upgrade.title", locale: locale)),
                "\(arrow) " + lingo.localize("estate.upgrade.next_header", locale: locale, interpolations: [
                    "tier": "\(step.toTier)",
                    "name": lingo.localize("estate.tier.\(step.toTier).name", locale: locale)
                ]),
                playerLevel(step.requiredPlayerLevel)
            ]
            lines += step.inputs.map { material($0.itemId, $0.quantity, have: held($0.itemId)) }
            if step.silverCost > 0 { lines.append(silver(step.silverCost)) }
            return Entry(lines: lines, removeLabel: lingo.localize("notes.remove.estate", locale: locale))

        case .training:
            guard let step = TrainingGroundCatalog.level(note.target) else { return nil }
            let cls = CharacterClass(rawValue: user.characterClass ?? "") ?? .warrior
            let technique = CombatService.TechniqueKind(rawValue: step.technique)
                .map { lingo.localize(EstateController.techniqueNameKey(kind: $0, class: cls), locale: locale) } ?? step.technique
            // Level 1 is the building itself, and its card says so — and that
            // the dummy comes with it.
            let building = note.target == 1
            var lines = [
                title(lingo.localize(building ? "estate.training.title" : "estate.training.upgrade.title", locale: locale)),
                "\(arrow) " + lingo.localize(building ? "estate.training.upgrade.next_with_spar" : "estate.training.upgrade.next",
                                             locale: locale, interpolations: ["level": "\(step.level)", "name": technique]),
                playerLevel(TrainingGroundCatalog.playerLevel(for: step))
            ]
            lines += step.inputs.map { material($0.itemId, $0.quantity, have: held($0.itemId)) }
            if step.silverCost > 0 { lines.append(silver(step.silverCost)) }
            return Entry(lines: lines, removeLabel: lingo.localize("notes.remove.training", locale: locale))
        }
    }
}
