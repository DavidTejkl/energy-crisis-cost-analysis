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
- Formula (SQL / DAX reference): `AVG(price_czk_mwh)` over the hours of the period (`vw_energy_prices_czk`).
  In Power BI as a sum of hourly prices / number of hours, which gives the same result for any period
  (sum / sum, never an average of daily averages). EUR version: `AVG(price_eur_mwh)` (tooltip).
- Unit & time grain: CZK/MWh; card = selected year, trend line = month.
- Filters / exclusions: none; negative and zero hours are included (valid market prices).
- How to read it: CZK/MWh 2020 886.55 · 2021 2,570.35 · 2022 6,082.84 · 2023 2,416.13 · 2024 2,138.04
  (run 2026-11-03); EUR/MWh 33.62 · 100.66 · 247.43 · 100.79 · 85.11. 2022 is 2.4 × 2021 and 6.9 × 2020 in CZK.
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
- Unit & time grain: CZK/MWh per year (EUR/MWh in the tooltip).
- Filters / exclusions: none.
- How to read it: CZK/MWh 2020 330.09 · 2021 858.42 · 2022 1,471.75 · 2023 526.54 · 2024 374.52
  (EUR/MWh 12.53 · 33.71 · 60.04 · 21.82 · 14.89). The upper limit of what one MWh moved from peak to off-peak
  could save; the company's real extra cost is the load profile premium (page 2).
- Known limitations: plain averages over hours; no holiday calendar (backlog).

## Total electricity cost
- Business question it answers: how much did the company pay for electricity in a month or year?
- Business definition: power (commodity) + regulated components per MWh (network use, system services, electricity
  tax) + fixed monthly charges (reserved capacity, OTE fees) + POZE. Without VAT and supplier margin (ADR-005).
- Formula (SQL / DAX reference): `total_cost_czk` in `sql/08_query_allin_price.sql`; power =
  `SUM(load_mwh × price_czk_mwh)` per hour, regulated components joined by validity period (`regulated_price`).
- Unit & time grain: CZK; month (query 08), year = sum of months.
- Filters / exclusions: reserved capacity 5 MW (scenario ASSUMPTION); the 2023 price cap never binds (ADR-005).
- How to read it: 2020 45.46 · 2021 95.72 · 2022 200.92 · 2023 87.93 · 2024 94.84 m CZK.
- Known limitations: SIMULATED load; no supplier margin; real invoices would differ.

## All-in price
- Business question it answers: what did one kWh really cost the company, everything included?
- Business definition: total electricity cost divided by consumed energy.
- Formula (SQL / DAX reference): `total_cost_czk / (SUM(load_mwh) × 1000)` (`allin_price_czk_kwh` in
  `sql/08_query_allin_price.sql`). In Power BI as `DIVIDE(total cost, load × 1000)` — sum / sum.
- Unit & time grain: CZK/kWh; month or year.
- Filters / exclusions: as Total electricity cost.
- How to read it: 2020 1.6208 · 2021 3.4193 · 2022 7.1878 · 2023 3.1461 · 2024 3.3807 CZK/kWh. Comparable with
  the price per kWh on an invoice (without VAT and margin).
- Known limitations: SIMULATED load; fixed charges make the price per kWh higher in months with low consumption.

## Power share
- Business question it answers: how much of the cost does the market drive, and how much regulation?
- Business definition: power (commodity) cost / total electricity cost. The rest is the regulated share.
- Formula (SQL / DAX reference): `power_cost_czk / total_cost_czk` from `sql/08_query_allin_price.sql`.
- Unit & time grain: %; year.
- Filters / exclusions: as Total electricity cost.
- How to read it: 2020 58.4 · 2021 79.5 · 2022 90.6 · 2023 81.0 · 2024 67.0 %. A high share = the budget depends
  on the market price → hedging matters.
- Known limitations: SIMULATED load.

