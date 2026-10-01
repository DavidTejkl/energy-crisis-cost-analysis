-- Business question: when did the big price shocks come and how large were they?
-- One row per day (1,827 rows for 2020-2024).
-- Daily price = simple average of the hours (base price of the day), same as in query 04.
-- Change = today's price minus yesterday's price, in CZK/MWh and in %.
-- The first day (2020-01-01) has no previous day, so its change is NULL.
-- pct_change is NULL when yesterday's price is <= 0: dividing by a negative price flips the sign
-- (5 days in 2020-2024). Shocks are judged by absolute_change, which is always valid.

USE EnergyCrisisCostAnalysis
GO

WITH daily_price AS (
	SELECT 
			d.full_date,
			AVG(p.price_czk_mwh) AS avg_czk_price_per_day
	FROM vw_energy_prices_czk p
	JOIN dim_date d ON d.date_key = p.date_key
	GROUP BY d.full_date
	)

SELECT 
		full_date,
		avg_czk_price_per_day,
		LAG(avg_czk_price_per_day) OVER(ORDER BY full_date) AS avg_price_czk_last_day,
		avg_czk_price_per_day - LAG(avg_czk_price_per_day) OVER(ORDER BY full_date) AS absolute_change,
		CASE
			WHEN LAG(avg_czk_price_per_day) OVER(ORDER BY full_date) > 0
			THEN ((avg_czk_price_per_day - LAG(avg_czk_price_per_day) OVER(ORDER BY full_date))
				/ LAG(avg_czk_price_per_day) OVER(ORDER BY full_date)) * 100
			ELSE NULL
		END AS pct_change
FROM daily_price
ORDER BY full_date;