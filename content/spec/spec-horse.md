# The Rysak — a faster horse hired in the capital (2026-11-09)

**Status: DECIDED and BUILT 2026-11-09 (committed, not deployed).** The owner
signed the draft off («Так») the same day. §2 holds the owner's decisions from the session's quiz. §3 applies
the wagon's decisions (`spec-wagon.md`) to the horse, and is what the sign-off approved. The code says
`horse`; the player reads «Рисак». It ships with the wagon, under its content schema v33, with one more
migration (`CreateHorses`, a new table, no row rewritten). Not live until the Pi is rebuilt and restarted.

## 1. What was asked

The owner, 2026-11-08: «Хочу додати можливість гравцям брати в аренду в Столиці більш швидкого коня а
також орендувати обоз». The horse was parked in favour of the wagon. The owner, 2026-11-09, with the
wagon built and not deployed: «Виходячи з того, які рішення я прийняв при розробці возу, запропонуй мені
рішення для швидшого коня.»

## 2. Decided (the owner, 2026-11-09)

1. **The wagon sets the pace.** A crossing with the wagon stays 3 minutes, hired horse or not. «Поки
   3хв. Потім буде окремий, донатний віз, який йде швидше.» (§7)
2. **A crossing on the Rysak takes 1 min 30 s**, against the road's 2 min. Shown and not taken: 1 min
   and 40 s.
3. **Prices: a start of 50** on the wagon's own curve, start × hours^0.6, rounded to 10. Shown and not
   taken: starts of 70, 100 and 150.
4. **The name is «Рисак»**, picked from Баский кінь / Румак / Скакун / Рисак. "Trotter" in English, a
   working name.
5. **The icon is 🐴**, picked from 🏇 / 🐴. 🐎 is taken by the road, the stable and «🐎 Верхи».
6. **It ships with the wagon**: one walk on the test bot, one build, one restart. Content schema stays
   v33, which no deployed binary has read.

<!-- generated: roi-content spec horse -->
| length | minutes | silver | per hour | per minute |
|---|---|---|---|---|
| 1 h | 60 | 50 | 50.0 | 0.833 |
| 3 h | 180 | 100 | 33.3 | 0.556 |
| 1 d | 1440 | 340 | 14.2 | 0.236 |
| 7 d | 10080 | 1080 | 6.4 | 0.107 |

A crossing on the Rysak: **90 s** (120 s without it); with the wagon it stays 180 s.
<!-- /generated -->

## 3. How it plays (approved with the sign-off)

### 3.1 Hiring (the wagon's §3.1)

- **At the stable on Поділ**, on the same screen as the wagon: two columns of buttons, the Rysak's on the left and
  the wagon's on the right, one length a row (the owner on the test bot, 2026-11-09).
- **Every length button asks first.** The question ends with `RequirementLine.silver`, and only
  «✅ Найняти» spends. The silver and the row are written in one transaction.
- **Hiring again while the Rysak is yours** adds the new length to the end of the current one.
- **A double tap pays once.** The yes carries what its question saw of the hire (`WagonMath.hireStamp`), and a hire
  that no longer matches redraws the stable and spends nothing. Found by the audit before the commit, the wagon's yes too.
- **No level or estate gate.** The price is the gate.
- **Only in town and not on the road**: the same guard as `WagonService.hire`, so a hire can never
  touch a trip already under way.
- **Nothing is typed into copy.** Every length, price and time is printed from the data.

### 3.2 The road

- **Every trip that sets out while the hire runs**, in both directions, takes 1 min 30 s, unless the
  wagon rides along (§2.1).
- **A crossing is one rule**, in this order: the wagon rides along → the wagon's 3 min; the hire runs →
  the Rysak's 1 min 30 s; otherwise the road's 2 min.
- **The crossing is stamped on the trip**, as the wagon's is (`travel_state.crossing_seconds`). A hire
  that ends on the way changes nothing, and a turn-back at second 24 takes 24 seconds.
- **The hire does not pause** while the wagon rides along or while the player is in the forest. The
  hired time runs, as the wagon's does.
- **It never enters the forest.** A walk and a 🏕 run are on foot, as today.

### 3.3 The estate's door

- **The Rysak alone asks nothing**: there is no trade-off, so «Столиця» sets out at 1 min 30 s.
- **With a running wagon the door asks exactly what it asks today**, and only the horseback time
  changes: «🐎 Верхи · 1хв 30сек» / «🫏 З возом · 3хв». The button keeps its name.
- **Riding out on the Rysak leaves the wagon at home** under the wagon's §2.11, and the answer holds
  both ways.

### 3.4 Where it is shown

- **The stable**: its offer, and «🐴 Рисак ваш ще …» while hired.
- **The road card**, under the 🐎 line, on all three cards (setting out, «how long is left», a
  turn-back), while the hire runs and no wagon rides along: «🐴 Рисак ще 2год 58хв.»
- **The profile**, beside the wagon's line: «🐴 Рисак: ще 2год 58хв».
- **Not the bag's header.** The Rysak is not a store.

### 3.5 When the hire ends

The watchman sends one notice, «🐴 Оренда рисака скінчилась.», with its marker written before the push,
in the shape of the wagon's `settled_end`. A new hire moves `ends_at` past the marker, which arms the
next notice. Nothing else happens: there is no cargo.

## 4. Copy (uk)

