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
GROUP BY d.year)

SELECT	
		year,
		volume_mwh,
		power_cost_eur,
		market_price_eur_mwh,
		power_cost_eur / NULLIF(volume_mwh,0) AS weighted_price_eur_mwh,
		(power_cost_eur / NULLIF(volume_mwh,0) - market_price_eur_mwh) AS profile_premium_eur_mwh
FROM yearly
ORDER BY year



