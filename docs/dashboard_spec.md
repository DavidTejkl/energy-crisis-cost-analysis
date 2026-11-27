# Power BI report specification

**English** · [Čeština](dashboard_spec_cz.md)

This file describes how I built the report and why. Requirements and user stories are in
[requirements.md](requirements.md), the formulas of all KPIs and DAX measures in [kpi_definitions.md](kpi_definitions.md).
The report itself is in Czech, so page titles and labels are quoted in Czech with an English translation.

## Goal

A CFO, an energy buyer or a reader with no energy background should understand from the Summary page in 30 seconds
what the crisis cost the company and why. The evidence is on the four pages after it.

## The story

The report has 6 pages. Every page title is a conclusion, so reading only the titles gives the whole result.

| # | Page | Reader's question | Page title (translated) |
|---|---|---|---|
| 1 | O projektu (About) | What is the report about and how was it built? | "What did the 2021–2023 energy crisis cost an industrial company and could it have been prevented?" |
| 2 | Shrnutí (Summary) | What happened and what does it mean? | "The 2021–2023 crisis cost the company 385 m CZK instead of 136 m at 2020 prices, so 248 m CZK extra" |
| 3 | Trh (Market) | What happened on the market? | "The crisis started in autumn 2021, and in 2022 electricity was 7× more expensive than in 2020" |
| 4 | Náklad firmy (Company cost) | How much did the company pay and for what? | "2020–2022: the cost rose from 45 to 201 m CZK, regulated charges stayed at about 19 m" |
| 5 | Příčiny změny (Why it changed) | Why did the cost change? | "2022: the market price caused the 106 m CZK increase, the stronger koruna saved 7 m CZK" |
| 6 | Zajištění ceny (Hedging) | Does buying in advance pay off? | "A full hedge would have saved 4.1 m EUR in 2022 and cost the same amount extra in 2023" |

The order follows how an analyst would explain it: context and result first, then the market, the company, the causes
and finally what to do about it. I built the Summary last, from the finished detail pages.

## Rules for all pages

**Layout**
- Canvas 1280 × 720 (16 : 9). All pages use the same template, so the reader learns it once.
- The header is a rounded graphite rectangle with a mint top edge (two rectangles on top of each other, the mint one
  4 px higher). Title on the left, subtitle below it, year slicer on the right.
- The title is a conclusion written as a sentence and it is static. I considered a dynamic title per year and dropped
  it, because the charts compare years and the cards show the selected year. A static title must therefore hold for
  every year the slicer offers, or name its period (for example "2020–2022: …"). Every title was checked in SQL first.
- The subtitle holds the page question, the data sources and the simulated-load label.
- Detail pages have three KPI cards under the header and a "Co to znamená" (What this means) box with two or three
  sentences for the CFO. Below them one main chart and at most two more visuals.
- Every card has a 4 px mint strip on top (same technique as the header). Under the main value there is a comparison
  line, for example "Minulý rok" (previous year). The new card visual cannot show static text there, so the comparison
  lines are text measures.
- Money on cards is in m CZK or m EUR through separate "(mil. Kč)" measures, because the card cannot set display units
  for its main value. The CZK measures stay for calculations and tooltips.

**Year slicer and interactions**
- Every detail page has its own year slicer (Tab style). The slicers are not synced, because the pages Příčiny změny
  and Zajištění ceny offer only 2021–2024 (2020 has no previous year). All pages are saved on 2022.
- The year slicer filters the cards. Charts that compare years always show the whole period and the slicer does not
  filter them. A click in a chart does not filter the cards (interaction "None"), otherwise the cards would go blank or
  show a different year than the slicer.
- The O projektu page has a page navigator. All other pages have a "Zpět na úvod" (back to intro) button at the bottom
  left (x 24, y 690, 109 × 26). In Power BI Desktop the buttons react to Ctrl + click, in the published report to a
  plain click.

**Colours** (theme `powerbi/theme/energy_crisis_theme_g.json`, one meaning per colour)

