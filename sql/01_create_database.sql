-- Purpose : Creating new database for my analytical project Energy Crisis Cost Analysis
-- With IF condition we check if database is created or none 
-- This condition protects from building database if database is created once before

IF DB_ID('EnergyCrisisCostAnalysis') IS NULL
	CREATE DATABASE EnergyCrisisCostAnalysis;

GO 