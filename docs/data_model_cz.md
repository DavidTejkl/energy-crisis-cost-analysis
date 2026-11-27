# Datový model

[English](data_model.md) · **Čeština**

Databáze `EnergyCrisisCostAnalysis` je hvězdicové schéma se dvěma faktovými tabulkami, které sdílejí stejné dimenze
(části 1–7). K tomu patří dvě tabulky pro běh pipeline (část 8) a pohledy, ze kterých čte Power BI (část 9). Tabulky
vytváří [sql/02_create_tables.sql](../sql/02_create_tables.sql), pohledy [sql/03_create_views.sql](../sql/03_create_views.sql).
Granularitu každé tabulky jsem sem zapsal dřív, než jsem do ní poprvé nahrál data.

Granularita (grain) říká, co přesně znamená jeden řádek tabulky. Když ji vím předem, nestane se mi, že při spojování
tabulek nečekaně namnožím řádky a sečtu stejné číslo víckrát.

## 1. fact_energy_prices

Zdrojové soubory: `data/bronze/ote/`

### Granularita

Jeden řádek = cena a zobchodované množství pro jednu hodinu dodávky v jednom dni. Kombinace `date_key` + `hour_of_day`
se nikdy neopakuje. Stejný `date_key` je na 23 až 25 řádcích (jeden za každou hodinu), takže vztah `dim_date`
a `fact_energy_prices` je 1:N (jeden ku mnoha).

### Primární klíč

`date_key`, `hour_of_day` (složený klíč)

### Cizí klíče

- `date_key` odkazuje na `dim_date.date_key`
- `hour_of_day` odkazuje na `dim_hour.hour_of_day`

### Sloupce

| Sloupec         | Formát             | Popis                                                                                   |
| --------------- | ------------------ | --------------------------------------------------------------------------------------- |
| `date_key`      | celé číslo (YYYYMMDD) | den dodávky, odkaz na `dim_date` (samotné datum je jen v `dim_date`)                  |
| `hour_of_day`   | celé číslo         | pořadová hodina dne dodávky (1–23, 1–24 nebo 1–25 kvůli změně času), odkaz na `dim_hour` |
| `price_eur_mwh` | DECIMAL(7,2)       | cena v EUR/MWh pro danou hodinu a den, záporné ceny jsou platné (žádný CHECK > 0)        |
| `volume_mwh`    | DECIMAL(9,3)       | zobchodované množství v MWh pro danou hodinu a den                                      |

Poznámky k typům:
- `price_eur_mwh`: OTE zveřejňuje ceny na 2 desetinná místa. V letech 2020–2024 jsou mezi −138,75 a 871,00 a `(7,2)`
  pojme až ±99 999,99, takže ani budoucí cenová špička nahrávání nerozbije.
- `volume_mwh`: není celé číslo. Většina hodin má 1 desetinné místo, ale 32 hodin v roce 2024 má 3 desetinná místa
  přímo ve zdrojovém souboru OTE (např. 2086,199). Ukládám plnou přesnost ze zdroje a zaokrouhluji až při zobrazení.
- `price_czk_mwh` se NEUKLÁDÁ. Je to odvozená hodnota (`price_eur_mwh × rate_czk_per_eur`) a počítá se v pohledech
  spojením s `fact_fx` přes `date_key`. Kurz je tak uložený jen na jednom místě.

## 2. dim_date

### Granularita

Jeden řádek = jeden kalendářní den. Pokrývá celé období projektu 2020–2024 (1 827 dní).

### Primární klíč

`date_key`, takzvaný chytrý klíč ve formátu `YYYYMMDD` (např. 31. 1. 2022 je `20220131`). Na rozdíl od obyčejného
pořadového čísla (1, 2, 3…) je z hodnoty vidět, o jaké datum jde, a pořád je to rychlé celé číslo pro spojování.

### Sloupce

