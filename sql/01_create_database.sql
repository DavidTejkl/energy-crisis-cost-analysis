-- Purpose: create the database of the Energy Crisis Cost Analysis project.
-- The IF condition checks whether the database already exists, so the script is safe to run again:
-- it never drops or recreates a database that holds data.
-- CZ: Účel: vytvořit databázi projektu Energy Crisis Cost Analysis.
-- Podmínka IF zkontroluje, jestli databáze už existuje, takže skript jde spustit opakovaně:
-- databázi s daty nikdy nesmaže ani nevytvoří znovu.

IF DB_ID('EnergyCrisisCostAnalysis') IS NULL
	CREATE DATABASE EnergyCrisisCostAnalysis;

GO 