## Load profile premium
- Business question it answers: how much extra does the company pay because it uses more power in expensive hours?
- Business definition: load-weighted power price (what the company paid per MWh) minus the plain market average of
  the same hours. Total premium = premium per MWh × consumed MWh = what the company paid above "the same volume
  bought flat at the market average". The part of the power cost the company can influence by moving load.
- Formula (SQL / DAX reference): per MWh `S = SUM(load × price) / SUM(load) − AVG(price)`; total
  `C − V × Pb = SUM(load × price) − SUM(load) × AVG(price)` (ADR-004). Page 2 uses CZK prices
  (`price_czk_mwh`), page 3 and query 10 use EUR. Cross-check query (run 2026-11-03):

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
- Unit & time grain: CZK/MWh and CZK per year.
- Filters / exclusions: none.
- How to read it: CZK/MWh 2020 59.99 · 2021 149.30 · 2022 426.45 · 2023 133.52 · 2024 127.53; total 1.68 · 4.18 ·
  11.92 · 3.73 · 3.58 m CZK (EUR in query 10: 2022 +17.29 EUR/MWh, 483,332.58 EUR). The yearly power cost of the
  same query sums to 419,457,499 CZK over 5 years (= queries 08 and 11). A base-load hedge does not remove it (2.9).
- Known limitations: SIMULATED load shape; the CZK and EUR totals differ slightly more than one yearly rate would
  explain, because every hour is converted at its own daily rate. Not additive across years (the market average
  is per period) → shown per year, see DAX measures.

## Power cost change
- Business question it answers: how much more or less did the company pay for power than in the previous year?
- Business definition: power (commodity) cost in CZK of the selected year minus the previous year. Regulated
  components are not part of it (they are on page 2).
- Formula (SQL / DAX reference): `C_czk1 − C_czk0`, `C_czk = SUM(load_mwh × price_czk_mwh)` per year
  (`sql/11_query_fx_effect.sql`).
- Unit & time grain: CZK; year over year (2021–2024).
- Filters / exclusions: none.
- How to read it: 2021 +49.58 · 2022 +105.82 · 2023 −110.70 · 2024 −7.70 m CZK.
- Known limitations: SIMULATED load.

## Market price, volume and load profile effects
These three are the split of the power cost change into its drivers, shown as one waterfall in CZK on page 3.
- Business question it answers: which part of the change came from the market price level, from the consumed
  volume, and from when the company consumed (load shape)?
