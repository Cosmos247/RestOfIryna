//
//  EnchantLadderTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 06.10.2026.
//
//  The Master's enchant as the armour's ladder (`spec-items.md` §11).
//
//  Until 2026-10-06 a level added 4% of the piece's own stats, and the only
//  rule guarding it asked whether the percentage was above zero. It was — and
//  thirteen of the twenty purchases on the shipped set changed no number. So
//  the tests here pin three things a percentage could never be asked: what a
//  level lifts a piece to, what it costs — the price is its only gate — and
//  that every level the Master sells changes something on every piece he can
//  be handed.
//

import XCTest
@testable import ROIContent

final class EnchantLadderTests: XCTestCase {

    private static let contentRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("content/data")

    private func shipped() throws -> ContentBundle {
        try ContentLoader.load(from: Self.contentRoot)
    }

    /// The shipped bundle with the Master — and, when asked, the items —
    /// swapped, so the curve, the level cap and the real armour are all there
    /// for the rules that read them.
    private func shipped(master: MasterFileDTO, extraItems: [ItemDTO] = []) throws -> ContentBundle {
        let s = try shipped()
        return ContentBundle(
            manifest: s.manifest, items: s.items + extraItems, enemies: s.enemies, recipes: s.recipes,
            rarities: s.rarities, gearSets: s.gearSets, budget: s.budget,
            starterRecipeIds: s.starterRecipeIds, weaponLadders: s.weaponLadders,
            weaponDurabilityByTier: s.weaponDurabilityByTier,
            bags: s.bags, estateUpgrades: s.estateUpgrades, master: master, plots: s.plots,
            tuning: s.tuning, contentHash: "test")
    }

    private func masterRules(_ bundle: ContentBundle) -> [String] {
        ContentValidator.validate(bundle).issues.map(\.rule).filter { $0.hasPrefix("master.") }
    }

    /// The shipped curve's two numbers; the slot weights and exchange rates
    /// cancel out of a ladder's lift and are not read by it.
    private let curve = BudgetTuningDTO(
        base: 6.0, perItemLevel: 1.5, slotWeights: [],
        statPerPoint: StatPerPointDTO(attack: 0.42, defense: 0.55, hp: 2.2,
                                      crit: 1.0, dodge: 1.0, accuracy: 0.8))

    private func lift(from: Int = 1, to: Int, share: Double = 0.75) -> LadderScale {
        EnchantLadderRules.scale(fromItemLevel: from, toItemLevel: to, growthShare: share, curve: curve)
    }

    // MARK: - The lift

    /// A level-1 piece budgeted at item level L with 75% of the growth — the
    /// weapon ladder's rule — is ×(1 + 0.15 · (L − 1)) its own stats.
    func testTheLiftIsTheWeaponLaddersLaw() {
        for (itemLevel, factor) in [(5, 1.6), (10, 2.35), (15, 3.1), (20, 3.85), (25, 4.6)] {
            XCTAssertEqual(lift(to: itemLevel).factor, factor, accuracy: 1e-12, "item level \(itemLevel)")
        }
    }

    /// 5 × 3.1 is 15.5, and it has to round as 15.5. Multiplying by the
    /// quotient 23.25 ÷ 7.5 can land a hair under and hand back 15 — which is
    /// why the scale keeps its two numbers and divides last.
    func testAHalfLandsOnTheHalf() {
        let scale = lift(to: 15)
        XCTAssertEqual(scale.numerator, 23.25)
        XCTAssertEqual(scale.denominator, 7.5)
        XCTAssertEqual(scale.apply(5), 16)
        XCTAssertEqual(scale.apply(10), 31)
    }

    /// The ladder never lowers a stat: a level at or below the piece's own item
    /// level lifts nothing.
    func testALevelAtOrBelowThePieceLiftsNothing() {
        XCTAssertEqual(lift(from: 20, to: 5), .identity)
        XCTAssertEqual(lift(from: 20, to: 20), .identity)
        XCTAssertEqual(lift(from: 20, to: 5).apply(17), 17)
        XCTAssertGreaterThan(lift(from: 20, to: 25).factor, 1)
    }

    func testNoShareNoLift() {
        XCTAssertEqual(lift(to: 25, share: 0), .identity)
    }

