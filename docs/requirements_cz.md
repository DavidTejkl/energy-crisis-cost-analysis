# Požadavky na report v Power BI

[English](requirements.md) · **Čeština**

Co musí report umět, pro koho je a podle čeho poznáme, že je hotový. Scénář a obchodní otázky jsou v [zadání
projektu](01_project_brief_cz.md). Modelová firma a její odběr jsou vymyšlené a simulované, ceny na trhu, kurzy
a regulované ceny jsou skutečná data.

## Pro koho report je

| Kdo | Co rozhoduje | Co potřebuje vidět |
|---|---|---|
| Finanční ředitel | rozpočet na energie na příští rok a jak velké cenové riziko firma unese | celkový náklad a z čeho se skládá (silová elektřina proti regulovaným platbám, pevné proti proměnlivým), proč se náklad změnil, vliv kurzu EUR/CZK |
| Nákup energií | jakou část spotřeby na příští rok koupit předem a jestli přesunout odběr do levnějších hodin | náklad při různém podílu nákupu předem, přirážku za diagram odběru, ceny ve špičce a mimo ni, nejdražší hodiny |

O tom, kolik elektřiny se koupí předem, nakonec rozhoduje finanční ředitel na návrh nákupu energií.

## Uživatelské příběhy (user stories)

**US-01 · finanční ředitel · celkový náklad**
Jako finanční ředitel chci vidět celkový náklad na elektřinu po měsících a letech rozdělený na silovou elektřinu
a regulované platby, abych věděl, kterou část nákladu určuje trh a kterou regulace.
Kdy je hotovo: roční součty se rovnají dotazu 08 (2022: 200 924 897,61 Kč, podíl silové elektřiny 90,6 %).

**US-02 · finanční ředitel · proč se náklad změnil**
Jako finanční ředitel chci vidět, o kolik se náklad na silovou elektřinu meziročně změnil a kolik z toho způsobila
cena na trhu, spotřeba, diagram odběru a kurz, abych mohl vedení vysvětlit, co firma mohla ovlivnit a co ne.
Kdy je hotovo: pro změnu z roku 2021 na rok 2022 report ukazuje +105,82 mil. Kč, z toho cena na trhu +104,75 mil.,
diagram odběru +8,16 mil., spotřeba −0,11 mil. a kurz −6,98 mil. Kč. Jednotlivé kroky dávají dohromady celkovou
změnu (rozdíl do 2 Kč kvůli zaokrouhlení). Stejný rozklad v eurech je v dotazu 10.

**US-03 · finanční ředitel · vliv kurzu**
Jako finanční ředitel chci vidět změnu nákladu na silovou elektřinu v korunách rozdělenou na vliv ceny komodity
a vliv kurzu EUR/CZK, abych věděl, jestli koruna firmě v krizi pomohla, nebo uškodila.
Kdy je hotovo: pro změnu z roku 2021 na rok 2022 report ukazuje +105 823 772 Kč, z toho komodita +112 802 613 Kč
a kurz −6 978 840 Kč (dotaz 11).

**US-04 · nákup energií · zajištění ceny**
Jako pracovník nákupu energií chci posuvníkem nastavit, kolik procent roční spotřeby firma koupila předem (0 až 100 %), a vidět,
kolik by zaplatila, abych mohl finančnímu řediteli podložit návrh, kolik elektřiny na příští rok zafixovat.
Kdy je hotovo: při 0 % se náklad rovná nákladu na spotu. Při 100 % report ukazuje pro rok 2022 3 297 116 EUR
s náhradní cenou a 6 685 638 EUR s cenou PXE (dotaz 12). Náhradní cena je označená jako předpoklad.

**US-05 · nákup energií · přirážka za diagram odběru**
Jako pracovník nákupu energií chci vidět, kolik firma ročně zaplatí navíc za to, že bere víc elektřiny v drahých hodinách, abych
věděl, kolik by nejvýš mohl ušetřit přesun směn do levnějších hodin.
Kdy je hotovo: pro rok 2022 report ukazuje přirážku 426,45 Kč/MWh a 11,92 mil. Kč, označenou jako simulovaná.
V eurech je to +17,29 EUR/MWh a 483 333 EUR (dotaz 10).

