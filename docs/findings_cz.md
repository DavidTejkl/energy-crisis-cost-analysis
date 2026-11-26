# Zjištění

[English](findings.md) · **Čeština**

Tady jsou všechna zjištění z analytických dotazů. U každé části je odkaz na dotaz, ze kterého čísla pocházejí, takže
si každé číslo může kdokoli spustit a ověřit sám.

Ceny na trhu, kurzy a regulované ceny jsou skutečná data (OTE, ČNB, ERÚ). Odběr modelové firmy je simulovaný
(28 GWh za rok, [metodika](methodology_cz.md)). Všechno, co mluví o nákladu firmy, proto platí pro tuto
modelovou firmu, ne pro konkrétní podnik.

Každý bod má označení:

- **FACT:** číslo přímo z výsledku dotazu
- **FINDING:** závěr, který z čísel vyvozuji
- **ASSUMPTION:** předpoklad, který jsem musel zvolit, protože data neexistují
- **RECOMMENDATION:** doporučení pro firmu

## Část 1: Trh s elektřinou

Jen skutečné ceny denního trhu OTE pro Českou republiku, zatím bez modelové firmy.

### Denní přehled

Dotaz: [`sql/04_query_daily_overview.sql`](../sql/04_query_daily_overview.sql)

- **FACT:** Nejdražší den byl 26. 8. 2022 s průměrnou cenou 17 325 Kč/MWh (703 EUR/MWh). V celém roce 2020 neměl
  žádný den průměr vyšší než 2 116 Kč/MWh, takže nejdražší den krize byl zhruba osmkrát dražší než nejdražší den
  roku 2020.
- **FACT:** Hodnota elektřiny zobchodované na denním trhu byla v roce 2020 20,7 mld. Kč a v roce 2022 155,8 mld. Kč,
  tedy 7,5× víc. Zobchodované množství přitom vzrostlo jen z 22,4 na 24,3 TWh (+8 %), takže skoro celý skok udělala
  cena.

### Cenová pásma

