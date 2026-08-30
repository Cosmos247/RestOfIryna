//
//  ContentDigest.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 29.08.2026.
//
//  Verification layer 3 for the catalog migration: a single hex digest over
//  everything the catalogs expose, computed the same way before and after the
//  Swift arrays are replaced by JSON.
//
//    swift run RestOfIryna --content-digest
//
//  Three halves, because three different things can break:
//
//  1. **Record fingerprints** — every stored property of every item, enemy,
//     recipe, ladder step, card and job, in catalog order, plus an accessor
//     replay for the derived reads (`nextStep`, `capForTier`, `durability`,
//     `stats`, `leagueKey`, `tithe`, `repairCost`, `icon`, `tuning`). The
//     accessor half exists because fingerprinting data does not verify the code
//     that reads it — `PlotCatalog.icon` and `MasterCatalog.repairCost` have no
//     backing array at all.
//  2. **Seeded `pickFor` replay** — 40 depths × 200 draws from a fixed seed.
//     `EnemyCatalog.pickFor` is `filter().randomElement()`, so the DECLARATION
//     ORDER of the roster decides which enemy a given roll returns. A reorder
//     that leaves every record byte-identical would still silently change every
//     encounter in the game; only a seeded replay catches that.
//  3. **Seeded `daily()` replay** — 200 users × 4 days × 3 NPCs. Same shape,
//     same reason: `QuestCatalog.daily` is
//     `pool[stableHash("<uuid>:<npc>:<day>") % pool.count]`, so pool order is
//     the assignment. Negative-tested — dropping the day from the hash key
//     leaves `records` byte-identical and moves this half alone.
//
//  Every dictionary a catalog exposes (`pools`, `t1Tunings`,
//  `WeaponUpgradeCatalog.progression`) is walked via `allCases` or a sorted key
//  list. Iterating one directly would make the digest differ between processes
//  and quietly destroy the whole comparison.
//
//  Full `RandomNumberGenerator` threading through `ExplorationService` /
//  `CombatService` is NOT needed here — the migration changes where catalog
//  data comes from, not how rolls resolve. That refactor stays a Phase 8
//  prerequisite for the simulator.
//

import Foundation

enum ContentDigest {

    /// Fixed seed and draw count. Changing either invalidates every recorded
    /// digest, so treat them as constants.
    private static let seed: UInt64 = 0x5245_4241_4C41_4E43   // "REBALANC"
    private static let drawsPerDepth = 200
    private static let maxDepth = 40

    /// Daily-quest replay inputs. The stamps straddle a month boundary on
    /// purpose — `daily` hashes the stamp as a plain string, so nothing about
    /// the date is special, but a spread of them keeps one unlucky day from
    /// hiding a pool reorder behind a collision.
    private static let questDraws = 200
    private static let questStamps = ["2026-08-29", "2026-08-30", "2026-09-01", "2027-01-15"]

