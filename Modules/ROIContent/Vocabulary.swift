//
//  Vocabulary.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Content vocabulary shared by the game, the validator and the simulator.
//
//  `EquipmentSlot` moved here from `Swift/Models/Item.swift` in Phase 8. It was
//  transcribed three times before that — once as the domain enum, twice as a
//  string-literal list inside `ContentValidator` (`equipmentSlots` and
//  `knownSlots`) — and the simulator needed a fourth, because `BudgetMath` has
//  to know which slots a reference kit fills. A slot id appears in `items.json`
//  AND in `tuning/budget.json`, so it is content vocabulary rather than domain
//  behaviour; one definition is what keeps the budget the validator enforces
//  and the budget the simulator spends the same budget.
//
//  `ItemType` and `RecipeCategory` stay in `Swift/Models/` for now: nothing
//  outside the game reads them, so moving them would be churn without a reader.
//
//  ⚠️ Raw values are a DATABASE CONTRACT — `InventoryEntry.equippedSlot` stores
//  them verbatim. Renaming a case is a migration, not a content edit.
//

import Foundation

public enum EquipmentSlot: String, Codable, CaseIterable, Sendable {
    case helmet
    case chest
    case legs
    case boots
    case mainHand   = "main_hand"
    case offHand    = "off_hand"
    case accessory1 = "accessory_1"
    case accessory2 = "accessory_2"
}
