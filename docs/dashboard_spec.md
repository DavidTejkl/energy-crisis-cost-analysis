# Dashboard specification — Power BI report

Version 1 (step 4.0b). Requirements and user stories: [requirements.md](requirements.md).
KPI formulas: [kpi_definitions.md](kpi_definitions.md). Every KPI on a page links to its definition there.

## Rules for all pages

- **One question per page, the answer in the title.** The page title states the conclusion for the selected year
  (dynamic title), e.g. "2022: the company paid 200.9 m CZK, 90.6 % of it for power". A reader who only glances at
  the page still takes the point away.
- **One currency per page.** Pages 1 and 2 are in CZK, because the users are a Czech CFO and energy manager and
  the price bands are defined in CZK. EUR appears only in tooltips. Page 3 shows the EUR split (ADR-004) and the
  EUR/CZK effect (ADR-006) in separate, clearly labelled visuals.
- **Colour carries the message.** The component that changes (power, crisis years, extreme band) gets a strong
  colour; stable components are grey. No rainbow palettes.
- Reading order top-left to bottom-right: title → KPI cards → main chart → detail charts → table.
- KPI cards show the year selected in the slicer; a small line under the number gives the comparison
  (previous year or share of the year), because a number without a yardstick says nothing.
- Charts that compare years always show all five years: the year slicer does not filter them
  (Power BI *edit interactions* set to "none").
- Prices are never averaged from averages: every price is a sum divided by a sum (weighted) or a plain average
  over hours, as defined in `kpi_definitions.md`.
- Numbers: money in millions of CZK with one decimal on cards, full precision in tables and tooltips.
- Labels: market data are FACT. Anything built on the simulated load says SIMULATED; the hedging proxy price
  says ASSUMPTION.
- Footer on every page: data sources and "prices without VAT".

## Page 1 — Market

**Question:** how extreme was the electricity market in each year, before we look at the company's cost?
**User:** energy manager. **User stories:** US-06.1, US-06.2. **Labels:** FACT (OTE, ČNB). **Currency:** CZK.
**Dynamic title (example 2022):** "2022: average market price 6,083 CZK/MWh, 3,694 hours above 5,821 CZK/MWh".