    static func run() {
        var digest = OutcomeDigest()

        for item in ItemCatalog.all { digest.combine(fingerprint(item)) }
        for enemy in EnemyCatalog.all { digest.combine(fingerprint(enemy)) }
        // The archetype table is a DICTIONARY on the snapshot, so it is walked
        // via `allCases` — iterating it directly would hash in seeded-hash
        // order and differ between processes.
        for kind in EnemyArchetype.allCases {
            digest.combine(kind.rawValue)
            guard let spec = EnemyCatalog.archetype(kind) else { digest.combine("-"); continue }
            digest.combine("r\(spec.rounds) hp\(spec.hpLossPercent) mit\(spec.mitigationPercent)")
            digest.combine("dodge\(spec.dodgePercent) crit\(spec.critPercent)")
            digest.combine("xp\(spec.xpMultiplier) loot\(spec.lootMultiplier)")
            digest.combine("weight\(spec.spawnWeight)")
        }
        // MARK: Phase 6 — rarity, sets, item budget
        for rarity in RarityCatalog.all {
            digest.combine("\(rarity.id) budget\(rarity.budgetMultiplier) value\(rarity.valueMultiplier) \(rarity.glyph)")
        }
        for set in GearSetCatalog.all {
            digest.combine("\(set.id) · \(set.nameKey)")
            for bonus in set.bonuses {
                switch bonus.effect {
                case .flatStats(let st):
                    digest.combine("\(bonus.pieces)pc flat \(st.attack)/\(st.defense)/\(st.hp)/\(st.crit)/\(st.dodge)/\(st.accuracy)")
                case .gearMultiplier(let m):
                    digest.combine("\(bonus.pieces)pc mult \(m)")
                }
            }
        }
        // The exchange rates. Hashed directly because nothing else reaches
        // them: `ItemBudget.points` returns an ALLOWANCE, and the rates only
        // enter when that allowance is spent — so doubling "one point buys 0.42
        // attack" would double every generated weapon without moving a single
        // other entry in this digest.
        let perPoint = Catalogs.current.budget.statPerPoint
        digest.combine("statPerPoint \(perPoint.attack)/\(perPoint.defense)/\(perPoint.hp)/"
                       + "\(perPoint.crit)/\(perPoint.dodge)/\(perPoint.accuracy)")
        // The reference kit, which is the only thing that reads the class
        // budget profiles. Hashing it covers the profiles AND the exchange
        // rates through the same call the acceptance check uses, so the printed
        // table and the digest can never disagree about what the model says.
        for cls in CharacterClass.allCases {
            for level in [1, 20, 40] {
                let kit = ItemBudget.referenceGear(for: cls, itemLevel: level)
                digest.combine("refKit \(cls.rawValue)@\(level): \(kit.attack)/\(kit.defense)/"
                               + "\(kit.hp)/\(kit.crit)/\(kit.dodge)/\(kit.accuracy)")
            }
        }
        // Replayed through the accessor rather than hashed as constants: the
        // slot weights are a dictionary, and the curve only means something
        // once a level, a slot and a rarity have gone through it together.
        for slot in EquipmentSlot.allCases {
            for level in [1, 20, 40] {
                for rarity in RarityCatalog.all.map(\.id) {
                    let points = ItemBudget.points(itemLevel: level, slot: slot, rarity: rarity)
                    digest.combine("budget \(slot.rawValue)@\(level)/\(rarity): \(points.map { String(format: "%.3f", $0) } ?? "-")")
                }
            }
        }
        for recipe in RecipeCatalog.all { digest.combine(fingerprint(recipe)) }
        for id in RecipeCatalog.starterRecipeIds.sorted() { digest.combine(id) }
        for id in WeaponUpgradeCatalog.progression.keys.sorted() {
            digest.combine(id)
            for (index, step) in (WeaponUpgradeCatalog.progression[id] ?? []).enumerated() {
                digest.combine("t\(index + 1) iLvl\(step.itemLevel)")
                digest.combine("\(step.stats.attack)/\(step.stats.defense)/\(step.stats.hp)/\(step.stats.crit)/\(step.stats.dodge)/\(step.stats.accuracy)")
                for input in step.inputs { digest.combine("\(input.itemId)x\(input.quantity)") }
            }
        }
        for durability in WeaponUpgradeCatalog.durabilityByTier { digest.combine(durability) }

        digest.combine(BagCatalog.maxTier)
        for capacity in BagCatalog.capacities { digest.combine(capacity) }
        for step in BagCatalog.progression { digest.combine(fingerprint(step)) }

        digest.combine(EstateUpgradeCatalog.maxTier)
        for step in EstateUpgradeCatalog.progression { digest.combine(fingerprint(step)) }

        for listing in TraderCatalog.all {
            digest.combine("\(listing.itemId) s\(listing.sellPacketQty)@\(listing.sellPacketSilver) b\(listing.buyPacketQty)@\(listing.buyPacketSilver)")
        }
        for listing in TavernCatalog.food { digest.combine("\(listing.itemId)@\(listing.priceSilver)") }
        for wager in TavernCatalog.wagerTiers { digest.combine(wager) }

        digest.combine(MarketCatalog.listingFee)
        digest.combine(MarketCatalog.maxActiveLots)

        digest.combine(GuildCatalog.memberCap)
        digest.combine(GuildCatalog.maxOfficers)
        digest.combine(GuildCatalog.foundCost)
        digest.combine(GuildCatalog.foundLevelGate)
        digest.combine(GuildCatalog.defaultEmblem)
        digest.combine(GuildCatalog.nameMinLength)
        digest.combine(GuildCatalog.nameMaxLength)
        digest.combine(GuildCatalog.vaultUnitCap)

        for stake in ArenaCatalog.stakeTiers { digest.combine(stake) }
        digest.combine(ArenaCatalog.tithePercent)
        digest.combine(ArenaCatalog.startingHonor)
        digest.combine("\(ArenaCatalog.honorKFactor)")
        digest.combine(ArenaCatalog.minHonor)
        digest.combine("\(ArenaCatalog.turnSeconds)")
        digest.combine(ArenaCatalog.maxMissedTurns)
        digest.combine("\(ArenaCatalog.challengeTTL)")
        digest.combine("\(ArenaCatalog.lobbyTTL)")
        digest.combine("\(ArenaCatalog.sweepInterval)")
        digest.combine(ArenaCatalog.dailyFightCap)
        // Replay the league boundaries rather than trusting the thresholds:
        // `leagueKey` is a switch today and a table after the move, so only
        // exercising it across the range proves the two agree.
        for honor in stride(from: 0, through: 2000, by: 5) {
            digest.combine(ArenaCatalog.leagueKey(forHonor: honor))
        }
        // Accessor replay. The record fingerprints above cover the DATA; these
        // cover the derived READS, whose bodies were rewritten when the
        // catalogs became façades. `nextStep` indexes by position, `capForTier`
        // and `durability(forTier:)` clamp — all three are exactly the kind of
        // logic a data fingerprint cannot see.
        for tier in -2...12 {
            digest.combine(BagCatalog.capForTier(tier))
            digest.combine(WeaponUpgradeCatalog.durability(forTier: tier))
            digest.combine(BagCatalog.nextStep(from: tier).map(fingerprint) ?? "-")
            digest.combine(EstateUpgradeCatalog.nextStep(from: tier).map(fingerprint) ?? "-")
            digest.combine("\(BagCatalog.canUpgrade(from: tier))")
            digest.combine("\(EstateUpgradeCatalog.canUpgrade(from: tier))")
        }
        for itemId in ["gear.rusty_sword", "gear.simple_bow", "gear.wooden_staff", "gear.forester_hood", "nope"] {
            digest.combine("\(WeaponUpgradeCatalog.isUpgradable(itemId))")
            digest.combine(WeaponUpgradeCatalog.maxTier(for: itemId).map(String.init) ?? "-")
            for tier in 0...6 {
                let stats = WeaponUpgradeCatalog.stats(for: itemId, tier: tier)
                digest.combine(stats.map { "\($0.attack)/\($0.defense)/\($0.hp)/\($0.crit)/\($0.dodge)/\($0.accuracy)" } ?? "-")
            }
        }

        // Tithe rounding is `.rounded()` on a Double — replay it too.
        for pot in stride(from: 0, through: 2000, by: 7) {
            digest.combine(ArenaCatalog.tithe(onPot: pot))
        }

        // MARK: Batch C — Master / Plot / Fortune / Quest
        //
        // Added while all four are still Swift arrays, per step 1 of the
        // migration loop. Two of them carry behaviour in code rather than data
        // (`PlotCatalog.icon`, `QuestCatalog.daily`), so the accessor replays
        // below matter more here than they did for batch B.

        digest.combine(MasterCatalog.enchantCap)
        digest.combine("\(MasterCatalog.enchantBudgetFractionPerLevel)")
        for listing in MasterCatalog.armorForSale {
            digest.combine("\(listing.itemId)@\(listing.priceSilver)")
        }
        for step in MasterCatalog.enchantSteps { digest.combine(fingerprint(step)) }
        // `repairCost` folds in `GearConditionService.maxDurabilityStart` and a
        // hardcoded 0.5, then rounds — none of which a record hash can see.
        for itemId in MasterCatalog.armorForSale.map(\.itemId) + ["gear.rusty_sword", "nope"] {
            digest.combine(MasterCatalog.buyPrice(for: itemId).map(String.init) ?? "-")
            for missing in [-5, 0, 1, 7, 15, 29, 30, 31, 60] {
                digest.combine(MasterCatalog.repairCost(itemId: itemId, missing: missing))
            }
        }
        for missing in [-5, 0, 1, 30, 100] { digest.combine(MasterCatalog.weaponRepairCost(missing: missing)) }
        // Replayed past both ends: the multiplier clamps at 0 below and at the
        // cap above, and a change to either bound is invisible in the raw
        // fraction alone.
        for level in -1...8 {
            digest.combine("\(MasterCatalog.enchantMultiplier(level: level))")
            digest.combine(MasterCatalog.enchantBonusPercent(level: level))
        }
        for level in -1...6 {
            digest.combine(MasterCatalog.enchantStep(currentLevel: level).map(fingerprint) ?? "-")
        }

        // `t1Tunings` is a DICTIONARY, so iterating it directly would hash in
        // whatever order the hasher happens to produce this process. Walking
        // `PlotType.allCases` is what makes the plot half reproducible at all.
        // `PlotCatalog.testMode` used to be hashed here. Phase 4b deletes the
        // flag, so what is hashed is the value it produced — which is the thing
        // that must not change when the flag becomes `time.scale`.
        digest.combine("\(PlotCatalog.intervalSeconds)")
        for type in PlotType.allCases {
            digest.combine(type.rawValue)
            digest.combine(PlotCatalog.icon(for: type))
            digest.combine(PlotCatalog.nameKey(for: type))
            digest.combine(PlotCatalog.descriptionKey(for: type))
            // Every tier returns the T1 row today — a documented placeholder.
            // Replaying the range pins that, so the day tiers become real it
            // shows up as a digest move rather than a silent behaviour change.
            for tier in 0...3 {
                digest.combine(PlotCatalog.tuning(for: type, tier: tier).map(fingerprint) ?? "-")
            }
        }
        for raw in ["farm", "forest", "mine", "coop", "training_ground", "Farm", "nope", ""] {
            digest.combine(PlotCatalog.tuning(forRaw: raw).map(fingerprint) ?? "-")
        }

        digest.combine(FortuneCatalog.drawPrice)
        digest.combine("\(FortuneCatalog.buffDurationSeconds)")
        digest.combine("\(FortuneCatalog.cooldownSeconds)")
        for card in FortuneCatalog.all { digest.combine(fingerprint(card)) }
        for cardId in FortuneCatalog.all.map(\.id) + ["nope", ""] {
            digest.combine(FortuneCatalog.find(cardId).map(fingerprint) ?? "-")
        }

        // `pools` is a dictionary too — same reasoning as `t1Tunings`.
        for npc in QuestNPC.allCases {
            digest.combine(npc.rawValue)
            digest.combine(npc.boardTitleKey)
            digest.combine(npc.backCallback)
            for def in QuestCatalog.pools[npc] ?? [] { digest.combine(fingerprint(def)) }
        }
        for questId in QuestNPC.allCases.flatMap({ (QuestCatalog.pools[$0] ?? []).map(\.id) }) + ["nope", ""] {
            digest.combine(QuestCatalog.find(questId).map(fingerprint) ?? "-")
        }

        // Snapshot the record-only hash before the replays fold in.
        let recordDigest = digest.hexDigest

        // Phase 4's own half. Kept OUT of `digest` until here so `records`
        // keeps its Phase 3 value: the tuning move must leave the catalogs
        // provably untouched, and it can only prove that if their hash is
        // still comparable to the one batch C signed off on.
        let tuningDigest = tuningFingerprint()

        // Seeded encounter replay — the half that catches a reordered roster.
        var rng = SplitMix64(seed: seed)
        var spawns = OutcomeDigest()
        var counts: [String: Int] = [:]
        for km in 1...maxDepth {
            for _ in 0..<drawsPerDepth {
                let picked = EnemyCatalog.pickFor(kmDepth: km, using: &rng)
                let id = picked?.id ?? "-"
                spawns.combine(id)
                counts[id, default: 0] += 1
            }
        }
        let spawnDigest = spawns.hexDigest

        digest.combine(tuningDigest)
        digest.combine(spawnDigest)

        // Seeded daily-quest replay — the batch-C twin of the spawn replay, and
        // for the same reason. `QuestCatalog.daily` resolves to
        // `pool[stableHash("<uuid>:<npc>:<day>") % pool.count]`, so the ORDER of
        // each NPC's pool decides which job every player is handed. Reordering a
        // pool leaves all nine record fingerprints byte-identical while silently
        // reassigning the whole playerbase; only replaying the derivation with
        // fixed inputs catches it.
        var questRNG = SplitMix64(seed: seed)
        var quests = OutcomeDigest()
        var questCounts: [String: Int] = [:]
        for _ in 0..<questDraws {
            let userId = seededUUID(&questRNG)
            for stamp in questStamps {
                for npc in QuestNPC.allCases {
                    let id = QuestCatalog.daily(npc: npc, userId: userId, stamp: stamp).id
                    quests.combine(id)
                    questCounts[id, default: 0] += 1
                }
            }
        }
        let questDigest = quests.hexDigest

        digest.combine(questDigest)

        print("records  \(recordDigest)   (\(ItemCatalog.all.count) items · \(EnemyCatalog.all.count) enemies · \(RecipeCatalog.all.count) recipes · \(WeaponUpgradeCatalog.progression.count) ladders · \(BagCatalog.progression.count) bag steps · \(EstateUpgradeCatalog.progression.count) estate steps · \(FortuneCatalog.all.count) cards · \(QuestNPC.allCases.reduce(0) { $0 + (QuestCatalog.pools[$1]?.count ?? 0) }) quests)")
        print("tuning   \(tuningDigest)   (combat · vigor · exploration · progression · economy · time)")
        print("spawns   \(spawnDigest)   (\(maxDepth) depths × \(drawsPerDepth) seeded draws)")
        print("quests   \(questDigest)   (\(questDraws) users × \(questStamps.count) days × \(QuestNPC.allCases.count) NPCs)")
        print("COMBINED \(digest.hexDigest)")
        print("")
        liveLookupCheck()

        combatModelCheck()
        referenceCharacterCheck()

        // Printed, not hashed. A balance phase is read by eye as much as by
        // comparison, and a stat ladder that has gone wrong is obvious in a
        // table and invisible in a hex digest.
        print("stat ladder (base line, before gear):")
        print("  " + "level".padding(toLength: 8, withPad: " ", startingAt: 0)
              + ["warrior", "archer", "mage"].map {
                  $0.padding(toLength: 30, withPad: " ", startingAt: 0)
              }.joined())
        for level in [1, 5, 10, 21, 40] {
            var row = "L\(level)".padding(toLength: 8, withPad: " ", startingAt: 0)
            for cls in CharacterClass.allCases {
                let s = User.baseStats(for: cls, at: level)
                row += "\(s.maxHp)hp \(s.attack)atk \(s.defense)def \(s.crit)/\(s.dodge)/\(s.accuracy)"
                    .padding(toLength: 30, withPad: " ", startingAt: 0)
            }
            print("  " + row + "vigor \(User.maxVigor(at: level))")
        }
        print("")

        print("spawn distribution:")
        for (id, count) in counts.sorted(by: { $0.key < $1.key }) {
            print("  \(id.padding(toLength: 24, withPad: " ", startingAt: 0)) \(count)")
        }
        // Worth printing rather than just hashing: a job that never appears is
        // unreachable content, and `daily` is a modulo over pool size, so an
        // uneven split is the visible symptom of a pool that changed length.
        print("")
        print("daily-quest distribution:")
        for npc in QuestNPC.allCases {
            for def in QuestCatalog.pools[npc] ?? [] {
                let count = questCounts[def.id] ?? 0
                let flag = count == 0 ? "   ⚠️ never assigned" : ""
                print("  \(def.id.padding(toLength: 24, withPad: " ", startingAt: 0)) \(count)\(flag)")
            }
        }
        fflush(stdout)
    }

