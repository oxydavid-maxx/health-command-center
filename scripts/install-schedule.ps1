[CmdletBinding()]
param(
    [string]$At = '07:45',
    [string]$LegacyTaskName = 'Garmin Health Fetch',
    [string]$TaskName = 'Health Command Center Daily Refresh'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$refresh = Join-Path $repoRoot 'scripts\daily-refresh.ps1'

$legacy = Get-ScheduledTask -TaskName $LegacyTaskName -ErrorAction SilentlyContinue
if ($legacy) {
    Disable-ScheduledTask -TaskName $LegacyTaskName | Out-Null
}

$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument (
    '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $refresh
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
} | ConvertTo-Json -Depth 3