| Sloupec        | Formát                | Popis                                                                                       |
| -------------- | --------------------- | ------------------------------------------------------------------------------------------- |
| `date_key`     | celé číslo (YYYYMMDD) | primární klíč                                                                               |
| `full_date`    | datum                 | skutečné kalendářní datum                                                                   |
| `day_of_month` | celé číslo (1–31)     | den v měsíci                                                                                |
| `month`        | celé číslo (1–12)     | měsíc                                                                                       |
| `year`         | celé číslo            | rok                                                                                         |
| `quarter`      | celé číslo (1–4)      | čtvrtletí                                                                                   |
| `week_of_year` | celé číslo (1–53)     | číslo týdne podle ISO (týden začíná pondělím). Některé roky mají 53. týden, např. 1.–3. 1. 2021 patří do 53. týdne roku 2020 |
| `weekday_num`  | celé číslo (1–7)      | den v týdnu jako číslo, 1 = pondělí (pro řazení a filtrování)                               |
| `weekday_name` | text                  | den v týdnu česky, Pondělí až Neděle (pro čitelnost)                                        |
| `is_weekend`   | 0/1                   | 1 = víkend, 0 = pracovní den                                                                |

## 3. dim_hour

### Granularita

Jeden řádek = jedna pořadová hodina dne, 1 až 25 kvůli změně času (viz zadání). Celkem 25 řádků. Neopakuje se pro
každý den (na rozdíl od `dim_date`, která má řádek za každý den).

### Primární klíč

`hour_of_day`, přirozený klíč. Umělé `hour_id` není potřeba, protože `hour_of_day` je samo malé a jedinečné celé
číslo.

### Sloupce

| Sloupec       | Formát            | Popis                                                                                             |
| ------------- | ----------------- | ------------------------------------------------------------------------------------------------- |
| `hour_of_day` | celé číslo (1–25) | primární klíč, pořadová hodina dne                                                                |
| `time_of_day` | text              | část dne česky podle `hour_of_day`: `ráno` 7–10 · `dopoledne` 11–12 · `odpoledne` 13–18 · `večer` 19–21 · `noc` všechny ostatní hodiny (1–6, 22–25) |

Špička a mimo špičku tu sloupec nemají. Tržní definice špičky (pondělí až pátek, 8:00 až 20:00) kombinuje hodinu
a den v týdnu, proto ji počítá dotaz [sql/09_query_peak_offpeak.sql](../sql/09_query_peak_offpeak.sql) spojením
`dim_hour` a `dim_date`.

## 4. fact_fx

Zdrojové soubory: `data/bronze/cnb/cnb_fx_*.txt`. ČNB vyhlašuje kurz jen v pracovní dny. Po vyčištění v
`python/02_transform.py` ([ADR-001](decisions/ADR-001-eur-czk-fill-rule_cz.md)) má tabulka řádek pro KAŽDÝ kalendářní
den období, včetně víkendů a svátků. Každá hodina v `fact_energy_prices` tak najde svůj kurz přes `date_key` (jeden
kurz za den, 23 až 25 hodin za den).

### Granularita

Jeden řádek = kurz EUR/CZK, který v daný den platí. Buď ten, který ČNB ten den vyhlásila, nebo převzatý z dřívějšího
dne podle pravidla pro víkendy a svátky (viz `is_actual_rate`).

### Primární klíč

`date_key` (`YYYYMMDD`), stejně jako v `dim_date`. Je to zároveň cizí klíč na `dim_date.date_key` (na obou stranách
jeden řádek za den).

### Sloupce

