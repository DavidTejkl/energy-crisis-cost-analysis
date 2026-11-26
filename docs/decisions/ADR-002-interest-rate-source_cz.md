# ADR-002: Úroková sazba jako kontext (2T repo sazba ČNB místo PRIBORu, akcie ČEZ odložené)

[English](ADR-002-interest-rate-source.md) · **Čeština**

- Datum: 2026-09-21

## Proč bylo potřeba rozhodnout

V zadání projektu byly dva volitelné zdroje pro kontext: PRIBOR (úroková sazba, za kterou si půjčují banky mezi sebou)
a cena akcií ČEZ. Ani jeden přímo neodpovídá na žádnou ze čtyř obchodních otázek. Každý zdroj navíc znamená další
stahování, čištění, tabulku, testy kvality dat a dokumentaci. Úroková sazba ale finančnímu řediteli doplní obraz
(spolu s energiemi zdražily i peníze) a dává kontext k pohybu kurzu EUR/CZK (otázka 3).

Co jsem zjistil 21. 9. 2026:

- Na stránce ČNB s PRIBORem stojí, že sazby se zveřejňují se souhlasem administrátora Czech Financial Benchmark
  Facility (CFBF), smí se používat jen pro interní účely a jakékoli další šíření sazeb nebo dat z nich odvozených je
  zakázané. Můj projekt je veřejný.
- ČNB zveřejňuje celou historii své 2T repo sazby jako textový soubor bez takového omezení:
  `https://www.cnb.cz/cs/casto-kladene-dotazy/.galleries/vyvoj_repo_historie.txt`. V letech 2020–2024 se sazba
  změnila 21krát, od 0,25 % v květnu 2020 přes 7,00 % v červnu 2022 po 4,00 % v listopadu 2024.
- Cena akcií ČEZ nemá oficiální zdroj ke stažení (jen Yahoo Finance). Navíc vypovídá o výrobci elektřiny, ne o firmě
  ze scénáře, která elektřinu kupuje.

## Jaké možnosti jsem zvažoval

1. Ponechat PRIBOR i ČEZ.
2. Oba zdroje odložit na později.
3. Ponechat jednu úrokovou sazbu jako kontext a ČEZ odložit.

## Co jsem vybral

Možnost 3, ale místo PRIBORu 2T repo sazbu ČNB. Akcie ČEZ jsem odložil na později.

## Co z toho plyne

- Repo sazbu ukládám jako období platnosti (platí od data až do další změny), stejně jako regulované ceny ERÚ.
  Sazba, která platila 1. 1. 2020, platí už od 3. 5. 2019.
- Je to jen kontext. Když mezi repo sazbou a kurzem EUR/CZK uvidím souvislost, popíšu ji jako korelaci, ne jako
  příčinu.
- Repo sazba je měnověpolitická sazba centrální banky, ne tržní úrok z úvěru. Ve zjištěních to musím uvést.
- Zatím je repo sazba nahraná v databázi a otestovaná, ale nepoužívá ji žádný analytický dotaz ani stránka reportu.