    /// With the whole growth a laddered piece IS the on-curve item of its
    /// level: (6 + 1.5 · 25) ÷ (6 + 1.5 · 1).
    func testFullShareIsTheOnCurveItem() {
        XCTAssertEqual(lift(to: 25, share: 1.0).factor, 43.5 / 7.5, accuracy: 1e-12)
        XCTAssertLessThan(lift(to: 25).factor, lift(to: 25, share: 1.0).factor)
    }

    func testEveryStatIsRoundedOnItsOwn() {
        let jerkin = GearStatsDTO(defense: 4, hp: 6, crit: 1, dodge: 1)
        XCTAssertEqual(jerkin.scaled(by: lift(to: 5)), GearStatsDTO(defense: 6, hp: 10, crit: 2, dodge: 2))
        XCTAssertEqual(jerkin.scaled(by: .identity), jerkin)
    }

    // MARK: - The shipped ladder

    private func lifted(_ itemId: String, to level: Int, in bundle: ContentBundle) throws -> GearStatsDTO {
        let item = try XCTUnwrap(bundle.items.first { $0.id == itemId })
        let stats = try XCTUnwrap(item.gearStats)
        guard level > 0 else { return stats }
        let master = try XCTUnwrap(bundle.master)
        let step = try XCTUnwrap(master.enchantSteps.first { $0.level == level })
        return stats.scaled(by: EnchantLadderRules.scale(
            fromItemLevel: item.itemLevel ?? 1, toItemLevel: step.itemLevel,
            growthShare: master.enchantGrowthShare, curve: try XCTUnwrap(bundle.budget)))
    }

    /// The table the owner approved on 2026-10-06, level by level: the whole
    /// Forester set, then the jerkin the mockup showed. A retune of the share,
    /// the curve or a piece's stats moves it and has to be decided, not found.
    func testTheShippedLadderIsTheOneThatWasApproved() throws {
        let bundle = try shipped()
        let pieces = ["gear.forester_hood", "gear.forester_jerkin", "gear.forester_breeches", "gear.forester_boots"]
        let approvedSet: [(defense: Int, hp: Int, crit: Int, dodge: Int)] = [
            (12, 18, 4, 3), (19, 29, 8, 6), (28, 42, 8, 6), (36, 56, 12, 9), (47, 69, 16, 12), (55, 83, 20, 15)
        ]
        for (level, approved) in approvedSet.enumerated() {
            var total = GearStatsDTO()
            for id in pieces {
                let s = try lifted(id, to: level, in: bundle)
                total = GearStatsDTO(defense: total.defense + s.defense, hp: total.hp + s.hp,
                                     crit: total.crit + s.crit, dodge: total.dodge + s.dodge)
            }
            XCTAssertEqual(total, GearStatsDTO(defense: approved.defense, hp: approved.hp,
                                               crit: approved.crit, dodge: approved.dodge), "set at +\(level)")
        }
        let approvedJerkin = [(4, 6, 1, 1), (6, 10, 2, 2), (9, 14, 2, 2), (12, 19, 3, 3), (15, 23, 4, 4), (18, 28, 5, 5)]
        for (level, row) in approvedJerkin.enumerated() {
            XCTAssertEqual(try lifted("gear.forester_jerkin", to: level, in: bundle),
                           GearStatsDTO(defense: row.0, hp: row.1, crit: row.2, dodge: row.3), "jerkin at +\(level)")
        }
    }

    /// An enchant level budgets the piece where the weapon rung of the same
    /// height sits (t2…t6: item levels 5…25) — and, unlike that rung, carries
    /// no player-level gate at all.
    func testShippedLevelsSitOnTheWeaponsRungs() throws {
        let bundle = try shipped()
        let master = try XCTUnwrap(bundle.master)
        let steps = master.enchantSteps.sorted { $0.level < $1.level }
        XCTAssertEqual(steps.count, master.enchantCap)
        XCTAssertEqual(master.enchantGrowthShare, 0.75)
        let sword = try XCTUnwrap(bundle.weaponLadders.first { $0.itemId == "gear.rusty_sword" })
        for step in steps {
            let rung = try XCTUnwrap(sword.tiers.first { $0.tier == step.level + 1 })
            XCTAssertEqual(step.itemLevel, rung.itemLevel, "enchant +\(step.level)")
        }
    }

