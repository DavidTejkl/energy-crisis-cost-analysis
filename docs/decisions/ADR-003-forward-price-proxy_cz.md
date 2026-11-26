# ADR-003: Cena zajištění (průměr spotu předchozího roku, ceny PXE pro porovnání)

[English](ADR-003-forward-price-proxy.md) · **Čeština**

- Datum: 2026-10-14

## Proč bylo potřeba rozhodnout

Obchodní otázka 4 se ptá, jestli se firma mohla proti krizi zajistit. Kolik by stála elektřina, kdyby 0, 25, 50, 75
nebo 100 % roční spotřeby koupila předem za pevnou cenu? K tomu potřebuji pevnou cenu, kterou by si firma mohla
zafixovat ještě před rokem dodávky.

- OTE zveřejňuje jen ceny denního trhu (spot), forwardové ceny ne.
- České forwardové kontrakty se obchodují na burzách PXE a EEX. Jejich denní historie cen je placený datový produkt,
  volně ke stažení není. Výroční zprávy PXE jsou ale veřejná PDF a v textu uvádějí jednotlivé ceny ročního produktu
  base load pro Česko (CZ CAL-YY).
- Base load dodává stejný výkon v každé hodině, proto mu na spotu odpovídá prostý průměr hodinových cen (každá hodina
  má stejnou váhu). Nejde o průměr z průměrů: vlastní náklad firmy dál počítám cenou váženou odběrem.
- Moje spotová data začínají 1. 1. 2020, takže průměr předchozího roku mám pro roky dodávky 2021–2024.

Co jsem zjistil 14. 10. 2026 (EUR/MWh):

| Rok dodávky | Průměrná spotová cena předchozího roku (OTE) | PXE CZ CAL base, první obchodní den předchozího roku | Rozpětí PXE v předchozím roce                      | PXE, poslední obchod předchozího roku | Zdroj                          |
| ----------- | -------------------------------------------: | ---------------------------------------------------: | -------------------------------------------------- | ------------------------------------- | ------------------------------ |
| 2021        |                                        33,62 |                                                    – | v březnu 2020 klesla na 38                         | neuvedeno                             | Výroční zpráva PXE 2020, s. 12 |
| 2022        |                                       100,66 |                                                53,17 | 163,83 (začátek října) · max 326,80 (22. 12. 2021) | 221,88                                | Výroční zpráva PXE 2021, s. 11 |
| 2023        |                                       247,43 |                                               123,88 | 371,68 (7. 7.) · max 984,00 (26. 8. 2022)          | 241,98 (28. 12. 2022)                 | Výroční zpráva PXE 2022, s. 11 |
| 2024        |                                       100,79 |                                               216,27 | –                                                  | 99,03 (27. 12. 2023)                  | Výroční zpráva PXE 2023        |

Průměrná spotová cena předchozího roku je `AVG(price_eur_mwh)` po letech z `fact_energy_prices`
(2020 33.621243 · 2021 100.659704 · 2022 247.433603 · 2023 100.785440 · 2024 85.105306). Ověřil jsem ji druhým dotazem,
který bere rok z `date_key` místo z `dim_date`.

Zdroje: výroční zprávy PXE 2020–2023 na `https://www.pxe.cz`, v části O nás, Výroční zprávy.

## Jaké možnosti jsem zvažoval

1. Skutečné forwardové ceny (denní vypořádací ceny PXE nebo EEX). Jsou to placená data, do veřejného repozitáře je dát
   nemůžu.
2. Klouzavý průměr spotu za 12 měsíců před zvoleným dnem nákupu. Je blíž praxi, ale přidává druhý předpoklad (který
   den firma kupuje) a zpoždění za trhem stejně neodstraní.
3. Prostý průměr spotu za předchozí kalendářní rok jako náhradní cena a několik skutečných cen PXE z výročních zpráv
   pro porovnání.

## Co jsem vybral

Možnost 3.

- Hlavní cena zajištění (`ASSUMPTION`): prostý průměr ceny denního trhu OTE za kalendářní rok před dodávkou. Používá
  jen informace, které firma v době rozhodnutí znala, takže výsledek neovlivňuje znalost budoucí ceny.
- Porovnání (`FACT`): cena PXE CZ CAL base při posledním obchodu předchozího roku pro roky 2022, 2023 a 2024
  (221,88 / 241,98 / 99,03 EUR/MWh), citovaná se zdrojem. Rozpětí během roku uvádím zvlášť, protože i to, kdy firma
  nakoupí, je riziko.
- Analýza zajištění pokrývá roky dodávky 2021–2024. Rok 2020 nemá spotová data za předchozí rok a rok 2021 má jen
  náhradní cenu.

## Co z toho plyne

- V klidných letech se náhradní cena od ceny PXE z konce roku liší jen asi o 2 % (2023: +2,3 %, 2024: +1,8 %). Pro rok
  2022 je ale o 55 % nižší (100,66 proti 221,88). V krizovém roce tak náhradní cena ukazuje zajištění levnější, než
  ve skutečnosti bylo, a jeho přínos pro rok 2022 nadsazuje. Zjištění proto musí ukázat obě varianty.
- Každá cena zajištění je označená buď jako náhradní cena, nebo jako citovaná cena PXE, nikdy jako cena smlouvy firmy.
- Omezení, která uvádím ve zjištěních:
  - Skutečná firma nemusí kupovat v jeden den, může nakupovat po částech během roku před dodávkou. Cena z konce roku
    je jediný bod, který veřejný zdroj uvádí pro každý rok. Není to doporučené datum nákupu.
  - Base load pokrývá stejný objem v každé hodině. Firma se směnami odebírá jinak, takže zbytek dál kupuje na spotu.
    Počítá s tím dotaz [sql/12_query_hedging.sql](../../sql/12_query_hedging.sql).
- Ceny jsou v EUR/MWh. Na koruny je v dotazech na náklad převádím kurzem ČNB
  ([ADR-001](ADR-001-eur-czk-fill-rule_cz.md)).
