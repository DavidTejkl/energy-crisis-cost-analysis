-- Business question: how much more expensive is electricity in peak hours than in offpeak
-- hours, and how did the gap change during the 2021-2023 energy crisis?
-- CZ: Byznysová otázka: o kolik je elektřina ve špičce (peak) dražší než mimo špičku
-- (offpeak) a jak se ten rozdíl měnil během energetické krize 2021-2023?

-- Peak = Monday-Friday, 08:00-20:00 (hour_of_day 9-20), the standard market definition of
-- the peak load product (PXE, EEX). Every other hour is offpeak.
-- CZ: Peak = pondělí-pátek, 08:00-20:00 (hour_of_day 9-20), standardní tržní definice
-- produktu peak load (PXE, EEX). Všechny ostatní hodiny jsou offpeak.

-- ASSUMPTION: public holidays on weekdays count as peak, because dim_date has no holiday flag.
-- CZ: PŘEDPOKLAD: státní svátky ve všední den se počítají jako peak, protože dim_date
-- nemá příznak svátku.

-- Simple AVG is correct here: market peak / offpeak prices give every hour the same weight
-- (a product delivers the same MW in every hour). Company cost uses a load-weighted price (08).
-- CZ: Prostý AVG je tady správně: tržní ceny peak / offpeak dávají každé hodině stejnou váhu
-- (produkt dodává stejný výkon v každé hodině). Náklad firmy používá cenu váženou odběrem (08).

-- Source: vw_energy_prices_czk + dim_date. One result row = year + peak / offpeak.
-- Check: peak hours = weekdays x 12 (3,144 / 3,132 / 3,120 / 3,120 / 3,144).
-- CZ: Zdroj: vw_energy_prices_czk + dim_date. Jeden řádek výsledku = rok + peak / offpeak.
-- Kontrola: peak hodin = pracovní dny x 12 (3 144 / 3 132 / 3 120 / 3 120 / 3 144).

USE [EnergyCrisisCostAnalysis]
GO

SELECT	d.year,
		COUNT(*) AS count_of_hours,
		CASE 
			WHEN hour_of_day BETWEEN 9 AND 20 AND is_weekend=0 THEN 'peak'
			ELSE 'offpeak' END AS peak_offpeak,
		AVG(price_eur_mwh) AS avg_price_eur_mwh,
		AVG(price_czk_mwh) AS avg_price_czk_mwh
FROM vw_energy_prices_czk ep
JOIN dim_date d ON ep.date_key = d.date_key
GROUP BY d.year,CASE 
			WHEN hour_of_day BETWEEN 9 AND 20 AND is_weekend=0 THEN 'peak'
			ELSE 'offpeak' END 
ORDER BY d.year,peak_offpeak

