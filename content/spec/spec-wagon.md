# The wagon — hired in the capital (2026-11-08)

**Status: DECIDED and BUILT 2026-11-08 (committed, not deployed).** The owner signed the draft off («Так»)
the same day. §2 holds the owner's decisions from the session's quizzes; §3 is what the sign-off
approved; §3.7 is what the build decided on its own. Amended the same evening on the test bot (§2.9,
§2.10): the road with a wagon takes 3 minutes, and anything the warehouse takes rides on it. Amended
again the same day (§2.11): the estate's door asks whether the wagon comes along. Content
schema **v33** (`stable.json`), four migrations (`CreateWagons` — two new tables; `AddTravelCrossing`,
`AddWagonCargoGear` and `AddWagonLeftHome` — columns only; no row rewritten). Not live until the Pi is
rebuilt and restarted.

## 1. What was asked

The owner: «Хочу додати можливість гравцям брати в аренду в Столиці більш швидкого коня а також
орендувати обоз. В обоз можна буде завантажити більше матеріалів ніж в сумку.»

After the first proposal the owner said «Поки зупинимось тільки на обозі», so the horse is parked
(§7). The owner then asked for:
- other names;
- several rental lengths, «щоб найдовший був дешевший за хвилину користування»;
- the capacity sized on the live warehouses (the owner allowed the read, §5).

## 2. Decided (the owner, 2026-11-08)

1. **«🫏 Віз».** The name was picked from Віз / Підвода / Мажа / Обоз, the icon from 🐴 / 🫏 / 🧺 / 🐴🛞.
   - Not «обоз»: the decree «Похідний обоз» already uses that word for bag tier 4.
   - Not 🛞: most phones draw it as a car tyre.
   - Taken icons: 🐂 Тур, 🦬 Зубр, 🐎 the road, 🛒 Базар, 📦 the warehouse.
   - 🫏 is Unicode 15, the same set the moose's 🫎 already shows from in live play.
2. **200 places.** 200 is more than the largest bag (90); §5 shows why this number. *Amended by
   §2.10:* it first took materials only (`mat.*`).
3. **Four lengths, the longest the cheapest per minute.** The owner named the start, 100 🪙, then
   took the curve:

<!-- generated: roi-content spec wagon -->
| length | minutes | silver | per hour | per minute |
|---|---|---|---|---|
| 1 h | 60 | 100 | 100.0 | 1.667 |
| 3 h | 180 | 190 | 63.3 | 1.056 |
| 1 d | 1440 | 670 | 27.9 | 0.465 |
| 7 d | 10080 | 2160 | 12.9 | 0.214 |

Capacity **200** places for anything the warehouse takes; the largest bag holds 90.
A crossing with the wagon: **3 min** (2 min without it).
<!-- /generated -->

   The row is 100 × hours^0.6, rounded to 10. Shown and not taken:
   - a start of 15 (15 · 30 · 100 · 325) — answered «Запропонуй більш дорогий варіант зі старту»;
   - starts of 30, 40 and 50 — the owner named 100 instead;
   - at a start of 100, the steeper 100 · 160 · 360 · 780 and the gentler 100 · 230 · 1,080 · 4,670.
4. **The wagon does not enter the forest.** It waits in the estate's yard. Forest finds stay paced
   by the bag, and a death never touches the wagon.
5. **When the rental ends, the cargo goes to the warehouse by itself.** What does not fit stays on
   the wagon until there is room.
6. **In the capital, every place that takes from the bag takes from the wagon too.** This was
   chosen over «the trader alone» and over «the trader, plus moving between the wagon and the bag»,
   knowing it is the largest build.
7. **The stable is on Поділ**, as a third row of the street's keyboard:
   [💼 Крамар] [🛠 Майстер] / [🍺 Шинок] [🔮 Ворожка] / [🐎 Стайня]. «Стайня» is a working name.
8. **At home the wagon is unloaded first.** The estate's own services keep drawing from bag +
   warehouse and never read the wagon. That covers the estate and bag upgrades, plots, workshop,
   kitchen and Training Ground. «Так, як у Столиці» was shown and not taken.
