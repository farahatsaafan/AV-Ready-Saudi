<#
=============================================================================
AV-Ready-Saudi Automated SQL Server Pipeline Runner
=============================================================================
Runs all warehouse layers (Init -> Bronze -> Silver -> Gold -> Analytics)
=============================================================================
#>

param(
    [string]$ServerInstance = ".\SQLEXPRESS",
    [string]$DataPath = "$PSScriptRoot\Data"
)

$sqlcmd = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE"
if (-not (Test-Path $sqlcmd)) {
    $sqlcmd = "sqlcmd"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Starting AV-Ready-Saudi Automated Pipeline" -ForegroundColor Cyan
Write-Host "Server Instance: $ServerInstance" -ForegroundColor Cyan
Write-Host "Data Directory : $DataPath" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Run-SqlScript {
    param([string]$FilePath, [string]$StepName)
    Write-Host "`n>>> Running: $StepName ($FilePath) ..." -ForegroundColor Yellow
    & $sqlcmd -S $ServerInstance -E -C -i $FilePath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[-] Error in $StepName (Exit code: $LASTEXITCODE)" -ForegroundColor Red
        return $false
    }
    Write-Host "[+] $StepName completed successfully." -ForegroundColor Green
    return $true
}

function Run-SqlQuery {
    param([string]$Query, [string]$StepName)
    Write-Host "`n>>> Executing Query: $StepName ..." -ForegroundColor Yellow
    & $sqlcmd -S $ServerInstance -E -C -d av_ready_saudi_dw -Q $Query
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[-] Error in $StepName (Exit code: $LASTEXITCODE)" -ForegroundColor Red
        return $false
    }
    Write-Host "[+] $StepName completed successfully." -ForegroundColor Green
    return $true
}

# 1. Init Database & Schemas
if (-not (Run-SqlScript -FilePath "$PSScriptRoot\sql\00_init.sql" -StepName "00_init.sql")) { exit 1 }

# 2. Bronze DDL & Ingestion
if (-not (Run-SqlScript -FilePath "$PSScriptRoot\sql\01_bronze.sql" -StepName "01_bronze.sql")) { exit 1 }
$loadBronzeSql = "EXEC bronze.load_bronze @base_path = N'$DataPath';"
if (-not (Run-SqlQuery -Query $loadBronzeSql -StepName "Execute bronze.load_bronze")) { exit 1 }

# 3. Silver DDL & Transformation
if (-not (Run-SqlScript -FilePath "$PSScriptRoot\sql\02_silver.sql" -StepName "02_silver.sql")) { exit 1 }
if (-not (Run-SqlQuery -Query "EXEC silver.load_silver;" -StepName "Execute silver.load_silver")) { exit 1 }

# 4. Gold DDL & Star Schema Modeling
if (-not (Run-SqlScript -FilePath "$PSScriptRoot\sql\03_gold.sql" -StepName "03_gold.sql")) { exit 1 }
if (-not (Run-SqlQuery -Query "EXEC gold.load_gold;" -StepName "Execute gold.load_gold")) { exit 1 }

# 5. Semantic & Feature Views
if (-not (Run-SqlScript -FilePath "$PSScriptRoot\sql\04_semantic.sql" -StepName "04_semantic.sql")) { exit 1 }
if (-not (Run-SqlScript -FilePath "$PSScriptRoot\sql\05_feature_views.sql" -StepName "05_feature_views.sql")) { exit 1 }

# 6. Quality Validation Gates
Write-Host "`n==========================================================" -ForegroundColor Magenta
Write-Host "Running Quality Gates and Validations..." -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Magenta
Run-SqlScript -FilePath "$PSScriptRoot\sql\quality\01_bronze_validation.sql" -StepName "Bronze Validation"
Run-SqlScript -FilePath "$PSScriptRoot\sql\quality\02_silver_reconciliation.sql" -StepName "Silver Reconciliation Gate"

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "AV-Ready-Saudi Data Warehouse Pipeline is 100% Complete!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
