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
