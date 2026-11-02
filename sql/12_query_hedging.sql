USE [EnergyCrisisCostAnalysis]
GO

WITH yearly AS (
SELECT 
		d.year,
		SUM(l.load_mwh) AS volume_mwh,
		SUM(ep.price_eur_mwh * l.load_mwh) AS spot_cost_eur,
		AVG(ep.price_eur_mwh) AS market_price_eur_mwh
FROM [dbo].[fact_energy_prices] ep
JOIN [dbo].[fact_load] l ON ep.date_key = l.date_key AND ep.hour_of_day = l.hour_of_day
JOIN [dbo].[dim_date] d ON ep.date_key = d.date_key
GROUP BY d.year ),

with_hedge_price AS (
SELECT
		year,
		volume_mwh,
		spot_cost_eur,
		market_price_eur_mwh,
		LAG(market_price_eur_mwh) OVER (ORDER BY year) AS hedge_price_eur_mwh
FROM yearly ),

hedge_shares AS (
SELECT	0.00 AS hedge_share 
		UNION ALL
SELECT	0.25
		UNION ALL
SELECT	0.50
		UNION ALL
SELECT	0.75
		UNION ALL
SELECT	1.00
				)
		
SELECT
		year,
		s.hedge_share,
		hp.spot_cost_eur,
		hp.hedge_price_eur_mwh,
		hp.market_price_eur_mwh,
		spot_cost_eur + hedge_share * volume_mwh * (hedge_price_eur_mwh - market_price_eur_mwh) AS hedged_cost_eur
FROM with_hedge_price hp 
CROSS JOIN hedge_shares s 
WHERE hedge_price_eur_mwh IS NOT NULL
ORDER BY year,hedge_share