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
Tests/ROIContentTests                            42 tests; fast because no Fluent/Postgres/Telegram
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
  ItemCatalog / EnemyCatalog / RecipeCatalog / WeaponUpgradeCatalog /
  BagCatalog / EstateUpgradeCatalog  — all read Catalogs.current
```

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
  data does not verify the code that reads it.

Both halves have been negative-tested: reordering enemies moves both; dropping
`?? all.first` from `pickFor` moves only `spawns`.

## Migration pattern (repeat per catalog)

1. Extend `ContentDigest` to cover the catalog **while it is still Swift-backed**;
   capture the baseline.
2. Add DTO + mapping + loader + `GameContent`/`DomainContent` fields.
3. Add it to `ContentExporter`; run `--export-content`; commit the JSON verbatim.
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
- `nextStep` on the bag and estate ladders indexes `progression[toTier − 2]`, so
  the validator demands contiguous tiers and the snapshot sorts on load.
- 21 `en.json` keys have no plain `uk.json` form; uk supplies `.m`/`.f` instead.
  `LocaleIndex.has` accepts either, or the validator emits 21 false errors.
- The Lingo emoji bug is encoded as a rule: any scalar wider than one UTF-16 unit
  before the LAST `%{…}` breaks interpolation. Currently 0 occurrences.
- `manifest.json` carries no `generatedAt` — a timestamp would dirty every
  re-export and destroy byte-for-byte comparison. `contentHash` is the identity.
