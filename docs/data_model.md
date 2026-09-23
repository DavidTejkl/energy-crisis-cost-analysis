# Data model

## 1. fact_energy_prices

Source files: `data/bronze/ote/`

### Grain

One row = one price/volume record for one delivery hour of one day. Every row is unique —
the same `full_date` + `hour_of_day` combination never repeats.

### Primary key

`full_date`, `hour_of_day`

### Columns

| Column          | Format       | Description                                                              |
| --------------- | ------------ | -------------------------------------------------------------------------- |
| `full_date`     | Date         | delivery day — links to `dim_date`                                        |
| `hour_of_day`   | integer      | sequential hour of the delivery day (1–23/24/25, see DST note) — links to `dim_hour` |
| `price_eur_mwh` | EUR          | price for the given hour and day                                          |
| `volume_mwh`    | integer      | traded volume for the given hour and day                                  |

## 2. dim_date

### Grain

One row = one calendar day. Covers the whole project period 2020–2024 (1,827 days).

### Primary key

`date_key` — a smart key in `YYYYMMDD` format (e.g. 31 Jan 2022 → `20220131`). Unlike a plain
sequential number (1, 2, 3...), the value itself tells you which date it represents, while
staying a fast, comparable integer for joins.

### Columns

| Column         | Format               | Description                                                  |
| -------------- | --------------------- | --------------------------------------------------------------|
| `date_key`     | integer (YYYYMMDD)    | primary key                                                   |
| `full_date`    | Date                  | the actual calendar date                                      |
| `day_of_month` | integer (1–31)        | day of month                                                   |
| `month`        | integer (1–12)        | month                                                          |
| `year`         | integer               | year                                                            |
| `quarter`      | integer (1–4)         | quarter                                                         |
| `week_of_year` | integer (1–52)        | week number within the year                                    |
| `weekday_num`  | integer (1–7)         | day of week as a number (for sorting/filtering in SQL)         |
| `weekday_name` | text                  | day of week as text — Monday ... Sunday (for readability)      |
| `is_weekend`   | 0/1                   | 1 = weekend, 0 = not weekend                                    |

## 3. dim_hour

### Grain

One row = one specific hour (sequential hour of the day, 1–25 because of DST — see brief).
25 rows total; does not repeat per day (unlike `dim_date`, which has one row per day).

### Primary key

`hour_of_day` — natural key. No artificial `hour_id` is needed, since `hour_of_day` is
already a small, unique integer on its own.

### Columns

| Column        | Format             | Description                                                           |
| ------------- | ------------------- | -------------------------------------------------------------------------|
| `hour_of_day` | integer (1–25)      | primary key — sequential hour of the day                                |
| `time_of_day` | text                | morning (6–10) / late morning (10–12) / afternoon (12–18) / evening (18–22) / night (22–6) |

Note: an `is_peak` column (peak vs. off-peak for the energy market, typically business days
8–20 h) is deferred to step 2.6 (`09_query_peak_offpeak.sql`) — the peak definition combines
hour and weekday, so it belongs in the query (JOIN `dim_hour` + `dim_date`) rather than as a
static column here.

## 4. fact_fx

Source files: `data/bronze/cnb/cnb_fx_*.txt`. ČNB publishes a rate only on working days —
after the transform step (0.5, ADR-001) this table will have one row for EVERY calendar day
in the project period (including weekends/holidays), so it can be joined 1:1 with
`fact_energy_prices`.

### Grain

One row = which EUR/CZK rate applies on a given day (either the actual published rate, or
one carried forward under the weekend/holiday fill rule — see `is_actual_rate`).

### Primary key

`date_key` (`YYYYMMDD`), same convention as `dim_date`.

### Columns

| Column             | Format                 | Description                                                                |
| ------------------- | -----------------------| ------------------------------------------------------------------------------|
| `date_key`          | integer (YYYYMMDD)     | primary key                                                                    |
| `full_date`         | Date                   | the actual calendar date                                                       |
| `rate_czk_per_eur`  | decimal                | exchange rate — CZK per 1 EUR                                                  |
| `is_actual_rate`    | 0/1                    | 1 = ČNB actually published a rate for this day, 0 = carried forward (fill rule) |
| `source_date`       | Date                   | where the displayed value actually comes from — if `is_actual_rate = 1`, equals `full_date`; if `is_actual_rate = 0`, the date of the last previously published rate. Never NULL (decision 2026-09-23: always populated, to avoid NULL handling in queries). |

## 5. repo_rate (validity-period table)

Source file: `data/bronze/cnb/vyvoj_repo_historie.txt`. Unlike `fact_fx`, this is NOT
expanded to one row per day — it stays compact (21 change rows for 2020–2024). Joining to
another table by date is done via a range condition
(`WHERE full_date BETWEEN valid_from AND valid_to`), not equality. The same pattern will be
used for ERÚ tariffs in `config/`.

### Grain

One row = one validity period of one repo rate value (not one day).

### Primary key

`valid_from` (`date_key` format) — the date from which the rate is in effect.

### Columns

| Column          | Format                | Description                                                                       |
| ---------------- | ----------------------| --------------------------------------------------------------------------------------|
| `valid_from`     | integer (YYYYMMDD)    | primary key — start of validity (source column `PLATNA_OD`)                           |
| `valid_to`       | Date                  | end of validity — one day before the next row's `valid_from` (computed with `LEAD()`); for the last row, set to the last `dim_date` day (2024-12-31), to avoid NULL |
| `repo_rate_pct`  | decimal               | repo rate in % (source column `CNB_REPO_SAZBA_V_%`)                                   |
