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




