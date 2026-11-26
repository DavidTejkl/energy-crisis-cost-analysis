# Zpráva o kvalitě dat

[English](data_quality_report.md) · **Čeština**

Databáze `EnergyCrisisCostAnalysis`, období 1. 1. 2020 až 31. 12. 2024. Všechny kontroly jsou v souboru
[sql/91_dq_tests.sql](../sql/91_dq_tests.sql) a spouštím je příkazem
`sqlcmd -S localhost -E -C -b -f 65001 -i sql/91_dq_tests.sql` (skončil bez chyby, exit 0). Kontroly běží
i automaticky na konci pipeline (`python/run_pipeline.py`).

Kontroly jsem pouštěl dvakrát a obě kola tu popisuji. V prvním kole jsem všechno prošel ručně a neobvyklé hodnoty
dohledal ve zdroji. Od druhého kola se výsledky ukládají do databáze, takže každé další spuštění nechá záznam.

## Kolo 1: 28. 9. 2026 (po prvním nahrání dat)

Počty řádků v době kontroly: `dim_date` 1 827 · `dim_hour` 25 · `repo_rate` 22 · `fact_energy_prices` 43 848 ·
`fact_fx` 1 827.

**Shrnutí:** 27 kontrol, 0 chyb v datech. Čtyři výsledky jsem označil k pozornosti, ale jsou to platná data:
záporné ceny, dny se změnou času, extrémní hodiny v P12 a skoky kurzu v F07. Popisuji je níže. Analýza s nimi musí
správně počítat, nesmí je vyhodit.

### fact_energy_prices (granularita: den dodávky + hodina dne)

| ID  | Kontrola | Výsledek | Závažnost | Rozhodnutí | Stav |
| --- | -------- | -------- | --------- | ---------- | ---- |
| P01 | Řádky po letech | 8 784 / 8 760 / 8 760 / 8 760 / 8 784 = 43 848 (podle očekávání) | vysoká | | PASS |
| P02 | Dny podle počtu hodin | 23 h: 5 · 24 h: 1 817 · 25 h: 5 (1 827 dní) | vysoká | | PASS |
| P03 | Dny se změnou času v poslední neděli března (23 h) a října (25 h) | 10 z 10 v pořádku, např. 27. 3. 2022 (23 h), 30. 10. 2022 (25 h) | vysoká | Dny se změnou času jsou platné. Hodina 25 existuje jen v podzimní den změny času | PASS |
| P04 | Dny s mezerou v číslování hodin (první hodina ≠ 1 nebo poslední hodina ≠ počet hodin) | 0 | vysoká | | PASS |
| P05 | Kalendářní dny bez jediného řádku s cenou | 0 | vysoká | | PASS |
| P06 | Duplicitní `date_key + hour_of_day` | 0 (hlídá i primární klíč) | vysoká | | PASS |
| P07 | Chybějící cena / chybějící objem (NULL) | 0 / 0 | vysoká | | PASS |
| P08 | Rozsahy: cena mimo −500 až 5 000 EUR/MWh, objem ≤ 0 | cena −138,75 až 871,00, 0 mimo rozsah. Objem 762,600 až 5 447,800, 0 nekladných | vysoká | V tabulce schválně není podmínka cena > 0 | PASS |
| P09 | Hodiny se zápornou a nulovou cenou po letech | záporné 119 / 33 / 8 / 134 / 315 = 609 (stejně jako zdroj), nulové 15 / 1 / 3 / 22 / 47 | nízká | Platný výsledek trhu, nechávám beze změny | PASS (označeno) |
| P10 | `date_key` / `hour_of_day` bez záznamu v dimenzi | 0 / 0 (hlídají i cizí klíče) | vysoká | | PASS |
| P11 | Cena po letech: min / průměr / max / směrodatná odchylka (EUR/MWh) | 2020: −65,00 / 33,62 / 125,10 / 16,07 · 2021: −36,26 / 100,66 / 620,00 / 71,69 · 2022: −22,45 / 247,43 / 871,00 / 137,52 · 2023: −68,54 / 100,79 / 444,02 / 43,89 · 2024: −138,75 / 85,11 / 844,63 / 51,72 | nízká | Prostý průměr hodin jen pro kontrolu věrohodnosti. Náklad počítám cenou váženou odběrem | PASS |
| P12 | 5 nejdražších hodin | 29. 8. 2022 h20 871,00 · 29. 8. 2022 h21 860,89 · 30. 8. 2022 h21 853,69 · 24. 8. 2022 h20 850,00 · 12. 12. 2024 h18 844,63 | střední | Nechávám (platné hodnoty, viz Ověření označených hodnot) | PASS (označeno) |

### fact_fx (granularita: kalendářní den, dny bez kurzu ČNB doplněné posledním kurzem podle ADR-001)

