# Purpose: download the raw source files into data/bronze/ exactly as published.
# Bronze is never edited, so every later step can be rebuilt from these files.

import requests

from config import (
    CNB_BRONZE_DIR, CNB_FX_URL, CNB_FX_YEARS, CNB_REPO_URL, OTE_BRONZE_DIR, OTE_URL, YEARS,
)


def download_file(url, target_path):
    """Download one file unchanged. Skip it if it is already there, so a second run is safe."""
    if target_path.exists() and target_path.stat().st_size > 0:
        print(f"  skip, already downloaded: {target_path.name}")
        return

    print(f"  downloading {url}")
    response = requests.get(url, timeout=120)
    # Stop the pipeline on a 404 or server error instead of saving an error page as data.
    response.raise_for_status()

    target_path.parent.mkdir(parents=True, exist_ok=True)
    target_path.write_bytes(response.content)
    print(f"  saved {target_path.name} ({len(response.content):,} bytes)")


def download_ote_year(year):
    """Download the OTE yearly market report (zip with one Excel file) for one year."""
    url = OTE_URL.format(year=year)
    # Keep the original file name, so a bronze file can be traced back to its source.
    target_path = OTE_BRONZE_DIR / f"Rocni_zprava_o_trhu_{year}_V2.zip"
    download_file(url, target_path)


def download_cnb_fx_year(year):
    """Download the ČNB exchange rate file (all currencies, working days) for one year."""
    url = CNB_FX_URL.format(year=year)
    # The URL has no file name of its own, so the year goes into the name.
    target_path = CNB_BRONZE_DIR / f"cnb_fx_{year}.txt"
    download_file(url, target_path)


def download_cnb_repo_rate():
    """Download the full history of the ČNB 2-week repo rate (one file)."""
    target_path = CNB_BRONZE_DIR / "vyvoj_repo_historie.txt"
    download_file(CNB_REPO_URL, target_path)


if __name__ == "__main__":
    print("OTE day-ahead market, yearly reports:")
    for year in YEARS:
        download_ote_year(year)

    print("ČNB EUR/CZK exchange rates:")
    for year in CNB_FX_YEARS:
        download_cnb_fx_year(year)

    print("ČNB 2-week repo rate:")
    download_cnb_repo_rate()
    print("Done.")
