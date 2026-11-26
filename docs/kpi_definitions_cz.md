# Definice KPI a míry DAX

[English](kpi_definitions.md) · **Čeština**

Tady mám popsané všechny ukazatele (KPI), se kterými pracují dotazy a report. U každého píšu, na jakou otázku
odpovídá, jak ho počítám, jak ho číst a kde má slabiny. Na konci je tabulka všech měr DAX z Power BI se vzorcem
a kontrolní hodnotou z SQL.

Všechny částky jsou bez DPH. Ceny a kurzy jsou skutečná data, odběr firmy je simulovaný (`SIMULATED`, viz
[metodika](methodology_cz.md)).

## Cenové pásmo

- **Otázka:** kolik hodin v roce mělo zápornou, nízkou, běžnou, vysokou a extrémní cenu a jak se tenhle poměr změnil
  během energetické krize 2021–2023?
- **Co měří:** každou hodinu zařadím podle ceny denního trhu v Kč/MWh do jednoho z pěti pásem. Hranice jsou stejné pro
  všechny roky, takže roky porovnávám jedním metrem.

  | Pásmo    | Kč/MWh          | Odkud hranice je |
  | -------- | --------------- | ---------------- |
  | záporná  | < 0             | znaménko ceny    |
  | nízká    | 0 až < 1 217    | P25              |
  | běžná    | 1 217 až < 3 374 | P25 až P75      |
  | vysoká   | 3 374 až < 5 821 | P75 až P90      |
  | extrémní | ≥ 5 821         | P90              |

  Dolní hranice do pásma patří, horní už ne. Každá hodina tak spadne právě do jednoho pásma.
- **Výpočet:** `price_czk_mwh` z pohledu `dbo.vw_energy_prices_czk` ([sql/03_create_views.sql](../sql/03_create_views.sql)),
  pásmo přiřazuje `CASE WHEN` v [sql/05_query_price_bands.sql](../sql/05_query_price_bands.sql). Pro Power BI je stejné
  pásmo ve sloupci `vw_hourly_cost[price_band]`.
- **Jednotka a období:** Kč/MWh, jeden řádek na hodinu dodávky (`date_key`, `hour_of_day`).
- **Co se počítá a co ne:** všech 43 848 hodin 2020–2024, nic nevyřazuji.
- **Jak to číst:** když roste podíl vysokých a extrémních hodin, nákup je dražší a hůř se plánuje. Když přibývá
  záporných hodin, jsou na trhu období přebytku (například polední fotovoltaika), která by mohl využít pružný odběr.
- **Omezení:**
  - Hranice jsou percentily celého období 2020–2024 (spočítané 29. 9. 2026) zaokrouhlené na celé koruny. Kdybych přidal
    další roky, posunuly by se. Pak je přepočítám a tabulku upravím vědomě, nikdy potichu.
  - V nízkém pásmu je méně než 25 % hodin, protože 609 záporných hodin počítám zvlášť. Hodiny s nulovou cenou (88)
    patří do nízkého pásma.
  - Je to jen cena na trhu, ne celková cena, kterou firma platí. Distribuce, poplatky a daň se přičítají až později.

  Použité percentily (Kč/MWh, 43 848 hodin): min −3 459,73 · P10 664,22 · P25 1 217,42 · P50 2 152,42 · P75 3 374,10 ·
  P90 5 820,77 · max 21 422,25. Kontrola počítáním: 4 385 hodin pod P10, 21 924 pod P50, 4 385 nad P90.

  ```sql
  SELECT DISTINCT
      MIN(price_czk_mwh) OVER ()                                            AS min_czk,
      PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY price_czk_mwh) OVER () AS p10_czk,
      PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price_czk_mwh) OVER () AS p25_czk,
      PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY price_czk_mwh) OVER () AS p50_czk,
      PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price_czk_mwh) OVER () AS p75_czk,
      PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY price_czk_mwh) OVER () AS p90_czk,
      MAX(price_czk_mwh) OVER ()                                            AS max_czk
  FROM dbo.vw_energy_prices_czk;
  ```

## Průměrná tržní cena

- **Otázka:** jak drahá byla elektřina na trhu v daném roce nebo měsíci?
- **Co měří:** prostý průměr hodinových cen denního trhu, každá hodina má stejnou váhu. Je to cenová hladina trhu, ne
  to, co platila firma. To ukazuje cena vážená odběrem na stránce Náklad firmy.
- **Výpočet:** `AVG(price_czk_mwh)` přes hodiny období (`vw_energy_prices_czk`). V Power BI
  `AVERAGE(vw_hourly_cost[price_czk_mwh])` přes hodinové řádky, takže pro jakékoli období vyjde součet cen dělený počtem
  hodin, nikdy průměr z denních průměrů. Verze v EUR: `AVG(price_eur_mwh)`.
- **Jednotka a období:** Kč/MWh. Karta na stránce Trh ukazuje vybraný rok, čárový graf měsíce.
- **Co se počítá a co ne:** všechny hodiny, i záporné a nulové ceny. Jsou to platné ceny trhu.
- **Jak to číst:** Kč/MWh 2020 886,55 · 2021 2 570,35 · 2022 6 082,84 · 2023 2 416,13 · 2024 2 138,04 (spočítáno
  3. 11. 2026). EUR/MWh 33,62 · 100,66 · 247,43 · 100,79 · 85,11. V korunách byl rok 2022 2,4× dražší než 2021
  a 6,9× dražší než 2020.
- **Omezení:** jen cena na trhu, bez regulovaných složek a bez vlivu toho, kdy firma odebírá.

## Extrémní hodiny

- **Otázka:** jak často trh dosáhl krizových cen?
- **Co měří:** počet hodin v pásmu „extrémní“ (od 5 821 Kč/MWh, viz Cenové pásmo). Srovnávací řádek na kartě ukazuje,
  jaký je to podíl ze všech hodin roku.
- **Výpočet:** počet hodin s `price_czk_mwh >= 5821` ([sql/05_query_price_bands.sql](../sql/05_query_price_bands.sql)).
  V Power BI filtruji na pásmo `extrémní`. Podíl = extrémní hodiny / všechny hodiny roku.
- **Jednotka a období:** hodiny za rok.
- **Co se počítá a co ne:** nic nevyřazuji.
- **Jak to číst:** 2020 0 · 2021 577 · 2022 3 694 · 2023 30 · 2024 84 hodin. Hodně extrémních hodin znamená, že
  nakupovat všechno jen na spotu je riskantní.
- **Omezení:** hranice je v korunách, takže hodinu přes hranici může posunout i kurz EUR/CZK.

## Nejvyšší hodinová cena

- **Otázka:** jak vysoko trh vyskočil v nejhorší hodině?
- **Co měří:** nejvyšší hodinovou cenu denního trhu v období, s datem a hodinou.
- **Výpočet:** `MAX(price_czk_mwh)` z `vw_energy_prices_czk`. Datum a hodinu najde `RANK() ... = 1`
  v [sql/07_query_top_hours.sql](../sql/07_query_top_hours.sql).
