-- Business question: how many hours per year fell into each price band,
-- and how did the mix change during the 2021-2023 energy crisis?
-- Bands and thresholds (CZK/MWh) are defined in docs/kpi_definitions.md,
-- fixed for all years so the years can be compared on the same scale.

USE EnergyCrisisCostAnalysis
GO

SELECT 
		d.year,
		COUNT(*) as count_of_hours,
		CASE
			WHEN price_czk_mwh < 0 THEN 'negative'
			WHEN price_czk_mwh < 1217 THEN 'low'
			WHEN price_czk_mwh < 3374 THEN 'normal'
			WHEN price_czk_mwh < 5821 THEN 'high'
			ELSE 'extreme'
			END AS price_band
FROM dbo.vw_energy_prices_czk v
JOIN dbo.dim_date d ON v.date_key = d.date_key
GROUP BY d.year,CASE
			WHEN price_czk_mwh < 0 THEN 'negative'
			WHEN price_czk_mwh < 1217 THEN 'low'
			WHEN price_czk_mwh < 3374 THEN 'normal'
			WHEN price_czk_mwh < 5821 THEN 'high'
			ELSE 'extreme'
			END
ORDER BY d.year,price_band
