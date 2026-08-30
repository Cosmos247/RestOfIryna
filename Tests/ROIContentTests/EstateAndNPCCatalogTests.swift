//
//  EstateAndNPCCatalogTests.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Locks the Phase 3C contract: Master, plots, fortune deck, quest pools.
//
//  Three properties in this batch cannot be seen by a round-trip and are the
//  reason most of these tests exist:
//
//  * a plot's ABSENT tuning is a value, not a gap — it is how the estate
//    controller knows to open a training fight instead of a harvest;
//  * a fortune multiplier's no-op is 1.0, not 0, so "skip the default" cannot
//    be one condition across the effect struct;
//  * a quest objective is a tagged union whose unknown `kind` must FAIL rather
//    than decode into something completable.
//

import XCTest
@testable import ROIContent

final class EstateAndNPCCatalogTests: XCTestCase {

    // MARK: - Plot tuning: absence is a value

    func testPlotRowWithoutTuningDecodesAsNilRatherThanEmpty() throws {
        let json = Data(#"{"type":"training_ground","icon":"🥋"}"#.utf8)
        let row = try JSONDecoder().decode(PlotTypeDTO.self, from: json)
        XCTAssertNil(row.tuning, "a nil tuning is how a non-producing plot is recognised")
    }

    func testPlotTuningNilSurvivesTheRoundTrip() throws {
        let original = PlotFileDTO(types: [
            PlotTypeDTO(type: "farm", icon: "🌾",
                        tuning: PlotTuningDTO(producedItemId: "food.potato", ratePerInterval: 4, capacity: 20)),
            PlotTypeDTO(type: "training_ground", icon: "🥋")
        ])
        let encoder = ContentLoader.makeEncoder()
        let first = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(PlotFileDTO.self, from: first)
        XCTAssertNil(decoded.types[1].tuning)
        XCTAssertEqual(try encoder.encode(decoded), first)
    }

    // MARK: - Fortune effect: per-field no-ops

    /// The trap this guards: treating 0 as "unset" for a multiplier would write
    /// nothing for a 1.0 and then decode a card that zeroes the stat it scales.
    func testFortuneMultipliersDefaultToOneNotZero() throws {
        let effect = try JSONDecoder().decode(FortuneEffectDTO.self, from: Data("{}".utf8))
        XCTAssertEqual(effect.xpMultiplier, 1.0)
        XCTAssertEqual(effect.lootChanceMultiplier, 1.0)
        XCTAssertEqual(effect.vigorDrainMultiplier, 1.0)
        XCTAssertEqual(effect.attackBonus, 0)
        XCTAssertFalse(effect.oneShotHpRestore)
    }

    func testFortuneEncoderOmitsNoOpsButKeepsRealValues() throws {
        let encoded = try ContentLoader.makeEncoder()
            .encode(FortuneEffectDTO(defenseBonus: -5, lootChanceMultiplier: 1.2))
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertTrue(text.contains("defenseBonus"))
        XCTAssertTrue(text.contains("lootChanceMultiplier"))
        XCTAssertFalse(text.contains("xpMultiplier"), "a 1.0 multiplier is a no-op and must not be written")
        XCTAssertFalse(text.contains("attackBonus"))
        XCTAssertFalse(text.contains("oneShotHpRestore"))
    }

    /// A negative bonus is meaningful data (half the deck is debuffs), so it
    /// must never be mistaken for an unset field.
    func testNegativeBonusesSurviveEncoding() throws {
        let original = FortuneEffectDTO(attackBonus: -10, defenseBonus: -10)
        let encoder = ContentLoader.makeEncoder()
        let decoded = try JSONDecoder().decode(FortuneEffectDTO.self, from: try encoder.encode(original))
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Quest objective: tagged union

    func testDeliverObjectiveRoundTrips() throws {
        let json = Data(#"{"kind":"deliver","itemIds":["mat.hide"],"target":10}"#.utf8)
        let objective = try JSONDecoder().decode(QuestObjectiveDTO.self, from: json)
        XCTAssertEqual(objective.kind, .deliver)
        XCTAssertEqual(objective.itemIds, ["mat.hide"])
        XCTAssertEqual(objective.target, 10)
    }

    /// An unknown kind has to fail the load. Defaulting it would turn the job
    /// into one no hook site can ever tick.
    func testUnknownObjectiveKindFailsDecoding() {
        let json = Data(#"{"kind":"escort","target":1}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(QuestObjectiveDTO.self, from: json))
    }

    /// Each kind writes only its own half, so a deliver row carries no null
    /// `counter` and a counter row carries no empty `itemIds`.
    func testObjectiveEncodesOnlyItsOwnHalf() throws {
        let encoder = ContentLoader.makeEncoder()
        let deliver = String(decoding: try encoder.encode(
            QuestObjectiveDTO(kind: .deliver, itemIds: ["mat.hide"], target: 10)), as: UTF8.self)
        XCTAssertTrue(deliver.contains("itemIds"))
        XCTAssertFalse(deliver.contains("counter"))

        let counter = String(decoding: try encoder.encode(
            QuestObjectiveDTO(kind: .counter, counter: "beastKill", target: 5)), as: UTF8.self)
        XCTAssertTrue(counter.contains("beastKill"))
        XCTAssertFalse(counter.contains("itemIds"))
    }

    // MARK: - Fixtures

    private func bundle(master: MasterFileDTO? = nil, plots: PlotFileDTO? = nil,
                        fortune: FortuneFileDTO? = nil, quests: QuestFileDTO? = nil) -> ContentBundle {
        ContentBundle(
            manifest: ManifestDTO(schemaVersion: ContentSchema.current),
            items: [
                ItemDTO(id: "mat.hide", type: "material", tier: 1, stackable: true),
                ItemDTO(id: "food.potato", type: "food", tier: 1, stackable: true),
                ItemDTO(id: "gear.forester_hood", type: "gear", tier: 1, stackable: false, slot: "helmet")
            ],
            enemies: [], recipes: [], starterRecipeIds: [],
            master: master, plots: plots, fortune: fortune, quests: quests,
            contentHash: "test"
        )
    }

    private func validMaster(cap: Int = 3, fraction: Double = 0.04,
                             steps: [EnchantStepDTO]? = nil) -> MasterFileDTO {
        MasterFileDTO(
            armorForSale: [MasterArmorListingDTO(itemId: "gear.forester_hood", priceSilver: 60)],
            repairCostFraction: 0.5,
            enchantCap: cap,
            enchantBudgetFractionPerLevel: fraction,
            enchantSteps: steps ?? (1...max(1, cap)).map {
                EnchantStepDTO(level: $0, silver: 40 * $0, materialId: "mat.hide", materialQty: 4 * $0)
            }
        )
    }

    private func allPlots() -> PlotFileDTO {
        PlotFileDTO(types: [
            PlotTypeDTO(type: "farm", icon: "🌾",
                        tuning: PlotTuningDTO(producedItemId: "food.potato", ratePerInterval: 4, capacity: 20)),
            PlotTypeDTO(type: "forest", icon: "🪚",
                        tuning: PlotTuningDTO(producedItemId: "mat.hide", ratePerInterval: 6, capacity: 30)),
            PlotTypeDTO(type: "mine", icon: "⛏",
                        tuning: PlotTuningDTO(producedItemId: "mat.hide", ratePerInterval: 8, capacity: 40)),
            PlotTypeDTO(type: "coop", icon: "🐔",
                        tuning: PlotTuningDTO(producedItemId: "food.potato", ratePerInterval: 2, capacity: 12)),
            PlotTypeDTO(type: "training_ground", icon: "🥋")
        ])
    }

    private func rules(_ bundle: ContentBundle) -> Set<String> {
        Set(ContentValidator.validate(bundle).issues.map(\.rule))
    }

    // MARK: - Master rules

    /// Phase 6 replaced the flat point table with a percentage of the item's
    /// own budget, so "the table is shorter than the cap" cannot happen any
    /// more. What can is a zero fraction — an enchant bench that charges for
    /// nothing.
    func testEnchantWithNoEffectIsAnError() {
        XCTAssertTrue(rules(bundle(master: validMaster(cap: 5, fraction: 0)))
            .contains("master.enchant_no_effect"))
    }

    /// Past 1.35x total, the rarity × enchant axis starts outrunning forty
    /// levels of stat growth — the cliff the drafted rarity multipliers fell off.
    func testRunawayEnchantWarns() {
        XCTAssertTrue(rules(bundle(master: validMaster(cap: 5, fraction: 0.20)))
            .contains("master.enchant_runaway"))
    }

    /// `enchantStep` looks a level up by value, so a gap makes it unreachable.
    func testEnchantLevelGapIsAnError() {
        let steps = [
            EnchantStepDTO(level: 1, silver: 40, materialId: "mat.hide", materialQty: 4),
            EnchantStepDTO(level: 3, silver: 90, materialId: "mat.hide", materialQty: 8)
        ]
        XCTAssertTrue(rules(bundle(master: validMaster(cap: 2, steps: steps)))
            .contains("master.levels_not_contiguous"))
    }

    /// Above 1.0 a full repair costs more than a new piece, so nobody repairs.
    func testRepairFractionAboveOneIsAnError() {
        let master = MasterFileDTO(armorForSale: [], repairCostFraction: 1.5, enchantCap: 1,
                                   enchantBudgetFractionPerLevel: 0.04,
                                   enchantSteps: [EnchantStepDTO(level: 1, silver: 40, materialId: "mat.hide", materialQty: 4)])
        XCTAssertTrue(rules(bundle(master: master)).contains("master.repair_fraction"))
    }

    func testArmorShopSellingANonGearItemIsAnError() {
        let master = MasterFileDTO(
            armorForSale: [MasterArmorListingDTO(itemId: "mat.hide", priceSilver: 60)],
            repairCostFraction: 0.5, enchantCap: 1, enchantBudgetFractionPerLevel: 0.04,
            enchantSteps: [EnchantStepDTO(level: 1, silver: 40, materialId: "mat.hide", materialQty: 4)])
        XCTAssertTrue(rules(bundle(master: master)).contains("master.not_gear"))
    }

    func testWellFormedMasterIsClean() {
        XCTAssertTrue(rules(bundle(master: validMaster())).isEmpty)
    }

    // MARK: - Plot rules

    /// `PlotType` raw values are persisted in `Plot.plotType`, so a type the
    /// file forgets is a row the game can load but cannot describe.
    func testMissingPlotTypeIsAnError() {
        var types = allPlots().types
        types.removeAll { $0.type == "coop" }
        XCTAssertTrue(rules(bundle(plots: PlotFileDTO(types: types)))
            .contains("plot.type_missing"))
    }

    func testWellFormedPlotsAreClean() {
        XCTAssertTrue(rules(bundle(plots: allPlots())).isEmpty)
    }

    // MARK: - Fortune rules

    /// The wheel only fires when both sides are set, so setting one alone is an
    /// effect that silently never happens.
    func testHalfConfiguredWheelIsAWarning() {
        let fortune = FortuneFileDTO(drawPrice: 10, buffDurationSeconds: 21600, cooldownSeconds: 86400,
                                     cards: [FortuneCardDTO(id: "10_wheel",
                                                            effect: FortuneEffectDTO(randomSilverPositive: 30))])
        let report = ContentValidator.validate(bundle(fortune: fortune))
        XCTAssertTrue(report.warnings.contains { $0.rule == "fortune.half_wheel" })
    }

    /// The id becomes `Assets/capital/fortune/<id>.png`, so a separator would
    /// build a path outside the asset directory.
    func testUnsafeCardIdIsAnError() {
        let fortune = FortuneFileDTO(drawPrice: 10, buffDurationSeconds: 21600, cooldownSeconds: 86400,
                                     cards: [FortuneCardDTO(id: "../secrets")])
        XCTAssertTrue(rules(bundle(fortune: fortune)).contains("fortune.unsafe_id"))
    }

    func testZeroMultiplierIsAnError() {
        let fortune = FortuneFileDTO(drawPrice: 10, buffDurationSeconds: 21600, cooldownSeconds: 86400,
                                     cards: [FortuneCardDTO(id: "0_fool",
                                                            effect: FortuneEffectDTO(xpMultiplier: 0))])
        XCTAssertTrue(rules(bundle(fortune: fortune)).contains("fortune.non_positive_multiplier"))
    }

    // MARK: - Quest rules

    private func pool(_ npc: String, _ ids: [String]) -> QuestPoolDTO {
        QuestPoolDTO(npc: npc, quests: ids.map {
            QuestDefDTO(id: $0,
                        objective: QuestObjectiveDTO(kind: .deliver, itemIds: ["mat.hide"], target: 3),
                        reward: QuestRewardDTO(silver: 60))
        })
    }

    private func allPools(_ overrides: [String: [String]] = [:]) -> QuestFileDTO {
        QuestFileDTO(pools: ["trader", "master", "tavern"].map {
            pool($0, overrides[$0] ?? ["\($0).one", "\($0).two"])
        })
    }

    /// `daily` falls back to a synthetic zero-reward job on an empty pool
    /// rather than trapping, which would ship as a visible but unearnable board.
    func testEmptyPoolIsAnError() {
        XCTAssertTrue(rules(bundle(quests: allPools(["trader": []]))).contains("quest.pool_empty"))
    }

    func testMissingNPCPoolIsAnError() {
        let quests = QuestFileDTO(pools: [pool("trader", ["trader.one"]), pool("master", ["master.one"])])
        XCTAssertTrue(rules(bundle(quests: quests)).contains("quest.npc_missing"))
    }

    /// `find` is a global lookup and a stored row re-hydrates by id alone, so
    /// ids must be unique across every pool — not merely within one.
    func testDuplicateQuestIdAcrossDifferentPoolsIsAnError() {
        let quests = QuestFileDTO(pools: [
            pool("trader", ["shared.id"]), pool("master", ["shared.id"]), pool("tavern", ["tavern.one"])
        ])
        XCTAssertTrue(rules(bundle(quests: quests)).contains("identity.duplicate_id"))
    }

    func testUnknownCounterIsAnError() {
        let quests = QuestFileDTO(pools: [
            QuestPoolDTO(npc: "trader", quests: [
                QuestDefDTO(id: "trader.one",
                            objective: QuestObjectiveDTO(kind: .counter, counter: "fishCaught", target: 3),
                            reward: QuestRewardDTO(silver: 60))
            ]),
            pool("master", ["master.one"]), pool("tavern", ["tavern.one"])
        ])
        XCTAssertTrue(rules(bundle(quests: quests)).contains("enum.quest_counter.unknown"))
    }

    func testWellFormedQuestsAreClean() {
        XCTAssertTrue(rules(bundle(quests: allPools())).isEmpty)
    }
}