- Business definition (ADR-004, then priced at the previous year's effective rate `R0`, ADR-006):
  - volume effect `(V1 − V0) × Pw0 × R0` — more or less MWh at last year's company price;
  - market price effect `V1 × (Pb1 − Pb0) × R0` — the plain market average moved;
  - load profile effect `V1 × (S1 − S0) × R0` — the premium for consuming in expensive hours changed
    (`S = Pw − Pb`, see Load profile premium).
  The three sum to the commodity effect of query 11, `(C_eur1 − C_eur0) × R0`.
- Formula (SQL / DAX reference): EUR effects in `sql/10_query_variance_split.sql`, `R0` in
  `sql/11_query_fx_effect.sql`. Cross-check query for the CZK waterfall (run 2026-11-03):

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
- Unit & time grain: CZK; year over year (2021–2024).
- Filters / exclusions: none.
- How to read it (m CZK, run 2026-11-03):

  | Year | Volume | Market price | Load profile | Rate | Check (CZK) |
  |---|---|---|---|---|---|
  | 2021 | −0.05 | +49.55 | +2.68 | −2.60 | 1.52 |
  | 2022 | −0.11 | +104.75 | +8.16 | −6.98 | −0.62 |
  | 2023 | −0.03 | −100.78 | −8.06 | −1.82 | 1.31 |
  | 2024 | +0.27 | −10.55 | −0.33 | +2.91 | −1.80 |

  Volume + market price + load profile = commodity effect of query 11 (2022: 112.80 m CZK).
- Known limitations: volume and load profile effects are SIMULATED (constant simulated volume → the volume effect
  is almost zero by construction). The order of the split (volume → price → profile) changes the size of the
  parts, not the total (ADR-004).

## Exchange rate effect
- Business question it answers: did the EUR/CZK rate help or hurt the CZK power cost?
- Business definition: the part of the CZK cost change caused by the effective EUR/CZK rate
  (`R = C_czk / C_eur`, cost-weighted) moving from the previous year: `C_eur1 × (R1 − R0)` (ADR-006).
  Negative = a stronger koruna made power cheaper.
- Formula (SQL / DAX reference): `rate_effect_czk` in `sql/11_query_fx_effect.sql`.
- Unit & time grain: CZK; year over year (2021–2024).
- Filters / exclusions: none.
- How to read it: 2021 −2.60 · 2022 −6.98 · 2023 −1.82 · 2024 +2.91 m CZK. In 2022 the koruna offset 6.2 % of the
  commodity increase.
- Known limitations: the effective rate weights days by cost, so it differs slightly from the yearly average
  ČNB rate.

## Spot cost
- Business question it answers: what did power cost the company when it bought everything on the day-ahead market?
- Business definition: load-weighted power cost without any hedge, `C = SUM(load × price)`.
- Formula (SQL / DAX reference): `spot_cost_eur` in `sql/12_query_hedging.sql` (= yearly C of query 10).
- Unit & time grain: EUR per year (2021–2024 on page 4).
- Filters / exclusions: none.
- How to read it: 2021 2.98 · 2022 7.40 · 2023 2.97 · 2024 2.53 m EUR.
- Known limitations: SIMULATED load; power only (no regulated components).

## Hedged cost
- Business question it answers: what would the company have paid if it had fixed a share of the yearly volume
  in advance?
- Business definition: the share is bought as a flat (base load) product at a price fixed before the year, the
  rest at spot: `hedged = C + share × V × (Ph − Pb)`. `Ph` = proxy price = plain average spot price of the
  previous year (ASSUMPTION, ADR-003); sensitivity with the PXE CZ CAL base price of the previous year-end (FACT,
  2022–2024 only).
- Formula (SQL / DAX reference): `hedged_cost_eur` and `hedged_cost_pxe_eur` in `sql/12_query_hedging.sql`;
  in Power BI the share comes from the what-if parameter (0–100 %, step 25 % = the shares of query 12).
- Unit & time grain: EUR per year.
- Filters / exclusions: 2020 excluded (no previous year).
- How to read it: 2022 at 50 % 5.35 m EUR (proxy) / 7.04 m (PXE); at 100 % 3.30 m / 6.69 m (spot 7.40 m).
  2023 at 100 % 7.07 m (proxy) vs spot 2.97 m — the hedge fixed the crisis price.
- Known limitations: proxy price is not a real contract price; no transaction costs, no supplier margin;
  base load only (the load profile premium stays on spot).

## Hedging result 2021–2024
- Business question it answers: over several years, did fixing in advance save money or cost money?
- Business definition: sum of hedged cost 2021–2024 at the selected share minus sum of spot cost 2021–2024.
  Negative = hedging was cheaper.
- Formula (SQL / DAX reference): sum over years of `hedged_cost_eur − spot_cost_eur` from `sql/12_query_hedging.sql`.
- Unit & time grain: EUR, period 2021–2024.
- Filters / exclusions: PXE variant only 2022–2024 (shown separately in the tooltip).
- How to read it: proxy price at 100 % −1.44 m EUR (14,442,596.70 vs 15,883,549.87), at 50 % −0.72 m EUR.
  PXE price 2022–2024 at 100 % +3.62 m EUR (more expensive).
- Known limitations: as Hedged cost; the result depends on which price the hedge used.

## Crisis cost multiple
- Business question it answers: how many times more did electricity cost at the peak of the crisis than before it?
- Business definition: total electricity cost 2022 / total electricity cost 2020.
- Formula (SQL / DAX reference): yearly `total_cost_czk` of `sql/08_query_allin_price.sql`:
  200,924,897.61 / 45,464,435.44 = 4.42.
- Unit & time grain: ratio, fixed years 2022 and 2020 (Summary page title).
- Filters / exclusions: none.
- How to read it: 4.4× — the headline number of the report.
- Known limitations: SIMULATED load; regulated tariffs changed too (POZE was 0 from 2022-10-01 to 2023-12-31).

## DAX measures in Power BI
Measures of the report (`powerbi/`, step 4.2). Names and descriptions are Czech (report language,
`docs/dashboard_spec.md`); columns are referenced with the table name, measures without it. Every ratio takes its
numerator and denominator from the same table, so a filter on one table cannot change only half of it.
Check values = yearly SQL results (queries 08 and 11, `vw_hourly_cost`), compared 2026-11-07 and 2026-11-08 (query 05 extreme hours, 07 top hour, 09 peak/off-peak, 11 cost change).

| Measure | Home table | DAX | KPI | Check 2022 |
|---------|------------|-----|-----|------------|
| Náklad na silovou elektřinu (Kč) | `vw_hourly_cost` | `SUM(vw_hourly_cost[power_cost_czk])` | Total electricity cost (power part) | 181,956,775.64 |
| Spotřeba (MWh) | `vw_hourly_cost` | `SUM(vw_hourly_cost[load_mwh])` | — | 27,953.42 |
| Cena za silovou elektřinu (Kč/MWh) | `vw_hourly_cost` | `DIVIDE([Náklad na silovou elektřinu (Kč)], [Spotřeba (MWh)])` | Load profile premium (weighted price) | 6,509.28 |
| Cena za silovou elektřinu (Kč/kWh) | `vw_hourly_cost` | `[Cena za silovou elektřinu (Kč/MWh)] / 1000` | — | 6.51 |
| Celkový náklad na elektřinu (Kč) | `vw_monthly_cost` | `SUM(vw_monthly_cost[total_cost_czk])` | Total electricity cost | 200,924,897.61 |
| Celková cena elektřiny (Kč/kWh) | `vw_monthly_cost` | `DIVIDE([Celkový náklad na elektřinu (Kč)], SUM(vw_monthly_cost[load_mwh])) / 1000` | All-in price | 7.19 |
| Podíl silové elektřiny (%) | `vw_monthly_cost` | `DIVIDE(SUM(vw_monthly_cost[power_cost_czk]), [Celkový náklad na elektřinu (Kč)])` | Power share | 90.6 % |
| Průměrná tržní cena (Kč/MWh) | `vw_hourly_cost` | `AVERAGE(vw_hourly_cost[price_czk_mwh])` | Average market price | 6,082.84 |
| Přirážka za diagram odběru (Kč/MWh) | `vw_hourly_cost` | `[Cena za silovou elektřinu (Kč/MWh)] - [Průměrná tržní cena (Kč/MWh)]` | Load profile premium | 426.45 |
| Přirážka za diagram odběru (Kč) | `vw_hourly_cost` | `[Přirážka za diagram odběru (Kč/MWh)] * [Spotřeba (MWh)]` | Load profile premium | 11,920,639.66 |
| Extrémní hodiny | `vw_hourly_cost` | `CALCULATE(COUNTROWS(vw_hourly_cost), vw_hourly_cost[price_czk_mwh] >= 5821) + 0` | Extreme hours | 3,694 |
| Nejvyšší hodinová cena (Kč/MWh) | `vw_hourly_cost` | `MAX(vw_hourly_cost[price_czk_mwh])` | Highest hourly price | 21,422.25 |
| Průměrná cena ve špičce (Kč/MWh) | `vw_hourly_cost` | `CALCULATE([Průměrná tržní cena (Kč/MWh)], dim_date[is_weekend] = FALSE(), dim_hour[hour_of_day] >= 9, dim_hour[hour_of_day] <= 20)` | Peak/off-peak spread | 7,030.40 |
| Průměrná cena mimo špičku (Kč/MWh) | `vw_hourly_cost` | see below | Peak/off-peak spread | 5,558.65 |
| Rozdíl špička – mimo špičku (Kč/MWh) | `vw_hourly_cost` | `[Průměrná cena ve špičce (Kč/MWh)] - [Průměrná cena mimo špičku (Kč/MWh)]` | Peak/off-peak spread | 1,471.75 |
| Náklad na silovou elektřinu minulý rok (Kč) | `vw_hourly_cost` | `CALCULATE([Náklad na silovou elektřinu (Kč)], SAMEPERIODLASTYEAR(dim_date[full_date]))` | Power cost change | 76,133,003.83 |
| Změna nákladu na silovou elektřinu (Kč) | `vw_hourly_cost` | `VAR previous_cost = [Náklad na silovou elektřinu minulý rok (Kč)] RETURN IF(ISBLANK(previous_cost), BLANK(), [Náklad na silovou elektřinu (Kč)] - previous_cost)` | Power cost change | +105,823,771.81 |
| Krok změny nákladu (Kč) | `vw_cost_change_steps` | `SUM(vw_cost_change_steps[amount_czk])` | Market price, volume and load profile effects | 181,956,776.26 (sum of 5 steps) |
| Vliv kurzu (Kč) | `vw_cost_change_steps` | `CALCULATE([Krok změny nákladu (Kč)], vw_cost_change_steps[step_name] = "Exchange rate")` | Exchange rate effect | −6,978,840.33 |
| Náklad na silovou elektřinu bez zajištění (EUR) | `vw_yearly_hedging` | `SUM(vw_yearly_hedging[spot_cost_eur])` | Spot cost | 7,399,949.24 |
| Násobek nákladu krize (2022 / 2020) | `vw_monthly_cost` | `VAR cost_2022 = CALCULATE([Celkový náklad na elektřinu (Kč)], dim_date[year] = 2022) VAR cost_2020 = CALCULATE([Celkový náklad na elektřinu (Kč)], dim_date[year] = 2020) RETURN DIVIDE(cost_2022, cost_2020)` | Crisis cost multiple | 4.42 (every row) |
| Hodnota parametru Podíl zajištění | `Podíl zajištění` | `SELECTEDVALUE('Podíl zajištění'[Podíl zajištění], 0)` (generated by Power BI) | Hedged cost (slider) | 0 – 100 % |
| Náklad na silovou elektřinu se zajištěním - proxy (EUR) | `vw_yearly_hedging` | `VAR no_hedge = [Náklad na silovou elektřinu bez zajištění (EUR)] VAR parameter = [Hodnota parametru Podíl zajištění] VAR hedge_diff = SUM(vw_yearly_hedging[hedge_diff_proxy_eur]) RETURN no_hedge + parameter * hedge_diff` | Hedged cost | 6,374,240.95 at 25 % |
| Náklad na silovou elektřinu se zajištěním - PXE (EUR) | `vw_yearly_hedging` | `VAR no_hedging = [Náklad na silovou elektřinu bez zajištění (EUR)] VAR param = [Hodnota parametru Podíl zajištění] VAR pxe = SUM(vw_yearly_hedging[hedge_diff_pxe_eur]) RETURN IF(ISBLANK(pxe), BLANK(), no_hedging + param * pxe)` | Hedged cost (PXE sensitivity) | 6,685,638.51 at 100 % |
| Výsledek zajištění - proxy (EUR) | `vw_yearly_hedging` | `VAR no_hedging = [Náklad na silovou elektřinu bez zajištění (EUR)] VAR proxy = [Náklad na silovou elektřinu se zajištěním - proxy (EUR)] RETURN proxy - no_hedging` | Hedging result 2021–2024 | −4,102,833.18 at 100 % |

Off-peak = weekend **or** an hour outside 9–20. Filters inside `CALCULATE` combine only with AND, and an OR across
two tables (`dim_date`, `dim_hour`) is not simple, so off-peak is computed as all hours minus peak hours:

```dax
Průměrná cena mimo špičku (Kč/MWh) =
VAR peak_price_sum = CALCULATE(SUM(vw_hourly_cost[price_czk_mwh]), dim_date[is_weekend] = FALSE(), dim_hour[hour_of_day] >= 9, dim_hour[hour_of_day] <= 20)
VAR peak_hours = CALCULATE(COUNTROWS(vw_hourly_cost), dim_date[is_weekend] = FALSE(), dim_hour[hour_of_day] >= 9, dim_hour[hour_of_day] <= 20)
RETURN
DIVIDE(SUM(vw_hourly_cost[price_czk_mwh]) - peak_price_sum, COUNTROWS(vw_hourly_cost) - peak_hours)
```

- Year-over-year measures need `dim_date` marked as date table. 2020 has no previous year in the data → BLANK
  (not 0, the data are missing); without the `ISBLANK` check 2020 would show its whole cost as a "change".
  Their total rows mean nothing (the period shifted by a year) → hidden in visuals.
- Krok změny nákladu: the waterfall splits it by `step_name`; per year the 5 steps add up to that year's power cost
  within 0.6–1.8 CZK (rounding of the effective rate R, ADR-006). The view starts in 2021 (2020 has no previous year).
- Násobek nákladu krize: the year filter inside `CALCULATE` replaces the year coming from the visual, so the value is
  the same in every row (fixed years, Summary page).
- Podíl zajištění is a what-if parameter: a disconnected table `GENERATESERIES(0, 1, 0.25)` with no relationship;
  it only holds the slider value. `SELECTEDVALUE(…, 0)` returns 0 (no hedge) when no single value is selected.
  Hedged cost checked at 25 % (2021–2024: 2,512,701.17 · 6,374,240.95 · 3,996,851.50 · 2,639,517.96 EUR).
- Hedged cost PXE: there is no PXE price for 2021, so `hedge_diff_pxe_eur` is NULL and its `SUM` is BLANK. BLANK acts as
  0 in arithmetic, so without the `ISBLANK` check 2021 would show the unhedged cost (2,981,864.21 EUR) as if the hedge
  changed nothing → BLANK. Checked at 100 % (2022–2024: 6,685,638.51 · 6,918,421.78 · 2,920,179.09 EUR = query 12).
  The total row mixes 2021 without a hedge with 2022–2024 hedged (19,506,103.60 EUR instead of 16,524,239.38 for the
  three years) → shown per year, total row hidden.
- Výsledek zajištění - proxy: one measure for both views — per year in a table, the whole period 2021–2024 without a
  year filter (both measures are sums, so their difference adds up). Checked at 100 %: −1,876,652.15 · −4,102,833.18 ·
  +4,098,656.75 · +439,875.41, total −1,440,953.17 EUR (= query 12). Negative = hedging was cheaper.
- `+ 0` in Extrémní hodiny: `COUNTROWS` of an empty table is BLANK; a year without extreme hours (2020) must show 0.
- `/ 1000` divides by a constant (MWh → kWh), so it cannot fail; `DIVIDE` is used wherever the denominator is a measure.
- Load profile premium (Kč) is correct for one year. Over several years the market average is taken over all their
  hours, not per year: 2020–2024 shows 25,028,480.44 CZK, the sum of the five years is 25,092,615.49 CZK. The report
  shows it per year (page 2 year slicer); visuals by year hide the total row.
- Power BI and SQL differ by up to 0.02 CZK in the premium (SQL rounds `AVG` of DECIMAL to 6 decimals).

## <KPI name>
- Business question it answers:
- Business definition:
- Formula (SQL / DAX reference):
- Unit & time grain:
- Filters / exclusions:
- How to read it (what good/bad looks like):
- Known limitations:
