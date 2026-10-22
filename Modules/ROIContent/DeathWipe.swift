//
//  DeathWipe.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 22.10.2026.
//
//  What a death in the forest takes from the bag, and what the forest edge
//  puts on before it can (2026-10-22).
//
//  A death — the player's on the walk, or the governor's on a passive run —
//  empties the bag of everything but what is WORN and the bound class weapon
//  (`InventoryEntry.wipeOnDeath`). New players kept losing armour that sat in
//  the bag (the owner's report): the Master puts what he sells in the bag, his
//  banner says only «куплено», and the first screen to name the rule was the
//  death screen listing what it had taken. So the forest edge now names the
//  armour a death would take, with «🛡 Одягнути» above the two ways out (the
//  owner's pick of four forms).
//
//  Both answers live here, once, in pure Foundation: the wipe and the warning
//  ask `takes`, so the edge can neither warn about a piece the wipe would spare
//  nor miss one it would take; the edge's button asks `wearPlan`; and the
//  tests reach both.
//

import Foundation

public enum DeathWipe {

    /// Whether a death takes a bag row: everything not worn, except the bound
    /// class weapon — granted once at registration, sold by no one, so a death
    /// that took it would disarm the character for good.
    public static func takes(isWorn: Bool, isBoundWeapon: Bool) -> Bool {
        !isWorn && !isBoundWeapon
    }

    /// An unworn armour row, as «🛡 Одягнути» weighs it. `id` names the row.
    public struct Piece: Sendable, Equatable {
        public let id: String
        public let slot: EquipmentSlot
        public let isBroken: Bool
        public let enchantLevel: Int
        public let durability: Int
        public let maxDurability: Int

        public init(id: String, slot: EquipmentSlot, isBroken: Bool,
                    enchantLevel: Int, durability: Int, maxDurability: Int) {
            self.id = id
            self.slot = slot
            self.isBroken = isBroken
            self.enchantLevel = enchantLevel
            self.durability = durability
            self.maxDurability = maxDurability
        }
    }

    /// What «🛡 Одягнути» puts on: for every slot nothing is worn in, the piece
    /// that grants the most right now.
    ///
    /// A slot already worn is left alone, whatever lies in the bag for it. A
    /// swap would only move the other piece into the bag, where the same death
    /// takes it — so a spare is named on the edge and nothing more (the owner's
    /// pick, 2026-10-22). Of two copies for one empty slot the other stays
    /// listed.
    public static func wearPlan(_ pieces: [Piece], wornSlots: Set<EquipmentSlot>) -> [Piece] {
        var best: [EquipmentSlot: Piece] = [:]
        for piece in pieces where !wornSlots.contains(piece.slot) {
            if let current = best[piece.slot], !outranks(piece, current) { continue }
            best[piece.slot] = piece
        }
        return ranked(Array(best.values))
    }

    /// The edge's listing order: head to toe, and the copy `wearPlan` would
    /// pick first within a slot.
    public static func ranked(_ pieces: [Piece]) -> [Piece] {
        pieces.sorted { lhs, rhs in
            if lhs.slot != rhs.slot { return slotIndex(lhs.slot) < slotIndex(rhs.slot) }
            return outranks(lhs, rhs)
        }
    }

    /// Which of two pieces for one slot grants more right now: a whole piece
    /// before a broken one (armour at 0 grants nothing), then the higher
    /// enchant (each level is more of every stat), then the one with more wear
    /// left. The row id keeps the answer the same tap after tap.
    static func outranks(_ lhs: Piece, _ rhs: Piece) -> Bool {
        if lhs.isBroken != rhs.isBroken { return !lhs.isBroken }
        if lhs.enchantLevel != rhs.enchantLevel { return lhs.enchantLevel > rhs.enchantLevel }
        if lhs.durability != rhs.durability { return lhs.durability > rhs.durability }
        if lhs.maxDurability != rhs.maxDurability { return lhs.maxDurability > rhs.maxDurability }
        return lhs.id < rhs.id
    }

    private static func slotIndex(_ slot: EquipmentSlot) -> Int {
        EquipmentSlot.allCases.firstIndex(of: slot) ?? EquipmentSlot.allCases.count
    }
}
