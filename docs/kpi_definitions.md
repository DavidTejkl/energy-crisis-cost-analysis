# KPI definitions

## Price band
- Business question it answers: how many hours per year were negative, cheap, normal, expensive or extreme,
  and how did this mix change during the 2021–2023 energy crisis?
- Business definition: every hour is put into one of five bands by its day-ahead price in CZK/MWh.
  The thresholds are fixed for all years, so the years can be compared with one yardstick.

  | Band | CZK/MWh | Derived from |
  |------|---------|--------------|
  | negative | < 0 | sign of the price |
  | low | 0 – < 1,217 | P25 |
  | normal | 1,217 – < 3,374 | P25 – P75 |
  | high | 3,374 – < 5,821 | P75 – P90 |
  | extreme | ≥ 5,821 | P90 |

  Lower bound is inclusive, upper bound exclusive → every hour falls into exactly one band.
- Formula (SQL / DAX reference): `price_czk_mwh` from `dbo.vw_energy_prices_czk`
  (`sql/03_create_views.sql`), band assigned with `CASE WHEN` in `sql/05_query_price_bands.sql` (step 1.3).
- Unit & time grain: CZK/MWh, one row per delivery hour (`date_key`, `hour_of_day`).
- Filters / exclusions: none; all 43,848 hours 2020–2024.
- How to read it: a rising share of high and extreme hours means higher and less predictable purchase cost;
  a rising number of negative hours shows periods of surplus (e.g. midday solar) that flexible load could use.
- Known limitations:
  - Thresholds are percentiles of the whole period 2020–2024 (computed 2026-09-29), rounded to whole CZK.
    Adding more years would move them → recompute and update this table on purpose, never silently.
  - The low band holds fewer than 25 % of hours, because the 609 negative hours are counted separately.
    Zero-price hours (88) belong to the low band.
  - This is the market price only, not the all-in price a company pays (distribution, fees, tax are added later).

  Percentiles used (CZK/MWh, 43,848 hours): min −3,459.73 · P10 664.22 · P25 1,217.42 · P50 2,152.42 ·
  P75 3,374.10 · P90 5,820.77 · max 21,422.25. Cross-check: 4,385 hours below P10, 21,924 below P50,
  4,385 above P90.

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

## <KPI name>
- Business question it answers:
- Business definition:
- Formula (SQL / DAX reference):
- Unit & time grain:
- Filters / exclusions:
- How to read it (what good/bad looks like):
- Known limitations:
