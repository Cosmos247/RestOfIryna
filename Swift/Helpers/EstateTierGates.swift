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
    /// Workshop — crafting, and the first armour a player can own.
    public static let workshop = 3
    /// Training Ground — the plot type that teaches techniques.
    public static let trainingGround = 3
    /// Tannery recipes inside the workshop.
    public static let tannery = 4
}