    /// Smoke test of the FAÇADE path rather than the data.
    ///
    /// `ContentValidator` checks referential integrity on the DTO bundle; this
    /// resolves the same references through `ItemCatalog.find` / `.items(of:)`
    /// / `RecipeCatalog.find` as the game does, so a façade that silently
    /// returns nil — a lookup dictionary built from the wrong key, a snapshot
    /// installed half-empty — is caught even though the JSON is perfect.
    private static func liveLookupCheck() {
        var problems: [String] = []

        for recipe in RecipeCatalog.all {
            for input in recipe.inputs where ItemCatalog.find(input.itemId) == nil {
                problems.append("recipe \(recipe.id) input \(input.itemId) does not resolve")
            }
            if ItemCatalog.find(recipe.output.itemId) == nil {
                problems.append("recipe \(recipe.id) output \(recipe.output.itemId) does not resolve")
            }
        }
        for enemy in EnemyCatalog.all {
            if EnemyCatalog.find(enemy.id) == nil {
                problems.append("enemy \(enemy.id) does not resolve through find()")
            }
            for drop in enemy.lootTable where ItemCatalog.find(drop.itemId) == nil {
                problems.append("enemy \(enemy.id) loot \(drop.itemId) does not resolve")
            }
        }
        for item in ItemCatalog.all {
            if ItemCatalog.find(item.id) == nil {
                problems.append("item \(item.id) does not resolve through find()")
            }
            if let taught = item.teachesRecipe, RecipeCatalog.find(taught) == nil {
                problems.append("scroll \(item.id) teaches unresolvable \(taught)")
            }
        }
        for id in RecipeCatalog.starterRecipeIds where RecipeCatalog.find(id) == nil {
            problems.append("starter recipe \(id) does not resolve")
        }
        for characterClass in CharacterClass.allCases {
            let weaponId = characterClass.starterWeaponId
            guard let weapon = ItemCatalog.find(weaponId) else {
                problems.append("\(characterClass.rawValue) starter weapon \(weaponId) does not resolve")
                continue
            }
            if weapon.slot != .mainHand {
                problems.append("\(characterClass.rawValue) starter weapon is not a main-hand item")
            }
        }
        // Grouping is a separate index from the id lookup, so check it too.
        let grouped = ItemType.allCases.reduce(0) { $0 + ItemCatalog.items(of: $1).count }
        if grouped != ItemCatalog.all.count {
            problems.append("items(of:) covers \(grouped) items but the catalog holds \(ItemCatalog.all.count)")
        }

        // The sweeper derivation is a HAND-TRANSLATION — `PlotProductionService
        // .tickInterval` was `testMode ? 60 : 300` and is now
        // `max(minSeconds, interval / divisor)`. The digest can only ever see
        // one branch of `testMode` per process, so the equivalence is proven
        // here instead: the old function had exactly two reachable outputs, and
        // both are checked against the interval that produces them.
        for (interval, expected) in [(60.0, 60.0), (3600.0, 300.0)] {
            let derived = PlotProductionService.tickInterval(forPlotInterval: interval)
            if derived != expected {
                problems.append("plot sweeper: interval \(interval)s derives \(derived)s, shipped value was \(expected)s")
            }
        }

        if problems.isEmpty {
            print("live lookups: ✅ every recipe input/output, loot id, scroll, starter recipe and starter weapon resolves through the façades")
            print("plot sweeper: ✅ derivation reproduces both shipped cadences (60s → 60s, 3600s → 300s)")
        } else {
            print("live lookups: ❌ \(problems.count) problem(s)")
            for problem in problems.prefix(10) { print("   • \(problem)") }
        }
        print("")
    }

