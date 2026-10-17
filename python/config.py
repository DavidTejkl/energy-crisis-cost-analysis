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

YEARS = [2020, 2021, 2022, 2023, 2024]

# OTE yearly market report, version V2 = final monthly settlement (see docs/01_project_brief.md).
OTE_URL = "https://www.ote-cr.cz/pubweb/attachments/62_162/{year}/Rocni_zprava_o_trhu_{year}_V2.zip"
OTE_BRONZE_DIR = BRONZE_DIR / "ote"

# ČNB EUR/CZK rates, one text file per year. 2019 is included because 1 January 2020 has no
# ČNB rate and is filled from the last 2019 working day (ADR-001).
CNB_FX_URL = ("https://www.cnb.cz/cs/financni-trhy/devizovy-trh/kurzy-devizoveho-trhu/"
              "kurzy-devizoveho-trhu/rok.txt?rok={year}")
CNB_FX_YEARS = [2019] + YEARS

# ČNB 2-week repo rate, full history in one file (ADR-002).
CNB_REPO_URL = "https://www.cnb.cz/cs/casto-kladene-dotazy/.galleries/vyvoj_repo_historie.txt"
CNB_BRONZE_DIR = BRONZE_DIR / "cnb"

# Market hours are in Czech local time, so daylight saving days have 23 or 25 hours.
TIMEZONE = "Europe/Prague"

# Expected sizes, used later as data-quality checks.
EXPECTED_DAYS = 1827           # 2020-01-01 to 2024-12-31, including leap years 2020 and 2024
EXPECTED_PRICE_ROWS = 43848    # 1,827 days x 24 hours; DST +5 and -5 hours cancel out

# SIMULATED load profile of the model company (docs/methodology.md). Real load curves are trade
# secrets, so the profile is built from three layers whose relative power levels are ASSUMPTIONS.
LOAD_BASE_WEIGHT = 1.3     # kilns, fans, dedusting, blowers: every hour of the year
LOAD_SHIFT_WEIGHT = 2.1    # crushing, milling, screening, packing: Sunday 22:00 to Friday 22:00
LOAD_DAY_WEIGHT = 0.6      # dispatch and offices: weekday morning shift 06:00-14:00
WINTER_MONTHS = [12, 1, 2]  # construction slowdown: shift layer runs only 06:00-22:00 on weekdays
LOAD_TARGET_MWH_PER_YEAR = 28000   # average yearly consumption of the model company (ASSUMPTION)
LOAD_NOISE = 0.03          # +-3 % random variation per hour, so the curve does not look artificial
LOAD_RANDOM_SEED = 42      # fixed seed: every run produces exactly the same profile

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
