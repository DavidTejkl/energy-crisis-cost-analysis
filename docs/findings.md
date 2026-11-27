# Findings

**English** · [Čeština](findings_cz.md)

These are all the findings from the analysis queries. Every section links the query the numbers come from, so anyone
can run it and check the numbers.

Market prices, exchange rates and regulated prices are real data (OTE, ČNB, ERÚ). The load of the model company is
simulated (28 GWh a year, [methodology](methodology.md)). Everything about the company's cost therefore holds for
this model company, not for a specific real plant.

Every point has a label:

- **FACT:** a number read directly from a query result
- **FINDING:** a conclusion I draw from the numbers
- **ASSUMPTION:** a choice I had to make because the data does not exist
- **RECOMMENDATION:** advice for the company

## Part 1: The electricity market

Only real OTE day-ahead prices for the Czech Republic, without the model company.

### Daily overview

Query: [`sql/04_query_daily_overview.sql`](../sql/04_query_daily_overview.sql)

- **FACT:** The most expensive day was 26 Aug 2022 with an average price of 17,325 CZK/MWh (703 EUR/MWh). No day in
  the whole of 2020 averaged more than 2,116 CZK/MWh, so the most expensive day of the crisis was about eight times
  the most expensive day of 2020.
- **FACT:** The value of electricity traded on the day-ahead market was 20.7 bn CZK in 2020 and 155.8 bn CZK in 2022,
  7.5 times more. The traded volume grew only from 22.4 to 24.3 TWh (+8 %), so almost all of the jump came from the
  price.

### Price bands

