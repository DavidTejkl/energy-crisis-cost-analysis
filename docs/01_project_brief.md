# Project brief — P1 Energy Crisis Cost Analysis

**English** · [Čeština](01_project_brief_cz.md)

## SCENARIO (fictional, stated once)
- Model company: energy-intensive Czech firm with a three-shift operation and lower weekend load.
- Load profile: SIMULATED hourly profile (`is_simulated = 1`) — real load curves are trade secrets.
  Method documented in `docs/methodology.md`.
- Stakeholders: CFO (cost and budget risk), energy purchasing (fix now or wait?).
- Decision: how much of next year's volume to fix in advance.

## Business questions
1. What did electricity really cost per kWh (all-in: power + regulated components)?
2. Why did cost change year over year — market price, volume, or load shape?
3. How did the EUR/CZK rate affect the CZK cost? (direction to be verified on data)
4. Could the loss have been hedged — cost at 0 / 25 / 50 / 75 / 100 % fixed volume?

## Data sources (2020–2024)
| Source | What | Granularity | Status |
|--------|------|-------------|--------|
| OTE-ČR day-ahead market | price EUR/MWh, volume | hourly | source verified |
| ČNB exchange rates | EUR/CZK | ČNB working days | source verified |
| ČNB 2-week repo rate | policy interest rate, context for CZK and cost of money | validity periods | source verified |
| ERÚ price decisions | distribution, system services, POZE, tax | validity periods | to collect into `config/` |
| Own generator | company load profile | hourly | SIMULATED |

### Source details
**OTE-ČR day-ahead market** — yearly market report, one zip per year:
`https://www.ote-cr.cz/pubweb/attachments/62_162/YYYY/Rocni_zprava_o_trhu_YYYY_V2.zip`
(listed on `https://www.ote-cr.cz/cs/statistika/rocni-zprava?date=YYYY-01-01`)
- V2 = final monthly settlement (V0 daily, V1 monthly evaluation) → use V2.
- The zip holds one Excel file: `.xls` for 2020–2023, `.xlsx` for 2024 → reading needs both
  `xlrd` and `openpyxl`.
- Sheet `DT ČR`, header on row 6 (`header=5`), hourly block in the left columns; the same sheet
  has daily, weekly and monthly summaries further right → select columns by name.
- Columns: `Den` (date), `Hodina` (1–24, 1–23 or 1–25), `Marginální cena ČR (EUR/MWh)` = price,
  `Množství - vč. Exp a Imp (MWh)` = volume. `Saldo DT (MWh)` exists from 2021 only → columns
  shift, never select by position. 2024 header names contain line breaks → normalise whitespace.
- Also contains `Marginální cena ČR (Kč/MWh)` and `Kurz Kč/EUR (ČNB)`: OTE labels the CZK price as
  informative only → not used; CZK is computed from the ČNB source (ADR-001), OTE CZK serves as a cross-check.
- `Hodina` is the sequential hour of the delivery day, not the clock hour: spring DST day has
  hours 1–23, autumn DST day has hours 1–25.
- Test download 2026-09-22, all five years: 43,848 hourly rows in 1,827 days
  (8,784 / 8,760 / 8,760 / 8,760 / 8,784), one 23-hour and one 25-hour day per year on the last
  Sunday of March / October, 0 duplicate day+hour, 0 missing prices, 609 negative-price hours
  (119 / 33 / 8 / 134 / 315), price range −138.75 to 871.00 EUR/MWh.

**ČNB EUR/CZK** — one text file per year:
`https://www.cnb.cz/cs/financni-trhy/devizovy-trh/kurzy-devizoveho-trhu/kurzy-devizoveho-trhu/rok.txt?rok=YYYY`
- Pipe-separated, date `DD.MM.YYYY`, decimal comma, value = CZK per 1 EUR (column `1 EUR`).
- Working days only: 1,257 rates in 2020–2024. 2020 starts on 2 January, so the end of 2019 is
  needed to fill 1 January 2020.
- The 2022 file repeats the header on 2 March 2022 (RUB dropped, columns shift) → find EUR by
  column name, skip repeated header rows.

**ČNB 2-week repo rate** — full history in one file:
`https://www.cnb.cz/cs/casto-kladene-dotazy/.galleries/vyvoj_repo_historie.txt`
- Columns `PLATNA_OD|CNB_REPO_SAZBA_V_%`, date `YYYYMMDD`, decimal comma, UTF-8 with BOM.
- 21 changes in 2020–2024; the rate valid on 1 January 2020 was set on 3 May 2019.

**Not used**
- PRIBOR: ČNB publishes it with the consent of the administrator (CFBF) for internal use only;
  redistribution of the rates or data derived from them is prohibited → replaced by the repo rate.
- ČEZ share price (CEZ.PR): context about the producer, not the buying company; no official
  download source → backlog.

## Scope
- In: pipeline, star schema, DQ tests, incremental load, analysis queries, 4-page Power BI, README CZ/EN.
- Out: Kaggle data, invoice PDF parsing, Airflow, Docker, dbt, Spark, cloud DB.
