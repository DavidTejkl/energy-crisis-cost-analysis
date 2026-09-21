# ADR-002: Interest rate context — ČNB 2-week repo rate instead of PRIBOR; ČEZ share price to backlog
- Date: 2026-09-21
- Status: accepted

## Context
The brief listed two optional context sources: PRIBOR (interbank interest rate) and the ČEZ share price.
Neither answers one of the four business questions directly, and each extra source adds extract,
transform, a table, DQ tests and documentation. An interest rate still helps the story for the CFO
(cost of money rose together with energy) and gives context to the EUR/CZK movement (question 3).

Facts found on 2026-09-21:
- The ČNB PRIBOR page states that the rates are published with the consent of the administrator
  Czech Financial Benchmark Facility (CFBF), may be used for internal purposes only, and that any
  redistribution of the rates or of data derived from them is prohibited. This project is public.
- ČNB publishes the full history of its 2-week repo rate as a text file with no such restriction:
  `https://www.cnb.cz/cs/casto-kladene-dotazy/.galleries/vyvoj_repo_historie.txt`
  (21 changes in 2020–2024, from 0.25 % in May 2020 to 7.00 % in June 2022 and 4.00 % in November 2024).
- The ČEZ share price has no official download source (Yahoo Finance only), and it describes the
  producer, not the buying company in the scenario.

## Options considered
1. Keep PRIBOR and ČEZ.
2. Move both to the backlog.
3. Keep one interest rate as context, ČEZ to the backlog.

## Decision
Option 3 with the ČNB 2-week repo rate instead of PRIBOR. The ČEZ share price goes to the backlog.

## Consequences
- The repo rate is stored as validity periods (valid from a date until the next change), the same
  pattern as the ERÚ tariffs; the rate valid on 1 January 2020 was set on 3 May 2019.
- It is context only: any link between the repo rate and EUR/CZK is described as correlation, not cause.
- The repo rate is the central bank's policy rate, not a market lending rate; findings must say so.