| Sloupec            | Formát                | Popis                                                                            |
| ------------------ | --------------------- | -------------------------------------------------------------------------------- |
| `date_key`         | celé číslo (YYYYMMDD) | primární klíč a cizí klíč na `dim_date`                                          |
| `rate_czk_per_eur` | DECIMAL(5,3)          | kurz, kolik Kč stojí 1 EUR, musí být > 0 (CHECK)                                 |
| `is_actual_rate`   | 0/1                   | 1 = ČNB ten den kurz vyhlásila, 0 = převzatý z dřívějšího dne                     |
| `source_date`      | datum                 | den, ze kterého kurz opravdu pochází. Když `is_actual_rate = 1`, je to datum řádku, když `is_actual_rate = 0`, datum posledního vyhlášeného kurzu. Nikdy není NULL, aby se v dotazech nemuselo řešit NULL. Je to obyčejné datum, ne klíč: pro 1. 1. 2020 je to 2019-12-31, a to už v `dim_date` není. |

Poznámka k typu: ČNB uvádí kurz nejvýš na 3 desetinná místa. V letech 2020–2024 byl mezi 23,275 a 27,81 a `(5,3)` pojme
až 99,999. Kurz nemůže být nulový ani záporný, takže tady je CHECK > 0 bezpečný (na rozdíl od cen elektřiny).

## 5. repo_rate (tabulka s obdobím platnosti)

Zdrojový soubor: `data/bronze/cnb/vyvoj_repo_historie.txt`. Na rozdíl od `fact_fx` tahle tabulka NENÍ rozepsaná na
každý den. Zůstává krátká: 22 období, sazba platná od 3. 5. 2019 a 21 změn v letech 2020–2024. Se dny se spojuje
podmínkou na rozsah (`WHERE d.full_date BETWEEN r.valid_from AND r.valid_to`, `d` = `dim_date`), ne rovností.
Stejně fungují i regulované ceny (část 7). Repo sazba je nahraná a otestovaná, ale zatím ji nepoužívá žádný
analytický dotaz (jen kontext, viz Omezení v README).

### Granularita

Jeden řádek = jedno období, po které platila jedna hodnota repo sazby (ne jeden den).

### Primární klíč

`valid_from` (datum), den, od kterého sazba platí.

Obě hranice ukládám jako datum, ne jako klíč `YYYYMMDD`. Porovnání rozsahu potřebuje na obou stranách stejný typ
a `valid_from` stejně nemůže být cizí klíč na `dim_date`, protože první období začíná 3. 5. 2019, ještě před
začátkem `dim_date`.

### Sloupce

| Sloupec         | Formát       | Popis                                                                               |
| --------------- | ------------ | ----------------------------------------------------------------------------------- |
| `valid_from`    | datum        | primární klíč, začátek platnosti (zdrojový sloupec `PLATNA_OD`, ve zdroji text `YYYYMMDD`) |
| `valid_to`      | datum        | konec platnosti, den před `valid_from` dalšího řádku (počítá `python/02_transform.py`). Poslední řádek má poslední den `dim_date` (2024-12-31), aby nebyl NULL |
| `repo_rate_pct` | DECIMAL(4,2) | repo sazba v % (zdrojový sloupec `CNB_REPO_SAZBA_V_%`)                              |

Poznámka k typu: repo sazba ČNB má nejvýš 2 desetinná místa. V letech 2020–2024 byla mezi 0,25 a 7,00 a `(4,2)` pojme
−99,99 až 99,99. Znaménko CHECK nehlídá: centrální banky můžou mít záporné sazby (např. depozitní sazba ECB byla
v letech 2019–2022 −0,50 %), takže záporná hodnota je platný výsledek, ne chyba. CHECK `valid_from <= valid_to`
odmítne období, které končí dřív, než začne (jednodenní období je povolené).

## 6. fact_load (SIMULATED)

Zdrojový soubor: `data/silver/fact_load.csv`, vytváří ho `python/04_generate_load_profile.py` (postup v
[metodice](methodology_cz.md)). Modelová firma je vymyšlená, takže je simulovaný každý řádek.

### Granularita

