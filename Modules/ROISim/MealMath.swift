//
//  MealMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 01.11.2026.
//
//  How many portions the bag's one many-portion button eats (2026-11-01, the
//  owner's pick of three).
//
//  A dish's card carries «🍴 Зʼїсти» and, beside it, ONE button whose label
//  says what the tap will do: «До повної снаги (N)» when the bag holds enough
//  to fill the pool, «Зʼїсти всі (N)» when even all of it will not. Two
//  buttons were the alternative and were turned down: for every food without
//  ❤️ they would always do the same thing, because a portion that restores
//  nothing is never eaten.
//
//  The count rounds UP: the last portion may top the pool out and lose its
//  remainder, exactly as one tap at the top always has. A button that stops
//  short of full would not be «до повної снаги». Nothing is offered when one
//  portion is enough — that is the plain «Зʼїсти» — nor when the pool is full,
//  nor for a lone unit.
//
//  The bot asks this twice: to draw the label, and again on the tap, where a
//  count that no longer matches the button redraws the card instead of eating.
//

import Foundation

public enum MealMath {

    /// The many-portion button, and how many portions it eats.
    public enum Bulk: Equatable, Sendable {
        /// «🍴 До повної снаги (N)» — N portions fill the pool.
        case toFull(Int)
        /// «🍴 Зʼїсти всі (N)» — the whole stack, and the pool still not full.
        case all(Int)

        public var count: Int {
            switch self {
            case .toFull(let count), .all(let count): return count
            }
        }
    }

    /// The button a dish's card offers, or nil when it offers none.
    /// `vigorPerPortion` is what one portion restores before the pool's clamp.
    public static func bulk(vigor: Int, maxVigor: Int, vigorPerPortion: Int, held: Int) -> Bulk? {
        let missing = maxVigor - vigor
        guard vigorPerPortion > 0, missing > 0, held >= 2 else { return nil }
        let needed = (missing + vigorPerPortion - 1) / vigorPerPortion
        if held >= needed {
            return needed >= 2 ? .toFull(needed) : nil
        }
        return .all(held)
    }
}
