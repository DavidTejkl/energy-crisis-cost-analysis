# Purpose: load the cleaned silver CSV files into the SQL Server star schema, incrementally:
# only rows newer than what the table already holds are inserted, so a second run inserts 0 rows.
# CSV column names are identical to the table column names, so one function loads any table.
# A full rebuild = run sql/02_create_tables.sql (empty tables), then this script loads everything.

import pandas as pd
import pyodbc

from config import CONFIG_DIR, CONNECTION_STRING, SILVER_DIR

# Load order: dimensions before facts, because the foreign keys in the facts
# only accept date_key / hour_of_day values that already exist in the dimensions.
TABLES = ["dim_date", "dim_hour", "repo_rate", "regulated_price", "fact_energy_prices", "fact_fx", "fact_load"]

SCRIPT_NAME = "03_load.py"

# Watermark column per table: the highest value already in the table marks how far it is loaded.
# Facts are loaded day by day in one transaction, so a day is never loaded only partly.
WATERMARK_COLUMNS = {
    "dim_date": "date_key",
    "dim_hour": "hour_of_day",
    "repo_rate": "valid_from",
    "regulated_price": "valid_from",
    "fact_energy_prices": "date_key",
    "fact_fx": "date_key",
    "fact_load": "date_key",
}


def get_watermark(cursor, table_name):
    """Return the highest watermark value in the table, or None when the table is empty."""
    column = WATERMARK_COLUMNS[table_name]
    cursor.execute(f"SELECT MAX({column}) FROM dbo.{table_name}")
    return cursor.fetchone()[0]


def keep_new_rows(df, table_name, watermark):
    """Keep only the CSV rows above the watermark; an empty table gets all rows."""
    if watermark is None:
        return df
    column = WATERMARK_COLUMNS[table_name]
    # valid_from is text in the CSV but a date in the database, so both are compared as dates.
    if column == "valid_from":
        return df[pd.to_datetime(df[column]) > pd.Timestamp(watermark)]
    return df[df[column] > watermark]


def load_table(cursor, table_name):
    """Insert the new rows of data/silver/<table_name>.csv into the table; return the row count."""
    # ERÚ prices are typed by hand into config/ (reference data), not produced by the transform.
    if table_name == "regulated_price":
        df = pd.read_csv(CONFIG_DIR / "tariffs.csv")
    else:
        df = pd.read_csv(SILVER_DIR / f"{table_name}.csv")

    watermark = get_watermark(cursor, table_name)
    df = keep_new_rows(df, table_name, watermark)
    if len(df) == 0:
        print(f"{table_name}: up to date (watermark {watermark}), 0 rows inserted")
        return 0

    columns = ", ".join(df.columns)
    placeholders = ", ".join(["?"] * len(df.columns))
    sql = f"INSERT INTO dbo.{table_name} ({columns}) VALUES ({placeholders})"

    cursor.executemany(sql, df.values.tolist())
    print(f"{table_name}: watermark {watermark}, {len(df)} rows inserted")
    return len(df)


def log_start(log_cursor, table_name):
    """Write a RUNNING row into etl_run_log and return its run_id."""
    log_cursor.execute(
        "INSERT INTO dbo.etl_run_log (script_name, table_name, started_at, status) "
        "OUTPUT INSERTED.run_id VALUES (?, ?, SYSDATETIME(), 'RUNNING')",
        SCRIPT_NAME, table_name,
    )
    return log_cursor.fetchone()[0]


def log_end(log_cursor, run_id, status, rows_inserted, error_message):
    """Close the log row: end time, OK or FAIL, inserted rows and the error text if any."""
    # Rows are only inserted, never updated, so rows_updated is always 0.
    log_cursor.execute(
        "UPDATE dbo.etl_run_log SET finished_at = SYSDATETIME(), status = ?, rows_inserted = ?, "
        "rows_updated = 0, error_message = ? WHERE run_id = ?",
        status, rows_inserted, error_message, run_id,
    )


def count_rows(cursor, table_name):
    """Return the number of rows in the table, used to check the load."""
    cursor.execute(f"SELECT COUNT(*) FROM dbo.{table_name}")
    return cursor.fetchone()[0]


if __name__ == "__main__":
    connection = pyodbc.connect(CONNECTION_STRING)
    cursor = connection.cursor()
    # Sends the rows in batches instead of one network round trip per row.
    cursor.fast_executemany = True

    # The log uses its own connection with autocommit: a failed load is rolled back,
    # but its FAIL row must stay in etl_run_log.
    log_connection = pyodbc.connect(CONNECTION_STRING, autocommit=True)
    log_cursor = log_connection.cursor()

    run_ids = {}
    inserted = {}
    try:
        for table_name in TABLES:
            run_ids[table_name] = log_start(log_cursor, table_name)
            inserted[table_name] = load_table(cursor, table_name)
        # One commit at the end: if any step fails, nothing is saved and the tables stay as before.
        connection.commit()
    except pyodbc.Error as error:
        connection.rollback()
        # Every table of this run is marked FAIL, because the rollback undid all of them.
        # ODBC error texts can be longer than the column (nvarchar 4000), so the text is cut.
        for table_name in run_ids:
            log_end(log_cursor, run_ids[table_name], "FAIL", 0, str(error)[:4000])
        print(f"Load failed, nothing saved: {error}")
        raise

    for table_name in TABLES:
        log_end(log_cursor, run_ids[table_name], "OK", inserted[table_name], None)
    log_connection.close()

    for table_name in TABLES:
        print(f"{table_name}: {count_rows(cursor, table_name)} rows in database")

    connection.close()
