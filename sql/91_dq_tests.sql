-- Business question: can the loaded data be trusted before any cost analysis runs on it?
-- Data quality checks for all 7 tables. Every check returns numbers next to the expected value;
-- results are written up in docs/data_quality_report.md.
-- Expected values come from the source profiling (docs/01_project_brief.md).
-- Checks with a pass/fail rule (expected 0) are stored in dq_results (sql/90_etl_infrastructure.sql),
-- one row per check with the same run_at, and listed at the end; descriptive checks are only displayed.
-- CZ: Byznys otázka: dá se nahraným datům věřit dřív, než nad nimi poběží jakákoli analýza nákladů?
-- Kontroly kvality dat pro všech 7 tabulek. Každá kontrola vrací čísla vedle očekávané hodnoty;
-- výsledky jsou sepsané v docs/data_quality_report.md.
-- Očekávané hodnoty pocházejí z profilování zdroje (docs/01_project_brief.md).
-- Kontroly s pravidlem pass/fail (očekáváno 0) se ukládají do dq_results (sql/90_etl_infrastructure.sql),
-- jeden řádek na kontrolu se stejným run_at, a na konci se vypíšou; popisné kontroly se jen zobrazí.

USE [EnergyCrisisCostAnalysis];
SET NOCOUNT ON;

-- One timestamp for the whole run, so all results of one run can be selected together.
-- CZ: Jeden čas pro celý běh, aby šly všechny výsledky jednoho běhu vybrat najednou.
DECLARE @run_at datetime2(0) = SYSDATETIME();

-- =====================================================================
-- fact_energy_prices  (grain: one delivery day + one hour of that day)
-- CZ: fact_energy_prices  (grain: jeden den dodávky + jedna hodina toho dne)
-- =====================================================================

-- P01 Volume: rows per year (expected 8,784 / 8,760 / 8,760 / 8,760 / 8,784 = 43,848)
-- CZ: P01 Objem: řádky za rok (očekáváno 8 784 / 8 760 / 8 760 / 8 760 / 8 784 = 43 848)
SELECT 'P01 rows per year' AS check_id, d.year, COUNT(*) AS row_count
FROM dbo.fact_energy_prices AS p
JOIN dbo.dim_date AS d ON d.date_key = p.date_key
GROUP BY d.year
ORDER BY d.year;

