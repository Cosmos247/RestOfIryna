# Content Pipeline (data-driven catalogs)

How game content is stored, loaded, validated and extended. Introduced by the
pre-release rebalance (see [rebalance.md](rebalance.md)).

## Why it exists

Every catalog used to be a static Swift array compiled into the binary, so any
balance change meant a rebuild and a redeploy. Content now lives in
`content/data/*.json` and the Swift catalogs are thin façades over a validated
snapshot.

## Targets

```
Modules/ROIContent    library, Foundation ONLY   DTOs · loader · validator · GameData snapshot · LocaleIndex
Modules/ROISim        library → ROIContent       the combat/progression/budget MATHS + the simulator
Modules/roi-content   executable                 CLI: validate · simulate
Tests/ROIContentTests                            222 tests; fast because no Fluent/Postgres/Telegram
Swift/                executable                 the bot; carries @_exported import ROIContent / ROISim
```

`Modules/`, not `Sources/` — `CLAUDE.md` states game code lives in `Swift/`, and
a `Sources/` directory would contradict that.

**`roi-content spec <progression|gates|bestiary|items>`** (Phase 9) prints the
tables a content specification quotes, from the code that owns the maths —
`ProgressionMath`, `EnemyGenerator`, `BudgetMath`. A spec full of hand-typed
numbers would be a fourth transcription of the same curves; this way the document
and the generator it feeds cannot disagree, and the command is the seed of Phase
10's generator.

## Runtime shape

```
content/data/*.json
      ↓ ContentLoader.load      (decode, readable errors, FNV-1a content hash, NEVER sorts)
   ContentBundle                 DTOs, not yet validated
      ↓ ContentValidator         identity · enums · references · localization · ladders · timeScale
   GameContent  (DTO snapshot)   → GameData.install
   DomainContent (domain snapshot) → Catalogs.install
      ↑
  ALL 13 catalogs — Item · Enemy · Recipe · WeaponUpgrade · Bag · EstateUpgrade · Zone (8E)
  Trader · Tavern · Market · Guild · Arena · Master · Plot · Fortune · Quest
  — every one reads Catalogs.current
```

`content/data/` holds 17 files: `manifest · items · enemies · recipes ·
weapon_upgrades · bags · estate_upgrades · trader · tavern · market · guild ·
arena · master · plots · fortune · quests · zones`. **No Swift catalog array
remains** (Phase 3 closed 2026-08-29; `zones.json` was the last holdout, two
arrays inside `ExplorationService.rollLoot` that Phase 8E pulled out when
foraging became part of the food economy), so `ContentExporter` and
`--export-content` are gone. `ContentDigest` stays — it is the "confirm only the intended change" step
of the add-content workflow, not a migration leftover.

**Two snapshots on purpose.** The domain types (`Item`, `Enemy`, …) still live in
the main target, so `ROIContent` can only hold DTOs. Mapping DTO → domain on
every `find()` would allocate inside combat loops, so it happens once in
`DomainContent`. `ContentBootstrap.load` is the ONLY installer of either and
installs both from one bundle, so they cannot drift.

**Holders** use `nonisolated(unsafe)` + `NSLock`, not `Synchronization.Mutex`
(macOS 15, package targets 14) and not `@TaskLocal` (task-locals do not cross
`Task.detached`, and six long-lived detached tasks read catalogs). The façade
accessors must stay synchronous, non-throwing and nonisolated — ~315 call sites
read them from `Sendable` contexts.

**Boot order is load-bearing.** `ContentBootstrap.load` runs in `configure` right
after `Dotenv.configure` and BEFORE the database block: the dev-inventory seed
and `GearConditionService.backfillWeaponDurability` later in the same function
both touch a catalog, and `all` is a computed property that traps if read before
install. No `static let` anywhere may reference a catalog.

## Tuning tables (Phase 4)

`content/data/tuning/` holds six balance tables — the numbers the formulas
consume, as opposed to the rosters the player scrolls through. They decode by
rules of their own:

| File | Owns |
|---|---|
| `combat.json` | hit/crit/variance, technique gates, 3 stances, 3 special attacks, 3 special defenses, flee, per-class Defend, the training-dummy id |
| `vigor.json` | 7 action costs, starvation, idle HP regen |
| `exploration.json` | the three-tier revisit weight table, trip damage |
| `progression.json` | `maxLevel`, XP curve, stat-growth levels, per-class starting stats + starter weapon, warehouse caps |
| `economy.json` | durability start, repair shave, per-fight wear budget |
| `time.json` | `scale` + `gameTime` (scaled) + `realTime` (never scaled) |

