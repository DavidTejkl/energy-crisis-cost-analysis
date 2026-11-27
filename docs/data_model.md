# Data model

**English** · [Čeština](data_model_cz.md)

The database `EnergyCrisisCostAnalysis` is a star schema with two fact tables that share the same dimensions
(sections 1–7), two pipeline tables (section 8) and views that Power BI reads (section 9). Tables are created by
[sql/02_create_tables.sql](../sql/02_create_tables.sql), views by [sql/03_create_views.sql](../sql/03_create_views.sql).
The grain of every table was written down here before the table was loaded.

## 1. fact_energy_prices

Source files: `data/bronze/ote/`

### Grain

One row = one price and volume record for one delivery hour of one day. The same `date_key` + `hour_of_day`
combination never repeats. The same `date_key` repeats on 23 to 25 rows (one per hour), so `dim_date` to
`fact_energy_prices` is a one-to-many (1:N) relationship.

### Primary key

`date_key`, `hour_of_day` (composite key)

### Foreign keys

- `date_key` references `dim_date.date_key`
- `hour_of_day` references `dim_hour.hour_of_day`

### Columns

| Column          | Format             | Description                                                                            |
| --------------- | ------------------ | -------------------------------------------------------------------------------------- |
| `date_key`      | integer (YYYYMMDD) | delivery day, links to `dim_date` (the date itself lives only in `dim_date`)           |
| `hour_of_day`   | integer            | sequential hour of the delivery day (1–23, 1–24 or 1–25, see the DST note), links to `dim_hour` |
| `price_eur_mwh` | DECIMAL(7,2)       | price in EUR/MWh for the given hour and day, negative prices are valid (no CHECK > 0)  |
| `volume_mwh`    | DECIMAL(9,3)       | traded volume in MWh for the given hour and day                                        |

Type notes:
- `price_eur_mwh`: OTE publishes 2 decimals. The 2020–2024 range is −138.75 to 871.00, and `(7,2)` leaves
  headroom up to ±99,999.99, so a later price spike cannot break the load.
- `volume_mwh`: not an integer. Most hours have 1 decimal, but 32 hours in 2024 have 3 decimals in the OTE source
  file itself (e.g. 2086.199). Stored at full source precision, rounded only on display.
- `price_czk_mwh` is NOT stored. It is derived (`price_eur_mwh × rate_czk_per_eur`) and computed in the views by
  joining `fact_fx` on `date_key`, so the exchange rate lives in one place only.

## 2. dim_date

### Grain

One row = one calendar day. Covers the whole project period 2020–2024 (1,827 days).

### Primary key

`date_key`, a smart key in `YYYYMMDD` format (e.g. 31 Jan 2022 is `20220131`). Unlike a plain sequential number
(1, 2, 3...), the value itself tells you which date it is, and it stays a fast, comparable integer for joins.

### Columns

| Column         | Format             | Description                                                                                  |
| -------------- | ------------------ | -------------------------------------------------------------------------------------------- |
| `date_key`     | integer (YYYYMMDD) | primary key                                                                                  |
| `full_date`    | Date               | the actual calendar date                                                                     |
| `day_of_month` | integer (1–31)     | day of month                                                                                 |
| `month`        | integer (1–12)     | month                                                                                        |
| `year`         | integer            | year                                                                                         |
| `quarter`      | integer (1–4)      | quarter                                                                                      |
| `week_of_year` | integer (1–53)     | ISO week number (weeks start on Monday). Some years have week 53, e.g. 1–3 Jan 2021 is week 53 of 2020 |
| `weekday_num`  | integer (1–7)      | day of week as a number, 1 = Monday (for sorting and filtering)                              |
| `weekday_name` | text               | day of week in Czech, Pondělí to Neděle (for readability)                                    |
| `is_weekend`   | 0/1                | 1 = weekend, 0 = working day                                                                 |

## 3. dim_hour

### Grain

One row = one sequential hour of the day, 1 to 25 because of the clock change (see the brief). 25 rows in total.
It does not repeat per day (unlike `dim_date`, which has one row per day).

### Primary key

`hour_of_day`, a natural key. No artificial `hour_id` is needed, because `hour_of_day` is already a small, unique
integer.

### Columns

