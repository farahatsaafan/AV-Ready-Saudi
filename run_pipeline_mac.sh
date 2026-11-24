#!/bin/bash
# =============================================================================
# AV-Ready-Saudi - full pipeline on macOS (SQL Server 2022 in Docker)
#
#   1. python/00_land_raw.py         Data/raw  -> Data/landing/*.tsv  (format only)
#   2. sql/00_init.sql .. 03_gold.sql + load procedures   Bronze -> Silver -> Gold
#   3. sql/quality/*.sql             validation, reconciliation, Gold checks + data shares
#   4. python/02_reference_gold.py   independent pandas rebuild to compare with SQL
#
# Usage (from the project folder):
#   SA_PASSWORD='your-sa-password' bash run_pipeline_mac.sh
# Optional: CONTAINER=sql2022 (default)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

C="${CONTAINER:-sql2022}"
PW="${SA_PASSWORD:?set SA_PASSWORD first, e.g. SA_PASSWORD='...' bash run_pipeline_mac.sh}"
case "$PW" in "..."|"your-sa-password"|"") echo "SA_PASSWORD is still the placeholder - use the real sa password of your container."; exit 1;; esac

# Python environment: the landing step needs openpyxl, the reference step pandas + numpy.
# Created once in ./.venv so the system Python is never touched.
if [ ! -x .venv/bin/python ]; then
  echo ">>> Creating .venv (first run only)"
  "${PYTHON:-python3}" -m venv .venv
fi
PY=.venv/bin/python
if ! "$PY" -c "import openpyxl, pandas, numpy" 2>/dev/null; then
  echo ">>> Installing openpyxl, pandas, numpy into .venv"
  "$PY" -m pip install --quiet --upgrade pip
  "$PY" -m pip install --quiet openpyxl pandas numpy
fi

[ -d Data/raw ] || { echo "Missing Data/raw (see docs/DATA_SOURCES.md)"; exit 1; }
docker ps --format '{{.Names}}' | grep -qx "$C" || { echo "Container '$C' is not running. Start Docker Desktop and the container first."; exit 1; }

SQLCMD_IN_CONTAINER=/opt/mssql-tools18/bin/sqlcmd
docker exec "$C" test -x "$SQLCMD_IN_CONTAINER" || SQLCMD_IN_CONTAINER=/opt/mssql-tools/bin/sqlcmd

echo ">>> 1. Landing raw files"
"$PY" python/00_land_raw.py

echo ">>> Copying sql/ and Data/landing/ into the container"
# run as root inside the container: copied files keep the Mac's owner and mode (often 600),
# and sqlcmd / sqlservr run as the "mssql" user, which then cannot read them ("Invalid filename").
docker exec -u 0 "$C" rm -rf /tmp/av
docker exec -u 0 "$C" mkdir -p /tmp/av
docker cp ./sql "$C":/tmp/av/sql
docker cp ./Data/landing "$C":/tmp/av/landing
docker exec -u 0 "$C" chmod -R a+rX /tmp/av

run()   { echo; echo ">>> $1"; docker exec -e SQLCMDPASSWORD="$PW" "$C" "$SQLCMD_IN_CONTAINER" -S localhost -U sa -C -b -f 65001 -i "/tmp/av/sql/$1"; }
query() { echo; echo ">>> $1"; docker exec -e SQLCMDPASSWORD="$PW" "$C" "$SQLCMD_IN_CONTAINER" -S localhost -U sa -C -b -f 65001 -d av_ready_saudi_dw -Q "$1"; }

echo ">>> 2. Warehouse"
run 00_init.sql
run 01_bronze.sql
query "EXEC bronze.load_bronze @landing_path = N'/tmp/av/landing';"
run 02_silver.sql
query "EXEC silver.load_silver;"
run 03_gold.sql
query "EXEC gold.load_gold;"

echo ">>> 3. Quality checks"
run quality/01_bronze_validation.sql
run quality/02_silver_reconciliation.sql
run quality/03_gold_checks.sql
run quality/04_rollback_demo.sql

echo ">>> 4. Independent reference build (pandas)"
"$PY" python/02_reference_gold.py > Data/reference_run.log 2>&1 && echo "Reference written to Data/reference/ (log: Data/reference_run.log)" \
  || echo "Reference build failed - see Data/reference_run.log (the SQL pipeline itself finished)"

echo
echo "Done. Connect: server localhost,1433 / user sa / database av_ready_saudi_dw"
echo "Gold table: gold.av_readiness_region_month"
