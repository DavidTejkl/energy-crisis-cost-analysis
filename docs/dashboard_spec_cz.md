# Specifikace reportu v Power BI

[English](dashboard_spec.md) · **Čeština**

Tady popisuju, jak jsem report postavil a proč takhle. Požadavky a uživatelské příběhy jsou v
[requirements_cz.md](requirements_cz.md), vzorce všech ukazatelů a měr DAX v [kpi_definitions_cz.md](kpi_definitions_cz.md).

## Cíl

Finanční ředitel, nákupčí energie nebo člověk bez znalosti energetiky má ze stránky Shrnutí do půl minuty pochopit,
kolik krize firmu stála a proč. Důkazy k tomu najde na čtyřech dalších stránkách.

## Příběh reportu

Report má 6 stránek. Nadpis každé stránky je závěr, takže kdo si přečte jen nadpisy, zná celý výsledek.

| # | Stránka | Otázka čtenáře | Nadpis stránky |
|---|---|---|---|
| 1 | O projektu | O čem report je a jak vznikl? | „Kolik stála energetická krize 2021–2023 průmyslovou firmu a dalo se jí bránit?“ |
| 2 | Shrnutí | Co se stalo a co to znamená? | „Krize 2021–2023 stála firmu 385 mil. Kč místo 136 mil. při cenách roku 2020, tedy 248 mil. Kč navíc“ |
| 3 | Trh | Co se dělo na trhu? | „Krize začala na podzim 2021 a v roce 2022 byla elektřina 7× dražší než v roce 2020“ |
| 4 | Náklad firmy | Kolik za elektřinu firma zaplatila a za co? | „2020–2022: náklad vzrostl ze 45 na 201 mil. Kč, regulované platby zůstaly kolem 19 mil.“ |
| 5 | Příčiny změny | Proč se náklad změnil? | „2022: růst o 106 mil. Kč způsobila cena na trhu, silnější koruna ušetřila 7 mil. Kč“ |
| 6 | Zajištění ceny | Vyplatí se koupit elektřinu předem? | „Plné zajištění by v r. 2022 ušetřilo 4,1 mil. EUR, v r. 2023 by stejnou částku stálo navíc“ |

Pořadí odpovídá tomu, jak by to vysvětloval analytik: nejdřív souvislosti a výsledek, potom trh, firma, příčiny a
nakonec co s tím dělat. Shrnutí jsem stavěl až nakonec, z hotových detailních stránek.

## Pravidla pro všechny stránky

**Rozložení**
- Plátno 1280 × 720 (16 : 9). Všechny stránky mají stejnou šablonu, takže se ji čtenář naučí jednou.
- Záhlaví je grafitový obdélník se zaoblenými rohy a mátovým horním okrajem (dva obdélníky přes sebe, mátový je o 4 px
  vyšší). Vlevo je nadpis, pod ním podnadpis, vpravo výběr roku.
- Nadpis je závěr napsaný jako věta a je pevný. Dynamický nadpis podle roku jsem zvažoval a nepoužil, protože grafy na
  stránce porovnávají roky a vybraný rok ukazují karty. Pevný nadpis proto musí platit pro každý rok, který jde vybrat,
  nebo musí říct, pro jaké období platí (například „2020–2022: …“). Každý nadpis jsem před použitím ověřil v SQL.
- Podnadpis tvoří otázka stránky, zdroje dat a označení simulovaného odběru.
- Detailní stránky mají pod záhlavím tři karty KPI a vedle nich rámeček „Co to znamená“ se dvěma až třemi větami pro
  finančního ředitele. Pod nimi je hlavní graf a nejvýš dva další vizuály.
- Každá karta má nad sebou mátový pruh 4 px (stejná technika jako záhlaví). Pod hlavní hodnotou karty je srovnávací
  řádek, například „Minulý rok“. Nová vizualizace karty neumí na tento řádek dát pevný text, proto jsou srovnávací řádky
  textové míry.
- Peníze na kartách ukazuju v mil. Kč nebo mil. EUR přes samostatné míry „(mil. Kč)“, protože karta neumí nastavit
  jednotky hlavní hodnoty. Míry v Kč zůstávají pro výpočty a popisky.

**Výběr roku a interakce**
- Každá detailní stránka má vlastní výběr roku (průřez ve stylu záložek). Průřezy nejsou synchronizované, protože stránky
  Příčiny změny a Zajištění ceny nabízejí jen roky 2021–2024 (rok 2020 nemá předchozí rok). Všechny stránky jsou uložené
  na roce 2022.
