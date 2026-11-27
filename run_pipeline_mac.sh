#!/bin/bash
# =============================================================================
# AV-Ready-Saudi - full pipeline on macOS (SQL Server 2022 in Docker)
#
#   1. python/00_land_raw.py         Data/raw  -> Data/landing/*.tsv  (format only)
#   2. sql/00_init.sql .. 03_gold.sql + load procedures   Bronze -> Silver -> Gold
#   3. sql/quality/*.sql             validation, reconciliation, Gold checks + data shares; sql/04_analysis.sql (EDA)
#   4. python/02_reference_gold.py   independent pandas rebuild (Silver -> prep -> Gold)
#   5. python/04_av_evidence_models.py  GLM cross-check of the AV relative risks + forest plot
#   6. export Gold -> Data/gold_export/gold_av_readiness_region_month.csv, then compare SQL Gold with the reference
#   7. python/05_readiness_model.py  readiness score, clustering, supervised test, sensitivity, figures
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

# Python environment: landing needs openpyxl; the reference build pandas + numpy; the models statsmodels,
# scipy, scikit-learn and matplotlib. Created once in ./.venv so the system Python is never touched.
if [ ! -x .venv/bin/python ]; then
  echo ">>> Creating .venv (first run only)"
  "${PYTHON:-python3}" -m venv .venv
fi
PY=.venv/bin/python
if ! "$PY" -c "import openpyxl, pandas, numpy, statsmodels, scipy, sklearn, matplotlib" 2>/dev/null; then
  echo ">>> Installing openpyxl, pandas, numpy, statsmodels, scipy, scikit-learn, matplotlib into .venv"
  "$PY" -m pip install --quiet --upgrade pip
  "$PY" -m pip install --quiet openpyxl pandas numpy statsmodels scipy scikit-learn matplotlib
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

echo ">>> 3b. EDA suite on the Gold table (sql/04_analysis.sql)"
run 04_analysis.sql

echo ">>> 4. Independent reference build (pandas)"
"$PY" python/02_reference_gold.py > Data/reference_run.log 2>&1 && echo "Reference written to Data/reference/ (log: Data/reference_run.log)" \
  || echo "Reference build failed - see Data/reference_run.log (the SQL pipeline itself finished)"

echo
echo ">>> 5. AV evidence: GLM cross-check of the Mantel-Haenszel relative risks"
"$PY" python/04_av_evidence_models.py || echo "AV evidence cross-check reported a FAIL (see above)"

echo
echo ">>> 6. Export Gold from the container and compare it with the reference"
mkdir -p Data/gold_export
GOLD_CSV=Data/gold_export/gold_av_readiness_region_month.csv
sq() { docker exec -e SQLCMDPASSWORD="$PW" "$C" "$SQLCMD_IN_CONTAINER" -S localhost -U sa -C -b -f 65001 \
         -d av_ready_saudi_dw -h -1 -W -w 65535 -s "," -Q "SET NOCOUNT ON; $1"; }
sq "SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('gold.av_readiness_region_month') ORDER BY column_id;" \
  | grep -v '^$' | paste -sd, - > "$GOLD_CSV"
sq "SELECT * FROM gold.av_readiness_region_month ORDER BY region_code, month_start;" | grep -v '^$' >> "$GOLD_CSV"
echo "Gold exported: $GOLD_CSV ($(($(wc -l < "$GOLD_CSV") - 1)) rows)"
# the AV evidence table behind the Gold weights (read by python/05_readiness_model.py for the sensitivity analysis);
# tab-separated because evidence_note contains commas
RR_TSV=Data/gold_export/av_relative_risk.tsv
docker exec -e SQLCMDPASSWORD="$PW" "$C" "$SQLCMD_IN_CONTAINER" -S localhost -U sa -C -b -f 65001 -d av_ready_saudi_dw \
  -h -1 -W -Q "SET NOCOUNT ON; SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('prep.av_relative_risk') ORDER BY column_id;" \
  | grep -v '^$' | paste -sd '\t' - > "$RR_TSV"
docker exec -e SQLCMDPASSWORD="$PW" "$C" "$SQLCMD_IN_CONTAINER" -S localhost -U sa -C -b -f 65001 -d av_ready_saudi_dw \
  -h -1 -W -w 65535 -s $'\t' -Q "SET NOCOUNT ON; SELECT * FROM prep.av_relative_risk ORDER BY event_source, factor, condition_code;" \
  | grep -v '^$' >> "$RR_TSV"
"$PY" python/02_reference_gold.py --compare || echo "SQL Gold differs from the reference (see above)"

echo
echo ">>> 7. Readiness score, clustering, supervised test, sensitivity (reads the Gold export)"
if [ -f python/05_readiness_model.py ]; then
  "$PY" python/05_readiness_model.py || echo "Readiness model failed (see above)"
fi

echo
echo "Done. Connect: server localhost,1433 / user sa / database av_ready_saudi_dw"
echo "Gold table: gold.av_readiness_region_month (export: $GOLD_CSV)"
