//
//  PlotOrdinal.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 04.11.2026.
//
//  The number a plot's button carries (2026-11-04, the owner). The plot list's
//  buttons read the plot's own icon and name — «🌳 Ліщина», «🪚 Лісопилка» —
//  instead of «🚜 Ділянка 2», and a type that stands on the estate more than
//  once is told apart by its ordinal WITHIN the type, in place order: the first
//  farm «🌾 Ферма (1)», the next «🌾 Ферма (2)» (the owner: «порядковий саме для
//  цього типу ділянки»). A type with one plot carries no number at all.
//

import Foundation

public enum PlotOrdinal {

    /// One entry per place, in place order: the plot type standing there, or
    /// nil for an empty place. Answers, per place, the ordinal its button shows
    /// — nil for an empty place and for a type that stands only once.
    public static func of<Kind: Hashable>(_ places: [Kind?]) -> [Int?] {
        var totals: [Kind: Int] = [:]
        for case let kind? in places { totals[kind, default: 0] += 1 }
        var seen: [Kind: Int] = [:]
        return places.map { place in
            guard let kind = place, (totals[kind] ?? 0) > 1 else { return nil }
            seen[kind, default: 0] += 1
            return seen[kind]
        }
    }
}
