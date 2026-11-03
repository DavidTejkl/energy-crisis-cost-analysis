-- ** CZK/MWH ENERGY PRICES VIEW **
-- Business question: what did each hour of electricity cost in CZK/MWh? OTE prices are in EUR, the budget in CZK.
-- One row = one hour (43,848 rows). A view, not a stored column: the rate lives only in fact_fx.
-- LEFT JOIN on the rate: a missing rate would show as NULL instead of a lost hour.
-- CZ: ** VIEW S CENAMI ENERGIE V CZK/MWH **
-- Byznys otázka: kolik stála každá hodina elektřiny v CZK/MWh? OTE má ceny v EUR, rozpočet je v CZK.
-- Jeden řádek = jedna hodina (43 848 řádků). View, ne uložený sloupec: kurz je uložený jen ve fact_fx.
-- LEFT JOIN na kurz: chybějící kurz by se ukázal jako NULL, místo aby hodina zmizela.

USE EnergyCrisisCostAnalysis
GO

CREATE OR ALTER VIEW dbo.vw_energy_prices_czk AS
	
	SELECT 
		p.date_key,
		p.hour_of_day,
		p.volume_mwh,
		p.price_eur_mwh,
		fx.rate_czk_per_eur,
		fx.rate_czk_per_eur * p.price_eur_mwh AS price_czk_mwh
	FROM dbo.fact_energy_prices p
	LEFT JOIN dbo.fact_fx fx ON p.date_key = fx.date_key 

GO

-- ** DAILY SUMMARY VIEW **
-- Business question: how much power did the company take each day and what did it cost?
-- One row = one day (1,827 rows). Only sums and counts, so days can be added into months and years
-- (a price is always sum / count, never an average of averages). Power only, load is SIMULATED.
-- CZ: ** VIEW S DENNÍM SOUHRNEM **
-- Byznys otázka: kolik elektřiny firma každý den odebrala a kolik to stálo?
-- Jeden řádek = jeden den (1 827 řádků). Jen součty a počty, aby šlo dny sčítat do měsíců a roků
-- (cena je vždy součet / počet, nikdy průměr průměrů). Jen silová elektřina, odběr je SIMULOVANÝ.

CREATE OR ALTER VIEW dbo.vw_daily_summary AS 

	SELECT
		ep.date_key,
		COUNT(*) AS hours_in_day,
		SUM(l.load_mwh) AS load_mwh,
		SUM(ep.price_eur_mwh) AS market_price_sum_eur,
		SUM(l.load_mwh * ep.price_eur_mwh) AS power_cost_eur,
		SUM(l.load_mwh * ep.price_czk_mwh) AS power_cost_czk
	FROM vw_energy_prices_czk ep
	JOIN dbo.fact_load l ON ep.date_key = l.date_key AND ep.hour_of_day = l.hour_of_day
	GROUP BY ep.date_key

GO

-- ** HOURLY COST VIEW **
-- Business question: what did the company pay for power in each hour, in EUR and in CZK?
-- Main fact table for Power BI: one row = one hour (43,848 rows). Costs are stored, the weighted price
-- is computed in Power BI as SUM(cost) / SUM(load). LEFT JOIN on the rate: no hour gets lost.
-- Power only (no distribution, taxes or VAT), load is SIMULATED.
-- CZ: ** VIEW S HODINOVÝM NÁKLADEM **
-- Byznys otázka: kolik firma zaplatila za silovou elektřinu v každé hodině, v EUR a v CZK?
-- Hlavní faktová tabulka pro Power BI: jeden řádek = jedna hodina (43 848 řádků). Ukládají se náklady, váženou
-- cenu počítá Power BI jako SUM(náklad) / SUM(odběr). LEFT JOIN na kurz: žádná hodina se neztratí.
-- Jen silová elektřina (bez distribuce, daní a DPH), odběr je SIMULOVANÝ.

CREATE OR ALTER VIEW dbo.vw_hourly_cost AS 
	
	SELECT
		ep.date_key,
		ep.hour_of_day,
		ep.price_eur_mwh,
		fx.rate_czk_per_eur,
		ep.price_eur_mwh * fx.rate_czk_per_eur AS price_czk_mwh,
		l.load_mwh,
		l.load_mwh * ep.price_eur_mwh AS power_cost_eur,
		l.load_mwh * ep.price_eur_mwh * fx.rate_czk_per_eur AS power_cost_czk
	FROM dbo.fact_energy_prices ep
	JOIN dbo.fact_load l ON ep.date_key = l.date_key AND ep.hour_of_day = l.hour_of_day
	LEFT JOIN dbo.fact_fx fx ON ep.date_key = fx.date_key

