[CmdletBinding()]
param(
    [string]$At = '07:45',
    [string]$LegacyTaskName = 'Garmin Health Fetch',
    [string]$TaskName = 'Health Command Center Daily Refresh',
    [string]$GarminRoot = 'C:\dev\apps\garmin-health-runtime',
    [string]$PythonPath = 'C:\dev\apps\garmin-claude-analysis\.venv\Scripts\python.exe'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$refresh = Join-Path $repoRoot 'scripts\daily-refresh.ps1'
$stablePwsh = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe'
if (-not (Test-Path -LiteralPath $stablePwsh -PathType Leaf)) {
    throw "Stable PowerShell app execution alias missing: $stablePwsh"
}

$legacy = Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
if ($legacy) {
    Disable-ScheduledTask -TaskName $LegacyTaskName | Out-Null
}

$action = New-ScheduledTaskAction -Execute $stablePwsh -Argument (
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -GarminRoot "{1}" -PythonPath "{2}"' -f `
        $refresh, $GarminRoot, $PythonPath
)
$trigger = New-ScheduledTaskTrigger -Daily -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Settings $settings -Description 'Health-owned trigger for Garmin acquisition and Health projection.' `
    -Force | Out-Null

[pscustomobject]@{
    legacy_task = $LegacyTaskName
    legacy_state = if ($legacy) { 'disabled' } else { 'absent' }
    task = $TaskName
    schedule = $At
    action = $refresh
    executable = $stablePwsh
    garmin_root = $GarminRoot
    python_runtime = $PythonPath
} | ConvertTo-Json -Depth 3
