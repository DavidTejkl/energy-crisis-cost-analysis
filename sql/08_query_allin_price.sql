-- Business question: what did electricity really cost the company per MWh, month by month?
-- One row per month (60 rows for 2020-2024). Load is SIMULATED (fact_load, docs/methodology.md).
-- Part 1: power (market) cost. Load and price are joined on date_key AND hour_of_day (both
-- hourly), cost = SUM(load x price) hour by hour.
-- Monthly power price = cost / load (volume-weighted), not AVG of hourly prices: 
-- the company uses more power in the expensive daytime hours, so a simple average would understate its cost
-- (January 2020: 1,148.10 weighted vs 1,054.47 simple average CZK/MWh).

USE [EnergyCrisisCostAnalysis]
GO 

WITH monthly_power AS (
SELECT
		d.year,
		d.month,
		SUM(l.load_mwh) AS load_mwh,
		SUM(l.load_mwh * p.price_czk_mwh) AS power_cost_czk,
		SUM(l.load_mwh * p.price_czk_mwh)/NULLIF(SUM(l.load_mwh),0) AS power_price_czk_mwh
FROM [dbo].[vw_energy_prices_czk] p
JOIN [dbo].[fact_load] l ON p.date_key = l.date_key AND p.hour_of_day = l.hour_of_day
JOIN [dbo].[dim_date] d ON p.date_key = d.date_key
GROUP BY d.year,d.month)

SELECT * FROM monthly_power
ORDER BY year,month
