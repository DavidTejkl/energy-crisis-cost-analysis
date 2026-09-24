# Purpose: clean the raw bronze files into model-ready silver tables
# (fact_energy_prices, dim_date, dim_hour, fact_fx, repo_rate).

import io
import zipfile

import pandas as pd

from config import (
    CNB_BRONZE_DIR, CNB_FX_YEARS, END_DATE, OTE_BRONZE_DIR, SILVER_DIR, START_DATE, YEARS,
)

OTE_SHEET = "DT ČR"
OTE_HEADER_ROW = 5  # row 6 in Excel (0-indexed), see docs/01_project_brief.md


def read_ote_year(year):
    """Read one OTE yearly report zip and return its hourly price/volume rows."""
    zip_path = OTE_BRONZE_DIR / f"Rocni_zprava_o_trhu_{year}_V2.zip"

    with zipfile.ZipFile(zip_path) as zf:
        # The zip holds exactly one Excel file (.xls for 2020-2023, .xlsx for 2024).
        excel_name = zf.namelist()[0]
        with zf.open(excel_name) as f:
            excel_bytes = io.BytesIO(f.read())

    df = pd.read_excel(excel_bytes, sheet_name=OTE_SHEET, header=OTE_HEADER_ROW)
    # 2024 headers contain line breaks (e.g. "Saldo DT\n(MWh)") -> normalise before selecting by name.
    df.columns = [str(c).replace("\n", " ") for c in df.columns]

    df = df[["Den", "Hodina", "Marginální cena ČR (EUR/MWh)", "Množství - vč. Exp a Imp (MWh)"]]
    df = df.rename(columns={
        "Den": "full_date",
        "Hodina": "hour_of_day",
        "Marginální cena ČR (EUR/MWh)": "price_eur_mwh",
        "Množství - vč. Exp a Imp (MWh)": "volume_mwh",
    })
    return df


def read_cnb_fx_year(year):
    """Read one ČNB FX file and return the EUR/CZK rate per date.

    The 2022 file repeats the header row on 2 March (RUB column dropped) as if it were a
    data row -> drop that one row, then convert EUR column text to numbers.
    """
    path = CNB_BRONZE_DIR / f"cnb_fx_{year}.txt"
    df = pd.read_csv(path, sep="|")
    df = df[df["Datum"] != "Datum"]

    df["full_date"] = pd.to_datetime(df["Datum"], format="%d.%m.%Y")
    df["rate_czk_per_eur"] = df["1 EUR"].str.replace(",", ".").astype(float)
    return df[["full_date", "rate_czk_per_eur"]]


def read_all_cnb_fx():
    """Read all ČNB FX files (2019-2024) and combine them into one table."""
    all_years = [read_cnb_fx_year(year) for year in CNB_FX_YEARS]
    return pd.concat(all_years, ignore_index=True)


def fill_fx_gaps(fx):
    """Fill every calendar day of the project with a rate (ADR-001).

    ČNB has no rate on weekends/holidays, so those days get the last previously
    published rate. is_actual_rate and source_date record whether a row is real or filled.
    """
    calendar = pd.DataFrame({"full_date": pd.date_range(fx["full_date"].min(), END_DATE, freq="D")})
    fx = calendar.merge(fx, on="full_date", how="left")

    fx["is_actual_rate"] = fx["rate_czk_per_eur"].notna().astype(int)
    # source_date is only known for rows with a real rate; leave the rest empty for now.
    fx["source_date"] = None
    fx.loc[fx["is_actual_rate"] == 1, "source_date"] = fx.loc[fx["is_actual_rate"] == 1, "full_date"]

    # Carry the last known rate/source_date forward into every gap (weekend, holiday).
    fx["rate_czk_per_eur"] = fx["rate_czk_per_eur"].ffill()
    fx["source_date"] = fx["source_date"].ffill()
    # The column started as None, so pandas stored it as plain objects; convert it back to a
    # real date type, otherwise the CSV gets "00:00:00" on every source_date.
    fx["source_date"] = pd.to_datetime(fx["source_date"])

    return fx[fx["full_date"] >= START_DATE].reset_index(drop=True)


def read_repo_rate():
    """Read the full ČNB repo rate history and compute each period's end date (valid_to)."""
    path = CNB_BRONZE_DIR / "vyvoj_repo_historie.txt"
    df = pd.read_csv(path, sep="|", encoding="utf-8-sig", decimal=",")
    df = df.rename(columns={"PLATNA_OD": "valid_from", "CNB_REPO_SAZBA_V_%": "repo_rate_pct"})
    df["valid_from"] = pd.to_datetime(df["valid_from"], format="%Y%m%d")

    # Drop rate changes after the project ends BEFORE computing valid_to, so the true
    # last relevant row gets capped at the project end instead of a later real change date.
    df = df[df["valid_from"] <= END_DATE].reset_index(drop=True)

    # A period ends the day before the next rate change starts.
    df["valid_to"] = df["valid_from"].shift(-1) - pd.Timedelta(days=1)
    # The last period has no "next" row -> cap it at the end of the project instead of NaT.
    df.loc[df.index[-1], "valid_to"] = pd.Timestamp(END_DATE)

    # Older rows (rate changes long before the project started) are not needed.
    return df[df["valid_to"] >= START_DATE].reset_index(drop=True)