- Výběr roku filtruje karty. Grafy, které porovnávají roky, ukazují vždy celé období a výběr roku je nefiltruje.
  Kliknutí do grafu nefiltruje karty (interakce „Žádné“), jinak by se karty vyprázdnily nebo by ukázaly jiný rok než
  výběr roku.
- Stránka O projektu má navigaci na všechny stránky. Ostatní stránky mají vlevo dole tlačítko „Zpět na úvod“
  (x 24, y 690, 109 × 26). V Power BI Desktop tlačítka reagují na Ctrl + klik, v publikovaném reportu na obyčejný klik.

**Barvy** (motiv `powerbi/theme/energy_crisis_theme_g.json`, každá barva má jeden význam)

| Barva | Hex | Význam | Kde |
|---|---|---|---|
| Grafit | `#1E1F22` | rám | záhlaví, rámečky „Co to znamená“, tlačítka |
| Jantarová | `#D97706` | náklad, růst, problém | náklad na silovou elektřinu, tržní cena, růst ve vodopádu, extrémní pásmo |
| Modrozelená | `#0D9488` | pokles, úspora | pokles ve vodopádu, pásmo záporných cen |
| Mátová | `#5EDD92` | akcent rámu | horní okraj záhlaví a karet, vybraný rok, text tlačítek |
| Šedé | `#B5BBC4`, `#D7DBE0` a další | všechno ostatní | regulované platby, průměr trhu, náklad bez zajištění |
| Pozadí / karty | `#F3F4F6` / `#FFFFFF` | | |
| Text / tlumený text | `#1E1F22` / `#6B7280` | | čísla a popisky |

- Žádná červená a zelená vedle sebe (asi 8 % mužů barvy nerozliší). Jantarová a modrozelená projdou kontrolou pro
  barvoslepé (ΔE 12,5, cíl aspoň 8). Čistá zelená vedle jantarové by neprošla.
- Mátová nikdy v grafu ani jako text na bílém, protože má kontrast jen 1,7 : 1.
- Celkové řádky v tabulkách jsou šedé, nikdy zelené, protože zelená znamená úsporu.

**Jazyk a měna**
- Všechno, co uživatel vidí, je česky: nadpisy, popisky os, názvy měr a jejich popisy. Uživatelé ve scénáři jsou
  český finanční ředitel a energetik. Tabulky a sloupce mají anglické názvy ze SQL (technická vrstva).
- Na jedné stránce je jedna měna. Stránky 1–5 jsou v Kč, protože firma platí v korunách a cenová pásma jsou definovaná
  v Kč. Stránka Zajištění ceny je v EUR, protože elektřina se na burze obchoduje v EUR/MWh.
- Na stránce jsou jednoduchá slova (například „přirážka za diagram odběru“, „koupit předem“), přesná definice je v
  popisu míry a v [kpi_definitions_cz.md](kpi_definitions_cz.md).

**Důvěryhodnost**
- Tržní data jsou skutečná (FACT). Všechno, co stojí na odběru firmy, je SIMULOVANÉ a podnadpis to říká. Pevná cena pro
  zajištění je PŘEDPOKLAD ([ADR-003](decisions/ADR-003-forward-price-proxy_cz.md)).
- Patička se zdroji dat, rozdělením na skutečná a simulovaná data a poznámkou „bez DPH a bez marže dodavatele“ je na
  stránkách O projektu a Shrnutí.
- Každé číslo v reportu jsem 23. 11. 2026 porovnal s čerstvým výsledkem SQL, pro každý rok a na stránce
  Zajištění ceny i pro polohy posuvníku 0, 50 a 100 %. Kontrolní hodnoty jsou níže u každé stránky.

### Šablona stránky