| Colour | Hex | Meaning | Where |
|---|---|---|---|
| Graphite | `#1E1F22` | frame | header, "Co to znamená" boxes, buttons |
| Amber | `#D97706` | cost, increase, problem | power cost, market price, increases in the waterfall, extreme band |
| Teal | `#0D9488` | decrease, saving | decreases in the waterfall, negative-price band |
| Mint | `#5EDD92` | frame accent | top edge of the header and cards, selected year, button text |
| Greys | `#B5BBC4`, `#D7DBE0` and others | everything else | regulated charges, market average, cost without hedging |
| Background / cards | `#F3F4F6` / `#FFFFFF` | | |
| Text / muted text | `#1E1F22` / `#6B7280` | | numbers and labels |

- No red next to green (about 8 % of men cannot tell them apart). Amber and teal pass the colour-blind check
  (ΔE 12.5, target at least 8). Pure green next to amber would not.
- Mint is never used in a chart or as text on white, because its contrast is only 1.7 : 1.
- Total rows in tables are grey, never green, because green means a saving.

**Language and currency**
- Everything the user sees is in Czech: titles, axis labels, measure names and their descriptions. The users in the
  scenario are a Czech CFO and energy manager. Tables and columns keep their English names from SQL (technical layer).
- One currency per page. Pages 1–5 are in CZK, because the company pays in koruna and the price bands are defined in
  CZK. The hedging page is in EUR, because electricity is traded on the exchange in EUR/MWh.
- The pages use plain words (for example "load profile premium" is called "přirážka za diagram odběru", "hedged" is
  "koupeno předem"). The exact definition is in the measure description and in [kpi_definitions.md](kpi_definitions.md).

**Trust**
- Market data are real (FACT). Everything built on the company's load is SIMULATED and the subtitle says so. The
  hedging price is an ASSUMPTION ([ADR-003](decisions/ADR-003-forward-price-proxy.md)).
- A footer with the data sources, the split into real and simulated data and "without VAT and supplier margin" is on
  the O projektu and Shrnutí pages.
- On 2026-11-23 I compared every number in the report with a fresh SQL result, for every year and on the
  hedging page also for slider positions 0, 50 and 100 %. The check values are listed per page below.

### Page template

```
┌────────────────────────────────────────────────────────────────────────┐
│ TITLE = CONCLUSION (sentence)                      [2021 2022 2023 …]  │
│ subtitle = question · sources · simulated load                         │
├──────────────┬──────────────┬──────────────┬───────────────────────────┤
│ KPI card     │ KPI card     │ KPI card     │ WHAT THIS MEANS           │
│ comparison   │ comparison   │ comparison   │ 2–3 sentences             │
├──────────────┴──────────────┴──────────────┴───────────────────────────┤
│ MAIN CHART                                                             │
├───────────────────────────────────┬────────────────────────────────────┤
│ SUPPORTING VISUAL                 │ SUPPORTING VISUAL (optional)       │
├───────────────────────────────────┴────────────────────────────────────┤
│ [Zpět na úvod]                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

## Page O projektu (About)

**Purpose:** the first page a reader opens. It says what the report is about, which questions it answers and how it
was built, and it lets the reader jump to any page. No charts.

**Look:** light page with the graphite header of the other pages. Every block is a white box with a grey border
`#D7DBE0` and the same mint top edge as the cards. Block headings 12 pt bold graphite, body 10 pt.