CZECH_WEEKDAYS = {
    "Monday": "Pondělí", "Tuesday": "Úterý", "Wednesday": "Středa", "Thursday": "Čtvrtek",
    "Friday": "Pátek", "Saturday": "Sobota", "Sunday": "Neděle",
}


def build_dim_date():
    """Build dim_date: one row per calendar day of the project, with calendar attributes."""
    dim_date = pd.DataFrame({"full_date": pd.date_range(START_DATE, END_DATE, freq="D")})

    dim_date["date_key"] = dim_date["full_date"].dt.strftime("%Y%m%d").astype(int)
    dim_date["day_of_month"] = dim_date["full_date"].dt.day
    dim_date["month"] = dim_date["full_date"].dt.month
    dim_date["year"] = dim_date["full_date"].dt.year
    dim_date["quarter"] = dim_date["full_date"].dt.quarter
    dim_date["week_of_year"] = dim_date["full_date"].dt.isocalendar().week
    dim_date["weekday_num"] = dim_date["full_date"].dt.dayofweek + 1  # Monday=1 ... Sunday=7
    dim_date["weekday_name"] = dim_date["full_date"].dt.day_name().map(CZECH_WEEKDAYS)
    dim_date["is_weekend"] = (dim_date["weekday_num"] >= 6).astype(int)

    return dim_date


def categorize_hour(hour_of_day):
    """Map one sequential hour (1-25) to a simple time-of-day label."""
    if 7 <= hour_of_day <= 10:
        return "ráno"
    if 11 <= hour_of_day <= 12:
        return "dopoledne"
    if 13 <= hour_of_day <= 18:
        return "odpoledne"
    if 19 <= hour_of_day <= 21:
        return "večer"
    return "noc"


def build_dim_hour():
    """Build dim_hour: one row per sequential hour of the day (1-25, see DST note in brief)."""
    dim_hour = pd.DataFrame({"hour_of_day": range(1, 26)})
    dim_hour["time_of_day"] = dim_hour["hour_of_day"].apply(categorize_hour)
    return dim_hour


def add_date_key(df):
    """Replace full_date with date_key (YYYYMMDD), the key that links a fact table to dim_date.

    The date itself lives only in dim_date; facts carry just the key (docs/data_model.md).
    price_czk_mwh is not stored: it is computed in SQL from fact_fx, so the rate lives in one place.
    """
    df = df.copy()
    df.insert(0, "date_key", df["full_date"].dt.strftime("%Y%m%d").astype(int))
    return df.drop(columns=["full_date"])


def read_all_ote_prices():
    """Read all five yearly OTE reports and combine them into one hourly price table."""
    all_years = [read_ote_year(year) for year in YEARS]
    return pd.concat(all_years, ignore_index=True)


if __name__ == "__main__":
    prices = read_all_ote_prices()
    print("total rows:", len(prices))

    # DST check: count hours per day, then show the min and max (expect 23 and 25).
    hours_per_day = prices.groupby("full_date")["hour_of_day"].count()
    print("min hours in a day:", hours_per_day.min())
    print("max hours in a day:", hours_per_day.max())

    duplicate_rows = prices.duplicated(subset=["full_date", "hour_of_day"]).sum()
    print("duplicate day+hour rows:", duplicate_rows)

    fx = read_all_cnb_fx()
    print("\nfx total rows:", len(fx))
    # The 2022 header repeat is right after 28.02.2022 -> check the rate is still sane there.
    print(fx[(fx["full_date"] >= "2022-02-28") & (fx["full_date"] <= "2022-03-03")])

    fx_filled = fill_fx_gaps(fx)
    print("\nfx_filled total rows:", len(fx_filled))
    # 1 Jan 2020 is a Wednesday with no ČNB rate -> should be filled from 31 Dec 2019.
    print(fx_filled[fx_filled["full_date"] <= "2020-01-03"])

    repo = read_repo_rate()
    print("\nrepo rate periods:", len(repo))
    print(repo)

    dim_date = build_dim_date()
    print("\ndim_date rows:", len(dim_date))
    # 1 Jan 2020 is a Wednesday -> weekday_num 3, is_weekend 0.
    print(dim_date[dim_date["full_date"] == "2020-01-01"])

    dim_hour = build_dim_hour()
    print("\ndim_hour rows:", len(dim_hour))
    print(dim_hour)

    fact_prices = add_date_key(prices)
    fact_fx = add_date_key(fx_filled)
    # Every fact date_key must exist in dim_date, otherwise the foreign key in SQL will fail.
    print("\nprice date_keys missing in dim_date:", (~fact_prices["date_key"].isin(dim_date["date_key"])).sum())
    print("fx date_keys missing in dim_date:", (~fact_fx["date_key"].isin(dim_date["date_key"])).sum())
    print(fact_prices.head(3))

    SILVER_DIR.mkdir(parents=True, exist_ok=True)
    fact_prices.to_csv(SILVER_DIR / "fact_energy_prices.csv", index=False)
    fact_fx.to_csv(SILVER_DIR / "fact_fx.csv", index=False)
    repo.to_csv(SILVER_DIR / "repo_rate.csv", index=False)
    dim_date.to_csv(SILVER_DIR / "dim_date.csv", index=False)
    dim_hour.to_csv(SILVER_DIR / "dim_hour.csv", index=False)
    print("\nSaved 5 silver files to", SILVER_DIR)
