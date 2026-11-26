# ADR-005: Celková cena (ČEZ Distribuce, hladina VN, bez DPH, cenový strop 2023 po měsících)

[English](ADR-005-all-in-price-scope.md) · **Čeština**

- Datum: 2026-10-14

## Proč bylo potřeba rozhodnout

Obchodní otázka 1 se ptá, kolik elektřina doopravdy stála za kWh. To je cena silové elektřiny z trhu plus regulované
složky: distribuce, systémové služby, POZE, poplatek OTE a daň z elektřiny. Regulované složky stanovuje ERÚ v cenových
rozhodnutích a liší se podle distribučního území a napěťové hladiny, na kterou je firma připojená. V roce 2023 navíc
platil státní strop na cenu silové elektřiny. V zadání ale stálo jen „energeticky náročná česká firma“, a to na výběr
tarifů nestačí.

Co jsem zjistil 14. 10. 2026:

- Nařízení vlády č. 298/2022 Sb. omezilo cenu silové elektřiny na 5 000 Kč/MWh bez DPH pro dodávky od 1. 1. do
  31. 12. 2023. Strop se týká jen ceny silové elektřiny, ne distribuce, systémových služeb, POZE ani poplatku OTE.
  U firem platil pro 80 % nejvyšší měsíční spotřeby za posledních pět let.
- V mých datech byla hodinová cena denního trhu nad 5 000 Kč/MWh v 88 hodinách roku 2023 (nejvýš 10 891,81 Kč/MWh)
  a ve 4 853 hodinách roku 2022. Žádný měsíc roku 2023 neměl prostý průměr nad stropem, nejvýš byl únor
  s 3 300,43 Kč/MWh. Dotaz: `vw_energy_prices_czk` JOIN `dim_date`, rok 2023, `AVG(price_czk_mwh)` po měsících.
- Jak se strop vypořádával u smluv s cenou podle spotu, jsem ve zdrojích, které jsem prošel, nenašel.

## Jaké možnosti jsem zvažoval

- Distribuční území: ČEZ Distribuce · EG.D · PREdistribuce.
- Napěťová hladina: NN (nízké napětí, dílny a domácnosti) · VN (vysoké napětí, 22 kV, průmyslové závody) · VVN
  (110 kV, velmi velké závody).
- DPH: započítat · nezapočítat.
- Marže dodavatele: vymyšlená pevná částka · žádná.
- Cenový strop: nebrat v úvahu · uplatnit po hodinách · uplatnit na měsíční průměrnou cenu silové elektřiny.

## Co jsem vybral

- **Distribuční území ČEZ Distribuce.** Je největší a patří k němu i Olomoucký kraj.
- **Hladina VN.** Je typická pro energeticky náročný závod se třemi směnami.
- **Bez DPH.** Firma je plátce DPH a odečte si ji, takže pro finančního ředitele DPH není náklad.
- **Bez marže dodavatele.** Veřejná hodnota neexistuje a vymyšlená by přidala další smyšlený předpoklad. Ve zjištěních
  uvádím, že celková cena marži dodavatele neobsahuje.
- **Cenový strop 2023 na měsíční cenu silové elektřiny váženou odběrem** (`ASSUMPTION`). Firma by za každý měsíc roku
  2023 platila `MIN(měsíční cena silové elektřiny, 5 000 Kč/MWh)`.

Území i napěťovou hladinu jsem 14. 10. 2026 doplnil do scénáře v [zadání projektu](../01_project_brief_cz.md).

## Co z toho plyne

- Regulované ceny za roky 2020–2024 jsou přepsané z cenových rozhodnutí ERÚ pro ČEZ Distribuce a hladinu VN do souboru
  [config/tariffs.csv](../../config/tariffs.csv) se sloupci `valid_from` / `valid_to`. Ve skriptech není nic zapsané
  natvrdo.
- Distribuční cena na hladině VN obsahuje měsíční platbu za rezervovanou kapacitu. Potřebuje proto nejvyšší odběr
  simulovaného diagramu (rezervovaná kapacita 5 MW, viz [metodika](../methodology_cz.md)).
- S měsíčním pravidlem a cenami roku 2023 jsem čekal, že strop nezabere v žádném měsíci. Dotaz
  [sql/08_query_allin_price.sql](../../sql/08_query_allin_price.sql) to 18. 10. 2026 ověřil s cenou váženou odběrem
  firmy: nejvyšší měsíční cena silové elektřiny v roce 2023 byla 3 572,47 Kč/MWh (leden). Strop tedy nikdy nezabral
  a pravidlo 80 % spotřeby nebylo potřeba modelovat. Dotaz proto nemá sloupec se stropem.
- Celková cena je modelová cena pro jedno distribuční území a jednu napěťovou hladinu, ne cena pro každou českou firmu.
  Ve zjištěních to uvádím.
