# Purpose: one place for paths and project constants used by every pipeline script.
# Scripts import from here, so a path or the analysis period is changed in one file only.

from pathlib import Path

# Paths are built from this file's location, so the project runs from any folder on any PC.
PROJECT_ROOT = Path(__file__).resolve().parent.parent

DATA_DIR = PROJECT_ROOT / "data"
BRONZE_DIR = DATA_DIR / "bronze"    # raw downloads, never edited
SILVER_DIR = DATA_DIR / "silver"    # cleaned data
GOLD_DIR = DATA_DIR / "gold"        # model-ready data
CONFIG_DIR = PROJECT_ROOT / "config"  # ERÚ tariffs with validity periods

# Analysis period of the energy crisis study (2020 = pre-crisis baseline).
START_DATE = "2020-01-01"
END_DATE = "2024-12-31"

# Market hours are in Czech local time, so daylight saving days have 23 or 25 hours.
TIMEZONE = "Europe/Prague"

# Expected sizes, used later as data-quality checks.
EXPECTED_DAYS = 1827           # 2020-01-01 to 2024-12-31, including leap years 2020 and 2024
EXPECTED_PRICE_ROWS = 43848    # 1,827 days x 24 hours; DST +5 and -5 hours cancel out

# SQL Server connection (local default instance, Windows authentication, no password stored).
SQL_SERVER = "localhost"
DATABASE = "EnergyCrisisCostAnalysis"
ODBC_DRIVER = "ODBC Driver 17 for SQL Server"
CONNECTION_STRING = (
    f"DRIVER={{{ODBC_DRIVER}}};"
    f"SERVER={SQL_SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
)