- **Jednotka a období:** Kč/MWh, jedna hodina dodávky.
- **Co se počítá a co ne:** nic nevyřazuji.
- **Jak to číst:** 29. 8. 2022, hodina 20 = 21 422,25 Kč/MWh. 12. 12. 2024, hodina 18 = 21 170,65 Kč/MWh, v době
  Dunkelflaute v Německu (viz [Kvalita dat](../README_cz.md#kvalita-dat)). Hodina 20 znamená dodávku 19:00–20:00.
- **Omezení:** jedna hodina o nákladu moc neřekne. Ukazuje, jak velké je riziko, ne jak často nastává.

## Rozdíl špička – mimo špičku

- **Otázka:** o kolik je elektřina levnější v noci a o víkendu než v pracovní době?
- **Co měří:** průměrnou cenu hodin ve špičce minus průměrnou cenu hodin mimo špičku. Špička je pondělí až pátek,
  dodávka 08:00–20:00 (`hour_of_day` 9–20, `is_weekend = 0`), stejně jako u produktu peak load na burzách PXE a EEX.
  Mimo špičku jsou všechny ostatní hodiny. Svátky ve všední den počítám jako špičku (`ASSUMPTION`).
- **Výpočet:** `AVG(CASE WHEN špička THEN cena END) − AVG(CASE WHEN mimo špičku THEN cena END)`
  ([sql/09_query_peak_offpeak.sql](../sql/09_query_peak_offpeak.sql)).
- **Jednotka a období:** Kč/MWh za rok.
- **Co se počítá a co ne:** nic nevyřazuji.
- **Jak to číst:** Kč/MWh 2020 330,09 · 2021 858,42 · 2022 1 471,75 · 2023 526,54 · 2024 374,52 (EUR/MWh 12,53 ·
  33,71 · 60,04 · 21,82 · 14,89). Je to horní hranice toho, kolik by mohla ušetřit jedna MWh přesunutá ze špičky mimo
  ni. Kolik firma skutečně platí navíc, ukazuje přirážka za diagram odběru. V reportu je rozdíl 1 472 Kč/MWh v textu
  „Co to znamená“ na stránce Trh.
- **Omezení:** prosté průměry přes hodiny, bez kalendáře svátků.

## Celkový náklad na elektřinu

- **Otázka:** kolik firma zaplatila za elektřinu za měsíc nebo za rok?
- **Co měří:** silová elektřina + regulované platby podle spotřeby (použití sítě, systémové služby, daň z elektřiny)
  + pevné měsíční platby (rezervovaná kapacita, poplatky OTE) + POZE. Bez DPH a bez marže dodavatele
  ([ADR-005](decisions/ADR-005-all-in-price-scope_cz.md)).
- **Výpočet:** `total_cost_czk` v [sql/08_query_allin_price.sql](../sql/08_query_allin_price.sql). Silová elektřina
  = `SUM(load_mwh × price_czk_mwh)` po hodinách, regulované složky připojuji podle období platnosti
  (`regulated_price`).
- **Jednotka a období:** Kč. Dotaz 08 počítá po měsících, rok je součet měsíců.
- **Co se počítá a co ne:** rezervovaná kapacita 5 MW (`ASSUMPTION` scénáře). Cenový strop 2023 nikdy nezabral
  (ADR-005).
- **Jak to číst:** 2020 45,46 · 2021 95,72 · 2022 200,92 · 2023 87,93 · 2024 94,84 mil. Kč.
- **Omezení:** simulovaný odběr a žádná marže dodavatele. Skutečné faktury by se lišily.

## Celková cena

- **Otázka:** kolik firmu doopravdy stála jedna kWh, se vším všudy?
- **Co měří:** celkový náklad na elektřinu dělený spotřebovanou energií.
- **Výpočet:** `total_cost_czk / (SUM(load_mwh) × 1000)` (`allin_price_czk_kwh` v
  [sql/08_query_allin_price.sql](../sql/08_query_allin_price.sql)). V Power BI `DIVIDE(celkový náklad, spotřeba) / 1000`,
  tedy součet dělený součtem.
- **Jednotka a období:** Kč/kWh, měsíc nebo rok.
- **Co se počítá a co ne:** stejné jako u celkového nákladu.
- **Jak to číst:** 2020 1,6208 · 2021 3,4193 · 2022 7,1878 · 2023 3,1461 · 2024 3,3807 Kč/kWh. Dá se porovnat s cenou
  za kWh na faktuře (bez DPH a marže).
- **Omezení:** simulovaný odběr. Pevné platby zvedají cenu za kWh v měsících s nízkou spotřebou.

## Podíl silové elektřiny

- **Otázka:** jakou část nákladu určuje trh a jakou regulace?
- **Co měří:** náklad na silovou elektřinu dělený celkovým nákladem na elektřinu. Zbytek je regulovaná část.
- **Výpočet:** `power_cost_czk / total_cost_czk` z [sql/08_query_allin_price.sql](../sql/08_query_allin_price.sql).
- **Jednotka a období:** %, rok.
- **Co se počítá a co ne:** stejné jako u celkového nákladu.
- **Jak to číst:** 2020 58,4 · 2021 79,5 · 2022 90,6 · 2023 81,0 · 2024 67,0 %. Vysoký podíl znamená, že rozpočet
  závisí na ceně na trhu, a proto má smysl řešit zajištění ceny.
- **Omezení:** simulovaný odběr.

## Přirážka za diagram odběru

- **Otázka:** kolik firma platí navíc, protože bere víc elektřiny v drahých hodinách?
- **Co měří:** cenu silové elektřiny váženou odběrem (co firma zaplatila za MWh) minus prostý průměr trhu ve stejných
  hodinách. Celková přirážka = přirážka za MWh × spotřebované MWh. Je to částka, kterou firma zaplatila navíc proti
  tomu, kdyby stejné množství odebírala rovnoměrně za průměrnou cenu trhu. Tuhle část nákladu může firma ovlivnit tím,
  že přesune odběr do levnějších hodin.
- **Výpočet:** za MWh `S = SUM(load × price) / SUM(load) − AVG(price)`, celkem
  `C − V × Pb = SUM(load × price) − SUM(load) × AVG(price)` ([ADR-004](decisions/ADR-004-cost-variance-split_cz.md)).
  Stránka Náklad firmy počítá s cenami v Kč (`price_czk_mwh`), dotaz 10 v EUR. Kontrolní dotaz (spuštěno 3. 11. 2026):

  ```sql
  SELECT d.year,
         SUM(l.load_mwh * p.price_czk_mwh) / SUM(l.load_mwh) - AVG(p.price_czk_mwh) AS s_czk_mwh,
         SUM(l.load_mwh * p.price_czk_mwh) - SUM(l.load_mwh) * AVG(p.price_czk_mwh) AS premium_czk
  FROM dbo.vw_energy_prices_czk p
  JOIN dbo.fact_load l ON l.date_key = p.date_key AND l.hour_of_day = p.hour_of_day
  JOIN dbo.dim_date d ON d.date_key = p.date_key
  GROUP BY d.year
  ORDER BY d.year;
  ```
- **Jednotka a období:** Kč/MWh a Kč za rok.
- **Co se počítá a co ne:** nic nevyřazuji.
- **Jak to číst:** Kč/MWh 2020 59,99 · 2021 149,30 · 2022 426,45 · 2023 133,52 · 2024 127,53. Celkem 1,68 · 4,18 ·
  11,92 · 3,73 · 3,58 mil. Kč. V EUR (dotaz 10) je to v roce 2022 +17,29 EUR/MWh a 483 332,58 EUR. Roční náklad na
  silovou elektřinu ze stejného dotazu dá za 5 let 419 457 499 Kč, stejně jako dotazy 08 a 11. Zajištění typu base load
  přirážku neodstraní ([sql/12_query_hedging.sql](../sql/12_query_hedging.sql)).
- **Omezení:** diagram odběru je simulovaný. Částky v Kč a v EUR se liší o trochu víc, než by vysvětlil jeden roční
  kurz, protože každou hodinu převádím kurzem jejího dne. Přes víc let se přirážka nesčítá, protože průměr trhu se pak
  počítá za celé období. Proto ji ukazuji po letech (viz poznámky k mírám DAX).

## Změna nákladu na silovou elektřinu

- **Otázka:** o kolik víc nebo méně firma zaplatila za silovou elektřinu než v předchozím roce?
- **Co měří:** náklad na silovou elektřinu v Kč ve vybraném roce minus předchozí rok. Regulované platby do toho nepatří,
  ty jsou na stránce Náklad firmy.
- **Výpočet:** `C_czk1 − C_czk0`, kde `C_czk = SUM(load_mwh × price_czk_mwh)` za rok
  ([sql/11_query_fx_effect.sql](../sql/11_query_fx_effect.sql)).
- **Jednotka a období:** Kč, meziročně 2021–2024.
- **Co se počítá a co ne:** nic nevyřazuji.
- **Jak to číst:** 2021 +49,58 · 2022 +105,82 · 2023 −110,70 · 2024 −7,70 mil. Kč.
- **Omezení:** simulovaný odběr.

## Vliv ceny na trhu, spotřeby a diagramu odběru

Tyhle tři vlivy rozkládají změnu nákladu na silovou elektřinu na příčiny. Na stránce Příčiny změny je ukazuji jako
jeden vodopádový graf v Kč.

- **Otázka:** jaká část změny přišla z hladiny cen na trhu, jaká ze spotřebovaného množství a jaká z toho, kdy firma
  odebírala?
- **Co měří:** rozklad podle [ADR-004](decisions/ADR-004-cost-variance-split_cz.md), oceněný efektivním kurzem
  předchozího roku `R0` podle [ADR-006](decisions/ADR-006-fx-effect-split_cz.md):
  - vliv spotřeby `(V1 − V0) × Pw0 × R0`: víc nebo méně MWh za loňskou cenu firmy
  - vliv ceny na trhu `V1 × (Pb1 − Pb0) × R0`: posunul se prostý průměr trhu
  - vliv diagramu odběru `V1 × (S1 − S0) × R0`: změnila se přirážka za odběr v drahých hodinách (`S = Pw − Pb`, viz
    Přirážka za diagram odběru)

  Všechny tři dohromady dají vliv komodity z dotazu 11, tedy `(C_eur1 − C_eur0) × R0`.
- **Výpočet:** vlivy v EUR jsou v [sql/10_query_variance_split.sql](../sql/10_query_variance_split.sql), `R0`
  v [sql/11_query_fx_effect.sql](../sql/11_query_fx_effect.sql). Pro Power BI jsou kroky vodopádu v pohledu
  `vw_cost_change_steps`. Kontrolní dotaz pro vodopád v Kč (spuštěno 3. 11. 2026):

  ```sql
  WITH yearly AS (
      SELECT d.year,
             SUM(l.load_mwh) AS v,
             SUM(l.load_mwh * p.price_eur_mwh) AS c_eur,
             SUM(l.load_mwh * p.price_czk_mwh) AS c_czk,
             AVG(p.price_eur_mwh) AS pb
      FROM dbo.vw_energy_prices_czk p
      JOIN dbo.fact_load l ON l.date_key = p.date_key AND l.hour_of_day = p.hour_of_day
      JOIN dbo.dim_date d ON d.date_key = p.date_key
      GROUP BY d.year
  ), derived AS (
      SELECT year, v, c_eur, c_czk, pb,
             c_eur / NULLIF(v, 0) AS pw,
             c_eur / NULLIF(v, 0) - pb AS s,
             c_czk / NULLIF(c_eur, 0) AS r
      FROM yearly
  ), prev AS (
      SELECT *, LAG(v) OVER (ORDER BY year) AS v0, LAG(c_eur) OVER (ORDER BY year) AS c_eur0,
             LAG(c_czk) OVER (ORDER BY year) AS c_czk0, LAG(pb) OVER (ORDER BY year) AS pb0,
             LAG(pw) OVER (ORDER BY year) AS pw0, LAG(s) OVER (ORDER BY year) AS s0,
             LAG(r) OVER (ORDER BY year) AS r0
      FROM derived
  )
  SELECT year,
         c_czk0                 AS cost_prev_czk,
         (v - v0) * pw0 * r0    AS volume_czk,
         v * (pb - pb0) * r0    AS market_price_czk,
         v * (s - s0) * r0      AS load_profile_czk,
         c_eur * (r - r0)       AS rate_czk,
         c_czk                  AS cost_czk,
         c_czk - c_czk0 - ((v - v0) * pw0 * r0 + v * (pb - pb0) * r0 + v * (s - s0) * r0 + c_eur * (r - r0))
                                AS check_czk
  FROM prev
  WHERE v0 IS NOT NULL
  ORDER BY year;
  ```
- **Jednotka a období:** Kč, meziročně 2021–2024.
- **Co se počítá a co ne:** nic nevyřazuji.
- **Jak to číst** (mil. Kč, spuštěno 3. 11. 2026):

  | Rok  | Spotřeba | Cena na trhu | Diagram odběru |  Kurz | Kontrola (Kč) |
  | ---- | -------: | -----------: | -------------: | ----: | ------------: |
  | 2021 |    −0,05 |       +49,55 |          +2,68 | −2,60 |          1,52 |
  | 2022 |    −0,11 |      +104,75 |          +8,16 | −6,98 |         −0,62 |
  | 2023 |    −0,03 |      −100,78 |          −8,06 | −1,82 |          1,31 |
  | 2024 |    +0,27 |       −10,55 |          −0,33 | +2,91 |         −1,80 |

  Spotřeba + cena na trhu + diagram odběru = vliv komodity z dotazu 11 (2022: 112,80 mil. Kč). Kontrola nevychází
  přesně 0 kvůli zaokrouhlení efektivního kurzu.
- **Omezení:** vliv spotřeby a diagramu odběru je simulovaný. Simulovaná spotřeba je každý rok skoro stejná, proto
  vliv spotřeby vychází téměř nulový už z principu. Pořadí rozkladu (spotřeba, cena, diagram) mění velikost
  jednotlivých částí, ne jejich součet (ADR-004).

## Vliv kurzu

- **Otázka:** pomohl kurz EUR/CZK nákladu v korunách, nebo ho zhoršil?
- **Co měří:** část změny nákladu v Kč, kterou způsobil pohyb efektivního kurzu EUR/CZK proti předchozímu roku
  (`R = C_czk / C_eur`, kurz vážený nákladem): `C_eur1 × (R1 − R0)`
  ([ADR-006](decisions/ADR-006-fx-effect-split_cz.md)). Záporný vliv znamená, že silnější koruna elektřinu zlevnila.
- **Výpočet:** `fx_effect_czk` v [sql/11_query_fx_effect.sql](../sql/11_query_fx_effect.sql).
- **Jednotka a období:** Kč, meziročně 2021–2024.
- **Co se počítá a co ne:** nic nevyřazuji.
- **Jak to číst:** 2021 −2,60 · 2022 −6,98 · 2023 −1,82 · 2024 +2,91 mil. Kč. V roce 2022 koruna vyrovnala 6,2 % růstu
  nákladu za komoditu.
- **Omezení:** efektivní kurz váží dny podle nákladu, proto se trochu liší od prostého ročního průměru kurzu ČNB. Na
  kartě na stránce Příčiny změny je pro představu prostý průměr kurzu (u roku 2022 je to 25,65 za rok 2021 a 24,56 za
  rok 2022), vliv ale počítám efektivním kurzem.

## Náklad bez zajištění

- **Otázka:** kolik firmu stála silová elektřina, když všechno kupovala na denním trhu?
- **Co měří:** náklad na silovou elektřinu vážený odběrem, bez zajištění: `C = SUM(load × price)`.
- **Výpočet:** `spot_cost_eur` v [sql/12_query_hedging.sql](../sql/12_query_hedging.sql), stejné jako roční `C`
  z dotazu 10.
- **Jednotka a období:** EUR za rok, na stránce Zajištění ceny 2021–2024.
- **Co se počítá a co ne:** nic nevyřazuji.
- **Jak to číst:** 2021 2,98 · 2022 7,40 · 2023 2,97 · 2024 2,53 mil. EUR.
- **Omezení:** simulovaný odběr, jen silová elektřina (bez regulovaných plateb).

## Náklad se zajištěním

- **Otázka:** kolik by firma zaplatila, kdyby část roční spotřeby zafixovala předem?
- **Co měří:** zajištěný podíl se koupí jako rovný produkt (base load) za cenu pevně danou před rokem dodávky, zbytek
  na spotu: `zajištěný náklad = C + podíl × V × (Ph − Pb)`. `Ph` je náhradní cena, tedy prostý průměr spotu
  předchozího roku (`ASSUMPTION`, [ADR-003](decisions/ADR-003-forward-price-proxy_cz.md)). Pro porovnání počítám totéž
  s cenou PXE CZ CAL base z konce předchozího roku (`FACT`, jen 2022–2024).
- **Výpočet:** `hedged_cost_eur` a `hedged_cost_pxe_eur` v [sql/12_query_hedging.sql](../sql/12_query_hedging.sql).
  V Power BI dává podíl parametr what-if (posuvník 0–100 % po 25 %, stejné podíly jako v dotazu 12).
- **Jednotka a období:** EUR za rok.
- **Co se počítá a co ne:** rok 2020 vynechávám, protože nemá předchozí rok.
- **Jak to číst:** v roce 2022 při 50 % 5,35 mil. EUR s náhradní cenou a 7,04 mil. EUR s cenou PXE. Při 100 % 3,30
  a 6,69 mil. EUR (bez zajištění 7,40). V roce 2023 při 100 % 7,07 mil. EUR proti 2,97 bez zajištění, protože
  zajištění zafixovalo krizovou cenu.
- **Omezení:** náhradní cena není cena skutečné smlouvy. Nepočítám transakční náklady ani marži dodavatele. Jde jen
  o base load, takže přirážka za diagram odběru zůstává na spotu.

## Výsledek zajištění 2021–2024

- **Otázka:** ušetřilo fixování předem za několik let peníze, nebo stálo peníze navíc?
- **Co měří:** součet zajištěného nákladu 2021–2024 při zvoleném podílu minus součet nákladu bez zajištění 2021–2024.
  Záporné číslo znamená, že zajištění vyšlo levněji.
- **Výpočet:** součet `hedged_cost_eur − spot_cost_eur` přes roky z
  [sql/12_query_hedging.sql](../sql/12_query_hedging.sql). V Power BI ho vrátí míra `Výsledek zajištění - proxy (EUR)`,
  když na ni nepůsobí filtr roku. V reportu pro něj nemám samostatnou kartu.
- **Jednotka a období:** EUR za období 2021–2024.
- **Co se počítá a co ne:** varianta s cenou PXE jen za roky 2022–2024.
- **Jak to číst:** s náhradní cenou při 100 % −1,44 mil. EUR (14 442 596,70 proti 15 883 549,87), při 50 %
  −0,72 mil. EUR. S cenou PXE za 2022–2024 při 100 % +3,62 mil. EUR, tedy dráž.
- **Omezení:** stejná jako u nákladu se zajištěním. Výsledek hodně závisí na tom, jakou cenu zajištění použilo.

## Násobek nákladu krize

- **Otázka:** kolikrát víc stála elektřina na vrcholu krize než před ní?
- **Co měří:** celkový náklad na elektřinu v roce 2022 dělený celkovým nákladem v roce 2020.
- **Výpočet:** roční `total_cost_czk` z [sql/08_query_allin_price.sql](../sql/08_query_allin_price.sql):
  200 924 897,61 / 45 464 435,44 = 4,42.
- **Jednotka a období:** poměr, pevné roky 2022 a 2020.
- **Co se počítá a co ne:** stejné jako u celkového nákladu.
- **Jak to číst:** 4,4×. V reportu je v textu „Co to znamená“ na stránce Náklad firmy.
- **Omezení:** simulovaný odběr. Měnily se i regulované ceny (POZE bylo od 1. 10. 2022 do 31. 12. 2023 nulové).

## Míry DAX v Power BI

Tady jsou všechny míry z reportu ([powerbi/](../powerbi/)). Model jich má 65: 64 jsem napsal sám a jednu vytvořil Power
BI pro parametr what-if. Názvy a popisy měr jsou česky, protože report je pro české uživatele. Tabulky a sloupce
zůstaly anglicky, tak jak přišly z SQL. Při psaní vzorců jsem dodržoval tři pravidla:

- Sloupec píšu vždy i s názvem tabulky, míru bez něj. Hned je vidět, co je co.
- Podíl bere čitatel i jmenovatel ze stejné tabulky. Filtr na jiné tabulce tak nemůže změnit jen polovinu výpočtu.
- Dělím přes `DIVIDE`, které při nule ve jmenovateli vrátí prázdnou hodnotu místo chyby. Výjimkou je `/ 1000`
  (převod MWh na kWh), kde je dělitel pevné číslo.

Kontrolní hodnota je výsledek z SQL (hlavně dotazy 08 a 11 a pohled `vw_hourly_cost`). Každou míru jsem se SQL
porovnal, když jsem ji psal. Při kontrole reportu 23. 11. 2026 jsem znovu porovnal všechny stránky se SQL.

| Míra | Tabulka | DAX | KPI | Kontrola 2022 |
|------|---------|-----|-----|---------------|
| Náklad na silovou elektřinu (Kč) | `vw_hourly_cost` | `SUM(vw_hourly_cost[power_cost_czk])` | Celkový náklad (část za silovou elektřinu) | 181 956 775,64 |
| Spotřeba (MWh) | `vw_hourly_cost` | `SUM(vw_hourly_cost[load_mwh])` | pomocná míra | 27 953,42 |
| Cena za silovou elektřinu (Kč/MWh) | `vw_hourly_cost` | `DIVIDE([Náklad na silovou elektřinu (Kč)], [Spotřeba (MWh)])` | Přirážka za diagram odběru (cena vážená odběrem) | 6 509,28 |
| Cena za silovou elektřinu (Kč/kWh) | `vw_hourly_cost` | `[Cena za silovou elektřinu (Kč/MWh)] / 1000` | pro porovnání s fakturou domácnosti | 6,51 |
| Celkový náklad na elektřinu (Kč) | `vw_monthly_cost` | `SUM(vw_monthly_cost[total_cost_czk])` | Celkový náklad na elektřinu | 200 924 897,61 |
| Celková cena elektřiny (Kč/kWh) | `vw_monthly_cost` | `DIVIDE([Celkový náklad na elektřinu (Kč)], SUM(vw_monthly_cost[load_mwh])) / 1000` | Celková cena | 7,19 |
| Celkový náklad na elektřinu (mil. Kč) | `vw_monthly_cost` | `DIVIDE([Celkový náklad na elektřinu (Kč)], 1000000)` | Celkový náklad (karta) | 200,92 |
| Celkový náklad na elektřinu minulý rok (mil. Kč) | `vw_monthly_cost` | `CALCULATE([Celkový náklad na elektřinu (mil. Kč)], SAMEPERIODLASTYEAR(dim_date[full_date]))` | Celkový náklad (srovnávací řádek) | 95,72 |
| Celková cena elektřiny minulý rok (Kč/kWh) | `vw_monthly_cost` | `CALCULATE([Celková cena elektřiny (Kč/kWh)], SAMEPERIODLASTYEAR(dim_date[full_date]))` | Celková cena (srovnávací řádek) | 3,42 |
| Regulované poplatky podle spotřeby (Kč) | `vw_monthly_cost` | `SUM(vw_monthly_cost[electricity_tax_czk]) + SUM(vw_monthly_cost[network_use_czk]) + SUM(vw_monthly_cost[system_services_czk])` | Měsíční náklad (složka) | leden 2020: 360 896,19 |
| Pevné platby (Kč) | `vw_monthly_cost` | `SUM(vw_monthly_cost[reserved_capacity_czk]) + SUM(vw_monthly_cost[ote_fees_czk])` | Měsíční náklad (složka) | leden 2020: 885 157,69 |
| POZE (Kč) | `vw_monthly_cost` | `SUM(vw_monthly_cost[poze_czk])` | Měsíční náklad (složka) | leden 2020: 288 372,60 |
| Regulované platby (Kč) | `vw_monthly_cost` | `[Pevné platby (Kč)] + [POZE (Kč)] + [Regulované poplatky podle spotřeby (Kč)]` | Měsíční náklad (regulovaná část) | 18 968 121,97 (leden 2020: 1 534 426,48) |
| Podíl silové elektřiny (%) | `vw_monthly_cost` | `DIVIDE(SUM(vw_monthly_cost[power_cost_czk]), [Celkový náklad na elektřinu (Kč)])` | Podíl silové elektřiny | 90,6 % |
| Průměrná tržní cena (Kč/MWh) | `vw_hourly_cost` | `AVERAGE(vw_hourly_cost[price_czk_mwh])` | Průměrná tržní cena | 6 082,84 |
| Průměrná tržní cena minulý rok (Kč/MWh) | `vw_hourly_cost` | `CALCULATE([Průměrná tržní cena (Kč/MWh)], SAMEPERIODLASTYEAR(dim_date[full_date]))` | Průměrná tržní cena (srovnávací řádek) | 2 570,35 |
| Přirážka za diagram odběru (Kč/MWh) | `vw_hourly_cost` | `[Cena za silovou elektřinu (Kč/MWh)] - [Průměrná tržní cena (Kč/MWh)]` | Přirážka za diagram odběru | 426,45 |
| Přirážka za diagram odběru (Kč) | `vw_hourly_cost` | `[Přirážka za diagram odběru (Kč/MWh)] * [Spotřeba (MWh)]` | Přirážka za diagram odběru | 11 920 639,66 |
| Přirážka za diagram odběru (mil. Kč) | `vw_hourly_cost` | `DIVIDE([Přirážka za diagram odběru (Kč)], 1000000)` | Přirážka za diagram odběru (karta) | 11,92 |
| Počet hodin | `vw_hourly_cost` | `COUNTROWS(vw_hourly_cost)` | Cenové pásmo (graf pásem na stránce Trh) | 8 760 |
| Extrémní hodiny | `vw_hourly_cost` | `CALCULATE(COUNTROWS(vw_hourly_cost), vw_hourly_cost[price_band] = "extrémní") + 0` | Extrémní hodiny | 3 694 |
| Podíl extrémních hodin (%) | `vw_hourly_cost` | `DIVIDE([Extrémní hodiny], COUNTROWS(vw_hourly_cost))` | Extrémní hodiny (podíl z roku) | 42,2 % |
| Nejvyšší hodinová cena (Kč/MWh) | `vw_hourly_cost` | `MAX(vw_hourly_cost[price_czk_mwh])` | Nejvyšší hodinová cena | 21 422,25 |
| Nejdražší hodina – kdy | `vw_hourly_cost` | viz níže | Nejvyšší hodinová cena (datum a hodina, text) | „29. 8. 2022, hodina 20“ |
| Průměrná cena ve špičce (Kč/MWh) | `vw_hourly_cost` | `CALCULATE([Průměrná tržní cena (Kč/MWh)], dim_date[is_weekend] = FALSE(), dim_hour[hour_of_day] >= 9, dim_hour[hour_of_day] <= 20)` | Rozdíl špička – mimo špičku | 7 030,40 |
| Průměrná cena mimo špičku (Kč/MWh) | `vw_hourly_cost` | viz níže | Rozdíl špička – mimo špičku | 5 558,65 |
| Rozdíl špička – mimo špičku (Kč/MWh) | `vw_hourly_cost` | `[Průměrná cena ve špičce (Kč/MWh)] - [Průměrná cena mimo špičku (Kč/MWh)]` | Rozdíl špička – mimo špičku | 1 471,75 |
| Náklad na silovou elektřinu minulý rok (Kč) | `vw_hourly_cost` | `CALCULATE([Náklad na silovou elektřinu (Kč)], SAMEPERIODLASTYEAR(dim_date[full_date]))` | Změna nákladu na silovou elektřinu | 76 133 003,83 |
| Změna nákladu na silovou elektřinu (Kč) | `vw_hourly_cost` | `VAR previous_cost = [Náklad na silovou elektřinu minulý rok (Kč)] RETURN IF(ISBLANK(previous_cost), BLANK(), [Náklad na silovou elektřinu (Kč)] - previous_cost)` | Změna nákladu na silovou elektřinu | +105 823 771,81 |
| Změna nákladu na silovou elektřinu (mil. Kč) | `vw_hourly_cost` | `DIVIDE([Změna nákladu na silovou elektřinu (Kč)], 1000000)`, formát `+#,0.00;-#,0.00;0.00` | Změna nákladu (karta) | +105,82 |
| Změna nákladu na silovou elektřinu (%) | `vw_hourly_cost` | `DIVIDE([Změna nákladu na silovou elektřinu (Kč)], [Náklad na silovou elektřinu minulý rok (Kč)])`, formát `+0.0 %;-0.0 %;0.0 %` | Změna nákladu (proti minulému roku) | +139,0 % |
| Krok změny nákladu (Kč) | `vw_cost_change_steps` | `SUM(vw_cost_change_steps[amount_czk])` | Vliv ceny na trhu, spotřeby a diagramu odběru | 181 956 776,26 (součet 5 kroků) |
| Vliv kurzu (Kč) | `vw_cost_change_steps` | `CALCULATE([Krok změny nákladu (Kč)], vw_cost_change_steps[step_name] = "Kurz EUR/CZK")` | Vliv kurzu | −6 978 840,33 |
| Vliv ceny na trhu (Kč) | `vw_cost_change_steps` | `CALCULATE([Krok změny nákladu (Kč)], vw_cost_change_steps[step_name] = "Cena na trhu")` | Vliv ceny na trhu | +104 753 598,23 |
| Vliv ceny na trhu (mil. Kč) | `vw_cost_change_steps` | `DIVIDE([Vliv ceny na trhu (Kč)], 1000000)`, formát `+#,0.00;-#,0.00;0.00` | Vliv ceny na trhu (karta) | +104,75 |
| Vliv kurzu (mil. Kč) | `vw_cost_change_steps` | `DIVIDE([Vliv kurzu (Kč)], 1000000)`, formát se znaménkem | Vliv kurzu (karta) | −6,98 |
| Krok změny nákladu (mil. Kč) | `vw_cost_change_steps` | `DIVIDE([Krok změny nákladu (Kč)], 1000000)`, formát se znaménkem | Vodopád a tabulka po letech | +104,75 (Cena na trhu) |
| Tržní cena – loni a letos | `vw_hourly_cost` | `VAR loni = [Průměrná tržní cena minulý rok (Kč/MWh)] VAR letos = [Průměrná tržní cena (Kč/MWh)] RETURN FORMAT(loni, "#,0") & " → " & FORMAT(letos, "#,0")` (text na kartu) | Průměrná tržní cena | `2 570 → 6 083` |
| Kurz – loni a letos | `vw_hourly_cost` | `VAR letos = AVERAGE(vw_hourly_cost[rate_czk_per_eur]) VAR loni = CALCULATE(AVERAGE(vw_hourly_cost[rate_czk_per_eur]), SAMEPERIODLASTYEAR(dim_date[full_date])) RETURN FORMAT(loni, "0.00") & " → " & FORMAT(letos, "0.00")` (text na kartu) | Vliv kurzu | `25,65 → 24,56` |
| Náklad na silovou elektřinu bez zajištění (EUR) | `vw_yearly_hedging` | `SUM(vw_yearly_hedging[spot_cost_eur])` | Náklad bez zajištění | 7 399 949,24 |
| Náklad na silovou elektřinu bez zajištění (mil. EUR) | `vw_yearly_hedging` | `DIVIDE([Náklad na silovou elektřinu bez zajištění (EUR)], 1000000)` | Náklad bez zajištění (karta) | 7,40 |
| Hodnota parametru Podíl zajištění | `Podíl zajištění` | `SELECTEDVALUE('Podíl zajištění'[Podíl zajištění], 0)` (vytvořil Power BI) | Náklad se zajištěním (posuvník) | 0–100 % |
| Náklad na silovou elektřinu se zajištěním - proxy (EUR) | `vw_yearly_hedging` | `VAR no_hedge = [Náklad na silovou elektřinu bez zajištění (EUR)] VAR parameter = [Hodnota parametru Podíl zajištění] VAR hedge_diff = SUM(vw_yearly_hedging[hedge_diff_proxy_eur]) RETURN no_hedge + parameter * hedge_diff` | Náklad se zajištěním | 6 374 240,95 při 25 % |
| Náklad na silovou elektřinu se zajištěním - proxy (mil. EUR) | `vw_yearly_hedging` | `DIVIDE([Náklad na silovou elektřinu se zajištěním - proxy (EUR)], 1000000)` | Náklad se zajištěním (karta, graf) | 5,35 při 50 % |
| Náklad na silovou elektřinu se zajištěním - PXE (EUR) | `vw_yearly_hedging` | `VAR no_hedging = [Náklad na silovou elektřinu bez zajištění (EUR)] VAR param = [Hodnota parametru Podíl zajištění] VAR pxe = SUM(vw_yearly_hedging[hedge_diff_pxe_eur]) RETURN IF(ISBLANK(pxe), BLANK(), no_hedging + param * pxe)` | Náklad se zajištěním (cena PXE) | 6 685 638,51 při 100 % |
| Náklad na silovou elektřinu se zajištěním - PXE (mil. EUR) | `vw_yearly_hedging` | `DIVIDE([Náklad na silovou elektřinu se zajištěním - PXE (EUR)], 1000000)` | Náklad se zajištěním, PXE (karta) | 7,04 při 50 % |
| Výsledek zajištění - proxy (EUR) | `vw_yearly_hedging` | `VAR no_hedging = [Náklad na silovou elektřinu bez zajištění (EUR)] VAR proxy = [Náklad na silovou elektřinu se zajištěním - proxy (EUR)] RETURN proxy - no_hedging` | Výsledek zajištění 2021–2024 | −4 102 833,18 při 100 % |
| Výsledek zajištění - proxy (mil. EUR) | `vw_yearly_hedging` | `DIVIDE([Výsledek zajištění - proxy (EUR)], 1000000)`, formát se znaménkem | Výsledek zajištění (řádek na kartě) | −2,05 při 50 % |
| Výsledek zajištění - PXE (mil. EUR) | `vw_yearly_hedging` | `VAR pxe = [Náklad na silovou elektřinu se zajištěním - PXE (mil. EUR)] VAR bez = [Náklad na silovou elektřinu bez zajištění (mil. EUR)] RETURN IF(ISBLANK(pxe), BLANK(), pxe - bez)` | Výsledek zajištění, PXE (řádek na kartě) | −0,36 při 50 % (2021 prázdné) |
| Karta – bez zajištění popisek | `vw_yearly_hedging` | `"Celý odběr za cenu z trhu"` (text na kartu, nová karta bere jako srovnávací řádek jen pole) | jen pro zobrazení | stejný text každý rok |
| Násobek nákladu krize (2022 / 2020) | `vw_monthly_cost` | `VAR cost_2022 = CALCULATE([Celkový náklad na elektřinu (Kč)], dim_date[year] = 2022) VAR cost_2020 = CALCULATE([Celkový náklad na elektřinu (Kč)], dim_date[year] = 2020) RETURN DIVIDE(cost_2022, cost_2020)` | Násobek nákladu krize | 4,42 (v každém řádku) |
| Regulované platby (mil. Kč) | `vw_monthly_cost` | `DIVIDE([Regulované platby (Kč)], 1000000)` | Regulované platby (karta na Shrnutí) | 18,97 (2024: 31,28) |
| Karta – náklad 2020 a násobek | `vw_monthly_cost` | `VAR celkem2020 = CALCULATE([Celkový náklad na elektřinu (mil. Kč)], dim_date[year] = 2020) VAR nasobek = [Násobek nákladu krize (2022 / 2020)] RETURN "2020: " & FORMAT(celkem2020, "0.00") & " mil. Kč · " & FORMAT(nasobek, "0.0") & "× více"` (text na kartu) | Násobek nákladu krize | `2020: 45,46 mil. Kč · 4,4× více` |
| Karta – cena 2020 | `vw_monthly_cost` | `VAR cena2020 = CALCULATE([Celková cena elektřiny (Kč/kWh)], dim_date[year] = 2020) RETURN "2020: " & FORMAT(cena2020, "0.00") & " Kč/kWh"` (text na kartu) | Celková cena | `2020: 1,62 Kč/kWh` |
| Karta – regulované platby 2024 | `vw_monthly_cost` | `VAR reg2024 = CALCULATE([Regulované platby (mil. Kč)], dim_date[year] = 2024) VAR reg2022 = [Regulované platby (mil. Kč)] RETURN "2024: " & FORMAT(reg2024, "0.00") & " mil. Kč · " & FORMAT(DIVIDE(reg2024, reg2022), "0.0") & "× více"` (text na kartu, karta má filtr na rok 2022) | Regulované platby | `2024: 31,28 mil. Kč · 1,6× více` |
| Karta – přirážka popisek | `vw_hourly_cost` | `"odběr v dražších denních hodinách"` (text na kartu) | jen pro zobrazení | stejný text každý rok |
| Nejdražší měsíc – celkový náklad (Kč) | `vw_monthly_cost` | `MAX(vw_monthly_cost[total_cost_czk])` (jeden řádek = jeden měsíc, takže MAX vybere měsíc) | Celkový náklad na elektřinu | 32 303 995,75 (srpen 2022, za 2020–2024) |
| Nejdražší měsíc karta – celkový náklad (mil. Kč) | `vw_monthly_cost` | `DIVIDE([Nejdražší měsíc – celkový náklad (Kč)], 1000000)` | Celkový náklad (karta na Shrnutí) | 32,30 |
| Nejdražší měsíc karta – spodni | `vw_monthly_cost` | `VAR cena = CALCULATE([Celková cena elektřiny (Kč/kWh)], vw_monthly_cost[year] = 2022, vw_monthly_cost[month] = 8) RETURN "Srpen 2022" & " · " & FORMAT(cena, "0.00") & " Kč/kWh"` (text na kartu, měsíc je pevný, protože Shrnutí nemá průřez) | Celková cena | `Srpen 2022 · 12,75 Kč/kWh` |
| Nejlevnější měsíc - celkový náklad | `vw_monthly_cost` | `MIN(vw_monthly_cost[total_cost_czk])` | Celkový náklad na elektřinu | 2 911 201,48 (duben 2020) |
| Nejlevnější měsíc karta - celkový náklad (mil. Kč) | `vw_monthly_cost` | `DIVIDE([Nejlevnější měsíc - celkový náklad], 1000000)` | Celkový náklad (karta na Shrnutí) | 2,91 |
| Nejlevnější měsíc karta - spodní | `vw_monthly_cost` | `VAR cena = CALCULATE([Celková cena elektřiny (Kč/kWh)], vw_monthly_cost[year] = 2020, vw_monthly_cost[month] = 4) RETURN "Duben 2020 (Covid)" & " · " & FORMAT(cena, "0.00") & " Kč/kWh"` (text na kartu) | Celková cena | `Duben 2020 (Covid) · 1,20 Kč/kWh` |
| Nejdražší den – silová elektřina (Kč) | `vw_hourly_cost` | `MAXX(VALUES(dim_date[full_date]), [Náklad na silovou elektřinu (Kč)])` (projde všechny dny, u každého sečte jeho hodiny a nechá si největší částku) | Náklad bez zajištění (jen silová elektřina) | 1 657 482,83 (30. 8. 2022) |
| Nejdražší den – silová elektřina (mil. Kč) | `vw_hourly_cost` | `DIVIDE([Nejdražší den – silová elektřina (Kč)], 1000000)` | Náklad bez zajištění (karta na Shrnutí) | 1,66 |
| Karta – nejdražší den | `vw_hourly_cost` | `"30. 8. 2022 · pouze silová elektřina"` (text na kartu) | jen pro zobrazení | stejný text |

Šest měr report na žádné stránce nezobrazuje. Vznikly během stavby reportu, nakonec jsem je na stránky nedal a jejich
hodnoty sedí se SQL:

- `Cena za silovou elektřinu (Kč/kWh)`
- `Podíl silové elektřiny (%)`
- `Rozdíl špička – mimo špičku (Kč/MWh)` (a míry ve špičce a mimo špičku, ze kterých se počítá)
- `Karta – přirážka popisek`, `Karta – náklad 2020 a násobek` a `Karta – cena 2020` (z první verze stránky Shrnutí, než
  jsem její karty vyměnil za nejdražší a nejlevnější měsíc a nejdražší den)

Mimo špičku je víkend **nebo** hodina mimo 9–20. Filtry uvnitř `CALCULATE` se spojují jen přes A (AND) a podmínka NEBO
přes dvě tabulky (`dim_date`, `dim_hour`) není jednoduchá. Proto počítám „mimo špičku“ jako všechny hodiny minus hodiny
ve špičce:

```dax
Průměrná cena mimo špičku (Kč/MWh) =
VAR peak_price_sum = CALCULATE(SUM(vw_hourly_cost[price_czk_mwh]), dim_date[is_weekend] = FALSE(), dim_hour[hour_of_day] >= 9, dim_hour[hour_of_day] <= 20)
VAR peak_hours = CALCULATE(COUNTROWS(vw_hourly_cost), dim_date[is_weekend] = FALSE(), dim_hour[hour_of_day] >= 9, dim_hour[hour_of_day] <= 20)
RETURN
DIVIDE(SUM(vw_hourly_cost[price_czk_mwh]) - peak_price_sum, COUNTROWS(vw_hourly_cost) - peak_hours)
```

Datum a hodina nejdražší hodiny: najdu řádek, jehož cena se rovná nejvyšší ceně, přečtu jeho `date_key`
a `hour_of_day`, klíč `YYYYMMDD` rozdělím na rok, měsíc a den a vrátím text pro kartu:

```dax
Nejdražší hodina – kdy =
VAR max_price = [Nejvyšší hodinová cena (Kč/MWh)]
VAR max_day = CALCULATE(MAX(vw_hourly_cost[date_key]), vw_hourly_cost[price_czk_mwh] = max_price)
VAR max_hour = CALCULATE(MAX(vw_hourly_cost[hour_of_day]), vw_hourly_cost[price_czk_mwh] = max_price)
VAR max_date = DATE(QUOTIENT(max_day, 10000), MOD(QUOTIENT(max_day, 100), 100), MOD(max_day, 100))
RETURN
FORMAT(max_date, "d. M. yyyy") & ", hodina " & max_hour
```

Ověřil jsem to 11. 11. 2026 proti dotazu s `RANK` nad `vw_hourly_cost`: 22. 9. 2020 h20 · 21. 12. 2021 h18 ·
29. 8. 2022 h20 · 11. 9. 2023 h20 · 12. 12. 2024 h18. Ani v jednom roce nemají dvě hodiny stejnou nejvyšší cenu.
Hodina 20 znamená 19:00–20:00.

### Poznámky k mírám

- **Meziroční míry** potřebují `dim_date` označenou jako tabulku kalendáře. Rok 2020 nemá v datech předchozí rok,
  proto vrací BLANK (prázdno, ne 0, protože data chybí). Bez kontroly `ISBLANK` by rok 2020 ukázal celý svůj náklad
  jako „změnu“. Řádek celkem u nich nedává smysl (období posunuté o rok), proto ho ve vizuálech skrývám.
- **Krok změny nákladu:** vodopád ho rozdělí podle `step_name`. Za každý rok dá 5 kroků dohromady náklad toho roku
  s rozdílem 0,6–1,8 Kč (zaokrouhlení efektivního kurzu R, ADR-006). Pohled začíná rokem 2021, protože 2020 nemá
  předchozí rok.
- **Násobek nákladu krize:** filtr roku uvnitř `CALCULATE` nahradí rok, který přichází z vizuálu, proto je hodnota
  v každém řádku stejná (pevné roky).
- **Podíl zajištění** je parametr what-if: samostatná tabulka `GENERATESERIES(0, 1, 0.25)` bez vazby na ostatní tabulky,
  která jen drží hodnotu posuvníku. `SELECTEDVALUE(…, 0)` vrátí 0 (bez zajištění), když není vybraná právě jedna
  hodnota. Zajištěný náklad jsem zkontroloval při 25 % (2021–2024: 2 512 701,17 · 6 374 240,95 · 3 996 851,50 ·
  2 639 517,96 EUR).
- **Náklad se zajištěním PXE:** pro rok 2021 cena PXE není, takže `hedge_diff_pxe_eur` je NULL a jeho `SUM` je BLANK.
  BLANK se ve výpočtu chová jako 0, takže bez kontroly `ISBLANK` by rok 2021 ukázal náklad bez zajištění
  (2 981 864,21 EUR), jako by zajištění nic nezměnilo. Proto vracím BLANK. Kontrola při 100 % (2022–2024:
  6 685 638,51 · 6 918 421,78 · 2 920 179,09 EUR, stejně jako dotaz 12). Řádek celkem by míchal rok 2021 bez zajištění
  s roky 2022–2024 se zajištěním (19 506 103,60 EUR místo 16 524 239,38 za tři roky), proto ukazuji jen jednotlivé roky
  a řádek celkem skrývám.
- **Výsledek zajištění - proxy:** jedna míra pro obě zobrazení, po letech i za celé období 2021–2024 bez filtru roku.
  Obě míry, ze kterých se počítá, jsou součty, takže jejich rozdíl se sčítá. Kontrola při 100 %: −1 876 652,15 ·
  −4 102 833,18 · +4 098 656,75 · +439 875,41, celkem −1 440 953,17 EUR (stejně jako dotaz 12). Záporné číslo znamená,
  že zajištění vyšlo levněji.
- **`+ 0` v Extrémní hodiny:** `COUNTROWS` prázdné tabulky vrátí BLANK. Rok bez extrémních hodin (2020) ale musí
  ukázat 0.
- **Cenová pásma** beru ze sloupce `vw_hourly_cost[price_band]` (SQL `CASE` se stejnými hranicemi jako dotaz 05,
  řazené podle skrytého sloupce `price_band_order` 1–5). Extrémní hodiny filtrují na pásmo, ne na
  `price_czk_mwh >= 5821`, takže hranice jsou zapsané jen na jednom místě, v SQL.
- **Podíl extrémních hodin** používá `[Extrémní hodiny]`, takže nepotřebuje vlastní hranici. Jmenovatel počítá řádky
  faktové tabulky (jeden řádek = jedna hodina), ne `dim_hour` (25 hodin dne). Kontrola: 0,0 / 6,6 / 42,2 / 0,3 / 1,0 %.
  Za 2020–2024 celkem vyjde přesně 10,0 % (4 385 / 43 848), protože hranice je P90 všech hodin.
- **Čísla na kartách:** karta v Power BI čísla ve výchozím stavu zkracuje (3 694 na „4 tis.“). Motiv reportu proto
  všem kartám vypíná jednotky zobrazení (`labelDisplayUnits = 1`). Částky v milionech ukazuji přes samostatné míry
  `(mil. Kč)` a `(mil. EUR)`, protože nová karta neumí hlavní hodnotu v milionech zobrazit sama. Původní míra v Kč
  zůstává pro další výpočty, tabulky a popisky.
- **Průměrná tržní cena minulý rok:** stejný vzor jako náklad minulého roku. Rok 2020 je BLANK (chybí data za 2019).
  Kontrola: 886,55 / 2 570,35 / 6 082,84 / 2 416,13 pro roky 2021–2024. Řádek celkem (2 987,53) je průměr let
  2020–2023 a nedává smysl, proto ukazuji jen jednotlivé roky.
- **`/ 1000`** dělí pevným číslem (MWh na kWh), takže nemůže selhat. `DIVIDE` používám všude, kde by dělitel mohl být
  nula nebo prázdný.
- **Přirážka za diagram odběru (Kč)** je správně za jeden rok. Přes víc let se průměr trhu bere ze všech jejich hodin,
  ne po letech: za 2020–2024 ukáže 25 028 480,44 Kč, ale součet pěti let je 25 092 615,49 Kč. V reportu ji proto
  ukazuji po letech (průřez rokem na stránce Náklad firmy) a vizuály po letech řádek celkem skrývají.
- Power BI a SQL se u přirážky liší nejvýš o 0,02 Kč, protože SQL zaokrouhlí `AVG` z typu DECIMAL na 6 desetinných míst.