```
┌────────────────────────────────────────────────────────────────────────┐
│ NADPIS = ZÁVĚR (věta)                              [2021 2022 2023 …]  │
│ podnadpis = otázka · zdroje · simulovaný odběr                         │
├──────────────┬──────────────┬──────────────┬───────────────────────────┤
│ karta KPI    │ karta KPI    │ karta KPI    │ CO TO ZNAMENÁ             │
│ srovnání     │ srovnání     │ srovnání     │ 2–3 věty                  │
├──────────────┴──────────────┴──────────────┴───────────────────────────┤
│ HLAVNÍ GRAF                                                            │
├───────────────────────────────────┬────────────────────────────────────┤
│ DALŠÍ VIZUÁL                      │ DALŠÍ VIZUÁL (nepovinný)           │
├───────────────────────────────────┴────────────────────────────────────┤
│ [Zpět na úvod]                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

## Stránka O projektu

**K čemu je:** první stránka, kterou čtenář otevře. Říká, o čem report je, na jaké otázky odpovídá, jak vznikl, a
umožní skočit na kteroukoli stránku. Nemá grafy.

**Vzhled:** světlá stránka s grafitovým záhlavím jako ostatní stránky. Každý blok je bílý rámeček s šedým okrajem
`#D7DBE0` a se stejným mátovým horním okrajem jako karty. Nadpisy bloků 12 pt tučně grafitově, text 10 pt.

| Blok | Poloha (x, y, š × v) | Obsah |
|---|---|---|
| Záhlaví | 24, 20, 1232 × 72 | nadpis a podnadpis „Analýza nákladů na elektřinu modelové české firmy · 2020–2024 · zdroje OTE, ČNB, ERÚ“ |
| O čem report je | 24, 107, 1232 × 125 | jeden odstavec celými větami: denní trh OTE, silová elektřina a regulované platby (ty stanovuje ERÚ a zákon, firma je nemůže vyjednat), přirážka za diagram odběru, co ukazuje stránka Zajištění ceny |
| Na co report odpovídá | 24, 248, 608 × 140 | čtyři obchodní otázky ze zadání |
| Proč je to důležité | 648, 248, 608 × 140 | tržní cena 2022 7× vyšší než 2020, náklad firmy ze 45 na 201 mil. Kč, riziko rozpočtu pro finančního ředitele, rozhodnutí nákupu |
| Postup projektu | 24, 404, 1232 × 150 | pět odrážek: Data (Python), Databáze (SQL Server), Analýza (SQL), Report (Power BI), Ověřitelnost |
| Navigace stránek | 24, 570, 1232 × 44 | vestavěná navigace. Vybraná stránka grafitová s mátovým textem a okrajem, ostatní bílé s grafitovým textem |
| Patička | 24, 652, 1232 × 60 | skutečná a simulovaná data, ceny bez DPH a marže, zajištění s náhradní cenou, autor a odkaz na repozitář |

**Kontrola:** čísla v textu pocházejí z dřívějších kontrol. 7× = 6 083 / 887 Kč/MWh (stránka Trh), 45 a 201 mil. Kč
(dotaz 08), 7 tabulek a 43 848 hodin (načtení), 18 automatických testů kvality dat (jeden běh v `dq_results`),
9 analytických dotazů (04–12), 6 ADR.

## Stránka Shrnutí

**Otázka:** kolik krize firmu stála, proč a co to znamená pro další rok?
**Pro koho:** všichni, hlavně finanční ředitel. Bere hlavní čísla ze všech detailních stránek. **Měna:** Kč.
**Výběr roku:** žádný, stránka vypráví celé období 2020–2024.

**Nadpis a podnadpis:** nadpis říká, kolik krize stála navíc. Podnadpis ukazuje výpočet, aby šel ověřit:
„Skutečný náklad: 95,72 + 200,92 + 87,93 = 384,57 mil. Kč · Při cenách roku 2020 (levný covidový rok, horní odhad):
3 × 45,46 = 136,39 mil. Kč“. Rok 2020 byl kvůli covidu levný, proto je to horní odhad.

### Karty

Shrnutí nesmí opakovat karty detailních stránek. Proto ukazuje extrémy celého období a regulované platby, které jinde
na kartě nejsou.

| Karta | Hodnota | Srovnávací řádek | Kontrola v SQL |
|---|---|---|---|
| Nejdražší měsíc celkově (mil. Kč) | 32,30 | Srpen 2022 · 12,75 Kč/kWh | `vw_monthly_cost`, nejvyšší `total_cost_czk` = 32 303 995,75 Kč, / 2 533,293 MWh = 12,75 Kč/kWh |
| Nejlevnější měsíc celkově (mil. Kč) | 2,91 | Duben 2020 (Covid) · 1,20 Kč/kWh | nejnižší = 2 911 201,48 Kč, / 2 433,427 MWh = 1,20 Kč/kWh |
| Nejdražší den (mil. Kč) | 1,66 | 30. 8. 2022 · pouze silová elektřina | `vw_hourly_cost` po dnech, nejdražší den 1 657 482,83 Kč |
| Regulované platby 2022 (mil. Kč) | 18,97 | 2024: 31,28 mil. Kč · 1,6× více | `vw_monthly_cost`, rok 2022 a 2024 |