- **Everything decodes as REQUIRED.** No `decodeIfPresent` anywhere in
  `TuningDTO.swift`. Optional-with-default is right for a record whose sub-field
  is genuinely absent and catastrophic for a constant — a missing
  `baseHitChance` silently becoming 0 is the drift the pipeline exists to stop.
  `vigor.drain.idle` is 0 and is stated anyway, because an absent key and a
  deliberate zero must not look alike.
- **Per-class rows are ARRAYS carrying an explicit `class`**, not objects. A
  JSON object decodes to `[String: T]`, where an absent `mage` reads as "the
  mage has no flee chance" rather than as an error. `DomainContent.init` then
  refuses a bundle missing any class from any of the five per-class tables,
  because those accessors are non-throwing and would otherwise have to invent a
  number.
- **`time.json` splits `gameTime` from `realTime`, and the split is load-bearing.**
  `time.scale` divides everything in `gameTime` and nothing in `realTime`.
  `tavernDeletableAfter` is the sharpest case: Telegram refuses to delete a
  private-chat dice message younger than 24 h, so scaling it would not rebalance
  the tavern — every delete would fail and the rows would never clear. The trade
  TTLs and the 12:00 rollover are the same kind of constant.
- **The plot sweeper is DERIVED, not stored**: `max(minSeconds, plotInterval /
  divisor)`. The one property that matters is "never slower than what it
  sweeps", and deriving it makes that hold by construction. It is deliberately
  not a function of `scale` — it is a DB polling cadence, and scaling it would
  make database load a function of game balance.

## Item stat budget (Phase 6)

`budget(itemLevel, slot, rarity) = slotWeight · (base + perItemLevel · itemLevel) · rarityBudget`,
in `tuning/budget.json`. Every stat an item carries is that budget SPENT at the
exchange rates in the same file, so one number bounds a piece. The combat
denominators were derived from this curve, which is what makes adding items
forever safe: respect the budget and no stat's PERCENTAGE can drift.

- **The overspend rule carries an ABSOLUTE rounding slack**, not a percentage.
  Rounding a stat can only add half a point of it, so the error is a fixed
  number of points — a percentage tolerance would be far too tight on a level-1
  piece and far too loose on a level-40 one.
- **`itemLevel` is not `tier`.** Tier is a crafting-ladder position (1–5); item
  level is the budget input (1–40). The weapon ladder maps tiers to levels
  1/10/20/30/40, because five rungs cover forty levels.
- **Rarity decouples budget from value** (×1.45 against ×16 at the top). Tying
  them makes selling a legendary the largest silver faucet in the game.
- **Enchant is a percentage of the item's own budget**, never flat points: the
  same +32 DEF is 267% of a level-1 chest and 14% of a level-40 one.
- **Set bonuses are capped against their members' combined budget**, because a
  set bonus is a third power axis bought with slot freedom.
- **The reference-character check** in `--content-digest` rebuilds the design's
  published character from the budget. DEF and absorption land exactly; the
  residual HP gap is the two unspent accessory slots, printed rather than hidden.

## Bestiary and combat model (Phase 5)

`enemies.json` carries an `archetypes` table beside the roster: six rows of
design input (rounds-to-kill, HP loss per encounter, absorption / dodge / crit
targets, XP / loot / silver multipliers, default spawn weight). Every enemy's
stats are GENERATED from its level and archetype at design time, never scaled to
the player at runtime — runtime scaling makes each gear upgrade evaporate as it
is equipped.

- **`pickFor` returns nil past coverage.** The old `?? all.first` tail answered
  any uncovered km with the first enemy in the file, so everything past km 35 was
  a wild boar and the deepest zone was the easiest. `rollEncounter` already
  treated nil as "no encounter" — the call site had been written for the honest
  answer all along. A gap is now a validator finding.
- **Combat curves come in two shapes and they are separate TYPES.**
  `MitigationCurveDTO` is `min(cap, DEF/(DEF+K))` where `cap` is a CEILING;
  `RatingCurveDTO` is `scale·R/(R+K)` where `scale` is a leading coefficient.
  Reading one as the other inflates derived values by ~80%.
- **The `--content-digest` run prints four live checks** beside the hashes: the
  façade lookups, the plot-sweeper equivalence, `combat model` (which replays the
  design's published anchors — five mitigation pairs, the warrior dodge line, the
  levelDiff clamps, four XP-curve costs), and the reference character rebuilt from
  the item budget. They are printed rather than hashed because a number that has
  drifted is worth seeing as a number.
