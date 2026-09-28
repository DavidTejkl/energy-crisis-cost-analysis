-- Business question: can the loaded data be trusted before any cost analysis runs on it?
-- Data quality checks for all 5 tables. Every check returns numbers next to the expected value;
-- results are written up in docs/data_quality_report.md.
-- Expected values come from the source profiling (docs/01_project_brief.md).

USE [EnergyCrisisCostAnalysis];
SET NOCOUNT ON;

-- =====================================================================
-- fact_energy_prices  (grain: one delivery day + one hour of that day)
-- =====================================================================

-- P01 Volume: rows per year (expected 8,784 / 8,760 / 8,760 / 8,760 / 8,784 = 43,848)
SELECT 'P01 rows per year' AS check_id, d.year, COUNT(*) AS row_count
FROM dbo.fact_energy_prices AS p
JOIN dbo.dim_date AS d ON d.date_key = p.date_key
GROUP BY d.year
ORDER BY d.year;

-- P02 Coverage: how many days have 23 / 24 / 25 hours (expected 5 / 1,817 / 5)
WITH hours_per_day AS (
    SELECT date_key, COUNT(*) AS hours_in_day
    FROM dbo.fact_energy_prices
    GROUP BY date_key
)
SELECT 'P02 days by hour count' AS check_id, hours_in_day, COUNT(*) AS day_count
FROM hours_per_day
GROUP BY hours_in_day
ORDER BY hours_in_day;

-- P03 DST days: every non-24-hour day must be the last Sunday of March (23 h) or October (25 h)
WITH hours_per_day AS (
    SELECT date_key, COUNT(*) AS hours_in_day
    FROM dbo.fact_energy_prices
    GROUP BY date_key
)
SELECT 'P03 DST days' AS check_id, d.full_date, d.weekday_name, h.hours_in_day,
       CASE WHEN d.weekday_num = 7 AND d.day_of_month >= 25
                 AND ((d.month = 3 AND h.hours_in_day = 23) OR (d.month = 10 AND h.hours_in_day = 25))
            THEN 'OK' ELSE 'WRONG' END AS dst_check
FROM hours_per_day AS h
JOIN dbo.dim_date AS d ON d.date_key = h.date_key
WHERE h.hours_in_day <> 24
ORDER BY d.full_date;

-- P04 Gaps inside a day: hours must run 1..n without holes (expected 0 days with a gap)
-- A day has no gap when its first hour is 1 and its last hour equals the number of hours.
WITH day_hours AS (
    SELECT date_key, MIN(hour_of_day) AS first_hour, MAX(hour_of_day) AS last_hour, COUNT(*) AS hours_in_day
    FROM dbo.fact_energy_prices
    GROUP BY date_key
)
SELECT 'P04 days with hour gaps' AS check_id, COUNT(*) AS day_count
FROM day_hours
WHERE first_hour <> 1 OR last_hour <> hours_in_day;

-- P05 Calendar days without any price row (expected 0)
SELECT 'P05 dim_date days without prices' AS check_id, COUNT(*) AS day_count
FROM dbo.dim_date AS d
LEFT JOIN dbo.fact_energy_prices AS p ON p.date_key = d.date_key
WHERE p.date_key IS NULL;

-- P06 Grain uniqueness: duplicate date_key + hour_of_day (expected 0; the PK also enforces it)
SELECT 'P06 duplicate grain keys' AS check_id, COUNT(*) AS duplicate_count
FROM (
    SELECT date_key, hour_of_day
    FROM dbo.fact_energy_prices
    GROUP BY date_key, hour_of_day
    HAVING COUNT(*) > 1
) AS dup;

-- P07 Completeness: NULL price or volume (expected 0 / 0)
SELECT 'P07 NULL values' AS check_id,
       SUM(CASE WHEN price_eur_mwh IS NULL THEN 1 ELSE 0 END) AS null_price,
       SUM(CASE WHEN volume_mwh IS NULL THEN 1 ELSE 0 END) AS null_volume
FROM dbo.fact_energy_prices;