| Column        | Format         | Description                                                                                       |
| ------------- | -------------- | ------------------------------------------------------------------------------------------------- |
| `hour_of_day` | integer (1–25) | primary key, sequential hour of the day                                                           |
| `time_of_day` | text           | time-of-day label in Czech by `hour_of_day`: `ráno` 7–10 · `dopoledne` 11–12 · `odpoledne` 13–18 · `večer` 19–21 · `noc` all other hours (1–6, 22–25) |

Peak and off-peak are not a column here. The market definition (Monday to Friday, 08:00 to 20:00) combines the hour
and the weekday, so it is computed in [sql/09_query_peak_offpeak.sql](../sql/09_query_peak_offpeak.sql) by joining
`dim_hour` and `dim_date`.

## 4. fact_fx

Source files: `data/bronze/cnb/cnb_fx_*.txt`. ČNB publishes a rate only on working days. After cleaning in
`python/02_transform.py` ([ADR-001](decisions/ADR-001-eur-czk-fill-rule.md)) this table has one row for EVERY calendar
day of the project period, weekends and holidays included, so every hour in `fact_energy_prices` finds its rate by
joining on `date_key` (one rate per day, 23 to 25 hours per day).

### Grain

One row = the EUR/CZK rate that applies on a given day: either the rate ČNB published that day, or one carried
forward under the weekend and holiday fill rule (see `is_actual_rate`).

### Primary key

`date_key` (`YYYYMMDD`), same convention as `dim_date`. It is also the foreign key to `dim_date.date_key` (one row
per day on both sides).

### Columns

| Column             | Format             | Description                                                                     |
| ------------------ | ------------------ | ------------------------------------------------------------------------------- |
| `date_key`         | integer (YYYYMMDD) | primary key and foreign key to `dim_date`                                       |
| `rate_czk_per_eur` | DECIMAL(5,3)       | exchange rate, CZK per 1 EUR, must be > 0 (CHECK)                               |
| `is_actual_rate`   | 0/1                | 1 = ČNB published a rate for this day, 0 = carried forward (fill rule)          |
| `source_date`      | Date               | the day the rate really comes from. If `is_actual_rate = 1` it equals the date of the row, if `is_actual_rate = 0` it is the date of the last published rate. Never NULL, so queries do not have to handle NULL. A plain date, not a key: for 1 Jan 2020 it is 2019-12-31, which is outside `dim_date`. |

Type note: ČNB publishes the rate with up to 3 decimals. The 2020–2024 range is 23.275 to 27.81, and `(5,3)` holds
up to 99.999. A rate can never be zero or negative, so a CHECK > 0 is safe here (unlike electricity prices).

## 5. repo_rate (validity-period table)

Source file: `data/bronze/cnb/vyvoj_repo_historie.txt`. Unlike `fact_fx`, this table is NOT expanded to one row per
day. It stays compact: 22 periods, the rate carried in from 2019-05-03 plus 21 changes in 2020–2024. It is joined
to days by a range condition (`WHERE d.full_date BETWEEN r.valid_from AND r.valid_to`, `d` = `dim_date`), not by
equality. The regulated prices (section 7) use the same pattern. The repo rate is loaded and tested, but no
analysis query uses it yet (context only, see Limits in the README).

### Grain

One row = one validity period of one repo rate value (not one day).

### Primary key

`valid_from` (Date), the date from which the rate is in effect.

Both boundaries are stored as Date, not as a `YYYYMMDD` key. The range comparison needs the same type on both ends,
and `valid_from` cannot be a foreign key to `dim_date` anyway, because the first period starts on 2019-05-03, before
`dim_date` begins.

### Columns

| Column          | Format       | Description                                                                         |
| --------------- | ------------ | ----------------------------------------------------------------------------------- |
| `valid_from`    | Date         | primary key, start of validity (source column `PLATNA_OD`, `YYYYMMDD` text in the source) |
| `valid_to`      | Date         | end of validity, one day before the next row's `valid_from` (computed in `python/02_transform.py`). For the last row it is the last day of `dim_date` (2024-12-31), to avoid NULL |
| `repo_rate_pct` | DECIMAL(4,2) | repo rate in % (source column `CNB_REPO_SAZBA_V_%`)                                 |

Type note: the ČNB repo rate has at most 2 decimals. The 2020–2024 range is 0.25 to 7.00, and `(4,2)` holds −99.99
to 99.99. There is no CHECK on the sign: central banks can set negative rates (e.g. the ECB deposit rate was −0.50 %
in 2019–2022), so a negative value is a valid outcome, not an error. A CHECK `valid_from <= valid_to` rejects a
period that ends before it starts (a one-day period is allowed).