GO

-- ** YEARLY HEDGING INPUTS VIEW **
-- Business question: what would the power have cost if the company had fixed part of its yearly volume a year ahead?
-- One row = one year (2021-2024). The fixed share (0-100 %) is chosen by a slider in Power BI.
-- hedge_diff = how much more (+) or less (-) the whole yearly volume would cost at the fixed price
-- instead of the spot price, in EUR. Load is SIMULATED, the fixed price is an ASSUMPTION (ADR-003).
-- CZ: ** VIEW SE VSTUPY PRO ZAJIŠTĚNÍ **
-- Byznys otázka: kolik by stála elektřina, kdyby firma část ročního objemu zafixovala rok dopředu?
-- Jeden řádek = jeden rok (2021-2024). Zafixovaný podíl (0-100 %) se volí posuvníkem v Power BI.
-- hedge_diff = o kolik víc (+) nebo méně (-) by stál celý roční objem za zafixovanou cenu
-- místo spotové ceny, v EUR. Odběr je SIMULOVANÝ, zafixovaná cena je PŘEDPOKLAD (ADR-003).

CREATE OR ALTER VIEW dbo.vw_yearly_hedging AS

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

pxe_prices AS (
SELECT	2022 AS year, 221.88 AS pxe_price_eur_mwh
		UNION ALL
SELECT	2023, 241.98
		UNION ALL
SELECT	2024, 99.03 )

SELECT
	hp.year * 10000 + 101  AS date_key,
	hp.year,
	hp.volume_mwh,
	hp.spot_cost_eur,
	hp.market_price_eur_mwh,
	hp.hedge_price_eur_mwh,
	pxe.pxe_price_eur_mwh,
	hp.volume_mwh * (hp.hedge_price_eur_mwh - hp.market_price_eur_mwh) AS hedge_diff_proxy_eur,
	hp.volume_mwh * (pxe.pxe_price_eur_mwh - hp.market_price_eur_mwh) AS hedge_diff_pxe_eur
FROM with_hedge_price hp
LEFT JOIN pxe_prices pxe ON hp.year = pxe.year
WHERE hp.hedge_price_eur_mwh IS NOT NULL

GO

-- ** MONTHLY COST VIEW **
-- Business question: what did electricity really cost the company each month, all-in (power + regulated components)?
-- One row = one month (60 rows), date_key = first day of the month. Only costs in CZK, no prices:
-- Power BI computes the all-in price as SUM(total_cost) / SUM(load). Reserved capacity 5 MW = ASSUMPTION.
-- Load is SIMULATED; without supplier margin and VAT (ADR-005).
-- CZ: ** VIEW S MĚSÍČNÍM NÁKLADEM **
-- Byznys otázka: kolik firmu elektřina opravdu stála každý měsíc, se vším (silová + regulované složky)?
-- Jeden řádek = jeden měsíc (60 řádků), date_key = první den měsíce. Jen náklady v CZK, žádné ceny:
-- Power BI počítá cenu se vším jako SUM(celkový náklad) / SUM(odběr). Rezervovaná kapacita 5 MW = PŘEDPOKLAD.
-- Odběr je SIMULOVANÝ; bez marže obchodníka a DPH (ADR-005).


CREATE OR ALTER VIEW dbo.vw_monthly_cost AS
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
			SUM(CASE WHEN rp.component = 'reserved_capacity_yearly' THEN rp.value * 5 END) AS reserved_capacity_czk,
			SUM(CASE WHEN rp.component IN ('ote_imbalance_settlement', 'ote_res_admin') THEN rp.value END) AS ote_fees_czk,
			SUM(CASE WHEN rp.component = 'poze_per_mw' THEN rp.value * 5 END) AS poze_capacity_czk,
			SUM(CASE WHEN rp.component = 'poze_cap' THEN rp.value END) AS poze_cap_czk_mwh
	FROM [dbo].[dim_date] d
	JOIN [dbo].[regulated_price] rp ON d.full_date BETWEEN rp.valid_from AND rp.valid_to
	WHERE d.day_of_month = 1 AND rp.component IN ('reserved_capacity_yearly', 'ote_imbalance_settlement', 'ote_res_admin', 'poze_per_mw', 'poze_cap')
	GROUP BY d.year,d.month),

	monthly_cost AS (
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
		JOIN monthly_fixed mf ON mp.year = mf.year AND mp.month = mf.month)