9. **A crossing with the wagon takes 3 minutes, not 2** (the owner on the test bot: «Віз повинен
   їхати не 2хвилини, а 3»). Every trip the wagon rides on, empty or loaded (*amended by §2.11:* it no
   longer rides on every trip while the hire runs). The crossing is
   stamped on the trip (`travel_state.crossing_seconds`), so a hire that ends on the way changes
   nothing and a turn-back is measured against the trip's own road — `TravelService.turnBack` read the
   global two minutes until then. `stable.json` → `travelMinutes`; the validator refuses a wagon
   faster than the road (`stable.wagon_faster_than_road`).
10. **Anything the warehouse takes rides on the wagon** («завантажувати у віз можна все, а не тільки
   матеріали»): food, tinctures, artifacts and gear as well. The class weapon stays with the player,
   as at the warehouse. A piece of gear carries its own tier, wear and enchant — the cargo has the
   warehouse's four `GearState` columns — and moves one copy at a time.
11. **The estate's door asks** (the owner, on «Найнятий віз сповільнює кожну поїздку до 3 хвилин навіть
   порожнім, і повернути його достроково не можна»). While a hire runs, «Столиця» at the estate asks
   «🐎 Верхи · 2хв» or «🫏 З возом · 3хв», an empty wagon included: an empty one in town takes what the
   bag cannot.
   - **On horseback the wagon stays at home** and its cargo is out of reach in town: the trader, the
     Master, the fortune teller and the jobs see the bag alone (`wagons.left_home`,
     `WagonMath.ridesAlong`). Shown and not taken: the cargo reachable anyway, which leaves nobody a
     reason to take 3 minutes.
   - **The answer holds both ways, and the capital asks nothing.** Rode out → 2 min home; came with
     the wagon, or hired it in town → 3 min home. Shown and not taken: asking in town too and leaving
     the wagon by the stable.

## 3. How it plays (proposed — the sign-off approves this)

### 3.1 Hiring

- **The stable's screen** names the wagon and its four lengths.
- **Every length button asks first.** The question ends with `RequirementLine.silver`, and only
  «✅ Найняти» spends. The silver and the wagon's row are written in one transaction.
- **Hiring again while the wagon is yours** adds the new length to the end of the current one
  («🫏 +1 год · 100 🪙»).
- **A double tap pays once** (2026-11-09): the yes carries what its question saw of the hire (`WagonMath.hireStamp`).
- **No level or estate gate.** The price is the gate.
- **Nothing is typed into copy.** Every length, every price and the capacity are printed from
  the data.

### 3.2 Where the wagon is

- **With the player** — on the road, in the capital and at the estate, unless they rode off without
  it (§2.11).
- **In the yard while the player is in the forest**, on a walk or a 🏕 run. The wagon's screen at
  home refuses while an expedition row stands, like every `estate:wh:` button.
- **In the yard while the player is away on horseback** (§2.11). A longer hire bought in town leaves it
  there; a new hire, after the old one ran out, starts beside the player at the stable.
- **Unreachable on the road.** No place on the road reads it.
- **It slows the road** to 3 minutes a crossing when it rides along (§2.9, §2.11), stamped on the trip.

### 3.3 At home

- **The warehouse screen shows the wagon** while one is hired or still holds cargo:
  - a line «🫏 Віз: 150/200 · ще 2год 41хв»;
  - a button «🫏 Віз (150/200)».
- **The wagon's list** shows everything in the warehouse and on the wagon (§2.10).
- **A wagon card has the warehouse card's shape:**
  - «⬆️ 🫏 1 · Усі (N) · ✏️» loads from the warehouse;
  - «⬇️ 📦 1 · Усі (N) · ✏️» unloads into it;
  - «📦 Розвантажити все» sits under the list.
- **The warehouse cap holds on every unload.** A partial unload says what stayed on the wagon.
- **Gear moves a copy at a time** (§2.10): the list names each copy with its tier, enchant and wear
  — «⬆️ 🫏 🦺 Куртка лісника +1 40/50» puts the warehouse's copy on the wagon while the hire runs,
  «⬇️ 📦 …» takes the wagon's copy off it — and the copy keeps its state both ways.
- **The wagon trades with the warehouse only.** The bag reaches it through the warehouse, as today
  («📦 Викласти все»).
- **The estate's own services keep drawing from bag + warehouse** (§2.8). The wagon is unloaded
  first, with «📦 Розвантажити все».

