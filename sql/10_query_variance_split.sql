-- Business question: why did the company's power cost change year over year - because of
-- the volume, the market price, or the load profile (in which hours the company takes power)?
-- CZ: Byznysová otázka: proč se náklad firmy na silovou elektřinu meziročně změnil - kvůli
-- objemu, tržní ceně, nebo diagramu odběru (v kterých hodinách firma elektřinu odebírá)?

-- Method: ADR-004. Per year V = volume, C = SUM(volume x price), Pw = C / V (load-weighted
-- price), Pb = simple average market price, S = Pw - Pb (load profile premium).
-- Effects from year 0 to year 1, in this fixed order:
--   volume = (V1 - V0) x Pw0 · market price = V1 x (Pb1 - Pb0) · load profile = V1 x (S1 - S0)
-- CZ: Metoda: ADR-004. Za rok V = objem, C = SUM(objem x cena), Pw = C / V (cena vážená
-- odběrem), Pb = prostý průměr tržní ceny, S = Pw - Pb (přirážka za diagram odběru).
-- Efekty z roku 0 do roku 1, v tomto pevném pořadí:
--   objem = (V1 - V0) x Pw0 · tržní cena = V1 x (Pb1 - Pb0) · diagram = V1 x (S1 - S0)

-- In EUR, power (commodity) cost only: the EUR/CZK effect is query 11, regulated components
-- are in query 08. Load is SIMULATED (docs/methodology.md), so the volume and load profile
-- effects reflect the generator's assumptions; market prices are real OTE data (FACT).
-- CZ: V EUR, jen náklad na silovou elektřinu: vliv kurzu EUR/CZK řeší dotaz 11, regulované
-- složky dotaz 08. Odběr je SIMULOVANÝ (docs/methodology.md), takže efekty objemu a diagramu
-- odrážejí předpoklady generátoru; tržní ceny jsou skutečná data OTE (FAKT).

-- Source: fact_energy_prices + fact_load (joined on date_key + hour_of_day) + dim_date.
-- One result row = one year compared with the previous one (2021-2024).
-- Check: the three effects sum to the total change; check_difference_eur <= 0.03 EUR, caused by
-- DECIMAL rounding of Pw to 6 decimals, not by the method.
-- CZ: Zdroj: fact_energy_prices + fact_load (spojené přes date_key + hour_of_day) + dim_date.
-- Jeden řádek výsledku = jeden rok porovnaný s předchozím (2021-2024).
-- Kontrola: tři efekty dají v součtu celkovou změnu; check_difference_eur <= 0.03 EUR kvůli
-- zaokrouhlení Pw na 6 desetinných míst v DECIMAL, ne kvůli metodě.

-- check_difference_eur = total change minus the sum of the three effects. A value near 0 proves
-- the split is complete: the effects explain the whole change, nothing is missing or counted twice.
-- CZ: check_difference_eur = celková změna minus součet tří efektů. Hodnota blízká 0 dokazuje,
-- že rozklad je úplný: efekty vysvětlují celou změnu, nic nechybí a nic se nepočítá dvakrát.


USE [EnergyCrisisCostAnalysis]
GO 

WITH yearly AS (
SELECT
		d.year,
		SUM(l.load_mwh) AS volume_mwh,
		SUM(l.load_mwh * ep.price_eur_mwh) AS power_cost_eur,
		AVG(ep.price_eur_mwh) AS market_price_eur_mwh
FROM [dbo].[fact_energy_prices] ep
JOIN [dbo].[fact_load] l ON ep.date_key = l.date_key AND ep.hour_of_day = l.hour_of_day
JOIN [dbo].[dim_date] d ON ep.date_key = d.date_key
GROUP BY d.year),

yearly_prices AS (
SELECT	
		year,
		volume_mwh,
		power_cost_eur,
		market_price_eur_mwh,
		power_cost_eur / NULLIF(volume_mwh,0) AS weighted_price_eur_mwh,
		(power_cost_eur / NULLIF(volume_mwh,0) - market_price_eur_mwh) AS profile_premium_eur_mwh
FROM yearly ),

with_previous AS (
SELECT 
		year,
		volume_mwh,
		power_cost_eur,
		market_price_eur_mwh,
		weighted_price_eur_mwh,
		profile_premium_eur_mwh,
		LAG (volume_mwh) OVER (ORDER BY year) AS prev_volume_mwh,
		LAG (power_cost_eur) OVER (ORDER BY year) AS prev_power_cost_eur,
		LAG (market_price_eur_mwh) OVER (ORDER BY year) AS prev_market_price_eur_mwh,
		LAG (weighted_price_eur_mwh) OVER (ORDER BY year) AS prev_weighted_price_eur_mwh,
		LAG (profile_premium_eur_mwh) OVER (ORDER BY year) AS prev_profile_premium_eur_mwh
FROM yearly_prices )

SELECT
		year,
		power_cost_eur - prev_power_cost_eur AS total_change_eur,
		(volume_mwh - prev_volume_mwh) * prev_weighted_price_eur_mwh AS volume_effect_eur,
		volume_mwh * (market_price_eur_mwh - prev_market_price_eur_mwh) AS market_price_effect_eur,
		volume_mwh * (profile_premium_eur_mwh - prev_profile_premium_eur_mwh) AS load_profile_effect_eur,
		(power_cost_eur - prev_power_cost_eur) - 
		((volume_mwh - prev_volume_mwh) * prev_weighted_price_eur_mwh + 
		volume_mwh * (market_price_eur_mwh - prev_market_price_eur_mwh) +
		volume_mwh * (profile_premium_eur_mwh - prev_profile_premium_eur_mwh)) AS check_difference_eur 
FROM with_previous
WHERE prev_volume_mwh IS NOT NULL
ORDER BY year



