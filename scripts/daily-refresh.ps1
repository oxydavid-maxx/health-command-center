[CmdletBinding()]
param(
    [string]$GarminRoot = 'C:\dev\runtime\garmin-health-command-center',
    [string]$PythonPath = 'C:\dev\apps\garmin-claude-analysis\.venv\Scripts\python.exe',
    [string]$VaultRoot = 'C:\dev\Obsidian'
)

$ErrorActionPreference = 'Stop'
$garminRootResolved = (Resolve-Path -LiteralPath $GarminRoot).Path
$python = (Resolve-Path -LiteralPath $PythonPath -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "Garmin Python runtime missing: $python"
}
$node = (Get-Command node.exe -ErrorAction Stop).Source
$recoveryEvaluator = Join-Path $PSScriptRoot 'evaluate-recovery.cjs'

$mutex = [System.Threading.Mutex]::new($false, 'Local\HealthCommandCenterDailyRefresh')
if (-not $mutex.WaitOne(0)) {
    Write-Output 'Health refresh already running; skipped overlapping trigger.'
    exit 0
}

try {
    $env:HEALTH_VAULT_DIR = Join-Path $VaultRoot 'Health'
    $env:INBODY_HISTORY_PATH = Join-Path $garminRootResolved 'data\inbody_history.json'
    $env:GARMIN_PYTHON = $python
    $env:HEALTH_RECOVERY_PATH = Join-Path $garminRootResolved 'runtime\recovery.json'
    $normalized = Join-Path $garminRootResolved 'health_normalized.json'
    $userDecisions = Join-Path $garminRootResolved 'runtime\user-recovery-decisions.jsonl'
    Push-Location $garminRootResolved
    try {
        foreach ($module in @('scripts.garmin_refresh')) {
            Write-Output "Running $module"
            & $python -m $module
            if ($LASTEXITCODE -ne 0) {
                throw "$module failed with exit code $LASTEXITCODE"
            }
        }
        Write-Output 'Evaluating Recovery Contract v1'
        & $node $recoveryEvaluator --input $normalized --output $env:HEALTH_RECOVERY_PATH --date (Get-Date).ToString('yyyy-MM-dd') --user-decisions $userDecisions
        if ($LASTEXITCODE -ne 0) {
            throw "evaluate-recovery.cjs failed with exit code $LASTEXITCODE"
        }
        foreach ($module in @('src.build_athlete_json', 'src.vault_sync')) {
            Write-Output "Running $module"
            & $python -m $module
            if ($LASTEXITCODE -ne 0) {
                throw "$module failed with exit code $LASTEXITCODE"
            }
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
