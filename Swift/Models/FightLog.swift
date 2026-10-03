//
//  FightLog.swift
//  RestOfIryna
//
//  Created by Dmytro Ihnatyuhin on 27.09.2026.
//
//  One row per finished fight in the forest — won, died or fled — so the
//  techniques can be judged on live fights rather than argued about. The owner
//  asked to see "the technique logs in the database" on 2026-09-27 and there
//  were none: nothing a fight did left a trace anywhere, not in a table and not
//  in the pm2 log.
//
//  A fight spans many taps, so its numbers are gathered on the expedition row
//  as it goes (`CombatTally`, JSON in `exploration_state.combat_tally`) and
//  written here once, when it ends. Not recorded: training bouts and the
//  registration dog (neither is a fight with anything at stake) and the
//  passive autobattle, which uses no techniques at all.
//
//  `enemy_id` is HISTORY, not a live reference. A row about a beast a later
//  bundle retires records a fight that happened, and refusing a reload over it
//  would freeze the bestiary forever — so `LiveReferenceQuery` does not read
//  this table, on purpose.
//

import Fluent
import Foundation

/// What dealt a blow. The raw values are the vocabulary of the log's
/// `max_blow_source` and `killing_blow` columns.
public enum FightBlowSource: String, Codable, Sendable {
    /// A plain attack.
    case attack
    /// The class Defend's chip.
    case defend
    case specialAtk = "special_atk"
    case specialDef = "special_def"
    /// The stance's own strike — raising a stance swings since 2026-09-27.
    case stance
    case burn
}

/// The running numbers of one fight. Lives on the expedition row between taps
/// and becomes a `FightLog` row when the fight ends.
///
/// The synthesized decoder wants every key, so a field added here makes the
/// tallies of fights in flight across that deploy undecodable — they read nil
/// and leave no row, which is the harmless way for it to fail.
public struct CombatTally: Codable, Sendable, Equatable {
    public var hpStart: Int
    /// Player actions taken — the stance's strike and every escape attempt,
    /// the one that got away included.
    public var actions = 0
    public var vigorSpent = 0
    public var damageDealt = 0
    public var maxBlow = 0
    public var maxBlowSource: FightBlowSource?
    public var killingBlow: FightBlowSource?
    public var specialAtkUses = 0
    public var specialAtkDamage = 0
    public var specialDefUses = 0
    public var specialDefDamage = 0
    public var stanceUses = 0
    /// Everything dealt while a stance was up, its own strike included.
    public var stanceDamage = 0
    public var burnDamage = 0

    public init(hpStart: Int) {
        self.hpStart = hpStart
    }

    /// Count one blow the player dealt. `blow` is what it rolled, and the
    /// biggest-blow record keeps that, overkill and all — it is the number the
    /// one-tap question is about. `removed` is the HP it actually took, and
    /// every sum counts that instead, so a finishing blow's overkill inflates
    /// no column and a won fight's total is exactly the beast's HP.
    public mutating func dealt(_ blow: Int, removed: Int, by source: FightBlowSource, inStance: Bool) {
        if blow > maxBlow {
            maxBlow = blow
            maxBlowSource = source
        }
        guard removed > 0 else { return }
        damageDealt += removed
        switch source {
        case .specialAtk: specialAtkDamage += removed
        case .specialDef: specialDefDamage += removed
        case .burn:       burnDamage += removed
        case .attack, .defend, .stance: break
        }
        if inStance { stanceDamage += removed }
    }
}

final public class FightLog: Model, @unchecked Sendable {
    public static let schema = "fight_log"

    public enum Outcome: String, Sendable {
        case win, death, flee
    }

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    /// The player's name when the fight happened — the log is read in Postico,
    /// where a bare user id says nothing.
    @OptionalField(key: "nickname")
    public var nickname: String?

    @Field(key: "character_class")
    public var characterClass: String

    @Field(key: "player_level")
    public var playerLevel: Int

    @Field(key: "depth_km")
    public var depthKm: Int

