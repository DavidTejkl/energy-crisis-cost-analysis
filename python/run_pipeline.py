# Purpose: run the whole pipeline with one command, in the right order, and stop at the first failing step.
# Safe to run again: downloads skip existing files, the database and tables are created only if missing,
# and the load inserts only new rows (incremental), so a second run changes nothing.

import subprocess
import sys

import pyodbc

from config import CONNECTION_STRING, PROJECT_ROOT, SQL_SERVER

PYTHON_DIR = PROJECT_ROOT / "python"
SQL_DIR = PROJECT_ROOT / "sql"


def run_python(script_name):
    """Run one pipeline script with the same Python (the project .venv) that runs this file."""
    # flush: print the step name now, before the child process writes its own output.
    print(f"\n=== {script_name} ===", flush=True)
    subprocess.run([sys.executable, str(PYTHON_DIR / script_name)], check=True)


def run_sql(file_name):
    """Run one SQL file with sqlcmd: -b stops on the first error, -f 65001 reads the file as UTF-8."""
    print(f"\n=== {file_name} ===", flush=True)
    subprocess.run(
        ["sqlcmd", "-S", SQL_SERVER, "-E", "-C", "-b", "-f", "65001", "-i", str(SQL_DIR / file_name)],
        check=True,
    )


def tables_exist():
    """Return True when the star schema is already created (checked on the last table it creates)."""
    connection = pyodbc.connect(CONNECTION_STRING)
    cursor = connection.cursor()
    cursor.execute("SELECT OBJECT_ID('dbo.regulated_price')")
    exists = cursor.fetchone()[0] is not None
    connection.close()
    return exists


def run_pipeline():
    """Download -> clean -> simulated load -> database -> load -> views -> data quality checks."""
    run_python("01_extract.py")
    run_python("02_transform.py")
    run_python("04_generate_load_profile.py")

    run_sql("01_create_database.sql")
    # 02_create_tables.sql drops and recreates the tables, so it runs only on an empty database;
    # otherwise every run would delete the data and the load could never be incremental.
    if tables_exist():
        print("\n=== 02_create_tables.sql === skipped, tables already exist", flush=True)
    else:
        run_sql("02_create_tables.sql")
    run_sql("90_etl_infrastructure.sql")

    run_python("03_load.py")
    run_sql("03_create_views.sql")
    run_sql("91_dq_tests.sql")


if __name__ == "__main__":
    try:
        run_pipeline()
    except subprocess.CalledProcessError as error:
        # The failing step has already printed its own error above.
        print(f"\nPipeline stopped: step failed with exit code {error.returncode}: {error.cmd[-1]}")
        sys.exit(1)
    print("\nPipeline finished: all steps OK")