### Layout

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1 <dynamic title with the conclusion>        Year: [2020] … [2024]     │
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
| Avg market price | [Average market price](kpi_definitions.md#average-market-price) | CZK/MWh | previous year | 6,082.84 (2021: 2,570.35) | yearly AVG of `price_czk_mwh`, run 2026-11-03 |
| Extreme hours | [Extreme hours](kpi_definitions.md#extreme-hours) | hours | share of the year | 3,694 (42.2 %) | `sql/05_query_price_bands.sql` |
| Top hour | [Highest hourly price](kpi_definitions.md#highest-hourly-price) | CZK/MWh | date and hour | 21,422.25 (2022-08-29, hour 20) | `sql/07_query_top_hours.sql` |
| Peak/off-peak spread | [Peak/off-peak spread](kpi_definitions.md#peakoff-peak-spread) | CZK/MWh | peak / off-peak averages | 1,471.75 (7,030.40 / 5,558.65) | `sql/09_query_peak_offpeak.sql` |

### Visuals

| Visual | Type | Axis / legend | Values | Year slicer | Colour | Answers |
|---|---|---|---|---|---|---|
| Market price trend | line | month 2020-01 … 2024-12 | Average market price, CZK/MWh | no (all years) | one colour; 2021–2023 band shaded | the crisis in one picture |
| Hours by price band | 100 % stacked bar | year; legend = band negative → extreme | count of hours | no (all years) | grey → red, extreme strongest | US-06.1 |
| Peak vs off-peak | clustered column | year; legend = peak, off-peak | average price, CZK/MWh | no (all years) | peak strong, off-peak grey | US-06.2 |
| Top 5 hours | table | rank, date, hour, CZK/MWh, EUR/MWh | `RANK` by price within the year | yes | — | US-06.1 |

Band order in the legend is negative → low → normal → high → extreme (sort-by column, decision 2026-09-30).

### Filters

- Year slicer (buttons 2020–2024), single select, default 2022.

### Acceptance (from requirements.md)

- 2022: 3,694 extreme hours; all bands of a year sum to the hours of the year (2022: 8,760).
- Most expensive hour 2022-08-29, hour 20, 21,422.25 CZK/MWh.
- 2022 spread 1,471.75 CZK/MWh (60.04 EUR/MWh in the tooltip); peak + off-peak hours = hours of the year
  (3,120 + 5,640 = 8,760).

## Page 2 — Company cost

**Question:** how much did the company pay for electricity, and for what?
**User:** CFO. **User stories:** US-01, US-05. **Labels:** SIMULATED (load), FACT (prices and tariffs). **Currency:** CZK.
**Dynamic title (example 2022):** "2022: the company paid 200.9 m CZK, 90.6 % of it for power".

### Layout

```
┌────────────────────────────────────────────────────────────────────────┐
│ 2 <dynamic title>                  SIMULATED  Year: [2020] … [2024]    │
├────────────────┬────────────────┬────────────────┬─────────────────────┤
│ Total cost     │ All-in price   │ Power share    │ Load profile premium│
├────────────────┴────────────────┴────────────────┴─────────────────────┤
│ Monthly cost by component — all years (stacked column)                 │
├───────────────────────────────────┬────────────────────────────────────┤
│ Cost composition, selected year   │ Company price vs market average    │
│ (bar, largest first)              │ (clustered column, all years)      │
├───────────────────────────────────┴────────────────────────────────────┤
│ Load is SIMULATED (methodology.md). Prices without VAT and supplier    │
│ margin (ADR-005). Source: OTE-ČR, ČNB, ERÚ price decisions.            │
└────────────────────────────────────────────────────────────────────────┘
```

### KPI cards (filtered by the year slicer)

| Card | KPI | Unit | Comparison line | Check value 2022 | SQL check |
|---|---|---|---|---|---|
| Total cost | [Total electricity cost](kpi_definitions.md#total-electricity-cost) | m CZK | previous year | 200.92 (2021: 95.72) | `sql/08_query_allin_price.sql` |
| All-in price | [All-in price](kpi_definitions.md#all-in-price) | CZK/kWh | previous year | 7.1878 (2021: 3.4193) | `sql/08_query_allin_price.sql` |
| Power share | [Power share](kpi_definitions.md#power-share) | % | regulated share | 90.6 % | `sql/08_query_allin_price.sql` |
| Load profile premium | [Load profile premium](kpi_definitions.md#load-profile-premium) | CZK/MWh | total in m CZK | 426.45 (11.92 m CZK) | premium query in `kpi_definitions.md`, run 2026-11-03 |

### Visuals

| Visual | Type | Axis / legend | Values | Year slicer | Colour | Answers |
|---|---|---|---|---|---|---|
| Monthly cost by component | stacked column | month 2020-01 … 2024-12; legend = power, regulated per MWh, fixed (reserved capacity, OTE fees), POZE | cost, m CZK | no (all years) | power strong, the rest shades of grey | US-01 |
| Cost composition | bar, sorted largest first | component (power, reserved capacity, POZE, system services, network use, tax, OTE fees) | cost, m CZK | yes | power strong, the rest grey | US-01 |
| Company price vs market average | clustered column | year; legend = market average, company price | CZK/MWh; the difference is the premium | no (all years) | company price strong, market grey | US-05 |

### Filters

- Year slicer (buttons 2020–2024), single select, default 2022.

### Acceptance (from requirements.md)

- Yearly totals equal query 08 (2022: 200,924,897.61 CZK, power share 90.6 %); the components sum to the total.
- 2022 load profile premium 426.45 CZK/MWh, 11.92 m CZK in total, labelled SIMULATED
  (requirements.md quotes the EUR value of query 10: +17.29 EUR/MWh, 483,333 EUR; the CZK value is the same
  premium priced in koruna, cross-checked 2026-11-03).

## Page 3 — Why it changed

Not specified yet.

## Page 4 — Hedging

Not specified yet.

## Data sources for Power BI

Not decided yet: which tables and views the model imports, and which query results (05, 07, 08, 09, 10, 11, 12)
become views. Decided after all four pages are specified. Known needs so far:
- Page 1 trend in CZK: `vw_daily_summary` holds the market price sum in EUR only → a CZK sum or the hourly view
  `vw_energy_prices_czk` is needed.
- Page 2 monthly components: the result of query 08 (monthly, by component).
