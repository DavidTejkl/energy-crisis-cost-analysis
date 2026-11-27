# Zadání projektu: Analýza nákladů energetické krize

[English](01_project_brief.md) · **Čeština**

## Scénář (vymyšlená firma)

- **Firma:** energeticky náročný český výrobce s nepřetržitým provozem, který běží 24 hodin denně celý rok.
  Výrobní linky jedou ve třech směnách od neděle 22:00 do pátku 22:00 (v zimě ve dvou směnách), expedice a kanceláře
  pracují ve všední dny na ranní směně. Firma spotřebuje zhruba 28 GWh elektřiny za rok (předpoklad).
- **Připojení k síti:** distribuční území ČEZ Distribuce, vysoké napětí (VN, 22 kV). Všechny ceny jsou bez DPH
  ([ADR-005](decisions/ADR-005-all-in-price-scope_cz.md)).
- **Odběr:** simulovaný hodinový odběr (`is_simulated = 1`), protože firmy svoje skutečné odběrové diagramy
  nezveřejňují. Jak se odběr počítá: [metodika](methodology_cz.md).
- **Pro koho je analýza:** finanční ředitel, který odpovídá za náklady a riziko rozpočtu, a nákup energií, který
  rozhoduje, jestli cenu zafixovat hned, nebo počkat.
- **Rozhodnutí, se kterým má analýza pomoct:** jakou část spotřeby na příští rok koupit předem za pevnou cenu.

## Obchodní otázky

1. Kolik elektřina skutečně stála za kWh včetně regulovaných plateb (celková cena)?
2. Proč se náklad meziročně měnil: kvůli ceně na trhu, kvůli spotřebě, nebo kvůli tomu, kdy během dne firma odebírá?
3. Jak náklad v korunách ovlivnil kurz EUR/CZK?
4. Dalo se ztrátě předejít zajištěním? Kolik by firma zaplatila, kdyby předem koupila 0, 25, 50, 75 nebo 100 %
   spotřeby?

## Zdroje dat (2020–2024)

| Zdroj                      | Co                                                  | Podrobnost       | Jak se dostane do projektu                                     |
| -------------------------- | --------------------------------------------------- | ---------------- | -------------------------------------------------------------- |
| Denní trh OTE-ČR           | cena EUR/MWh, množství                              | hodina           | stahuje `python/01_extract.py`                                 |
| Kurzy ČNB                  | EUR/CZK                                             | pracovní dny ČNB | stahuje `python/01_extract.py`                                 |
| Dvoutýdenní repo sazba ČNB | úroková sazba ČNB, kontext pro korunu a cenu peněz  | období platnosti | stažená a načtená, v analýze se nepoužívá                      |
| Cenová rozhodnutí ERÚ      | distribuce, systémové služby, POZE, daň z elektřiny | období platnosti | přepsaná z oficiálních rozhodnutí do `config/tariffs.csv`      |
| Výroční zprávy PXE         | cena ročního produktu base load na konci roku       | rok              | citované v [ADR-003](decisions/ADR-003-forward-price-proxy_cz.md) |
| Vlastní generátor          | odběr firmy                                         | hodina           | simulovaný skriptem `python/04_generate_load_profile.py`       |

### Podrobnosti ke zdrojům

**Denní trh OTE-ČR:** roční zpráva o trhu, jeden zip za každý rok:
`https://www.ote-cr.cz/pubweb/attachments/62_162/YYYY/Rocni_zprava_o_trhu_YYYY_V2.zip`
(seznam na `https://www.ote-cr.cz/cs/statistika/rocni-zprava?date=YYYY-01-01`)

- Zpráva vychází ve třech verzích: V0 (denní), V1 (měsíční vyhodnocení) a V2 (konečné měsíční vypořádání).
  Projekt používá V2.
- V každém zipu je jeden soubor Excel: `.xls` za roky 2020–2023 a `.xlsx` za rok 2024, takže ke čtení jsou potřeba
  knihovny `xlrd` i `openpyxl`.
- Data jsou na listu `DT ČR`, záhlaví je na 6. řádku (`header=5`). Hodinová data jsou v levých sloupcích a na stejném
  listu jsou vpravo i denní, týdenní a měsíční souhrny, proto se sloupce vybírají podle názvu.
- Použité sloupce: `Den` (datum), `Hodina` (1–24, 1–23 nebo 1–25), `Marginální cena ČR (EUR/MWh)` (cena)
  a `Množství - vč. Exp a Imp (MWh)` (množství). Sloupec `Saldo DT (MWh)` existuje až od roku 2021, takže se sloupce
  mezi roky posouvají a nikdy se nevybírají podle pozice. Záhlaví za rok 2024 obsahuje zalomení řádků, proto se
  mezery a konce řádků v názvech sjednocují.
- Soubor obsahuje i `Marginální cena ČR (Kč/MWh)` a `Kurz Kč/EUR (ČNB)`. Cenu v korunách OTE uvádí jen pro
  informaci, proto se nepoužívá. Cena v korunách se počítá z kurzu ČNB (ADR-001) a hodnota od OTE slouží jen
  ke kontrole.
- `Hodina` je pořadová hodina obchodního dne, ne čas na hodinách. V jarní den se změnou času jde od 1 do 23,
  v podzimní od 1 do 25.
- Zkušební stažení 22. 9. 2026, všech pět let: 43 848 hodinových řádků v 1 827 dnech (8 784 / 8 760 / 8 760 /
  8 760 / 8 784). Každý rok má jeden den s 23 hodinami a jeden s 25 hodinami, vždy poslední neděli v březnu
  a v říjnu. Žádný den a hodina dvakrát, žádná chybějící cena, 609 hodin se zápornou cenou (119 / 33 / 8 / 134 / 315),
  ceny od −138,75 do 871,00 EUR/MWh.

**Kurz EUR/CZK ČNB:** jeden textový soubor za každý rok:
`https://www.cnb.cz/cs/financni-trhy/devizovy-trh/kurzy-devizoveho-trhu/kurzy-devizoveho-trhu/rok.txt?rok=YYYY`

- Hodnoty odděluje svislítko `|`, datum je ve tvaru `DD.MM.YYYY`, desetinná čárka, hodnota znamená počet korun
  za 1 EUR (sloupec `1 EUR`).
- Kurzy jsou jen pro pracovní dny ČNB: 1 257 kurzů v letech 2020–2024. Soubor za rok 2020 začíná 2. ledna, proto se
  stahuje i konec roku 2019, aby šel doplnit 1. leden 2020.
- Soubor za rok 2022 zopakuje 2. 3. 2022 záhlaví, protože z něj vypadl rubl a sloupce se posunuly. EUR se proto hledá
  podle názvu sloupce a opakované řádky se záhlavím se přeskakují.

**Dvoutýdenní repo sazba ČNB:** celá historie v jednom souboru:
`https://www.cnb.cz/cs/casto-kladene-dotazy/.galleries/vyvoj_repo_historie.txt`

- Sloupce `PLATNA_OD|CNB_REPO_SAZBA_V_%`, datum ve tvaru `YYYYMMDD`, desetinná čárka, kódování UTF-8 s BOM.
- V letech 2020–2024 se sazba změnila 21krát. Sazba platná 1. 1. 2020 byla stanovená 3. 5. 2019.

## Rozsah

- **Součástí projektu je:** datová pipeline, hvězdicové schéma, testy kvality dat, přírůstkové načítání, analytické
  dotazy, report v Power BI se 6 stránkami (úvod, shrnutí a 4 podrobné stránky), README česky a anglicky.
