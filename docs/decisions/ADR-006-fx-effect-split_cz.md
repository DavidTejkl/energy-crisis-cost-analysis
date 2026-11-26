# ADR-006: Rozklad vlivu kurzu EUR/CZK (vliv komodity a vliv kurzu)

[English](ADR-006-fx-effect-split.md) · **Čeština**

- Datum: 2026-10-22

## Proč bylo potřeba rozhodnout

Obchodní otázka 3 se ptá, jak kurz EUR/CZK ovlivnil náklad v korunách. Ceny OTE jsou v EUR/MWh, firma platí v korunách
a cenu v korunách počítám kurzem ČNB ze stejného dne ([ADR-001](ADR-001-eur-czk-fill-rule_cz.md), pohled
`vw_energy_prices_czk`). Rozklad změny nákladu podle [ADR-004](ADR-004-cost-variance-split_cz.md) je schválně v EUR,
takže kurz potřebuje vlastní rozklad. Vlivy musí dát dohromady celkovou změnu a směr vlivu musí vyjít z dat, ne z mého
předpokladu.

Definice (za rok, z hodinových dat):

- `C_eur` = náklad na silovou elektřinu v EUR = `SUM(load_h × price_eur_h)`
- `C_czk` = náklad na silovou elektřinu v Kč = `SUM(load_h × price_czk_h)`
- `R` = efektivní kurz = `C_czk / C_eur`. Je to kurz vážený nákladem: dny s vysokým nákladem v EUR mají větší váhu než
  dny s nízkým. Prostý roční průměr kurzu by to nezohlednil.

Platí tedy `C_czk = C_eur × R`.

## Jaké možnosti jsem zvažoval

1. Prostý roční průměr kurzu × náklad v EUR. Nevyjde z toho skutečný náklad v korunách, takže by vlivy nedaly dohromady
   celkovou změnu. Zamítl jsem to.
2. Rozklad den po dni (změna nákladu v EUR a změna kurzu v každém dni). Je přesný, ale těžko se vysvětluje.
3. Rozklad přes efektivní kurz `R` v pevném pořadí: komodita (náklad v EUR), potom kurz. Stejná stavba jako v ADR-004.

## Co jsem vybral

Možnost 3. Meziroční změna z roku 0 na rok 1:

| Vliv     | Vzorec                     |
| -------- | -------------------------- |
| Komodita | `(C_eur1 − C_eur0) × R0`   |
| Kurz     | `C_eur1 × (R1 − R0)`       |

Oba vlivy dají dohromady přesně `C_czk1 − C_czk0`:
`(C_eur1 − C_eur0) × R0 + C_eur1 × (R1 − R0) = C_eur1 × R1 − C_eur0 × R0`.

Záporný vliv kurzu znamená, že koruna posílila (za 1 EUR se platí méně korun) a náklad v korunách se tím snížil.
Například v roce 2022 vyšel vliv kurzu −6,98 mil. Kč. Vliv komodity je změna v EUR z ADR-004 (spotřeba + cena na trhu +
diagram odběru) oceněná kurzem předchozího roku. Počítá to dotaz
[sql/11_query_fx_effect.sql](../../sql/11_query_fx_effect.sql).

## Co z toho plyne

- Na pořadí záleží stejně jako v ADR-004. Změnu v EUR oceňuji starým kurzem, změnu kurzu novým nákladem v EUR. Uvádím
  to v hlavičce dotazu i ve zjištěních.
- Rozklad pokrývá jen náklad na silovou elektřinu. Regulované platby ([ADR-005](ADR-005-all-in-price-scope_cz.md)) jsou
  stanovené v korunách a kurz je neovlivňuje.
- `R` vzniká dělením v SQL Serveru a je zaokrouhlený na 6 desetinných míst. Kontrolní rozdíl proto vychází na pár
  korun (nejvýš 2,05 Kč), ne přesně 0. Je to zaokrouhlení, ne chyba metody.
- Diagram odběru je simulovaný (`SIMULATED`), takže velikost obou vlivů v korunách závisí na simulované spotřebě.
  Kurzy a ceny jsou skutečná data (`FACT`).
