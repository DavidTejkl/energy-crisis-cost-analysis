# Requirements — Power BI report

Version 1 (draft, step 4.0a). Scenario and business questions: [01_project_brief.md](01_project_brief.md).
The model company and its load are SCENARIO / SIMULATED; market prices, exchange rates and regulated prices are real data.

## Stakeholders

| Stakeholder | Decision they make | What they need to see |
|---|---|---|
| CFO | energy budget for next year and how much price risk the company can carry | total cost and its split (power vs regulated, fixed vs variable), why the cost changed, the effect of the EUR/CZK rate |
| Energy manager (purchasing) | how much of next year's volume to fix in advance and whether to move load into cheaper hours | cost at different hedge shares, the load profile premium, market peak vs off-peak, the most expensive hours |

The final decision on the hedge share is made by the CFO on the energy manager's proposal (brief: "how much of next
year's volume to fix in advance").

## User stories

**US-01 · CFO · total cost**
As a CFO I want to see the total electricity cost per month and year, split into power (commodity) and regulated
components, so that I know which part of the cost the market drives and which part is set by regulation.
Acceptance: yearly totals equal query 08 (2022: 200,924,897.61 CZK, power share 90.6 %).

**US-02 · CFO · why the cost changed**
As a CFO I want to see how much the power cost changed year over year and which part came from the market price,
the volume and the load profile, so that I can explain to the board what the company could and could not influence.
Acceptance: for 2021 → 2022 the report shows a total change of +4,418,085 EUR: market price +4,102,833, load
profile +319,538, volume −4,286 EUR (query 10); the three parts sum to the total change.

**US-03 · CFO · exchange rate effect**
As a CFO I want to see the year-over-year change of the power cost in CZK split into the commodity effect and the
EUR/CZK rate effect, so that I know whether the koruna helped or hurt during the crisis.
Acceptance: for 2021 → 2022 the report shows +105,823,772 CZK: commodity +112,802,613 CZK, rate −6,978,840 CZK
(query 11).

**US-04 · Energy manager · hedging**
As an energy manager I want to set the fixed share of the yearly volume from 0 to 100 % with a slider and see what
the company would have paid, so that I can back my proposal to the CFO on how much to fix for next year.
Acceptance: at 0 % the cost equals the spot cost; at 100 % for 2022 the report shows 3,297,116 EUR with the proxy
price and 6,685,638 EUR with the PXE price (query 12). The proxy price is labelled ASSUMPTION.

**US-05 · Energy manager · load profile premium**
As an energy manager I want to see how much the company pays extra per year because it takes more power in
expensive hours, so that I know how much moving shifts into cheaper hours could save at most.
Acceptance: for 2022 the report shows a premium of +17.29 EUR/MWh and 483,333 EUR in total (query 10, `C − V × Pb`),
labelled SIMULATED.

## Traceability

| Business question (brief) | User story | SQL source | Report page |
|---|---|---|---|
| 1 What did electricity really cost per kWh? | US-01 | `sql/08_query_allin_price.sql` | 2 Company cost |
| 2 Why did the cost change? | US-02 | `sql/10_query_variance_split.sql` | 3 Why it changed |
| 3 How did EUR/CZK affect the CZK cost? | US-03 | `sql/11_query_fx_effect.sql` | 3 Why it changed |
| 4 Could the loss have been hedged? | US-04 | `sql/12_query_hedging.sql` | 4 Hedging |
| own finding (2.7, 2.9) | US-05 | `sql/10_query_variance_split.sql`, `sql/12_query_hedging.sql` | 2 Company cost |

## Open (next version)

- Priorities (MoSCoW) and what the report will not do.
- Page 1 Market (price bands, peak vs off-peak, top hours): user story to be added.
