[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MigrationSource,
    [string]$CanonicalSkill = (Join-Path $PSScriptRoot '..\skills\health-command-center\SKILL.md'),
    [string]$Receipt
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $MigrationSource).Path
$canonical = (Resolve-Path -LiteralPath $CanonicalSkill).Path
$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
$canonicalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $canonical).Hash.ToLowerInvariant()
$proof = [ordered]@{
    schema_version = 1
    migration_source = $source
    canonical_skill = $canonical
    source_bytes = (Get-Item -LiteralPath $source).Length
    canonical_bytes = (Get-Item -LiteralPath $canonical).Length
    source_sha256 = $sourceHash
    canonical_sha256 = $canonicalHash
    byte_equal = $sourceHash -eq $canonicalHash
}

$json = $proof | ConvertTo-Json -Depth 4
if ($Receipt) {
    $parent = Split-Path -Parent $Receipt
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($Receipt, $json, [System.Text.UTF8Encoding]::new($false))
}
$json
if (-not $proof.byte_equal) { exit 2 }

