//
//  BudgetTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 30.08.2026.
//
//  Phase 6. The item stat budget is the rule that makes "add items forever" a
//  safe operation: every equippable piece's stats are one budget spent at fixed
//  exchange rates, so a single number bounds it. Because the combat curves were
//  derived from that same budget, an item that respects it cannot move any
//  stat's PERCENTAGE no matter how many items follow.
//
//  Which is exactly why the rules here have to be provoked rather than assumed.
//  Power creep is invisible item by item — each new piece looks reasonable
//  beside the last — and only shows up much later as "why is everyone immune".
//

import XCTest
@testable import ROIContent

final class BudgetTests: XCTestCase {

    private func rarities() -> [RarityDTO] {
        [RarityDTO(id: "common", budgetMultiplier: 1.00, valueMultiplier: 1, glyph: "⚪"),
         RarityDTO(id: "rare", budgetMultiplier: 1.18, valueMultiplier: 4, glyph: "🔵"),
         RarityDTO(id: "legendary", budgetMultiplier: 1.45, valueMultiplier: 16, glyph: "🟠")]
    }

    private func budget(base: Double = 6.0, perItemLevel: Double = 1.5) -> BudgetTuningDTO {
        BudgetTuningDTO(
            base: base, perItemLevel: perItemLevel,
            slotWeights: [SlotWeightDTO(slot: "main_hand", weight: 3.0),
                          SlotWeightDTO(slot: "off_hand", weight: 1.2),
                          SlotWeightDTO(slot: "helmet", weight: 1.0),
                          SlotWeightDTO(slot: "chest", weight: 1.6),
                          SlotWeightDTO(slot: "legs", weight: 1.3),
                          SlotWeightDTO(slot: "boots", weight: 0.9),
                          SlotWeightDTO(slot: "accessory_1", weight: 0.5),
                          SlotWeightDTO(slot: "accessory_2", weight: 0.5)],
            statPerPoint: StatPerPointDTO(attack: 0.42, defense: 0.55, hp: 2.2,
                                          crit: 1.0, dodge: 1.0, accuracy: 0.8))
    }

    private func master(cap: Int = 5, fraction: Double = 0.04) -> MasterFileDTO {
        MasterFileDTO(armorForSale: [], repairCostFraction: 0.5, enchantCap: cap,
                      enchantBudgetFractionPerLevel: fraction,
                      enchantSteps: (1...max(1, cap)).map {
                          EnchantStepDTO(level: $0, silver: 40 * $0,
                                         materialId: "mat.hide", materialQty: 4 * $0)
                      })
    }

    /// A chest piece at item level 1 is allowed 1.6 × 7.5 = 12 points, which
    /// buys about 6 DEF.
    private func chest(defense: Int = 6, itemLevel: Int = 1, rarity: String = "common",
                       setId: String? = nil) -> ItemDTO {
        ItemDTO(id: "gear.chest", type: "gear", tier: 1, stackable: false,
                slot: "chest", gearStats: GearStatsDTO(defense: defense),
                itemLevel: itemLevel, rarity: rarity, setId: setId)
    }

