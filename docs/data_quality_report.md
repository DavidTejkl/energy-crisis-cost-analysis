# Data quality report

Database `EnergyCrisisCostAnalysis`, period 2020-01-01 to 2024-12-31.
All checks are in `sql/91_dq_tests.sql` and were run via
`sqlcmd -S localhost -E -C -b -f 65001 -i sql/91_dq_tests.sql` (exit 0).

## Run 1 — 2026-09-28 (after the first load, step 0.8)

Row counts at the time of the run: `dim_date` 1,827 · `dim_hour` 25 · `repo_rate` 22 ·
`fact_energy_prices` 43,848 · `fact_fx` 1,827.

**Summary:** 27 checks, 0 data errors. Four results are flagged for attention but are valid data
(negative prices, DST days, the extreme hours in P12 and FX jumps in F07); they are documented below and
must be handled correctly by the analysis, not removed.

### fact_energy_prices (grain: delivery day + hour of the day)

| ID | Check | Result (number) | Severity | Decision | Status |
|----|-------|-----------------|----------|----------|--------|
| P01 | Rows per year | 8,784 / 8,760 / 8,760 / 8,760 / 8,784 = 43,848 (expected equal) | High | — | PASS |
| P02 | Days by hour count | 23 h: 5 · 24 h: 1,817 · 25 h: 5 (1,827 days) | High | — | PASS |
| P03 | DST days on the last Sunday of March (23 h) / October (25 h) | 10 of 10 OK, e.g. 2022-03-27 (23 h), 2022-10-30 (25 h) | High | DST days are valid; hour 25 exists only on autumn DST days | PASS |
| P04 | Days with gaps in hour numbering (first hour ≠ 1 or last hour ≠ hour count) | 0 | High | — | PASS |
| P05 | Calendar days without any price row | 0 | High | — | PASS |
| P06 | Duplicate `date_key + hour_of_day` | 0 (also enforced by PK) | High | — | PASS |
| P07 | NULL price / NULL volume | 0 / 0 | High | — | PASS |
| P08 | Ranges: price outside −500 … 5,000 EUR/MWh; volume ≤ 0 | price −138.75 … 871.00, 0 out of range; volume 762.600 … 5,447.800, 0 not positive | High | No CHECK price > 0 in the DDL | PASS |
| P09 | Negative / zero price hours per year | negative 119 / 33 / 8 / 134 / 315 = 609 (equal to source); zero 15 / 1 / 3 / 22 / 47 | Low | Valid market outcome, kept as is | PASS (flagged) |
| P10 | Orphan `date_key` / `hour_of_day` | 0 / 0 (also enforced by FKs) | High | — | PASS |
| P11 | Price per year: min / avg / max / stdev (EUR/MWh) | 2020: −65.00 / 33.62 / 125.10 / 16.07 · 2021: −36.26 / 100.66 / 620.00 / 71.69 · 2022: −22.45 / 247.43 / 871.00 / 137.52 · 2023: −68.54 / 100.79 / 444.02 / 43.89 · 2024: −138.75 / 85.11 / 844.63 / 51.72 | Low | Simple hourly average, for plausibility only; cost uses the volume-weighted price | PASS |
| P12 | Top 5 hours by price | 2022-08-29 h20 871.00 · 2022-08-29 h21 860.89 · 2022-08-30 h21 853.69 · 2022-08-24 h20 850.00 · 2024-12-12 h18 844.63 | Med | Kept (valid values, see "Verification of flagged values") | PASS (flagged) |

### fact_fx (grain: calendar day, forward-filled on non-ČNB days, ADR-001)

| ID | Check | Result (number) | Severity | Decision | Status |
|----|-------|-----------------|----------|----------|--------|
| F01 | Rows / actual / filled | 1,827 / 1,257 / 570 (1,257 equal to source) | High | — | PASS |
| F02 | Calendar days without a rate | 0 | High | — | PASS |
| F03 | Fill rule: actual rate with another source day / filled rate not from an earlier day / fill older than 4 days | 0 / 0 / 0; longest fill 4 days | High | ADR-001 | PASS |
| F04 | Filled days by weekday (Mon … Sun) | 14 / 6 / 9 / 6 / 13 / 261 / 261 → 522 weekend days + 48 weekday public holidays | Low | — | PASS |
| F05 | Actual ČNB rate on a weekend | 0 | Med | — | PASS |
| F06 | Rate per year min / avg / max (CZK per EUR), NULL, outside 20 … 30 | 2020: 24.795 / 26.451 / 27.810 · 2021: 24.860 / 25.649 / 26.420 · 2022: 24.115 / 24.563 / 25.865 · 2023: 23.275 / 24.006 / 24.725 · 2024: 24.480 / 25.118 / 25.460; NULL 0, out of band 0 | Med | Relevant for business question 3 (CZK stronger in 2022–2023 than in 2020) | PASS |
| F07 | Largest day-to-day change of actual rates (parsing-error threshold 3 %) | 2020-03-16 +3.53 % (26.040 → 26.960) · 2022-02-24 +2.41 % · 2022-03-01 +1.88 % | Low | Value equals the ČNB source → real market move, kept. Dates coincide with the COVID market shock and the invasion of Ukraine (coincidence in time, not proven cause) | PASS (flagged) |
| F08 | Rates around the repeated header in the ČNB 2022 file (2022-02-28 … 03-04) | 5 actual rates 24.995 / 25.465 / 25.865 / 25.645 / 25.735, none lost | Med | Header row filtered in `02_transform.py` | PASS |