    /// Phase 6 acceptance: does the item budget, spent through the class
    /// profiles, actually build the character the design table describes?
    ///
    /// This is the check Phase 5 could not make. Its combat-model check proved
    /// that published stats produce published percentages; it could say nothing
    /// about where those stats come from, because the reference warrior's DEF
    /// 225 is 52 from levels and 173 from gear that did not exist yet.
    ///
    /// The two accessory slots are deliberately empty — no accessory has been
    /// authored — so the kit is short by their 1.0 of slot weight. The residual
    /// is printed rather than hidden: it IS the quantified value of the three
    /// unfilled slots, and it should close in Phase 10, not before.
    private static func referenceCharacterCheck() {
        // The warrior row was REBASED in Phase 8C, when the simulator measured
        // the classes 17% apart on days-to-cap and the fix was to re-spend the
        // warrior's budget toward offence (weapon attack 0.72 → 0.80, armour
        // defence 0.82 → 0.78, base attack 10 → 12). Its published numbers moved
        // with the profile, by intent. The archer and mage rows are UNTOUCHED
        // and are what keeps this check honest: a later edit that moves them is
        // still caught, and the warrior's own row still catches an accidental
        // drift away from the new intent.
        let design: [(CharacterClass, Int, hp: Int, atk: Double, def: Int, mit: Double)] = [
            (.warrior, 40, hp: 653, atk: 126.0, def: 217, mit: 37.1),
            (.archer,  40, hp: 442, atk: 128.4, def: 136, mit: 27.0),
            (.mage,    40, hp: 558, atk: 131.7, def:  99, mit: 21.2),
        ]
        print("reference character (level gear, common, accessories empty):")
        print("      class     HP           ATK          DEF          absorb")
        var worstShortfall = 0.0
        for row in design {
            let base = User.baseStats(for: row.0, at: row.1)
            let gear = ItemBudget.referenceGear(for: row.0, itemLevel: row.1)
            let hp = base.maxHp + gear.hp
            let atk = Double(base.attack + gear.attack)
            let def = base.defense + gear.defense
            let mit = CombatService.mitigation(defenderDEF: def, defenderLevel: row.1) * 100
            func gap(_ got: Double, _ want: Double) -> String {
                let delta = (got - want) / want * 100
                worstShortfall = Swift.max(worstShortfall, abs(delta))
                return String(format: "%+.0f%%", delta)
            }
            print("      \(row.0.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0))"
                  + "\(hp)/\(row.hp) \(gap(Double(hp), Double(row.hp)).padding(toLength: 6, withPad: " ", startingAt: 0))"
                  + " \(String(format: "%.1f", atk))/\(row.atk) \(gap(atk, row.atk).padding(toLength: 5, withPad: " ", startingAt: 0))"
                  + " \(def)/\(row.def) \(gap(Double(def), Double(row.def)).padding(toLength: 6, withPad: " ", startingAt: 0))"
                  + " \(String(format: "%.1f", mit))%/\(row.mit)% \(gap(mit, row.mit))")
        }
        // DEF and absorption are load-bearing and must land: they are produced
        // entirely by the four armour slots and the off-hand, all of which are
        // populated. HP and ATK are allowed to run short because the accessory
        // slots are not.
        let defExact = design.allSatisfy { row in
            let d = User.baseStats(for: row.0, at: row.1).defense
                + ItemBudget.referenceGear(for: row.0, itemLevel: row.1).defense
            return abs(Double(d - row.def) / Double(row.def)) < 0.02
        }
        print(defExact
              ? "      ✅ DEF and absorption reproduce the design exactly; the residual gap is the two empty accessory slots"
              : "      ❌ DEF does not reproduce the design — the armour profiles or slot weights have drifted")
        print("")
    }