Dotaz: [`sql/05_query_price_bands.sql`](../sql/05_query_price_bands.sql) · hranice pásem jsou v
[definicích KPI](kpi_definitions_cz.md#cenové-pásmo)

- **FACT:** V roce 2020 byla v pásmu vysoké nebo extrémní ceny (od 3 374 Kč/MWh) jediná hodina. V roce 2022 jich bylo
  6 951, tedy 79 % roku. Levných hodin (od 0 do méně než 1 217 Kč/MWh) ubylo ze 7 045 (80 % roku 2020) na 237
  (3 % roku 2022). V roce 2024 už byla většina hodin zase v normálním pásmu (6 462) a extrémních hodin bylo 84.
- **FACT:** Hodin se zápornou cenou bylo v roce 2022 jen 8. V roce 2024 jich bylo 315, nejvíc ze všech pěti let.

### Změny ceny ze dne na den

Dotaz: [`sql/06_query_price_changes.sql`](../sql/06_query_price_changes.sql)

- **FACT:** Nejvíc průměrná denní cena vyskočila 11. 7. 2022, o 6 844 Kč/MWh (z 2 265 na 9 109). Nejvíc spadla
  1. 10. 2022, o 5 266 Kč/MWh (z 8 697 na 3 430).
- **FACT:** 18 z 20 největších denních nárůstů v roce 2022 připadlo na pondělí. Změna ze dne na den tedy hlavně
  ukazuje týdenní rytmus při velmi vysoké cenové hladině: o víkendu je elektřina levná a v pondělí cena zase vyskočí.
  Většinou nejde o samostatné události na trhu.
- **Poznámka k metodě:** Procentní změnu (`pct_change`) nechávám prázdnou, když byla cena předchozího dne nulová nebo
  záporná (5 dní). Dělení zápornou cenou totiž otočí znaménko. Například 22. 3. 2020 byla průměrná cena
  −0,98 EUR/MWh (neděle s 11 zápornými hodinami, ověřeno v surovém souboru OTE). Změny proto porovnávám v korunách.

### Nejdražší hodiny a dny

Dotaz: [`sql/07_query_top_hours.sql`](../sql/07_query_top_hours.sql)

- **FACT:** Nejdražší hodina roku 2024 (12. 12. 2024, 17:00–18:00, 21 171 Kč/MWh) byla skoro stejně drahá jako
  nejdražší hodina krize (29. 8. 2022, 19:00–20:00, 21 422 Kč/MWh). Nejdražší den roku 2024 měl ale průměr jen
  9 035 Kč/MWh, zhruba polovinu nejdražšího dne roku 2022 (26. 8. 2022, 17 325 Kč/MWh).
- **FACT:** Všech pět nejdražších dnů roku 2022 bylo v osmi dnech od 24. do 31. 8. 2022 (15 535 až 17 325 Kč/MWh).
- **FINDING:** Rok 2022 bylo dlouhé období velmi vysokých cen. Špička v roce 2024 byla krátký šok na pár hodin, kdy
  málo foukalo a svítilo (viz [zpráva o kvalitě dat](data_quality_report_cz.md)). Hodiny s cenou jako v krizi
  tedy můžou přijít i po ní a riziko nákupu na spotu s krizí nezmizelo.

### Špička a mimo špičku

Dotaz: [`sql/09_query_peak_offpeak.sql`](../sql/09_query_peak_offpeak.sql)

Špička je pondělí až pátek 8:00–20:00 (`hour_of_day` 9–20), stejně jak ji trh definuje pro produkt peak load.
Všechny ostatní hodiny jsou mimo špičku. **ASSUMPTION:** státní svátky ve všední den počítám jako špičku, protože
`dim_date` nemá příznak svátku. Ceny jsou prosté průměry, každá hodina má stejnou váhu jako v produktu na trhu.

- **FACT:** Rozdíl mezi špičkou a zbytkem týdne vzrostl z 12,53 EUR/MWh v roce 2020 na **60,04 EUR/MWh v roce 2022**
  (4,8×) a pak klesl na 21,82 (2023) a 14,89 (2024). V korunách to bylo 330,09 Kč/MWh v roce 2020, 1 471,75 v roce
  2022, 526,54 v roce 2023 a 374,52 v roce 2024.
- **FACT:** V procentech ale přirážka za špičku klesala. Špička byla dražší o 43 % v roce 2020, o 38 % v roce 2021,
  o 27 % v roce 2022, o 23 % v roce 2023 a o 19 % v roce 2024. Rozdíl v roce 2022 narostl proto, že stoupla celá
  cenová hladina. Denní hodiny se proti ostatním nezdražily víc než dřív.

## Část 2: Modelová firma (simulovaný odběr)

Odběr firmy je simulovaný (`SIMULATED`), ceny, kurzy a regulované ceny jsou skutečné. Pokud není uvedeno jinak,
firma kupuje všechnu elektřinu za spotovou cenu denního trhu.

### Celková cena za kWh

Dotaz: [`sql/08_query_allin_price.sql`](../sql/08_query_allin_price.sql)

Celková cena je silová elektřina z denního trhu plus regulované platby: použití sítě, systémové služby, daň
z elektřiny, rezervovaná kapacita 5 MW, POZE a poplatky OTE. Platí pro distribuční území ČEZ Distribuce na vysokém
napětí, **bez DPH a bez marže dodavatele** ([co do ceny patří](decisions/ADR-005-all-in-price-scope_cz.md)).

- **FINDING:** Celková cena vzrostla z **1,62 Kč/kWh v roce 2020 na 7,19 Kč/kWh v roce 2022** (4,4×) a pak klesla
  na 3,15 (2023) a 3,38 (2024). Firma přitom každý rok odebrala skoro stejně (27,95–28,05 GWh) a roční náklad se
  zvýšil ze 45,5 mil. Kč (2020) na 200,9 mil. Kč (2022).
- **FINDING:** Krizi táhla silová elektřina. V roce 2020 tvořila 58 % celkového nákladu, v roce 2022 už 91 %.
  Nejdražší měsíc byl srpen 2022: celková cena 12,75 Kč/kWh, silová elektřina 12 084 Kč/MWh.
- **FINDING:** Rok 2024 vyšel dráž než 2023 (3,38 proti 3,15 Kč/kWh), i když silová elektřina zlevnila (2 266 proti
  2 550 Kč/MWh). Zdražila totiž regulovaná část. Za použití sítě firma platila 2,2× víc a za systémové služby 1,9× víc
  než v roce 2023 a vrátil se poplatek POZE, který byl od října 2022 do prosince 2023 nulový.
- **FINDING:** Firma platí víc, než je průměr trhu, protože nejvíc elektřiny bere v drahých denních hodinách.
  V lednu 2020 vyšla její vážená cena silové elektřiny na 1 148,10 Kč/MWh, prostý průměr trhu byl 1 054,47 Kč/MWh.
- **FACT:** Státní strop 5 000 Kč/MWh z roku 2023, který se počítá z měsíční vážené ceny silové elektřiny, modelovou
  firmu nikdy nezasáhl. Nejdražší měsíc roku 2023 byl leden s 3 572,47 Kč/MWh. V roce 2022, kdy strop ještě neplatil,
  bylo nad 5 000 Kč/MWh šest měsíců (nejvíc srpen, 12 084 Kč/MWh). Pro firmu, která kupuje na spotu, přišel strop až
  ve chvíli, kdy ceny už klesly.
- **FACT:** Poplatek POZE vyšel vždycky levněji podle rezervovaného příkonu než podle spotřeby (ani v jednom z 60
  měsíců nebyla levnější platba za MWh). Nepřetržitý provoz totiž spotřebuje na každý rezervovaný MW hodně MWh.

### Proč regulované platby v roce 2024 vyskočily

| Regulované platby modelové firmy (mil. Kč)       |      2022 |      2023 |      2024 |
| ------------------------------------------------ | --------: | --------: | --------: |
| Distribuce (rezervovaná kapacita a použití sítě) |     12,69 |     12,71 |     17,57 |
| Systémové služby                                 |      3,17 |      3,17 |      5,97 |
| POZE                                             |      2,32 |      0,00 |      6,95 |
| Daň z elektřiny                                  |      0,79 |      0,79 |      0,79 |
| **Celkem**                                       | **18,97** | **16,67** | **31,28** |

POZE za rok 2022 je jen za leden až září. Poplatky OTE dělají jen desítky korun za rok, proto v tabulce nejsou.

- **FACT:** V krizových letech platil část regulovaných plateb za odběratele stát. Od října 2022 do konce roku 2023
  hradil ze státního rozpočtu celou podporu obnovitelných zdrojů, takže poplatek POZE byl nulový. V roce 2023 navíc
  státní dotace udržely cenu systémových služeb a náklady na ztráty v sítích na úrovni roku 2022. Pro rok 2024 vláda
  dotace skoro úplně ukončila a do regulovaných cen se naplno promítlo, že vysoké ceny elektřiny zdražily i provoz
  sítě, hlavně krytí ztrát v sítích a systémové služby
  ([tisková zpráva ERÚ z 30. 11. 2023](https://eru.gov.cz/sites/default/files/obsah/prilohy/20231130tzcreruproelektroenergetikuaplynarenstvi.pdf)).
- **FINDING:** Proti roku 2022 zaplatila firma v roce 2024 za regulované platby o 12,31 mil. Kč víc: distribuce
  +4,88 mil. Kč, POZE +4,63 mil. Kč a systémové služby +2,80 mil. Kč. Daň z elektřiny se neměnila.
- **FINDING:** Proti roku 2023 vzrostly regulované platby firmy o 88 %. ERÚ v listopadu 2023 očekával pro odběratele
  na vysokém napětí průměrný nárůst o 105,5 %. U modelové firmy je nárůst nižší hlavně proto, že její největší položka,
  rezervovaná kapacita, zdražila jen o 19 %.

### Proč se náklad měnil

Dotaz: [`sql/10_query_variance_split.sql`](../sql/10_query_variance_split.sql) ·
metoda: [rozklad změny nákladu](decisions/ADR-004-cost-variance-split_cz.md)

Meziroční změnu nákladu na silovou elektřinu v eurech rozkládám v pevném pořadí na tři části:

- spotřeba: `(V1 − V0) × Pw0`
- cena na trhu: `V1 × (Pb1 − Pb0)`
- diagram odběru: `V1 × (S1 − S0)`

V je odběr firmy, Pb průměrná cena na trhu, Pw cena vážená odběrem firmy a S = Pw − Pb přirážka za diagram odběru.
Tři části dají v každém roce dohromady celkovou změnu, rozdíl je nejvýš 0,03 EUR kvůli zaokrouhlení Pw.

| Změna          | Celkem (EUR) | Spotřeba | Cena na trhu | Diagram odběru |
| -------------- | -----------: | -------: | -----------: | -------------: |
| z 2020 na 2021 |   +1 976 267 |   −2 052 |   +1 876 652 |       +101 667 |
| z 2021 na 2022 |   +4 418 085 |   −4 286 |   +4 102 833 |       +319 538 |
| z 2022 na 2023 |   −4 427 762 |   −1 194 |   −4 098 657 |       −327 911 |
| z 2023 na 2024 |     −442 638 |  +11 073 |     −439 875 |        −13 836 |

- **FINDING:** Přirážka za diagram odběru se v krizi skoro ztrojnásobila. V roce 2020 byla +2,23 EUR/MWh, v roce 2021
  +5,86, v roce 2022 vyskočila na **+17,29 EUR/MWh** a pak klesla na 5,56 (2023) a 5,06 (2024). Za celý rok 2022 to
  je **483 333 EUR** víc, než kdyby firma stejné množství odebírala rovnoměrně ve všech hodinách. V letech 2020–2024
  to bylo 62 491 / 164 030 / 483 333 / 155 344 / 142 087 EUR (`C − V × Pb`), každý rok zhruba 5–6,5 % nákladu na
  silovou elektřinu.
- **FINDING:** Diagram odběru je ta část nákladu, kterou firma může ovlivnit sama. Cenu na trhu ovlivnit nemůže.
  Samotný diagram se mezi roky neměnil. Přirážka rostla, protože se s celou cenovou hladinou zvětšil i rozdíl mezi
  cenou ve dne a v noci. Roční přirážka je horní hranice toho, co by firma mohla ušetřit přesunem směn do nocí
  a víkendů.
- **FINDING:** Cena na trhu vysvětluje 93–99 % každé meziroční změny (95,0 / 92,9 / 92,6 / 99,4 %). U simulovaného
  odběru, který je každý rok kolem 28 GWh, se to dalo čekat a není to žádný objev: vliv spotřeby je jen mezi −4 286
  a +11 073 EUR. Se skutečnými daty firmy by stejný dotaz oddělil změny ve výrobě od pohybu trhu.

### Vliv kurzu EUR/CZK

Dotaz: [`sql/11_query_fx_effect.sql`](../sql/11_query_fx_effect.sql) ·
metoda: [vliv kurzu](decisions/ADR-006-fx-effect-split_cz.md)

Meziroční změnu nákladu na silovou elektřinu v korunách rozkládám na vliv ceny komodity `(C_eur1 − C_eur0) × R0`
a vliv kurzu `C_eur1 × (R1 − R0)`. R = C_czk / C_eur je kurz vážený náklady: dny s vysokým nákladem v eurech mají
větší váhu než dny s nízkým. Obě části dají dohromady celkovou změnu, rozdíl je nejvýš 2,05 Kč kvůli zaokrouhlení R.
Náklad v korunách za všech 5 let vychází 419 457 499 Kč, stejně jako náklad na silovou elektřinu v dotazu 08.

| Změna          | Celkem (Kč)  | Cena komodity | Kurz       |
| -------------- | -----------: | ------------: | ---------: |
| z 2020 na 2021 |  +49 581 580 |   +52 180 598 | −2 599 020 |
| z 2021 na 2022 | +105 823 772 |  +112 802 613 | −6 978 840 |
| z 2022 na 2023 | −110 696 659 |  −108 873 893 | −1 822 768 |
| z 2023 na 2024 |   −7 703 937 |   −10 612 537 | +2 908 602 |

- **FACT:** Kurz vážený náklady klesl z 26,40 Kč/EUR (2020) na 25,53 (2021), 24,59 (2022) a 23,98 (2023) a v roce
  2024 vzrostl na 25,13. Koruna v krizi posilovala a v roce 2024 oslabila.
- **FINDING:** Silnější koruna snížila náklad v roce 2022 o **6,98 mil. Kč**. To vyrovnalo jen **6,2 %** nárůstu ceny
  komodity (+112,80 mil. Kč), takže krizi kurz zmírnil jen trochu.
- **FINDING:** V roce 2024 to fungovalo opačně. Slabší koruna přidala 2,91 mil. Kč a snědla 27 % úspory na ceně
  komodity (−10,61 mil. Kč).
- **Poznámka k metodě:** Report na stránce Příčiny změny ukazuje i obyčejný průměr kurzu za rok (v roce 2022 z 25,65
  na 24,56 Kč/EUR). Pro výpočet vlivu kurzu ale používám kurz vážený náklady, protože jen s ním dají obě části přesně
  skutečný náklad v korunách.

### Zajištění ceny nákupem předem

Dotaz: [`sql/12_query_hedging.sql`](../sql/12_query_hedging.sql) ·
metoda: [cena zajištění](decisions/ADR-003-forward-price-proxy_cz.md)

Firma koupí předem část roční spotřeby (0, 25, 50, 75 nebo 100 %) jako base load, tedy stejný výkon v každé hodině.
Zbytek platí na spotu. Náklad se zajištěním je `C + podíl × V × (Ph − Pb)`. Cenu zajištění Ph počítám dvakrát:

- průměrná spotová cena předchozího roku (**ASSUMPTION**, náhradní cena, protože OTE nemá forwardové ceny)
- poslední obchod ročního produktu PXE CZ CAL base na konci předchozího roku (**FACT** z výročních zpráv PXE, jen
  pro roky 2022–2024)

Kontroly: při 0 % se obě varianty rovnají nákladu na spotu. Při 100 % se část, kterou firma dál platí na spotu,
rovná `C − V × Pb` z dotazu 10 (2022: 483 332,58 EUR). Rozdíl s náhradní cenou se rovná vlivu ceny na trhu z dotazu
10 s opačným znaménkem.

Rozdíl nákladu při zajištění 100 % spotřeby proti nákupu jen na spotu (EUR, záporné číslo = úspora):

| Rok dodávky | Náklad na spotu | Náhradní cena (EUR/MWh) | Rozdíl s náhradní cenou | Cena PXE (EUR/MWh) | Rozdíl s cenou PXE |
| ----------- | --------------: | ----------------------: | ----------------------: | -----------------: | -----------------: |
| 2021        |       2 981 864 |                   33,62 |      −1 876 652 (−63 %) |                  – |                  – |
| 2022        |       7 399 949 |                  100,66 |      −4 102 833 (−55 %) |             221,88 |   −714 311 (−10 %) |
| 2023        |       2 972 187 |                  247,43 |     +4 098 657 (+138 %) |             241,98 | +3 946 234 (+133 %) |
| 2024        |       2 529 549 |                  100,79 |        +439 875 (+17 %) |              99,03 |   +390 630 (+15 %) |
| 2022–2024   |      12 901 686 |                         |                +435 699 |                    |     **+3 622 554** |

Řádek 2022–2024 je sečtený z přesných hodnot, proto se od součtu zaokrouhlených čísel může lišit o 1 EUR.

- **FINDING:** Když firma zafixuje celou spotřebu jednou na konci roku, krize nezmizí, jen se posune o rok. Nejvyšší
  roční náklad je 7,40 mil. EUR na spotu (2022) a 7,07 mil. EUR při plném zajištění (2023). Elektřinu na rok 2023 by
  totiž firma kupovala ještě za ceny roku 2022 a trh pak v roce 2023 spadl o 59 %.
- **FINDING:** Náhradní cena přínos zajištění v krizovém roce nadsazuje. Se skutečnou cenou PXE z konce roku je
  úspora za rok 2022 jen 0,71 mil. EUR místo 4,10 mil. EUR, protože forwardové ceny vyskočily už na podzim 2021.
  Za roky 2022–2024 by plné zajištění za ceny PXE z konce roku stálo o **3,62 mil. EUR víc** než nákup na spotu.
- **FINDING:** Base load nepokryje přirážku za diagram odběru. I při plném zajištění firma dál platí na spotu
  `C − V × Pb`: 164 030 / 483 333 / 155 344 / 142 087 EUR v letech 2021–2024, tedy 14,8 / 14,7 / 2,2 / 4,8 % nákladu
  se zajištěním.
- **FACT:** Záleží na dni nákupu. Elektřina na rok 2023 stála na burze PXE první obchodní den roku 2022
  123,88 EUR/MWh, 26. 8. 2022 984,00 EUR/MWh a při posledním obchodu roku 28. 12. 2022 241,98 EUR/MWh (výroční zpráva
  PXE 2022, [ADR-003](decisions/ADR-003-forward-price-proxy_cz.md)).
- **RECOMMENDATION:** Zajištění smysl má, jen se nemá kupovat všechno v jeden den. Elektřinu na příští rok je lepší
  nakupovat postupně po částech během celého roku před dodávkou, například na rok 2027 po čtvrtinách během roku 2026,
  a část nechat na spotu. Takový postupný nákup jsem v projektu nepočítal, protože denní ceny z PXE nejsou volně
  ke stažení.

### Nejdražší den firmy

Dotaz: pohled `dbo.vw_hourly_cost` ([`sql/03_create_views.sql`](../sql/03_create_views.sql)) seskupený po dnech

Náklad na silovou elektřinu za den je součet hodinového odběru × cena denního trhu × kurz EUR/CZK, bez regulovaných
plateb, marže a DPH. Firma kupuje všechno na spotu bez zajištění, je to tedy nejhorší případ. Nejdražší den každého
roku vybírá `RANK() OVER (PARTITION BY year ORDER BY SUM(power_cost_czk) DESC)`.

| Rok  | Nejdražší den   | Odběr (MWh) | Náklad na silovou elektřinu (Kč) | Vážená cena (Kč/MWh) | × průměrný den 2020 |
| ---- | --------------- | ----------: | -------------------------------: | -------------------: | ------------------: |
| 2020 | st 9. 12. 2020  |      78,753 |                          186 946 |                2 374 |                 2,6 |
| 2021 | út 21. 12. 2021 |      78,565 |                          912 097 |               11 609 |                12,6 |
| 2022 | út 30. 8. 2022  |      97,792 |                    **1 657 483** |               16 949 |            **22,8** |
| 2023 | po 23. 1. 2023  |      78,511 |                          406 854 |                5 182 |                 5,6 |
| 2024 | čt 12. 12. 2024 |      78,535 |                          830 802 |               10 579 |                11,5 |

Průměrný den (náklad za rok / počet dní) stál 72 545 / 208 584 / 498 512 / 195 233 / 173 651 Kč v letech 2020–2024.
Kontrola: tři nejdražší dny roku 2022 vyjdou na haléř stejně i při výpočtu přímo z tabulek faktů.

- **FINDING:** Na vrcholu krize stál jeden den provozu nezajištěnou firmu 1,66 mil. Kč jen za silovou elektřinu,
  22,8× víc než průměrný den roku 2020 (72 545 Kč). I průměrný den roku 2022 stál 0,50 mil. Kč.
- **FINDING:** Nejdražší den firmy nebyl nejdražším dnem trhu. Trh měl vrchol v pátek 26. 8. 2022 (dotaz 07), firma
  ale zaplatila nejvíc v úterý 30. 8. 2022 (1 657 483 proti 1 629 833 Kč). V pátek ve 22:00 totiž končí mletí, takže
  firma odebrala méně (93,8 proti 97,8 MWh). Kolik firma zaplatí, tedy záleží na ceně i na tom, kolik elektřiny
  odebírá v drahých hodinách.
- **FINDING:** Krize skončila, cenové špičky ale zůstaly. Nejdražší den roku 2024 (12. 12. 2024, Dunkelflaute) stál
  0,83 mil. Kč, skoro tolik jako nejdražší den roku 2021.
- **Omezení:** Skutečné firmy si cenu často fixují dopředu, takže takové denní částky v roce 2022 většinou neplatily.
  V [průzkumu Svazu průmyslu a dopravy ČR](https://www.spcr.cz/drahe-energie-na-firmy-dopadnou-zejmena-v-pristim-roce)
  ze září 2022 (114 převážně průmyslových firem) měly cenu elektřiny na rok 2022 zafixovanou skoro dvě třetiny firem,
  na rok 2023 jen 20 %. Tenhle nejhorší případ porovnává stránka reportu Zajištění ceny s částečně zajištěnou
  spotřebou.