**US-06.1 · nákup energií · cenová pásma a nejdražší hodiny**
Jako pracovník nákupu energií chci vidět, kolik hodin každého roku spadlo do jednotlivých cenových pásem a které hodiny byly
nejdražší, abych viděl, jak často měl trh extrémní ceny a kdy je nákup jen na spotu riskantní.
Kdy je hotovo: rok 2022 má 3 694 hodin v pásmu extrémní ceny (od 5 821 Kč/MWh, dotaz 05). Hodiny všech pásem dávají
dohromady počet hodin v roce (8 760). Nejdražší hodina je 29. 8. 2022, hodina 20, 21 422,25 Kč/MWh (dotaz 07).

**US-06.2 · nákup energií · špička a mimo špičku**
Jako pracovník nákupu energií chci pro každý rok vidět rozdíl v ceně mezi špičkou (pondělí až pátek, 8:00 až 20:00) a zbytkem týdne,
abych věděl, kolik by mohl ušetřit přesun části výroby do nocí a víkendů.
Kdy je hotovo: v roce 2022 je špička o 60,04 EUR/MWh (1 471,75 Kč/MWh) dražší než hodiny mimo špičku (dotaz 09).
Hodiny ve špičce a mimo ni dávají dohromady všechny hodiny roku (2022: 3 120 + 5 640 = 8 760).

## Návaznost od otázky po stránku reportu

| Obchodní otázka (zadání) | Příběh | SQL | Stránka reportu |
|---|---|---|---|
| 1 Kolik elektřina skutečně stála za kWh? | US-01 | `sql/08_query_allin_price.sql` | Náklad firmy |
| 2 Proč se náklad změnil? | US-02 | `sql/10_query_variance_split.sql` | Příčiny změny |
| 3 Jak náklad v korunách ovlivnil kurz? | US-03 | `sql/11_query_fx_effect.sql` | Příčiny změny |
| 4 Dalo se ztrátě předejít zajištěním? | US-04 | `sql/12_query_hedging.sql` | Zajištění ceny |
| vlastní zjištění | US-05 | `sql/10_query_variance_split.sql`, `sql/12_query_hedging.sql` | Náklad firmy |
| kontext trhu pro otázky 2 a 4 | US-06.1 | `sql/05_query_price_bands.sql`, `sql/07_query_top_hours.sql` | Trh |
| kontext trhu pro otázky 2 a 4 | US-06.2 | `sql/09_query_peak_offpeak.sql` | Trh |

Stránka Shrnutí bere hlavní čísla ze všech těchto stránek.

## Priority (MoSCoW)

| Příběh | Priorita | Proč |
|---|---|---|
| US-01 celkový náklad | Must (nutné) | obchodní otázka 1 a základ všech ostatních stránek |
| US-02 proč se náklad změnil | Must (nutné) | obchodní otázka 2 |
| US-04 posuvník zajištění | Must (nutné) | obchodní otázka 4, hlavní rozhodnutí ze zadání |
| US-05 přirážka za diagram odběru | Must (nutné) | část nákladu, kterou firma může ovlivnit sama, a neodstraní ji ani nákup celé spotřeby předem |
| US-03 vliv kurzu | Should (mělo by být) | obchodní otázka 3, ale malý vliv (6,2 % nárůstu ceny komodity v roce 2022) |
| US-06.1 cenová pásma a nejdražší hodiny | Should (mělo by být) | kontext trhu pro ostatní stránky |
| US-06.2 špička a mimo špičku | Could (může být) | částečně se překrývá s US-05 |

## Co report dělat nebude (Won't)

- Předpovídat ceny: report hodnotí minulost a historie forwardových cen není k dispozici (ADR-003).
- Ukazovat data konkrétní skutečné firmy: odběr je simulovaný a každá stránka to uvádí.
- Počítat faktury a DPH: ceny jsou bez DPH a bez marže dodavatele (ADR-005).
- Pracovat s daty po roce 2024: projekt pokrývá roky 2020–2024.
- Automaticky se aktualizovat: data jsou historická, report se sám neobnovuje.