## 6. fact_load (SIMULATED)

Source file: `data/silver/fact_load.csv`, generated by `python/04_generate_load_profile.py` (method in
[methodology.md](methodology.md)). The model company is fictional, so every row is simulated.

### Grain

One row = electricity used by the model company in one delivery hour of one day. Same grain as `fact_energy_prices`
(43,848 rows), but a separate fact table: prices are real market data from OTE, the load is a simulation of a
fictional company, a different business process and a different kind of data. Both fact tables share the same
dimensions (`dim_date`, `dim_hour`) and are combined through them, never by a foreign key from one fact table to the
other.

### Primary key

`date_key`, `hour_of_day` (composite key)

### Foreign keys

- `date_key` references `dim_date.date_key`
- `hour_of_day` references `dim_hour.hour_of_day`

### Columns

| Column         | Format             | Description                                                            |
| -------------- | ------------------ | ---------------------------------------------------------------------- |
| `date_key`     | integer (YYYYMMDD) | delivery day, links to `dim_date`                                      |
| `hour_of_day`  | integer            | sequential hour of the delivery day (1–25), links to `dim_hour`        |
| `load_mwh`     | DECIMAL(5,3)       | consumption in MWh in that hour (2020–2024 range 1.428 to 4.665), CHECK ≥ 0 |
| `is_simulated` | bit                | 1 = simulated value, always 1 in this table (CHECK = 1)                |

## 7. regulated_price (validity-period table)

Source file: `config/tariffs.csv`, typed by hand from the ERÚ price decisions and the electricity tax act. Every row
names its source in the `source` column. Same pattern as `repo_rate`: compact validity periods, joined to days by a
range condition (`d.full_date BETWEEN t.valid_from AND t.valid_to`).

### Grain

One row = one regulated price component in one validity period. Most periods are one calendar year. A component gets
an extra row when its price changes during the year (e.g. POZE set to 0 from 2022-10-01 by ERÚ decision 8/2022).
41 rows: 8 components × 5 years + 1 extra POZE period in 2022.

### Primary key

`valid_from`, `component` (composite key). `valid_from` alone is not unique, because eight components start on
2024-01-01. `valid_to` is not part of the key: the component and the start already identify the period.

### Columns

| Column       | Format        | Description                                                              |
| ------------ | ------------- | ------------------------------------------------------------------------ |
| `component`  | text          | short code, e.g. `network_use`, `poze_per_mw`, `electricity_tax`         |
| `value`      | DECIMAL(9,2)  | price in the unit of the row, CHECK ≥ 0                                  |
| `unit`       | text          | `CZK/MWh`, `CZK/MW/month` or `CZK/supply_point/month` (CHECK)            |
| `valid_from` | Date          | first day of validity                                                    |
| `valid_to`   | Date          | last day of validity (inclusive)                                         |
| `source`     | text          | price decision and point, e.g. `ERU 5/2023 point 4.40`                   |

Data check (2026-10-17): every component covers every day of 2020–2024 exactly once (0 days without a price,
0 days with two prices). The same rule is checked on every run by test G01 in `sql/91_dq_tests.sql`.

## 8. Pipeline tables ([sql/90_etl_infrastructure.sql](../sql/90_etl_infrastructure.sql))

Not part of the star schema: they describe the pipeline, not the business. They are created only if missing (no
DROP), so a rebuild of the model keeps their history. No foreign keys to the model: a failed run must be logged even
when the model tables are empty. The last loaded day of a fact table is read as `MAX(date_key)` from the table
itself, so no separate watermark table is kept.

### etl_run_log

Grain: one row = one load of one table in one run. Primary key `run_id` (IDENTITY): a run has no natural key, and
two runs can start in the same second.

| Column          | Format    | Description                                                       |
| --------------- | --------- | ----------------------------------------------------------------- |
| `run_id`        | int       | sequence number assigned by SQL Server                            |
| `script_name`   | text      | e.g. `03_load.py`                                                 |
| `table_name`    | text      | loaded table, NULL for a step without a table                     |
| `started_at`    | datetime  | start of the step                                                 |
| `finished_at`   | datetime  | end of the step, NULL while running or after a crash              |
| `rows_inserted` | int       | rows inserted, ≥ 0                                                |
| `rows_updated`  | int       | rows updated, ≥ 0                                                 |
| `status`        | text      | `RUNNING`, `OK` or `FAIL`                                         |
| `error_message` | text      | error text when `FAIL`                                            |

