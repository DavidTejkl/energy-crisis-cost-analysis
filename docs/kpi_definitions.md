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

## Average market price
- Business question it answers: how expensive was electricity on the market in a year or month?
- Business definition: plain average of the hourly day-ahead prices; every hour has the same weight.
  This is the market's price level, not what the company paid (that is the load-weighted price, page 2).
- Formula (SQL / DAX reference): `AVG(price_eur_mwh)` over the hours of the period (`fact_energy_prices`).
  In Power BI from `vw_daily_summary` as `SUM(market_price_sum_eur) / SUM(hours_in_day)`, which gives the same
  result for any period (sum / sum, never an average of daily averages).
- Unit & time grain: EUR/MWh; card = selected year, trend line = month.
- Filters / exclusions: none; negative and zero hours are included (valid market prices).
- How to read it: 2022 (247.43) is 2.5 × 2021 (100.66) and 7.4 × 2020 (33.62).
- Known limitations: market price only, without regulated components and without the company's load shape.

## Extreme hours
- Business question it answers: how often did the market reach crisis prices?
- Business definition: number of hours in the "extreme" price band (≥ 5,821 CZK/MWh, see Price band).
  The comparison line shows the share of all hours of the year.
- Formula (SQL / DAX reference): `COUNT` of hours with `price_czk_mwh >= 5821` (`sql/05_query_price_bands.sql`);
  share = extreme hours / all hours of the year.
- Unit & time grain: hours per year.
- Filters / exclusions: none.
- How to read it: 2020 0 · 2021 577 · 2022 3,694 · 2023 30 · 2024 84 hours. Many extreme hours = buying only
  on the spot market is risky.
- Known limitations: threshold in CZK, so the EUR/CZK rate moves an hour across the threshold too.

## Highest hourly price
- Business question it answers: how high did the market jump in the worst single hour?
- Business definition: the highest hourly day-ahead price of the period, with its date and hour.
- Formula (SQL / DAX reference): `MAX(price_czk_mwh)` from `vw_energy_prices_czk`; date and hour from
  `RANK() ... = 1` in `sql/07_query_top_hours.sql`.
- Unit & time grain: CZK/MWh, one delivery hour.
- Filters / exclusions: none.
- How to read it: 2022-08-29 hour 20 = 21,422.25 CZK/MWh; 2024-12-12 hour 18 = 21,170.65 (Dunkelflaute,
  see `data_quality_report.md`). `hour_of_day` 20 = delivery 19:00–20:00.
- Known limitations: one hour says little about cost; it shows the size of the risk, not its frequency.

## Peak/off-peak spread
- Business question it answers: how much cheaper is electricity at night and at weekends than in working hours?
- Business definition: average price of peak hours minus average price of off-peak hours.
  Peak = Monday–Friday, delivery 08:00–20:00 (`hour_of_day` 9–20, `is_weekend = 0`), the market peak-load
  definition (PXE / EEX). Off-peak = all other hours. Weekday public holidays count as peak (ASSUMPTION).
- Formula (SQL / DAX reference): `AVG(CASE WHEN peak THEN price END) − AVG(CASE WHEN off-peak THEN price END)`
  (`sql/09_query_peak_offpeak.sql`).
- Unit & time grain: EUR/MWh per year.
- Filters / exclusions: none.
- How to read it: 2020 12.53 · 2021 33.71 · 2022 60.04 · 2023 21.82 · 2024 14.89 EUR/MWh. The upper limit of what
  one MWh moved from peak to off-peak could save; the company's real extra cost is the load profile premium (page 2).
- Known limitations: plain averages over hours; no holiday calendar (backlog).

## <KPI name>
- Business question it answers:
- Business definition:
- Formula (SQL / DAX reference):
- Unit & time grain:
- Filters / exclusions:
- How to read it (what good/bad looks like):
- Known limitations:
