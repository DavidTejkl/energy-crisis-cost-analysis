# Data model

## 1. fact_energy_prices

Source files: `data/bronze/ote/`

### Grain 

One row = one price/volume record for one delivery hour of one day. Every row is unique —
the same `date_key` + `hour_of_day` combination never repeats. The same `date_key` repeats on
23–25 rows (one per hour), so `dim_date` → `fact_energy_prices` is a one-to-many (1:N) relationship.

### Primary key

`date_key`, `hour_of_day` (composite key)

### Foreign keys

- `date_key` → `dim_date.date_key`
- `hour_of_day` → `dim_hour.hour_of_day`

### Columns

| Column          | Format             | Description                                                                          |
| --------------- | ------------------ | ------------------------------------------------------------------------------------ |
| `date_key`      | integer (YYYYMMDD) | delivery day — links to `dim_date` (the date itself lives only in `dim_date`)          |
| `hour_of_day`   | integer            | sequential hour of the delivery day (1–23/24/25, see DST note) — links to `dim_hour` |
| `price_eur_mwh` | DECIMAL(7,2)       | price in EUR/MWh for the given hour and day; negative prices are valid (no CHECK > 0) |
| `volume_mwh`    | DECIMAL(9,3)       | traded volume in MWh for the given hour and day                                      |

Type notes:
- `price_eur_mwh`: OTE publishes 2 decimals; 2020–2024 range is −138.75 to 871.00, `(7,2)` leaves
  headroom up to ±99,999.99 so a later price spike cannot overflow the load.
- `volume_mwh`: not an integer — most hours have 1 decimal, but 32 hours in 2024 have 3 decimals
  in the OTE source file itself (e.g. 2086.199). Stored at full source precision, rounding only
  happens on display.
- `price_czk_mwh` is NOT stored. It is derived (`price_eur_mwh × rate_czk_per_eur`) and computed
  in SQL by joining `fact_fx` on `date_key`, so the exchange rate lives in one place only.

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
| `week_of_year` | integer (1–53)        | ISO week number (Monday start); some years have week 53, e.g. 1–3 Jan 2021 is week 53 of 2020 |
| `weekday_num`  | integer (1–7)         | day of week as a number (for sorting/filtering in SQL)         |
| `weekday_name` | text                  | day of week as text in Czech — Pondělí ... Neděle (for readability) |
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
| `time_of_day` | text                | time-of-day label in Czech, by `hour_of_day`: `ráno` 7–10 · `dopoledne` 11–12 · `odpoledne` 13–18 · `večer` 19–21 · `noc` all other hours (1–6, 22–25) |

Note: an `is_peak` column (peak vs. off-peak for the energy market, typically business days
8–20 h) is deferred to step 2.6 (`09_query_peak_offpeak.sql`) — the peak definition combines
hour and weekday, so it belongs in the query (JOIN `dim_hour` + `dim_date`) rather than as a
static column here.

## 4. fact_fx

Source files: `data/bronze/cnb/cnb_fx_*.txt`. ČNB publishes a rate only on working days —
after the transform step (0.5, ADR-001) this table has one row for EVERY calendar day
in the project period (including weekends/holidays), so every hour in `fact_energy_prices`
finds its rate by joining on `date_key` (one rate per day ↔ 23–25 hours per day).

### Grain

One row = which EUR/CZK rate applies on a given day (either the actual published rate, or
one carried forward under the weekend/holiday fill rule — see `is_actual_rate`).

### Primary key

`date_key` (`YYYYMMDD`), same convention as `dim_date`. It is also the foreign key to
`dim_date.date_key` (one row per day on both sides).

### Columns

| Column             | Format             | Description                                                                     |
| ------------------ | ------------------ | ------------------------------------------------------------------------------- |
| `date_key`         | integer (YYYYMMDD) | primary key and foreign key to `dim_date`                                       |
| `rate_czk_per_eur` | decimal            | exchange rate — CZK per 1 EUR                                                   |
| `is_actual_rate`   | 0/1                | 1 = ČNB actually published a rate for this day, 0 = carried forward (fill rule) |
| `source_date`      | Date               | where the displayed value actually comes from — if `is_actual_rate = 1`, equals the date of this row; if `is_actual_rate = 0`, the date of the last previously published rate. Never NULL (decision 2026-09-23: always populated, to avoid NULL handling in queries). Plain date, not a key: for 1 Jan 2020 it is 2019-12-31, which is outside `dim_date`. |

## 5. repo_rate (validity-period table)

Source file: `data/bronze/cnb/vyvoj_repo_historie.txt`. Unlike `fact_fx`, this is NOT
expanded to one row per day — it stays compact (22 periods: the rate carried in from
2019-05-03 plus 21 changes in 2020–2024). Joining to another table by date is done via a
range condition (`WHERE d.full_date BETWEEN r.valid_from AND r.valid_to`, `d` = `dim_date`),
not equality. The same pattern will be used for ERÚ tariffs in `config/`.

### Grain

One row = one validity period of one repo rate value (not one day).

### Primary key

`valid_from` (Date) — the date from which the rate is in effect.

Both boundaries are stored as Date (not as a `YYYYMMDD` key): the range comparison needs the
same type on both ends, and `valid_from` cannot be a foreign key to `dim_date` anyway — the
first period starts on 2019-05-03, before `dim_date` begins.

### Columns

| Column          | Format  | Description                                                                         |
| --------------- | ------- | ----------------------------------------------------------------------------------- |
| `valid_from`    | Date    | primary key — start of validity (source column `PLATNA_OD`, `YYYYMMDD` text in the source) |
| `valid_to`      | Date    | end of validity — one day before the next row's `valid_from` (computed in `python/02_transform.py`); for the last row, set to the last `dim_date` day (2024-12-31), to avoid NULL |
| `repo_rate_pct` | decimal | repo rate in % (source column `CNB_REPO_SAZBA_V_%`)                                 |
