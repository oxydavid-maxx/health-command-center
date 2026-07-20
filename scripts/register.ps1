[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$skillRoot = (Resolve-Path (Join-Path $repoRoot 'skills\health-command-center')).Path
$targets = @(
    (Join-Path $env:USERPROFILE '.codex\skills\health-command-center'),
    (Join-Path $env:USERPROFILE '.claude\skills\health-command-center'),
    (Join-Path $env:USERPROFILE '.agents\skills\health-command-center')
)

$result = foreach ($target in $targets) {
    $parent = Split-Path -Parent $target
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    if (Test-Path -LiteralPath $target) {
        $item = Get-Item -LiteralPath $target -Force
        $resolvedTarget = if ($item.LinkTarget) {
            [System.IO.Path]::GetFullPath(($item.LinkTarget -join ''))
        } else { '' }
        if ($item.LinkType -ne 'Junction' -or $resolvedTarget -ne $skillRoot) {
            throw "Refusing to replace noncanonical registration target: $target"
        }
        [pscustomobject]@{ path = $target; state = 'already-current'; target = $skillRoot }
        continue
    }

    New-Item -ItemType Junction -Path $target -Target $skillRoot | Out-Null
    [pscustomobject]@{ path = $target; state = 'created'; target = $skillRoot }
}

$result | ConvertTo-Json -Depth 4