Karty porovnávají měsíce, ne dny. Nejlevnější den (13. 4. 2020) má záporný náklad na silovou elektřinu (−28 460 Kč),
takže by poměr nedával smysl, a měsíc odpovídá jedné faktuře. Den je jen silová elektřina, protože regulované platby
existují jen po měsících. Měsíc a den ve srovnávacích řádcích jsou pevný text, protože stránka nemá výběr roku a data
2020–2024 se nemění.

### Textové rámečky

Místo jednoho rámečku „Co to znamená“ má Shrnutí tři rámečky s odrážkami (400 × 160):
1. **Příčina růstu nákladu:** v r. 2022 vzrostl náklad na silovou elektřinu o 105,8 mil. Kč, z toho 104,8 mil. Kč
   způsobila cena na trhu. Cena na trhu byla téměř 7× vyšší než v r. 2020, silová elektřina tvořila 91 % nákladu,
   silnější koruna ušetřila 7,0 mil. Kč.
2. **Rizika po skončení krize:** v r. 2024 byl náklad 94,8 mil. Kč, tedy 2,1× víc než v r. 2020. Cena na trhu byla
   stále 2,4× vyšší a regulované platby vzrostly na 31,3 mil. Kč. Tuto část nákup předem nezajistí.
3. **Doporučení** (RECOMMENDATION): fixovat jen část odběru (plná fixace ušetřila v r. 2022 4,1 mil. EUR a v r. 2023
   je prodělala, dotaz 12), nakupovat postupně (roční produkt na rok 2023 stál v srpnu 2022 984 EUR/MWh a v prosinci
   2022 242 EUR/MWh, [ADR-003](decisions/ADR-003-forward-price-proxy_cz.md)), přesunout část odběru mimo špičku
   (přirážka za diagram odběru 11,9 mil. Kč v r. 2022).

Do doporučení jsem dal jen to, co projekt opravdu spočítal. Zajištění kurzu tam není, protože jsem ho nepočítal.

### Graf

| Vizuál | Typ | Osa a hodnoty | Interakce | Barvy | Nadpis grafu |
|---|---|---|---|---|---|
| Náklad po letech | skládaný sloupcový | rok (kategorická osa), silová elektřina a regulované platby, součty v mil. Kč | nefiltruje nic | silová elektřina jantarová, regulované platby šedé | „Náklad na elektřinu po letech (mil. Kč)“ |

Graf nefiltruje karty ani rámečky. Jinak by kliknutí na rok 2020 změnilo hodnotu karty, zatímco pevný srovnávací řádek
by pořád říkal „Srpen 2022“.

**Kontrola:** součty 45,5 · 95,7 · 200,9 · 87,9 · 94,8 mil. Kč (dotaz 08), mimo krizi 384,57 − 136,39 = 248,18 mil. Kč.

## Stránka Trh

**Otázka:** jak extrémní byl trh s elektřinou v jednotlivých letech?
**Pro koho:** nákup energie (US-06.1, US-06.2). **Data:** skutečná (OTE, ČNB). **Měna:** Kč.

### Karty (vybraný rok)

| Karta | Míra | Srovnávací řádek | Kontrola 2022 |
|---|---|---|---|
| Průměrná tržní cena (Kč/MWh) | `Průměrná tržní cena (Kč/MWh)` | Minulý rok | 6 083 (2021: 2 570) |
| Extrémní hodiny | `Extrémní hodiny` | Podíl roku | 3 694 (42,2 %) |
| Nejdražší hodina (Kč/MWh) | `Nejvyšší hodinová cena (Kč/MWh)` | datum a hodina | 21 422 (29. 8. 2022, hodina 20) |

### Co to znamená

V r. 2022 byla elektřina na trhu 7× dražší než v r. 2020 a extrémní cenu (od 5 821 Kč/MWh) mělo 42 % hodin. Pracovní
dny od 8 do 20 h byly v r. 2022 o 1 472 Kč/MWh dražší než noci a víkendy. Od r. 2023 ceny klesly o 60–65 %, extrémní
hodiny se ale znovu objevily (prosinec 2024).

### Grafy