### repo_rate (grain: one validity period)

| ID | Check | Result (number) | Severity | Decision | Status |
|----|-------|-----------------|----------|----------|--------|
| R01 | Periods, span, rate range | 22 periods, 2019-05-03 … 2024-12-31, 0.25 … 7.00 % | Med | First period starts before 2020 (rate valid on 2020-01-01) | PASS |
| R02 | Gaps / overlaps between consecutive periods | 0 / 0 | High | — | PASS |
| R03 | Calendar days with no rate / with two rates | 0 / 0 | High | — | PASS |

### dim_date and dim_hour

| ID | Check | Result (number) | Severity | Decision | Status |
|----|-------|-----------------|----------|----------|--------|
| D01 | `dim_date` span | 1,827 rows, 2020-01-01 … 2024-12-31 = 1,827 calendar days | High | — | PASS |
| D02 | Derived columns vs `full_date`: key / year-month-day / quarter / ISO week / weekend flag | 0 / 0 / 0 / 0 / 0 wrong | High | — | PASS |
| D03 | `weekday_num` (1 = Monday … 7 = Sunday) vs a known Monday 2020-01-06 | 0 wrong | Med | — | PASS |
| D04 | `dim_hour` labels | noc 10 h (1–6, 22–25) · ráno 4 (7–10) · dopoledne 2 (11–12) · odpoledne 6 (13–18) · večer 3 (19–21) = 25 | Low | Hour 25 labelled night (autumn DST extra hour) | PASS |

### Verification of flagged values
Decision (2026-09-28): negative and zero prices (P09), the highest prices (P12) and the FX jumps (F07) are
valid data and stay unchanged. Outliers are verified against the source, not removed.

- **Negative prices are allowed by the market rules.** The Czech day-ahead market is part of the European
  Single Day-Ahead Coupling (SDAC), whose harmonised minimum clearing price was −500 EUR/MWh during 2020–2024
  (lowered to −600 EUR/MWh from 28 May 2026, outside the scope):
  [OTE news](https://www.ote-cr.cz/en/about-ote/ote-news/harmonised-minimum-clearing-price-for-sdac-to-be-set-to-600-eur-mwh-starting-from-the-28th-may-2026-trading-date).
  The lowest value, −138.75 EUR/MWh on 2024-05-12 hour 14, is present in the raw OTE file
  (`Rocni_zprava_o_trhu_2024_V2.xlsx`, sheet `DT ČR`) together with the OTE CZK value −3,459.731 CZK/MWh.
- **Pattern of non-positive prices (query output, 2020–2024):** hours 13–16 hold 309 of the 609 negative hours;
  April–August 481; weekends 476 of 12,528 hours (3.8 %) vs working days 133 of 31,320 (0.4 %).
  ASSUMPTION: midday solar surplus at low demand; 2024-05-01 (public holiday on a Wednesday) behaves like a weekend.
- **2024-12-12 hour 18 (17:00–18:00), 844.63 EUR/MWh.** Raw OTE file checked in Excel
  (`docs/screenshots/bronze_ote_2024-12-12_price_peak_excel.png`): the price rises and falls smoothly over the
  evening (hours 14–21: 380.01 → 448.48 → 601.61 → 795.12 → 844.63 → 670.00 → 547.94 → 294.48), and the file's own
  derived columns agree (844.63 × 25.065 = 21,170.65 CZK/MWh; 844.63 × 4,935.6 MWh = 4,168,755.83 EUR).
  FACT (external source): the same hour was the peak of a "Dunkelflaute" (cold, almost no wind or solar) in
  Germany, day-ahead price 936 EUR/MWh between 17:00 and 18:00
  ([Clean Energy Wire](https://www.cleanenergywire.org/news/short-term-power-prices-spike-amid-new-dunkelflaute-germany-most-customers-unaffected)).
  The Czech and German markets are coupled in SDAC, with limited cross-border capacity.
- **August 2022 (871.00 EUR/MWh on 2022-08-29 hour 20)** is the peak of the energy crisis that this project measures.
- **F07 FX jumps** equal the ČNB source values; the dates coincide with the COVID market shock (2020-03-16) and
  the invasion of Ukraine (2022-02-24) — coincidence in time, not proven cause.

### What the analysis must respect
- Sum or weight over the rows that exist; never multiply "days × 24" (DST days have 23 or 25 hours).
- Negative and zero prices are part of the market; averages and costs include them.
- `fact_fx` has a rate for every day; `is_actual_rate = 0` marks the 570 filled days (ADR-001).
- The repo rate joins to days by range (`full_date BETWEEN valid_from AND valid_to`), exactly one match per day (R03).