    @Field(key: "enemy_id")
    public var enemyId: String

    @Field(key: "enemy_level")
    public var enemyLevel: Int

    /// The player's estate tier when the fight happened — the input of the
    /// forest's strength (`spec-bestiary.md` §11), and the only record of it:
    /// `users.estate_level` moves on, and a player holding an upgrade back to
    /// keep the forest soft is exactly what this column has to show. Nil on
    /// rows written before the scaling shipped (`AddFightLogEstateLevel`),
    /// whose fights were unscaled whatever the tier was.
    @OptionalField(key: "estate_level")
    public var estateLevel: Int?

    /// `Outcome.rawValue` — win / death / flee.
    @Field(key: "outcome")
    public var outcome: String

    @Field(key: "rounds")
    public var rounds: Int

    @Field(key: "vigor_spent")
    public var vigorSpent: Int

    @Field(key: "hp_start")
    public var hpStart: Int

    @Field(key: "hp_end")
    public var hpEnd: Int

    /// HP actually removed, overkill excluded — on a won fight, exactly the
    /// beast's HP. The per-technique damage columns count the same way.
    @Field(key: "damage_dealt")
    public var damageDealt: Int

    /// The biggest single blow the player dealt, as ROLLED — overkill kept,
    /// because it is the number the one-tap question of 2026-09-27 was about.
    @Field(key: "max_blow")
    public var maxBlow: Int

    @OptionalField(key: "max_blow_source")
    public var maxBlowSource: String?

    /// What finished the beast. Nil unless the fight was won.
    @OptionalField(key: "killing_blow")
    public var killingBlow: String?

    @Field(key: "special_atk_uses")
    public var specialAtkUses: Int

    @Field(key: "special_atk_damage")
    public var specialAtkDamage: Int

    @Field(key: "special_def_uses")
    public var specialDefUses: Int

    @Field(key: "special_def_damage")
    public var specialDefDamage: Int

    @Field(key: "stance_uses")
    public var stanceUses: Int

    @Field(key: "stance_damage")
    public var stanceDamage: Int

    @Field(key: "burn_damage")
    public var burnDamage: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}
}

extension FightLog {
    /// Write the fight that just ended, from the tally on its expedition row.
    ///
    /// Callers use `try?`, the way `QuestService.record` is called: a log row
    /// must never be the reason a victory, a death or an escape fails to land.
    /// A fight with no tally — one already in flight when AddCombatTally
    /// shipped — leaves no row rather than a row of zeros.
    public static func record(_ outcome: Outcome, state: ExplorationState, enemy: Enemy,
                              user: User, on db: any Database) async throws {
        guard let userId = user.id, let tally = state.combatTally else { return }
        let row = FightLog()
        row.$user.id = userId
        row.nickname = user.nickname
        row.characterClass = user.characterClass ?? ""
        row.playerLevel = user.level
        row.depthKm = state.stepsDeep
        row.enemyId = enemy.id
        row.enemyLevel = enemy.level
        // The tier the fight was rolled at: nothing can raise the estate while
        // the expedition row stands (`ExplorationState.combatEnemy(for:)`).
        row.estateLevel = user.estateLevel
        row.outcome = outcome.rawValue
        row.rounds = tally.actions
        row.vigorSpent = tally.vigorSpent
        row.hpStart = tally.hpStart
        row.hpEnd = user.hp
        row.damageDealt = tally.damageDealt
        row.maxBlow = tally.maxBlow
        row.maxBlowSource = tally.maxBlowSource?.rawValue
        row.killingBlow = outcome == .win ? tally.killingBlow?.rawValue : nil
        row.specialAtkUses = tally.specialAtkUses
        row.specialAtkDamage = tally.specialAtkDamage
        row.specialDefUses = tally.specialDefUses
        row.specialDefDamage = tally.specialDefDamage
        row.stanceUses = tally.stanceUses
        row.stanceDamage = tally.stanceDamage
        row.burnDamage = tally.burnDamage
        try await row.save(on: db)
    }
}