    /// Acceptance check for the Phase 5C combat model against the anchors the
    /// design published.
    ///
    /// It cannot verify BALANCE — the plan's reference character carries gear
    /// from an item budget curve that does not exist until Phase 6, which is
    /// why its level-40 warrior shows DEF 225 where the bare stat line gives 52.
    /// What it can verify, and does, is that feeding the published stat values
    /// through the implemented formula returns the published percentages. Five
    /// of those pairs pin the mitigation curve exactly, and the warrior's dodge
    /// pins a rating curve end to end, because the warrior is the one build
    /// that wears no dodge.
    ///
    /// Printed rather than hashed: a number that drifts is worth seeing as a
    /// number, not as a changed digest.
    private static func combatModelCheck() {
        var problems: [String] = []

        func near(_ got: Double, _ want: Double, _ tolerance: Double, _ label: String) {
            if abs(got - want) > tolerance {
                problems.append("\(label): got \(String(format: "%.2f", got)), design says \(want)")
            }
        }

        // Mitigation — the five (DEF, level) pairs printed in the design table.
        for (def, level, want) in [(12, 1, 18.0), (6, 1, 9.9), (225, 40, 38.0),
                                   (136, 40, 27.0), (99, 40, 21.2)] {
            near(CombatService.mitigation(defenderDEF: def, defenderLevel: level) * 100,
                 want, 0.15, "mitigation(DEF \(def) @ L\(level))")
        }
        // Dodge — the warrior line, the only one free of gear contribution.
        for (rating, level, want) in [(5.0, 1, 5.3), (5.0 * (1 + 0.085 * 19), 20, 5.5),
                                      (5.0 * (1 + 0.085 * 39), 40, 5.6)] {
            near(CombatService.dodgePercent(rating: Int(rating.rounded()), level: level),
                 want, 0.15, "warrior dodge @ L\(level)")
        }
        // Nobody may become immune, however much DEF they stack.
        let cap = Catalogs.current.tuningCombat.curves.mitigation.cap
        near(CombatService.mitigation(defenderDEF: 1_000_000, defenderLevel: 1) , cap, 0.001,
             "mitigation cap")

        // levelDiff: neutral at parity, clamped at both ends.
        let diff = Catalogs.current.tuningCombat.levelDiff
        near(CombatService.levelDiffMultiplier(attackerLevel: 10, defenderLevel: 10), 1.0, 0.001,
             "levelDiff at parity")
        near(CombatService.levelDiffMultiplier(attackerLevel: 1, defenderLevel: 99), diff.min, 0.001,
             "levelDiff floor")
        near(CombatService.levelDiffMultiplier(attackerLevel: 99, defenderLevel: 1), diff.max, 0.001,
             "levelDiff ceiling")

        // XP curve — the design's published costs at four levels.
        for (level, want) in [(2, 120.0), (6, 2309.0), (11, 22746.0), (21, 224029.0)] {
            let got = Double(User.xpRequiredToReach(level))
            // 0.5% — the design table rounded its exponent for print.
            if abs(got - want) / want > 0.005 {
                problems.append("xpToNext(L\(level - 1)): got \(Int(got)), design says \(Int(want))")
            }
        }
        // Out-levelling must cost XP, and never below the floor.
        let xpGap = Catalogs.current.tuningProgression.xpLevelDiff
        near(User.xpMultiplier(playerLevel: 10, monsterLevel: 10), 1.0, 0.001, "xp parity")
        near(User.xpMultiplier(playerLevel: 40, monsterLevel: 1), xpGap.min, 0.001, "xp floor")

        if problems.isEmpty {
            print("combat model: ✅ mitigation, dodge, levelDiff and the XP curve all reproduce the design anchors")
        } else {
            print("combat model: ❌ \(problems.count) mismatch(es)")
            for problem in problems { print("   • \(problem)") }
        }
        print("")
    }

