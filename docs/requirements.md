# Requirements: Power BI report

**English** · [Čeština](requirements_cz.md)

What the report has to do, for whom, and how we know it is done. The scenario and the business questions are in the
[project brief](01_project_brief.md). The model company and its load are fictional and simulated, market prices,
exchange rates and regulated prices are real data.

## Stakeholders

| Stakeholder | Decision they make | What they need to see |
|---|---|---|
| CFO | the energy budget for next year and how much price risk the company can carry | the total cost and its split (power vs regulated charges, fixed vs variable), why the cost changed, the effect of the EUR/CZK rate |
| Energy purchasing | how much of next year's volume to fix in advance and whether to move load into cheaper hours | the cost at different hedge shares, the load profile premium, peak vs off-peak prices, the most expensive hours |

The final decision on the hedge share is made by the CFO, based on the proposal from energy purchasing.

## User stories

**US-01 · CFO · total cost**
As a CFO I want to see the total electricity cost per month and year, split into power and regulated charges, so that
I know which part of the cost the market drives and which part is set by regulation.
Acceptance: the yearly totals equal query 08 (2022: 200,924,897.61 CZK, power share 90.6 %).

**US-02 · CFO · why the cost changed**
As a CFO I want to see how much the power cost changed from year to year and how much of it came from the market
price, the volume, the load profile and the exchange rate, so that I can explain to the board what the company could
and could not influence.
Acceptance: for 2021 to 2022 the report shows a change of +105.82 m CZK, made of market price +104.75 m, load profile
+8.16 m, volume −0.11 m and exchange rate −6.98 m CZK. The steps add up to the total change (within 2 CZK of
rounding). The same split in EUR is in query 10.

**US-03 · CFO · exchange rate effect**
As a CFO I want to see the change of the power cost in CZK split into the commodity effect and the EUR/CZK rate
effect, so that I know whether the koruna helped or hurt during the crisis.
Acceptance: for 2021 to 2022 the report shows +105,823,772 CZK: commodity +112,802,613 CZK, exchange rate
−6,978,840 CZK (query 11).

**US-04 · Energy purchasing · hedging**
As an energy buyer I want to set the share of the yearly volume bought in advance from 0 to 100 % with a slider and
see what the company would have paid, so that I can back my proposal to the CFO on how much to fix for next year.
Acceptance: at 0 % the cost equals the spot cost. At 100 % for 2022 the report shows 3,297,116 EUR with the proxy
price and 6,685,638 EUR with the PXE price (query 12). The proxy price is labelled as an assumption.

**US-05 · Energy purchasing · load profile premium**
As an energy buyer I want to see how much extra the company pays per year because it takes more power in expensive
hours, so that I know the most that moving shifts into cheaper hours could save.
Acceptance: for 2022 the report shows a premium of 426.45 CZK/MWh and 11.92 m CZK, labelled as simulated. In EUR the
same premium is +17.29 EUR/MWh and 483,333 EUR (query 10).

**US-06.1 · Energy purchasing · price bands and top hours**
As an energy buyer I want to see how many hours of each year fell into each price band and which hours were the
most expensive, so that I can see how often the market had extreme prices and when buying only on the spot market is
risky.
Acceptance: 2022 has 3,694 hours in the extreme band (5,821 CZK/MWh or more, query 05). The hours of all bands add up
to the hours of the year (8,760). The most expensive hour is 29 Aug 2022, hour 20, 21,422.25 CZK/MWh (query 07).

**US-06.2 · Energy purchasing · peak vs off-peak**
As an energy buyer I want to see the price difference between peak hours (Monday to Friday, 08:00 to 20:00) and
the rest of the week for every year, so that I know how much moving part of the production to nights and weekends
could save.
Acceptance: in 2022 peak hours are 60.04 EUR/MWh (1,471.75 CZK/MWh) more expensive than off-peak hours (query 09).
Peak and off-peak hours add up to all hours of the year (2022: 3,120 + 5,640 = 8,760).

## Traceability

From the business question to the user story, the SQL query and the report page.

| Business question (brief) | User story | SQL source | Report page |
|---|---|---|---|
| 1 What did electricity really cost per kWh? | US-01 | `sql/08_query_allin_price.sql` | Company cost (Náklad firmy) |
| 2 Why did the cost change? | US-02 | `sql/10_query_variance_split.sql` | Why it changed (Příčiny změny) |
| 3 How did EUR/CZK affect the CZK cost? | US-03 | `sql/11_query_fx_effect.sql` | Why it changed (Příčiny změny) |
| 4 Could the loss have been hedged? | US-04 | `sql/12_query_hedging.sql` | Hedging (Zajištění ceny) |
| own finding | US-05 | `sql/10_query_variance_split.sql`, `sql/12_query_hedging.sql` | Company cost (Náklad firmy) |
| market context for questions 2 and 4 | US-06.1 | `sql/05_query_price_bands.sql`, `sql/07_query_top_hours.sql` | Market (Trh) |
| market context for questions 2 and 4 | US-06.2 | `sql/09_query_peak_offpeak.sql` | Market (Trh) |

The Summary page (Shrnutí) takes the main numbers from all of these pages.

## Priorities (MoSCoW)

| User story | Priority | Why |
|---|---|---|
| US-01 total cost | Must | business question 1 and the base for every other page |
| US-02 why the cost changed | Must | business question 2 |
| US-04 hedging slider | Must | business question 4, the main decision of the brief |
| US-05 load profile premium | Must | the part of the cost the company can influence itself, and even a 100 % hedge does not remove it |
| US-03 exchange rate effect | Should | business question 3, but a small effect (6.2 % of the 2022 commodity increase) |
| US-06.1 price bands and top hours | Should | market context for the other pages |
| US-06.2 peak vs off-peak | Could | partly overlaps with US-05 |

## Out of scope (Won't)

- Price forecasts: the report looks at the past, and no history of forward prices is available (ADR-003).
- Real data of a specific company: the load is simulated and every page says so.
- Invoicing and VAT: prices are without VAT and without a supplier margin (ADR-005).
- Data after 2024: the project covers 2020–2024.
- Automatic refresh: the data is historical, so the report does not refresh itself.
