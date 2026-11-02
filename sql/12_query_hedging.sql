-- Business question: could the company have hedged the energy crisis - what would the power
-- cost have been with 0 / 25 / 50 / 75 / 100 % of the yearly volume fixed in advance?
-- CZ: Byznysová otázka: mohla se firma proti energetické krizi zajistit - kolik by stála silová
-- elektřina při 0 / 25 / 50 / 75 / 100 % ročního objemu zafixovaného dopředu?

-- Method: ADR-003. The fixed part is a base load contract (same power in every hour). Hours where
-- the load is above the block are bought on the spot market, hours below it are sold back, so:
--   hedged cost = C + share x V x (Ph - Pb)
-- C = spot cost SUM(load x price), V = volume, Pb = simple average spot price of the year,
-- Ph = hedge price. fixed_part = share x V x Ph, spot_part = the rest.
-- CZ: Metoda: ADR-003. Zafixovaná část je pásmo (base load, stejný výkon v každé hodině). Hodiny,
-- kdy je odběr nad pásmem, se dokoupí na spotu, hodiny pod ním se prodají zpět, takže:
--   náklad se zajištěním = C + podíl x V x (Ph - Pb)
-- C = spotový náklad SUM(odběr x cena), V = objem, Pb = prostý průměr spotové ceny roku,
-- Ph = cena zajištění. fixed_part = podíl x V x Ph, spot_part = zbytek.

-- Two hedge prices: Ph = simple spot average of the prior year (proxy, ASSUMPTION, no look-ahead)
-- and the PXE CZ CAL base last trade of the prior year.
-- CZ: Dvě ceny zajištění: Ph = prostý průměr spotu předchozího roku (proxy, PŘEDPOKLAD, bez
-- pohledu do budoucnosti) a poslední obchod PXE CZ CAL base v předchozím roce.

-- Source: fact_energy_prices + fact_load (joined on date_key + hour_of_day) + dim_date, in EUR.
-- One result row = one year + one hedge share (2021-2024 x 5 shares = 20 rows); 2020 has no
-- prior year and is removed after the LAG.
-- Check: at 0 % both hedged costs equal spot_cost_eur; at 100 % spot_part_eur equals
-- C - V x Pb of query 10 (2022: 483,332.58 EUR).
-- CZ: Zdroj: fact_energy_prices + fact_load (spojené přes date_key + hour_of_day) + dim_date, v EUR.
-- Jeden řádek výsledku = jeden rok + jeden podíl zajištění (2021-2024 x 5 podílů = 20 řádků);
-- 2020 nemá předchozí rok a vyřadí se až po LAG.
-- Kontrola: při 0 % se oba náklady se zajištěním rovnají spot_cost_eur; při 100 % se
-- spot_part_eur rovná C - V x Pb z dotazu 10 (2022: 483 332,58 EUR).

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
				),

-- PXE CZ CAL base, last trade of the prior year, ADR-003
pxe_prices AS (
SELECT	2022 AS year, 221.88 AS pxe_price_eur_mwh
		UNION ALL
SELECT	2023, 241.98
		UNION ALL
SELECT	2024, 99.03 )

SELECT
		hp.year,
		s.hedge_share,
		hp.spot_cost_eur,
		hp.hedge_price_eur_mwh,
		hp.market_price_eur_mwh,
		spot_cost_eur + hedge_share * volume_mwh * (hedge_price_eur_mwh - market_price_eur_mwh) AS hedged_cost_eur,
		hedge_share * volume_mwh * hedge_price_eur_mwh AS fixed_part_eur,
		(spot_cost_eur + hedge_share * volume_mwh * (hedge_price_eur_mwh - market_price_eur_mwh)) -
		(hedge_share * volume_mwh * hedge_price_eur_mwh) AS  spot_part_eur,
		px.pxe_price_eur_mwh,
		spot_cost_eur + hedge_share * volume_mwh * (pxe_price_eur_mwh - market_price_eur_mwh) AS hedged_cost_pxe_eur
FROM with_hedge_price hp
CROSS JOIN hedge_shares s
LEFT JOIN pxe_prices px ON hp.year = px.year
WHERE hedge_price_eur_mwh IS NOT NULL
ORDER BY hp.year,hedge_share