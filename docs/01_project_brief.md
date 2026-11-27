# Project brief: Energy Crisis Cost Analysis

**English** · [Čeština](01_project_brief_cz.md)

## Scenario (fictional company)

- **The company:** an energy-intensive Czech manufacturer with a continuous process that runs 24 hours a day
  all year. Production lines work in three shifts from Sunday 22:00 to Friday 22:00 (two shifts in winter), dispatch
  and offices work the weekday morning shift. It uses about 28 GWh of electricity a year (ASSUMPTION).
- **Grid connection:** ČEZ Distribuce area, high voltage (VN, 22 kV). All prices are without VAT
  ([ADR-005](decisions/ADR-005-all-in-price-scope.md)).
- **Load profile:** a simulated hourly profile (`is_simulated = 1`), because companies do not publish their real load
  curves. How it is generated: [methodology.md](methodology.md).
- **Who uses the analysis:** the CFO, who is responsible for the cost and the budget risk, and energy purchasing,
  who decides whether to fix the price now or wait.
- **Decision to support:** how much of next year's consumption to buy in advance at a fixed price.

## Business questions

1. What did electricity really cost per kWh, including the regulated charges (all-in price)?
2. Why did the cost change from year to year: because of the market price, the volume, or the shape of the load?
3. How did the EUR/CZK exchange rate affect the cost in CZK?
4. Could the loss have been hedged? What would the cost be with 0, 25, 50, 75 or 100 % of the volume fixed in advance?

## Data sources (2020–2024)

| Source | What | Granularity | How it gets into the project |
|---|---|---|---|
| OTE-ČR day-ahead market | price EUR/MWh, volume | hourly | downloaded by `python/01_extract.py` |
| ČNB exchange rates | EUR/CZK | ČNB working days | downloaded by `python/01_extract.py` |
| ČNB 2-week repo rate | policy interest rate, context for the koruna and the cost of money | validity periods | downloaded, loaded, not used in the analysis |
| ERÚ price decisions | distribution, system services, POZE, electricity tax | validity periods | typed from the official decisions into `config/tariffs.csv` |
| PXE annual reports | year-end price of the yearly base load product | yearly | quoted in [ADR-003](decisions/ADR-003-forward-price-proxy.md) |
| Own generator | load profile of the company | hourly | SIMULATED by `python/04_generate_load_profile.py` |

### Source details

**OTE-ČR day-ahead market:** a yearly market report, one zip file per year:
`https://www.ote-cr.cz/pubweb/attachments/62_162/YYYY/Rocni_zprava_o_trhu_YYYY_V2.zip`
(listed on `https://www.ote-cr.cz/cs/statistika/rocni-zprava?date=YYYY-01-01`)

- The report comes in three versions: V0 (daily), V1 (monthly evaluation) and V2 (final monthly settlement).
  The project uses V2.
- Each zip holds one Excel file: `.xls` for 2020–2023 and `.xlsx` for 2024, so reading needs both `xlrd` and
  `openpyxl`.
- The data is on the sheet `DT ČR` with the header on row 6 (`header=5`). The hourly data is in the left columns, and
  the same sheet also holds daily, weekly and monthly summaries further right, so columns are selected by name.
- Columns used: `Den` (date), `Hodina` (1–24, 1–23 or 1–25), `Marginální cena ČR (EUR/MWh)` (price) and
  `Množství - vč. Exp a Imp (MWh)` (volume). The column `Saldo DT (MWh)` exists only from 2021, so the columns shift
  between years and are never selected by position. The 2024 headers contain line breaks, so whitespace is normalised.
- The file also contains `Marginální cena ČR (Kč/MWh)` and `Kurz Kč/EUR (ČNB)`. OTE labels the CZK price as
  informative only, so it is not used. The CZK price is computed with the ČNB rate (ADR-001) and the OTE value serves
  as a cross-check.
- `Hodina` is the sequential hour of the delivery day, not the clock time. On the spring daylight saving day it runs
  from 1 to 23, on the autumn day from 1 to 25.
- Test download on 2026-09-22, all five years: 43,848 hourly rows in 1,827 days (8,784 / 8,760 / 8,760 / 8,760 /
  8,784). Every year has one 23-hour day and one 25-hour day, on the last Sunday of March and of October. No duplicate
  day and hour, no missing price, 609 hours with a negative price (119 / 33 / 8 / 134 / 315), prices from −138.75 to
  871.00 EUR/MWh.

**ČNB EUR/CZK:** one text file per year:
`https://www.cnb.cz/cs/financni-trhy/devizovy-trh/kurzy-devizoveho-trhu/kurzy-devizoveho-trhu/rok.txt?rok=YYYY`

- Values are separated by `|`, the date is `DD.MM.YYYY`, decimals use a comma and the value is CZK for 1 EUR
  (column `1 EUR`).
- Rates exist only for ČNB working days: 1,257 rates in 2020–2024. The 2020 file starts on 2 January, so the end of
  2019 is downloaded too, to fill 1 January 2020.
- The 2022 file repeats its header on 2 March 2022, when the rouble was dropped and the columns shifted. EUR is
  therefore found by column name and repeated header rows are skipped.

**ČNB 2-week repo rate:** the full history in one file:
`https://www.cnb.cz/cs/casto-kladene-dotazy/.galleries/vyvoj_repo_historie.txt`

- Columns `PLATNA_OD|CNB_REPO_SAZBA_V_%`, date `YYYYMMDD`, decimal comma, UTF-8 with BOM.
- 21 changes in 2020–2024. The rate valid on 1 January 2020 was set on 3 May 2019.

**Not used**

- PRIBOR: ČNB publishes it with the consent of its administrator (CFBF) for internal use only, and passing on the
  rates or data derived from them is not allowed. The repo rate is used instead
  ([ADR-002](decisions/ADR-002-interest-rate-source.md)).
- ČEZ share price (CEZ.PR): it says something about the producer, not about the company that buys the electricity,
  and there is no official download source. Left in the backlog.

## Scope

- **In scope:** data pipeline, star schema, data quality tests, incremental load, analysis queries, a Power BI report
  with 6 pages (intro, summary and 4 detail pages), README in Czech and English.
- **Out of scope:** Kaggle data, reading PDF invoices, Airflow, Docker, dbt, Spark, cloud database.
