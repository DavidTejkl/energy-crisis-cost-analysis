-- ** CZK/MWH ENERGY PRICES VIEW **
-- Business question: what did each hour of electricity cost in CZK/MWh? 
-- The CFO's budget is in CZK, but OTE publishes prices in EUR, 
-- so every later analysis (price bands, price shocks, top hours) needs the CZK price.

-- Why a view and not a stored column: the exchange rate lives only in fact_fx. 
-- If a rate is ever corrected, the CZK price updates automatically.

-- Why LEFT JOIN: fact_fx has a rate for every calendar day (ADR-001),
-- so INNER JOIN would return the same 43,848 rows. 
-- LEFT JOIN is safer: if a rate were ever missing, the hour would show NULL instead of disappearing.


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


