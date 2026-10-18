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
