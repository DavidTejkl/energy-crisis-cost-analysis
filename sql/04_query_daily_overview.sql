-- Business question: how did the daily power price and the EUR/CZK rate move over time?
-- One row per day (1,827 rows for 2020-2024).
-- avg prices = simple average of the hours (base price of the day)
-- traded_value_czk = sum of volume * price, total value traded on the day
-- hours_in_day is 23 or 25 on DST days, so volume is lower/higher on those days

USE [EnergyCrisisCostAnalysis]
GO

SELECT 
		vp.date_key,
		d.full_date,
		d.weekday_name,
		d.is_weekend,
		COUNT(vp.hour_of_day) as hours_in_day,
		vp.rate_czk_per_eur,
		SUM(vp.volume_mwh) as volume_mwh_per_day,
		AVG(vp.price_eur_mwh) as avg_eur_price_per_day,
		AVG(vp.price_czk_mwh) as avg_czk_price_per_day,
		MIN(vp.price_czk_mwh) as min_price_czk,
		MAX(vp.price_czk_mwh) as max_price_czk,
		SUM(vp.volume_mwh * vp.price_czk_mwh) as traded_value_czk
FROM dbo.vw_energy_prices_czk vp
	JOIN dbo.dim_date d 
	ON vp.date_key = d.date_key
GROUP BY vp.date_key,d.full_date,d.weekday_name,d.is_weekend,vp.rate_czk_per_eur
ORDER BY vp.date_key;


