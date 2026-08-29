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
Modules/ROISim        library → ROIContent       SplitMix64 + OutcomeDigest (simulator lands Phase 8)
Modules/roi-content   executable                 CLI: validate
Tests/ROIContentTests                            85 tests; fast because no Fluent/Postgres/Telegram
Swift/                executable                 the bot; carries @_exported import ROIContent / ROISim
```

`Modules/`, not `Sources/` — `CLAUDE.md` states game code lives in `Swift/`, and
a `Sources/` directory would contradict that.

## Runtime shape

```
content/data/*.json
      ↓ ContentLoader.load      (decode, readable errors, FNV-1a content hash, NEVER sorts)
   ContentBundle                 DTOs, not yet validated
      ↓ ContentValidator         identity · enums · references · localization · ladders · timeScale
   GameContent  (DTO snapshot)   → GameData.install
   DomainContent (domain snapshot) → Catalogs.install
      ↑
  ALL 12 catalogs — Item · Enemy · Recipe · WeaponUpgrade · Bag · EstateUpgrade
  Trader · Tavern · Market · Guild · Arena · Master · Plot · Fortune · Quest
  — every one reads Catalogs.current
```

`content/data/` holds 16 files: `manifest · items · enemies · recipes ·
weapon_upgrades · bags · estate_upgrades · trader · tavern · market · guild ·
arena · master · plots · fortune · quests`. **No Swift catalog array remains**
(Phase 3 closed 2026-08-29), so `ContentExporter` and `--export-content` are
gone. `ContentDigest` stays — it is the "confirm only the intended change" step
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

## Adding content

It is a data edit. There is no Swift array to touch.

1. Append to the right `content/data/*.json`.
2. Add locale keys to **both** `Localizations/en.json` and `uk.json`.
3. `swift run roi-content validate --strict` → must exit 0.
4. `swift run RestOfIryna --content-digest` → confirm only the intended change.

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

Both halves have been negative-tested: reordering enemies moves both; dropping
`?? all.first` from `pickFor` moves only `spawns`.

## Migration pattern (historical — Phase 3 is closed)

Kept because the same shape recurs whenever behaviour moves from code to data.

1. Extend `ContentDigest` to cover the catalog **while it is still Swift-backed**;
   capture the baseline.
2. Add DTO + mapping + loader + `GameContent`/`DomainContent` fields.
3. Add it to `ContentExporter`; run `--export-content`; commit the JSON verbatim.
   *(That tool was deleted at the end of Phase 3 — reconstruct it from git if a
   future catalog ever needs the same move.)*
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