| Vizuál | Typ | Osa a hodnoty | Výběr roku | Barvy | Nadpis grafu |
|---|---|---|---|---|---|
| Vývoj ceny | spojnicový, lineární | `dim_date[month_start]`, 60 měsíců, průměrná tržní cena, osa od 0 | ne, graf nic nefiltruje | jantarová čára | „Tržní ceny se v letech 2021–2022 znásobily a v roce 2023 výrazně klesly“ |
| Hodiny podle cenových pásem | 100% skládaný pruhový | rok × cenové pásmo, `Počet hodin` | ne, graf nic nefiltruje | modrozelená, světle modrozelená, šedá, světle jantarová, jantarová (od záporné po extrémní) | „Extrémních hodin přibylo z 0 % v roce 2020 na 42 % v roce 2022“ |
| Nejdražší hodiny | tabulka | den, hodina, cena, prvních 5 podle `hour_key` | ano | | „Nejdražší hodiny vybraného roku“ |

Čára je jantarová, protože tržní cena je problém, o kterém stránka je (šedá byla jako jediná řada moc slabá). Pásma jsou
seřazená od záporných po extrémní přes pomocný sloupec `price_band_order`. Tři odstíny šedé nešly rozlišit, proto
stupnice modrozelená, šedá, jantarová.

**Kontrola:** extrémní hodiny 0 / 577 / 3 694 / 30 / 84 (0,0 / 6,6 / 42,2 / 0,3 / 1,0 %), pásma každého roku dají
dohromady hodiny roku (2022: 8 760), nejdražší hodiny všech let a rozdíl 1 471,75 Kč/MWh sedí s dotazy 05, 07 a 09.
Extrémní hodiny 2021 po měsících 0 (leden až srpen), 1, 78, 155, 343 ukazují, že krize začala na podzim 2021.

## Stránka Náklad firmy

**Otázka:** kolik firma za elektřinu zaplatila a za co?
**Pro koho:** finanční ředitel (US-01, US-05). **Data:** odběr SIMULOVANÝ, ceny a tarify skutečné. **Měna:** Kč.

### Karty (vybraný rok)

| Karta | Míra | Srovnávací řádek | Kontrola 2022 |
|---|---|---|---|
| Celkový náklad za rok (mil. Kč) | `Celkový náklad na elektřinu (mil. Kč)` | Minulý rok | 200,92 (2021: 95,72) |
| Celková cena (Kč/kWh) | `Celková cena elektřiny (Kč/kWh)` | Minulý rok | 7,19 (2021: 3,42) |
| Přirážka za diagram (mil. Kč) | `Přirážka za diagram odběru (mil. Kč)` | Přirážka za MWh | 11,92 (426,45 Kč/MWh) |

### Co to znamená

V r. 2022 stála elektřina firmu 200,9 mil. Kč, 4,4× víc než v r. 2020. 91 % nákladu tvořila silová elektřina z trhu,
regulované platby se skoro nezměnily. Firma bere nejvíc elektřiny ve dne, kdy je dražší, a to ji v r. 2022 stálo
11,9 mil. Kč navíc. V r. 2024 vzrostly regulované platby na 31 mil. Kč (dražší síť a systémové služby, návrat POZE).

### Grafy

| Vizuál | Typ | Osa a hodnoty | Výběr roku | Barvy | Nadpis grafu |
|---|---|---|---|---|---|
| Náklad po měsících | skládaný sloupcový, součty v mil. Kč | 12 měsíců vybraného roku, `Náklad na silovou elektřinu (Kč)` a `Regulované platby (Kč)` | ano | silová elektřina jantarová, regulované platby šedé | „Náklad na elektřinu po měsících (mil. Kč)“ |
| Cena firmy proti průměru trhu | seskupený sloupcový | rok, průměrná tržní cena a cena firmy (Kč/MWh) | ne | cena firmy jantarová, průměr trhu šedý | „Průměrná tržní cena vs. cena firmy (Kč/MWh)“ |

Po najetí myší na měsíc se ukáže rozklad na silovou elektřinu a regulované platby. Podnadpis druhého grafu vysvětluje,
že rozdíl mezi sloupci je přirážka za diagram odběru.

**Proč takhle:** první verze měsíčního grafu měla 60 měsíců a čtyři části nákladu. Regulované platby jsou asi
1,5 mil. Kč měsíčně proti až 31 mil. Kč za silovou elektřinu, takže tři tenké šedé proužky nešly rozlišit. Spojil jsem
je do jedné řady a graf jsem napojil na výběr roku, aby se osa přizpůsobila jednomu roku. Graf cen porovnává roky, proto
se výběrem roku nefiltruje. Oba grafy nefiltrují karty (kliknutí do grafu jinak karty vyprázdnilo).

