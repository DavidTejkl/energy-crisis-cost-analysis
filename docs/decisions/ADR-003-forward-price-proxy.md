# ADR-003: Hedging price — prior-year spot average as proxy, PXE year-end prices as sensitivity
- Date: 2026-10-14
- Status: accepted

## Context
Business question 4 asks whether the company could have hedged: what would electricity have cost if
0 / 25 / 50 / 75 / 100 % of the yearly volume had been bought in advance at a fixed price?
That needs the fixed price a company could have locked in before the delivery year.

- OTE publishes only day-ahead (spot) prices, no forward prices.
- Czech forward contracts are traded on PXE / EEX. Their daily price history is a licensed data
  product, not a free download. The PXE annual reports are public PDFs and quote single prices of the
  Czech base load annual contract (CZ CAL-YY) in the text.
- A base load contract delivers the same power in every hour, so its fair spot equivalent is the
  simple average of hourly prices (each hour has the same weight). This is not "averaging averages":
  the company's own cost still uses the volume-weighted price.
- Our spot data start on 1 January 2020, so a prior-year average exists for delivery years 2021–2024.

Facts found on 2026-10-14 (EUR/MWh):

| Delivery year | Prior-year spot average (OTE) | PXE CZ CAL base, first trading day of prior year | PXE range in prior year | PXE last trade of prior year | Source |
|---|---|---|---|---|---|
| 2021 | 33.62 | – | fell to 38 in March 2020 | not quoted | PXE Annual Report 2020, p. 12 |
| 2022 | 100.66 | 53.17 | 163.83 (early Oct) · max 326.80 (22 Dec 2021) | 221.88 | PXE Annual Report 2021, p. 11 |
| 2023 | 247.43 | 123.88 | 371.68 (7 Jul) · max 984.00 (26 Aug 2022) | 241.98 (28 Dec 2022) | PXE Annual Report 2022, p. 11 |
| 2024 | 100.79 | 216.27 | – | 99.03 (27 Dec 2023) | PXE Annual Report 2023 |

Prior-year spot average = `AVG(price_eur_mwh)` per year from `fact_energy_prices`
(2020 33.621243 · 2021 100.659704 · 2022 247.433603 · 2023 100.785440 · 2024 85.105306),
cross-checked with a second query that takes the year from `date_key` instead of `dim_date`.

Sources: PXE annual reports 2020–2023, `https://www.pxe.cz` → About us → Annual reports.

## Options considered
1. Real forward prices (PXE / EEX daily settlement) — licensed data, not available for a public repo.
2. Rolling 12-month spot average up to a chosen purchase date — closer to practice, but adds a second
   assumption (which purchase date) and does not remove the lag behind the market.
3. Simple spot average of the prior calendar year as proxy, with the few real PXE prices quoted in the
   annual reports as a sensitivity check.

## Decision
Option 3.
- Main hedging price (ASSUMPTION): simple average of the OTE day-ahead price in the calendar year
  before delivery. It uses only information known at the time of the decision (no look-ahead bias).
- Sensitivity (FACT): PXE CZ CAL base last trade of the prior year for 2022, 2023 and 2024
  (221.88 / 241.98 / 99.03 EUR/MWh), quoted with source. The range within the year is shown
  separately, because the timing of the purchase is itself a risk.
- The hedging analysis covers delivery years 2021–2024. 2020 has no prior-year spot data;
  2021 has the proxy only.

## Consequences
- The proxy matches the PXE year-end price within ±2 % in calm years (2023: +2.3 %, 2024: +1.8 %)
  but is 55 % below it for 2022 (100.66 vs 221.88). In the crisis year the proxy makes hedging look
  cheaper than it really was, so its benefit for 2022 is overstated. Findings must show both variants.
- Any hedging price is labelled as proxy or as a quoted PXE price, never as the company's contract price.
- Limits stated in findings:
  - A real company buys in tranches over one to three years, not on one day. The year-end price is
    the only point the public source gives for every year, not a recommended purchase date.
  - A base load contract covers a flat volume; the company's shift profile differs, so the rest is
    still bought on the spot market. This is handled in the hedging query (2.9).
- Prices are in EUR/MWh; conversion to CZK follows the ČNB rate (ADR-001) in the cost queries.