| Block | Position (x, y, w × h) | Content |
|---|---|---|
| Header | 24, 20, 1232 × 72 | title and subtitle "Analysis of the electricity cost of a model Czech company · 2020–2024 · sources OTE, ČNB, ERÚ" |
| O čem report je (What the report is about) | 24, 107, 1232 × 125 | one paragraph in full sentences: OTE day-ahead market, power vs regulated charges (set by ERÚ and law, not negotiable), the load profile premium, what the hedging page shows |
| Na co report odpovídá (What it answers) | 24, 248, 608 × 140 | the four business questions of the brief |
| Proč je to důležité (Why it matters) | 648, 248, 608 × 140 | market price 2022 7× higher than 2020, company cost from 45 to 201 m CZK, budget risk for the CFO, purchasing decision |
| Postup projektu (How it was built) | 24, 404, 1232 × 150 | five bullets: Data (Python), Database (SQL Server), Analysis (SQL), Report (Power BI), Reproducibility |
| Page navigator | 24, 570, 1232 × 44 | built-in navigator. Selected page graphite with mint text and outline, the others white with graphite text |
| Footer | 24, 652, 1232 × 60 | real and simulated data, prices without VAT and margin, hedging with a proxy price, author and repo link |

**Check:** the numbers in the text come from earlier checks. 7× = 6,083 / 887 CZK/MWh (page Trh), 45 and 201 m CZK
(query 08), 7 tables and 43,848 hours (load), 18 automated data quality checks (one run in `dq_results`),
9 analysis queries (04–12), 6 ADRs.

## Page Shrnutí (Summary)

**Question:** what did the crisis cost the company, why, and what does it mean for next year?
**User:** everyone, the CFO first. It takes the main numbers from all detail pages. **Currency:** CZK.
**Year slicer:** none, the page tells the whole 2020–2024 story.

**Title and subtitle:** the title states the extra cost of the crisis. The subtitle shows the calculation so it can be
checked: "Actual cost: 95.72 + 200.92 + 87.93 = 384.57 m CZK · At 2020 prices (cheap COVID year, upper estimate):
3 × 45.46 = 136.39 m CZK". 2020 was a cheap year because of COVID, so this is an upper estimate.

### Cards

The Summary must not repeat the cards of the detail pages. It shows the extremes of the whole period and the regulated
charges, which are not on any other card.

| Card | Value | Comparison line | SQL check |
|---|---|---|---|
| Most expensive month overall (m CZK) | 32.30 | August 2022 · 12.75 CZK/kWh | `vw_monthly_cost`, highest `total_cost_czk` = 32,303,995.75 CZK, / 2,533.293 MWh = 12.75 CZK/kWh |
| Cheapest month overall (m CZK) | 2.91 | April 2020 (COVID) · 1.20 CZK/kWh | lowest = 2,911,201.48 CZK, / 2,433.427 MWh = 1.20 CZK/kWh |
| Most expensive day (m CZK) | 1.66 | 30 Aug 2022 · power only | `vw_hourly_cost` by day, top day 1,657,482.83 CZK |
| Regulated charges 2022 (m CZK) | 18.97 | 2024: 31.28 m CZK · 1.6× more | `vw_monthly_cost`, years 2022 and 2024 |

The cards compare months, not days. The cheapest day (2020-04-13) has a negative power cost (−28,460 CZK), so a ratio
would make no sense, and a month equals one invoice. The day is power only, because regulated charges exist only per
month. The month and day in the comparison lines are fixed text, because the page has no year slicer and the data
2020–2024 do not change.

### Text boxes

Instead of one "Co to znamená" box the Summary has three bullet boxes (400 × 160):
1. **Cause of the increase:** in 2022 the power cost rose by 105.8 m CZK, 104.8 m CZK of it from the market price.
   The market price was almost 7× the 2020 level, power was 91 % of the total cost, the stronger koruna saved 7.0 m CZK.
2. **Risks after the crisis:** in 2024 the cost was 94.8 m CZK, 2.1× the 2020 level. The market price was still 2.4×
   higher and regulated charges rose to 31.3 m CZK. Buying in advance does not cover this part.
3. **Recommendation** (RECOMMENDATION): fix only part of the volume (a full hedge saved 4.1 m EUR in 2022 and lost it
   in 2023, query 12), buy in several steps (the yearly product for 2023 traded at 984 EUR/MWh in August 2022 and at
   242 EUR/MWh in December 2022, [ADR-003](decisions/ADR-003-forward-price-proxy.md)), move part of the load out of the
   peak (load profile premium 11.9 m CZK in 2022).

The recommendations contain only what the project actually computed. FX hedging is not there, because I did not
compute it.

### Chart

| Visual | Type | Axis and values | Interaction | Colours | Chart title |
|---|---|---|---|---|---|
| Cost by year | stacked column | year (categorical axis), power and regulated charges, totals in m CZK | filters nothing | power amber, regulated grey | "Náklad na elektřinu po letech (mil. Kč)" (electricity cost by year) |

The chart filters neither the cards nor the text boxes. Otherwise a click on 2020 would change a card value while its
fixed comparison line still says "August 2022".

**Check:** totals 45.5 · 95.7 · 200.9 · 87.9 · 94.8 m CZK (query 08), crisis extra cost 384.57 − 136.39 = 248.18 m CZK.

## Page Trh (Market)

**Question:** how extreme was the electricity market in each year?
**User:** energy purchasing (US-06.1, US-06.2). **Data:** real (OTE, ČNB). **Currency:** CZK.

### Cards (selected year)

| Card | Measure | Comparison line | Check 2022 |
|---|---|---|---|
| Average market price (CZK/MWh) | `Průměrná tržní cena (Kč/MWh)` | previous year | 6,083 (2021: 2,570) |
| Extreme hours | `Extrémní hodiny` | share of the year | 3,694 (42.2 %) |
| Most expensive hour (CZK/MWh) | `Nejvyšší hodinová cena (Kč/MWh)` | date and hour | 21,422 (29 Aug 2022, hour 20) |

### What this means

In 2022 electricity on the market was 7× more expensive than in 2020 and 42 % of hours had an extreme price (from
5,821 CZK/MWh). Weekdays from 8:00 to 20:00 were 1,472 CZK/MWh more expensive than nights and weekends in 2022. From
2023 prices fell by 60–65 %, but extreme hours appeared again (December 2024).

### Charts

| Visual | Type | Axis and values | Year slicer | Colours | Chart title (translated) |
|---|---|---|---|---|---|
| Price trend | line, linear | `dim_date[month_start]`, 60 months, average market price, axis from 0 | no, the chart filters nothing | amber line | "Market prices multiplied in 2021–2022 and fell sharply in 2023" |
| Hours by price band | 100 % stacked bar | year × price band, `Počet hodin` | no, the chart filters nothing | teal, light teal, grey, light amber, amber (negative to extreme) | "Extreme hours grew from 0 % in 2020 to 42 % in 2022" |
| Most expensive hours | table | day, hour, price, top 5 by `hour_key` | yes | | "The most expensive hours of the selected year" |

The line is amber because the market price is the problem the page is about (grey was too weak as the only series).
The bands are sorted from negative to extreme with the helper column `price_band_order`. Three greys could not be told
apart, so the scale is teal, grey, amber.

**Check:** extreme hours 0 / 577 / 3,694 / 30 / 84 (0.0 / 6.6 / 42.2 / 0.3 / 1.0 %), the bands of every year sum to the
hours of the year (2022: 8,760), the top hours of all years and the spread 1,471.75 CZK/MWh equal queries 05, 07 and 09.
Extreme hours in 2021 by month, 0 (January to August), 1, 78, 155, 343, show that the crisis started in autumn 2021.

## Page Náklad firmy (Company cost)

**Question:** how much did the company pay for electricity, and for what?
**User:** CFO (US-01, US-05). **Data:** load SIMULATED, prices and tariffs real. **Currency:** CZK.

### Cards (selected year)

| Card | Measure | Comparison line | Check 2022 |
|---|---|---|---|
| Total cost per year (m CZK) | `Celkový náklad na elektřinu (mil. Kč)` | previous year | 200.92 (2021: 95.72) |
| All-in price (CZK/kWh) | `Celková cena elektřiny (Kč/kWh)` | previous year | 7.19 (2021: 3.42) |
| Load profile premium (m CZK) | `Přirážka za diagram odběru (mil. Kč)` | premium per MWh | 11.92 (426.45 CZK/MWh) |

### What this means

In 2022 electricity cost the company 200.9 m CZK, 4.4× more than in 2020. 91 % of the cost was power from the market,
regulated charges hardly changed. The company uses most power in the daytime, when it is more expensive, and that cost
it 11.9 m CZK extra in 2022. In 2024 regulated charges rose to 31 m CZK (more expensive network and system services,
POZE back).

### Charts

| Visual | Type | Axis and values | Year slicer | Colours | Chart title (translated) |
|---|---|---|---|---|---|
| Monthly cost | stacked column, totals in m CZK | 12 months of the selected year, `Náklad na silovou elektřinu (Kč)` and `Regulované platby (Kč)` | yes | power amber, regulated grey | "Electricity cost by month (m CZK)" |
| Company price vs market average | clustered column | year, average market price and company price (CZK/MWh) | no | company amber, market grey | "Average market price vs company price (CZK/MWh)" |

Hovering over a month shows the split into power and regulated charges. The subtitle of the second chart explains that
the gap between the columns is the load profile premium.

**Why this way:** the first version of the monthly chart had 60 months and four cost parts. Regulated charges are about
1.5 m CZK a month against up to 31 m CZK of power, so three thin grey strips could not be told apart. I merged them into
one series and connected the chart to the year slicer, so the axis rescales to one year. The price chart compares years,
so the slicer does not filter it. Neither chart filters the cards (a click in a chart used to blank them).

**Check:** all 60 monthly totals equal `vw_monthly_cost` (power + regulated = total cost, difference 0.00 CZK), August
2022 32.3 m CZK, market and company prices 887/947 · 2,570/2,720 · 6,083/6,509 · 2,416/2,550 · 2,138/2,266 CZK/MWh.
Regulated charges 18.91 / 19.58 / 18.97 / 16.67 / 31.28 m CZK, so the title holds only for 2020–2022 and says so.

## Page Příčiny změny (Why it changed)

**Question:** why did the power cost change from the previous year? Because of the market price, volume, load profile,
or the exchange rate?
**User:** CFO (US-02, US-03). **Data:** volume and load profile effects are SIMULATED. **Currency:** CZK.
**Year slicer:** 2021–2024 (2020 has nothing to compare with).

**Method:** one CZK waterfall answers both questions. [ADR-004](decisions/ADR-004-cost-variance-split.md) splits the
EUR cost change into volume, market price and load profile. [ADR-006](decisions/ADR-006-fx-effect-split.md) values the
EUR change at the previous year's rate, and the rest is the exchange rate effect. Each EUR effect times the previous
year's effective rate gives the same effect in CZK. The steps live in the view `vw_cost_change_steps` with Czech names
(`step_name`) and an order (`step_order`).

### Cards (change from the previous year into the selected year)

| Card | Measure | Comparison line | Check 2022 |
|---|---|---|---|
| Power cost change (m CZK) | `Změna nákladu na silovou elektřinu (mil. Kč)` | vs previous year | +105.82 (+139.0 %) |
| Market price effect (m CZK) | `Vliv ceny na trhu (mil. Kč)` | market price last year and this year | +104.75 (2,570 and 6,083 CZK/MWh) |
| Exchange rate effect (m CZK) | `Vliv kurzu (mil. Kč)` | EUR/CZK rate last year and this year | −6.98 (25.65 and 24.56) |

The first card is power only (the total cost rose by 105.20 m CZK, regulated charges by −0.62 m CZK), so its title says
"Silová el." (power).

### What this means

In 2022 the cost rose by 105.8 m CZK and almost all of it came from the market price (+104.8 m). Daytime load, when
electricity is more expensive, added 8.2 m, the stronger koruna took off 7.0 m. In 2023–2024 the price fell and the cost
with it. The main risk is the market price. Buying in advance does not remove it, it only spreads it over a longer
period.

### Charts