| ID  | Kontrola | Výsledek | Závažnost | Rozhodnutí | Stav |
| --- | -------- | -------- | --------- | ---------- | ---- |
| F01 | Řádky / skutečné kurzy / doplněné | 1 827 / 1 257 / 570 (1 257 stejně jako zdroj) | vysoká | | PASS |
| F02 | Kalendářní dny bez kurzu | 0 | vysoká | | PASS |
| F03 | Pravidlo doplnění: skutečný kurz s jiným zdrojovým dnem / doplněný kurz, který není z dřívějšího dne / doplnění starší než 4 dny | 0 / 0 / 0, nejdelší doplnění 4 dny | vysoká | [ADR-001](decisions/ADR-001-eur-czk-fill-rule_cz.md) | PASS |
| F04 | Doplněné dny podle dne v týdnu (po až ne) | 14 / 6 / 9 / 6 / 13 / 261 / 261, tedy 522 víkendových dní a 48 svátků ve všední den | nízká | | PASS |
| F05 | Skutečný kurz ČNB o víkendu | 0 | střední | | PASS |
| F06 | Kurz po letech min / průměr / max (Kč za 1 EUR), NULL, mimo 20 až 30 | 2020: 24,795 / 26,451 / 27,810 · 2021: 24,860 / 25,649 / 26,420 · 2022: 24,115 / 24,563 / 25,865 · 2023: 23,275 / 24,006 / 24,725 · 2024: 24,480 / 25,118 / 25,460. NULL 0, mimo pásmo 0 | střední | Důležité pro obchodní otázku 3 (koruna byla v letech 2022–2023 silnější než v roce 2020) | PASS |
| F07 | Největší změna skutečného kurzu mezi dvěma dny (hranice pro chybu při čtení 3 %) | 16. 3. 2020 +3,53 % (z 26,040 na 26,960) · 24. 2. 2022 +2,41 % · 1. 3. 2022 +1,88 % | nízká | Hodnota je stejná jako ve zdroji ČNB, je to skutečný pohyb trhu, nechávám. Data se kryjí s covidovým šokem na trzích a s invazí na Ukrajinu (shoda v čase, ne prokázaná příčina) | PASS (označeno) |
| F08 | Kurzy kolem opakované hlavičky v souboru ČNB za rok 2022 (28. 2. až 4. 3. 2022) | 5 skutečných kurzů 24,995 / 25,465 / 25,865 / 25,645 / 25,735, žádný se neztratil | střední | Řádek s hlavičkou odfiltruje `02_transform.py` | PASS |

### repo_rate (granularita: jedno období platnosti)

| ID  | Kontrola | Výsledek | Závažnost | Rozhodnutí | Stav |
| --- | -------- | -------- | --------- | ---------- | ---- |
| R01 | Počet období, rozsah, rozpětí sazby | 22 období, 3. 5. 2019 až 31. 12. 2024, 0,25 až 7,00 % | střední | První období začíná před rokem 2020 (sazba platná 1. 1. 2020) | PASS |
| R02 | Mezery / překryvy mezi po sobě jdoucími obdobími | 0 / 0 | vysoká | | PASS |
| R03 | Kalendářní dny bez sazby / se dvěma sazbami | 0 / 0 | vysoká | | PASS |

### dim_date a dim_hour

| ID  | Kontrola | Výsledek | Závažnost | Rozhodnutí | Stav |
| --- | -------- | -------- | --------- | ---------- | ---- |
| D01 | Rozsah `dim_date` | 1 827 řádků, 1. 1. 2020 až 31. 12. 2024 = 1 827 kalendářních dní | vysoká | | PASS |
| D02 | Odvozené sloupce proti `full_date`: klíč / rok-měsíc-den / čtvrtletí / týden podle ISO / příznak víkendu | 0 / 0 / 0 / 0 / 0 chybných | vysoká | | PASS |
| D03 | `weekday_num` (1 = pondělí až 7 = neděle) proti známému pondělí 6. 1. 2020 | 0 chybných | střední | | PASS |
| D04 | Popisky v `dim_hour` | noc 10 h (1–6, 22–25) · ráno 4 (7–10) · dopoledne 2 (11–12) · odpoledne 6 (13–18) · večer 3 (19–21) = 25 | nízká | Hodina 25 je noc (hodina navíc při podzimní změně času) | PASS |

### Ověření označených hodnot

Rozhodl jsem (28. 9. 2026), že záporné a nulové ceny (P09), nejvyšší ceny (P12) a skoky kurzu (F07) jsou platná data
a zůstávají beze změny. Neobvyklé hodnoty ověřuji ve zdroji, nemažu je.