### dq_results

Grain: one row = one data quality test in one run. Primary key `dq_result_id` (IDENTITY).

| Column         | Format   | Description                                                         |
| -------------- | -------- | ------------------------------------------------------------------- |
| `dq_result_id` | int      | sequence number assigned by SQL Server                              |
| `run_at`       | datetime | time of the DQ run                                                  |
| `test_id`      | text     | test number as in `sql/91_dq_tests.sql`, e.g. `P05`                 |
| `test_name`    | text     | short description                                                   |
| `failed_rows`  | int      | rows breaking the rule, ≥ 0                                         |
| `status`       | text     | `PASS`, `WARN` (valid value flagged on purpose) or `FAIL`           |

## 9. Views (gold layer, [sql/03_create_views.sql](../sql/03_create_views.sql))

The views are the gold layer: Power BI imports four of them together with `dim_date` and `dim_hour`. In Power BI
`dim_date` is linked to all four views by `date_key` and `dim_hour` to the hourly view by `hour_of_day`, always
one-to-many and in one direction (5 relationships, a galaxy schema). The monthly and yearly views carry the
`date_key` of the first day of their period, so the year selector filters them through `dim_date` like the hourly view.

| View                   | Grain                                  | Rows   | Used by                         |
| ---------------------- | -------------------------------------- | -----: | ------------------------------- |
| `vw_hourly_cost`       | one hour of one day                    | 43,848 | Power BI                        |
| `vw_monthly_cost`      | one month                              |     60 | Power BI                        |
| `vw_yearly_hedging`    | one delivery year (2021–2024)          |      4 | Power BI                        |
| `vw_cost_change_steps` | one year and one step of the cost change |   20 | Power BI (waterfall)            |
| `vw_energy_prices_czk` | one hour of one day                    | 43,848 | analysis queries in `sql/`      |
| `vw_daily_summary`     | one day                                |  1,827 | not imported (the hourly view covers it) |

Costs and MWh in the views can be summed over any period. Prices and rates are valid only for their own hour or
year and are never summed: in Power BI they are set to "do not summarize", and every price in the report is a ratio
of sums (`DIVIDE(SUM(cost), SUM(load))`), never an average of averages.

### Columns of the four Power BI views

The formats are the types SQL Server reports for the view columns (`sys.columns`). A sum over many rows gets
precision 38 automatically.

#### vw_hourly_cost

