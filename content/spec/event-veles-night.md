# Content spec — Велесова ніч (the 2026 Halloween event)

**Status: approved 2026-10-29, piece by piece, across the 2026-10-27 → 10-29 sessions. Reworked
2026-10-30 on the owner's word: the reveal is told in the palace, and the flask is collected there in
person (§3, §4.2–4.4, §7); the same day, «Велесовий гарбуз», a find on one step in ten (§4.5).**
The owner's idea (2026-10-27): on Halloween the King falls ill; players learn it from strange
notices with nonsensical decrees; the cure is the blood of a creature; at a kilometre of the
forest a button leads into a place there is no leaving except by dying; each creature "leaks"
blood, kept outside the bag so a death does not take it; whoever brings the most wins. On
2026-10-29 the owner re-set it as Велесова ніч, the Ukrainian take on Halloween, in Veles's
abandoned manor at km 5.

The copy below is the approved Ukrainian text, quoted as the player will read it (bold is
`<b>`). English is written to the same pattern and is not yet approved. The creatures' lines and
blood in §5 are printed by `roi-content spec events`; the descent table under them comes from the
session's scratch harness (`probe2`, the shipped `CombatMath`), which no CLI reproduces.

---

## 1. The mythology, and what the game claims

Checked 2026-10-29 (sources at the end):

- **Veles (Волос)** is attested as «скотій бог» — the god of cattle — in the Primary Chronicle's
  treaties of 907 and 971, sworn by beside Perun. Old East Slavic «скотъ» meant both cattle and
  money, so the cattle god is also the god of wealth. «Слово о полку Ігоревім» calls the singer
  Boyan «Велесів внук».
- **Veles as the lord of the dead,** the shepherd of souls and Perun's adversary is a 20th-century
  scholarly reconstruction (Ivanov–Toporov), partly disputed today — but it is the image people
  know. In it the oak is Perun's tree and Veles's places are low and wet, which is why the manor has
  a willow over a pond and black water at the bottom, and no oak.
- **«Велесова ніч» is a modern name** (20th–21st-century neo-pagans). The authentic folk custom of
  the season is **Діди** (Дідова субота): the dead are remembered, believed to come home, and a
  table is laid for them.
- **There is no "manor of Veles" in any myth.** The abandoned manor stands on Діди: a house where
  no one waits for the dead. The game tells all of it as «кажуть», never as truth.

## 2. The story

The King drank from a cup sent from a manor the scribe can find in no list. The fortune teller
had seen it coming (the King drew the Moon at her table a week before) and explains it: the Crown
struck the manor from its lists long ago, when its governor swore to Veles instead of the Crown.
Every autumn, on Велесова ніч, the dead go home, and where no one waits for them Veles lays the
table himself; this year he called the King to it. The cure is «клин клином»: the fever from
Veles's cup is cured only by blood from Veles's yard — the hot blood of the rabid bats and rats
under his roof. The gate is open while the King is in fever. The fever breaks at nightfall on
Sunday; the manor goes dark until the next Велесова ніч.

**What the event adds to the lore, on the owner's word:** the name Veles and the legend above;
the dead as ATMOSPHERE only (the laid table, the candles) — the enemies are rabid animals, so the
Blight stays «not skeletal or demonic»; «Велес відпускає тих, кому ще не час» as why a player who
falls there wakes at home.

## 3. The schedule (Kyiv time, 2026)