    // MARK: - Phase 4 tuning fingerprint
    //
    // The FOURTH half, captured while every constant below is still a Swift
    // literal (step 1 of the migration loop). Deliberately a separate hash
    // rather than more entries in `records`: Phase 4 must leave the catalogs
    // untouched, and the only way to *prove* that is to keep `records`,
    // `spawns` and `quests` comparable to the values batch C signed off on.
    //
    // Two kinds of entry, and the split is the whole point:
    //
    //   • **Scalars** are hashed directly. This phase changes where the number
    //     comes from, not the formula that consumes it, so fingerprinting the
    //     value is a complete check for them.
    //   • **Accessor replays** cover every `switch` that becomes a table
    //     lookup. A value hash cannot see a rewritten body, and each of these
    //     bodies IS rewritten. They are replayed PAST the live domain —
    //     negative tiers, levels above the cap, unknown ids, an empty string —
    //     because the out-of-range tail is exactly where a clamp or a
    //     `?? first` fallback stops agreeing.
    //
    // Every set is walked sorted and every enum via `allCases`: a `Set<Int>`
    // iterates in seeded-hash order, so hashing `statGrowthLevels` directly
    // would produce a digest that differs between processes and quietly
    // destroy the comparison (the batch-C dictionary lesson, one type over).
    private static func tuningFingerprint() -> String {
        var d = OutcomeDigest()

        // MARK: combat.json — scalars
        d.combine("combat")
        d.combine(CombatService.baseHitChance)
        d.combine(CombatService.minHitChance)
        d.combine(CombatService.maxHitChance)
        d.combine("\(CombatService.critMultiplier)")
        d.combine("\(CombatService.varianceRange.lowerBound)...\(CombatService.varianceRange.upperBound)")
        d.combine("\(CombatService.defendChipFraction)")
        d.combine(CombatService.stanceDurationRounds)
        d.combine(CombatService.trainingDummyEnemyId)
        d.combine(CombatService.SpecialAttack.cleaveVigor)
        d.combine(CombatService.SpecialAttack.vitalShotVigor)
        d.combine(CombatService.SpecialAttack.soulfireVigor)
        d.combine(CombatService.SpecialDefense.ironBulwarkVigor)
        d.combine(CombatService.SpecialDefense.shadowVeilVigor)
        d.combine(CombatService.SpecialDefense.mirrorWardVigor)
        d.combine("\(CombatService.SpecialDefense.ironBulwarkChipFraction)")
        d.combine(CombatService.SpecialDefense.shadowVeilDodgeBonus)
        d.combine("\(CombatService.SpecialDefense.mirrorWardReflectFraction)")
        d.combine(CombatService.SpecialDefense.effectPersistRounds)
        d.combine(CombatService.Flee.warriorChance)
        d.combine(CombatService.Flee.archerChance)
        d.combine(CombatService.Flee.mageChance)
        d.combine(CombatService.Flee.mageVigorExtra)
        d.combine("\(CombatService.Defend.archerChipMultiplier)")
        d.combine(CombatService.Defend.archerDodgeBonus)
        d.combine("\(CombatService.Defend.mageBarrierDamageFraction)")

        // The curves, replayed through the live accessors rather than hashed as
        // constants: a `kBase`/`kPerLevel` pair only means something once it has
        // been through the formula, and the mitigation curve's `cap` is a
        // ceiling where the other three carry a leading scale — a distinction a
        // raw constant hash cannot express.
        for level in [1, 20, 40] {
            for rating in [0, 5, 50, 500] {
                d.combine("mit@\(level)/\(rating):\(CombatService.mitigation(defenderDEF: rating, defenderLevel: level))")
                d.combine("dodge@\(level)/\(rating):\(CombatService.dodgePercent(rating: rating, level: level))")
                d.combine("crit@\(level)/\(rating):\(CombatService.critPercent(rating: rating, level: level))")
                d.combine("acc@\(level)/\(rating):\(CombatService.accuracyPercent(rating: rating, level: level))")
            }
        }
        // Replayed past both clamps — the tails are where a changed bound hides.
        for gap in [-60, -10, 0, 10, 60] {
            d.combine("levelDiff\(gap):\(CombatService.levelDiffMultiplier(attackerLevel: 20 + gap, defenderLevel: 20))")
        }

        // MARK: combat.json — accessor replays
        //
        // `initialUses` is replayed to L25 rather than to `maxLevel`: the
        // thresholds are 17 / 20 / 21, and 21 is the cap today. Running past it
        // pins the "at or above" comparison so raising `maxLevel` to 40 in
        // Phase 5 shows up as a deliberate digest move.
        for kind in CombatService.TechniqueKind.allCases {
            d.combine(kind.rawValue)
            d.combine(CombatService.requiredLevel(for: kind))
            for level in 1...25 { d.combine(CombatService.initialUses(for: kind, playerLevel: level)) }
        }
        for stanceId in [CombatService.StanceId.bloodlust, CombatService.StanceId.hawksEye,
                         CombatService.StanceId.arcaneResonance, "nope", ""] {
            d.combine(stanceId)
            d.combine(CombatService.stanceActivationVigor(for: stanceId))
            d.combine(fingerprint(CombatService.stanceModifiers(for: stanceId)))
        }
        // nil is a separate arm from an unknown id — callers pass the stored
        // `combat_stance` column straight through, and it is nil far more often
        // than it is wrong.
        d.combine(fingerprint(CombatService.stanceModifiers(for: nil)))
        for cls in CharacterClass.allCases {
            d.combine(cls.rawValue)
            d.combine(CombatService.stanceId(forClass: cls))
            d.combine(CombatService.specialAttackVigor(forClass: cls))
            d.combine(fingerprint(CombatService.specialAttackModifiers(forClass: cls)))
            d.combine("\(CombatService.specialAttackZeroesDodge(forClass: cls))")
            d.combine(fingerprint(CombatService.specialAttackEffect(forClass: cls)))
            d.combine(CombatService.specialDefenseVigor(forClass: cls))
            d.combine(CombatService.fleeChance(forClass: cls))
            d.combine(CombatService.fleeVigorExtra(forClass: cls))
        }

        // MARK: vigor.json
        d.combine("vigor")
        d.combine(VigorService.drainWalkRoom)
        d.combine(VigorService.drainWalkRoomDoubleSpeed)
        d.combine(VigorService.drainCombatRound)
        d.combine(VigorService.drainCombatAttack)
        d.combine(VigorService.drainCombatDefend)
        d.combine(VigorService.drainCombatFlee)
        d.combine("\(VigorService.starvationStatPenalty)")
        d.combine("\(VigorService.starvationHPDrainPercent)")
        for action in VigorAction.allCases {
            d.combine(action.rawValue)
            d.combine(VigorService.cost(of: action))
        }
        d.combine("\(Catalogs.current.tuningProgression.vigorPool.fullRegenHours)")
        d.combine("\(HealingService.regenPerMinute)")
        d.combine("\(HealingService.maxIdleMinutes)")

        // MARK: exploration.json
        d.combine("exploration")
        d.combine(ExplorationService.weightTotal)
        d.combine("\(ExplorationService.tripDamagePercent)")
        // −2 and −1 matter: the tier arm is a `default`, so a negative visit
        // count resolves to BARE today. A table keyed 0/1/2 would return nil
        // there instead, and nothing else in the digest would notice.
        for priorVisits in -2...5 {
            d.combine(fingerprint(ExplorationService.weights(forPriorVisits: priorVisits)))
        }
        // The passive discounts. Nothing else reaches them — they are applied
        // once, deep inside `finalizeAndPush`, so only a direct hash notices a
        // change to the ratio that keeps unattended play below active play.
        let passive = ExplorationService.passiveTuning
        d.combine("passive xp\(passive.xpMultiplier) "
                  + "loot\(passive.lootMultiplier) fresh\(passive.freshStepCount)")

        // MARK: progression.json
        d.combine("progression")
        d.combine(User.maxLevel)
        // Growth is a FUNCTION of level now, so the replay walks the whole
        // ladder instead of hashing three flat constants and a set of levels.
        // This is the half that would catch a rate whose decimal point moved:
        // the level-1 line is unchanged by construction, and only the shape
        // above it moves.
        for cls in CharacterClass.allCases {
            for level in [1, 2, 5, 10, 21, 40] {
                let s = User.baseStats(for: cls, at: level)
                d.combine("\(cls.rawValue)@\(level) hp\(s.maxHp) atk\(s.attack) def\(s.defense) crit\(s.crit) dodge\(s.dodge) acc\(s.accuracy)")
            }
        }
        for level in [0, 1, 21, 40] { d.combine(User.maxVigor(at: level)) }
        // Replayed past the cap on both ends: `xpRequiredToReach` returns
        // `Int.max` outside 2...maxLevel, and that guard is as much a part of
        // the curve as the 100 / ×2 / ×1.4 constants inside it.
        for level in 0...45 { d.combine(User.xpRequiredToReach(level)) }
        // `mobXP` is design-time input — every enemy's `xpReward` was baked from
        // it — but it lives in the tuning and is solved as a pair with the curve
        // above, so it is hashed beside it.
        let mobXP = Catalogs.current.tuningProgression.mobXP
        d.combine("mobXP \(mobXP.coefficient)^\(mobXP.exponent)")
        // The level-gap scaling, replayed across both clamps.
        for gap in [-20, -5, 0, 5, 20] {
            d.combine("xpGap\(gap):\(User.xpMultiplier(playerLevel: 20 + gap, monsterLevel: 20))")
        }
        for cls in CharacterClass.allCases {
            let s = cls.startingStats
            d.combine("\(cls.rawValue) hp\(s.hp) atk\(s.attack) def\(s.defense) crit\(s.crit) dodge\(s.dodge) acc\(s.accuracy)")
            d.combine(cls.starterWeaponId)
        }
        for estateLevel in -2...12 { d.combine(WarehouseService.capForLevel(estateLevel)) }

        // MARK: economy.json
        d.combine("economy")
        d.combine(GearConditionService.maxDurabilityStart)
        d.combine(GearConditionService.repairMaxShave)
        for event in GearConditionService.WearEvent.allCases {
            d.combine(event.rawValue)
            d.combine(event.amount)
        }
        // Not moving to JSON — these must stay in lockstep with `EquipmentSlot`
        // — but hashed so that stays a decision rather than an oversight.
        for slot in GearConditionService.durableSlots.sorted() { d.combine(slot) }
        for slot in GearConditionService.armorSlots.sorted() { d.combine(slot) }

        // MARK: time.json
        //
        // Split the way the file will be: `gameTime` is everything `time.scale`
        // multiplies, `realTime` is everything it must NOT touch. Telegram's
        // 24 h floor on deleting a dice message is the sharpest example — it is
        // a protocol constant, and scaling it would break the tavern sweep
        // rather than merely rebalance it.
        //
        // Only DERIVED durations are hashed, never the `testMode` flags that
        // feed them. That is what makes Phase 4b — collapsing three booleans
        // into one `time.scale` — a provable no-op: the inputs change shape
        // entirely while every wall-clock duration the player experiences has
        // to come out bit-identical.
        d.combine("time.gameTime")
        d.combine(TravelService.travelMinutes)
        d.combine("\(TravelService.travelSeconds)")
        d.combine(PassiveExpeditionService.unitsPerStep)
        d.combine("\(PassiveExpeditionService.secondsPerUnit)")
        d.combine("\(PassiveExpeditionService.stepDurationSeconds)")
        d.combine("\(PlotCatalog.intervalSeconds)")
        d.combine("\(PlotProductionService.tickInterval)")
        d.combine("time.realTime")
        d.combine("\(TradeStore.lobbyTTL)")
        d.combine("\(TradeStore.sessionTTL)")
        d.combine("\(TradeStore.sweepInterval)")
        d.combine("\(TavernCleanupService.deletableAfter)")
        d.combine("\(TavernCleanupService.sweepInterval)")
        d.combine(GameDay.rolloverHour)
        d.combine(GameDay.timeZoneID)
        // Replay `stamp` through the real function rather than trusting the two
        // constants above. The instants straddle the 12:00 Kyiv boundary, a DST
        // change and a year end — the three places an arithmetic shortcut
        // would disagree with the calendar search the implementation uses.
        for epoch in [1_756_000_000.0, 1_756_040_000.0, 1_761_000_000.0,
                      1_767_225_600.0, 1_772_000_000.0] {
            let date = Date(timeIntervalSince1970: epoch)
            d.combine(GameDay.stamp(date))
            d.combine(GameDay.secondsUntilNextRollover(from: date))
        }

        return d.hexDigest
    }

