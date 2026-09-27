# Purpose: load the cleaned silver CSV files into the SQL Server star schema.
# CSV column names are identical to the table column names, so one function loads any table.

import pandas as pd
import pyodbc

from config import CONNECTION_STRING, SILVER_DIR

# Load order: dimensions before facts, because the foreign keys in the facts
# only accept date_key / hour_of_day values that already exist in the dimensions.
TABLES = ["dim_date", "dim_hour", "repo_rate", "fact_energy_prices", "fact_fx"]


def clear_tables(cursor):
    """Delete all rows in reverse load order (facts first), so the script can run again."""
    # TRUNCATE is not allowed on tables referenced by a foreign key, so DELETE is used.
    for table_name in reversed(TABLES):
        cursor.execute(f"DELETE FROM dbo.{table_name}")
        print(f"{table_name}: cleared")


def load_table(cursor, table_name):
    """Insert all rows of data/silver/<table_name>.csv into the table of the same name."""
    df = pd.read_csv(SILVER_DIR / f"{table_name}.csv")

    columns = ", ".join(df.columns)
    placeholders = ", ".join(["?"] * len(df.columns))
    sql = f"INSERT INTO dbo.{table_name} ({columns}) VALUES ({placeholders})"

    cursor.executemany(sql, df.values.tolist())
    print(f"{table_name}: {len(df)} rows inserted")


def count_rows(cursor, table_name):
    """Return the number of rows in the table, used to check the load."""
    cursor.execute(f"SELECT COUNT(*) FROM dbo.{table_name}")
    return cursor.fetchone()[0]


if __name__ == "__main__":
    connection = pyodbc.connect(CONNECTION_STRING)
    cursor = connection.cursor()
    # Sends the rows in batches instead of one network round trip per row.
    cursor.fast_executemany = True

    clear_tables(cursor)
    for table_name in TABLES:
        load_table(cursor, table_name)

    # One commit at the end: if any step fails, nothing is saved and the tables stay as before.
    connection.commit()

    for table_name in TABLES:
        print(f"{table_name}: {count_rows(cursor, table_name)} rows in database")

    connection.close()
