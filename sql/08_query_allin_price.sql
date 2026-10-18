-- Business question: what did electricity really cost the company per MWh, month by month?
-- One row per month (60 rows for 2020-2024). Load is SIMULATED (fact_load, docs/methodology.md).

-- Part 1: power (market) cost. Load and price are joined on date_key AND hour_of_day (both
-- hourly), cost = SUM(load x price) hour by hour.
-- Monthly power price = cost / load (volume-weighted), not AVG of hourly prices: 
-- the company uses more power in the expensive daytime hours, so a simple average would understate its cost
-- (January 2020: 1,148.10 weighted vs 1,054.47 simple average CZK/MWh).

-- Part 2: regulated components paid per MWh (network use, system services, electricity tax).
-- regulated_price has validity periods, so it is joined to days with BETWEEN; it is summed in its
-- own CTE, because joining it to the power CTE would repeat each hour 3 times (once per component).

-- Part 3a: fixed monthly charges (reserved capacity 5 MW = scenario ASSUMPTION, docs/methodology.md;
-- two OTE fees per supply point). They do not depend on load, so they are joined to one day per
-- month (day_of_month = 1), never to hours or days, which would add the charge 744 or 31 times.

-- Part 3b: POZE = the lower of (rate per MW x reserved MW) and (cap per MWh x monthly load), per
-- ERU price decisions. The choice needs the monthly load, so it is made in the final SELECT.
-- POZE was 0 from October 2022 to December 2023 (paid by the state).

USE [EnergyCrisisCostAnalysis]
GO 

DECLARE @reserved_mw DECIMAL(4,1) = 5;

WITH 
	monthly_power AS (
	SELECT
			d.year,
			d.month,
			SUM(l.load_mwh) AS load_mwh,
			SUM(l.load_mwh * p.price_czk_mwh) AS power_cost_czk,
			SUM(l.load_mwh * p.price_czk_mwh)/NULLIF(SUM(l.load_mwh),0) AS power_price_czk_mwh
	FROM [dbo].[vw_energy_prices_czk] p
	JOIN [dbo].[fact_load] l ON p.date_key = l.date_key AND p.hour_of_day = l.hour_of_day
	JOIN [dbo].[dim_date] d ON p.date_key = d.date_key
	GROUP BY d.year,d.month),
	
	monthly_regulated AS (
	SELECT 
			d.year,
			d.month,
			SUM(CASE WHEN rp.component = 'network_use' THEN l.load_mwh * rp.value END) AS network_use_czk,
			SUM(CASE WHEN rp.component = 'electricity_tax' THEN l.load_mwh * rp.value END) AS electricity_tax_czk,
			SUM(CASE WHEN rp.component = 'system_services' THEN l.load_mwh * rp.value END) AS system_services_czk

	FROM [dbo].[fact_load] l
	JOIN [dbo].[dim_date] d ON l.date_key = d.date_key 
	JOIN [dbo].[regulated_price] rp ON d.full_date BETWEEN rp.valid_from AND rp.valid_to
	WHERE rp.component IN ('network_use', 'system_services', 'electricity_tax')
	GROUP BY d.year,d.month),

	monthly_fixed AS (
	SELECT 
			d.year,
			d.month,
			SUM(CASE WHEN rp.component = 'reserved_capacity_yearly' THEN rp.value * @reserved_mw END) AS reserved_capacity_czk,
			SUM(CASE WHEN rp.component IN ('ote_imbalance_settlement', 'ote_res_admin') THEN rp.value END) AS ote_fees_czk,
			SUM(CASE WHEN rp.component = 'poze_per_mw' THEN rp.value * @reserved_mw END) AS poze_capacity_czk,
			SUM(CASE WHEN rp.component = 'poze_cap' THEN rp.value END) AS poze_cap_czk_mwh
	FROM [dbo].[dim_date] d
	JOIN [dbo].[regulated_price] rp ON d.full_date BETWEEN rp.valid_from AND rp.valid_to
	WHERE d.day_of_month = 1 AND rp.component IN ('reserved_capacity_yearly', 'ote_imbalance_settlement', 'ote_res_admin', 'poze_per_mw', 'poze_cap')
	GROUP BY d.year,d.month )

SELECT 
		mp.year,
		mp.month,
		mp.load_mwh,
		mp.power_cost_czk,
		mp.power_price_czk_mwh,
		mr.electricity_tax_czk,
		mr.network_use_czk,
		mr.system_services_czk,
		mf.reserved_capacity_czk,
		mf.ote_fees_czk,
		CASE WHEN mf.poze_capacity_czk < mf.poze_cap_czk_mwh * mp.load_mwh
			THEN mf.poze_capacity_czk
			ELSE mf.poze_cap_czk_mwh * mp.load_mwh
			END AS poze_czk
FROM monthly_power mp 
JOIN monthly_regulated mr ON mp.year = mr.year AND mp.month = mr.month
JOIN monthly_fixed mf ON mp.year = mf.year AND mp.month = mf.month
ORDER BY mp.year,mp.month
