[CmdletBinding()]
param(
    [string]$GarminRoot = 'C:\dev\apps\garmin-health-runtime',
    [string]$PythonPath = 'C:\dev\apps\garmin-claude-analysis\.venv\Scripts\python.exe',
    [string]$VaultRoot = 'C:\dev\Obsidian',
    # Explicit override of the Health folder. Normally empty: the folder is read from the
    # Vault registry because the Vault numbers its top-level folders (for example
    # "02_<leisure> Health"), so it must never be hard-coded here.
    [string]$HealthDir = '',
    # Print the resolved Health folder and status file, then exit without refreshing.
    [switch]$ResolveOnly
)

$ErrorActionPreference = 'Stop'
$garminRootResolved = (Resolve-Path -LiteralPath $GarminRoot).Path
$python = (Resolve-Path -LiteralPath $PythonPath -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "Garmin Python runtime missing: $python"
}
# Refuse an obsolete producer before it can report success to the scheduler.
$publisher = Join-Path $garminRootResolved 'src\vault_sync.py'
$publisherSource = Get-Content -LiteralPath $publisher -Raw
if ($publisherSource -notmatch 'from \.health_command_center import' -or $publisherSource -match 'out = VAULT / "_generated"') {
    throw 'Health producer does not implement the canonical status publication contract.'
}
if (-not $HealthDir -and -not (Test-Path -LiteralPath (Join-Path $garminRootResolved 'src\health_vault.py') -PathType Leaf)) {
    throw 'Garmin runtime does not provide the Vault registry locator (src/health_vault.py); update the runtime before running the Health refresh.'
}
$node = (Get-Command node.exe -ErrorAction Stop).Source
$recoveryEvaluator = Join-Path $PSScriptRoot 'evaluate-recovery.cjs'

# Find the Health folder: workflow_bindings entry whose skill is health-command-center
# in the Vault registry (KEY = folder name, current_projection = status file). The
# locator prints ASCII-only JSON, so console code pages cannot garble CJK folder names.
if ($HealthDir) {
    $healthRoot = $HealthDir
    $statusPath = Join-Path $HealthDir 'status.md'
}
else {
    Push-Location $garminRootResolved
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $locatorOutput = @(& $python -m src.health_vault --vault-root $VaultRoot 2>&1)
        $locatorExit = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
        Pop-Location
    }
    $locatorErrors = ($locatorOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }) -join '; '
    $locatorJson = ($locatorOutput | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
    if ($locatorExit -ne 0) {
        throw "Health folder lookup in the Vault registry failed (exit code ${locatorExit}): $locatorErrors"
    }
    $located = $locatorJson | ConvertFrom-Json
    $healthRoot = $located.health_dir
    $statusPath = $located.status_path
    if (-not $ResolveOnly) {
        Write-Output "Health folder from Vault registry: $($located.root_name)"
    }
}
if ($ResolveOnly) {
    [pscustomobject]@{ health_dir = $healthRoot; status_path = $statusPath } | ConvertTo-Json -Compress -EscapeHandling EscapeNonAscii
    exit 0
}

$mutex = [System.Threading.Mutex]::new($false, 'Local\HealthCommandCenterDailyRefresh')
if (-not $mutex.WaitOne(0)) {
    Write-Output 'Health refresh already running; skipped overlapping trigger.'
    exit 0
}

try {
    $refreshStarted = [DateTime]::UtcNow
    $env:HEALTH_VAULT_DIR = $healthRoot
    $env:INBODY_HISTORY_PATH = Join-Path $garminRootResolved 'data\inbody_history.json'
    $env:GARMIN_PYTHON = $python
    $env:HEALTH_RECOVERY_PATH = Join-Path $garminRootResolved 'runtime\recovery.json'
    # vault_sync defaults the manual InBody submission to <Health folder>/inbody-input.json,
    # but vault-structure.yaml does not register that slot, so the file cannot legally
    # exist and the manual-confirmation lane was unreachable: a failed photo read stayed
    # parse-error forever even after 光佑 supplied the values. Keep the submission in the
    # producer runtime, which every scheduled pass already reads.
    $env:INBODY_INPUT_PATH = Join-Path $garminRootResolved 'runtime\inbody-input.json'
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
        $publishedStatus = Get-Item -LiteralPath $statusPath -ErrorAction Stop
        if ($publishedStatus.LastWriteTimeUtc -lt $refreshStarted) {
            throw "Health refresh did not update the canonical Health status projection: $statusPath"
        }
        Write-Output "Verified canonical Health status publication: $statusPath"
    }
    finally {
        Pop-Location
    }
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