- **Záporné ceny pravidla trhu dovolují.** Český denní trh je součástí evropského propojení denních trhů (SDAC).
  Jeho nejnižší povolená cena byla v letech 2020–2024 −500 EUR/MWh (od 28. 5. 2026 se snížila na −600 EUR/MWh, to je
  už mimo moje období): [zpráva OTE](https://www.ote-cr.cz/en/about-ote/ote-news/harmonised-minimum-clearing-price-for-sdac-to-be-set-to-600-eur-mwh-starting-from-the-28th-may-2026-trading-date).
  Nejnižší hodnota −138,75 EUR/MWh z 12. 5. 2024, hodina 14, je i v původním souboru OTE
  (`Rocni_zprava_o_trhu_2024_V2.xlsx`, list `DT ČR`), spolu s hodnotou OTE v korunách −3 459,731 Kč/MWh.
- **Kdy ceny klesají na nulu a pod ni (výsledek dotazu, 2020–2024):** v hodinách 13–16 je 309 z 609 záporných hodin,
  v dubnu až srpnu 481. O víkendu 476 z 12 528 hodin (3,8 %), v pracovní dny 133 z 31 320 (0,4 %).
  `ASSUMPTION`: přebytek fotovoltaiky v poledne při nízké spotřebě. 1. 5. 2024 (svátek ve středu) se chová jako
  víkend.
- **12. 12. 2024, hodina 18 (17:00–18:00), 844,63 EUR/MWh.** Původní soubor OTE jsem zkontroloval v Excelu
  ([snímek obrazovky](screenshots/bronze_ote_2024-12-12_price_peak_excel.png)): cena během večera plynule roste
  a klesá (hodiny 14–21: 380,01 · 448,48 · 601,61 · 795,12 · 844,63 · 670,00 · 547,94 · 294,48) a sedí i odvozené
  sloupce v souboru (844,63 × 25,065 = 21 170,65 Kč/MWh, 844,63 × 4 935,6 MWh = 4 168 755,83 EUR).
  `FACT` (vnější zdroj): ve stejné hodině vrcholila v Německu Dunkelflaute (zima, skoro žádný vítr ani slunce)
  a cena denního trhu tam mezi 17:00 a 18:00 dosáhla 936 EUR/MWh
  ([Clean Energy Wire](https://www.cleanenergywire.org/news/short-term-power-prices-spike-amid-new-dunkelflaute-germany-most-customers-unaffected)).
  Český a německý trh jsou v SDAC propojené, i když přeshraniční kapacita je omezená.
- **Srpen 2022 (871,00 EUR/MWh 29. 8. 2022, hodina 20)** je vrchol energetické krize, kterou projekt měří.
- **Skoky kurzu v F07** jsou stejné jako ve zdroji ČNB. Data se kryjí s covidovým šokem na trzích (16. 3. 2020)
  a s invazí na Ukrajinu (24. 2. 2022). Je to shoda v čase, ne prokázaná příčina.

### Co musí analýza dodržet

- Sčítat a vážit přes řádky, které opravdu existují. Nikdy nenásobit „dny × 24“, protože dny se změnou času mají
  23 nebo 25 hodin.
- Záporné a nulové ceny patří k trhu. Průměry i náklady s nimi počítají.
- `fact_fx` má kurz pro každý den. `is_actual_rate = 0` označuje 570 doplněných dní (ADR-001).
- Repo sazba se ke dnům připojuje podle období (`full_date BETWEEN valid_from AND valid_to`), každý den najde právě
  jednu sazbu (R03).

## Kolo 2: 2. 11. 2026 (výsledky uložené v tabulce `dq_results`)

Od tohoto kola zapíše každá z 18 kontrol, které mají pravidlo „projde / neprojde“, jeden řádek do tabulky
`dq_results` ([sql/90_etl_infrastructure.sql](../sql/90_etl_infrastructure.sql)), všechny se stejným časem `run_at`.
Popisné kontroly (počty po letech, statistiky, nejvyšší hodnoty) se dál jen vypisují. Poslední výstup skriptu ukáže
uložené řádky.

| Stav | Kontroly |
| ---- | -------- |
| PASS (0 chybných řádků) | P04, P05, P06, P07, P08, P10, F02, F03, F05, R02, R03, D02, D03, L01, L02, G01, G02 |
| WARN | P09 hodiny se zápornou cenou: 609 (platný výsledek trhu, nechávám schválně) |
| FAIL | žádná |

Přibyly čtyři kontroly pro dvě tabulky, které jsem přidal později:

- **L01:** odběr a ceny mají stejné hodiny (stejná granularita).
- **L02:** odběr je označený jako simulovaný.
- **G01:** každá regulovaná složka má na každý den právě jednu cenu.
- **G02:** složek je osm.

Ověřil jsem i to, že kontroly umí selhat. Uvnitř transakce jsem v `dim_date` označil jeden pracovní den jako
víkend a v `fact_fx` jeden sobotní kurz jako skutečný kurz ČNB. Skript uložil FAIL pro D02, F03 a F05 (po jednom
řádku). Pro nové kontroly jsem smazal jednu hodinu odběru a prodloužil jedno období platnosti o den, skript uložil
FAIL pro L01 a G01. Po ROLLBACK byla data i `dq_results` beze změny.

Výsledky posledního spuštění vypíše tento dotaz:

```sql
SELECT test_id, test_name, failed_rows, status
FROM dbo.dq_results
WHERE run_at = (SELECT MAX(run_at) FROM dbo.dq_results)
ORDER BY dq_result_id;
```
