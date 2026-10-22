-- Business question: how did the EUR/CZK exchange rate affect the company's power cost in CZK?
-- Did the stronger koruna in the crisis help, and by how much compared with the market price?
-- CZ: Byznysová otázka: jak ovlivnil kurz EUR/CZK náklad firmy na silovou elektřinu v Kč?
-- Pomohla v krizi silnější koruna, a o kolik ve srovnání s tržní cenou?

-- Method: ADR-006. Per year C_eur = SUM(load x EUR price), C_czk = SUM(load x CZK price),
-- R = C_czk / C_eur (effective rate, weighted by cost). Effects from year 0 to year 1:
--   commodity = (C_eur1 - C_eur0) x R0 · exchange rate = C_eur1 x (R1 - R0)
-- A negative exchange rate effect = the koruna strengthened and lowered the CZK cost.
-- CZ: Metoda: ADR-006. Za rok C_eur = SUM(odběr x cena EUR), C_czk = SUM(odběr x cena Kč),
-- R = C_czk / C_eur (efektivní kurz, vážený náklady). Efekty z roku 0 do roku 1:
--   komodita = (C_eur1 - C_eur0) x R0 · kurz = C_eur1 x (R1 - R0)
-- Záporný efekt kurzu = koruna posílila a snížila náklad v Kč.

-- Power (commodity) cost only, regulated components are in CZK and in query 08. Load is
-- SIMULATED (docs/methodology.md); prices and ČNB rates are real data (FACT).
-- CZ: Jen náklad na silovou elektřinu, regulované složky jsou v Kč a v dotazu 08. Odběr je
-- SIMULOVANÝ (docs/methodology.md); ceny a kurzy ČNB jsou skutečná data (FAKT).

-- Source: vw_energy_prices_czk + fact_load (joined on date_key + hour_of_day) + dim_date.
-- One result row = one year compared with the previous one (2021-2024).
-- Check: the two effects sum to the total change; check_difference_czk is a few CZK (max 2.05),
-- caused by DECIMAL rounding of R to 6 decimals, not by the method. C_czk over 5 years equals
-- the power cost of query 08 (419,457,499 CZK).
-- CZ: Zdroj: vw_energy_prices_czk + fact_load (spojené přes date_key + hour_of_day) + dim_date.
-- Jeden řádek výsledku = jeden rok porovnaný s předchozím (2021-2024).
-- Kontrola: dva efekty dají v součtu celkovou změnu; check_difference_czk je pár korun (max 2,05)
-- kvůli zaokrouhlení R na 6 desetinných míst v DECIMAL, ne kvůli metodě. C_czk za 5 let se rovná
-- nákladu na silovou elektřinu z dotazu 08 (419 457 499 Kč).

USE [EnergyCrisisCostAnalysis]
GO 

WITH yearly AS (
SELECT 
		d.year,
		SUM(l.load_mwh * vw.price_eur_mwh) AS power_cost_eur,
		SUM(l.load_mwh * vw.price_czk_mwh) AS power_cost_czk
FROM [dbo].[vw_energy_prices_czk] vw
JOIN [dbo].[fact_load] l ON vw.date_key = l.date_key AND vw.hour_of_day = l.hour_of_day
JOIN [dbo].[dim_date] d ON vw.date_key = d.date_key
GROUP BY d.year ),

yearly_rate AS (
SELECT 
		year,
		power_cost_eur,
		power_cost_czk,
		power_cost_czk / NULLIF(power_cost_eur,0) AS effective_rate_czk_per_eur
FROM yearly),

with_previous AS (
SELECT 
		year,
		power_cost_eur,
		power_cost_czk,
		effective_rate_czk_per_eur,
		LAG (power_cost_eur) OVER (ORDER BY year) AS prev_power_cost_eur,
		LAG (power_cost_czk) OVER (ORDER BY year) AS prev_power_cost_czk,
		LAG (effective_rate_czk_per_eur) OVER (ORDER BY year) AS prev_effective_rate_czk_per_eur
FROM yearly_rate)

SELECT 
		year,
		power_cost_czk - prev_power_cost_czk AS total_change_czk,
		(power_cost_eur - prev_power_cost_eur) * prev_effective_rate_czk_per_eur AS commodity_effect_czk,
		power_cost_eur * (effective_rate_czk_per_eur - prev_effective_rate_czk_per_eur) AS fx_effect_czk,
		(power_cost_czk - prev_power_cost_czk) - 
		((power_cost_eur - prev_power_cost_eur) * prev_effective_rate_czk_per_eur +
		power_cost_eur * (effective_rate_czk_per_eur - prev_effective_rate_czk_per_eur)) AS check_difference_czk
FROM with_previous
WHERE prev_power_cost_czk IS NOT NULL
ORDER BY year




