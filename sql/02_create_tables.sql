-- ** This file is made for creating every table which we will need in our project - dim_date, dim_hour, fact_energy_prices, fact_fx, repo_rate **

USE [EnergyCrisisCostAnalysis]
GO

-- Safe to rerun: the table is dropped and recreated, so definition changes apply - data is reloaded from the folder data/silver files
DROP TABLE IF EXISTS dbo.fact_energy_prices;
DROP TABLE IF EXISTS dbo.fact_fx;
DROP TABLE IF EXISTS dbo.dim_date;
DROP TABLE IF EXISTS dbo.dim_hour;
DROP TABLE IF EXISTS dbo.repo_rate;

-- Creating first table of our project dimension Date - according to the document data_model.md
CREATE TABLE dbo.dim_date (
	date_key int NOT NULL,
	full_date date NOT NULL,
	day_of_month int NOT NULL,
	month int NOT NULL,
	year int NOT NULL,
	quarter int NOT NULL,
	week_of_year int NOT NULL,
	weekday_num int NOT NULL,
	weekday_name nvarchar(7) NOT NULL,
	is_weekend bit NOT NULL,
	CONSTRAINT pk_dim_date PRIMARY KEY(date_key),
	CONSTRAINT uq_dim_date_full_date UNIQUE (full_date),
	CONSTRAINT ck_dim_date_day_of_month CHECK (day_of_month BETWEEN 1 AND 31),
	CONSTRAINT ck_dim_date_month CHECK (month BETWEEN 1 AND 12),
	CONSTRAINT ck_dim_date_quarter CHECK (quarter BETWEEN 1 AND 4),
	CONSTRAINT ck_dim_date_week_of_year CHECK (week_of_year BETWEEN 1 AND 53),
	CONSTRAINT ck_dim_date_weekday_num CHECK (weekday_num BETWEEN 1 AND 7),
	CONSTRAINT ck_dim_date_weekday_name CHECK (weekday_name IN ('Pondělí','Úterý',
	'Středa','Čtvrtek','Pátek','Sobota','Neděle')));

-- Creating second table of our project dimension Hour - according to the document data_model.md
CREATE TABLE dbo.dim_hour(
	hour_of_day int NOT NULL,
	time_of_day nvarchar(10) NOT NULL,
	CONSTRAINT pk_dim_hour PRIMARY KEY (hour_of_day),
	CONSTRAINT ck_dim_hour_hour_of_day CHECK (hour_of_day BETWEEN 1 AND 25),
	CONSTRAINT ck_dim_hour_time_of_day CHECK (time_of_day IN ('ráno','dopoledne','odpoledne','večer','noc')));

-- Creating third table of our project fact Energy prices - the main table in our star schema - according to the document data_model.md
CREATE TABLE dbo.fact_energy_prices(
    date_key int NOT NULL,
    hour_of_day int NOT NULL,
	price_eur_mwh DECIMAL(7,2) NOT NULL,
	volume_mwh DECIMAL(9,3) NOT NULL,
	CONSTRAINT pk_fact_energy_prices PRIMARY KEY (date_key,hour_of_day),
	CONSTRAINT ck_fact_energy_prices_hour_of_day CHECK (hour_of_day BETWEEN 1 AND 25),
	CONSTRAINT fk_fact_energy_prices_date_key FOREIGN KEY (date_key) REFERENCES dbo.dim_date (date_key),
	CONSTRAINT fk_fact_energy_prices_hour_of_day FOREIGN KEY (hour_of_day) REFERENCES dbo.dim_hour (hour_of_day));

-- Creating fourth table of our project fact_fx - according to the document data_model.md
CREATE TABLE dbo.fact_fx(
	date_key int NOT NULL,
	rate_czk_per_eur DECIMAL(5,3) NOT NULL,
	is_actual_rate BIT NOT NULL,
	source_date DATE NOT NULL,
	CONSTRAINT pk_fact_fx PRIMARY KEY (date_key),
	CONSTRAINT fk_fact_fx_date_key FOREIGN KEY (date_key) REFERENCES dbo.dim_date (date_key),
	CONSTRAINT ck_fact_fx_rate_czk_per_eur CHECK (rate_czk_per_eur > 0));

-- Creating fifth table of our project repo_rate - non fact, non dimension table but period table - according to the document data_model.md
CREATE TABLE dbo.repo_rate(
	valid_from DATE NOT NULL,
	valid_to DATE NOT NULL,
	repo_rate_pct DECIMAL(4,2) NOT NULL,
	CONSTRAINT pk_repo_rate PRIMARY KEY (valid_from),
	CONSTRAINT ck_repo_rate_repo_period CHECK (valid_from <= valid_to));



