-- Business question: which were the most expensive hours of each year, and how high did the price go?
-- An average hides the extremes; the top hours show what unhedged spot buying could cost in one hour.
-- Top 5 hours per year (25 rows for 2020-2024), price in CZK/MWh from vw_energy_prices_czk.
-- RANK restarts every year (PARTITION BY year); equal prices get the same rank, so a tie on
-- 5th place would return more than 5 rows for that year.
-- The rank is filtered outside the CTE because a window function cannot be used in WHERE.
-- Part 2: top 5 days per year (25 rows). Daily price = simple average of the hours, same as in
-- queries 04 and 06; it is computed in its own CTE first, then ranked in a second CTE.

USE EnergyCrisisCostAnalysis
GO

WITH ranked_hours AS (
	SELECT	d.year,
			d.full_date,
			p.hour_of_day,
			p.price_czk_mwh,
			RANK() OVER (PARTITION BY d.year ORDER BY p.price_czk_mwh DESC) AS price_rank
	FROM vw_energy_prices_czk p
	JOIN dim_date d ON d.date_key = p.date_key )

SELECT	year,
		full_date,
		hour_of_day,
		price_czk_mwh,
		price_rank
FROM ranked_hours
WHERE price_rank <= 5 
ORDER BY year,price_rank;


WITH daily_price AS (
	SELECT	d.year,
			d.full_date,
			AVG(p.price_czk_mwh) AS avg_price_czk
	FROM vw_energy_prices_czk p
	JOIN dim_date d ON p.date_key = d.date_key
	GROUP BY d.year,d.full_date ),

	ranked_days AS (
	SELECT	year,
			full_date,
			avg_price_czk,
			RANK() OVER (PARTITION BY year ORDER BY avg_price_czk DESC) AS price_rank
	FROM daily_price )

SELECT	year,
		full_date,
		avg_price_czk,
		price_rank
FROM ranked_days
WHERE price_rank <= 5
ORDER BY year, price_rank;