**Kontrola:** všech 60 měsíčních součtů sedí s `vw_monthly_cost` (silová elektřina + regulované platby = celkový náklad,
rozdíl 0,00 Kč), srpen 2022 32,3 mil. Kč, ceny trhu a firmy 887/947 · 2 570/2 720 · 6 083/6 509 · 2 416/2 550 ·
2 138/2 266 Kč/MWh. Regulované platby 18,91 / 19,58 / 18,97 / 16,67 / 31,28 mil. Kč, proto nadpis platí jen pro
2020–2022 a říká to.

## Stránka Příčiny změny

**Otázka:** proč se náklad na silovou elektřinu změnil proti minulému roku? Kvůli ceně na trhu, spotřebě, diagramu
odběru, nebo kurzu?
**Pro koho:** finanční ředitel (US-02, US-03). **Data:** vliv spotřeby a diagramu odběru je SIMULOVANÝ. **Měna:** Kč.
**Výběr roku:** 2021–2024 (rok 2020 nemá s čím srovnat).

**Metoda:** jeden vodopád v Kč odpovídá na obě otázky. [ADR-004](decisions/ADR-004-cost-variance-split_cz.md) rozkládá
změnu nákladu v EUR na spotřebu, cenu na trhu a diagram odběru. [ADR-006](decisions/ADR-006-fx-effect-split_cz.md)
oceňuje změnu v EUR kurzem minulého roku a zbytek je vliv kurzu. Každý vliv v EUR krát efektivní kurz minulého roku dá
stejný vliv v Kč. Kroky jsou v pohledu `vw_cost_change_steps` s českými názvy (`step_name`) a pořadím (`step_order`).

### Karty (změna z minulého roku do vybraného roku)

| Karta | Míra | Srovnávací řádek | Kontrola 2022 |
|---|---|---|---|
| Silová el. – změna (mil. Kč) | `Změna nákladu na silovou elektřinu (mil. Kč)` | Proti minulému roku | +105,82 (+139,0 %) |
| Vliv ceny na trhu (mil. Kč) | `Vliv ceny na trhu (mil. Kč)` | tržní cena loni a letos | +104,75 (2 570 a 6 083 Kč/MWh) |
| Vliv kurzu (mil. Kč) | `Vliv kurzu (mil. Kč)` | kurz EUR/CZK loni a letos | −6,98 (25,65 a 24,56) |

První karta je jen silová elektřina (celkový náklad vzrostl o 105,20 mil. Kč, regulované platby o −0,62 mil. Kč),
proto má v názvu „Silová el.“.

### Co to znamená

V r. 2022 vzrostl náklad o 105,8 mil. Kč a téměř celý růst způsobila cena na trhu (+104,8 mil.). Odběr ve dne, kdy je
elektřina dražší, přidal 8,2 mil., silnější koruna ubrala 7,0 mil. V letech 2023–2024 cena klesla a náklad s ní.
Hlavní riziko je cena na trhu. Nákup předem ho nezruší, jen rozloží do delšího období.

### Grafy

| Vizuál | Typ | Osa a hodnoty | Výběr roku | Barvy | Nadpis grafu |
|---|---|---|---|---|---|
| Vodopád | vodopád | spotřeba, cena na trhu, diagram odběru, kurz EUR/CZK, celkem, v mil. Kč na 2 desetinná místa | ano | růst jantarový, pokles modrozelený, celkem šedý | „Co změnilo náklad na silovou elektřinu oproti minulému roku (mil. Kč)“ |
| Změna podle let | matice | krok × rok 2021–2024, mil. Kč, šedý celkový řádek | ne | | „Změna nákladu podle let (mil. Kč)“ |

Pod vodopádem je poznámka „Spotřeba ≈ 0. Simulovaný odběr je každý rok stejný (28 GWh / rok)“.

**Proč takhle:** vestavěný vodopád barví sloupce jen jako růst, pokles a celkem, takže počáteční sloupec „Náklad minulý
rok“ nejde udělat šedý (vypadal by jako jantarový růst od nuly). Proto ho ve vizuálu odfiltruju, vodopád ukazuje jen
změnu a absolutní náklad je na kartě. Krok „Spotřeba“ jsem nechal, i když je skoro nula, protože jinak by součet
nesouhlasil a otázka „změnila se spotřeba?“ k analýze patří. Druhý vizuál je matice, protože čtyři vlivy velmi
rozdílné velikosti nešly ve sloupcích přečíst a matice dá přesná čísla.