| Column             | Format             | Description                                                                                       |
| ------------------ | ------------------ | ------------------------------------------------------------------------------------------------- |
| `date_key`         | integer (YYYYMMDD) | delivery day, links to `dim_date`                                                                  |
| `hour_of_day`      | integer            | sequential hour of the delivery day (1–25), links to `dim_hour`                                    |
| `price_eur_mwh`    | DECIMAL(7,2)       | OTE day-ahead price in EUR/MWh (from `fact_energy_prices`)                                         |
| `rate_czk_per_eur` | DECIMAL(5,3)       | ČNB EUR/CZK rate of the day (from `fact_fx`, weekends and holidays filled by ADR-001)              |
| `price_czk_mwh`    | DECIMAL(13,5)      | price in CZK/MWh = `price_eur_mwh × rate_czk_per_eur`, not rounded                                 |
| `load_mwh`         | DECIMAL(5,3)       | company load in that hour, `SIMULATED` (from `fact_load`)                                          |
| `power_cost_eur`   | DECIMAL(13,5)      | power cost of the hour in EUR = `load_mwh × price_eur_mwh`                                         |
| `power_cost_czk`   | DECIMAL(19,8)      | power cost of the hour in CZK = `load_mwh × price_eur_mwh × rate_czk_per_eur`                      |
| `price_band`       | NVARCHAR(8)        | [price band](kpi_definitions.md#price-band) of the hour in Czech: `záporná` (below 0), `nízká` (below 1,217), `běžná` (below 3,374), `vysoká` (below 5,821), `extrémní` (5,821 CZK/MWh and more) |
| `price_band_order` | integer            | 1–5, sort order of `price_band` in Power BI (hidden there)                                         |

#### vw_monthly_cost

All amounts are in CZK for the whole month, without VAT and supplier margin ([ADR-005](decisions/ADR-005-all-in-price-scope.md)).

| Column                  | Format             | Description                                                                              |
| ----------------------- | ------------------ | ---------------------------------------------------------------------------------------- |
| `date_key`              | integer (YYYYMMDD) | first day of the month (`year × 10000 + month × 100 + 1`), links to `dim_date`           |
| `year`                  | integer            | year                                                                                     |
| `month`                 | integer            | month 1–12                                                                               |
| `load_mwh`              | DECIMAL(38,3)      | company load of the month, `SIMULATED`                                                    |
| `power_cost_czk`        | DECIMAL(38,8)      | power cost = sum of the hourly load × price in CZK                                        |
| `electricity_tax_czk`   | DECIMAL(38,5)      | electricity tax = load × rate in CZK/MWh                                                  |
| `network_use_czk`       | DECIMAL(38,5)      | distribution, network use = load × rate in CZK/MWh                                        |
| `system_services_czk`   | DECIMAL(38,5)      | system services = load × rate in CZK/MWh                                                  |
| `reserved_capacity_czk` | DECIMAL(38,2)      | distribution, reserved capacity = monthly price per MW × 5 MW (`ASSUMPTION`)              |
| `ote_fees_czk`          | DECIMAL(38,2)      | the two monthly OTE fees per supply point                                                 |
| `poze_czk`              | DECIMAL(38,2)      | POZE (support of renewables) = the lower of price per MW × 5 MW and cap per MWh × load    |
| `total_cost_czk`        | DECIMAL(38,2)      | sum of all components above = the monthly bill                                            |

#### vw_yearly_hedging

One row per delivery year 2021–2024, amounts in EUR ([ADR-003](decisions/ADR-003-forward-price-proxy.md)).

| Column                 | Format             | Description                                                                                      |
| ---------------------- | ------------------ | ------------------------------------------------------------------------------------------------ |
| `date_key`             | integer (YYYYMMDD) | 1 January of the year (`year × 10000 + 101`), links to `dim_date`                                 |
| `year`                 | integer            | delivery year                                                                                    |
| `volume_mwh`           | DECIMAL(38,3)      | yearly load, `SIMULATED`                                                                          |
| `spot_cost_eur`        | DECIMAL(38,5)      | power cost with everything bought at spot = sum of the hourly load × price                        |
| `market_price_eur_mwh` | DECIMAL(38,6)      | simple average of the hourly prices of the year (for display, never summed)                       |
| `hedge_price_eur_mwh`  | DECIMAL(38,6)      | fixed price = simple average of the previous year (`ASSUMPTION`)                                  |
| `pxe_price_eur_mwh`    | NUMERIC(5,2)       | PXE CZ base load year product, last trade of the previous year (`FACT`, PXE annual reports), NULL for 2021 |
| `hedge_diff_proxy_eur` | DECIMAL(38,6)      | `volume_mwh × (hedge_price_eur_mwh − market_price_eur_mwh)`: how much more (+) or less (−) the whole yearly volume costs at the fixed price. Hedged cost at share *s* = `spot_cost_eur + s × hedge_diff_proxy_eur` |
| `hedge_diff_pxe_eur`   | NUMERIC(38,6)      | the same with the PXE price, NULL for 2021                                                        |

#### vw_cost_change_steps

One row per year 2021–2024 and step, amounts in CZK ([ADR-004](decisions/ADR-004-cost-variance-split.md),
[ADR-006](decisions/ADR-006-fx-effect-split.md)).

| Column       | Format             | Description                                                                                           |
| ------------ | ------------------ | ----------------------------------------------------------------------------------------------------- |
| `date_key`   | integer (YYYYMMDD) | 1 January of the year, links to `dim_date`                                                             |
| `year`       | integer            | year whose cost change is split                                                                        |
| `step_order` | integer            | 1–5, sort order of the steps (hidden in Power BI)                                                      |
| `step_name`  | NVARCHAR(17)       | step in Czech: `Náklad minulý rok`, `Spotřeba`, `Cena na trhu`, `Diagram odběru`, `Kurz EUR/CZK`       |
| `amount_czk` | DECIMAL(38,6)      | step 1 = power cost of the previous year, steps 2–5 = effect of volume, market price, load profile and exchange rate. Previous year + the 4 steps = this year's power cost within 2 CZK (rounding of the rate) |

Power BI adds two DAX calculated columns that are not in SQL: `dim_date[month_start]` (first day of the month, the
axis of the monthly charts) and `vw_hourly_cost[hour_key]` (`date_key × 100 + hour_of_day`, a unique key of an hour
for the top 5 table).
