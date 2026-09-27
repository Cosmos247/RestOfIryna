//
//  SalvageMath.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  What taking a crafted piece apart at the workshop gives back.
//
//  A piece returns a share of the recipe that made it, and the share shrinks
//  with the piece's MAX durability — the part of its life that repairs can no
//  longer restore. A fresh piece returns `fraction` of its recipe, a piece at
//  half its max returns half of that, and a piece worn to 1/1 returns nothing.
//  It leaves the bag either way, which makes this the one way to be rid of a
//  dead piece as well as a way to recover a spare one.
//
//  Rounded DOWN, per ingredient. Rounding up would hand back a hide for a hood
//  worn to 2/2, and rounding to nearest would make half the cases hang on a .5
//  that floating point may or may not land on. The epsilon keeps an exact
//  product (5 × 0.5 × 24/30 = 2) from flooring to 1 on a representation error.
//

import Foundation

public enum SalvageMath {

    /// One ingredient line: an item and how many of it.
    public struct Line: Sendable, Equatable {
        public let itemId: String
        public let quantity: Int

        public init(itemId: String, quantity: Int) {
            self.itemId = itemId
            self.quantity = quantity
        }
    }

    /// The lines one piece returns. `recipeInputs` pay for
    /// `recipeOutputQuantity` pieces (1 for every gear recipe today), so a
    /// recipe that ever makes two at once is split per piece instead of paid
    /// out twice. A max above `maxDurabilityStart` counts as fresh. Lines that
    /// round to zero are dropped, so an empty result means the piece yields
    /// nothing at all.
    public static func yield(recipeInputs: [Line], recipeOutputQuantity: Int, fraction: Double,
                             maxDurability: Int, maxDurabilityStart: Int) -> [Line] {
        guard maxDurabilityStart > 0, recipeOutputQuantity > 0, fraction > 0 else { return [] }
        let condition = Double(min(max(maxDurability, 0), maxDurabilityStart)) / Double(maxDurabilityStart)
        let share = fraction * condition / Double(recipeOutputQuantity)
        return recipeInputs.compactMap { input in
            let quantity = Int((Double(input.quantity) * share + 1e-9).rounded(.down))
            return quantity > 0 ? Line(itemId: input.itemId, quantity: quantity) : nil
        }
    }
}
