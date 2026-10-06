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
//  * a plot's ABSENT tuning is a value, not a gap — the DTO keeps it optional
//    even though every shipped type produces since the Training Ground
//    left the plots (2026-09-27);
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
        let json = Data(#"{"type":"shrine","icon":"⛩"}"#.utf8)
        let row = try JSONDecoder().decode(PlotTypeDTO.self, from: json)
        XCTAssertNil(row.tuning, "a nil tuning is how a non-producing plot is recognised")
    }

    func testPlotTuningNilSurvivesTheRoundTrip() throws {
        let original = PlotFileDTO(types: [
            PlotTypeDTO(type: "farm", icon: "🌾",
                        tuning: PlotTuningDTO(producedItemId: "food.potato", ratePerInterval: 4, capacity: 20)),
            PlotTypeDTO(type: "shrine", icon: "⛩")
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
                ItemDTO(id: "gear.forester_hood", type: "gear", tier: 1, stackable: false, slot: "helmet",
                        maxDurability: 50)
            ],
            enemies: [], recipes: [], starterRecipeIds: [],
            master: master, plots: plots, fortune: fortune, quests: quests,
            contentHash: "test"
        )
    }

    /// One enchant level, budgeted like the shipped ladder — item level 5 × the
    /// level — unless a test says otherwise.
    private func enchantStep(_ level: Int, silver: Int? = nil, itemLevel: Int? = nil) -> EnchantStepDTO {
        EnchantStepDTO(level: level, silver: silver ?? 40 * level, materialId: "mat.hide",
                       materialQty: 4 * level, itemLevel: itemLevel ?? 5 * level)
    }

    private func validMaster(cap: Int = 3, share: Double = 0.75,
                             steps: [EnchantStepDTO]? = nil) -> MasterFileDTO {
        MasterFileDTO(
            armorForSale: [MasterArmorListingDTO(itemId: "gear.forester_hood", priceSilver: 60)],
            repairCostFraction: 0.5,
            enchantCap: cap,
            enchantGrowthShare: share,
            enchantSteps: steps ?? (1...max(1, cap)).map { enchantStep($0) }
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
                        tuning: PlotTuningDTO(producedItemId: "food.potato", ratePerInterval: 2, capacity: 12))
        ])
    }

    private func rules(_ bundle: ContentBundle) -> Set<String> {
        Set(ContentValidator.validate(bundle).issues.map(\.rule))
    }

    // MARK: - Master rules

    /// The enchant is a ladder since 2026-10-06 (`spec-items.md` §11): a level
    /// carries a share of the budget curve's growth. At a share of zero the
    /// bench charges for nothing.
    func testEnchantWithNoEffectIsAnError() {
        XCTAssertTrue(rules(bundle(master: validMaster(cap: 5, share: 0)))
            .contains("master.enchant_no_effect"))
    }

    /// Above 1 an enchanted piece outgrows the on-curve item of the level that
    /// opens it — the weapon ladder's own defect, before it was rebuilt.
    func testGrowthShareAboveOneIsAnError() {
        XCTAssertTrue(rules(bundle(master: validMaster(cap: 5, share: 1.2)))
            .contains("master.enchant_growth_share"))
        XCTAssertFalse(rules(bundle(master: validMaster(cap: 5, share: 1.0)))
            .contains("master.enchant_growth_share"))
    }

    /// Item level 0 has no budget.
    func testEnchantItemLevelStartsAtOne() {
        XCTAssertTrue(rules(bundle(master: validMaster(cap: 1, steps: [enchantStep(1, itemLevel: 0)])))
            .contains("master.enchant_item_level"))
        XCTAssertFalse(rules(bundle(master: validMaster(cap: 1))).contains("master.enchant_item_level"))
    }

    /// A level that budgets no higher than the last lifts nothing.
    func testEnchantLevelsMustClimb() {
        let flat = [enchantStep(1), enchantStep(2, itemLevel: 5)]
        XCTAssertTrue(rules(bundle(master: validMaster(cap: 2, steps: flat)))
            .contains("master.enchant_item_level_not_ascending"))
        XCTAssertFalse(rules(bundle(master: validMaster(cap: 3)))
            .contains("master.enchant_item_level_not_ascending"))
    }

    /// The price is the only thing that holds an enchant level back
    /// (`spec-items.md` §11), so a price that falls opens the level above early.
    func testAnEnchantPriceThatFallsIsReported() {
        let falls = [enchantStep(1, silver: 200), enchantStep(2, silver: 150)]
        XCTAssertTrue(rules(bundle(master: validMaster(cap: 2, steps: falls)))
            .contains("master.enchant_cost_drops"))
        XCTAssertFalse(rules(bundle(master: validMaster(cap: 3))).contains("master.enchant_cost_drops"))
    }

    /// `enchantStep` looks a level up by value, so a gap makes it unreachable.
    func testEnchantLevelGapIsAnError() {
        let steps = [enchantStep(1), enchantStep(3, silver: 90)]
        XCTAssertTrue(rules(bundle(master: validMaster(cap: 2, steps: steps)))
            .contains("master.levels_not_contiguous"))
    }

    /// Above 1.0 a full repair costs more than a new piece, so nobody repairs.
    func testRepairFractionAboveOneIsAnError() {
        let master = MasterFileDTO(armorForSale: [], repairCostFraction: 1.5, enchantCap: 1,
                                   enchantGrowthShare: 0.75,
                                   enchantSteps: [enchantStep(1)])
        XCTAssertTrue(rules(bundle(master: master)).contains("master.repair_fraction"))
    }

    func testArmorShopSellingANonGearItemIsAnError() {
        let master = MasterFileDTO(
            armorForSale: [MasterArmorListingDTO(itemId: "mat.hide", priceSilver: 60)],
            repairCostFraction: 0.5, enchantCap: 1, enchantGrowthShare: 0.75,
            enchantSteps: [enchantStep(1)])
        XCTAssertTrue(rules(bundle(master: master)).contains("master.not_gear"))
    }

    func testWellFormedMasterIsClean() {
        XCTAssertTrue(rules(bundle(master: validMaster())).isEmpty)
    }

    /// The lesson's fee (`spec-items.md` §9.4): zero is a free lesson, below
    /// zero the Master would pay the player to learn.
    func testNegativeLessonFeeIsAnError() {
        let master = MasterFileDTO(armorForSale: [], repairCostFraction: 0.5, enchantCap: 1,
                                   enchantGrowthShare: 0.75,
                                   enchantSteps: [enchantStep(1)],
                                   weaponLessonSilver: -1)
        XCTAssertTrue(rules(bundle(master: master)).contains("master.lesson_silver"))
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

    /// Ukrainian agrees with the plot's own noun — «Шахта заповнена» but
    /// «Курник заповнений» — so every plot name declares its gender, in uk
    /// only. Missing, the ready notification falls back to masculine, which is
    /// wrong for three of the four producing plots.
    func testPlotWithoutADeclaredGenderWarns() {
        let report = ContentValidator.validate(bundle(plots: allPlots()),
                                               localizations: plotLocales(genders: ["farm": "f"]))
        XCTAssertTrue(report.issues.contains {
            $0.rule == "locale.plot_gender_missing" && $0.id == "mine"
        })
        XCTAssertFalse(report.issues.contains {
            $0.rule == "locale.plot_gender_missing" && $0.id == "farm"
        })
    }

    func testPlotGenderOutsideTheFourFormsIsAnError() {
        let report = ContentValidator.validate(
            bundle(plots: allPlots()),
            localizations: plotLocales(genders: ["farm": "f", "forest": "f", "mine": "f",
                                                 "coop": "ж"]))
        XCTAssertTrue(report.errors.contains {
            $0.rule == "locale.plot_gender_invalid" && $0.id == "coop"
        })
    }

    /// Name + desc in both locales (so the plain key check stays quiet), and
    /// whichever genders the caller wants declared, uk only.
    private func plotLocales(genders: [String: String]) -> LocaleIndex {
        let types = ["farm", "forest", "mine", "coop"]
        var en: [String: String] = [:]
        var uk: [String: String] = [:]
        for t in types {
            en["plot.type.\(t).name"] = t
            en["plot.type.\(t).desc"] = t
            uk["plot.type.\(t).name"] = t
            uk["plot.type.\(t).desc"] = t
            if let g = genders[t] { uk["plot.type.\(t).gender"] = g }
        }
        return LocaleIndex(tables: ["en": en, "uk": uk])
    }

    // MARK: - Fortune rules

    /// The wheel rolls when either side is set, so setting one alone makes a
    /// 50/50 between that side and nothing — an authoring slip worth a warning.
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

    /// A counter job names its count on the board and in the journal, so its
    /// label must exist in both locales. Fired against a table holding the
    /// job's title and description and nothing else — the only way to know
    /// the rule is wired at all.
    func testAMissingCounterLabelIsAnError() {
        let quests = QuestFileDTO(pools: [
            QuestPoolDTO(npc: "trader", quests: [
                QuestDefDTO(id: "trader.one",
                            objective: QuestObjectiveDTO(kind: .counter, counter: "beastKill", target: 3),
                            reward: QuestRewardDTO(silver: 60))
            ])
        ])
        let present = ["quest.trader.board_title": "t", "quest.trader.one.title": "t", "quest.trader.one.desc": "d"]
        let missing = ContentValidator.validate(bundle(quests: quests),
                                                localizations: LocaleIndex(tables: ["en": present, "uk": present]))
            .errors.filter { $0.rule == "locale.key.missing" && $0.message.contains("quest.counter.beastKill") }
        XCTAssertEqual(missing.count, 2, "expected en + uk, got \(missing.map(\.file))")

        let labelled = present.merging(["quest.counter.beastKill": "k"]) { a, _ in a }
        XCTAssertFalse(ContentValidator.validate(bundle(quests: quests),
                                                 localizations: LocaleIndex(tables: ["en": labelled, "uk": labelled]))
            .errors.contains { $0.message.contains("quest.counter.") })
    }

    func testWellFormedQuestsAreClean() {
        XCTAssertTrue(rules(bundle(quests: allPools())).isEmpty)
    }
}