-- P08 Validity: price range and prices outside the sanity range -500 .. 5,000 EUR/MWh (expected 0)
-- Volume must be positive: the market always clears some volume.
SELECT 'P08 ranges' AS check_id,
       MIN(price_eur_mwh) AS min_price, MAX(price_eur_mwh) AS max_price,
       SUM(CASE WHEN price_eur_mwh < -500 OR price_eur_mwh > 5000 THEN 1 ELSE 0 END) AS price_out_of_range,
       MIN(volume_mwh) AS min_volume, MAX(volume_mwh) AS max_volume,
       SUM(CASE WHEN volume_mwh <= 0 THEN 1 ELSE 0 END) AS volume_not_positive
FROM dbo.fact_energy_prices;

-- P09 Negative prices per year (expected 119 / 33 / 8 / 134 / 315 = 609) - valid market outcome, not an error
SELECT 'P09 negative price hours' AS check_id, d.year,
       SUM(CASE WHEN p.price_eur_mwh < 0 THEN 1 ELSE 0 END) AS negative_hours,
       SUM(CASE WHEN p.price_eur_mwh = 0 THEN 1 ELSE 0 END) AS zero_hours
FROM dbo.fact_energy_prices AS p
JOIN dbo.dim_date AS d ON d.date_key = p.date_key
GROUP BY d.year
ORDER BY d.year;

-- P10 Referential integrity: fact keys missing in the dimensions (expected 0 / 0; the FKs also enforce it)
SELECT 'P10 orphan keys' AS check_id,
       SUM(CASE WHEN d.date_key IS NULL THEN 1 ELSE 0 END) AS orphan_date_key,
       SUM(CASE WHEN h.hour_of_day IS NULL THEN 1 ELSE 0 END) AS orphan_hour
FROM dbo.fact_energy_prices AS p
LEFT JOIN dbo.dim_date AS d ON d.date_key = p.date_key
LEFT JOIN dbo.dim_hour AS h ON h.hour_of_day = p.hour_of_day;

-- P11 Distribution: yearly price statistics - the crisis should be visible, not hidden by an error
SELECT 'P11 price by year' AS check_id, d.year,
       MIN(p.price_eur_mwh) AS min_price,
       CAST(AVG(p.price_eur_mwh) AS DECIMAL(7,2)) AS avg_price,
       MAX(p.price_eur_mwh) AS max_price,
       CAST(STDEV(p.price_eur_mwh) AS DECIMAL(7,2)) AS stdev_price
FROM dbo.fact_energy_prices AS p
JOIN dbo.dim_date AS d ON d.date_key = p.date_key
GROUP BY d.year
ORDER BY d.year;

-- P12 Outliers: the 5 most expensive hours - must match known crisis dates (August 2022)
SELECT TOP (5) 'P12 top prices' AS check_id, d.full_date, p.hour_of_day, p.price_eur_mwh
FROM dbo.fact_energy_prices AS p
JOIN dbo.dim_date AS d ON d.date_key = p.date_key
ORDER BY p.price_eur_mwh DESC, d.full_date;

-- =====================================================================
-- fact_fx  (grain: one calendar day; weekends and holidays forward-filled, ADR-001)
-- =====================================================================

-- F01 Volume and coverage: one row per calendar day, actual vs filled rates
-- (expected 1,827 rows, 1,257 actual ČNB rates, 570 filled days)
SELECT 'F01 rows' AS check_id,
       COUNT(*) AS row_count,
       SUM(CASE WHEN is_actual_rate = 1 THEN 1 ELSE 0 END) AS actual_rates,
       SUM(CASE WHEN is_actual_rate = 0 THEN 1 ELSE 0 END) AS filled_rates
FROM dbo.fact_fx;

-- F02 Calendar days without a rate (expected 0)
SELECT 'F02 dim_date days without rate' AS check_id, COUNT(*) AS day_count
FROM dbo.dim_date AS d
LEFT JOIN dbo.fact_fx AS f ON f.date_key = d.date_key
WHERE f.date_key IS NULL;

