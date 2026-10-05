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

    /// The four armour slots. Armour worn to 0 is broken — it grants nothing —
    /// and every repair shaves its maximum.
    public var isArmor: Bool {
        switch self {
        case .helmet, .chest, .legs, .boots: return true
        case .mainHand, .offHand, .accessory1, .accessory2: return false
        }
    }

    /// What a fight wears: the armour and the main-hand weapon. The off-hand
    /// and both accessories never drain, so a piece there has no durability.
    ///
    /// Here rather than in `GearConditionService` since 2026-10-05, when
    /// durability moved onto each item: the validator has to know which pieces
    /// need a `maxDurability`, and a second list in it would be the transcription
    /// this file was created to end.
    public var isDurable: Bool { isArmor || self == .mainHand }
}


/// Which of Ukrainian's three noun forms a count takes.
///
/// Lives here rather than beside the `Lingo` extension that calls it for one
/// reason: `Tests/ROIContentTests` can reach this module and cannot reach the
/// game target, and an untested plural rule is exactly the kind of thing that
/// looks right for a year. The forms themselves are content; the arithmetic
/// that picks between them is code, and it has an off-by-one that bites
/// exactly once — at 11.
public enum UkrainianPlural {
    public enum Form: String, Sendable { case one, few, many }

    public static func form(for count: Int) -> Form {
        let n = abs(count)
        // 11–14 are the exception, and they are checked FIRST: 11 ends in 1 and
        // 12 ends in 2, so a units-only rule calls them `one` and `few` when
        // both are `many` — «11 срібників», not «11 срібник».
        if (11...14).contains(n % 100) { return .many }
        switch n % 10 {
        case 1:      return .one
        case 2...4:  return .few
        default:     return .many
        }
    }
}
