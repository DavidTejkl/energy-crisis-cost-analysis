-- Purpose : Creating new database for my analytical project Energy Crisis Cost Analysis
-- With IF condition we check if database is created or none 
-- This condition protects from building database if database is created once before
-- CZ: Účel: vytvoření nové databáze pro můj analytický projekt Energy Crisis Cost Analysis
-- Podmínkou IF kontrolujeme, jestli databáze už existuje, nebo ne
-- Tato podmínka brání vytvoření databáze, pokud už byla jednou vytvořena

IF DB_ID('EnergyCrisisCostAnalysis') IS NULL
	CREATE DATABASE EnergyCrisisCostAnalysis;

GO 