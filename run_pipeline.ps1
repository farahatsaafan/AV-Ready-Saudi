<#
=============================================================================
AV-Ready-Saudi - full pipeline on Windows (local SQL Server instance)
  1. python\00_land_raw.py        Data\raw -> Data\landing\*.tsv (format only)
  2. sql\00..03 + load procedures  Bronze -> Silver -> Gold
  3. sql\quality\*.sql             checks + data shares
  4. python\02_reference_gold.py   independent pandas rebuild to compare with SQL
Usage (from the project folder, PowerShell 5.1 or 7):
  powershell -ExecutionPolicy Bypass -File .\run_pipeline.ps1
  powershell -ExecutionPolicy Bypass -File .\run_pipeline.ps1 -ServerInstance "localhost"
Note: BULK INSERT reads files on the SQL Server machine, so @landing_path must
be a folder the SQL Server service account can read.
=============================================================================
#>
param(
    [string]$ServerInstance = ".\SQLEXPRESS",
    [string]$LandingPath = "$PSScriptRoot\Data\landing"
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# --- raw data -----------------------------------------------------------------
if (-not (Test-Path (Join-Path $PSScriptRoot "Data\raw"))) {
    throw "Missing Data\raw. Download the data bundle (link in docs\DATA_SOURCES.md) and unzip it into the project folder."
}

# --- sqlcmd: PATH first, then the usual install folders ------------------------
$sqlcmd = (Get-Command sqlcmd -ErrorAction SilentlyContinue).Source
if (-not $sqlcmd) {
    $candidates = @(
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\SqlCmd\sqlcmd.exe"
    )
    $sqlcmd = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $sqlcmd) { throw "sqlcmd not found. Install the SQL Server command-line tools (sqlcmd)." }

# --- Python environment (.venv, created once) ---------------------------------
$py = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    Write-Host ">>> Creating .venv (first run only)" -ForegroundColor Yellow
    $sysPy = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $sysPy) { $sysPy = (Get-Command py -ErrorAction SilentlyContinue).Source }
    if (-not $sysPy) { throw "Python 3 not found on PATH." }
    & $sysPy -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw "Failed: python -m venv .venv" }
}
& $py -c "import openpyxl, pandas, numpy" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host ">>> Installing openpyxl, pandas, numpy into .venv" -ForegroundColor Yellow
    & $py -m pip install --quiet --upgrade pip
    & $py -m pip install --quiet openpyxl pandas numpy
    if ($LASTEXITCODE -ne 0) { throw "Failed: pip install" }
}

function Run-Py([string]$Script) {
    Write-Host ">>> $Script" -ForegroundColor Yellow
    & $py (Join-Path $PSScriptRoot "python\$Script")
    if ($LASTEXITCODE -ne 0) { throw "Failed: $Script" }
}
function Run-Sql([string]$File) {
    Write-Host ">>> $File" -ForegroundColor Yellow
    & $sqlcmd -S $ServerInstance -E -C -b -f 65001 -i (Join-Path $PSScriptRoot "sql\$File")
    if ($LASTEXITCODE -ne 0) { throw "Failed: $File" }
}
function Run-Query([string]$Query) {
    Write-Host ">>> $Query" -ForegroundColor Yellow
    & $sqlcmd -S $ServerInstance -E -C -b -f 65001 -d av_ready_saudi_dw -Q $Query
    if ($LASTEXITCODE -ne 0) { throw "Failed: $Query" }
}

Run-Py  "00_land_raw.py"
Run-Sql "00_init.sql"
Run-Sql "01_bronze.sql"
Run-Query "EXEC bronze.load_bronze @landing_path = N'$LandingPath';"
Run-Sql "02_silver.sql"
Run-Query "EXEC silver.load_silver;"
Run-Sql "03_gold.sql"
Run-Query "EXEC gold.load_gold;"
Run-Sql "quality\01_bronze_validation.sql"
Run-Sql "quality\02_silver_reconciliation.sql"
Run-Sql "quality\03_gold_checks.sql"
Run-Sql "quality\04_rollback_demo.sql"

Write-Host ">>> 02_reference_gold.py (independent pandas build)" -ForegroundColor Yellow
& $py (Join-Path $PSScriptRoot "python\02_reference_gold.py") *> (Join-Path $PSScriptRoot "Data\reference_run.log")
if ($LASTEXITCODE -eq 0) { Write-Host "Reference written to Data\reference\ (log: Data\reference_run.log)" }
else { Write-Host "Reference build failed - see Data\reference_run.log (the SQL pipeline itself finished)" -ForegroundColor Red }

Write-Host "Done. Gold table: gold.av_readiness_region_month" -ForegroundColor Green