Query: [`sql/05_query_price_bands.sql`](../sql/05_query_price_bands.sql) · band limits are in the
[KPI definitions](kpi_definitions.md#price-band)

- **FACT:** In 2020 only one hour was in the high or extreme band (3,374 CZK/MWh or more). In 2022 there were 6,951,
  79 % of the year. Cheap hours (from 0 to less than 1,217 CZK/MWh) fell from 7,045 (80 % of 2020) to 237 (3 % of
  2022). By 2024 most hours were back in the normal band (6,462) and 84 hours were extreme.
- **FACT:** There were only 8 hours with a negative price in 2022. In 2024 there were 315, the most of all five years.

### Day-to-day price changes

Query: [`sql/06_query_price_changes.sql`](../sql/06_query_price_changes.sql)

- **FACT:** The daily average price jumped the most on 11 Jul 2022, by 6,844 CZK/MWh (from 2,265 to 9,109). It fell
  the most on 1 Oct 2022, by 5,266 CZK/MWh (from 8,697 to 3,430).
- **FACT:** 18 of the 20 largest daily rises in 2022 fell on a Monday. The day-to-day change therefore mostly shows the
  weekly rhythm at a very high price level: power is cheap at the weekend and the price jumps back on Monday. These are
  mostly not separate market events.
- **Method note:** I leave the percentage change (`pct_change`) empty when the previous day's price was zero or
  negative (5 days), because dividing by a negative price flips the sign. For example, on 22 Mar 2020 the average
  price was −0.98 EUR/MWh (a Sunday with 11 negative hours, confirmed in the raw OTE file). That is why changes are
  compared in CZK.

### Most expensive hours and days

Query: [`sql/07_query_top_hours.sql`](../sql/07_query_top_hours.sql)

- **FACT:** The most expensive hour of 2024 (12 Dec 2024, 17:00–18:00, 21,171 CZK/MWh) was almost as expensive as the
  most expensive hour of the crisis (29 Aug 2022, 19:00–20:00, 21,422 CZK/MWh). The most expensive day of 2024,
  however, averaged only 9,035 CZK/MWh, about half of the most expensive day of 2022 (26 Aug 2022, 17,325 CZK/MWh).
- **FACT:** All five most expensive days of 2022 fell within the eight days from 24 to 31 Aug 2022 (15,535 to
  17,325 CZK/MWh).
- **FINDING:** 2022 was a long period of very high prices. The 2024 peak was a short shock of a few hours with little
  wind and sun (see the [data quality report](data_quality_report.md)). Hours priced like the crisis can still come
  after it, and the risk of buying on the spot market did not go away with the crisis.

### Peak and off-peak

Query: [`sql/09_query_peak_offpeak.sql`](../sql/09_query_peak_offpeak.sql)

Peak is Monday to Friday 08:00–20:00 (`hour_of_day` 9–20), the same as the market's peak load product. All other
hours are off-peak. **ASSUMPTION:** public holidays on weekdays count as peak, because `dim_date` has no holiday flag.
Prices are simple averages, every hour has the same weight, as in a market product.

- **FACT:** The gap between peak and the rest of the week grew from 12.53 EUR/MWh in 2020 to **60.04 EUR/MWh in 2022**
  (4.8 times), then fell to 21.82 (2023) and 14.89 (2024). In CZK it was 330.09 CZK/MWh in 2020, 1,471.75 in 2022,
  526.54 in 2023 and 374.52 in 2024.
- **FACT:** In percent, however, the peak premium kept falling. Peak was more expensive by 43 % in 2020, 38 % in 2021,
  27 % in 2022, 23 % in 2023 and 19 % in 2024. The gap grew in 2022 because the whole price level rose. Daytime hours
  did not become more expensive relative to the others.

## Part 2: The model company (simulated load)

The company's load is simulated (`SIMULATED`), while prices, exchange rates and regulated prices are real. Unless
stated otherwise, the company buys all its power at the day-ahead spot price.

### All-in price per kWh

Query: [`sql/08_query_allin_price.sql`](../sql/08_query_allin_price.sql)

The all-in price is power from the day-ahead market plus the regulated charges: network use, system services,
electricity tax, reserved capacity of 5 MW, POZE and OTE fees. It applies to the ČEZ Distribuce area at high voltage,
**without VAT and without a supplier margin** ([what the price includes](decisions/ADR-005-all-in-price-scope.md)).

- **FINDING:** The all-in price rose from **1.62 CZK/kWh in 2020 to 7.19 CZK/kWh in 2022** (4.4 times), then fell to
  3.15 (2023) and 3.38 (2024). The company used almost the same amount every year (27.95–28.05 GWh), and the yearly
  cost went up from 45.5 m CZK (2020) to 200.9 m CZK (2022).
- **FINDING:** Power drove the crisis. It was 58 % of the total cost in 2020 and 91 % in 2022. The most expensive month
  was August 2022: all-in price 12.75 CZK/kWh, power 12,084 CZK/MWh.
- **FINDING:** 2024 was more expensive than 2023 (3.38 vs 3.15 CZK/kWh) although power got cheaper (2,266 vs
  2,550 CZK/MWh). The regulated part went up. The company paid 2.2 times more for network use and 1.9 times more for
  system services than in 2023, and the POZE fee, which had been zero from October 2022 to December 2023, came back.
- **FINDING:** The company pays more than the market average because it takes the most power in the expensive daytime
  hours. In January 2020 its load-weighted power price was 1,148.10 CZK/MWh, while the simple market average was
  1,054.47 CZK/MWh.
- **FACT:** The 2023 state price cap of 5,000 CZK/MWh, which applies to the monthly weighted power price, never reached
  the model company. The most expensive month of 2023 was January at 3,572.47 CZK/MWh. In 2022, when there was no cap
  yet, six months were above 5,000 CZK/MWh (highest August, 12,084 CZK/MWh). For a company buying on the spot market,
  the cap came only after prices had already fallen.
- **FACT:** The POZE fee was always cheaper when charged by reserved capacity than by consumption (the per-MWh option
  was cheaper in none of the 60 months). A continuous process uses a lot of MWh for every reserved MW.

### Why regulated charges jumped in 2024

| Regulated charges of the model company (m CZK) |      2022 |      2023 |      2024 |
| ---------------------------------------------- | --------: | --------: | --------: |
| Distribution (reserved capacity and network use) |   12.69 |     12.71 |     17.57 |
| System services                                |      3.17 |      3.17 |      5.97 |
| POZE                                           |      2.32 |      0.00 |      6.95 |
| Electricity tax                                |      0.79 |      0.79 |      0.79 |
| **Total**                                      | **18.97** | **16.67** | **31.28** |

POZE for 2022 covers January to September only. OTE fees are only tens of CZK a year, so they are not in the table.

- **FACT:** In the crisis years the state paid part of the regulated charges for the customers. From October 2022 to
  the end of 2023 it paid the whole support for renewable sources from the state budget, so the POZE fee was zero. In
  2023 state subsidies also kept the price of system services and of network losses at the 2022 level. For 2024 the
  government ended almost all of these subsidies, and the regulated prices fully reflected that high power prices had
  also made running the grid more expensive, mainly covering network losses and system services
  ([ERÚ press release of 30 Nov 2023, in Czech](https://eru.gov.cz/sites/default/files/obsah/prilohy/20231130tzcreruproelektroenergetikuaplynarenstvi.pdf)).
- **FINDING:** Compared with 2022, the company paid 12.31 m CZK more for regulated charges in 2024: distribution
  +4.88 m CZK, POZE +4.63 m CZK and system services +2.80 m CZK. The electricity tax did not change.
- **FINDING:** Compared with 2023, the company's regulated charges rose by 88 %. In November 2023 ERÚ expected an
  average increase of 105.5 % for high-voltage customers. The model company's increase is lower mainly because its
  largest item, reserved capacity, went up by only 19 %.

### Why the cost changed

Query: [`sql/10_query_variance_split.sql`](../sql/10_query_variance_split.sql) ·
method: [cost variance split](decisions/ADR-004-cost-variance-split.md)

I split the year-over-year change of the power cost in EUR into three parts, always in the same order:

- volume: `(V1 − V0) × Pw0`
- market price: `V1 × (Pb1 − Pb0)`
- load profile: `V1 × (S1 − S0)`

V is the company's load, Pb the average market price, Pw the price weighted by the company's load and S = Pw − Pb the
load profile premium. In every year the three parts add up to the total change, with a difference of at most
0.03 EUR from rounding Pw.

| Change       | Total (EUR) |  Volume | Market price | Load profile |
| ------------ | ----------: | ------: | -----------: | -----------: |
| 2020 to 2021 |  +1,976,267 |  −2,052 |   +1,876,652 |     +101,667 |
| 2021 to 2022 |  +4,418,085 |  −4,286 |   +4,102,833 |     +319,538 |
| 2022 to 2023 |  −4,427,762 |  −1,194 |   −4,098,657 |     −327,911 |
| 2023 to 2024 |    −442,638 | +11,073 |     −439,875 |      −13,836 |

- **FINDING:** The load profile premium almost tripled in the crisis. It was +2.23 EUR/MWh in 2020 and +5.86 in 2021,
  jumped to **+17.29 EUR/MWh in 2022**, then fell to 5.56 (2023) and 5.06 (2024). For the whole of 2022 that is
  **483,333 EUR** more than if the company had taken the same amount evenly in every hour. In 2020–2024 it was
  62,491 / 164,030 / 483,333 / 155,344 / 142,087 EUR (`C − V × Pb`), about 5–6.5 % of the power cost every year.
- **FINDING:** The load profile is the part of the cost the company can influence itself. It cannot influence the
  market price. The profile itself did not change between years. The premium grew because the gap between daytime and
  night prices grew together with the whole price level. The yearly premium is the upper limit of what the company
  could save by moving shifts to nights and weekends.
- **FINDING:** The market price explains 93–99 % of every yearly change (95.0 / 92.9 / 92.6 / 99.4 %). With a
  simulated load of about 28 GWh every year this was to be expected and is not a discovery: the volume effect stays
  between −4,286 and +11,073 EUR. With real company data the same query would separate changes in production from
  market moves.

### Effect of the EUR/CZK rate

Query: [`sql/11_query_fx_effect.sql`](../sql/11_query_fx_effect.sql) ·
method: [exchange rate effect](decisions/ADR-006-fx-effect-split.md)

I split the year-over-year change of the power cost in CZK into the commodity effect `(C_eur1 − C_eur0) × R0` and the
exchange rate effect `C_eur1 × (R1 − R0)`. R = C_czk / C_eur is the cost-weighted rate: days with a high EUR cost
count more than days with a low one. The two parts add up to the total change, with a difference of at most 2.05 CZK
from rounding R. The CZK cost over all five years is 419,457,499 CZK, the same as the power cost in query 08.

| Change       | Total (CZK)  |    Commodity | Exchange rate |
| ------------ | -----------: | -----------: | ------------: |
| 2020 to 2021 |  +49,581,580 |  +52,180,598 |    −2,599,020 |
| 2021 to 2022 | +105,823,772 | +112,802,613 |    −6,978,840 |
| 2022 to 2023 | −110,696,659 | −108,873,893 |    −1,822,768 |
| 2023 to 2024 |   −7,703,937 |  −10,612,537 |    +2,908,602 |

- **FACT:** The cost-weighted rate fell from 26.40 CZK/EUR (2020) to 25.53 (2021), 24.59 (2022) and 23.98 (2023), then
  rose to 25.13 in 2024. The koruna got stronger during the crisis and weaker in 2024.
- **FINDING:** The stronger koruna lowered the cost in 2022 by **6.98 m CZK**. That offset only **6.2 %** of the
  commodity increase (+112.80 m CZK), so the exchange rate softened the crisis only a little.
- **FINDING:** In 2024 it worked the other way. The weaker koruna added 2.91 m CZK and ate 27 % of the commodity saving
  (−10.61 m CZK).
- **Method note:** The report page Příčiny změny (Why it changed) also shows the plain yearly average rate (in 2022 from
  25.65 to 24.56 CZK/EUR). For the exchange rate effect, however, I use the cost-weighted rate, because only with it
  do the two parts add up exactly to the real CZK cost.

### Hedging by buying in advance

Query: [`sql/12_query_hedging.sql`](../sql/12_query_hedging.sql) ·
method: [hedging price](decisions/ADR-003-forward-price-proxy.md)

The company buys part of its yearly volume (0, 25, 50, 75 or 100 %) in advance as base load, the same power in every
hour. It pays the rest on the spot market. The hedged cost is `C + share × V × (Ph − Pb)`. I compute the hedging
price Ph in two ways:

- the simple spot average of the previous year (**ASSUMPTION**, a proxy, because OTE has no forward prices)
- the last trade of the PXE CZ CAL base yearly product at the end of the previous year (**FACT** from the PXE annual
  reports, only for 2022–2024)

Checks: at 0 % both variants equal the spot cost. At 100 % the part the company still pays on the spot market equals
`C − V × Pb` from query 10 (2022: 483,332.58 EUR). The proxy difference equals the market price effect of query 10
with the opposite sign.

Difference of the cost with 100 % of the volume hedged against buying only on the spot market (EUR, negative = saving):

| Delivery year | Spot cost  | Proxy price (EUR/MWh) | Proxy difference   | PXE price (EUR/MWh) | PXE difference     |
| ------------- | ---------: | --------------------: | -----------------: | ------------------: | -----------------: |
| 2021          |  2,981,864 |                 33.62 | −1,876,652 (−63 %) |                   – |                  – |
| 2022          |  7,399,949 |                100.66 | −4,102,833 (−55 %) |              221.88 |   −714,311 (−10 %) |
| 2023          |  2,972,187 |                247.43 | +4,098,657 (+138 %) |             241.98 | +3,946,234 (+133 %) |
| 2024          |  2,529,549 |                100.79 |   +439,875 (+17 %) |               99.03 |   +390,630 (+15 %) |
| 2022–2024     | 12,901,686 |                       |           +435,699 |                     |     **+3,622,554** |

The 2022–2024 row is added up from the exact values, so it can differ by 1 EUR from the sum of the rounded numbers.

- **FINDING:** If the company fixes its whole volume once at the end of the year, the crisis does not go away, it only
  moves by one year. The highest yearly cost is 7.40 m EUR on spot (2022) and 7.07 m EUR fully hedged (2023). The
  company would have bought its power for 2023 still at 2022 prices, and the market then fell by 59 % in 2023.
- **FINDING:** The proxy overstates the benefit of hedging in the crisis year. With the real PXE year-end price the
  saving for 2022 is only 0.71 m EUR instead of 4.10 m EUR, because forward prices had already jumped in autumn 2021.
  Over 2022–2024 a full hedge at PXE year-end prices would have cost **3.62 m EUR more** than buying on spot.
- **FINDING:** A base load hedge does not cover the load profile premium. Even fully hedged, the company still pays
  `C − V × Pb` on the spot market: 164,030 / 483,333 / 155,344 / 142,087 EUR in 2021–2024, which is 14.8 / 14.7 /
  2.2 / 4.8 % of the hedged cost.
- **FACT:** The purchase date matters. Power for 2023 traded on PXE at 123.88 EUR/MWh on the first trading day of
  2022, at 984.00 EUR/MWh on 26 Aug 2022 and at 241.98 EUR/MWh in the last trade of the year on 28 Dec 2022 (PXE
  Annual Report 2022, [ADR-003](decisions/ADR-003-forward-price-proxy.md)).
- **RECOMMENDATION:** Hedging makes sense, but not everything should be bought on one day. It is better to buy next
  year's power in parts during the whole year before delivery, for example power for 2027 in quarters during 2026,
  and to keep a part on spot. I did not calculate such gradual buying in this project, because daily PXE prices are
  not a free download.

### Most expensive day for the company

Query: view `dbo.vw_hourly_cost` ([`sql/03_create_views.sql`](../sql/03_create_views.sql)) grouped by day

The power cost per day is the sum of hourly load × day-ahead price × EUR/CZK rate, without regulated charges, margin
and VAT. The company buys everything on the spot market without a hedge, so this is the worst case. The most expensive
day of each year is picked with `RANK() OVER (PARTITION BY year ORDER BY SUM(power_cost_czk) DESC)`.

| Year | Most expensive day | Load (MWh) | Power cost (CZK) | Weighted price (CZK/MWh) | × average day of 2020 |
| ---- | ------------------ | ---------: | ---------------: | -----------------------: | --------------------: |
| 2020 | Wed 9 Dec 2020     |     78.753 |          186,946 |                    2,374 |                   2.6 |
| 2021 | Tue 21 Dec 2021    |     78.565 |          912,097 |                   11,609 |                  12.6 |
| 2022 | Tue 30 Aug 2022    |     97.792 |    **1,657,483** |                   16,949 |              **22.8** |
| 2023 | Mon 23 Jan 2023    |     78.511 |          406,854 |                    5,182 |                   5.6 |
| 2024 | Thu 12 Dec 2024    |     78.535 |          830,802 |                   10,579 |                  11.5 |

An average day (yearly cost / number of days) cost 72,545 / 208,584 / 498,512 / 195,233 / 173,651 CZK in 2020–2024.
Check: the three most expensive days of 2022 come out the same to the haléř when computed directly from the fact
tables.

- **FINDING:** At the peak of the crisis one day of operation cost the unhedged company 1.66 m CZK for power alone,
  22.8 times an average day of 2020 (72,545 CZK). Even an average day of 2022 cost 0.50 m CZK.
- **FINDING:** The most expensive day for the company was not the most expensive day of the market. The market peaked
  on Friday 26 Aug 2022 (query 07), but the company paid the most on Tuesday 30 Aug 2022 (1,657,483 vs 1,629,833 CZK).
  On Friday the shift work stops at 22:00, so the company took less power (93.8 vs 97.8 MWh). What the company pays
  therefore depends on the price and on how much power it takes in the expensive hours.
- **FINDING:** The crisis ended, but the price spikes stayed. The most expensive day of 2024 (12 Dec 2024,
  Dunkelflaute) cost 0.83 m CZK, almost as much as the most expensive day of 2021.
- **Limit:** Real companies often fix their price in advance, so most of them did not pay such daily amounts in
  2022. In a [survey by the Confederation of Industry of the Czech Republic](https://www.spcr.cz/drahe-energie-na-firmy-dopadnou-zejmena-v-pristim-roce)
  from September 2022 (114 mostly industrial firms), almost two thirds had a fixed electricity price for 2022, but only
  20 % for 2023. The report page Zajištění ceny (Hedging) compares this worst case with a partly hedged volume.