SELECT
	year * 10000 + month * 100 + 1  AS date_key,
	year,
	month,
	load_mwh,
	power_cost_czk,
	electricity_tax_czk,
	network_use_czk,
	system_services_czk,
	reserved_capacity_czk,
	ote_fees_czk,
	poze_czk,
	power_cost_czk + electricity_tax_czk + network_use_czk + system_services_czk
		+ reserved_capacity_czk + ote_fees_czk + poze_czk AS total_cost_czk
FROM monthly_cost

GO

-- ** COST CHANGE STEPS VIEW **
-- Business question: why did the power cost change from the previous year - volume, market price, load profile or EUR/CZK rate?
-- One row = one year + one step (2021-2024 x 5 = 20 rows) for the waterfall on Power BI page 3.
-- Previous year cost + the 4 steps = this year's cost (difference of a few CZK from rounding the rate).
-- Method ADR-004 + ADR-006. Volume and load profile effects are SIMULATED.
-- CZ: ** VIEW S KROKY ZMĚNY NÁKLADU **
-- Byznys otázka: proč se náklad na silovou elektřinu změnil proti loňsku - objem, tržní cena, tvar odběru, nebo kurz?
-- Jeden řádek = jeden rok + jeden krok (2021-2024 x 5 = 20 řádků) pro vodopádový graf na stránce 3 v Power BI.
-- Loňský náklad + 4 kroky = letošní náklad (rozdíl pár korun ze zaokrouhlení kurzu).
-- Metoda ADR-004 + ADR-006. Vliv objemu a tvaru odběru je SIMULOVANÝ.


CREATE OR ALTER VIEW dbo.vw_cost_change_steps AS 

  WITH yearly AS (
      SELECT d.year,
             SUM(l.load_mwh) AS v,
             SUM(l.load_mwh * p.price_eur_mwh) AS c_eur,
             SUM(l.load_mwh * p.price_czk_mwh) AS c_czk,
             AVG(p.price_eur_mwh) AS pb
      FROM dbo.vw_energy_prices_czk p
      JOIN dbo.fact_load l ON l.date_key = p.date_key AND l.hour_of_day = p.hour_of_day
      JOIN dbo.dim_date d ON d.date_key = p.date_key
      GROUP BY d.year
  ), 
  
  derived AS (
      SELECT year, v, c_eur, c_czk, pb,
             c_eur / NULLIF(v, 0) AS pw,
             c_eur / NULLIF(v, 0) - pb AS s,
             c_czk / NULLIF(c_eur, 0) AS r
      FROM yearly
  ), 
  
  prev AS (
      SELECT *, 
			LAG(v) OVER (ORDER BY year) AS v0, 
			LAG(c_eur) OVER (ORDER BY year) AS c_eur0,
            LAG(c_czk) OVER (ORDER BY year) AS c_czk0,
			LAG(pb) OVER (ORDER BY year) AS pb0,
            LAG(pw) OVER (ORDER BY year) AS pw0,
			LAG(s) OVER (ORDER BY year) AS s0,
            LAG(r) OVER (ORDER BY year) AS r0
      FROM derived
  ),

  effects AS (
      SELECT year,
             c_czk0                 AS cost_prev_czk,
             (v - v0) * pw0 * r0    AS volume_czk,
             v * (pb - pb0) * r0    AS market_price_czk,
             v * (s - s0) * r0      AS load_profile_czk,
             c_eur * (r - r0)       AS rate_czk
      FROM prev
      WHERE v0 IS NOT NULL
  )

SELECT year * 10000 + 101 AS date_key, year, 1 AS step_order, 'Previous year cost' AS step_name, cost_prev_czk AS amount_czk FROM effects
UNION ALL
SELECT year * 10000 + 101 AS date_key, year, 2 AS step_order, 'Volume' AS step_name, volume_czk AS amount_czk FROM effects 
UNION ALL
SELECT year * 10000 + 101 AS date_key, year, 3 AS step_order, 'Market price' AS step_name, market_price_czk AS amount_czk FROM effects
UNION ALL
SELECT year * 10000 + 101 AS date_key, year, 4 AS step_order, 'Load profile' AS step_name, load_profile_czk AS amount_czk FROM effects 
UNION ALL
SELECT year * 10000 + 101 AS date_key, year, 5 AS step_order, 'Exchange rate' AS step_name, rate_czk AS amount_czk FROM effects 

GO