| where | line |
|---|---|
| the stable, the carter (replaces «Віз під товар?…») | «Візник змащує колесо дьогтем: «Коня чи віз під товар? На скільки берете?»» |
| Поділ's caption (its last sentence) | «А в Стайні біля брами наймають рисака чи віз під товар.» *(the build's own edit: it named only the wagon)* |
| the stable, the offer | «🐴 Рисак — дорога 1хв 30сек замість 2хв. Що довша оренда, то дешевша година.» |
| the stable's buttons | a column per offer: «🐴 1 год · 50 🪙» «🫏 1 год · 100 🪙» / «🐴 3 год · 100 🪙» «🫏 3 год · 190 🪙» / «🐴 1 день · 340 🪙» «🫏 1 день · 670 🪙» / «🐴 7 днів · 1080 🪙» «🫏 7 днів · 2160 🪙»; while hired «🐴 +1 год · 50 🪙» … |
| the stable, while hired | «🐴 Рисак ваш ще 2год 58хв» |
| the question | «🐴 Найняти рисака на 3 год за 100 срібників?» (more: «… ще на 3 год …») · «Дорога між маєтком і столицею — 1хв 30сек замість 2хв.» *(the owner on the test bot, 2026-11-09, cut «Віз Рисак не пришвидшує: з ним дорога лишається 3хв. У ліс не йде.»; the rules stand)* · «   ✅ 🪙 Срібло  (412/100)» · [✅ Найняти] [❌ Ні] |
| the banner | «🐴 Рисака найнято на 3 год · −100 🪙» |
| the road card | «🐎 Ви підганяєте коня до столиці. Прибуття за 1хв 30сек.» · «🐴 Рисак ще 2год 58хв.» |
| the profile | «🐴 Рисак: ще 2год 58хв» |
| the end of the hire | «🐴 Оренда рисака скінчилась.» |
| refused away from town | «Рисака наймають у Стайні, у столиці.» *(only in a race: at home or on the road the main router deletes a stale stable button, the wagon's as well)* |

The wagon's line «Дорога з ним — 3хв замість 2хв» keeps quoting the road's own 2 minutes, for a player
with a hired Rysak too. The number printed here is a sample state; every number comes from the data.

## 5. Measured (2026-11-09)

The runs are the wagon's §5, counted the same way (each run two crossings, from the capital), with
the wagon at its later 3 minutes. Each column carries its road time and an hour's hire.

| player | bag | bag on the Rysak | wagon |
|---|---|---|---|
| Ліліт | 12 runs · 48 min · 0 🪙 | 12 runs · 36 min · 50 🪙 | 2 runs · 12 min · 100 🪙 |
| Ivan Djyran | 7 runs · 28 min · 0 🪙 | 7 runs · 21 min · 50 🪙 | 2 runs · 12 min · 100 🪙 |
| Надійка | 7 runs · 28 min · 0 🪙 | 7 runs · 21 min · 50 🪙 | 2 runs · 12 min · 100 🪙 |
| анія | 16 runs · 64 min · 0 🪙 | 16 runs · 48 min · 50 🪙 | 5 runs · 30 min · 100 🪙 |

- The Rysak saves 30 seconds a crossing, so the wagon stays ahead on bulk in both time and trips.
- The daily jobs pay 98–217 🪙 (`spec economy`); the richest players hold 11–15 thousand.
- **How many crossings a player makes is not recorded** anywhere, so what a day's or a week's hire
  saves in practice is not measured.

## 6. What the build touched

- **Content.** `stable.json` → `horse`: `travelSeconds` (90; the wagon's whole minutes cannot say it)
  and `lengths`.
  - The validator refuses a horse not faster than the road (`stable.horse_not_faster_than_road`) and
    applies the wagon's length rules to its lengths, through one routine.
  - The digest names every value.
  - `roi-content spec horse` prints §2's table.
  - Schema stays v33, with `stable.json`'s `horse` required.
- **Table.** `horses` (`CreateHorses`): one row a player, `ends_at`, the notice marker. In
  `WipeForRebalance.playerTables`. No content id, so not in `LiveReferenceQuery`. No row rewritten.
- **The crossing.** `WagonMath.crossing` stays the one reading and gains the horse.
  `TravelService.crossingSeconds` returns the plain road when no wagon row exists, so that guard must
  go: a player with a Rysak and no wagon has no such row.
- **The door.** `roadQuestion` prints `TravelService.travelSeconds` for «Верхи» and must print the ride
  the player will get.
- **Screens.** The stable, its question and its `stable:` callbacks; the road card's three call sites;
  the profile.
- **The watchman.** One more pass beside `settleWagons`. It writes rows, never a `User`.
- **Tests.** Each rule gets a case that must fail it: the crossing's three branches, the validator's
  rules, a hire that extends and one that starts anew.
- **Records with the build.** `spec-wagon.md` §7, `TODO.md`'s parked line, `CLAUDE.md`'s stable rule,
  the README, the file map, the FAQ. The tree's digest moved in `records` alone (`44ac628c24ed47be`,
  content hash `0b82dc59`, COMBINED `40f970baec4a21ce`).
- **Art.** None needed.

## 7. Left open

- **A separate zlatnyk wagon that rides faster** (the owner, 2026-11-09: «Потім буде окремий, донатний
  віз, який йде швидше»). Not designed. If it crosses in under 2 minutes it needs its own rule, because
  `stable.wagon_faster_than_road` refuses any wagon faster than the road.
- **Working names.** The English "Trotter", and «Стайня» from the wagon's spec.
