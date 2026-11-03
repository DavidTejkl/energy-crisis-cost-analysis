# Dashboard specification — Power BI report

Version 2 (step 4.0b). Requirements and user stories: [requirements.md](requirements.md).
KPI formulas: [kpi_definitions.md](kpi_definitions.md). Every KPI on a page links to its definition there.

## Goal

Anyone — a CFO, an energy manager or a reader with no energy background — understands the result of the project
in 30 seconds from the Summary page and finds the evidence for it in the next four pages.

## The story

The report is one story in five chapters. Read only the page titles and you have the whole result.

| # | Page | Reader's question | Title for 2022 (dynamic) |
|---|---|---|---|
| 0 | Summary | What happened and what does it mean? | "The energy crisis made electricity 4.4× more expensive for the company" (fixed, not by year) |
| 1 | Market | What happened on the market? | "2022: prices were extreme in 42 % of all hours" |
| 2 | Company cost | What did it do to the company? | "2022: the company paid 200.9 m CZK, 90.6 % of it for power" |
| 3 | Why it changed | Why? | "2022: 99 % of the power cost increase came from the market price" |
| 4 | Hedging | What to do next time? | "Fixing the price in advance moves the shock, it does not remove it" |

## Rules for all pages

**Structure**
- Same template on every page (below), canvas 16:9 (1280 × 720). The reader learns it once.
- Title = the conclusion, written as a sentence. Pages 1–3 have a dynamic title for the selected year
  (DAX measure in the title's *fx*). Subtitle = the page question + labels.
- Three KPI cards plus one text box **"What this means"**: 2–3 plain sentences for the CFO.
  The text is true for the whole period 2020–2024, so it never contradicts the selected year.
- One main chart and at most two supporting visuals.
- Navigation buttons at the bottom; one year slicer synced across pages 1–3 (*sync slicers*).
- Charts that compare years always show all five years: the year slicer does not filter them
  (*edit interactions* = none).

**Visual**
- Every colour has one meaning (theme file in Power BI):

  | Colour | Hex | Meaning | Where |
  |---|---|---|---|
  | Graphite | `#1E1F22` | frame | page header band, "What this means" box, active page button |
  | Amber | `#D97706` | cost, increase, problem | power cost, increases in the waterfall, extreme band, fixed-price line |
  | Teal green | `#0D9488` | decrease, saving, what the company can influence | decreases in the waterfall, negative-price band, short notes on cards |
  | Mint | `#5EDD92` | control on a dark background | SIMULATED label, selected year, "What this means" heading |
  | Greys | `#868E9A`, `#A7AEB8`, `#B5BBC4`, `#D7DBE0` | everything else | regulated charges, market average, spot cost |
  | Background / cards | `#F3F4F6` / `#FFFFFF` | — | cards with 18 px rounded corners and a light shadow |
  | Text / muted text | `#1E1F22` / `#6B7280` | — | numbers and labels; never in a data colour |

- Rules: teal green and mint never fill a large area; mint never in a chart (contrast 1.7 : 1 on white).
  Amber and teal pass the colour-blind check (ΔE 12.5 protan, target ≥ 8); pure green next to amber would not.
  Never red/green (~8 % of men are colour-blind).
- Data labels on the data instead of legends where possible; no gridlines; no pie, gauge or 3D charts.
- Title 20 pt or more, card numbers 28 pt or more.
- Money: m CZK (or m EUR on page 4) with one decimal on cards and charts; full precision in tooltips.

**Words**
- Chart titles are sentences with the finding, not topic names.
- Plain words on the page, the technical term and definition in an ⓘ tooltip:

  | On the page | Technical term (tooltip) |
  |---|---|
  | How much more expensive day is than night | peak/off-peak spread |
  | Extra cost of using power in expensive hours | load profile premium |
  | Fixed in advance | hedged |
  | Price fixed one year ahead (estimate) | hedging proxy price (ASSUMPTION, ADR-003) |

**Currency** — one currency per page. Pages 0–3 in CZK (the users are a Czech CFO and energy manager; price bands
are defined in CZK). Page 4 in EUR, because power contracts are traded in EUR/MWh. The other currency appears only
in tooltips.

**Trust**
- Labels: market data are FACT. Anything built on the simulated load says SIMULATED with one sentence in the
  tooltip: "Real load curves are trade secrets; the load is a simulated 28 GWh/year profile, prices are real."
  The hedging proxy price says ASSUMPTION.
- Footer on every page: data sources and "prices without VAT".
- Every number on the report equals the SQL result (step 4.7); the check values are listed per page below.

### Page template

```
┌────────────────────────────────────────────────────────────────────────┐
│ TITLE = CONCLUSION (sentence)                          [Year ▾]   ⓘ    │
│ subtitle = page question · SIMULATED / ASSUMPTION labels               │
├──────────────┬──────────────┬──────────────┬───────────────────────────┤
│ KPI card     │ KPI card     │ KPI card     │ WHAT THIS MEANS           │
│              │              │              │ 2–3 plain sentences       │
├──────────────┴──────────────┴──────────────┴───────────────────────────┤
│ MAIN CHART                                                             │
├───────────────────────────────────┬────────────────────────────────────┤
│ SUPPORTING VISUAL                 │ SUPPORTING VISUAL (optional)       │
├───────────────────────────────────┴────────────────────────────────────┤
│ ◀ Summary · Market · Cost · Why · Hedging ▶          source · no VAT   │
└────────────────────────────────────────────────────────────────────────┘
```

## Page 0 — Summary

**Question:** what did the energy crisis cost the company, why, and what does it mean for next year?
**User:** everyone (CFO first). **User stories:** all (US-01 – US-06.2 in short). **Labels:** SIMULATED.
**Currency:** CZK. **Year slicer:** none — the page tells the whole 2020–2024 story.
**Title (fixed):** "The energy crisis made electricity 4.4× more expensive for the company".

### KPI cards

| Card | KPI | Value | SQL check |
|---|---|---|---|
| Cost 2022 vs 2020 | [Crisis cost multiple](kpi_definitions.md#crisis-cost-multiple) | 200.9 m CZK vs 45.5 m CZK (4.4×) | `sql/08_query_allin_price.sql` |
| Market price share of the 2022 increase | [Market price, volume and load profile effects](kpi_definitions.md#market-price-volume-and-load-profile-effects) | 99 % | waterfall query in `kpi_definitions.md` |
| Extra cost of using power in expensive hours, 2022 | [Load profile premium](kpi_definitions.md#load-profile-premium) | 11.9 m CZK | premium query in `kpi_definitions.md` |

### What this means (text box)

1. The crisis was a market price shock: consumption hardly changed, the price did.
2. The company pays extra because it uses most power in expensive daytime hours — that part it can influence.
3. Fixing the price a year ahead is insurance against swings, not a way to save: it lowered 2022 but raised 2023.

### Visuals

| Visual | Type | Axis / legend | Values | Colour | Chart title |
|---|---|---|---|---|---|
| Main: yearly cost | stacked column | year 2020–2024; power, regulated | m CZK | power amber, regulated grey; 2021–2023 shaded | "Power drove the cost up; regulated charges stayed at 17–20 m CZK until 2024" |
| Navigation tiles | 4 buttons | one per detail page with its question | — | grey | — |

### Acceptance

- Yearly totals equal query 08: 45.46 · 95.72 · 200.92 · 87.93 · 94.84 m CZK; 200.92 / 45.46 = 4.4×.
- 99 % = market price effect 104.75 / power cost change 105.82 m CZK (2021 → 2022).

## Page 1 — Market

**Question:** how extreme was the electricity market in each year?
**User:** energy manager. **User stories:** US-06.1, US-06.2. **Labels:** FACT (OTE, ČNB). **Currency:** CZK.
**Dynamic title (2022):** "2022: prices were extreme in 42 % of all hours".

### KPI cards (selected year)

| Card | KPI | Unit | Comparison line | Check value 2022 | SQL check |
|---|---|---|---|---|---|
| Average market price | [Average market price](kpi_definitions.md#average-market-price) | CZK/MWh | previous year | 6,082.84 (2021: 2,570.35) | yearly AVG of `price_czk_mwh`, run 2026-11-03 |
| Hours with extreme prices | [Extreme hours](kpi_definitions.md#extreme-hours) | hours | share of the year | 3,694 (42.2 %) | `sql/05_query_price_bands.sql` |
| Most expensive hour | [Highest hourly price](kpi_definitions.md#highest-hourly-price) | CZK/MWh | date and hour | 21,422.25 (2022-08-29, 19:00–20:00) | `sql/07_query_top_hours.sql` |

### What this means

Prices rose already in 2021 and peaked in 2022, when four hours in ten were extreme. Daytime working hours were
1,472 CZK/MWh more expensive than nights and weekends in 2022 (peak/off-peak spread) — moving load matters most
in a crisis. After 2023 prices fell, but single extreme hours still occur (December 2024).

### Visuals

| Visual | Type | Axis / legend | Values | Year slicer | Colour | Chart title |
|---|---|---|---|---|---|---|
| Main: price trend | line | month 2020-01 … 2024-12 | Average market price, CZK/MWh | no | grey line, 2021–2023 shaded amber | "Market prices multiplied in 2021–2022 and fell back in 2023" |
| Hours by price band | 100 % stacked bar | year; band negative → extreme | count of hours | no | grey scale, negative teal green, extreme amber | "Extreme hours: 0 in 2020, 3,694 in 2022" |
| Top 5 hours | table | rank, date, hour, CZK/MWh | `RANK` within the year | yes | — | "The most expensive hours of {year}" |

Tooltip on the bands chart: hours per band and the peak/off-peak spread and hours of the year (US-06.2).
Band order: negative → low → normal → high → extreme (sort-by column, decision 2026-09-30).

### Acceptance (from requirements.md)

- 2022: 3,694 extreme hours; all bands of a year sum to the hours of the year (2022: 8,760).
- Most expensive hour 2022-08-29, hour 20, 21,422.25 CZK/MWh.
- 2022 spread 1,471.75 CZK/MWh (60.04 EUR/MWh) in the text and tooltip; peak + off-peak hours = 3,120 + 5,640 = 8,760.

## Page 2 — Company cost

**Question:** how much did the company pay for electricity, and for what?
**User:** CFO. **User stories:** US-01, US-05. **Labels:** SIMULATED (load), FACT (prices, tariffs). **Currency:** CZK.
**Dynamic title (2022):** "2022: the company paid 200.9 m CZK, 90.6 % of it for power".

### KPI cards (selected year)

| Card | KPI | Unit | Comparison line | Check value 2022 | SQL check |
|---|---|---|---|---|---|
| Total cost | [Total electricity cost](kpi_definitions.md#total-electricity-cost) | m CZK | previous year | 200.92 (2021: 95.72) | `sql/08_query_allin_price.sql` |
| Price per kWh, everything included | [All-in price](kpi_definitions.md#all-in-price) | CZK/kWh | previous year | 7.19 (2021: 3.42) | `sql/08_query_allin_price.sql` |
| Extra cost of using power in expensive hours | [Load profile premium](kpi_definitions.md#load-profile-premium) | m CZK | per MWh | 11.92 (426.45 CZK/MWh) | premium query in `kpi_definitions.md` |

The power share (90.6 % in 2022, [Power share](kpi_definitions.md#power-share)) is in the dynamic title.

### What this means

In a crisis the budget risk is the market price, not regulation: regulated charges stayed at 17–20 m CZK a year
until 2024 while power cost multiplied. The company also pays extra every year because it runs most of its load in expensive
daytime hours — this is the part of the bill it can influence by moving load.

### Visuals

| Visual | Type | Axis / legend | Values | Year slicer | Colour | Chart title |
|---|---|---|---|---|---|---|
| Main: monthly cost | stacked column | month 2020-01 … 2024-12; power, regulated per MWh, fixed (reserved capacity, OTE fees), POZE | m CZK | no | power amber, the rest grey shades | "Only the power part of the bill exploded" |
| Company price vs market average | clustered column | year; market average, company price | CZK/MWh | no | company amber, market grey | "The company pays more than the market average because it uses power in expensive hours" |

Tooltip on the monthly chart: every component in CZK (network use, system services, tax, reserved capacity,
OTE fees, POZE).

### Acceptance

- Yearly totals equal query 08 (2022: 200,924,897.61 CZK, power share 90.6 %); components sum to the total.
- 2022 premium 426.45 CZK/MWh, 11.92 m CZK, labelled SIMULATED (requirements.md quotes the EUR value of query 10:
  +17.29 EUR/MWh, 483,333 EUR; the CZK value is the same premium priced in koruna, cross-checked 2026-11-03).

## Page 3 — Why it changed

**Question:** why did the power cost change from the previous year — market price, volume, load profile or the
EUR/CZK rate?
**User:** CFO. **User stories:** US-02, US-03. **Labels:** SIMULATED (volume and load profile effects).
**Currency:** CZK; EUR split of query 10 in the tooltip. **Year slicer:** "Change into" 2021–2024.
**Dynamic title (2022):** "2022: 99 % of the power cost increase came from the market price".

**Method:** one waterfall in CZK answers both stories. ADR-006 prices the commodity effect as
`(C_eur1 − C_eur0) × R0`, and ADR-004 splits `C_eur1 − C_eur0` into volume, market price and load profile.
Each EUR effect × the previous year's effective rate `R0` gives the same effect in CZK; the three sum to the
commodity effect of query 11. No new method, only ADR-004 and ADR-006 in one picture.

### KPI cards (change from the previous year into the selected year)

| Card | KPI | Unit | Comparison line | Check value 2022 | SQL check |
|---|---|---|---|---|---|
| Change in power cost | [Power cost change](kpi_definitions.md#power-cost-change) | m CZK | % vs previous year | +105.82 (+139.0 %) | `sql/11_query_fx_effect.sql` |
| Caused by the market price | [Market price effect](kpi_definitions.md#market-price-volume-and-load-profile-effects) | m CZK | share of the change | +104.75 (99.0 %) | waterfall query in `kpi_definitions.md` |
| Caused by the EUR/CZK rate | [Exchange rate effect](kpi_definitions.md#exchange-rate-effect) | m CZK | "koruna helped" / "koruna hurt" | −6.98 (helped) | `sql/11_query_fx_effect.sql` |

### What this means

Almost the whole change in every year came from the market price. Consumption was stable (simulated), so the
volume effect is close to zero. The stronger koruna softened the crisis a little (−7.0 m CZK in 2022), but it
was small next to the market price.

### Visuals

| Visual | Type | Axis / legend | Values | Year slicer | Colour | Chart title |
|---|---|---|---|---|---|---|
| Main: waterfall | waterfall | previous year cost → volume → market price → load profile → exchange rate → selected year cost | m CZK | yes | increase amber, decrease teal green, start and end grey | "From {year−1} to {year}: what pushed the cost up and down" |
| Effects of all years | clustered column | year 2021–2024; volume, market price, load profile, exchange rate | m CZK | no | market price amber, the rest grey | "Every year, the market price was the main driver" |

Tooltip on the waterfall: the same effect in EUR (query 10) and the effective rates `R0`, `R1` (query 11).

### Acceptance

- 2022: start 76.13 m CZK; volume −0.11 + market price +104.75 + load profile +8.16 = commodity +112.80 m CZK
  (= query 11); exchange rate −6.98 m CZK (= query 11); end 181.96 m CZK.
- Every year the four effects sum to the change within 2 CZK (run 2026-11-03: 1.52 / −0.62 / 1.31 / −1.80 CZK).
- Tooltip shows the EUR effects of US-02: market price +4,102,833, load profile +319,538, volume −4,286 EUR.

## Page 4 — Hedging

**Question:** how much of next year's volume should the company fix in advance?
**User:** energy manager, CFO. **User story:** US-04. **Labels:** SIMULATED, ASSUMPTION (proxy price).
**Currency:** EUR (power contracts are traded in EUR/MWh). **Controls:** year slicer 2021–2024 and a
"Share fixed in advance" slider 0–100 % in steps of 5 %, default 50 % (*what-if parameter*).
**Title (fixed):** "Fixing the price in advance moves the shock, it does not remove it".

### KPI cards (selected year and share)

| Card | KPI | Unit | Comparison line | Check value 2022, 50 % | SQL check |
|---|---|---|---|---|---|
| Cost without fixing | [Spot cost](kpi_definitions.md#spot-cost) | m EUR | — | 7.40 | `sql/12_query_hedging.sql` |
| Cost with {share} fixed | [Hedged cost](kpi_definitions.md#hedged-cost) | m EUR | difference to spot; with PXE price | 5.35 (−2.05; PXE 7.04) | `sql/12_query_hedging.sql` |
| 2021–2024 total with {share} fixed | [Hedging result 2021–2024](kpi_definitions.md#hedging-result-20212024) | m EUR | vs spot | −0.72 (cheaper) | `sql/12_query_hedging.sql`, sum of years |

### What this means

Fixing the price a year ahead uses last year's price. In 2022 that was cheap and saved money; at the end of 2022
the company would have fixed the crisis price, so 2023 cost more than spot. Fixing is insurance against swings,
not a way to save. Even at 100 % the company still pays the extra cost of its daytime load (page 2), because a
flat contract does not match its load shape.

### Visuals

| Visual | Type | Axis / legend | Values | Year slicer | Colour | Chart title |
|---|---|---|---|---|---|---|
| Main: cost by share fixed | line | share 0–100 %; spot (flat), proxy price, PXE price | m EUR | yes | proxy amber, PXE dark grey, spot light grey; marker at the slider value | "{year}: what the company would have paid at each share fixed in advance" |
| All years at the selected share | clustered column | year 2021–2024; spot, fixed at proxy price | m EUR | no (slider yes) | fixed amber, spot grey | "The 2022 shock gets smaller — and moves to 2023" |

The PXE price exists for 2022–2024 only; for 2021 the PXE line is hidden and the card says "no PXE price".

### Acceptance

- 0 % = spot cost for every year (2022: 7,399,949.24 EUR).
- 2022 at 100 %: 3,297,116.06 EUR with the proxy price, 6,685,638.51 EUR with the PXE price (query 12).
- 2022 at 50 %: 5,348,532.65 (proxy), 7,042,793.88 (PXE).
- 2021–2024 at 100 % proxy: 14,442,596.70 vs spot 15,883,549.87 EUR (−1.44 m); at 50 %: 15,163,073.28 (−0.72 m).
- The proxy price is labelled ASSUMPTION.

## Data sources for Power BI

Not decided yet: which tables and views the model imports, and which query results become views
(decided in the next part of 4.0b). Known needs:
- Page 1 trend in CZK: `vw_daily_summary` holds the market price sum in EUR only → a CZK sum or the hourly
  view `vw_energy_prices_czk` is needed.
- Page 2 monthly components: the result of query 08 (monthly, by component).
- Page 3 waterfall: one row per year and step (step name, value in CZK) — Power BI's waterfall needs this shape.
- Page 4: yearly V, C, Pb, proxy price and PXE price (query 12 inputs); the share comes from the what-if parameter.
