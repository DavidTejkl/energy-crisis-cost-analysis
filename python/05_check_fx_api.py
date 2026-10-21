# Purpose: cross-check the silver EUR/CZK rates against the ČNB REST API for a few days.
# The pipeline downloads yearly text files; the API is a second, independent channel to the same
# source, so a match shows the download and the cleaning (incl. the ADR-001 fill rule) are right.

import pandas as pd
import requests

from config import CNB_API_URL, FX_API_CHECK_DATES, SILVER_DIR


def get_cnb_eur_rate(day):
    """Ask the ČNB API for one day and return the EUR row (validFor date + rate)."""
    params = {"date": day, "lang": "EN"}
    response = requests.get(CNB_API_URL, params=params, timeout=30)
    # Stop on a 404 or server error instead of reading an error page as data.
    response.raise_for_status()

    data = response.json()
    for rate in data["rates"]:
        if rate["currencyCode"] == "EUR":
            return rate
    # A day without EUR would mean the API changed, not that the rate is zero.
    raise ValueError(f"No EUR rate in the ČNB API answer for {day}")


def compare_day(fx, day):
    """Compare one day of silver fact_fx with the API. Return True when rate and source date match."""
    date_key = int(day.replace("-", ""))
    silver_row = fx[fx["date_key"] == date_key].iloc[0]
    api_row = get_cnb_eur_rate(day)

    # Round both to 3 decimals: ČNB publishes 3, and float numbers may differ in the last digit.
    same_rate = round(silver_row["rate_czk_per_eur"], 3) == round(api_row["rate"], 3)
    # The API answers a weekend or holiday with the last published day = our source_date (ADR-001).
    same_date = silver_row["source_date"] == api_row["validFor"]

    print(f"  {day}: silver {silver_row['rate_czk_per_eur']} from {silver_row['source_date']}"
          f" | API {api_row['rate']} from {api_row['validFor']}"
          f" -> {'OK' if same_rate and same_date else 'DIFFERENCE'}")
    return same_rate and same_date


if __name__ == "__main__":
    fx = pd.read_csv(SILVER_DIR / "fact_fx.csv")
    print("Silver EUR/CZK vs ČNB REST API:")

    matches = 0
    for day in FX_API_CHECK_DATES:
        if compare_day(fx, day):
            matches += 1

    print(f"{matches} of {len(FX_API_CHECK_DATES)} days match.")