### 3.4 In the capital

**Taking.** These places take an item from the bag first and from the wagon for the shortfall:
- the trader's sale;
- the Master's lesson and enchant;
- the fortune teller's tinctures;
- the jobs' deliveries;
- listing a Базар lot;
- a deposit into the guild's treasury;
- a trade between players.

This is the house's order at home, where `WeaponUpgradeService` drains «inventory first, warehouse
for the shortfall».

**Putting.** These places put an item into the bag first and onto the wagon for what does not
fit:
- the trader's purchase;
- a Базар purchase or a cancelled lot;
- a withdrawal from the guild's treasury;
- a trade between players.

One fit check predicts both stores, in units, using the writer's own arithmetic (`CraftMath`'s bag
+ second store). It is all or nothing.

**Counting.** Every number a card shows counts both stores.
- A `RequirementLine` for 26 hides, with 10 in the bag and 30 on the wagon, reads «(40/26)».
- The trader's rows show the split: «🪵 Сосновий брус · 🎒 4 · 🫏 100 · 🪙 2».
- The bag screen's header gains «🫏 Віз: 150/200 · ще 2год 41хв» (the time since §2.11) and a button to the wagon's list. In town that
  list is read-only.

A sale from the wagon goes through the same funnels as one from the bag, so the jobs, «Оптовий
день» and the decree's trader sale count it. Since §2.10 this covers food and the rest too (the
trader's potatoes and eggs, a job's berries, a Базар lot of nuts). **Gear on the wagon is read by no
place in town:** the Master's repair and enchant and a trade's gear name the bag's rows.

### 3.5 When the rental ends

- **The carter takes the cargo home at once**, wherever the player is. It goes into the warehouse,
  up to the cap.
- **What does not fit stays on the wagon in the yard.** That wagon:
  - no longer travels;
  - takes nothing new;
  - is read by no place in town;
  - moves its cargo into the warehouse as room appears, on the watchman's sweep.
- **Hiring again takes the same wagon**, with whatever is still on it.
- **The watchman sends one notice:** «🫏 Оренда воза скінчилась. Візник відвіз на склад 120 одиниць.»
  With a remainder it adds «30 не вмістились — лежать на возі, доки на складі не звільниться місце.»
  The marker is written before the push.

### 3.6 What the wagon never does (unchanged by the build)

- enter the forest;
- get taken by a death;
- get thrown from — it has no «🗑», like the warehouse;
- carry the class weapon.

### 3.7 What the build decided on its own (for the owner's review)

- **The bag's «🫏 Віз» list is read-only at home too**, not only in town. The bag is answered by
  its own router, and the main router deletes a message whose button it does not know, so the
  warehouse's move buttons cannot live on the bag's screen. The moves stay at the warehouse (§3.3).
- **A delivery job counts a running wagon wherever the player is, unless they are away without it**
  (§2.11: a wagon left at home counts for nothing at the NPC, so a «ready» told at home does not hold
  for a player who then rides out without it). It rides to the NPC with them,
  so the board, the watchman's «ready» and the turn-in agree; the turn-in drains it in town only.
  The Master's and the fortune teller's journal notes count it the same way.
- **The capital's refusals name both stores** when the wagon took part: «Сумка й віз повні — вільно
  N місць, треба M.» at the trader, on the Базар and in the guild's vault.
- **The trader's «Скільки … купити?»** shows the wagon's room beside the bag's: «(у 🎒 вільно 27 · у
  🫏 вільно 150)», from the room the purchase checks.
- **Hiring again while the wagon is yours asks «Найняти віз ще на 3 год за 190 срібників?»** — the
  same question with «ще».
- **The stable has «🔙 До столиці» under its lengths**, the shape of every place in town.
- **A line for a wagon whose hire ran out with cargo on it** reads «🫏 Віз: 30/200 · оренда
  скінчилась» on the warehouse and in the profile; its list says «Оренда скінчилась — віз можна
  тільки розвантажити.» A move asked away from the yard is refused with «Віз вантажать і
  розвантажують удома, біля складу.»
- **The end-of-hire notice with nothing on the wagon is only its first sentence**, «🫏 Оренда воза
  скінчилась.»
- **`Countdown.format` prints days** (`time.short.days`, «д» / "d"): «6д 23год».