-- F03 Fill rule consistency (expected 0 / 0 / 0):
-- an actual rate comes from its own day, a filled rate from an earlier day, never more than 4 days back
-- (4 days = the longest ČNB gap around Easter or Christmas).
SELECT 'F03 fill rule' AS check_id,
       SUM(CASE WHEN f.is_actual_rate = 1 AND f.source_date <> d.full_date THEN 1 ELSE 0 END) AS actual_wrong_source,
       SUM(CASE WHEN f.is_actual_rate = 0 AND f.source_date >= d.full_date THEN 1 ELSE 0 END) AS filled_not_earlier,
       SUM(CASE WHEN DATEDIFF(day, f.source_date, d.full_date) > 4 THEN 1 ELSE 0 END) AS fill_older_than_4_days,
       MAX(DATEDIFF(day, f.source_date, d.full_date)) AS max_fill_days
FROM dbo.fact_fx AS f
JOIN dbo.dim_date AS d ON d.date_key = f.date_key;

-- F04 Filled days by weekday: weekends dominate, weekday fills are public holidays
SELECT 'F04 filled days by weekday' AS check_id, d.weekday_num, COUNT(*) AS filled_days
FROM dbo.fact_fx AS f
JOIN dbo.dim_date AS d ON d.date_key = f.date_key
WHERE f.is_actual_rate = 0
GROUP BY d.weekday_num
ORDER BY d.weekday_num;

-- F05 Actual rates on weekends (expected 0 - ČNB does not publish on Saturday or Sunday)
SELECT 'F05 actual rate on weekend' AS check_id, COUNT(*) AS row_count
FROM dbo.fact_fx AS f
JOIN dbo.dim_date AS d ON d.date_key = f.date_key
WHERE f.is_actual_rate = 1 AND d.is_weekend = 1;

-- F06 Ranges and NULLs per year (plausible EUR/CZK band 20 - 30)
SELECT 'F06 rate by year' AS check_id, d.year,
       MIN(f.rate_czk_per_eur) AS min_rate,
       CAST(AVG(f.rate_czk_per_eur) AS DECIMAL(5,3)) AS avg_rate,
       MAX(f.rate_czk_per_eur) AS max_rate,
       SUM(CASE WHEN f.rate_czk_per_eur IS NULL THEN 1 ELSE 0 END) AS null_rate,
       SUM(CASE WHEN f.rate_czk_per_eur NOT BETWEEN 20 AND 30 THEN 1 ELSE 0 END) AS out_of_band
FROM dbo.fact_fx AS f
JOIN dbo.dim_date AS d ON d.date_key = f.date_key
GROUP BY d.year
ORDER BY d.year;

-- F07 Jumps: largest day-to-day change of the actual rates (a jump over 3 % would suggest a parsing error)
WITH actual AS (
    SELECT source_date, rate_czk_per_eur,
           LAG(rate_czk_per_eur) OVER (ORDER BY source_date) AS prev_rate
    FROM dbo.fact_fx
    WHERE is_actual_rate = 1
)
SELECT TOP (3) 'F07 largest daily change' AS check_id, source_date, prev_rate, rate_czk_per_eur,
       CAST(100.0 * (rate_czk_per_eur - prev_rate) / prev_rate AS DECIMAL(5,2)) AS change_pct
FROM actual
WHERE prev_rate IS NOT NULL
ORDER BY ABS(rate_czk_per_eur - prev_rate) DESC;

-- F08 Cross-check with the ČNB 2022 file anomaly: rates around 2 March 2022 (repeated header row in bronze)
SELECT 'F08 rates around 2022-03-02' AS check_id, d.full_date, f.rate_czk_per_eur, f.is_actual_rate, f.source_date
FROM dbo.fact_fx AS f
JOIN dbo.dim_date AS d ON d.date_key = f.date_key
WHERE d.full_date BETWEEN '2022-02-28' AND '2022-03-04'
ORDER BY d.full_date;

-- =====================================================================
-- repo_rate  (grain: one validity period of the ČNB 2-week repo rate)
-- =====================================================================