| Visual | Type | Axis and values | Year slicer | Colours | Chart title (translated) |
|---|---|---|---|---|---|
| Waterfall | waterfall | volume, market price, load profile, EUR/CZK rate, total, in m CZK with 2 decimals | yes | increase amber, decrease teal, total grey | "What changed the power cost compared with the previous year (m CZK)" |
| Change by year | matrix | step × year 2021–2024, m CZK, grey total row | no | | "Cost change by year (m CZK)" |

A note under the waterfall says "Volume ≈ 0. The simulated load is the same every year (28 GWh / year)".

**Why this way:** the built-in waterfall colours bars only as increase, decrease and total, so a grey start bar
"Náklad minulý rok" (previous-year cost) is not possible (it would look like an amber increase from zero). I filter it
out of the visual, the waterfall shows only the change and the absolute cost is on the card. I kept the volume step
although it is almost zero, because otherwise the sum would not match and "did the volume change?" belongs to the
analysis. The second visual is a matrix, because four effects of very different size could not be read as columns and
the matrix gives exact numbers.

**Check:** 2022: −0.11 + 104.75 + 8.16 − 6.98 = +105.82 m CZK (query 11). The steps sum to the change in every year
within 2 CZK (rounding of the effective rate). Changes 2021–2024 +49.58 / +105.82 / −110.70 / −7.70 m CZK.

## Page Zajištění ceny (Hedging)

**Question:** how much of next year's volume should the company buy in advance at a fixed price?
**User:** energy purchasing and the CFO (US-04). **Data:** SIMULATED load, fixed price is an ASSUMPTION.
**Currency:** EUR. **Controls:** year slicer 2021–2024 and a slider "Podíl zajištění" (share hedged) 0–100 % in steps
of 25 %, default 50 %. Steps of 25 % are enough, because the cost is linear in the share and every position has a check
value in query 12.

### Cards (selected year and share)

| Card | Measure | Comparison line | Check 2022 at 50 % |
|---|---|---|---|
| Without hedging (m EUR) | `Náklad na silovou elektřinu bez zajištění (mil. EUR)` | whole volume at the market price | 7.40 |
| With hedging (m EUR) | `Náklad na silovou elektřinu se zajištěním - proxy (mil. EUR)` | vs without hedging | 5.35 (−2.05) |
| At the PXE price (m EUR) | `Náklad na silovou elektřinu se zajištěním - PXE (mil. EUR)` | vs without hedging | 7.04 (−0.36) |

2021 has no PXE price, so the PXE card shows "--", not the cost without hedging.

### What this means

Without hedging the company paid 7.40 m EUR in 2022. With half of the volume bought in advance it would have been
5.35 m, but in 2023 it would have paid 5.02 m instead of 2.97, because it fixed the expensive crisis price. Hedging does
not lower the cost, it spreads it over two years and gives the company time to prepare. At the PXE exchange price the
saving in 2022 would have been only 0.36 m.

### Method box

Next to the slider a box "Jak zajištění funguje" (how hedging works) explains: during the year the company gradually
buys part of next year's electricity at a fixed price, the same amount for every hour, and pays the rest at the market
price. The fixed price is the average market price of the previous year (an assumption that matches gradual buying).
The PXE card shows, for comparison, the last price of the yearly product on the Prague exchange at the end of the
previous year. The box also explains why 2020 and PXE 2021 are missing.

### Chart

| Visual | Type | Axis and values | Year slicer / slider | Colours | Chart title (translated) |
|---|---|---|---|---|---|
| Cost by year | line, linear, markers, axis from 0 | year 2021–2024, cost without and with hedging (m EUR) | slicer no, slider yes | without hedging grey, with hedging amber | "Cost without and with hedging by year (m EUR)" |

**Why this way:** I tried a chart of the cost by share, but the cost is linear in the share, so it only repeated the
cards. Clustered columns looked the same as the chart on the Náklad firmy page. A ribbon chart stacks the two
alternatives on each other, so its height means nothing. The line chart shows the main point: the lines cross between
2022 and 2023, because hedging moves the crisis by one year. I dropped a card with the 2021–2024 total, because a sum
over years hides that shift.

