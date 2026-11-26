# ADR-001: Kurz EUR/CZK o víkendech a svátcích

[English](ADR-001-eur-czk-fill-rule.md) · **Čeština**

- Datum: 2026-09-23

## Proč bylo potřeba rozhodnout

ČNB vyhlašuje kurz EUR/CZK jen v pracovní dny. Za roky 2019–2024 je v surových souborech
`data/bronze/cnb/cnb_fx_*.txt` 1 508 kurzů (ověřeno 23. 9. 2026). Ceny elektřiny z OTE ale mají řádek pro každou
hodinu každého dne, i o víkendech a svátcích (43 848 hodin v 1 827 dnech). Abych mohl každou hodinu převést na
koruny, potřeboval jsem kurz pro každý kalendářní den, ne jen pro pracovní dny ČNB.

Pro 1. 1. 2020 navíc ČNB žádný kurz nevyhlásila. Nejbližší předchozí kurz je z 31. 12. 2019, proto skript stahuje
i kurzy za rok 2019.

## Jaké možnosti jsem zvažoval

1. Nechat dny bez kurzu prázdné (NULL) a řešit je až v jednotlivých dotazech.
2. Doplnit kurz dopředu: den bez kurzu dostane poslední kurz, který ČNB vyhlásila před ním.
3. Dopočítat kurz mezi okolními dny (interpolace).

## Co jsem vybral

Možnost 2, doplnění dopředu. Sobota, neděle i svátek dostanou kurz z posledního pracovního dne před nimi. Tak se
kurz používá i v praxi: přes víkend se nic nepřeceňuje a poslední vyhlášený kurz platí, dokud ČNB nevyhlásí nový.
Interpolace by vytvořila kurz, který nikdy na žádném trhu neplatil. Prázdné hodnoty jsem nechtěl, protože by se
o ně musel postarat každý dotaz a stačilo by jednou zapomenout.

## Co z toho plyne

- Tabulka kurzů `fact_fx` (vytváří ji funkce `fill_fx_gaps()` v `python/02_transform.py`) má jeden řádek pro každý
  den od 1. 1. 2020 do 31. 12. 2024 a nikdy v ní nechybí kurz.
- Dva sloupce navíc říkají, odkud kurz pochází:
  - `is_actual_rate`: 1 znamená, že ČNB ten den kurz vyhlásila, 0 znamená, že je převzatý z dřívějšího dne.
  - `source_date`: datum, ze kterého kurz opravdu je. Je vyplněné vždy, i když `is_actual_rate = 1`, aby se
    v dotazech nemuselo řešit NULL.
- Ověřeno 23. 9. 2026: 1. 1. 2020 dostal správně kurz z 31. 12. 2019 (`rate_czk_per_eur = 25.41`,
  `is_actual_rate = 0`, `source_date = 2019-12-31`).
- Pravidlo později nezávisle potvrdilo i REST API ČNB: pro sobotu 5. 3. 2022 vrací kurz z pátku 4. 3. 2022
  (25,735 Kč/EUR), stejně jako tabulka `fact_fx` ([python/05_check_fx_api.py](../../python/05_check_fx_api.py)).
- Kontrola nebo dotaz, který potřebuje vědět, jestli je kurz skutečný, musí použít `is_actual_rate`. Nesmí brát
  každý řádek jako kurz, který ČNB ten den vyhlásila.
