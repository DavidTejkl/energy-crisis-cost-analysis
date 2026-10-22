# ADR-006: EUR/CZK effect split — commodity and exchange rate effect
- Date: 2026-10-22
- Status: accepted

## Context
Business question 3 asks how the EUR/CZK rate affected the cost in CZK. OTE prices are in EUR/MWh,
the company pays in CZK, and the CZK price is computed from the ČNB rate of the same day (ADR-001,
view `vw_energy_prices_czk`). The cost variance split of ADR-004 is in EUR on purpose, so the rate
needs its own split. ROADMAP 2.8 requires that the effects sum to the total change and that the
direction is stated from the data, not assumed.

Definitions (per year, from hourly data):
- `C_eur` = power cost in EUR = `SUM(load_h × price_eur_h)`
- `C_czk` = power cost in CZK = `SUM(load_h × price_czk_h)`
- `R` = effective rate = `C_czk / C_eur` — the rate weighted by cost: days with a high EUR cost count
  more than days with a low one. A simple yearly average of the rate would ignore that.

So `C_czk = C_eur × R`.

## Options considered
1. Yearly simple average rate × EUR cost — does not reproduce the real CZK cost, so the effects would
   not sum to the total change. Rejected.
2. Day-by-day split (EUR cost and rate change on every day) — exact, but hard to explain.
3. Split through the effective rate `R` with a fixed order: commodity (EUR cost), then exchange rate.
   Same structure as ADR-004.

## Decision
Option 3. Year-over-year change from year 0 to year 1:

| Effect | Formula |
|---|---|
| Commodity | `(C_eur1 − C_eur0) × R0` |
| Exchange rate | `C_eur1 × (R1 − R0)` |

The two effects sum exactly to `C_czk1 − C_czk0`:
`(C_eur1 − C_eur0) × R0 + C_eur1 × (R1 − R0) = C_eur1 × R1 − C_eur0 × R0`.

A negative exchange rate effect means the koruna strengthened (fewer CZK per EUR) and lowered the CZK
cost. The commodity effect is the EUR change of ADR-004 (volume + market price + load profile) valued
at the previous year's rate.

## Consequences
- The order matters in the same way as in ADR-004: the EUR change is valued at the old rate, the rate
  change at the new EUR cost. It is stated in the query header and in findings.
- The split covers the power (commodity) cost only. Regulated components (ADR-005) are set in CZK and
  are not affected by the rate.
- `R` is a DECIMAL division result rounded to 6 decimals, so the check difference is a few CZK, not
  exactly 0. This is rounding, not a gap in the method.
- The load profile is SIMULATED, so the size of both effects in CZK depends on the simulated volume;
  the rates and prices are real data (FACT).
