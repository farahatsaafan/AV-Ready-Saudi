<#
=============================================================================
AV-Ready-Saudi - full pipeline on Windows (local SQL Server instance)
  1. python\00_land_raw.py   Data\raw -> Data\landing\*.tsv (format only)
  2. sql\00..03 + load procedures   Bronze -> Silver -> Gold
  3. sql\quality\*.sql        checks + data shares
Note: BULK INSERT reads files on the SQL Server machine, so @landing_path must
be a folder the SQL Server service account can read.
=============================================================================
#>
param(
    [string]$ServerInstance = ".\SQLEXPRESS",
    [string]$LandingPath = "$PSScriptRoot\Data\landing"
)
$ErrorActionPreference = "Stop"
$sqlcmd = "sqlcmd"

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

python (Join-Path $PSScriptRoot "python\00_land_raw.py")
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
Write-Host "Done. Gold table: gold.av_readiness_region_month" -ForegroundColor Green