| when | what |
|---|---|
| Sat 31.10, 09:00 | 📜 decree 1 |
| Sat 31.10, 12:00 | 🌑 the daily «new day» notice, themed for the day; the capital wears the holiday (`artFrom`): its pictures, the palace's empty throne, the square's raving windows |
| Sat 31.10, 14:00 | 📜 decree 2 |
| Sat 31.10, 16:00 | 📜 decree 3 |
| Sat 31.10, 18:00 | 🕯 the summons to the palace (one message); the manor opens — the story and the flask wait in the palace (§4.3) |
| Sun 01.11, 10:00 | 📜 the prize announcement (added 2026-11-01, the owner's text, §4.8) |
| Sun 01.11, 12:00 | 🌑 the daily notice, themed again |
| Sun 01.11, 18:00 | 👑 the finale; the manor closes |

The event shipped with the 2026-10-31 02:01 restart (`20f5681`). The times live in the data
(`events.json`), so `/reload` can move them; the TEXT is Lingo and needs a restart.

## 4. The copy (approved uk)

### 4.1 The decrees — tone «Марення, що темнішає»

> 📜 **Указ Його Величності.** Усім намісникам негайно перефарбувати місяць у зелене. Курей не будити.

> 📜 **Указ Його Величності.** Ведмедям заборонено ходити босоніж. Нетопирям — літати над палацом: вони рахують мої вікна. *Печатку поставлено догори дриґом.*

> 📜 **Указ Його Величності.** Мені холодно. Принесіть червоного. Ні. Не вина. *Літери скачуть, а підпис сповзає в риску.*

«Указ» is the word the palace's chain uses, so the parody is recognised; the real decree in the
palace does not change.

### 4.2 The noon notices

Saturday:
> 🌑 Новий день, та сонце з самого ранку світить, як у сутінках: бліде, низьке, і тіні від нього довші, ніж мали б бути.
> На Подолі ворожка сьогодні тасує карти довше, ніж звичайно.
> А на дошках Крамаря, Майстра й Шинкаря, як завжди, нові замовлення — їх треба взяти особисто.

Sunday:
> 🌑 Новий день, а сонце й далі світить, як у сутінках. У палаці кажуть, що жар у Короля не спадає.
> Ворожка попереджає: брама маєтку Велеса зачиниться разом із заходом сонця — сьогодні о 18:00. Хто ще хоче наповнити флягу — поспішайте.
> А на дошках Крамаря, Майстра й Шинкаря, як завжди, нові замовлення — їх треба взяти особисто.

*Changed 2026-10-31, the night before (the owner's pick of four):* Saturday's second line said «…ворожка
сьогодні не розкладає карт, лише каже кожному, хто зайде: «Сьогодні мертві йдуть додому. Не питайте, кого вони
покличуть до столу».» The fortune teller deals as usual all holiday, and a card that comes ready at noon is
announced in the SAME message, first («🔮 Карти знову готові — ворожка чекає вас у столиці.»), so the line
contradicted the line above it for everyone who drew on Friday afternoon (6 at 00:30). The owner took «тасує карти
довше, ніж звичайно» and struck the quote; closing the fortune teller for the day was offered and not taken.

Both keep the ordinary notice's job (and its «locked» tail for a carried job). The «18:00» is
printed from the data. Sunday's last sentence of the second line is the reader's flask (2026-10-30): a
player who has not collected it reads «Хто ще не забрав у палаці флягу — поспішайте.» instead.

### 4.3 The reveal — a summons at 18:00, the story in the palace (reworked 2026-10-30)

The owner (2026-10-30): the reveal should come when the player walks into the palace, and a flask has
to be collected to explain where it came from — so the player must be told to come for it. At 18:00 one
message goes to everyone:

> 🕯 **З палацу.** Гінці скачуть від маєтку до маєтку: писар скликає всіх намісників до палацу. Він дізнався, що з Королем.

In the palace, while the manor is open and the player has not taken the flask, two messages follow the
palace card (which stays as it is, the decree included) — on every visit until the flask is taken:

> 🕯 **Писар зачиняє за вами двері тронної зали.**
> Його Величність у гарячці з ночі на суботу, і всі ці укази — марення.
> У п'ятницю, на осінньому бенкеті, Королю піднесли кубок темного вина — дарунок із далекого маєтку. Писар не знайшов того маєтку в жодному списку. Король пожартував, що вино тепле, як кров, а вночі вже марив.
> Ворожка з Подолу сказала, що Король витягнув у неї карту Місяць, яка віщувала ілюзії, страх, тривогу та інтуїтивні сни.
> Маєток той Корона давно викреслила зі списків. Колись там жив Намісник, що присягнув не Короні, а Велесові — старому богові худоби й багатства, господареві мертвих. Маєток спорожнів. Та щоосені, у Велесову ніч, мертві йдуть додому, і там, де на них ніхто не чекає, стіл їм накриває сам Велес. Цього року він покликав до столу й Короля.

> 📜 **Писар знімає з полиці срібну флягу з печаткою Корони.**
> «Ліки ворожка назвала одні: клин клином — жар із Велесового кубка зніме лише кров із Велесового двору, кров, у якій теж горить жар. Кров скажених нетопирів і щурів, що живуть під його дахом.
> Покинутий маєток стоїть на 5-му кілометрі. Брама відчинена, доки Король у гарячці, а назад через неї ще ніхто не вийшов сам.
> Флягу носіть на поясі — смерть її не забере. Хто до неділі, 18:00, принесе найбільше крові, того Корона не забуде». **[🩸 Взяти флягу]**

The tap takes the button away (the words stay) and posts the banner:
> ✅ Срібна фляга з печаткою Корони тепер у вас на поясі. Маєток Велеса — на п'ятому кілометрі лісу, брама відчинена до неділі, 18:00.

*Changed 2026-10-31 at 17:30, before the opening (the owner's own rewrite, tried on the test bot):* the story's
first sentence stands on its own line; «У п'ятницю ввечері» → «У п'ятницю»; the fortune teller's sentence is its
own paragraph and names what the Moon foretold — «ілюзії, страх, тривогу та інтуїтивні сни», the card's own
meaning in the game; «намісник» → «Намісник». The scribe's first sentence on its own line and «на п'ятому
кілометрі» → «на 5-му кілометрі» (the other four lines keep «п'ятому»); the entrance question in three lines;
«За цей спуск» → «За цей похід» on the manor card and the death screen — «спуск» read like a cave. English
follows the same edits.

*Changed 2026-10-31, the night before (the owner's picks):* «Його Величність третю ніч у гарячці» → «…у гарячці з
ночі на суботу», and «На осінньому бенкеті» → «У п'ятницю ввечері, на осінньому бенкеті» — the King sat on his
throne all Friday and the palace is itself until Saturday noon, so «the third night» could not be true. Days of the
week, not «учора» / «минулої ночі»: the story is read from Saturday 18:00 to Sunday 18:00, and on Sunday «yesterday»
would put the feast on Saturday. A story told over a window must not say «yesterday».

What changed from the 10-29 text: the two messages moved from the 18:00 push into the palace; the
story's header «З палацу.» → «Писар зачиняє за вами двері тронної зали.»; the scribe's «Від писаря.» →
«Писар знімає з полиці срібну флягу з печаткою Корони.», his words in quotes, and «Кожному наміснику я
видав срібну флягу з печаткою Корони. Фляга висить на поясі, тож смерть її не забере.» → «Флягу носіть на
поясі — смерть її не забере.» The km-5 line (§4.4) and the Sunday sentence (§4.2) were picked in the
quiz; the button and the summons' text come from the sample the owner approved with «Давай зробимо це»
(in the quiz those two forms were left unanswered); the owner then struck the summons' «, і кожному приготував
срібну флягу з печаткою Корони» the same day — the flask is the palace's surprise.

### 4.4 The entrance — km 5 of an active walk, while the manor is open

> 🏚 За бур'яном проступає покинутий маєток. Ставок перед ним затягнуло ряскою, над водою схилилася стара верба, а у вікнах світиться, хоча там давно ніхто не живе. **[🕯 Увійти до маєтку]**

A walk without the flask (2026-10-30, the owner's pick) is shown the same manor with the way to the
palace in place of the button:
> 🏚 За бур'яном проступає покинутий маєток. … хоча там давно ніхто не живе.
> Брама прочинена, та писар кликав спершу до палацу — по срібну флягу. Без неї тут нема чого робити.

The confirmation (the tap edits the message; the bag list is `DeathWipe.takes`):
> 🕯 **Увійти до маєтку Велеса?**
> Брама зачиниться за вашою спиною: вийти не можна, лише вглиб, доки стоїте на ногах.
> Під дахом живуть скажені нетопирі й щури, і що глибше, то щедріша їхня кров.
> 🩸 Кров іде у флягу, а не в сумку. 🎒 Сумку смерть забере, як у лісі: 🥩 Сире м'ясо ×2. Одягнене лишається з вами. **[🕯 Увійти] [🌲 Лишитися в лісі]**

### 4.5 Inside

The screen (the line under the title changes with the room):
> 🏚 **Маєток Велеса · глибина 1.** Брама грюкнула за спиною. Подвір'я заросло бур'яном, а над ворітьми стайні прибиті бичачі роги.
> ❤️ 254/254 🍖 135/165 · 🩸 За цей похід: 0 · у флязі: 0

| room | depths | the line |
|---|---|---|
| подвір'я | 1–3 | Брама грюкнула за спиною. Подвір'я заросло бур'яном, а над ворітьми стайні прибиті бичачі роги. |
| світлиця | 4–6 | У світлиці накрито стіл: кутя в мисках ще тепла, біля кожної ложка — для тих, хто прийде. Стільці відсунуті, ніби гості щойно встали. |
| льох | 7–9 | Сходи ведуть у льох. Вода тут по кісточки і тепла, як кров, а з темряви долинає писк. |
| чорна вода | 10+ | Льох скінчився, а вода — ні. Вона чорна й не відбиває вашого обличчя. |

The walk's own keyboard stays: «🚶 Крок вперед» is the next creature, «🎒 Сумка» eats between
fights, «🔙 Крок назад» answers:
> Брама позаду зачинилася сама. Шлях один — углиб.

A fight has no flee button for any class. `/start` and stale buttons redraw the manor.

The encounter (each ends «Ваш хід?»), by room and creature:

| room | 🦇 Скажений нетопир | 🐀 Скажений щур |
|---|---|---|
| подвір'я | Зі стріхи стайні зривається **Скажений нетопир** і пікірує вам просто в обличчя. | З-під гнилих дощок стайні вилазить **Скажений щур** — завбільшки з кота, з піною на морді. |
| світлиця | Свічка на столі гасне, і з темряви вилітає **Скажений нетопир**. | Щось шкребеться за піччю — і звідти вискакує **Скажений щур**. |
| льох | Зі склепіння льоху зривається **Скажений нетопир**. | З темряви блищать дві червоні цятки — **Скажений щур** кидається вам до ніг. |
| чорна вода | Над чорною водою ляскають крила — **Скажений нетопир** уже тут. | Вода хлюпає: до вас пливе **Скажений щур**, і тільки очі блищать над чорнотою. |

The win:
> **Скажений нетопир** падає додолу. Кров стікає у флягу: 🩸 +4.

> **Скажений щур** перекидається й більше не ворушиться. Кров стікає у флягу: 🩸 +7.

**The find — «Велесовий гарбуз»** (2026-10-30, the owner's event and numbers; the text is the owner's pick of
three). One step deeper in ten turns it up instead of a creature, at that depth (the counter moves, there is no
fight and no blood there, the next creature is one deeper). It puts back a quarter of the maximum HP and of the
Vigor pool at once, capped at the maximum, and the line under it is a meal's receipt. Under a new room's line when
the step entered one; the archer of the walkthrough at depth 7:
> Сходи ведуть у льох. Вода тут по кісточки і тепла, як кров, а з темряви долинає писк.
>
> 🎃 Попереду в темряві жовтіє вогник — гарбуз із вирізаним обличчям, а в ньому тремтить свічка. Це **Велесовий гарбуз**. Кажуть, Велес дає гарбуза тим, кого ще не хоче бачити за своїм столом. Ви відламуєте шматок — м'якуш теплий і солодкий, ніби щойно з печі.
> ✅ +41 снаги (124/165), +51 ОЗ (133/204)
>
> 🏚 **Маєток Велеса · глибина 7.** ❤️ 133/204 🍖 124/165 · 🩸 За цей похід: 15 · у флязі: 15

«Дати гарбуза» is the old refusal of a suitor: Veles turns you away from his table, i.e. your time has not come —
the same «Велес відпускає тих, кому ще не час» as the death screen.

The death (the killing round's lines, as in the forest):
> 💀 **Ви полягли в маєтку Велеса.** Ви влучаєте — **Скажений нетопир** втрачає **43 ОЗ**. **Скажений нетопир** б'є у відповідь. Ви втрачаєте **12 ОЗ**. Свічки гаснуть одна за одною.
> 🩸 Фляга ціла: за цей похід +55, у флязі 55.
> Маєток забрав усе, що ви несли: 🥩 Сире м'ясо ×2
> Ви отямлюєтеся на порозі власного маєтку, ледь живі. Кажуть, Велес відпускає тих, кому ще не час.

### 4.6 The end

The finale, Sunday 18:00, to every player:
> 👑 **Король одужав!** Надвечір жар спав, і сонце знову сідало як слід. Його Величність попросив води, потім хліба, а потім — список тих, хто ходив до маєтку Велеса.
> 🥇 … — 412 🩸 · 🥈 … — 380 🩸 · 🥉 … — 301 🩸
> Ви принесли 96 🩸 — сьоме місце. Корона пам'ятає кожну краплю.
> Ворожка каже: щойно сонце сіло, світло у вікнах маєтку погасло, і він знову порожній — до наступної Велесової ночі.
> *Першим указом після хвороби Король скасував усі попередні. Крім чобіт для ведмедів.*

A player who never went in reads instead of «Ви принесли…»:
> Цього разу ви до маєтку не ходили. Наступна Велесова ніч — восени.

Whoever is still inside at the close is walked out:
> 🕯 Свічки у вікнах гаснуть одна за одною, стіни блякнуть, як туман, і ви стоїте серед бур'яну перед порожньою руїною на п'ятому кілометрі. 🩸 Фляга ціла.

An old entrance button after the close:
> 🏚 На п'ятому кілометрі — лише порожня руїна і стара верба над ставком. Ворожка казала — до наступної осені.

The board — the journal's «🏆 Рейтинги» gains «🩸 Кров для Короля», «Хто приніс найбільше крові
Його Величності»; a player with none reads «Ви ще не заходили до маєтку Велеса». *Superseded 2026-11-01:* the
top three's zlatnyks by hand gave way to the prizes of §4.8, handed out at the palace.

### 4.7 The capital while the King is ill (`artFrom` to close — 12:00 Saturday since 2026-10-31; the decrees alone go out from 09:00)

- 👑 the palace, from 12:00 Saturday with its picture (2026-10-31, the owner — before noon the palace is as usual): «Тронна зала порожня. Писар веде пальцем по списку й шепоче: «Його Величність у гарячці. Укази поки підписую я — так, як велів би він».»
- 🏛 the capital's welcome, from 12:00 Saturday with the square's picture (2026-10-31, the owner), ends «А з вікон палацу долинає марення.» instead of «…пильно спостерігає сам Король.» («ночами» struck 2026-10-31: at Saturday noon one night has passed)
- 🍺 the innkeeper (open to close): «Чули, наміснику? На п'ятому кілометрі у вікнах мертвого маєтку світиться. Кажуть, звідти не повертаються. Брешуть: повертаються — на порозі власного дому. Ха!»
- 🔮 the fortune teller (open to close): «Велесова ніч, наміснику. Мертві йдуть додому — а ви йдете до них.»

### 4.8 The prizes (added 2026-11-01, past midnight — the owner)

Read off the Pi at 00:53 Sunday: 12 flasks, 11 with blood, the most 666 🩸, median 42.

**The announcement** — the notice `prizes` (📜), Sunday 10:00 until the close, to every registered player. The
owner's own text, verbatim (an edit was offered and declined, but for the Druid, who became the fortune teller);
«18:00» is `%{close}`, the decrees' value, so it renders the same and moves with the data. **The numbers are typed
into it** (the owner's pick): the reward table must agree with it.
> 📜 **Оголошення Палацу**
>
> Життя нашого Короля висить на волосині — Король уже однією ногою за столом Велеса, і лише відданість та старання Намісників тримають його серед живих.
>
> Збір крові продовжується до 18:00, адже наявних запасів усе ще недостатньо для виготовлення ліків. Ворожка вже чаклує над відваром із крові Скажених створінь, а Палац оголошує про щедрі нагороди для всіх рятівників Корони:
>
> 🍽 Дарунок Короля: Кожен Намісник, який принесе бодай краплю крові скажених істот, отримає 5 Бенкетів Намісника.
> 🪙 Срібний фонд (Топ-10): Десятка найактивніших збирачів розділить між собою щедру королівську нагороду — від 100 до 1000 срібників.
> 👑 Королівська заслога (Топ-3): Трійці найвідданіших героїв буде вручено особливу валюту — Златники. Застосувати їх можна буде в Канцелярії, де вже готуються унікальні та достойні пропозиції.
>
> Поспішайте! Доля королівства у ваших руках!

**The rewards** (decided; ties share a place, the board's competition rank; a participant is a flask with blood > 0,
the board's and the finale's own definition):

| place | 🟡 zlatnyks | 🪙 silver | 🍽 «Бенкет Намісника» |
|---|---|---|---|
| 1 | 100 | 1,000 | 5 |
| 2 | 60 | 800 | 5 |
| 3 | 40 | 600 | 5 |
| 4 · 5 · 6 | — | 500 · 400 · 300 | 5 |
| 7 · 8 · 9 · 10 | — | 250 · 200 · 150 · 100 | 5 |
| 11 and below, with blood | — | — | 5 |

**Handed out in person at the palace after the close, with no expiry** (decided; NOT built — the owner: «Спершу текст
анонсу»). The sample shown, its copy a draft, not approved: a one-time «👑 Король кличе до палацу…» to the
participants; under the palace card the King's words, the place and blood («🥇 1-ше місце · 666 🩸») and a «💰» line;
«🎁 Отримати нагороду» pays in ONE transaction — a claimed marker on `event_blood` (a migration), the zlatnyks and
their announced marker together (the receipt names them, the watchman stays quiet), the silver through the player's
own cached `User`, the feasts into the bag after a fit check in units (the capital has no warehouse: no room → a modal,
nothing paid, the reward waits). Not by SQL: `users.silver` is a cached field a player's next silver tap would write
back, and a hand-inserted bag row skips the cap and is never announced. The table belongs in `events.json`, printed by
`spec events` and hashed by the digest.

## 5. The creatures and the numbers

**Two creatures, one at a time, 50/50 at every depth** — of the nine steps in ten that are not the pumpkin (§4.5). Both scale with the PLAYER's level — an
exception to «creature strength follows the estate tier», for the manor alone — and neither scales
with the estate:

- the depth-`d` creature is level `max(1, playerLevel − 8 + d)` (the first one seven below);
- 🦇 **Скажений нетопир** — the `skirmisher` contract at its level, HP and ATK × 0.7; **38 XP**
  (the eagle's, the forest's skirmisher at km 3–7); blood **⌈d / 2⌉**;
- 🐀 **Скажений щур** — the `normal` contract at its level, ×1.0; **57 XP** (×1.5, the owner's
  pick); blood **d**;
- no loot; a fight wears gear as a forest fight does; a kill counts as a beast for the decrees
  and the jobs; hunger works as in the forest.

The lines and the blood, printed by the code that draws them (no estate scaling; crit and dodge are
ratings):

<!-- generated: swift run roi-content spec events -->
**veles_night_2026** — prelude 2026-10-31T09:00:00+02:00 · pictures from 2026-10-31T12:00:00+02:00 · opens 2026-10-31T18:00:00+02:00 · closes 2026-11-01T18:00:00+02:00 · the manor at km 5 · a depth-d creature is level max(1, player − 8 + d)

| level | 🦇 bat (`skirmisher` ×0.7 HP, ×0.7 ATK) | 🐀 rat (`normal` ×1 HP, ×1 ATK) |
|---|---|---|
| 1 | ❤️43 · АТК 11 · ЗАХ 7 · крит 17 · ухил. 18 | ❤️78 · АТК 10 · ЗАХ 14 · крит 6 · ухил. 3 |
| 3 | ❤️54 · АТК 12 · ЗАХ 10 · крит 19 · ухил. 20 | ❤️101 · АТК 12 · ЗАХ 18 · крит 7 · ухил. 3 |
| 5 | ❤️67 · АТК 14 · ЗАХ 12 · крит 21 · ухил. 23 | ❤️123 · АТК 14 · ЗАХ 22 · крит 8 · ухил. 4 |
| 7 | ❤️78 · АТК 15 · ЗАХ 14 · крит 23 · ухил. 26 | ❤️146 · АТК 16 · ЗАХ 26 · крит 8 · ухил. 4 |
| 9 | ❤️90 · АТК 18 · ЗАХ 16 · крит 26 · ухил. 29 | ❤️168 · АТК 18 · ЗАХ 30 · крит 9 · ухил. 4 |
| 11 | ❤️104 · АТК 20 · ЗАХ 18 · крит 28 · ухил. 31 | ❤️191 · АТК 20 · ЗАХ 34 · крит 10 · ухил. 5 |
| 13 | ❤️114 · АТК 21 · ЗАХ 21 · крит 30 · ухил. 34 | ❤️212 · АТК 22 · ЗАХ 38 · крит 10 · ухил. 5 |
| 15 | ❤️128 · АТК 23 · ЗАХ 23 · крит 32 · ухил. 37 | ❤️236 · АТК 23 · ЗАХ 42 · крит 11 · ухил. 6 |
| 17 | ❤️139 · АТК 25 · ЗАХ 25 · крит 34 · ухил. 40 | ❤️257 · АТК 25 · ЗАХ 46 · крит 12 · ухил. 6 |
| 19 | ❤️153 · АТК 27 · ЗАХ 27 · крит 36 · ухил. 42 | ❤️280 · АТК 27 · ЗАХ 50 · крит 13 · ухил. 7 |
| 21 | ❤️165 · АТК 29 · ЗАХ 29 · крит 38 · ухил. 45 | ❤️302 · АТК 29 · ЗАХ 54 · крит 13 · ухил. 7 |
| 25 | ❤️189 · АТК 32 · ЗАХ 34 · крит 42 · ухил. 51 | ❤️348 · АТК 32 · ЗАХ 62 · крит 15 · ухил. 8 |
| 30 | ❤️221 · АТК 36 · ЗАХ 39 · крит 47 · ухил. 58 | ❤️405 · АТК 37 · ЗАХ 72 · крит 16 · ухил. 9 |
| 40 | ❤️284 · АТК 46 · ЗАХ 50 · крит 57 · ухил. 71 | ❤️520 · АТК 46 · ЗАХ 92 · крит 20 · ухил. 11 |

| depth | 🦇 🩸 (÷2, ⌈⌉) · 38 XP | 🐀 🩸 (÷1, ⌈⌉) · 57 XP |
|---|---|---|
| 1 | 1 | 1 |
| 2 | 1 | 2 |
| 3 | 2 | 3 |
| 4 | 2 | 4 |
| 5 | 3 | 5 |
| 6 | 3 | 6 |
| 7 | 4 | 7 |
| 8 | 4 | 8 |
| 9 | 5 | 9 |
| 10 | 5 | 10 |
| 11 | 6 | 11 |
| 12 | 6 | 12 |

| find (in a creature's place) | chance a step | ❤️ back, of the maximum | 🍖 back, of the pool |
|---|---|---|---|
| 🎃 pumpkin | 10% | 25% | 25% |
<!-- /generated -->

A rat costs about twice a bat's HP per fight and half as many taps again (Надійка L13 against an
on-level one: the bat 41 HP in 4 taps, the rat 75 in 7) — hence twice the blood.

A descent, 50/50, full HP, Vigor = pool − 30, no food, attack plus a sure-kill Defend, 4,000 runs (measured
2026-10-29, before the pumpkin: one step in ten is a find now, so a descent runs a little deeper than this):

| player | creatures | 🩸 per descent |
|---|---|---|
| ODARKA L1 | 3.9 | 8 |
| НеБармен L3 | 5.3 | 13 |
| Leyfor L5 | 5.6 | 14 |
| Нястюшка L9 | 5.7 | 15 |
| Надійка L13 | 8.0 | 28 |
| Володимир L19 | 6.9 | 21 |

Rats deal 61–66% of the deaths. Rejected for the rat, with the reasons the owner was shown: the
same rat biting 20% harder (a weaker player dies to one on-level rat in 14–16% of fights) and a
"big bat" (the skirmisher at 100%: no variety, up to 18%).

## 6. Rejected along the way

A cave at km 10 (became the manor at km 5); the riddles of the master, the double from the black
water, doors at every depth and the unkillable old she-bat (the owner: «Залишаємо як є»); the
Sunday midway news with the top three; the arena's blind rounds (needs the class special, which
newcomers at km 5 lack) and dice at the table (luck, and a dice message cannot be deleted for
24 h); the oak (Perun's tree); the cracked charm of the Crown (it would explain a mystery the lore
keeps, and make the fever the Blight in a human).

Sources: [Veles (god) — Wikipedia](https://en.wikipedia.org/wiki/Veles_(god)) ·
[Did Slavic people have a Halloween? — The Vlasta](https://thevlasta.substack.com/p/did-slavic-people-have-a-halloween) ·
[Суспільне Херсон](https://suspilne.media/kherson/870243-gellovin-po-ukrainski-ak-hersonci-vidsvatkuvali-velesovu-nic/) ·
[LIGA.net](https://life.liga.net/en/poyasnennya/article/veles-night-where-the-roots-of-ukrainian-halloween-come-from-and-whether-our-ancestors-celebrated-it)

## 7. How it was built (2026-10-29), and what the build decided on its own

- **Data:** `content/data/events.json` (schema v29) — the window, the entrance km, the level offset,
  the creatures (archetype, scales, XP, blood divisor, weight), the rooms, the notices (`at`,
  `until`, kind, icon) and the two noon days. Validated by `ContentValidator.validateEvents`; every
  key the event prints is `EventKeys.required`, required in both locales and rendered through the
  same functions.
- **Maths:** `EventMath` (ROISim) — the level, the line, the blood, the weighted pick. Every level's
  line is solved once at install (`GameEvent`), never inside a fight.
- **State:** a descent is the walk's own row (`exploration_state.manor_event_id`, `manor_depth`,
  `manor_run_blood`, `manor_offered`); the flask is `event_blood`, one row per player per holiday;
  a notice sent is `event_notices`, written before the push. A fight's creature is
  `event:<event>:<creature>:<level>` (`EventCreatureRef`), read back by
  `ExplorationState.combatEnemy(for:)` like every fight.
- **Screens:** `ExplorationController+Manor` (the entrance, the gate's question, the step, the
  refusal, the close), `CombatController` (no flee button and a typed flee refused, the room's intro,
  the kill, the manor's death), the watchman (`RestNotificationService+Events`), the blood board
  (`LeaderboardBoard.blood`, its tab once a holiday has opened), the capital's four lines.

Decided in the build, not asked — each is small and reversible:
- **A room's line is said when a step enters the room,** above the creature's entrance, not under
  every card: the yard's «Брама грюкнула за спиною…» repeated after each of three fights read as the
  gate slamming three times. The gate's own screen (depth 0) carries the yard's line under
  «Маєток Велеса.» (`manor.gate`); the card after a fight is the title, HP and the flask.
- **A step deeper costs the walk's Vigor** (`walkRoom`, 2) and hunger bites on a step begun at 0 —
  the forest's rules; the depth is not a km, so the lifetime km tally is untouched.
- **A fight that outlasts the close pays no blood:** the gate shut at the hour the finale names. The
  win still stands (`combat.victory`), and the player is walked out under it.
- **New lines nobody approved,** because the flow needed them: the entrance tapped away from km 5
  (an alert, «Маєток стоїть на %{km} км стежки — дійдіть туди, і брама буде поруч.»); the gate's
  question with an empty bag («Сумка порожня. Одягнене лишається з вами.»); the manor's death with an
  empty bag («Сумка була порожня, тож маєток нічого не забрав.»); «Лишитися в лісі» puts the entrance
  back as it was. The finale's place is written «7-ме місце» (`PlaceOrdinal`).
- **The km is in the copy as a word** («на п'ятому кілометрі»), as approved. `entranceKm` moved by
  `/reload` would leave it wrong: change both together, and the text needs a restart.
- **The two noon notices** keep the ordinary notice's «locked» tail for a carried job.

**The rework (2026-10-30)** — the reveal in the palace and the flask collected there (§4.3):
- **The flask is the `event_blood` row**, made empty by «🩸 Взяти флягу» (`EventBlood.issueFlask`); the
  board and the finale already read only `total > 0`. A pour into a flask never issued still makes the
  row, because a pour must never lose blood.
- **The gate asks for it**: `ManorService.refusal(…, hasFlask:)` → `.noFlask`; `offerManorIfDue` shows a
  walk without it the entrance with `entrance.no_flask` and no button, once per walk.
- **Screens:** `CapitalController+Flask` (the story and the scribe after the palace card, the tap);
  the button's callback `event:flask:<event>` is claimed in `MainController.onCallbackQuery`, because
  every router hands its unknown callbacks there and that dispatcher's default deletes the message.
- **Decided in the build, not asked:** the story repeats on every palace visit until the flask is
  taken (no "seen" marker); the button works wherever it is tapped while the manor is open (the offer
  was made in the palace — a player who rode home first has still come for it), and in a forest fight
  the tap only redraws the fight, as every callback there does; a second scribe's button under a
  repeated story goes quiet (stripped, no banner); after the close the button is stripped with the
  `entrance.gone` alert; English is written to the same pattern and not approved.

**The pumpkin (2026-10-30, the same day)** — `events.json` → `finds` (an optional list, so a holiday without one
says nothing): id, icon, `chance` a step, `hpShare` / `vigorShare` of the maximum. `EventMath.pickFind` gives each
find a slice of a `0 ..< 1` roll from 0 up, the rest is the creatures'; `EventMath.restore` is the share rounded half
up and capped at the room left. `ManorService.step` draws it after the stride's Vigor and the hunger tick and before
the creatures; the controller shows its lines above the manor card (`findLead`) — with no room's line since
2026-10-31 (the owner's cut: a pumpkin on the step into a new room speaks alone). Five validator rules
(`event.find_chance`, `event.find_share`, `event.find_restores_nothing`, `event.finds_crowd_out_creatures`, plus the
id, icon and duplicate rules), each with a failing test; `spec events` prints the finds; the digest hashes them.
Decided in the build, not asked: hunger that kills comes first (a dead player finds nothing); a step that began
starving prints its hunger line above the find, whose receipt already counts it; the receipt adds «снага повна» /
«здоров'я повне» when a pool topped out, as a meal's does; the find costs the stride's Vigor like any step; no XP.

**The art (2026-10-30, the owner's three pictures — «Всі ці картинки тільки на час івенту»)** —
`Assets/events/veles_night_2026/`: `capital.jpg` (the capital map with pumpkins; the map is one image in three
files, so it replaces the square's `welcome.jpg` AND both `street_<id>.jpg`), `palace.jpg` (the empty throne,
the scribe with his book — the palace card from 12:00 Saturday, and «Тронна зала порожня» with it: asked, the
owner moved the palace's line to noon rather than write it under the King still on his throne), `manor.jpg` (the
manor across its pond — the manor's first screen, sent as the player steps through the gate, its caption the
gate's card, 188 of 1,024 in uk, 210 in en; no manor screen is ever edited in place). `EventArt.path` picks a
holiday's file from its `artFrom` to the close, and only when the file exists; otherwise every screen keeps its
usual art. *Changed 2026-10-31, the night before:* it was the whole prelude, from 09:00 — the owner: «Картинки
івентові повинні з'являтись не о 9, а о 12». `artFrom` is data (`events.json`, optional: absent = the prelude),
`event.art_window` refuses one outside preludeAt ≤ artFrom < endsAt, and `spec events` prints it. A slot is a screen, so the next holiday drops its own files into `Assets/events/<id>/` and needs no
code. The manor picture shows the approach (the pond, the willow, the lit windows — the km-5 entrance's words);
the gate screen it sits on speaks of the yard. Told to the owner, not changed.