    private func bundle(items: [ItemDTO] = [], rarities: [RarityDTO]? = nil,
                        budget: BudgetTuningDTO? = nil, sets: [GearSetDTO] = [],
                        ladders: [WeaponLadderDTO] = [],
                        master: MasterFileDTO? = nil) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: items, enemies: [], recipes: [],
            rarities: rarities ?? self.rarities(),
            gearSets: sets,
            budget: budget ?? self.budget(),
            starterRecipeIds: [],
            weaponLadders: ladders,
            master: master ?? self.master(),
            contentHash: "test")
    }

    private func rules(_ bundle: ContentBundle) -> [String] {
        ContentValidator.validate(bundle).errors.map(\.rule)
    }

    private func warnings(_ bundle: ContentBundle) -> [String] {
        ContentValidator.validate(bundle).warnings.map(\.rule)
    }

    // MARK: - The shipped shape is clean

    func testAnItemInsideItsBudgetIsClean() {
        let budgetRules = rules(bundle(items: [chest()])).filter {
            $0.hasPrefix("budget.") || $0.hasPrefix("rarity.") || $0.hasPrefix("set.")
        }
        XCTAssertTrue(budgetRules.isEmpty, "clean item produced: \(budgetRules)")
    }

    // MARK: - The budget itself

    func testOverspentItemIsAnError() {
        XCTAssertTrue(rules(bundle(items: [chest(defense: 40)])).contains("budget.overspent"))
    }

    /// Rounding a stat can only add half a point of it, so the allowance carries
    /// an absolute slack rather than a percentage — a percentage would be far
    /// too tight on a level-1 piece and far too loose on a level-40 one.
    func testRoundingSlackDoesNotTripTheRule() {
        // 12 points buys 6.6 DEF; 7 is the rounded-up value a generator emits.
        XCTAssertFalse(rules(bundle(items: [chest(defense: 7)])).contains("budget.overspent"))
    }

    /// Same stats, higher item level — the allowance grows, so it fits.
    func testHigherItemLevelRaisesTheAllowance() {
        XCTAssertTrue(rules(bundle(items: [chest(defense: 40)])).contains("budget.overspent"))
        XCTAssertFalse(rules(bundle(items: [chest(defense: 40, itemLevel: 40)])).contains("budget.overspent"))
    }

    func testUnknownRarityIsAnError() {
        XCTAssertTrue(rules(bundle(items: [chest(rarity: "mythic")])).contains("rarity.unknown"))
    }

    func testMissingSlotWeightIsAnError() {
        let stripped = BudgetTuningDTO(
            base: 6.0, perItemLevel: 1.5,
            slotWeights: [SlotWeightDTO(slot: "chest", weight: 1.6)],
            statPerPoint: budget().statPerPoint)
        XCTAssertTrue(rules(bundle(budget: stripped)).contains("budget.slot_missing"))
    }

    func testFlatBudgetCurveIsAnError() {
        XCTAssertTrue(rules(bundle(budget: budget(perItemLevel: 0))).contains("budget.flat_curve"))
    }

    // MARK: - The rarity ladder

    /// The lowest rarity is what every other multiplies against, so it has to be
    /// the identity or the whole ladder is offset.
    func testBaselineRarityMustBeOne() {
        var ladder = rarities()
        ladder[0] = RarityDTO(id: "common", budgetMultiplier: 1.2, valueMultiplier: 1, glyph: "⚪")
        XCTAssertTrue(rules(bundle(rarities: ladder)).contains("rarity.baseline_not_one"))
    }

    func testRarityBudgetMustAscend() {
        var ladder = rarities()
        ladder[2] = RarityDTO(id: "legendary", budgetMultiplier: 1.0, valueMultiplier: 16, glyph: "🟠")
        XCTAssertTrue(rules(bundle(rarities: ladder)).contains("rarity.budget_not_ascending"))
    }

    /// The exact value the design draft proposed and then rejected: at ×2.45 a
    /// legendary plus a full enchant reaches 2.94× a common of the same level,
    /// a second progression axis outweighing all forty levels of the first.
    func testTheDraftedLegendaryMultiplierExceedsTheCeiling() {
        var ladder = rarities()
        ladder[2] = RarityDTO(id: "legendary", budgetMultiplier: 2.45, valueMultiplier: 16, glyph: "🟠")
        XCTAssertTrue(rules(bundle(rarities: ladder)).contains("rarity.ceiling_exceeded"))
    }

    func testShippedCeilingHolds() {
        XCTAssertFalse(rules(bundle()).contains("rarity.ceiling_exceeded"))
    }

    // MARK: - Sets

    private func forester(_ bonuses: [SetBonusDTO]) -> GearSetDTO {
        GearSetDTO(id: "set.forester", bonuses: bonuses)
    }

    private func fourPieces() -> [ItemDTO] {
        ["helmet", "chest", "legs", "boots"].map {
            ItemDTO(id: "gear.\($0)", type: "gear", tier: 1, stackable: false, slot: $0,
                    gearStats: GearStatsDTO(defense: 3), itemLevel: 1,
                    rarity: "common", setId: "set.forester")
        }
    }

    func testUnknownSetOnAnItemIsAnError() {
        XCTAssertTrue(rules(bundle(items: [chest(setId: "set.ghost")])).contains("set.unknown"))
    }

    /// A "set bonus" at one piece is just the piece.
    func testThresholdBelowTwoIsAnError() {
        let set = forester([SetBonusDTO(pieces: 1, effect: .flatStats(GearStatsDTO(dodge: 1)))])
        XCTAssertTrue(rules(bundle(items: fourPieces(), sets: [set])).contains("set.threshold_below_two"))
    }

    func testThresholdBeyondTheMemberCountIsAnError() {
        let set = forester([SetBonusDTO(pieces: 6, effect: .flatStats(GearStatsDTO(dodge: 1)))])
        XCTAssertTrue(rules(bundle(items: fourPieces(), sets: [set])).contains("set.threshold_unreachable"))
    }

    /// A set bonus is extra budget bought with slot freedom — a third power
    /// axis. Unbounded, "wear the whole set" becomes the only correct answer to
    /// every slot decision in the game.
    func testSetBonusOverBudgetIsAnError() {
        let set = forester([SetBonusDTO(pieces: 4, effect: .flatStats(GearStatsDTO(defense: 60)))])
        XCTAssertTrue(rules(bundle(items: fourPieces(), sets: [set])).contains("set.bonus_over_budget"))
    }

    func testModestSetBonusIsClean() {
        let set = forester([SetBonusDTO(pieces: 2, effect: .flatStats(GearStatsDTO(dodge: 2))),
                            SetBonusDTO(pieces: 4, effect: .flatStats(GearStatsDTO(defense: 2, hp: 6)))])
        XCTAssertFalse(rules(bundle(items: fourPieces(), sets: [set])).contains("set.bonus_over_budget"))
    }

    func testGearMultiplierOfZeroIsAnError() {
        let set = forester([SetBonusDTO(pieces: 2, effect: .gearMultiplier(0))])
        XCTAssertTrue(rules(bundle(items: fourPieces(), sets: [set])).contains("set.multiplier_non_positive"))
    }

    /// The union must survive JSON, or a case added later silently loses its
    /// payload the way the technique effects did in Phase 5.
    func testSetEffectsRoundTrip() throws {
        for effect in [SetBonusEffectDTO.flatStats(GearStatsDTO(defense: 2, hp: 6)),
                       .gearMultiplier(1.1)] {
            let data = try ContentLoader.makeEncoder().encode(effect)
            XCTAssertEqual(try JSONDecoder().decode(SetBonusEffectDTO.self, from: data), effect)
        }
    }

    // MARK: - Weapon ladders

    private func ladder(levels: [Int]) -> WeaponLadderDTO {
        WeaponLadderDTO(itemId: "gear.chest", tiers: levels.enumerated().map { index, level in
            WeaponUpgradeStepDTO(tier: index + 1, itemLevel: level,
                                 stats: GearStatsDTO(defense: 3))
        })
    }

    /// Item level has to climb with the tier, or a later rung is a downgrade
    /// wearing a bigger number.
    func testLadderItemLevelMustAscend() {
        XCTAssertTrue(rules(bundle(items: [chest()], ladders: [ladder(levels: [1, 20, 5])]))
            .contains("budget.ladder_level_not_ascending"))
    }

    func testAscendingLadderIsClean() {
        XCTAssertFalse(rules(bundle(items: [chest()], ladders: [ladder(levels: [1, 10, 20])]))
            .contains("budget.ladder_level_not_ascending"))
    }
}
