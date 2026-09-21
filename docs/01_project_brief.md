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
| ČNB exchange rates | EUR/CZK | ČNB working days | to download |
| ERÚ price decisions | distribution, system services, POZE, tax | validity periods | to collect into `config/` |
| Own generator | company load profile | hourly | SIMULATED |
| ČNB PRIBOR, Yahoo CEZ.PR | context | daily | pending decision — see STATUS |

## Scope
- In: pipeline, star schema, DQ tests, incremental load, analysis queries, 4-page Power BI, README CZ/EN.
- Out: Kaggle data, invoice PDF parsing, Airflow, Docker, dbt, Spark, cloud DB.
