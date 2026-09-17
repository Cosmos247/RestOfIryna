//
//  RequirementLine.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 17.09.2026.
//
//  One rendering of "this is what it costs, and this is what you have" — the
//  sentence the game says on more screens than any other.
//
//  It said it four ways. The kitchen recipe read «2× 🥩 Сире м'ясо — маєте 3»,
//  the estate / weapon / bag upgrade screens read «1× 🪵 Соснова дошка (12/1)»,
//  the shortage modal read «• 🔩 Шматок заліза — треба ще 2 (1/3)», and the
//  gate lines read «Тир маєтку: треба 3 (у вас 2)» beside a weapon screen that
//  read «Рівень маєтку: 2/3» for the very same gate two rows of code away.
//  Four dialects, ten call sites, all answering one question.
//
//  The form the user picked, 2026-09-17: marker, label, fraction in brackets.
//
//      ✅ 1× 🪵 Соснова дошка  (12/1)
//      ❌ 3× 🔩 Шматок заліза  (1/3)
//
//  The count prefix is kept: «3×» is what the recipe ASKS FOR, read before any
//  of the player's own numbers, and it survives being quoted on its own in a
//  sentence. The fraction answers a different question — how close you are —
//  and the marker answers it again at a glance, deliberately: a player scans
//  the column of ✅ and reads numbers only where one is ❌. A gate line has no
//  count (there is no «3× Рівень гравця»), which is why the prefix belongs to
//  `item` and not to `render`.
//
//  ⛔ is retired. It used to mean a gate and ❌ a shortage, which is a real
//  distinction nobody wrote down and no screen explained, and the same tap
//  ("go and get more") answers both.
//
//  A fraction needs no words, so the material and gate lines no longer reach
//  for Lingo at all beyond the item's own name — which is one fewer pair of
//  locale strings to keep in step. Anything that shows current-against-maximum
//  (durability 0/100, the bag 18/25, a plot 40/40) is a DIFFERENT sentence and
//  is not rendered here: a full bag is not a failed requirement.
//

import Foundation
import Lingo

public enum RequirementLine {

    /// Indent for a row that sits under a bold section header. Gate lines are
    /// their own paragraph and pass `""`.
    public static let blockIndent = "   "

    /// ✅ when the player already has enough, ❌ when they do not.
    public static func mark(have: Int, need: Int) -> String {
        have >= need ? "✅" : "❌"
    }

    /// `✅ 🪙 Срібло  (120/250)`. `label` is whatever names the thing — an item
    /// with its icon, or a localized word for a gate.
    public static func render(label: String, have: Int, need: Int, indent: String = blockIndent) -> String {
        "\(indent)\(mark(have: have, need: need)) \(label)  (\(have)/\(need))"
    }

    /// The same line for a content item, led by the count the recipe asks for:
    /// `✅ 3× 🔩 Шматок заліза  (1/3)`. The icon and the localized name are
    /// resolved here so the four material lists stop each doing it themselves —
    /// and so an item with no icon cannot leave the stray double space the
    /// hand-rolled versions all had.
    public static func item(_ itemId: String, have: Int, need: Int,
                            lingo: Lingo, locale: String, indent: String = blockIndent) -> String {
        guard let item = ItemCatalog.find(itemId) else {
            return render(label: "\(need)× \(itemId)", have: have, need: need, indent: indent)
        }
        let icon = item.icon.map { "\($0) " } ?? ""
        let name = lingo.localize(item.nameKey, locale: locale)
        return render(label: "\(need)× \(icon)\(name)", have: have, need: need, indent: indent)
    }

    /// Telegram's ceiling on `answerCallbackQuery.text`. A protocol constant,
    /// not a balance knob — the same kind of number as the 24 h dice-delete
    /// window, and it belongs beside the one function that can exceed it.
    public static let alertLimit = 200

    /// The modal a refused craft / upgrade throws up: header, then one row per
    /// missing input in exactly the shape of the screen the player just tapped.
    /// Four handlers had this same block copied out; two of them had already
    /// drifted in their comments alone.
    ///
    /// **It is capped, because the old one silently was not.** Over 200
    /// characters Telegram refuses the answer outright, and every call site
    /// swallows that with `try?` — so tapping Cook on the Governor's Feast, or
    /// Upgrade on any estate step from T4 up, produced no modal at all. Five
    /// cases were over, the worst at 262. Measured in UTF-16 because that
    /// is the unit Telegram counts, and a Ukrainian name is longer than its
    /// English twin: the English side never overflowed, which is exactly how a
    /// bug like this stays invisible to whoever wrote it.
    ///
    /// The tail is `… +N` rather than a sentence: a count needs three noun
    /// forms in Ukrainian, and this one does not need words at all.
    ///
    /// No indent — a Telegram alert is plain text with no bold header to sit
    /// under, and the marker is the bullet.
    public static func shortageModal(_ shortages: [CraftingService.Shortage],
                                     lingo: Lingo, locale: String,
                                     limit: Int = alertLimit) -> String {
        let header = lingo.localize("workshop.alert.short_header", locale: locale)
        var rows = shortages.map {
            item($0.itemId, have: $0.have, need: $0.need, lingo: lingo, locale: locale, indent: "")
        }
        var dropped = 0
        while true {
            let tail = dropped > 0 ? ["… +\(dropped)"] : []
            let text = ([header] + rows + tail).joined(separator: "\n")
            if text.utf16.count <= limit || rows.isEmpty { return text }
            rows.removeLast()
            dropped += 1
        }
    }
}
