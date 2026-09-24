-- Creating first table of our project dimension Date
-- Safe to rerun: the table is dropped and recreated, so definition changes apply - data is reloaded from the folder data/silver files

USE [EnergyCrisisCostAnalysis]
GO

DROP TABLE IF EXISTS dbo.dim_date;
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
	

