# Metodika: simulovaný odběr

[English](methodology.md) · **Čeština**

Firmy své skutečné hodinové odběry nezveřejňují, proto má modelová firma ze
[zadání projektu](01_project_brief_cz.md) odběr vygenerovaný. Každý řádek má příznak `is_simulated = 1`. Každé číslo,
které na tomto odběru závisí (spotřeba, náklady v Kč, vliv diagramu odběru), je označené `SIMULATED`.

Skript: `python/04_generate_load_profile.py` · konstanty: `python/config.py` · výstup: `data/silver/fact_load.csv`

## Nápad: tři vrstvy

Nepřetržitý vysokoteplotní proces se v noci ani o víkendu nezastaví, provoz kolem něj ale ano. Odběr jsem proto složil
ze tří vrstev. Každá vrstva v dané hodině buď běží (1), nebo stojí (0), a má pevný poměrný příkon (váhu).

| Vrstva                          | Co běží                                 | Kdy                                        | Váha |
| ------------------------------- | --------------------------------------- | ------------------------------------------ | ---: |
| Základ                          | pece, ventilátory, odprášení, dmychadla | každou hodinu v roce                       |  1,3 |
| Směny                           | drcení, mletí, třídění, balení          | od neděle 22:00 do pátku 22:00 (tři směny) |  2,1 |
| Směny v zimě (prosinec až únor) | totéž                                   | pondělí až pátek 6:00–22:00 (dvě směny)    |  2,1 |
| Den                             | expedice, kanceláře                     | pondělí až pátek 6:00–14:00                |  0,6 |

`hour_of_day` je pořadová hodina dodávky: hodina 7 je 6:00–7:00, hodina 23 je 22:00–23:00.

Postup:

1. Seznam hodin beru z cen OTE (43 848 řádků), takže dny se změnou času mají 23 nebo 25 hodin stejně jako ceny.
2. Váha hodiny je součet vah vrstev, které v té hodině běží.
3. Každá hodina dostane náhodnou odchylku ±3 % , aby křivka nevypadala uměle.
4. Celé období přepočítám jedním koeficientem tak, aby průměrný rok měl 28 000 MWh. Každý rok si nechává svůj
   kalendář (přestupný rok, počet pracovních dní), takže se roční součty trochu liší. Uměle je na stejnou hodnotu
   nesrovnávám.

## Předpoklady

| Položka              | Hodnota         | Z čeho vychází                                                                                                                                                                                                                                                                                                |
| -------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Roční spotřeba       | 28 GWh          | `ASSUMPTION`. Řádově odpovídá závodu s pecemi, který vyrobí několik set tisíc tun ročně. Výroba vápna spotřebuje 40–140 kWh elektřiny na tunu podle typu pece a toho, jak jemné vápno má být ([IPCC AR4, WG III, kapitola 7, oddíl 7.4.5.2, s. 468](https://www.ipcc.ch/site/assets/uploads/2018/02/ar4-wg3-chapter7.pdf#page=22)), takže 28 GWh do tohoto rozsahu spadá. |
| Váhy vrstev          | 1,3 / 2,1 / 0,6 | `ASSUMPTION`. Pece spotřebují elektřiny poměrně málo (většinu energie dodává palivo), nejvíc jí spotřebuje drcení a mletí.                                                                                                                                                                                    |
| Rozvrh směn          | podle tabulky   | `ASSUMPTION` podle běžného nepřetržitého provozu.                                                                                                                                                                                                                                                             |
| Rezervovaná kapacita | 5 MW            | `ASSUMPTION`. Nejvyšší hodinový odběr je 4,665 MWh, takže zbývá rezerva asi 7 %.                                                                                                                                                                                                                              |

## Zjednodušení (co odběr neobsahuje)

- Plánované odstávky a opravy.
- Státní svátky se berou jako běžné pracovní dny (`dim_date` zatím nemá příznak svátku).
- Neděle se změnou času: směna začíná podle pořadové hodiny, takže dvě neděle se změnou času v roce začne o hodinu
  jinak, než ukazují hodiny realně.
- Firma na ceny nereaguje: spotřeba i tvar odběru jsou každý rok stejné. Změny nákladu proto vycházejí z cen, ne z toho,
  jak se firma chovala.

## Kontroly (spuštěno 17. 10. 2026)

- 43 848 řádků, 1 827 dní. Dvě spuštění dají bajtově stejný soubor (stejný SHA-256).
- Roční součty: 28 050,9 / 27 993,7 / 27 953,4 / 27 948,9 / 28 053,0 MWh (2020–2024).
- Hodinový odběr 1,428–4,665 MWh. V sobotu je průměr 1,47 MWh, protože běží jen základní vrstva.
- Cena vážená odběrem je v každém roce vyšší než prostý průměr ceny, takže vliv diagramu odběru v datech opravdu je,
  viz [ADR-004](decisions/ADR-004-cost-variance-split_cz.md).
