# ADR-004: Cost variance split — volume, market price and load profile effect
- Date: 2026-10-14
- Status: accepted

## Context
Business question 2 asks why the electricity cost changed year over year: because of the market price,
the volume, or the load profile (in which hours the company takes its electricity).

The first draft of the split worked with yearly volume and a yearly average price only. Hourly
information was lost, so the load profile effect was 0 by construction and the question could not be
answered. ROADMAP 2.7 requires that the effects sum exactly to the total change and that the load
profile effect is not zero by construction.

Definitions (per year, from hourly data):
- `V` = company volume in MWh = `SUM(volume_h)`
- `C` = power cost = `SUM(volume_h × price_h)`
- `Pw` = volume-weighted price the company paid = `C / V`
- `Pb` = market base price = simple average of all hourly prices (a flat profile, same as the
  base load proxy in ADR-003)
- `S` = load profile premium = `Pw − Pb`. Positive: the company takes more in expensive hours.
  Negative: more in cheap hours. A flat profile has `S = 0`.

So `C = V × Pw = V × (Pb + S)`.

## Options considered
1. Volume and average price only — load profile effect always 0, rejected.
2. Hour-by-hour split (volume and price change in every hour) — exact, but hard to explain and the
   result depends on 8,760 small terms.
3. Split through the load profile premium `S` with a fixed order: volume, then market price,
   then load profile.

## Decision
Option 3. Year-over-year change from year 0 to year 1:

| Effect | Formula |
|---|---|
| Volume | `(V1 − V0) × Pw0` |
| Market price | `V1 × (Pb1 − Pb0)` |
| Load profile | `V1 × (S1 − S0)` |

The three effects sum exactly to `C1 − C0`, with no residual:
`(V1 − V0) × Pw0 + V1 × (Pw1 − Pw0) = V1 × Pw1 − V0 × Pw0`, and `Pw1 − Pw0 = (Pb1 − Pb0) + (S1 − S0)`.

Worked example (one day, two hours):

| Hour | Price (EUR/MWh) | Volume (MWh) |
|---|---|---|
| night | 50 | 1 |
| day | 150 | 3 |

`Pb = (50 + 150) / 2 = 100`, `Pw = (1 × 50 + 3 × 150) / 4 = 125`, `S = 125 − 100 = +25`:
the company pays 25 EUR/MWh more than the market average, because it takes most of its volume
in the expensive hour.

The split is calculated in EUR, so the exchange rate does not enter it. The EUR/CZK effect is split
separately in query 11 (ROADMAP 2.8). It covers the power (commodity) cost only; regulated components
are part of the all-in price (ADR-005).

## Consequences
- The order matters: volume is valued at the old price, the price change at the new volume. Another
  order gives slightly different effects. The order is fixed here and stated in the query header and
  in findings.
- The load profile effect changes even when the company's profile stays the same, if the market's
  hourly price pattern changes (for example cheaper midday hours with more solar). This is intended:
  it measures how the company's profile fits the market's price pattern.
- The company's load profile is SIMULATED (`is_simulated = 1`). The volume effect and the load
  profile effect therefore reflect the generator's assumptions (`docs/methodology.md`), not a real
  company. The market price effect uses real OTE prices (FACT). Findings must state this.
- Checks for query 10: the three effects sum to `C1 − C0` for every pair of years, and the load
  profile effect is not 0 for the simulated profile.
