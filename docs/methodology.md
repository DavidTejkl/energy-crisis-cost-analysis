# Methodology — simulated load profile

Status: SIMULATED. Real hourly load curves of companies are trade secrets, so the model company from the
[project brief](01_project_brief.md) gets a generated profile. Every row carries `is_simulated = 1`.
Any number that depends on this profile (volumes, CZK costs, load-shape effect) is labelled SIMULATED.

Script: `python/04_generate_load_profile.py` · constants: `python/config.py` · output: `data/silver/fact_load.csv`

## Idea: three layers

A continuous high-temperature process does not stop at night or at weekends, but the operations around
it do. The profile is the sum of three layers. Each layer is either running (1) or stopped (0) in a given
hour and has a fixed relative power level (weight).

| Layer | What runs | When | Weight |
|-------|-----------|------|--------|
| Base | kilns, fans, dedusting, blowers | every hour of the year | 1.3 |
| Shift | crushing, milling, screening, packing | Sunday 22:00 to Friday 22:00 (three shifts) | 2.1 |
| Shift, winter (Dec–Feb) | same | Monday to Friday 06:00–22:00 (two shifts) | 2.1 |
| Day | dispatch, offices | Monday to Friday 06:00–14:00 | 0.6 |

`hour_of_day` is the sequential delivery hour: hour 7 = 06:00–07:00, hour 23 = 22:00–23:00.

Steps:
1. Hour list = the OTE price hours (43,848 rows), so DST days have 23 or 25 hours exactly like the prices.
2. Weight of an hour = sum of the weights of the layers that run in that hour.
3. Random variation ±3 % per hour (uniform, fixed seed 42) so the curve does not look artificial.
   The fixed seed makes every run produce the same file.
4. One scale factor for the whole period, chosen so that the average year is 28,000 MWh. Each year keeps
   its own calendar (leap year, number of weekdays), so yearly totals differ slightly instead of being
   forced to the same value.

## Assumptions

| Item | Value | Basis |
|------|-------|-------|
| Yearly consumption | 28 GWh | ASSUMPTION. Order of magnitude for a kiln plant producing a few hundred thousand tonnes per year: electricity use for lime production is 40–140 kWh/t depending on kiln type and milling ([IPCC AR4, 7.4.5.2](https://archive.ipcc.ch/publications_and_data/ar4/wg3/en/ch7s7-4-5-2.html)), so 28 GWh is within the range for such a plant |
| Layer weights | 1.3 / 2.1 / 0.6 | ASSUMPTION. Kilns use comparatively little electricity (most of the energy is fuel), crushing and milling use most of it |
| Shift pattern | as in the table | ASSUMPTION based on a typical continuous plant |
| Reserved capacity | 5 MW | ASSUMPTION. Highest hourly load of the profile is 4.665 MWh → about 7 % headroom |

## Simplifications (not modelled)

- Planned shutdowns and maintenance stops.
- Public holidays are treated as normal weekdays (`dim_date` has no holiday flag yet).
- DST Sundays: the shift starts by the sequential hour, so on the two DST Sundays per year the shift
  start is shifted by one clock hour.
- The company does not react to prices: volume and shape are the same in every year. Changes in cost
  therefore come from prices, not from the company's behaviour.

## Checks (run 2026-10-17)

- 43,848 rows, 1,827 days; two runs give byte-identical files (same SHA-256).
- Yearly totals: 28,050.9 / 27,993.7 / 27,953.4 / 27,948.9 / 28,053.0 MWh (2020–2024).
- Hourly load 1.428–4.665 MWh. Saturday average 1.47 MWh (base layer only).
- Load-weighted price minus simple average price is positive in every year (load-shape effect is not
  zero by construction), see ADR-004.
