# Findings

Market prices only (OTE day-ahead, CZ). The company cost comes in phase 2.
Labels: FACT = read from a query output, with the query named.

## 1.2 Daily overview (`sql/04_query_daily_overview.sql`)

- **FACT:** The most expensive day was 26 Aug 2022 with an average of 17,325 CZK/MWh (703 EUR/MWh).
  In the whole of 2020 no day averaged more than 2,116 CZK/MWh, so the peak day was about 8 times
  the most expensive day of 2020.
  (`avg_czk_price_per_day`, max per year)
- **FACT:** The value traded on the day-ahead market (sum of `traded_value_czk`) was 20.7 bn CZK in 2020
  and 155.8 bn CZK in 2022, 7.5 times more. Volume grew only from 22.4 to 24.3 TWh (+8 %),
  so almost all of the jump came from the price.
  (`traded_value_czk` and `volume_mwh_per_day` summed per year)

## 1.3 Price bands (`sql/05_query_price_bands.sql`)

- **FACT:** In 2020 only 1 hour was in the high or extreme band (≥ 3,374 CZK/MWh); in 2022 it was
  6,951 hours, 79 % of the year. Cheap hours (low band, 0 – < 1,217 CZK/MWh) fell from 7,045 (80 % of 2020)
  to 237 (3 % of 2022). By 2024 the market was back to mostly normal hours (6,462) with 84 extreme hours.
  (`count_of_hours` per `year` and `price_band`, bands from `docs/kpi_definitions.md`)
- **FACT:** Negative-price hours dropped to 8 in 2022 and rose to 315 in 2024, the most of all five years.
  (same query, band `negative`)

## 1.4 Price changes (`sql/06_query_price_changes.sql`)

- **FACT:** The largest day-to-day rise of the daily average price was on 11 Jul 2022: +6,844 CZK/MWh
  (2,265 → 9,109). The largest drop was on 1 Oct 2022: −5,266 CZK/MWh (8,697 → 3,430).
  (`absolute_change`, max and min)
- **FACT:** 18 of the 20 largest daily rises in 2022 fell on a Monday, so the day-to-day change mostly shows
  the weekly pattern (cheap weekend, rebound on Monday) at a very high price level, not separate market events.
  (`absolute_change` of 2022, top 20, counted by `dim_date.weekday_num`)
- **Method note:** `pct_change` is NULL when the previous day's price is ≤ 0 (5 days), because dividing by
  a negative price flips the sign (e.g. 22 Mar 2020: −0.98 EUR/MWh on a Sunday with 11 negative hours,
  confirmed in the raw OTE file). Changes are therefore compared in CZK.

## 1.5 Top hours and days (`sql/07_query_top_hours.sql`)

- **FACT:** The most expensive hour of 2024 (12 Dec 2024, hour 18: 21,171 CZK/MWh) was almost as high as the
  most expensive hour of the crisis (29 Aug 2022, hour 20: 21,422 CZK/MWh). The most expensive day of 2024
  averaged 9,035 CZK/MWh, about half of the 2022 peak day (26 Aug 2022: 17,325 CZK/MWh).
  (`price_czk_mwh` and `avg_price_czk`, rank 1 per year)
- **FACT:** All 5 most expensive days of 2022 fell within one week, 24–31 Aug 2022 (15,535 – 17,325 CZK/MWh).
  (`avg_price_czk`, rank 1–5 of 2022)
- **FINDING:** 2022 was a long period of very high prices; the 2024 peak was a short shock of a few hours
  (low wind and solar output, see the DQ report). Single-hour spikes at crisis level are still possible after
  the crisis, so spot price risk did not disappear with it.

## 2.5 All-in price per month (`sql/08_query_allin_price.sql`)

All-in = power from the day-ahead market + regulated components (network use, system services, electricity tax,
reserved capacity 5 MW, POZE, OTE fees), ČEZ Distribuce, VN, **without VAT and without a supplier margin**
(ADR-005). Load is **SIMULATED** (28 GWh/year, `docs/methodology.md`); prices and tariffs are FACT.

- **FINDING (SIMULATED load):** the all-in price rose from **1.62 CZK/kWh in 2020 to 7.19 CZK/kWh in 2022**
  (4.4×), then 3.15 (2023) and 3.38 (2024). With almost the same volume (27.95–28.05 GWh), the yearly cost went
  from 45.5 m CZK (2020) to 200.9 m CZK (2022).
