# ADR-001: EUR/CZK fill rule for weekends and holidays

- Date: 2026-09-23
- Status: accepted

## Context

ČNB publishes an EUR/CZK rate only on working days (1,508 rows in `data/bronze/cnb/cnb_fx_*.txt`
for 2019–2024, verified 2026-09-23). `fact_energy_prices` has a row for every hour of every
calendar day, including weekends and holidays (43,848 rows, 1,827 days). To join the two tables
1:1 by date, `fact_fx` needs a rate for every calendar day, not just ČNB working days.

Also: 1 January 2020 has no ČNB rate at all — the closest preceding rate is from 31 December 2019.

## Options considered

1. Leave gaps as NULL and handle them at query time.
2. Forward-fill: a day with no published rate gets the last previously published rate.
3. Interpolate between the surrounding published rates.

## Decision

Option 2, forward-fill. A weekend/holiday keeps the rate from the last preceding working day.
This matches how the rate is actually used in practice — nobody re-prices contracts over a
weekend, the last published rate stays the reference rate until the next one is published.
Interpolation (option 3) would invent a rate that was never real on any market.

## Consequences

- `fact_fx` (silver, `python/02_transform.py`, function `fill_fx_gaps()`) has one row per
  calendar day of the project (2020-01-01 to 2024-12-31), never NULL.
- Two extra columns record the fill: `is_actual_rate` (1 = ČNB published a rate that day,
  0 = carried forward) and `source_date` (the date the value actually comes from — always
  populated, even when `is_actual_rate = 1`, to avoid NULL handling in queries).
- Verified 2026-09-23: 1 Jan 2020 correctly fills from 31 Dec 2019
  (`rate_czk_per_eur = 25.41`, `is_actual_rate = 0`, `source_date = 2019-12-31`).
- Any DQ check or query that needs to know whether a rate is real must filter or group on
  `is_actual_rate`, not assume every row is an actual ČNB quote.
