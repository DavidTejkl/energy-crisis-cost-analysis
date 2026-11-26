# ADR-004: Rozklad změny nákladu (vliv spotřeby, ceny na trhu a diagramu odběru)

[English](ADR-004-cost-variance-split.md) · **Čeština**

- Datum: 2026-10-14

## Proč bylo potřeba rozhodnout

Obchodní otázka 2 se ptá, proč se náklad na elektřinu meziročně změnil. Kvůli ceně na trhu, kvůli spotřebě, nebo kvůli
diagramu odběru, tedy kvůli tomu, v kterých hodinách firma elektřinu odebírá?

První návrh rozkladu pracoval jen s roční spotřebou a roční průměrnou cenou. Tím se ztratila informace z jednotlivých
hodin, vliv diagramu odběru vycházel vždycky 0 a na otázku se nedalo odpovědět. Nový rozklad proto musí splnit dvě
pravidla: vlivy dají dohromady přesně celkovou změnu a vliv diagramu odběru nevychází nulový jen kvůli tomu, jak je
výpočet postavený.

Definice (za rok, z hodinových dat):

- `V` = spotřeba firmy v MWh = `SUM(volume_h)`
- `C` = náklad na silovou elektřinu = `SUM(volume_h × price_h)`
- `Pw` = cena, kterou firma zaplatila, vážená odběrem = `C / V`
- `Pb` = základní cena trhu = prostý průměr všech hodinových cen. Odpovídá rovnému odběru, stejně jako náhradní cena
  base load v [ADR-003](ADR-003-forward-price-proxy_cz.md).
- `S` = přirážka za diagram odběru = `Pw − Pb`. Kladná znamená, že firma bere víc elektřiny v drahých hodinách,
  záporná, že víc v levných. Rovný odběr má `S = 0`.

Platí tedy `C = V × Pw = V × (Pb + S)`.

## Jaké možnosti jsem zvažoval

1. Jen spotřeba a průměrná cena. Vliv diagramu odběru je vždy 0, proto jsem to zamítl.
2. Rozklad hodinu po hodině (změna spotřeby a ceny v každé hodině). Je přesný, ale těžko se vysvětluje a výsledek se
   skládá z 8 760 malých částí.
3. Rozklad přes přirážku za diagram odběru `S` v pevném pořadí: spotřeba, potom cena na trhu, potom diagram odběru.

## Co jsem vybral

Možnost 3. Meziroční změna z roku 0 na rok 1:

| Vliv           | Vzorec              |
| -------------- | ------------------- |
| Spotřeba       | `(V1 − V0) × Pw0`   |
| Cena na trhu   | `V1 × (Pb1 − Pb0)`  |
| Diagram odběru | `V1 × (S1 − S0)`    |

Tyto tři vlivy dají dohromady přesně `C1 − C0` a nic nezbyde:
`(V1 − V0) × Pw0 + V1 × (Pw1 − Pw0) = V1 × Pw1 − V0 × Pw0` a zároveň `Pw1 − Pw0 = (Pb1 − Pb0) + (S1 − S0)`.

Příklad (jeden den, dvě hodiny):

| Hodina | Cena (EUR/MWh) | Odběr (MWh) |
| ------ | -------------: | ----------: |
| noc    |             50 |           1 |
| den    |            150 |           3 |

`Pb = (50 + 150) / 2 = 100`, `Pw = (1 × 50 + 3 × 150) / 4 = 125`, `S = 125 − 100 = +25`. Firma platí o 25 EUR/MWh víc,
než je průměr trhu, protože většinu elektřiny bere v drahé hodině.

Rozklad počítám v EUR, takže do něj nevstupuje kurz. Vliv kurzu EUR/CZK rozkládám zvlášť
([ADR-006](ADR-006-fx-effect-split_cz.md)). Rozklad pokrývá jen náklad na silovou elektřinu, regulované platby patří
do celkové ceny ([ADR-005](ADR-005-all-in-price-scope_cz.md)). Počítá ho dotaz
[sql/10_query_variance_split.sql](../../sql/10_query_variance_split.sql).

## Co z toho plyne

- Na pořadí záleží. Změnu spotřeby oceňuji starou cenou, změnu ceny novou spotřebou. Jiné pořadí by dalo trochu jiné
  vlivy. Pořadí je pevně dané tady a uvádím ho v hlavičce dotazu i ve zjištěních.
- Vliv diagramu odběru se může změnit, i když firma odebírá pořád stejně. Stačí, aby se změnilo, jak se ceny na trhu
  rozkládají během dne (například levnější polední hodiny, když víc vyrábí fotovoltaika). Je to záměr: vliv ukazuje,
  jak dobře se diagram firmy hodí k cenám na trhu.
- Diagram odběru firmy je simulovaný (`SIMULATED`, `is_simulated = 1`). Vliv spotřeby a vliv diagramu proto ukazují
  předpoklady generátoru ([metodika](../methodology_cz.md)), ne skutečnou firmu. Vliv ceny na trhu stojí na skutečných
  cenách OTE (`FACT`). Ve zjištěních to uvádím.
- Kontrola v dotazu 10: tři vlivy dají dohromady `C1 − C0` pro každou dvojici let a vliv diagramu odběru není 0.
  SQL Server při dělení zaokrouhlí `Pw` na 6 desetinných míst, proto kontrolní rozdíl vychází nejvýš 0,03 EUR, ne
  přesně 0. Je to zaokrouhlení, ne chyba metody.
