# Project brief — P1 Energy Crisis Cost Analysis

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
| OTE-ČR day-ahead market | price EUR/MWh, volume | hourly | to download |
| ČNB exchange rates | EUR/CZK | ČNB working days | source verified |
| ČNB 2-week repo rate | policy interest rate, context for CZK and cost of money | validity periods | source verified |
| ERÚ price decisions | distribution, system services, POZE, tax | validity periods | to collect into `config/` |
| Own generator | company load profile | hourly | SIMULATED |

### Source details
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