-- R01 Volume and span (expected 22 periods, 2019-05-03 to 2024-12-31)
SELECT 'R01 periods' AS check_id, COUNT(*) AS period_count,
       MIN(valid_from) AS first_from, MAX(valid_to) AS last_to,
       MIN(repo_rate_pct) AS min_rate, MAX(repo_rate_pct) AS max_rate
FROM dbo.repo_rate;

-- R02 Gaps and overlaps: each period must start the day after the previous one ends (expected 0 / 0)
WITH ordered AS (
    SELECT valid_from, valid_to,
           LAG(valid_to) OVER (ORDER BY valid_from) AS prev_to
    FROM dbo.repo_rate
)
SELECT 'R02 gaps and overlaps' AS check_id,
       SUM(CASE WHEN DATEDIFF(day, prev_to, valid_from) > 1 THEN 1 ELSE 0 END) AS gaps,
       SUM(CASE WHEN DATEDIFF(day, prev_to, valid_from) < 1 THEN 1 ELSE 0 END) AS overlaps
FROM ordered
WHERE prev_to IS NOT NULL;

-- R03 Coverage: calendar days with no valid repo rate or more than one (expected 0 / 0)
WITH rate_per_day AS (
    SELECT d.date_key, COUNT(r.valid_from) AS rate_count
    FROM dbo.dim_date AS d
    LEFT JOIN dbo.repo_rate AS r ON d.full_date BETWEEN r.valid_from AND r.valid_to
    GROUP BY d.date_key
)
SELECT 'R03 days by rate count' AS check_id,
       SUM(CASE WHEN rate_count = 0 THEN 1 ELSE 0 END) AS days_without_rate,
       SUM(CASE WHEN rate_count > 1 THEN 1 ELSE 0 END) AS days_with_two_rates
FROM rate_per_day;

-- =====================================================================
-- dim_date and dim_hour
-- =====================================================================

-- D01 dim_date: every calendar day 2020-01-01 .. 2024-12-31 exactly once (expected 1,827 rows = 1,827 days)
SELECT 'D01 dim_date span' AS check_id, COUNT(*) AS row_count,
       MIN(full_date) AS first_date, MAX(full_date) AS last_date,
       DATEDIFF(day, MIN(full_date), MAX(full_date)) + 1 AS calendar_days
FROM dbo.dim_date;

-- D02 dim_date: derived columns agree with full_date (expected 0 for each)
SELECT 'D02 dim_date consistency' AS check_id,
       SUM(CASE WHEN date_key <> YEAR(full_date) * 10000 + MONTH(full_date) * 100 + DAY(full_date) THEN 1 ELSE 0 END) AS wrong_key,
       SUM(CASE WHEN year <> YEAR(full_date) OR month <> MONTH(full_date) OR day_of_month <> DAY(full_date) THEN 1 ELSE 0 END) AS wrong_parts,
       SUM(CASE WHEN quarter <> DATEPART(quarter, full_date) THEN 1 ELSE 0 END) AS wrong_quarter,
       SUM(CASE WHEN week_of_year <> DATEPART(iso_week, full_date) THEN 1 ELSE 0 END) AS wrong_iso_week,
       SUM(CASE WHEN is_weekend <> CASE WHEN weekday_num IN (6, 7) THEN 1 ELSE 0 END THEN 1 ELSE 0 END) AS wrong_weekend
FROM dbo.dim_date;

-- D03 dim_date: weekday_num against a known Monday (2020-01-06); 1 = Monday .. 7 = Sunday (expected 0)
SELECT 'D03 dim_date weekday' AS check_id,
       SUM(CASE WHEN weekday_num <> (DATEDIFF(day, '2020-01-06', full_date) % 7 + 7) % 7 + 1 THEN 1 ELSE 0 END) AS wrong_weekday
FROM dbo.dim_date;

-- D04 dim_hour: hours 1..25 exactly once, label per time of day
SELECT 'D04 dim_hour' AS check_id, time_of_day, COUNT(*) AS hour_count,
       MIN(hour_of_day) AS first_hour, MAX(hour_of_day) AS last_hour
FROM dbo.dim_hour
GROUP BY time_of_day
ORDER BY MIN(hour_of_day);
