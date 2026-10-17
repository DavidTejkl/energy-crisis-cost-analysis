# Purpose: build the SIMULATED hourly load profile of the model company for 2020-2024.
# Real load curves are trade secrets, so the profile is generated from three layers
# (continuous kilns, shift-based crushing and milling, day-shift dispatch) described in
# docs/methodology.md. Output: data/silver/fact_load.csv, one row per delivery day and hour.

import numpy as np
import pandas as pd

import config


def read_calendar():
    """Return every delivery hour of 2020-2024 with its weekday and month."""
    # The hour list comes from the OTE prices, so DST days have 23 or 25 hours like the prices.
    hours = pd.read_csv(config.SILVER_DIR / "fact_energy_prices.csv", usecols=["date_key", "hour_of_day"])
    dates = pd.read_csv(config.SILVER_DIR / "dim_date.csv", usecols=["date_key", "year", "month", "weekday_num"])
    calendar = hours.merge(dates, on="date_key", how="left")
    print(f"Calendar: {len(calendar)} hours, {calendar['date_key'].nunique()} days")
    return calendar


def add_layers(calendar):
    """Mark which load layers run in each hour (1 = running, 0 = stopped)."""
    df = calendar.copy()
    hour = df["hour_of_day"]
    weekday = df["weekday_num"]   # 1 = Monday ... 7 = Sunday
    is_winter = df["month"].isin(config.WINTER_MONTHS)

    # hour_of_day is the sequential delivery hour: hour 23 = 22:00-23:00, hour 7 = 06:00-07:00.
    # Outside winter: three shifts from Sunday 22:00 (hours 23-24) to Friday 22:00 (hours 1-22).
    shift_normal = (weekday.between(1, 4)) | ((weekday == 5) & (hour <= 22)) | ((weekday == 7) & (hour >= 23))
    # In winter only the morning and afternoon shift, Monday to Friday 06:00-22:00.
    shift_winter = weekday.between(1, 5) & hour.between(7, 22)

    df["base_on"] = 1
    df["shift_on"] = 0
    df.loc[~is_winter & shift_normal, "shift_on"] = 1
    df.loc[is_winter & shift_winter, "shift_on"] = 1
    df["day_on"] = 0
    df.loc[weekday.between(1, 5) & hour.between(7, 14), "day_on"] = 1
    return df


def compute_load(layers):
    """Turn the running layers into hourly load in MWh, scaled to the yearly target."""
    df = layers.copy()
    weight = (df["base_on"] * config.LOAD_BASE_WEIGHT
              + df["shift_on"] * config.LOAD_SHIFT_WEIGHT
              + df["day_on"] * config.LOAD_DAY_WEIGHT)

    # Small random variation per hour; the fixed seed makes every run identical.
    rng = np.random.default_rng(config.LOAD_RANDOM_SEED)
    noise = rng.uniform(1 - config.LOAD_NOISE, 1 + config.LOAD_NOISE, size=len(df))
    weight = weight * noise

    # One scale factor for the whole period: the average year hits the target, while each year
    # keeps its own calendar (leap years, number of weekdays) instead of being forced to 28 GWh.
    years = df["year"].nunique()
    factor = config.LOAD_TARGET_MWH_PER_YEAR * years / weight.sum()
    df["load_mwh"] = (weight * factor).round(3)
    df["is_simulated"] = 1
    return df


def save_load(df):
    """Save the profile to the silver layer."""
    output = df[["date_key", "hour_of_day", "load_mwh", "is_simulated"]]
    path = config.SILVER_DIR / "fact_load.csv"
    output.to_csv(path, index=False)
    print(f"Saved {len(output)} rows to {path}")


if __name__ == "__main__":
    calendar = read_calendar()
    layers = add_layers(calendar)
    load = compute_load(layers)
    print(load.groupby("year")["load_mwh"].sum().round(1))
    print(f"Hourly load: min {load['load_mwh'].min()} / max {load['load_mwh'].max()} MWh")
    save_load(load)