**Check** (query 12, m EUR, years 2021–2024): at 50 % with hedging 2.04 / 5.35 / 5.02 / 2.75, PXE – / 7.04 / 4.95 /
2.72. At 100 % 1.11 / 3.30 / 7.07 / 2.97, PXE – / 6.69 / 6.92 / 2.92. At 0 % with hedging = without hedging (2022:
7,399,949.24 EUR). Title: result of a full hedge 2022 −4.10 and 2023 +4.10 m EUR.

## Sharing the report

- [docs/report/energy_crisis_cost_analysis_report_final.pdf](report/energy_crisis_cost_analysis_report_final.pdf):
  export of all 6 pages (year slicers on 2022, slider at 50 %).
- [docs/screenshots/report/](screenshots/report/): page images `report_01_o_projektu.png` to
  `report_06_zajisteni_ceny.png`, rendered from the PDF.
- [docs/report/energy_crisis_cost_analysis_demo_1920.mp4](report/energy_crisis_cost_analysis_demo_1920.mp4): screen
  recording of the published report (2 min 15 s, 1920 × 1080, 7.2 MB, under the 10 MB limit for a video in a GitHub
  README).
- The public link (Publish to web, no sign-in) comes from a Power BI Pro trial. It works only while I hold a Pro licence
  (the trial ends around 2027-01-22). The PDF, images and video are the permanent way to show the report. The `.pbix`
  with the imported data will be attached to a GitHub Release (it is not in git).

## Data sources for Power BI

**Source = SQL Server database `EnergyCrisisCostAnalysis`, Import mode.** Power BI never reads the CSV files. The
database is the single source of truth: it has the keys, the data quality tests and the views whose numbers I checked
in SQL. The "gold" layer is therefore the set of views below, not a folder of files. After the pipeline runs, one
Refresh in Power BI updates the report.

| Model table | Source in SQL | Grain (1 row =) | Rows | Used on |
|---|---|---|---|---|
| `dim_date` | table `dim_date` + DAX column `month_start` | 1 day | 1,827 | all pages (year slicer, month axis) |
| `dim_hour` | table `dim_hour` | 1 hour of the day | 25 | Trh (peak, top hours) |
| `vw_hourly_cost` | view: price EUR and CZK, rate, load, cost EUR and CZK, price band | 1 hour | 43,848 | Shrnutí, Trh, Náklad firmy |
| `vw_monthly_cost` | view from query 08: power, regulated, fixed charges, POZE, total | 1 month | 60 | Shrnutí, Náklad firmy |
| `vw_cost_change_steps` | view from queries 10 and 11: previous-year cost and four change steps | 1 year and 1 step | 20 | Příčiny změny |
| `vw_yearly_hedging` | view from query 12: cost, hedging difference at the proxy price and at the PXE price | 1 year | 4 | Zajištění ceny |
| `Podíl zajištění` | what-if parameter (GENERATESERIES 0–1 step 0.25), no relationship | 1 share | 5 | Zajištění ceny |

- Relationships: `dim_date` 1 : many to every fact on `date_key`, `dim_hour` 1 : many to the hourly fact on
  `hour_of_day`, always single direction (5 relationships, none between facts). Monthly and yearly views carry the
  `date_key` of the first day of their month or year, so the same year slicer filters them. Several facts sharing the
  same dimensions is a star schema with more than one fact (galaxy).
- Auto date/time is off and `dim_date` is marked as the date table.
- Prices are never stored as averages. Every price in the report is a DAX ratio of two sums (cost / volume), so it
  stays correct for any filter. Columns whose sum means nothing (prices, rates, year, month) are set to "Do not
  summarize".
- Logic over validity periods (regulated tariffs) and the year-over-year splits stay in SQL, where I tested them. DAX
  does sums, ratios and the hedged cost for the slider.
- `vw_energy_prices_czk` and `vw_daily_summary` are not imported. The hourly view covers both at a finer grain, and two
  tables with the same content could give two different answers.