**Kontrola:** 2022: −0,11 + 104,75 + 8,16 − 6,98 = +105,82 mil. Kč (dotaz 11). Součet kroků sedí se změnou v každém roce
s rozdílem do 2 Kč (zaokrouhlení efektivního kurzu). Změny 2021–2024 +49,58 / +105,82 / −110,70 / −7,70 mil. Kč.

## Stránka Zajištění ceny

**Otázka:** jakou část spotřeby na příští rok koupit předem za pevnou cenu?
**Pro koho:** nákup energie a finanční ředitel (US-04). **Data:** SIMULOVANÝ odběr, PŘEDPOKLAD pevné ceny.
**Měna:** EUR. **Ovládání:** výběr roku 2021–2024 a posuvník „Podíl zajištění“ 0–100 % po 25 %, výchozí 50 %.
Krok 25 % stačí, protože náklad roste s podílem lineárně a každá poloha má kontrolní hodnotu v dotazu 12.

### Karty (vybraný rok a podíl)

| Karta | Míra | Srovnávací řádek | Kontrola 2022 při 50 % |
|---|---|---|---|
| Bez zajištění (mil. EUR) | `Náklad na silovou elektřinu bez zajištění (mil. EUR)` | Celý odběr za cenu z trhu | 7,40 |
| Se zajištěním (mil. EUR) | `Náklad na silovou elektřinu se zajištěním - proxy (mil. EUR)` | Oproti bez zajištění | 5,35 (−2,05) |
| Za cenu PXE (mil. EUR) | `Náklad na silovou elektřinu se zajištěním - PXE (mil. EUR)` | Oproti bez zajištění | 7,04 (−0,36) |

Pro rok 2021 chybí cena PXE, karta PXE proto ukazuje „--“, a ne náklad bez zajištění.

### Co to znamená

Bez zajištění zaplatila firma v r. 2022 7,40 mil. EUR. S polovinou elektřiny koupenou předem by to bylo 5,35 mil.,
ale v r. 2023 by zaplatila 5,02 mil. místo 2,97, protože fixovala drahou cenu z krize. Zajištění náklad nesnižuje,
rozloží ho do dvou let a dává firmě čas připravit se. Za burzovní cenu PXE by úspora v r. 2022 byla jen 0,36 mil.

### Rámeček s metodou

Vedle posuvníku je rámeček „Jak zajištění funguje“: firma během roku postupně nakoupí část elektřiny na příští rok za
pevnou cenu, kupuje stejné množství na každou hodinu a zbytek platí za cenu z trhu. Pevná cena je průměrná tržní cena
předchozího roku (předpoklad, odpovídá postupnému nákupu). Karta PXE ukazuje pro srovnání poslední cenu ročního produktu
na pražské burze z konce předchozího roku. Rámeček také vysvětluje, proč chybí rok 2020 a PXE 2021.

### Graf

| Vizuál | Typ | Osa a hodnoty | Výběr roku / posuvník | Barvy | Nadpis grafu |
|---|---|---|---|---|---|
| Náklad po letech | spojnicový, lineární, se značkami, osa od 0 | rok 2021–2024, náklad bez zajištění a se zajištěním (mil. EUR) | výběr roku ne, posuvník ano | bez zajištění šedá, se zajištěním jantarová | „Náklad bez zajištění a se zajištěním po letech (mil. EUR)“ |

**Proč takhle:** zkoušel jsem graf nákladu podle podílu, ale náklad je v podílu lineární, takže jen opakoval karty.
Seskupené sloupce vypadaly stejně jako graf na stránce Náklad firmy. Pásový graf skládá obě varianty na sebe, takže jeho
výška nic neznamená. Spojnicový graf ukazuje to hlavní: čáry se mezi roky 2022 a 2023 překříží, protože zajištění
posune krizi o rok. Kartu se součtem za 2021–2024 jsem vypustil, protože součet přes roky ten posun schová.

**Kontrola** (dotaz 12, v mil. EUR, roky 2021–2024): při 50 % se zajištěním 2,04 / 5,35 / 5,02 / 2,75, PXE – / 7,04 /
4,95 / 2,72. Při 100 % 1,11 / 3,30 / 7,07 / 2,97, PXE – / 6,69 / 6,92 / 2,92. Při 0 % se zajištěním = bez zajištění
(2022: 7 399 949,24 EUR). Nadpis: výsledek plného zajištění 2022 −4,10 a 2023 +4,10 mil. EUR.

