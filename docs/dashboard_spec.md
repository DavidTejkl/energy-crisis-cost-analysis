# Dashboard specification — Power BI report

Version 1 (step 4.0b). Requirements and user stories: [requirements.md](requirements.md).
KPI formulas: [kpi_definitions.md](kpi_definitions.md). Every KPI on a page links to its definition there.

## Rules for all pages

- One page answers one question; the question is the page subtitle.
- Reading order top-left to bottom-right: KPI cards → main chart → detail charts → table.
- KPI cards show the year selected in the slicer; a small line under the number gives the comparison
  (previous year or share of the year), because a number without a yardstick says nothing.
- Charts that compare years always show all five years: the year slicer does not filter them
  (Power BI *edit interactions* set to "none").
- Prices are never averaged from averages: every price is a sum divided by a sum (weighted) or a plain average
  over hours, as defined in `kpi_definitions.md`.
- Labels: market data are FACT. Anything built on the simulated load says SIMULATED; the hedging proxy price
  says ASSUMPTION.
- Footer on every page: data sources and "prices without VAT".

## Page 1 — Market

**Question:** how extreme was the electricity market in each year, before we look at the company's cost?
**User:** energy manager. **User stories:** US-06.1, US-06.2. **Labels:** FACT (OTE, ČNB).
**Currency:** EUR — the market trades in EUR. Exception: the top hour in CZK/MWh, because price bands are defined in CZK.

### Layout

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1 MARKET 2020–2024                           Year: [2020] … [2024]     │
├────────────────┬────────────────┬────────────────┬─────────────────────┤
│ Avg market     │ Extreme hours  │ Top hour       │ Peak/off-peak spread│
│ price          │                │                │                     │
├────────────────┴────────────────┴────────────────┴─────────────────────┤
│ Market price trend — monthly, all years (line)                         │
├───────────────────────────────────┬────────────────────────────────────┤
│ Hours by price band (100 % bar)   │ Peak vs off-peak (clustered column)│
├───────────────────────────────────┴────────────────────────────────────┤
│ Top 5 hours of the selected year (table)                               │
├────────────────────────────────────────────────────────────────────────┤
│ Source: OTE-ČR day-ahead, ČNB EUR/CZK. Prices without VAT.             │
└────────────────────────────────────────────────────────────────────────┘
```

### KPI cards (filtered by the year slicer)

| Card | KPI | Unit | Comparison line | Check value 2022 | SQL check |
|---|---|---|---|---|---|
| Avg market price | [Average market price](kpi_definitions.md#average-market-price) | EUR/MWh | previous year | 247.43 (2021: 100.66) | yearly AVG, STATUS 2026-10-14 |
| Extreme hours | [Extreme hours](kpi_definitions.md#extreme-hours) | hours | share of the year | 3,694 (42.2 %) | `sql/05_query_price_bands.sql` |
| Top hour | [Highest hourly price](kpi_definitions.md#highest-hourly-price) | CZK/MWh | date and hour | 21,422.25 (2022-08-29, hour 20) | `sql/07_query_top_hours.sql` |
| Peak/off-peak spread | [Peak/off-peak spread](kpi_definitions.md#peakoff-peak-spread) | EUR/MWh | peak / off-peak averages | 60.04 (286.09 / 226.05) | `sql/09_query_peak_offpeak.sql` |

### Visuals

| Visual | Type | Axis / legend | Values | Year slicer | Answers |
|---|---|---|---|---|---|
| Market price trend | line | month 2020-01 … 2024-12 | Average market price, EUR/MWh | no (all years) | the crisis in one picture |
| Hours by price band | 100 % stacked bar | year; legend = band negative → extreme | count of hours | no (all years) | US-06.1 |
| Peak vs off-peak | clustered column | year; legend = peak, off-peak | average price, EUR/MWh | no (all years) | US-06.2 |
| Top 5 hours | table | rank, date, hour, CZK/MWh, EUR/MWh | `RANK` by price within the year | yes | US-06.1 |

Band order in the legend is negative → low → normal → high → extreme (sort-by column, decision 2026-09-30).

### Filters

- Year slicer (buttons 2020–2024), single select, default 2022.

### Acceptance (from requirements.md)

- 2022: 3,694 extreme hours; all bands of a year sum to the hours of the year (2022: 8,760).
- Most expensive hour 2022-08-29, hour 20, 21,422.25 CZK/MWh.
- 2022 spread 60.04 EUR/MWh; peak + off-peak hours = hours of the year (3,120 + 5,640 = 8,760).

## Page 2 — Company cost

Not specified yet.

## Page 3 — Why it changed

Not specified yet.

## Page 4 — Hedging

Not specified yet.

## Data sources for Power BI

Not decided yet: which tables and views the model imports, and which query results (05, 07, 09, 10, 11, 12)
become views. Decided after all four pages are specified.
