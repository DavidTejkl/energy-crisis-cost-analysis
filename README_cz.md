# Analýza nákladů energetické krize (Česko, 2020–2024)

[English](README.md) · **Čeština**

**Elektřina zobchodovaná na českém denním trhu měla v roce 2022 hodnotu 7,5× vyšší než v roce 2020,
přestože zobchodované množství vzrostlo jen o 8 %. Téměř celý nárůst způsobila cena.**

` · Python (pandas, requests, pyodbc)`

` · SQL Server / T-SQL (hvězdicové schéma, testy kvality dat`)

` · Power BI (dashboardy, vizualizace, report)`

Kolik stála energetická krize let 2021–2023 českou firmu, co náklady hnalo nahoru (tržní cena, spotřebované
množství, tvar odběru během dne, kurz EUR/CZK) a dalo se proti tomu zajistit? Tento repozitář na otázku
odpovídá krok za krokem: od surových veřejných dat přes hvězdicové schéma v SQL Serveru až po analytické dotazy.

> **Stav — verze 1:** hotová je datová pipeline, datový model, kontroly kvality dat a analýza tržních cen.
> Náklady firmy (cena „all-in“), rozklad příčin nákladů, scénáře zajištění a report v Power BI přijdou v další verzi.

## Problém

- **Scénář (fiktivní):** energeticky náročná česká firma s třísměnným provozem a nižším odběrem o víkendech
  nakupuje elektřinu za spotovou cenu denního trhu.
- **Komu analýza slouží:** finanční ředitel (náklady a riziko rozpočtu) a nákup energií (zafixovat cenu teď,
  nebo počkat?).
- **Rozhodnutí:** jakou část spotřeby na příští rok zafixovat dopředu.
- Byznysové otázky a rozsah projektu: [docs/01_project_brief_cz.md](docs/01_project_brief_cz.md)

## Data

