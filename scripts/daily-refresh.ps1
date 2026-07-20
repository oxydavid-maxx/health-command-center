[CmdletBinding()]
param(
    [string]$GarminRoot = 'C:\dev\apps\garmin-claude-analysis',
    [string]$VaultRoot = 'C:\dev\Obsidian'
)

$ErrorActionPreference = 'Stop'
$garminRootResolved = (Resolve-Path -LiteralPath $GarminRoot).Path
$python = Join-Path $garminRootResolved '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw "Garmin runtime missing: $python"
}

$mutex = [System.Threading.Mutex]::new($false, 'Local\HealthCommandCenterDailyRefresh')
if (-not $mutex.WaitOne(0)) {
    Write-Output 'Health refresh already running; skipped overlapping trigger.'
    exit 0
}

try {
    $env:HEALTH_VAULT_DIR = Join-Path $VaultRoot 'Health'
    $env:INBODY_HISTORY_PATH = Join-Path $garminRootResolved 'data\inbody_history.json'
    Push-Location $garminRootResolved
    try {
        foreach ($module in @('scripts.garmin_refresh', 'src.build_athlete_json', 'src.vault_sync')) {
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