Jeden řádek = elektřina, kterou modelová firma odebrala v jedné hodině dodávky v jednom dni. Granularita je stejná jako
u `fact_energy_prices` (43 848 řádků), ale je to samostatná faktová tabulka. Ceny jsou skutečná tržní data z OTE,
odběr je simulace vymyšlené firmy, tedy jiný proces a jiný druh dat. Obě faktové tabulky sdílejí stejné dimenze
(`dim_date`, `dim_hour`) a spojují se přes ně, nikdy cizím klíčem z jedné faktové tabulky do druhé.

### Primární klíč

`date_key`, `hour_of_day` (složený klíč)

### Cizí klíče

- `date_key` odkazuje na `dim_date.date_key`
- `hour_of_day` odkazuje na `dim_hour.hour_of_day`

### Sloupce

| Sloupec        | Formát                | Popis                                                                  |
| -------------- | --------------------- | ---------------------------------------------------------------------- |
| `date_key`     | celé číslo (YYYYMMDD) | den dodávky, odkaz na `dim_date`                                       |
| `hour_of_day`  | celé číslo            | pořadová hodina dne dodávky (1–25), odkaz na `dim_hour`                |
| `load_mwh`     | DECIMAL(5,3)          | odběr v MWh v dané hodině (v letech 2020–2024 mezi 1,428 a 4,665), CHECK ≥ 0 |
| `is_simulated` | bit                   | 1 = simulovaná hodnota, v této tabulce vždy 1 (CHECK = 1)              |

## 7. regulated_price (tabulka s obdobím platnosti)

Zdrojový soubor: `config/tariffs.csv`, který jsem ručně přepsal z cenových rozhodnutí ERÚ a ze zákona o dani
z elektřiny. Každý řádek má ve sloupci `source` uvedený zdroj. Funguje stejně jako `repo_rate`: krátká období
platnosti, se dny spojená podmínkou na rozsah (`d.full_date BETWEEN t.valid_from AND t.valid_to`).

### Granularita

Jeden řádek = jedna regulovaná složka ceny v jednom období platnosti. Většina období trvá jeden kalendářní rok.
Když se cena složky změní během roku, dostane složka další řádek (např. POZE od 1. 10. 2022 na 0 podle cenového
rozhodnutí ERÚ 8/2022). Celkem 41 řádků: 8 složek × 5 let + 1 období POZE navíc v roce 2022.

### Primární klíč

`valid_from`, `component` (složený klíč). Samotné `valid_from` jedinečné není, protože 1. 1. 2024 začíná osm složek
najednou. `valid_to` v klíči není, složka a začátek období ho určují jednoznačně.

### Sloupce

| Sloupec      | Formát        | Popis                                                                    |
| ------------ | ------------- | ------------------------------------------------------------------------ |
| `component`  | text          | krátký kód, např. `network_use`, `poze_per_mw`, `electricity_tax`        |
| `value`      | DECIMAL(9,2)  | cena v jednotce daného řádku, CHECK ≥ 0                                  |
| `unit`       | text          | `CZK/MWh`, `CZK/MW/month` nebo `CZK/supply_point/month` (CHECK)          |
| `valid_from` | datum         | první den platnosti                                                      |
| `valid_to`   | datum         | poslední den platnosti (včetně)                                          |
| `source`     | text          | cenové rozhodnutí a bod, např. `ERU 5/2023 point 4.40`                   |

Kontrola dat (17. 10. 2026): každá složka pokrývá každý den let 2020–2024 právě jednou (0 dní bez ceny, 0 dní se dvěma
cenami). Stejné pravidlo hlídá při každém běhu kontrola G01 v `sql/91_dq_tests.sql`.

## 8. Tabulky pipeline ([sql/90_etl_infrastructure.sql](../sql/90_etl_infrastructure.sql))