## 4. Copy (uk) — approved with the spec

| where | line |
|---|---|
| Поділ's keyboard | «🐎 Стайня» |
| the stable | «🐎 <b>Стайня</b>» · «Візник змащує колесо дьогтем: «Віз під товар? На скільки берете?»» · «🫏 Віз — 200 місць під вантаж. Дорога з ним — 3хв замість 2хв. Що довша оренда, то дешевша година.» *(amended with §2.9–10)* |
| the stable's buttons | the right-hand column since the Rysak (2026-11-09, `spec-horse.md` §4): «🫏 1 год · 100 🪙» / «🫏 3 год · 190 🪙» / «🫏 1 день · 670 🪙» / «🫏 7 днів · 2160 🪙»; while hired «🫏 +1 год · 100 🪙» … |
| the stable, while hired | «🫏 Віз ваш ще 2год 41хв · на возі 150/200» |
| the question | «🫏 Найняти віз на 1 день за 670 срібників?» · «Він їздить з вами між маєтком і столицею й везе все, що бере склад, — дорога з ним 3хв замість 2хв.» *(amended; the owner cut «У ліс не йде — чекає на подвір'ї.» on 2026-11-09, the rule stands)* · «   ✅ 🪙 Срібло  (2946/670)» · [✅ Найняти] [❌ Ні] |
| the banner | «🫏 Віз найнято на 1 день · −670 🪙» |
| the estate's door (§2.11) | «🐎 <b>Дорога до столиці</b>» · «🫏 Віз: 150/200 · ще 2год 41хв» · «Верхи — 2хв. Віз чекатиме вдома, вантаж у столиці буде недоступний.» · «З возом — 3хв. Вантаж їде з вами.» · [🐎 Верхи · 2хв] [🫏 З возом · 3хв] |
| the road card, under the 🐎 line, when it rides along | «🫏 Позаду торохтить віз: 150/200.» |
| the warehouse | «🫏 Віз: 150/200 · ще 2год 41хв» · button «🫏 Віз (150/200)» |
| the wagon's card, at home | «📦 На складі: 110 · 🫏 На возі: 100 (вільно 50)» · «⬆️ 🫏 1» «⬆️ Усі (50)» «⬆️ ✏️» / «⬇️ 📦 1» «⬇️ Усі (100)» «⬇️ ✏️» · «📦 Розвантажити все» |
| the trader's rows | «🪵 Сосновий брус · 🎒 4 · 🫏 100 · 🪙 2» |
| the bag's header and the profile | «🫏 Віз: 150/200 · ще 2год 41хв», away without it «… · чекає вдома» (§2.11) |
| the end of the rental | «🫏 Оренда воза скінчилась. Візник відвіз на склад 120 одиниць.» + «30 не вмістились — лежать на возі, доки на складі не звільниться місце.» |

Grammar notes:
- «Віз» is masculine (`m` in `uk.json`): «на возі», «воза».
- Units are «одиниць», as in «Викладено N одиниць на склад»; room is «місць». Never «слот».
- A count of units takes the three plural forms.

The number printed in the copy is a sample state; every number comes from the data or the rows.

## 5. Measured (2026-11-08)

**Source.** A live read of `ArtaniaDB` on the Pi, read-only, with the developer account excluded.

**Who.** 17 players fought in the 7 days to 11-08; 10 of them have an estate at tier 3 or above.
- Those 10 warehouses hold 277–1,466 building materials.
- Three are nearly full: анія 1,555/1,600, Ivan Djyran 767/800, Ліліт 555/600.
- Pebbles are the biggest pile: 2,592 on 12 warehouses.
- «Оптовий день» (sell 300 🪙 at the trader in a day) was taken 53 times and finished 49.

**Method.** Surplus = what a player holds (bag + warehouse) beyond the next estate recipe.
Counted from the capital: each run is two crossings of 2 min, and the bag's room is its full cap.

| player | bag | surplus | bag alone | wagon 200 + bag |
|---|---|---|---|---|
| Ліліт (L9, warehouse 555/600) | 35 | 389 ≈ 1,477 🪙 | 12 runs, 48 min | 2 runs, 8 min |
| Ivan Djyran (L11, 767/800) | 45 | 306 ≈ 1,248 🪙 | 7 runs, 28 min | 2 runs, 8 min |
| Надійка (L15) | 60 | 416 ≈ 1,380 🪙 | 7 runs, 28 min | 2 runs, 8 min |
| анія (L17, 1,555/1,600) | 75 | 1,145 ≈ 3,753 🪙 | 16 runs, 64 min | 5 runs, 20 min |

**Why 200.**
- It puts a typical mid-game surplus into two runs.
- It carries the estate's tier-5 recipe (193) in one.
- 150 gives Ліліт 3 runs and анія 6.
- 300 gives Ліліт the same 2 runs and анія 4, but means more storage on wheels.

**What an hour costs.** One hour (100 🪙) clears any of these surpluses. Against the surplus's sale
value, the fee is:
- 2.7% for анія and 6.8% for Ліліт;
- 17% for Samolan (585 🪙).

Against the cargo of a single run of 235 places (wagon 200 + bag 35), the fee takes:
- 43% of a run of pebbles (235 🪙);
- 21% of lumber;
- 14% of hides;
- 4% of iron or clay.

So the wagon pays on valuable cargo, and pebbles and lumber will mostly still travel by bag. Buying
the estate's tier-5 materials at the trader costs 2,860 🪙; an hour is 3.5% of it. The seven-day
length is three times a daily hour, so it serves a wealthy or constant trader: the richest hold
11–15 thousand.

Recipe: per player, sum `inventory` (`equipped_slot IS NULL`) and `warehouse` by item for the six
building materials. Subtract the next row of `estate_upgrades.json`, price what is left at the
trader's sell prices, and divide by the bag cap plus the wagon. Activity is a `fight_log` row in
the last 7 days.

## 6. What the build touched

- **Content.** `content/data/stable.json` → `wagon`: the capacity, and the lengths as minutes and
  silver.
  - The validator refuses a capacity that is not above the largest bag.
  - It refuses lengths that are not strictly longer and pricier, each one cheaper per minute than
    every shorter one.
  - The digest names every value. Content schema v33.
- **Tables.**
  - The wagon: one row a player, with its end and its delivery/notice markers.
  - The cargo: `item_id`, `quantity` and, since §2.10, the four `GearState` columns
    (`AddWagonCargoGear`, which also drops the one-row-per-item constraint).
  - `travel_state.crossing_seconds` (`AddTravelCrossing`, §2.9).
  - `wagons.left_home` (`AddWagonLeftHome`, §2.11): written at every departure from the estate,
    cleared on landing there.
  - `wagon_cargo.item_id` goes into `LiveReferenceQuery`, and both tables into
    `WipeForRebalance.playerTables`.
- **`WagonService`**: hire and extend, load and unload, and the end. Each capital service named in
  §3.4 takes the wagon as its second store.
- **`Countdown.format` learns days** («6д 23год»). No countdown in the game reaches 24 hours today;
  the longest, the fortune teller's next card, stays under it. So only the wagon's lines change.
- **Screens.**
  - The stable: `CapitalController+Stable.swift`.
  - Поділ's keyboard and its copy, and the square's welcome.
  - The wagon at the warehouse.
  - The trader's rows, the bag's header, the road card's line and the profile's line.
- **The watchman** gets an end-of-rental pass. It writes rows, never a `User`.
- **`CLAUDE.md` rules that change.**
  - «What a place can draw on is where it stands»: in the capital that becomes the bag and the
    hired wagon.
  - The fit-check rule names the wagon as a store.
  - The warehouse-cap rule names the end-of-rental delivery as a path in.
- **`spec-economy.md` §4**: the wagon joins the sinks.
- **Tests.** Each rule gets a case that must fail it:
  - a put that splits across bag and wagon is all or nothing;
  - an expired wagon refuses cargo;
  - a full warehouse leaves the remainder on the wagon;
  - the validator's two rules.
- **Art.**
  - `Assets/capital/stable.jpg` is a slot; without it the screen is text.
  - The capital map has no «Стайня» label.

## 7. Left open

- **The horse came back on 2026-11-09**, as «🐴 Рисак»: `spec-horse.md`. It feeds the trip's stamp this
  wagon's §2.9 built, and never speeds the wagon up.
- **Working names.** The place's name «Стайня» and the English "Wagon" are working names.
