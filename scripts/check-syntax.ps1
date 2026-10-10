# SprintVFX syntax gate (Windows PowerShell 5.1).
# Runs StyLua --check on src/ and fails ONLY on parse errors.
# Formatting-only differences are ignored: this repo does not follow
# StyLua style, so "would reformat" output is not a failure.
#
# Install (one time, outside the repo):
#   1. Download the Windows x86_64 zip from
#      https://github.com/JohnnyMorganz/StyLua/releases
#      (for example stylua-windows-x86_64.zip).
#   2. Extract stylua.exe into %LOCALAPPDATA%\luau-bin\
#      so this path exists: %LOCALAPPDATA%\luau-bin\stylua.exe
# (cargo install does not work on 32-bit MinGW toolchains here.)
#
# Usage: run from the repo root. Exit 0 means SYNTAX OK.
# A passing check does not replace testing in Studio.

$stylua = Join-Path $env:LOCALAPPDATA 'luau-bin\stylua.exe'
if (-not (Test-Path -LiteralPath $stylua)) {
	Write-Error "stylua.exe not found at $stylua (see install steps in this script header)"
	exit 2
}

$output = & $stylua --check src/ 2>&1 | Out-String
$failures = @($output | Select-String -Pattern 'error parsing' | ForEach-Object { $_.Line })
if ($failures.Count -gt 0) {
	foreach ($line in $failures) {
		Write-Output $line
	}
	exit 1
}

Write-Output 'SYNTAX OK'
exit 0