    /// The prices the owner picked on 2026-10-06 — 50 × level², with the hides
    /// the bench always asked for. They are the ladder's ONLY gate, so a change
    /// to them is a balance decision and has to be made, not found.
    func testTheShippedPricesAreTheOnesThatWereApproved() throws {
        let master = try XCTUnwrap(try shipped().master)
        let steps = master.enchantSteps.sorted { $0.level < $1.level }
        XCTAssertEqual(steps.map(\.silver), [50, 200, 450, 800, 1250])
        XCTAssertEqual(steps.map(\.silver), steps.map { 50 * $0.level * $0.level })
        XCTAssertEqual(steps.map(\.materialQty), [4, 8, 15, 26, 42])
        XCTAssertTrue(steps.allSatisfy { $0.materialId == "mat.hide" })
        XCTAssertEqual(4 * steps.reduce(0) { $0 + $1.silver }, 11_000, "a whole set to +5")
    }

    func testTheShippedLadderPassesItsOwnRules() throws {
        XCTAssertEqual(masterRules(try shipped()), [])
    }

    // MARK: - The checker can fail

    private func step(_ level: Int, itemLevel: Int? = nil) -> EnchantStepDTO {
        EnchantStepDTO(level: level, silver: 40 * level, materialId: "mat.hide", materialQty: 4 * level,
                       itemLevel: itemLevel ?? 5 * level)
    }

    private func master(share: Double = 0.75, steps: [EnchantStepDTO]? = nil) throws -> MasterFileDTO {
        let shippedMaster = try XCTUnwrap(try shipped().master)
        let rows = steps ?? (1...5).map { step($0) }
        return MasterFileDTO(armorForSale: shippedMaster.armorForSale,
                             repairCostFraction: shippedMaster.repairCostFraction,
                             enchantCap: rows.count, enchantGrowthShare: share,
                             enchantSteps: rows, weaponLessonSilver: shippedMaster.weaponLessonSilver)
    }

    /// The mechanic this replaced, written in the ladder's own terms: a lift
    /// too small to move a level-1 piece. It has to be refused, and by name.
    func testALevelThatChangesNothingIsAnError() throws {
        let weak = try shipped(master: try master(share: 0.02))
        let issues = ContentValidator.validate(weak).issues.filter { $0.rule == "master.enchant_level_changes_nothing" }
        XCTAssertFalse(issues.isEmpty)
        XCTAssertTrue(issues.contains { $0.id == "gear.forester_boots" })
        XCTAssertFalse(masterRules(try shipped(master: try master()))
            .contains("master.enchant_level_changes_nothing"))
    }

    /// Armour authored at or above a level's item level gains nothing from it.
    /// The day such a piece is written, the ladder has to be decided for it.
    func testArmourAuthoredAboveALevelIsCaught() throws {
        let plate = ItemDTO(id: "gear.test_plate", type: "gear", tier: 1, stackable: false,
                            slot: "chest", gearStats: GearStatsDTO(defense: 20, hp: 22),
                            itemLevel: 20, maxDurability: 50)
        let bundle = try shipped(master: try master(), extraItems: [plate])
        let hits = ContentValidator.validate(bundle).issues.filter {
            $0.rule == "master.enchant_level_changes_nothing" && $0.id == "gear.test_plate"
        }
        XCTAssertEqual(hits.count, 4, "levels +1…+4 budget at 5…20, none above the piece's own 20")
    }

    /// A v18 step — silver and hides, no item level — must not decode:
    /// defaulting it would budget the piece nowhere and lift nothing.
    func testAStepWithoutItsItemLevelDoesNotDecode() {
        let v18 = #"{"level":1,"materialId":"mat.hide","materialQty":4,"silver":40}"#
        XCTAssertThrowsError(try JSONDecoder().decode(EnchantStepDTO.self, from: Data(v18.utf8)))
        let v19 = #"{"itemLevel":5,"level":1,"materialId":"mat.hide","materialQty":4,"silver":40}"#
        XCTAssertEqual(try JSONDecoder().decode(EnchantStepDTO.self, from: Data(v19.utf8)), step(1))
    }
}