- **FINDING (SIMULATED load):** the power price drove the crisis: power was 58 % of the all-in cost in 2020 and
  91 % in 2022. The most expensive month was August 2022 (12.75 CZK/kWh all-in, power 12,084 CZK/MWh).
- **FINDING (SIMULATED load):** 2024 was more expensive than 2023 (3.38 vs 3.15 CZK/kWh) although power was
  cheaper (2,266 vs 2,550 CZK/MWh): the regulated part grew (network use 2.2×, system services 1.9× vs 2023,
  POZE back after being 0 from October 2022 to December 2023).
- **FINDING (SIMULATED load):** the company pays more than the market average because it uses more power in
  the expensive daytime hours: January 2020 load-weighted power price 1,148.10 vs simple average 1,054.47 CZK/MWh.
- **FACT:** the 2023 state price cap (5,000 CZK/MWh, applied to the monthly weighted power price, ADR-005) never
  binds: the most expensive month of 2023 was January at 3,572.47 CZK/MWh. In 2022, when no cap existed,
  6 months were above 5,000 CZK/MWh (highest August 2022, 12,084). For a company buying at spot prices, the cap
  came after the prices had already fallen.
- **FACT:** POZE was always cheaper by reserved capacity than by consumption (0 of 60 months chose the per-MWh
  cap): a continuous process uses many MWh per reserved MW.

## 2.6 Peak vs offpeak (`sql/09_query_peak_offpeak.sql`)

Peak = Monday–Friday 08:00–20:00 (`hour_of_day` 9–20), the market definition of the peak load product; every other
hour is offpeak. ASSUMPTION: weekday public holidays count as peak (no holiday flag in `dim_date`). Simple averages
of market prices (every hour has the same weight, as in a market product).

- **FACT:** the peak/offpeak spread rose from **12.53 EUR/MWh in 2020 to 60.04 EUR/MWh in 2022** (4.8×), then
  21.82 (2023) and 14.89 (2024). In CZK: 330.09 → 1,471.75 → 526.54 → 374.52 CZK/MWh.
- **FACT:** in relative terms the peak premium fell: peak was 43 % above offpeak in 2020, 38 % in 2021, 27 % in
  2022, 23 % in 2023 and 19 % in 2024. The spread grew in 2022 because the whole price level rose, not because
  daytime hours became relatively more expensive.
- **FINDING (SIMULATED load):** the company runs its crushing and offices in daytime shifts, so the absolute spread
  is the price of its schedule; this is why its load-weighted price is above the market average (+17.29 EUR/MWh in
  2022). The split into price, volume and load-profile effects follows in 2.7.

## 2.7 Cost variance split (`sql/10_query_variance_split.sql`)

Method ADR-004: year-over-year change of the power (commodity) cost in EUR, split in a fixed order into volume
`(V1 − V0) × Pw0`, market price `V1 × (Pb1 − Pb0)` and load profile `V1 × (S1 − S0)`. Load is SIMULATED, market
prices are real OTE data. Check: the three effects sum to the total change in every year (difference ≤ 0.03 EUR,
DECIMAL rounding of `Pw`).

| Change | Total (EUR) | Volume | Market price | Load profile |
|---|---:|---:|---:|---:|
| 2020 → 2021 | +1,976,267 | −2,052 | +1,876,652 | +101,667 |
| 2021 → 2022 | +4,418,085 | −4,286 | +4,102,833 | +319,538 |
| 2022 → 2023 | −4,427,762 | −1,194 | −4,098,657 | −327,911 |
| 2023 → 2024 | −442,638 | +11,073 | −439,875 | −13,836 |

- **FINDING:** the market price drove the cost: 95.0 % of the change in 2021, 92.9 % in 2022, 92.6 % in 2023 and
  99.4 % in 2024. The market price effect uses real OTE prices (FACT); its size depends on the simulated volume.
- **FINDING (SIMULATED load):** the load profile added **+319,538 EUR in 2022** (7.2 % of the increase) and
  returned −327,911 EUR in 2023. The company's profile did not change; the effect comes from the market's hourly
  price pattern, which made the company's daytime hours relatively more expensive when the whole price level rose.
- **FINDING (SIMULATED load):** the volume effect is small (−4,286 to +11,073 EUR), because the simulated company
  takes about 28 GWh every year. With a real load profile this effect would carry production changes.