    private static func fingerprint(_ m: CombatService.StanceModifiers) -> String {
        "atk×\(m.attackMultiplier) def×\(m.defenseMultiplier) crit×\(m.critMultiplier) "
            + "acc×\(m.accuracyMultiplier) dodge×\(m.dodgeMultiplier) vigor×\(m.vigorMultiplier)"
    }

    private static func fingerprint(_ m: CombatService.AttackModifiers) -> String {
        "hit\(m.hitChanceModifier) crit+\(m.critBonus) "
            + "cannotMiss:\(m.cannotMiss) flat+\(m.flatDamageBonus) "
            + "critMult:\(m.critMultiplierOverride.map { "\($0)" } ?? "-")"
    }

    /// The Phase 5D technique effects. Hashed SEPARATELY from the roll
    /// modifiers because they do not travel through `AttackModifiers` at all —
    /// the controller reads them and mutates round state. Without this,
    /// doubling a burn's duration or halving an armour break would leave the
    /// digest byte-identical, which is exactly the silent balance drift the
    /// whole layer exists to catch.
    private static func fingerprint(_ effect: SpecialAttackEffectDTO) -> String {
        switch effect {
        case .armourBreak(let rounds):
            return "armour_break:\(rounds)"
        case .guaranteedCrit(let multiplier):
            return "guaranteed_crit:\(multiplier)"
        case .burn(let rounds, let fraction):
            return "burn:\(rounds)x\(fraction)"
        }
    }

