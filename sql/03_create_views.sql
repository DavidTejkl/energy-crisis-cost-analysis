-- ** CZK/MWH ENERGY PRICES VIEW **
-- Business question: what did each hour of electricity cost in CZK/MWh? 
-- The CFO's budget is in CZK, but OTE publishes prices in EUR, 
-- so every later analysis (price bands, price shocks, top hours) needs the CZK price.
-- CZ: ** VIEW S CENAMI ENERGIE V CZK/MWH **
-- Byznys otázka: kolik stála každá hodina elektřiny v CZK/MWh?
-- Rozpočet finančního ředitele je v korunách, ale OTE zveřejňuje ceny v EUR,
-- proto každá další analýza (cenová pásma, cenové šoky, nejdražší hodiny) potřebuje cenu v CZK.

-- Why a view and not a stored column: the exchange rate lives only in fact_fx. 
-- If a rate is ever corrected, the CZK price updates automatically.
-- CZ: Proč view a ne uložený sloupec: kurz je uložený jen ve fact_fx.
-- Když se kurz někdy opraví, cena v CZK se přepočítá automaticky.

-- Why LEFT JOIN: fact_fx has a rate for every calendar day (ADR-001),
-- so INNER JOIN would return the same 43,848 rows. 
-- LEFT JOIN is safer: if a rate were ever missing, the hour would show NULL instead of disappearing.
-- CZ: Proč LEFT JOIN: fact_fx má kurz pro každý kalendářní den (ADR-001),
-- takže INNER JOIN by vrátil stejných 43 848 řádků.
-- LEFT JOIN je bezpečnější: kdyby kurz někdy chyběl, hodina by ukázala NULL, místo aby zmizela.


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
-- Source for Power BI: one row = one day (1,827 rows). Load is SIMULATED (docs/methodology.md).
-- CZ: ** VIEW S DENNÍM SOUHRNEM **
-- Byznys otázka: kolik elektřiny firma každý den odebrala a kolik to stálo?
-- Zdroj pro Power BI: jeden řádek = jeden den (1 827 řádků). Odběr je SIMULOVANÝ (docs/methodology.md).

-- Only additive columns (sums and counts), so Power BI can add days into months and years.
-- Prices are computed in Power BI as sum / count, never stored as an average (no average of averages):
-- market_price_sum_eur is only the numerator of the simple average price, use it with hours_in_day.
-- CZ: Jen sčitatelné sloupce (součty a počty), aby Power BI mohlo sčítat dny do měsíců a roků.
-- Ceny se počítají v Power BI jako součet / počet, nikdy se neukládají jako průměr (žádný průměr průměrů):
-- market_price_sum_eur je jen čitatel prostého průměru ceny, používá se spolu s hours_in_day.

-- power_cost_eur / power_cost_czk = power (commodity) only: hourly load x day-ahead OTE price,
-- summed per day. Without regulated components (query 08), supplier margin and VAT (ADR-005).
-- CZ: power_cost_eur / power_cost_czk = jen silová elektřina: hodinový odběr x cena denního trhu OTE,
-- sečtená za den. Bez regulovaných složek (dotaz 08), marže obchodníka a DPH (ADR-005).

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


