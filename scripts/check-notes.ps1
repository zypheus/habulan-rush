# Notes hygiene gate (Windows PowerShell 5.1).
# Verifies two things, docs and notes only:
#   1. Every relative Markdown link in dev-notes/ and the root .md files
#      resolves to a file or folder on disk.
#   2. Every note in dev-notes/ starts with YAML frontmatter holding the
#      required keys: title, type, status, owner, task, updated, source.
#
# Usage: run from the repo root. Exit 0 means NOTES OK.
# Existing files outside dev-notes/ are reported, never fixed here.
# Style follows scripts/check-syntax.ps1 (PS 5.1 compatible, no ternary).

$ErrorActionPreference = 'Continue'
$failures = @()

function Resolve-NoteLink {
    param([string]$fromFile, [string]$target)
    # Drop anchors and titles. Decode percent escapes such as %20.
    $target = ($target -split '#')[0].Trim()
    if ($target -match '^(<[^>]+>)$') { $target = $Matches[1].Trim('<', '>') }
    $target = ($target -split '\s+"')[0].Trim().Trim('"')
    if ($target -eq '') { return $null }
    if ($target -match '^(https?://|mailto:|#)') { return $null }
    $target = [System.Uri]::UnescapeDataString($target)
    $base = Split-Path -Parent $fromFile
    return (Join-Path $base $target)
}

# 1. Link check: dev-notes/ recursive plus root .md files only.
$linkFiles = @()
$linkFiles += Get-ChildItem -LiteralPath 'dev-notes' -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue
$linkFiles += Get-ChildItem -LiteralPath '.' -Filter '*.md' -File
$linkPattern = '\[[^\]]*\]\((<[^>]+>|[^)]+)\)'
foreach ($file in $linkFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($m in [regex]::Matches($text, $linkPattern)) {
        $resolved = Resolve-NoteLink $file.FullName $m.Groups[1].Value
        if ($null -eq $resolved) { continue }
        if (-not (Test-Path -LiteralPath $resolved)) {
            $failures += @("BROKEN LINK $($file.FullName): $($m.Groups[1].Value)")
        }
    }
}

# 2. Frontmatter check: every dev-notes/ note needs the required keys.
$required = @('title', 'type', 'status', 'owner', 'task', 'updated', 'source')
$noteFiles = Get-ChildItem -LiteralPath 'dev-notes' -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue
foreach ($file in $noteFiles) {
    $lines = Get-Content -LiteralPath $file.FullName
    if ($lines.Count -lt 2 -or $lines[0].Trim() -ne '---') {
        $failures += @("NO FRONTMATTER $($file.FullName)")
        continue
    }
    $keys = @()
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { break }
        if ($lines[$i] -match '^\s*([A-Za-z]+)\s*:') { $keys += $Matches[1] }
    }
    foreach ($key in $required) {
        if ($keys -notcontains $key) {
            $failures += @("MISSING KEY '$key' $($file.FullName)")
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($line in $failures) { Write-Output $line }
    exit 1
}

Write-Output 'NOTES OK'
exit 0