    private static func fingerprint(_ w: ExplorationService.EventWeights) -> String {
        "n\(w.nothing)/l\(w.loot)/e\(w.encounter)/t\(w.trip)"
    }

    // MARK: - Field-complete fingerprints
    //
    // When a domain type gains a stored property, extend the matching
    // fingerprint in the same edit — an omission silently weakens the check.
    // (These were shared with `ContentExporter`'s layer-0 equivalence pass
    // until Phase 3 ended and that file was deleted with the last Swift array.)

    /// Deterministic UUID from the seeded generator. `QuestCatalog.daily`
    /// hashes `userId.uuidString`, so the replay needs stable ids that do not
    /// come from `UUID()`.
    private static func seededUUID(_ rng: inout SplitMix64) -> UUID {
        let hex = Array(String(format: "%016llx%016llx", rng.next(), rng.next()))
        let text = String(hex[0..<8]) + "-" + String(hex[8..<12]) + "-" + String(hex[12..<16])
            + "-" + String(hex[16..<20]) + "-" + String(hex[20..<32])
        // Non-optional by construction: 32 hex digits in the 8-4-4-4-12 shape
        // always parse. Falling back to a fixed id rather than `UUID()` keeps
        // the digest reproducible even if that ever stops being true.
        return UUID(uuidString: text) ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }

    private static func fingerprint(_ step: MasterCatalog.EnchantStep) -> String {
        "t\(step.level) silver\(step.silver) \(step.materialId)x\(step.materialQty)"
    }

    private static func fingerprint(_ tuning: PlotTuning) -> String {
        let bonus = tuning.bonusOutput.map {
            "\($0.producedItemId)@\($0.ratePerInterval)/cap\($0.capacity)"
        } ?? "-"
        return "\(tuning.producedItemId)@\(tuning.ratePerInterval)/cap\(tuning.capacity) bonus[\(bonus)]"
    }

    private static func fingerprint(_ card: FortuneCard) -> String {
        let e = card.effect
        return [
            card.id, card.nameKey, card.meaningKey, card.buffDescKey,
            "\(e.attackBonus)/\(e.defenseBonus)/\(e.critBonus)/\(e.dodgeBonus)/\(e.accuracyBonus)",
            "\(e.xpMultiplier)/\(e.lootChanceMultiplier)/\(e.vigorDrainMultiplier)",
            "\(e.oneShotSilver)/\(e.oneShotXpGain)/\(e.oneShotHpRestore)/\(e.oneShotVigorRestore)",
            "\(e.randomSilverPositive)/\(e.randomSilverNegative)",
            // Derived, not stored — a field added to `FortuneEffect` and left
            // out of `hasDurationEffect` would show up here and nowhere else.
            "duration:\(e.hasDurationEffect)"
        ].joined(separator: " · ")
    }

    private static func fingerprint(_ def: QuestDef) -> String {
        let objective: String
        switch def.objective {
        case .deliver(let itemIds, let count):
            objective = "deliver:\(itemIds.joined(separator: "|"))x\(count)"
        case .counter(let counter, let target):
            objective = "counter:\(counter.rawValue)x\(target)"
        }
        return [
            def.id, def.npc.rawValue, objective, "target\(def.objective.target)",
            "silver\(def.reward.silver)/xp\(def.reward.xp)/vigor\(def.reward.vigor)",
            def.titleKey, def.descKey
        ].joined(separator: " · ")
    }

    private static func fingerprint(_ step: BagUpgradeStep) -> String {
        let inputs = step.inputs.map { "\($0.itemId)x\($0.quantity)" }.joined(separator: "|")
        return "t\(step.toTier) cap\(step.capacity) estate\(step.requiredEstateLevel) \(inputs)"
    }

    private static func fingerprint(_ step: EstateUpgradeStep) -> String {
        let inputs = step.inputs.map { "\($0.itemId)x\($0.quantity)" }.joined(separator: "|")
        return "t\(step.toTier) lvl\(step.requiredPlayerLevel) silver\(step.silverCost) \(inputs)"
    }

    private static func fingerprint(_ item: Item) -> String {
        let effects = item.effects.map { effect -> String in
            switch effect {
            case .restoreVigor(let amount): return "vigor:\(amount)"
            case .restoreHP(let amount):    return "hp:\(amount)"
            }
        }.joined(separator: "|")
        let gear = item.gearStats.map {
            "\($0.attack)/\($0.defense)/\($0.hp)/\($0.crit)/\($0.dodge)/\($0.accuracy)"
        } ?? "-"
        return [
            item.id, item.nameKey, item.type.rawValue, "\(item.tier)",
            "iLvl\(item.itemLevel)", item.rarity, item.setId ?? "-", "\(item.stackable)",
            effects, item.slot?.rawValue ?? "-", gear, item.icon ?? "-",
            item.descriptionKey ?? "-", item.teachesRecipe ?? "-"
        ].joined(separator: " · ")
    }

    private static func fingerprint(_ enemy: Enemy) -> String {
        let loot = enemy.lootTable
            .map { "\($0.itemId)@\($0.chance)x\($0.quantity)" }
            .joined(separator: "|")
        return [
            enemy.id, enemy.nameKey, "\(enemy.tier)", "\(enemy.hp)", "\(enemy.attack)",
            "\(enemy.defense)", "\(enemy.crit)/\(enemy.dodge)/\(enemy.accuracy)",
            "L\(enemy.level)", enemy.archetype.rawValue,
            "weight\(enemy.spawnWeight)",
            "\(enemy.depthRange.lowerBound)...\(enemy.depthRange.upperBound)",
            loot, enemy.icon, "\(enemy.xpReward)"
        ].joined(separator: " · ")
    }

    private static func fingerprint(_ recipe: Recipe) -> String {
        let inputs = recipe.inputs.map { "\($0.itemId)x\($0.quantity)" }.joined(separator: "|")
        return [
            recipe.id, recipe.category.rawValue, inputs,
            "\(recipe.output.itemId)x\(recipe.output.quantity)"
        ].joined(separator: " · ")
    }
}