- **Phase 8 gave the tables a second reader.** `swift run roi-content simulate`
  rolls the SAME `CombatMath` the bot calls over levels × archetypes × classes ×
  profiles × gear offsets. Run it after touching `tuning/combat.json`,
  `tuning/progression.json`, `tuning/budget.json` or the archetype table: the
  digest says WHAT moved, the simulator says whether the move was survivable.
  `--strict` exits 1 on a broken band.

## Adding content

It is a data edit. There is no Swift array to touch.

1. Append to the right `content/data/*.json`.
2. Add locale keys to **both** `Localizations/en.json` and `uk.json`.
3. `swift run roi-content validate --strict` → must exit 0.
4. `swift run RestOfIryna --content-digest` → confirm only the intended change.
5. If a balance table moved, `swift run -c release roi-content simulate --strict`.

**Write JSON in the Swift `JSONEncoder` style** the files already use — two-space
indent, `"key" : value` WITH the space before the colon, keys sorted, empty array
as `[]`. A tool that re-emits them python-style reformats every line and buries
the real change in a 900-line diff. (It cannot move the digest — that hashes
values, not bytes — but it does move the bundle's content hash.)

Locale keys are **derived** unless overridden: `item.<id>`, `<nameKey>.desc`,
and an enemy's key is its own id. A tiered weapon resolves `.t<tier>` instead,
so its base `.desc` is never used and must not exist.

## Verification discipline

Three layers, learned the hard way (both lessons cost a real bug):

- **Layer 0 — domain equivalence.** Rebuild the domain value from the DTO and
  compare field-complete fingerprints against the original. A round-trip stays
  byte-stable even when the mapper never captured a field, because both
  directions drop it consistently. Proven: deleting `teachesRecipe` from the
  mapper (which would have removed all five recipe scrolls from the game) left
  the round-trip green.
- **Layer 1 — canonical round-trip.** `domain → DTO → JSON → DTO → domain → DTO
  → JSON` byte-identical, with `.sortedKeys`.
- **Layer 3 — migration digest** (`--content-digest`). Record fingerprints in
  catalog order, a seeded `pickFor` replay, and an **accessor replay**
  (`nextStep`, `capForTier`, `durability`, `stats`, `leagueKey`, `tithe`) over
  in- and out-of-range inputs. The accessor half exists because fingerprinting
  data does not verify the code that reads it. It earns its keep: the Arena
  league bands are never fingerprinted as records, so moving a boundary from
  1150 to 1151 is caught by the `leagueKey` replay **alone**.
- **Replay proof for a catalog that is code, not data.** When the shipped
  catalog is control flow (`ArenaCatalog.leagueKey` was a `switch`), the table
  cannot be read off it — it has to be hand-translated, and the translation
  proven before the flip: replay the shipped implementation against the new
  table across the whole input range and refuse to write on the first mismatch.
  Run it WIDER than the digest does; the digest replayed honor 0…2000 while
  `case ..<1000` also swallowed negatives, so the export check ran −500…3000.
  `PlotCatalog` and `QuestCatalog` are the same shape.

The digest has **four** halves: `records`, `tuning`, `spawns`, `quests`. Keeping
`tuning` separate is what let Phase 4 prove it moved the balance tables and
nothing else — the three catalog halves stayed at their Phase 3 values through
the whole migration.

All four have been negative-tested: reordering enemies moves `records` and
`spawns`; dropping `?? all.first` from `pickFor` moves only `spawns`; perturbing
`baseHitChance`, a bloodlust modifier, a `statGrowthLevels` member, a bare-tier
weight and the tavern delete window each moved `tuning` to a distinct value
while the catalog halves held. Phase 8D added three more: Shadow Veil ×2.1 and
the archer's Defend ×1.6 each moved `tuning` to a distinct value, and an elite
floor of 15 moved `records` alone. `spawns` covers foraging too since 8E — the
zone pools are picked by a weighted walk in declaration order, so a reordered
pool changes every draw while leaving each entry byte-identical. 8E's own three:
a forage weight of 2 → 3 moved `spawns` alone, while the plot-slot ladder (T7
6 → 5) and a farm capacity (6 → 7) each moved `records` alone. The enemy half of
the spawn replay is unchanged across the phase, which the printed distribution
shows directly — the same seven counts as before, with the forage rows appended.

**A hash cannot see a value the shipped configuration masks.** The sweeper's
`intervalDivisor` is invisible to the digest at `scale = 60`, because the 60 s
floor swallows every sane divisor — the hash is identical for 12 and for 6. It
is covered instead by the two-point equivalence check printed on every digest
run (`interval 3600s → 300s`, `60s → 60s`), which fails loudly. When a
derivation has a clamp, check the unclamped branch somewhere the hash is not
looking.

## Migration pattern (historical — Phase 3 is closed)

Kept because the same shape recurs whenever behaviour moves from code to data.

1. Extend `ContentDigest` to cover the catalog **while it is still Swift-backed**;
   capture the baseline.
2. Add DTO + mapping + loader + `GameContent`/`DomainContent` fields.
3. Add it to `ContentExporter`; run `--export-content`; commit the JSON verbatim.
   *(That tool was deleted at the end of Phase 3. Phase 4 skipped this step and
   hand-wrote the six tuning files instead — safe ONLY because step 1 had
   already put every one of the ~80 constants under the digest, so a
   transcription typo could not survive step 5. Without that coverage, rebuild
   the exporter from git.)*
4. Flip the catalog to a façade, delete the Swift array.
5. Re-run the digest — must be identical.
6. **Remove it from `ContentExporter`** — re-exporting a façade writes back what
   was just loaded, and a self-check over that circle proves nothing.

Normalize nothing during a migration. Sentinels (`0...0` depth ranges) and
declaration order are preserved so any behavioural difference is provably a
pipeline bug rather than a design change.

## Gotchas

- `Dictionary(uniqueKeysWithValues:)` **traps** on a duplicate id. Snapshots use
  `uniquingKeysWith:`; duplicates are a validator error.
- `ClosedRange` traps when `min > max`. Ranges are validated as a `{min,max}`
  pair and only built after passing.
- Swift does **not** apply property defaults for missing keys in a synthesized
  `Decodable` — every DTO writes `init(from:)` by hand. Locked by a test.
- **Records tolerate a missing key; tuning scalars must not.** A ladder step's
  absent `inputs` sensibly means "no cost", so it decodes with
  `decodeIfPresent`. A constant has no such reading: `market.json`,
  `guild.json` and `arena.json` decode every field with `decode`, so a missing
  `memberCap` fails the boot instead of silently becoming 20. Locked by
  `CapitalCatalogTests`.
- **A round-trip is blind to a transposed pair.** `maxOfficers` written into
  `memberCap` encodes and decodes flawlessly. The scalar files' layer 0 is
  therefore encode → decode → compare each field against the live Swift
  constant, not a round-trip.
- `all.first { … }` returns the **first** match, so a dictionary replacing it
  needs `uniquingKeysWith: { first, _ in first }`. The `{ _, last in last }`
  reflex changes which row a duplicate id resolves to.
- Files that are scalars-only cannot use an empty-array sentinel for "absent",
  because a zero has to stay a validation ERROR. `ContentBundle` holds the five
  capital files as **optionals**; `DomainContent` throws `incompleteBundle` on a
  nil rather than booting a game whose guild cap is silently zero.
- **A `private static let` inside the catalog is the sharpest edge in a flip.**
  `FortuneCatalog.lookup` read `all` at type-init; harmless while `all` was also
  a `static let`, a guaranteed trap the moment `all` reads the snapshot. Grep
  inside the catalog, not just at its call sites.
- **Absence can be a value.** A plot with no `tuning` is how the estate
  controller knows to open a training fight instead of a harvest, so nil-ness is
  compared explicitly rather than flattened to an empty struct.
- **A no-op default is per-field.** `FortuneEffect` omits 0 for bonuses but
  **1.0** for multipliers; one "skip falsy" rule would decode a card that zeroes
  the stat it scales.
- **Never iterate a catalog's Dictionary for a digest or an export.** `pools`
  and `t1Tunings` hash in an arbitrary per-process order; walk `allCases`.
- `TimeInterval` fields are `Double` on the wire. `45` and `45.0` decode to the
  same value and the digest interpolates them as `"45.0"`, so JSON formatting
  cannot move the digest. Locked by a test.
- `nextStep` on the bag and estate ladders indexes `progression[toTier − 2]`, so
  the validator demands contiguous tiers and the snapshot sorts on load.
- 21 `en.json` keys have no plain `uk.json` form; uk supplies `.m`/`.f` instead.
  `LocaleIndex.has` accepts either, or the validator emits 21 false errors.
- The Lingo emoji bug is encoded as a rule: any scalar wider than one UTF-16 unit
  before the LAST `%{…}` breaks interpolation. Currently 0 occurrences.
- `manifest.json` carries no `generatedAt` — a timestamp would dirty every
  re-export and destroy byte-for-byte comparison. `contentHash` is the identity.
