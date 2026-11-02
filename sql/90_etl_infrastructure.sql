-- Purpose: pipeline tables that make every load and every data quality check traceable afterwards:
-- etl_run_log (one row = one load of one table in one run) and dq_results (one row = one DQ test in one run).
-- CZ: Účel: tabulky pipeline, díky kterým lze každé načtení a každou kontrolu kvality dat dohledat zpětně:
-- etl_run_log (jeden řádek = jedno načtení jedné tabulky v jednom běhu) a dq_results (jeden řádek = jeden DQ test v jednom běhu).

-- Unlike 02_create_tables.sql there is no DROP: the tables are created only if they do not exist yet,
-- so a rebuild of the data model never deletes the history of runs and checks.
-- No foreign keys to the model: a failed run must still be logged even when the model tables are empty.
-- CZ: Na rozdíl od 02_create_tables.sql tu není DROP: tabulky se vytvoří, jen když ještě neexistují,
-- takže nové sestavení datového modelu nikdy nesmaže historii běhů a kontrol.
-- Žádné cizí klíče na model: neúspěšný běh se musí zapsat, i když jsou tabulky modelu prázdné.

USE [EnergyCrisisCostAnalysis]
GO

-- finished_at stays NULL while a load runs; a NULL in an old row means the run stopped without logging its end.
-- CZ: finished_at zůstává NULL, dokud načítání běží; NULL ve starém řádku znamená, že běh skončil bez zápisu konce.
IF OBJECT_ID('dbo.etl_run_log') IS NULL
CREATE TABLE dbo.etl_run_log (
	run_id int IDENTITY(1,1) NOT NULL,
	script_name nvarchar(100) NOT NULL,
	table_name nvarchar(100) NULL,
	started_at datetime2(0) NOT NULL,
	finished_at datetime2(0) NULL,
	rows_inserted int NULL,
	rows_updated int NULL,
	status nvarchar(10) NOT NULL,
	error_message nvarchar(4000) NULL,
	CONSTRAINT pk_etl_run_log PRIMARY KEY (run_id),
	CONSTRAINT ck_etl_run_log_status CHECK (status IN ('RUNNING', 'OK', 'FAIL')),
	CONSTRAINT ck_etl_run_log_rows_inserted CHECK (rows_inserted >= 0),
	CONSTRAINT ck_etl_run_log_rows_updated CHECK (rows_updated >= 0),
	CONSTRAINT ck_etl_run_log_finished_at CHECK (finished_at >= started_at)
);
GO

-- WARN = valid values that are flagged on purpose (e.g. negative prices), not errors.
-- CZ: WARN = platné hodnoty, které jsou záměrně označené (např. záporné ceny), nejde o chyby.
IF OBJECT_ID('dbo.dq_results') IS NULL
CREATE TABLE dbo.dq_results (
	dq_result_id int IDENTITY(1,1) NOT NULL,
	run_at datetime2(0) NOT NULL,
	test_id nvarchar(10) NOT NULL,
	test_name nvarchar(200) NOT NULL,
	failed_rows int NOT NULL,
	status nvarchar(10) NOT NULL,
	CONSTRAINT pk_dq_results PRIMARY KEY (dq_result_id),
	CONSTRAINT ck_dq_results_failed_rows CHECK (failed_rows >= 0),
	CONSTRAINT ck_dq_results_status CHECK (status IN ('PASS', 'WARN', 'FAIL'))
);
GO
