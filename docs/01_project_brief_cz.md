# Zadání projektu — P1 Analýza nákladů energetické krize

[English](01_project_brief.md) · **Čeština**

## SCÉNÁŘ (fiktivní, uvedený jednou)

- Modelová firma: energeticky náročná česká firma s třísměnným provozem a nižším odběrem o víkendech.
- Odběrový profil: SIMULOVANÝ hodinový profil (`is_simulated = 1`) — skutečné odběrové křivky jsou obchodní
  tajemství. Metoda je popsaná v `docs/methodology.md`.
- Komu analýza slouží: finanční ředitel (náklady a riziko rozpočtu), nákup energií (zafixovat teď, nebo počkat?).
- Rozhodnutí: jakou část spotřeby na příští rok zafixovat dopředu.

## Byznysové otázky

1. Kolik elektřina skutečně stála za kWh (all-in: silová elektřina + regulované složky)?
2. Proč se náklady meziročně měnily — tržní cena, spotřebované množství, nebo tvar odběru?
3. Jak kurz EUR/CZK ovlivnil náklady v korunách? (směr vlivu se ověří na datech)
4. Dala se ztráta zajistit — náklady při 0 / 25 / 50 / 75 / 100 % zafixovaného množství?

## Zdroje dat (2020–2024)

| Zdroj                 | Co                                                             | Podrobnost       | Stav              |
| --------------------- | -------------------------------------------------------------- | ---------------- | ----------------- |
| Denní trh OTE-ČR      | cena EUR/MWh, množství                                         | hodinová         | zdroj ověřen      |
| Kurzy ČNB             | EUR/CZK                                                        | pracovní dny ČNB | zdroj ověřen      |
| 2T repo sazba ČNB     | měnověpolitická úroková sazba, kontext pro korunu a cenu peněz | období platnosti | zdroj ověřen      |
| Cenová rozhodnutí ERÚ | distribuce, systémové služby, POZE, daň                        | období platnosti | sběr do `config/` |
| Vlastní generátor     | odběrový profil firmy                                          | hodinová         | SIMULOVANÝ        |

### Podrobnosti ke zdrojům

**Denní trh OTE-ČR** — roční zpráva o trhu, jeden zip za rok:
`https://www.ote-cr.cz/pubweb/attachments/62_162/YYYY/Rocni_zprava_o_trhu_YYYY_V2.zip`
(seznam na `https://www.ote-cr.cz/cs/statistika/rocni-zprava?date=YYYY-01-01`)

- V2 = konečné měsíční vyúčtování (V0 denní, V1 měsíční vyhodnocení) → používá se V2.
- Zip obsahuje jeden soubor Excel: `.xls` pro 2020–2023, `.xlsx` pro 2024 → ke čtení jsou potřeba obě
  knihovny, `xlrd` i `openpyxl`.
- List `DT ČR`, záhlaví na 6. řádku (`header=5`), hodinová data v levých sloupcích; na stejném listu jsou
  vpravo i denní, týdenní a měsíční souhrny → sloupce se vybírají podle názvu.
- Sloupce: `Den` (datum), `Hodina` (1–24, 1–23 nebo 1–25), `Marginální cena ČR (EUR/MWh)` = cena,
  `Množství - vč. Exp a Imp (MWh)` = množství. `Saldo DT (MWh)` existuje až od roku 2021 → sloupce se
  posouvají, nikdy je nevybírat podle pozice. Názvy v záhlaví 2024 obsahují zalomení řádku → bílé znaky
  se sjednocují.
- Soubor obsahuje i `Marginální cena ČR (Kč/MWh)` a `Kurz Kč/EUR (ČNB)`: cenu v Kč označuje OTE jen jako
  informativní → nepoužívá se; cena v Kč se počítá z kurzu ČNB (ADR-001), cena v Kč od OTE slouží jako kontrola.
- `Hodina` je pořadová hodina obchodního dne, ne hodina na hodinách: jarní den se změnou času má hodiny 1–23,
  podzimní hodiny 1–25.
- Zkušební stažení 2026-09-22, všech pět let: 43 848 hodinových řádků v 1 827 dnech
  (8 784 / 8 760 / 8 760 / 8 760 / 8 784), v každém roce jeden 23hodinový a jeden 25hodinový den na poslední
  neděli v březnu / říjnu, 0 duplicit den+hodina, 0 chybějících cen, 609 hodin se zápornou cenou
  (119 / 33 / 8 / 134 / 315), rozpětí cen −138,75 až 871,00 EUR/MWh.

**Kurz EUR/CZK ČNB** — jeden textový soubor za rok:
`https://www.cnb.cz/cs/financni-trhy/devizovy-trh/kurzy-devizoveho-trhu/kurzy-devizoveho-trhu/rok.txt?rok=YYYY`

- Oddělovač svislítko, datum `DD.MM.YYYY`, desetinná čárka, hodnota = Kč za 1 EUR (sloupec `1 EUR`).
- Jen pracovní dny: 1 257 kurzů v letech 2020–2024. Rok 2020 začíná 2. ledna, proto je potřeba i konec roku
  2019, aby se dal doplnit 1. leden 2020.
- Soubor 2022 opakuje záhlaví 2. března 2022 (vypadl rubl, sloupce se posunuly) → EUR se hledá podle názvu
  sloupce, opakované řádky záhlaví se přeskakují.

**2T repo sazba ČNB** — celá historie v jednom souboru:
`https://www.cnb.cz/cs/casto-kladene-dotazy/.galleries/vyvoj_repo_historie.txt`

- Sloupce `PLATNA_OD|CNB_REPO_SAZBA_V_%`, datum `YYYYMMDD`, desetinná čárka, UTF-8 s BOM.
- 21 změn v letech 2020–2024; sazba platná 1. ledna 2020 byla stanovena 3. května 2019.

**Nepoužito**

- PRIBOR: ČNB ho zveřejňuje se souhlasem administrátora (CFBF) jen pro interní použití; další šíření sazeb
  nebo z nich odvozených dat je zakázané → nahrazen repo sazbou.

##
