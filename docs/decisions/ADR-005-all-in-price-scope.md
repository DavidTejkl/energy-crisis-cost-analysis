# ADR-005: All-in price — ČEZ Distribuce area, VN voltage level, no VAT, 2023 price cap per month
- Date: 2026-10-14
- Status: accepted

## Context
Business question 1 asks what electricity really cost per kWh: the power price from the market plus
the regulated components (distribution, system services, POZE, OTE fee, electricity tax).
The regulated components are set by ERÚ price decisions and depend on the distribution area and on
the voltage level of the connection. In 2023 a state price cap applied to the power price.
The scenario in the brief said only "energy-intensive Czech firm", which is not enough to choose
the tariffs.

Facts found on 2026-10-14:
- Government regulation No. 298/2022 Coll. capped the power price at 5,000 CZK/MWh excluding VAT for
  supplies from 1 January to 31 December 2023. The cap covers the power price only, not distribution,
  system services, POZE or the OTE fee. For businesses it applied to 80 % of the highest monthly
  consumption of the last five years.
- In our data, the hourly day-ahead price exceeded 5,000 CZK/MWh in 88 hours of 2023
  (maximum 10,891.81 CZK/MWh) and in 4,853 hours of 2022. No month of 2023 had a simple average above
  the cap (highest: February 3,300.43 CZK/MWh). Query: `vw_energy_prices_czk` JOIN `dim_date`,
  2023, `AVG(price_czk_mwh)` by month.
- How the cap was settled for spot-indexed supply contracts was not found in the sources checked.

## Options considered
- Distribution area: ČEZ Distribuce · EG.D · PREdistribuce.
- Voltage level: NN (low voltage, workshops and households) · VN (high voltage, 22 kV, industrial
  plants) · VVN (110 kV, very large plants).
- VAT: included · excluded.
- Supplier margin: invented fixed value · none.
- Price cap: ignored · applied per hour · applied to the monthly average power price.

## Decision
- **Distribution area: ČEZ Distribuce** — the largest area, covering the Olomouc region.
- **Voltage level: VN** — typical for an energy-intensive plant with three shifts.
- **Without VAT** — the company is a VAT payer and deducts it, so VAT is not a cost for the CFO.
- **No supplier margin** — no public value exists; inventing one would add a new fictional
  assumption. Findings state that the all-in price excludes the supplier's margin.
- **2023 price cap: applied to the monthly volume-weighted power price** (ASSUMPTION): the company pays
  `MIN(monthly power price, 5,000 CZK/MWh)` for each month of 2023.

Both the area and the voltage level extend the SCENARIO in `docs/01_project_brief.md` (approved by
the project owner on 2026-10-14).

## Consequences
- Tariff values (2020–2024) are collected from the ERÚ price decisions for ČEZ Distribuce, VN, into
  `config/` with `valid_from` / `valid_to` (ROADMAP 2.2). Nothing is hard-coded in scripts.
- The VN distribution price includes a monthly charge for reserved capacity, so it needs the maximum
  load of the simulated profile (ROADMAP 2.3).
- With the monthly rule and the 2023 prices, the cap is expected not to bind in any month. Query 08
  (ROADMAP 2.5) checks this with the company's volume-weighted price. If a month is above the cap,
  this ADR is revisited, including the 80 % volume rule.
- The all-in price is a model price for one area and one voltage level, not a price for every Czech
  company. Findings say so.