| Zdroj                                                                                                   | Co                                      | Podrobnost       | Období    |
| ------------------------------------------------------------------------------------------------------- | --------------------------------------- | ---------------- | --------- |
| [OTE-ČR](https://www.ote-cr.cz/cs/statistika/rocni-zprava) roční zpráva o trhu (V2, konečné vyúčtování) | cena denního trhu EUR/MWh, množství MWh | hodinová         | 2020–2024 |
| [ČNB](https://www.cnb.cz/cs/financni-trhy/devizovy-trh/kurzy-devizoveho-trhu/) kurzy devizového trhu    | EUR/CZK                                 | pracovní dny ČNB | 2019–2024 |
| [ČNB](https://www.cnb.cz/cs/casto-kladene-dotazy/.galleries/vyvoj_repo_historie.txt) 2T repo sazba      | měnověpolitická úroková sazba           | období platnosti | 2019–2024 |

- 43 848 hodinových cen v 1 827 dnech. Dny se změnou letního času mají 23 nebo 25 hodin.
- Kurz pro víkendy a svátky se doplňuje z posledního pracovního dne ČNB
  ([ADR-001](docs/decisions/ADR-001-eur-czk-fill-rule.md)); každý doplněný řádek je označený.
- Odběrový profil firmy bude **simulovaný** (skutečné odběrové křivky jsou obchodní tajemství) a tak bude
  i všude označený.
- Data nejsou uložená v repozitáři. Skripty je stahují přímo z OTE a ČNB, takže složky `data/` jsou prázdné,
  dokud skripty nespustíte.

## Architektura

```
stažení (Python)      →  data/bronze   surové soubory, nikdy se neupravují
čištění (Python)      →  data/silver   vyčištěné CSV, jeden soubor na tabulku
nahrání (Python)      →  SQL Server    hvězdicové schéma: fact_energy_prices, fact_fx, dim_date, dim_hour, repo_rate
analýza (T-SQL)       →  pohled vw_energy_prices_czk + dotazy sql/04–07
```

```
python/    01_extract · 02_transform · 03_load · config.py (cesty a konstanty)
sql/       01–03 databáze, tabulky, pohledy · 04–07 analytické dotazy · 91 testy kvality dat
docs/      zadání, datový model, definice KPI, report kvality dat, nálezy, rozhodnutí (ADR)
config/    regulované složky ceny s obdobím platnosti (další verze)
data/      bronze (surová) · silver (vyčištěná) — vytváří je skripty, v gitu nejsou · gold (další verze)
powerbi/   report Power BI ve formátu PBIP (další verze)
```

- Datový model a definice (co je jeden řádek) každé tabulky: [docs/data_model.md](docs/data_model.md)
- Definice KPI (cenová pásma): [docs/kpi_definitions.md](docs/kpi_definitions.md)
- Kontroly kvality dat (27 testů) a jejich výsledky: [sql/91_dq_tests.sql](sql/91_dq_tests.sql),
  [docs/data_quality_report.md](docs/data_quality_report.md)
- Rozhodnutí: [docs/decisions/](docs/decisions/)

Zadání projektu je česky i anglicky; ostatní dokumentace v `docs/` je v angličtině.

## Jak projekt spustit

Potřebujete: Windows, Python 3.13, SQL Server (lokální výchozí instance, přihlášení přes Windows),
ODBC Driver 17 for SQL Server, `sqlcmd`.

```bash
# 1. Prostředí Pythonu
py -m venv .venv
source .venv/Scripts/activate    # Git Bash; v PowerShellu: .venv\Scripts\Activate.ps1
pip install -r requirements.txt

# 2. Stažení a vyčištění dat
py python/01_extract.py          # surové soubory do data/bronze (druhé spuštění už stažené soubory přeskočí)
py python/02_transform.py        # vyčištěné CSV do data/silver

# 3. Databáze a nahrání dat
sqlcmd -S localhost -E -C -b -f 65001 -i sql/01_create_database.sql
sqlcmd -S localhost -E -C -b -f 65001 -i sql/02_create_tables.sql
py python/03_load.py             # kompletní nové nahrání v jedné transakci

# 4. Pohled, kontroly kvality dat a analýza
sqlcmd -S localhost -E -C -b -f 65001 -i sql/03_create_views.sql
sqlcmd -S localhost -E -C -b -f 65001 -i sql/91_dq_tests.sql
sqlcmd -S localhost -E -C -b -f 65001 -i sql/04_query_daily_overview.sql
```

Očekávané počty řádků po nahrání: `dim_date` 1 827 · `dim_hour` 25 · `repo_rate` 22 ·
`fact_energy_prices` 43 848 · `fact_fx` 1 827.

## Hlavní zjištění (tržní ceny, verze 1)

Všechna čísla pocházejí z dotazů uvedených v [docs/findings.md](docs/findings.md).

1. **Krizi udělala cena, ne množství.** Hodnota zobchodovaná na denním trhu vzrostla z 20,7 mld. Kč (2020)
   na 155,8 mld. Kč (2022), zatímco množství stouplo jen z 22,4 na 24,3 TWh (+8 %).
   (`sql/04_query_daily_overview.sql`)
2. **Drahé hodiny se staly normou.** V roce 2020 stála 3 374 Kč/MWh nebo víc jediná hodina; v roce 2022
   to bylo 6 951 hodin, tedy 79 % roku. (`sql/05_query_price_bands.sql`)
3. **Krize skončila, cenové špičky ne.** Nejdražší hodina roku 2024 (12. 12., 17:00–18:00, 21 171 Kč/MWh)
   byla skoro stejně drahá jako vrchol krize (29. 8. 2022, 21 422 Kč/MWh). Rok 2022 byl ale dlouhým obdobím
   vysokých cen — všech 5 nejdražších dnů připadá na jediný týden na konci srpna — kdežto v roce 2024 šlo
   o krátký šok trvající několik hodin. (`sql/07_query_top_hours.sql`)

### Příklad z kontroly kvality dat: odlehlá hodnota není chyba

První kontrola kvality dat označila 12. prosinec 2024, 17:00–18:00: **844,63 EUR/MWh**, vysoko nad stejnou
hodinou v předchozích dnech (199,29 a 442,45 EUR/MWh). Hodnota je v surovém souboru OTE, sedí i hodnoty, které
soubor sám dopočítává (844,63 × 25,065 = 21 170,65 Kč/MWh), a cena během celého večera plynule roste a zase
klesá — překlep by vypadal jako osamocený skok. Ve stejné hodině vrcholila v Německu _Dunkelflaute_ („temné
bezvětří“: chladné počasí téměř bez větru a slunce, tedy s velmi malou výrobou z obnovitelných zdrojů) a tamní
cena denního trhu dosáhla 936 EUR/MWh; český a německý trh jsou propojené. Hodnota je skutečná tržní cena
a v datech zůstává — odlehlé hodnoty se ověřují proti zdroji, ne mažou.

![Surový soubor OTE, 12. 12. 2024](docs/screenshots/bronze_ote_2024-12-12_price_peak_excel.png)

## Omezení

- **Zatím jen tržní ceny.** Verze 1 analyzuje denní trh; náklady firmy včetně distribuce, systémových služeb,
  podpory obnovitelných zdrojů (POZE), daní a státního zastropování cen v roce 2023 přijdou v další verzi.
- **Prosté průměry.** Denní a roční ceny ve verzi 1 jsou prosté průměry hodin (cena „base“). Náklady firmy
  budou počítané cenou váženou spotřebovaným množstvím.
- **Simulovaný odběr.** Odběrový profil firmy bude simulovaný; zjištění o vlivu množství a tvaru odběru budou
  odrážet předpoklady generátoru, ne skutečnou firmu.
- **Žádné forwardové ceny.** OTE forwardové ceny nezveřejňuje; cena zajištění bude zdokumentovaná náhradní
  hodnota (proxy), nikoli skutečná cena kontraktu.
- **Souvislost není příčina.** Data skoků cen nebo kurzu se porovnávají s událostmi na trhu, ale samotná data
  příčinu nedokazují.
- Pouze lokální SQL Server, bez nasazení do cloudu.