Nepatří do hvězdicového schématu: popisují běh pipeline, ne byznys. Vytvoří se jen tehdy, když ještě neexistují (žádný
DROP), takže při přestavbě modelu se jejich historie zachová. Nemají cizí klíče na model, protože zapsat se musí
i neúspěšný běh, když jsou tabulky modelu prázdné. Poslední nahraný den faktové tabulky čtu jako `MAX(date_key)`
přímo z ní, takže samostatnou tabulku s watermarkem nepotřebuji.

### etl_run_log

Granularita: jeden řádek = jedno nahrání jedné tabulky v jednom běhu. Primární klíč `run_id` (IDENTITY): běh nemá
přirozený klíč a dva běhy můžou začít ve stejné sekundě.

| Sloupec         | Formát    | Popis                                                             |
| --------------- | --------- | ----------------------------------------------------------------- |
| `run_id`        | int       | pořadové číslo, které přidělí SQL Server                          |
| `script_name`   | text      | např. `03_load.py`                                                |
| `table_name`    | text      | nahrávaná tabulka, NULL u kroku bez tabulky                       |
| `started_at`    | datetime  | začátek kroku                                                     |
| `finished_at`   | datetime  | konec kroku, NULL během běhu nebo po pádu                         |
| `rows_inserted` | int       | vložené řádky, ≥ 0                                                |
| `rows_updated`  | int       | změněné řádky, ≥ 0                                                |
| `status`        | text      | `RUNNING`, `OK` nebo `FAIL`                                       |
| `error_message` | text      | text chyby při `FAIL`                                             |

### dq_results

Granularita: jeden řádek = jedna kontrola kvality dat v jednom běhu. Primární klíč `dq_result_id` (IDENTITY).

| Sloupec        | Formát   | Popis                                                               |
| -------------- | -------- | ------------------------------------------------------------------- |
| `dq_result_id` | int      | pořadové číslo, které přidělí SQL Server                            |
| `run_at`       | datetime | čas běhu kontrol                                                    |
| `test_id`      | text     | číslo kontroly jako v `sql/91_dq_tests.sql`, např. `P05`            |
| `test_name`    | text     | krátký popis                                                        |
| `failed_rows`  | int      | počet řádků, které pravidlo porušují, ≥ 0                           |
| `status`       | text     | `PASS`, `WARN` (platná hodnota označená záměrně) nebo `FAIL`        |

## 9. Pohledy (vrstva gold, [sql/03_create_views.sql](../sql/03_create_views.sql))

Pohledy jsou vrstva gold: Power BI z nich importuje čtyři, k tomu `dim_date` a `dim_hour`. V Power BI je `dim_date`
napojená na všechny čtyři pohledy přes `date_key` a `dim_hour` na hodinový pohled přes `hour_of_day`, vždy 1:N
a jedním směrem (5 vazeb, schéma typu galaxy). Měsíční a roční pohled nesou `date_key` prvního dne svého období,
takže je výběr roku filtruje přes `dim_date` stejně jako hodinový pohled.

| Pohled                 | Granularita                               | Řádků  | Kdo ho používá                       |
| ---------------------- | ----------------------------------------- | -----: | ------------------------------------ |
| `vw_hourly_cost`       | jedna hodina jednoho dne                  | 43 848 | Power BI                             |
| `vw_monthly_cost`      | jeden měsíc                               |     60 | Power BI                             |
| `vw_yearly_hedging`    | jeden rok dodávky (2021–2024)             |      4 | Power BI                             |
| `vw_cost_change_steps` | jeden rok a jeden krok změny nákladu      |     20 | Power BI (vodopádový graf)           |
| `vw_energy_prices_czk` | jedna hodina jednoho dne                  | 43 848 | analytické dotazy ve složce `sql/`   |
| `vw_daily_summary`     | jeden den                                 |  1 827 | do Power BI se neimportuje (pokryje ho hodinový pohled) |

Náklady a MWh z pohledů jde sčítat za libovolné období. Ceny a kurzy platí jen pro svou hodinu nebo rok a nikdy se
nesčítají. V Power BI mají nastavené „nesumarizovat“ a každá cena v reportu je podíl součtů
(`DIVIDE(SUM(náklad), SUM(odběr))`), nikdy průměr z průměrů.