## Sdílení reportu

- [docs/report/energy_crisis_cost_analysis_report_final.pdf](report/energy_crisis_cost_analysis_report_final.pdf):
  export všech 6 stránek (výběr roku na 2022, posuvník na 50 %).
- [docs/screenshots/report/](screenshots/report/): obrázky stránek `report_01_o_projektu.png` až
  `report_06_zajisteni_ceny.png`, vykreslené z PDF.
- [docs/report/energy_crisis_cost_analysis_demo_1920.mp4](report/energy_crisis_cost_analysis_demo_1920.mp4): záznam
  obrazovky publikovaného reportu (2 min 15 s, 1920 × 1080, 7,2 MB, pod limitem 10 MB pro video v README na GitHubu).
- Veřejný odkaz (Publikovat na web, bez přihlášení) je ze zkušební licence Power BI Pro. Funguje jen, dokud mám licenci
  Pro (zkušební verze končí kolem 22. 1. 2027). PDF, obrázky a video jsou trvalý způsob, jak report ukázat. Soubor
  `.pbix` s načtenými daty přiložím k vydání na GitHubu (v gitu není).

## Zdroje dat pro Power BI

**Zdroj je databáze SQL Server `EnergyCrisisCostAnalysis`, režim Import.** Power BI nikdy nečte soubory CSV. Databáze
je jediný zdroj pravdy: má klíče, testy kvality dat a pohledy, jejichž čísla jsem ověřil v SQL. Vrstva „gold“ jsou tedy
pohledy níže, ne složka souborů. Po spuštění pipeline stačí v Power BI jednou Aktualizovat.

| Tabulka modelu | Zdroj v SQL | Granularita (1 řádek =) | Řádků | Kde se používá |
|---|---|---|---|---|
| `dim_date` | tabulka `dim_date` + sloupec DAX `month_start` | 1 den | 1 827 | všechny stránky (výběr roku, osa měsíců) |
| `dim_hour` | tabulka `dim_hour` | 1 hodina dne | 25 | Trh (špička, nejdražší hodiny) |
| `vw_hourly_cost` | pohled: cena EUR a Kč, kurz, odběr, náklad EUR a Kč, cenové pásmo | 1 hodina | 43 848 | Shrnutí, Trh, Náklad firmy |
| `vw_monthly_cost` | pohled z dotazu 08: silová elektřina, regulované platby, pevné platby, POZE, celkem | 1 měsíc | 60 | Shrnutí, Náklad firmy |
| `vw_cost_change_steps` | pohled z dotazů 10 a 11: náklad minulý rok a čtyři kroky změny | 1 rok a 1 krok | 20 | Příčiny změny |
| `vw_yearly_hedging` | pohled z dotazu 12: náklad, rozdíl při zajištění za náhradní cenu a za cenu PXE | 1 rok | 4 | Zajištění ceny |
| `Podíl zajištění` | parametr „co když“ (GENERATESERIES 0–1 po 0,25), bez vazby | 1 podíl | 5 | Zajištění ceny |

- Vazby: `dim_date` 1 : N na každý fakt přes `date_key`, `dim_hour` 1 : N na hodinový fakt přes `hour_of_day`, vždy
  jedním směrem (5 vazeb, žádná mezi fakty). Měsíční a roční pohledy mají `date_key` prvního dne měsíce nebo roku, takže
  je filtruje stejný výběr roku. Několik faktů se stejnými dimenzemi je hvězdicové schéma s více fakty (galaxy).
- Automatické datum a čas je vypnuté a `dim_date` je označená jako tabulka kalendáře.
- Ceny se nikdy neukládají jako průměry. Každá cena v reportu je míra DAX jako podíl dvou součtů (náklad / spotřeba),
  takže platí pro jakýkoli filtr. Sloupce, jejichž součet nedává smysl (ceny, kurzy, rok, měsíc), mají nastaveno
  „Nesumarizovat“.
- Logika nad obdobími platnosti (regulované tarify) a meziroční rozklady zůstávají v SQL, kde jsem je otestoval. DAX
  dělá součty, podíly a výpočet zajištění podle posuvníku.
- `vw_energy_prices_czk` a `vw_daily_summary` neimportuju. Hodinový pohled obsahuje obojí v jemnější granularitě a dvě
  tabulky se stejným obsahem by mohly dát dvě různé odpovědi.
