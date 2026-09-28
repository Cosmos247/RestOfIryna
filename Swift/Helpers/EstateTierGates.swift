//
//  EstateTierGates.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 07.09.2026.
//
//  The estate tiers at which a room or a feature opens, in one place.
//  The estate screen gates its buttons on these numbers and the upgrade
//  banner reports what a tier just opened — two readers of the same fact,
//  which is exactly the shape that drifts the day one of them is edited.
//
//  Slot count and warehouse capacity are NOT here: those are content
//  (`estate_upgrades.json` → `plotSlotsByTier`, `tuning/progression.json` →
//  `warehouseCapByEstateLevel`) and are read through their own façades.
//

import Foundation

public enum EstateTierGates {
    /// Kitchen — the oven that turns raw meat into Vigor.
    public static let kitchen = 2
    /// Workshop — ingots, the weapon and bag upgrades, and salvage. Armour
    /// is not made here since 2026-09-28; the Master sells it.
    public static let workshop = 3
    /// Training Ground — a room of the house since 2026-09-27 (it was a plot
    /// type from T3); built and raised for silver, one technique per level.
    public static let trainingGround = 4
}