### Sloupce čtyř pohledů pro Power BI

Formáty jsou typy, které pro sloupce pohledů hlásí SQL Server (`sys.columns`). Součet přes mnoho řádků dostane
přesnost 38 automaticky.

#### vw_hourly_cost

| Sloupec            | Formát                | Popis                                                                                          |
| ------------------ | --------------------- | ---------------------------------------------------------------------------------------------- |
| `date_key`         | celé číslo (YYYYMMDD) | den dodávky, odkaz na `dim_date`                                                                |
| `hour_of_day`      | celé číslo            | pořadová hodina dne dodávky (1–25), odkaz na `dim_hour`                                         |
| `price_eur_mwh`    | DECIMAL(7,2)          | cena denního trhu OTE v EUR/MWh (z `fact_energy_prices`)                                        |
| `rate_czk_per_eur` | DECIMAL(5,3)          | kurz ČNB EUR/CZK daného dne (z `fact_fx`, víkendy a svátky doplněné podle ADR-001)              |
| `price_czk_mwh`    | DECIMAL(13,5)         | cena v Kč/MWh = `price_eur_mwh × rate_czk_per_eur`, nezaokrouhlená                              |
| `load_mwh`         | DECIMAL(5,3)          | odběr firmy v dané hodině, `SIMULATED` (z `fact_load`)                                          |
| `power_cost_eur`   | DECIMAL(13,5)         | náklad na silovou elektřinu v hodině v EUR = `load_mwh × price_eur_mwh`                         |
| `power_cost_czk`   | DECIMAL(19,8)         | náklad na silovou elektřinu v hodině v Kč = `load_mwh × price_eur_mwh × rate_czk_per_eur`       |
| `price_band`       | NVARCHAR(8)           | [cenové pásmo](kpi_definitions_cz.md#cenové-pásmo) hodiny: `záporná` (pod 0), `nízká` (pod 1 217), `běžná` (pod 3 374), `vysoká` (pod 5 821), `extrémní` (od 5 821 Kč/MWh) |
| `price_band_order` | celé číslo            | 1–5, pořadí `price_band` v Power BI (tam je skrytý)                                             |

#### vw_monthly_cost

Všechny částky jsou v Kč za celý měsíc, bez DPH a marže dodavatele ([ADR-005](decisions/ADR-005-all-in-price-scope_cz.md)).

| Sloupec                 | Formát                | Popis                                                                                  |
| ----------------------- | --------------------- | -------------------------------------------------------------------------------------- |
| `date_key`              | celé číslo (YYYYMMDD) | první den měsíce (`year × 10000 + month × 100 + 1`), odkaz na `dim_date`               |
| `year`                  | celé číslo            | rok                                                                                    |
| `month`                 | celé číslo            | měsíc 1–12                                                                             |
| `load_mwh`              | DECIMAL(38,3)         | odběr firmy za měsíc, `SIMULATED`                                                       |
| `power_cost_czk`        | DECIMAL(38,8)         | náklad na silovou elektřinu = součet hodinových odběrů × ceny v Kč                      |
| `electricity_tax_czk`   | DECIMAL(38,5)         | daň z elektřiny = odběr × sazba v Kč/MWh                                                |
| `network_use_czk`       | DECIMAL(38,5)         | distribuce, použití sítí = odběr × sazba v Kč/MWh                                       |
| `system_services_czk`   | DECIMAL(38,5)         | systémové služby = odběr × sazba v Kč/MWh                                               |
| `reserved_capacity_czk` | DECIMAL(38,2)         | distribuce, rezervovaná kapacita = měsíční cena za MW × 5 MW (`ASSUMPTION`)             |
| `ote_fees_czk`          | DECIMAL(38,2)         | dva měsíční poplatky OTE za odběrné místo                                               |
| `poze_czk`              | DECIMAL(38,2)         | POZE (podpora obnovitelných zdrojů) = nižší z ceny za MW × 5 MW a stropu za MWh × odběr |
| `total_cost_czk`        | DECIMAL(38,2)         | součet všech složek výše = měsíční účet                                                 |

#### vw_yearly_hedging

Jeden řádek = jeden rok dodávky 2021–2024, částky v EUR ([ADR-003](decisions/ADR-003-forward-price-proxy_cz.md)).

| Sloupec                | Formát                | Popis                                                                                         |
| ---------------------- | --------------------- | --------------------------------------------------------------------------------------------- |
| `date_key`             | celé číslo (YYYYMMDD) | 1. leden daného roku (`year × 10000 + 101`), odkaz na `dim_date`                              |
| `year`                 | celé číslo            | rok dodávky                                                                                   |
| `volume_mwh`           | DECIMAL(38,3)         | roční odběr, `SIMULATED`                                                                       |
| `spot_cost_eur`        | DECIMAL(38,5)         | náklad na silovou elektřinu při nákupu všeho na spotu = součet hodinových odběrů × ceny        |
| `market_price_eur_mwh` | DECIMAL(38,6)         | prostý průměr hodinových cen roku (jen pro zobrazení, nikdy se nesčítá)                        |
| `hedge_price_eur_mwh`  | DECIMAL(38,6)         | pevná cena = prostý průměr předchozího roku (`ASSUMPTION`)                                     |
| `pxe_price_eur_mwh`    | NUMERIC(5,2)          | roční produkt PXE CZ base load, poslední obchod předchozího roku (`FACT`, výroční zprávy PXE), pro rok 2021 NULL |
| `hedge_diff_proxy_eur` | DECIMAL(38,6)         | `volume_mwh × (hedge_price_eur_mwh − market_price_eur_mwh)`: o kolik víc (+) nebo méně (−) stojí celý roční objem za pevnou cenu. Náklad se zajištěním podílu *s* = `spot_cost_eur + s × hedge_diff_proxy_eur` |
| `hedge_diff_pxe_eur`   | NUMERIC(38,6)         | totéž s cenou PXE, pro rok 2021 NULL                                                           |

#### vw_cost_change_steps

Jeden řádek = jeden rok 2021–2024 a jeden krok, částky v Kč ([ADR-004](decisions/ADR-004-cost-variance-split_cz.md),
[ADR-006](decisions/ADR-006-fx-effect-split_cz.md)).

| Sloupec      | Formát                | Popis                                                                                                |
| ------------ | --------------------- | ---------------------------------------------------------------------------------------------------- |
| `date_key`   | celé číslo (YYYYMMDD) | 1. leden daného roku, odkaz na `dim_date`                                                             |
| `year`       | celé číslo            | rok, jehož změnu nákladu rozkládám                                                                    |
| `step_order` | celé číslo            | 1–5, pořadí kroků (v Power BI skrytý)                                                                 |
| `step_name`  | NVARCHAR(17)          | krok: `Náklad minulý rok`, `Spotřeba`, `Cena na trhu`, `Diagram odběru`, `Kurz EUR/CZK`               |
| `amount_czk` | DECIMAL(38,6)         | krok 1 = náklad na silovou elektřinu v předchozím roce, kroky 2–5 = vliv spotřeby, ceny na trhu, diagramu odběru a kurzu. Předchozí rok + 4 kroky = letošní náklad s rozdílem do 2 Kč (zaokrouhlení kurzu) |

Power BI k tomu přidává dva počítané sloupce v DAX, které v SQL nejsou: `dim_date[month_start]` (první den měsíce,
osa měsíčních grafů) a `vw_hourly_cost[hour_key]` (`date_key × 100 + hour_of_day`, jedinečný klíč hodiny pro tabulku
pěti nejdražších hodin).
