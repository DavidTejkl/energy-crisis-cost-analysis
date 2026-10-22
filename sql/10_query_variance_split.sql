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
		(power_cost_eur - prev_power_cost_eur) - ((volume_mwh - prev_volume_mwh) * prev_weighted_price_eur_mwh + volume_mwh * (market_price_eur_mwh - prev_market_price_eur_mwh) + volume_mwh * (profile_premium_eur_mwh - prev_profile_premium_eur_mwh)) AS check_difference_eur 
FROM with_previous
WHERE prev_volume_mwh IS NOT NULL
ORDER BY year