-- P02 Coverage: how many days have 23 / 24 / 25 hours (expected 5 / 1,817 / 5)
-- CZ: P02 Pokrytí: kolik dní má 23 / 24 / 25 hodin (očekáváno 5 / 1 817 / 5)
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
-- CZ: P03 Dny změny času: každý den, který nemá 24 hodin, musí být poslední neděle března (23 h) nebo října (25 h)
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
-- CZ: P04 Mezery uvnitř dne: hodiny musí jít 1..n bez děr (očekáváno 0 dní s mezerou)
-- Den nemá mezeru, když je jeho první hodina 1 a poslední hodina se rovná počtu hodin.
WITH day_hours AS (
    SELECT date_key, MIN(hour_of_day) AS first_hour, MAX(hour_of_day) AS last_hour, COUNT(*) AS hours_in_day
    FROM dbo.fact_energy_prices
    GROUP BY date_key
),
result AS (
    SELECT COUNT(*) AS failed_rows
    FROM day_hours
    WHERE first_hour <> 1 OR last_hour <> hours_in_day
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'P04', 'days with hour gaps', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- P05 Calendar days without any price row (expected 0)
-- CZ: P05 Kalendářní dny bez jakéhokoli řádku s cenou (očekáváno 0)
WITH result AS (
    SELECT COUNT(*) AS failed_rows
    FROM dbo.dim_date AS d
    LEFT JOIN dbo.fact_energy_prices AS p ON p.date_key = d.date_key
    WHERE p.date_key IS NULL
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'P05', 'dim_date days without prices', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- P06 Grain uniqueness: duplicate date_key + hour_of_day (expected 0; the PK also enforces it)
-- CZ: P06 Jedinečnost grainu: duplicitní date_key + hour_of_day (očekáváno 0; vynucuje to i PK)
WITH result AS (
    SELECT COUNT(*) AS failed_rows
    FROM (
        SELECT date_key, hour_of_day
        FROM dbo.fact_energy_prices
        GROUP BY date_key, hour_of_day
        HAVING COUNT(*) > 1
    ) AS dup
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'P06', 'duplicate grain keys', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- P07 Completeness: NULL price or volume (expected 0)
-- COALESCE: SUM over an empty table returns NULL, which would not count as a failure.
-- CZ: P07 Úplnost: NULL cena nebo objem (očekáváno 0)
-- CZ: COALESCE: SUM nad prázdnou tabulkou vrátí NULL, což by se nepočítalo jako chyba.
WITH result AS (
    SELECT COALESCE(SUM(CASE WHEN price_eur_mwh IS NULL OR volume_mwh IS NULL THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM dbo.fact_energy_prices
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'P07', 'NULL price or volume', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- P08 Validity: prices outside the sanity range -500 .. 5,000 EUR/MWh or volume not positive (expected 0)
-- Volume must be positive: the market always clears some volume. Min / max per year are shown in P11.
-- CZ: P08 Platnost: ceny mimo rozumný rozsah -500 .. 5 000 EUR/MWh nebo objem není kladný (očekáváno 0)
-- Objem musí být kladný: trh vždy zobchoduje nějaký objem. Min / max za rok ukazuje P11.
WITH result AS (
    SELECT COALESCE(SUM(CASE WHEN price_eur_mwh < -500 OR price_eur_mwh > 5000 OR volume_mwh <= 0
                             THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM dbo.fact_energy_prices
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'P08', 'price or volume out of range', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- P09 Negative prices per year (expected 119 / 33 / 8 / 134 / 315 = 609) - valid market outcome, not an error
-- CZ: P09 Záporné ceny za rok (očekáváno 119 / 33 / 8 / 134 / 315 = 609) - platný výsledek trhu, ne chyba
SELECT 'P09 negative price hours' AS check_id, d.year,
       SUM(CASE WHEN p.price_eur_mwh < 0 THEN 1 ELSE 0 END) AS negative_hours,
       SUM(CASE WHEN p.price_eur_mwh = 0 THEN 1 ELSE 0 END) AS zero_hours
FROM dbo.fact_energy_prices AS p
JOIN dbo.dim_date AS d ON d.date_key = p.date_key
GROUP BY d.year
ORDER BY d.year;

-- Stored as WARN, not FAIL: negative prices are kept on purpose (docs/data_quality_report.md).
-- CZ: Uloženo jako WARN, ne FAIL: záporné ceny se záměrně ponechávají (docs/data_quality_report.md).
WITH result AS (
    SELECT COALESCE(SUM(CASE WHEN price_eur_mwh < 0 THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM dbo.fact_energy_prices
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'P09', 'negative price hours (valid, flagged)', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'WARN' END
FROM result;

-- P10 Referential integrity: fact keys missing in the dimensions (expected 0; the FKs also enforce it)
-- CZ: P10 Referenční integrita: klíče faktu chybějící v dimenzích (očekáváno 0; vynucují to i FK)
WITH result AS (
    SELECT COALESCE(SUM(CASE WHEN d.date_key IS NULL OR h.hour_of_day IS NULL THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM dbo.fact_energy_prices AS p
    LEFT JOIN dbo.dim_date AS d ON d.date_key = p.date_key
    LEFT JOIN dbo.dim_hour AS h ON h.hour_of_day = p.hour_of_day
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'P10', 'orphan keys', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- P11 Distribution: yearly price statistics - the crisis should be visible, not hidden by an error
-- CZ: P11 Rozdělení: roční statistiky cen - krize má být vidět, ne schovaná za chybou
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
-- CZ: P12 Odlehlé hodnoty: 5 nejdražších hodin - musí odpovídat známým datům krize (srpen 2022)
SELECT TOP (5) 'P12 top prices' AS check_id, d.full_date, p.hour_of_day, p.price_eur_mwh
FROM dbo.fact_energy_prices AS p
JOIN dbo.dim_date AS d ON d.date_key = p.date_key
ORDER BY p.price_eur_mwh DESC, d.full_date;

-- =====================================================================
-- fact_fx  (grain: one calendar day; weekends and holidays forward-filled, ADR-001)
-- CZ: fact_fx  (grain: jeden kalendářní den; víkendy a svátky doplněné dopředu, ADR-001)
-- =====================================================================

-- F01 Volume and coverage: one row per calendar day, actual vs filled rates
-- (expected 1,827 rows, 1,257 actual ČNB rates, 570 filled days)
-- CZ: F01 Objem a pokrytí: jeden řádek na kalendářní den, skutečné vs. doplněné kurzy
-- (očekáváno 1 827 řádků, 1 257 skutečných kurzů ČNB, 570 doplněných dní)
SELECT 'F01 rows' AS check_id,
       COUNT(*) AS row_count,
       SUM(CASE WHEN is_actual_rate = 1 THEN 1 ELSE 0 END) AS actual_rates,
       SUM(CASE WHEN is_actual_rate = 0 THEN 1 ELSE 0 END) AS filled_rates
FROM dbo.fact_fx;

-- F02 Calendar days without a rate (expected 0)
-- CZ: F02 Kalendářní dny bez kurzu (očekáváno 0)
WITH result AS (
    SELECT COUNT(*) AS failed_rows
    FROM dbo.dim_date AS d
    LEFT JOIN dbo.fact_fx AS f ON f.date_key = d.date_key
    WHERE f.date_key IS NULL
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'F02', 'dim_date days without rate', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- F03 Fill rule consistency (expected 0 / 0 / 0):
-- an actual rate comes from its own day, a filled rate from an earlier day, never more than 4 days back
-- (4 days = the longest ČNB gap around Easter or Christmas).
-- CZ: F03 Konzistence pravidla doplnění (očekáváno 0 / 0 / 0):
-- skutečný kurz pochází z vlastního dne, doplněný kurz z dřívějšího dne, nikdy víc než 4 dny zpět
-- (4 dny = nejdelší mezera ČNB kolem Velikonoc nebo Vánoc).
WITH result AS (
    SELECT COALESCE(SUM(CASE WHEN (f.is_actual_rate = 1 AND f.source_date <> d.full_date)
                               OR (f.is_actual_rate = 0 AND f.source_date >= d.full_date)
                               OR DATEDIFF(day, f.source_date, d.full_date) > 4
                             THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM dbo.fact_fx AS f
    JOIN dbo.dim_date AS d ON d.date_key = f.date_key
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'F03', 'fill rule broken', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- F04 Filled days by weekday: weekends dominate, weekday fills are public holidays
-- CZ: F04 Doplněné dny podle dne v týdnu: převažují víkendy, doplnění ve všední den jsou státní svátky
SELECT 'F04 filled days by weekday' AS check_id, d.weekday_num, COUNT(*) AS filled_days
FROM dbo.fact_fx AS f
JOIN dbo.dim_date AS d ON d.date_key = f.date_key
WHERE f.is_actual_rate = 0
GROUP BY d.weekday_num
ORDER BY d.weekday_num;

-- F05 Actual rates on weekends (expected 0 - ČNB does not publish on Saturday or Sunday)
-- CZ: F05 Skutečné kurzy o víkendu (očekáváno 0 - ČNB v sobotu a neděli kurz nevyhlašuje)
WITH result AS (
    SELECT COUNT(*) AS failed_rows
    FROM dbo.fact_fx AS f
    JOIN dbo.dim_date AS d ON d.date_key = f.date_key
    WHERE f.is_actual_rate = 1 AND d.is_weekend = 1
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'F05', 'actual rate on weekend', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- F06 Ranges and NULLs per year (plausible EUR/CZK band 20 - 30)
-- CZ: F06 Rozsahy a NULL za rok (věrohodné pásmo EUR/CZK 20 - 30)
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
-- CZ: F07 Skoky: největší změna skutečného kurzu mezi dny (skok přes 3 % by naznačoval chybu při čtení)
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
-- CZ: F08 Křížová kontrola s anomálií v souboru ČNB 2022: kurzy kolem 2. března 2022 (opakovaný řádek záhlaví v bronze)
SELECT 'F08 rates around 2022-03-02' AS check_id, d.full_date, f.rate_czk_per_eur, f.is_actual_rate, f.source_date
FROM dbo.fact_fx AS f
JOIN dbo.dim_date AS d ON d.date_key = f.date_key
WHERE d.full_date BETWEEN '2022-02-28' AND '2022-03-04'
ORDER BY d.full_date;

-- =====================================================================
-- repo_rate  (grain: one validity period of the ČNB 2-week repo rate)
-- CZ: repo_rate  (grain: jedno období platnosti dvoutýdenní repo sazby ČNB)
-- =====================================================================

-- R01 Volume and span (expected 22 periods, 2019-05-03 to 2024-12-31)
-- CZ: R01 Objem a rozsah (očekáváno 22 období, 2019-05-03 až 2024-12-31)
SELECT 'R01 periods' AS check_id, COUNT(*) AS period_count,
       MIN(valid_from) AS first_from, MAX(valid_to) AS last_to,
       MIN(repo_rate_pct) AS min_rate, MAX(repo_rate_pct) AS max_rate
FROM dbo.repo_rate;

-- R02 Gaps and overlaps: each period must start the day after the previous one ends (expected 0 / 0)
-- CZ: R02 Mezery a překryvy: každé období musí začít den po skončení předchozího (očekáváno 0 / 0)
WITH ordered AS (
    SELECT valid_from, valid_to,
           LAG(valid_to) OVER (ORDER BY valid_from) AS prev_to
    FROM dbo.repo_rate
),
result AS (
    SELECT COALESCE(SUM(CASE WHEN DATEDIFF(day, prev_to, valid_from) <> 1 THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM ordered
    WHERE prev_to IS NOT NULL
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'R02', 'repo rate gaps or overlaps', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- R03 Coverage: calendar days with no valid repo rate or more than one (expected 0 / 0)
-- CZ: R03 Pokrytí: kalendářní dny bez platné repo sazby nebo s více než jednou (očekáváno 0 / 0)
WITH rate_per_day AS (
    SELECT d.date_key, COUNT(r.valid_from) AS rate_count
    FROM dbo.dim_date AS d
    LEFT JOIN dbo.repo_rate AS r ON d.full_date BETWEEN r.valid_from AND r.valid_to
    GROUP BY d.date_key
),
result AS (
    SELECT COALESCE(SUM(CASE WHEN rate_count <> 1 THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM rate_per_day
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'R03', 'days without exactly one repo rate', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- =====================================================================
-- dim_date and dim_hour
-- CZ: dim_date a dim_hour
-- =====================================================================

-- D01 dim_date: every calendar day 2020-01-01 .. 2024-12-31 exactly once (expected 1,827 rows = 1,827 days)
-- CZ: D01 dim_date: každý kalendářní den 2020-01-01 .. 2024-12-31 právě jednou (očekáváno 1 827 řádků = 1 827 dní)
SELECT 'D01 dim_date span' AS check_id, COUNT(*) AS row_count,
       MIN(full_date) AS first_date, MAX(full_date) AS last_date,
       DATEDIFF(day, MIN(full_date), MAX(full_date)) + 1 AS calendar_days
FROM dbo.dim_date;

-- D02 dim_date: derived columns agree with full_date (expected 0 for each)
-- CZ: D02 dim_date: odvozené sloupce odpovídají full_date (očekáváno 0 u každého)
WITH result AS (
    SELECT COALESCE(SUM(CASE WHEN date_key <> YEAR(full_date) * 10000 + MONTH(full_date) * 100 + DAY(full_date)
                               OR year <> YEAR(full_date) OR month <> MONTH(full_date) OR day_of_month <> DAY(full_date)
                               OR quarter <> DATEPART(quarter, full_date)
                               OR week_of_year <> DATEPART(iso_week, full_date)
                               OR is_weekend <> CASE WHEN weekday_num IN (6, 7) THEN 1 ELSE 0 END
                             THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM dbo.dim_date
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'D02', 'dim_date derived columns wrong', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- D03 dim_date: weekday_num against a known Monday (2020-01-06); 1 = Monday .. 7 = Sunday (expected 0)
-- CZ: D03 dim_date: weekday_num proti známému pondělí (2020-01-06); 1 = pondělí .. 7 = neděle (očekáváno 0)
WITH result AS (
    SELECT COALESCE(SUM(CASE WHEN weekday_num <> (DATEDIFF(day, '2020-01-06', full_date) % 7 + 7) % 7 + 1
                             THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM dbo.dim_date
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'D03', 'dim_date weekday wrong', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- D04 dim_hour: hours 1..25 exactly once, label per time of day
-- CZ: D04 dim_hour: hodiny 1..25 právě jednou, popisek podle části dne
SELECT 'D04 dim_hour' AS check_id, time_of_day, COUNT(*) AS hour_count,
       MIN(hour_of_day) AS first_hour, MAX(hour_of_day) AS last_hour
FROM dbo.dim_hour
GROUP BY time_of_day
ORDER BY MIN(hour_of_day);

-- =====================================================================
-- fact_load (SIMULATED, grain: delivery day + hour) and regulated_price (grain: component + validity period)
-- CZ: fact_load (SIMULOVANÝ, grain: den dodávky + hodina) a regulated_price (grain: složka + období platnosti)
-- =====================================================================

-- L01 Same grain as the prices: every price hour has a load and every load hour has a price (expected 0).
-- The cost is load x price per hour, so a missing hour on either side would silently drop cost.
-- CZ: L01 Stejný grain jako ceny: každá hodina s cenou má odběr a každá hodina s odběrem má cenu (očekáváno 0).
-- CZ: Náklad je odběr x cena po hodinách, takže chybějící hodina na kterékoli straně by tiše ubrala náklad.
WITH price_without_load AS (
    SELECT COUNT(*) AS row_count
    FROM dbo.fact_energy_prices AS p
    LEFT JOIN dbo.fact_load AS l ON l.date_key = p.date_key AND l.hour_of_day = p.hour_of_day
    WHERE l.date_key IS NULL
),
load_without_price AS (
    SELECT COUNT(*) AS row_count
    FROM dbo.fact_load AS l
    LEFT JOIN dbo.fact_energy_prices AS p ON p.date_key = l.date_key AND p.hour_of_day = l.hour_of_day
    WHERE p.date_key IS NULL
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'L01', 'load and price hours not matching', a.row_count + b.row_count,
       CASE WHEN a.row_count + b.row_count = 0 THEN 'PASS' ELSE 'FAIL' END
FROM price_without_load AS a
CROSS JOIN load_without_price AS b;

-- L02 Every load row is labelled as simulated and has a load of 0 or more (expected 0)
-- CZ: L02 Každý řádek odběru je označený jako simulovaný a má odběr 0 nebo víc (očekáváno 0)
WITH result AS (
    SELECT COALESCE(SUM(CASE WHEN is_simulated <> 1 OR load_mwh < 0 THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM dbo.fact_load
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'L02', 'load not simulated or negative', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- G01 Every component has exactly one valid price on every calendar day (expected 0 of 1,827 x 8 pairs).
-- A gap would leave a day without a regulated charge, an overlap would charge it twice.
-- CZ: G01 Každá složka má každý kalendářní den právě jednu platnou cenu (očekáváno 0 z 1 827 x 8 dvojic).
-- CZ: Mezera by nechala den bez regulované platby, překryv by ji započítal dvakrát.
WITH components AS (
    SELECT DISTINCT component
    FROM dbo.regulated_price
),
coverage AS (
    SELECT d.date_key, c.component, COUNT(r.component) AS period_count
    FROM dbo.dim_date AS d
    CROSS JOIN components AS c
    LEFT JOIN dbo.regulated_price AS r
        ON r.component = c.component AND d.full_date BETWEEN r.valid_from AND r.valid_to
    GROUP BY d.date_key, c.component
),
result AS (
    SELECT COALESCE(SUM(CASE WHEN period_count <> 1 THEN 1 ELSE 0 END), 0) AS failed_rows
    FROM coverage
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'G01', 'component-days without exactly one price', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- G02 Number of components (expected 8, config/tariffs.csv); failed_rows = how far the count is from 8
-- CZ: G02 Počet složek (očekáváno 8, config/tariffs.csv); failed_rows = o kolik se počet liší od 8
WITH result AS (
    SELECT ABS(COUNT(DISTINCT component) - 8) AS failed_rows
    FROM dbo.regulated_price
)
INSERT INTO dbo.dq_results (run_at, test_id, test_name, failed_rows, status)
SELECT @run_at, 'G02', 'number of components not 8', failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END
FROM result;

-- =====================================================================
-- Stored results of this run (expected: every check PASS, only P09 WARN with 609 rows)
-- CZ: Uložené výsledky tohoto běhu (očekáváno: všechny kontroly PASS, jen P09 WARN s 609 řádky)
-- =====================================================================
SELECT run_at, test_id, test_name, failed_rows, status
FROM dbo.dq_results
WHERE run_at = @run_at
ORDER BY dq_result_id;
