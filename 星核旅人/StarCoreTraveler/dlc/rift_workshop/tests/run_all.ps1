# Repro runner for dlc/rift_workshop/tests (PowerShell).
#
# Does NOT touch git, does NOT export.  Writes every log next to this script.
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File dlc\rift_workshop\tests\run_all.ps1
#
# The final step temporarily moves the whole dlc/rift_workshop folder out of the
# project to prove that level_01 still boots with 0 errors and the entry hidden,
# then restores it.

param(
    [string]$Godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location $root
$tests = "dlc/rift_workshop/tests"
$summary = @()

function Invoke-Logged(
    [string]$name, [string[]]$godotArgs, [string]$logName, [string]$logDir = ""
) {
    if ($logDir -eq "") { $logDir = $tests }
    $out = & $Godot @godotArgs 2>&1
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $logDir "$logName.log") -Encoding UTF8
    $problems = @($out | Select-String -Pattern "ERROR|SCRIPT ERROR|Parse Error|Failed to load")
    $warnings = @($out | Select-String -Pattern "WARNING")
    Write-Host ("{0}: exit={1} problems={2} warnings={3}" -f $name, $code, $problems.Count, $warnings.Count)
    if ($problems.Count -gt 0) {
        $problems | ForEach-Object { Write-Host ("   " + $_.Line) }
    }
    return @{ name = $name; exit = $code; problems = $problems.Count; warnings = $warnings.Count }
}

if (-not (Test-Path $Godot)) {
    throw "Godot console binary not found: $Godot"
}

$summary += Invoke-Logged "import" @("--headless", "--path", ".", "--import") "import"
$summary += Invoke-Logged "mechanics" @("--headless", "--path", ".", "res://dlc/rift_workshop/tests/mechanics_test.tscn") "mechanics_test"
$summary += Invoke-Logged "route" @("--headless", "--path", ".", "res://dlc/rift_workshop/tests/route_test.tscn") "route_test"
$summary += Invoke-Logged "title" @("--headless", "--path", ".", "res://dlc/rift_workshop/tests/title_test.tscn") "title_test"

# Missing-scene branch: rename the chapter scene only.
$scene = "dlc/rift_workshop/rift_workshop.tscn"
Rename-Item $scene "rift_workshop.tscn.bak"
try {
    $summary += Invoke-Logged "title_missing" @("--headless", "--path", ".", "res://dlc/rift_workshop/tests/title_missing_test.tscn") "title_missing_test"
} finally {
    Rename-Item "dlc/rift_workshop/rift_workshop.tscn.bak" "rift_workshop.tscn"
}

$summary += Invoke-Logged "rift_90" @("--headless", "--path", ".", "res://dlc/rift_workshop/rift_workshop.tscn", "--quit-after", "90") "rift_90"
$summary += Invoke-Logged "level_01_90" @("--headless", "--path", ".", "res://scenes/level_01.tscn", "--quit-after", "90") "level_01_90"
$summary += Invoke-Logged "level_02_90" @("--headless", "--path", ".", "res://scenes/level_02.tscn", "--quit-after", "90") "level_02_90"
$summary += Invoke-Logged "level_03_90" @("--headless", "--path", ".", "res://scenes/level_03.tscn", "--quit-after", "90") "level_03_90"

# Whole-folder removal proof.  The folder is restored in finally.
$backup = Join-Path $env:TEMP "rift_workshop_del_proof"
if (Test-Path $backup) { Remove-Item -Recurse -Force $backup }
Move-Item "dlc/rift_workshop" $backup
try {
    # The log folder travels with the deleted DLC: write this one to the
    # project root, then move it back after the folder is restored.
    $summary += Invoke-Logged "level_01_deleted_90" @("--headless", "--path", ".", "res://scenes/level_01.tscn", "--quit-after", "90") "level_01_deleted_90" "."
} finally {
    Move-Item $backup "dlc/rift_workshop"
    if (Test-Path "level_01_deleted_90.log") {
        Move-Item "level_01_deleted_90.log" (Join-Path $tests "level_01_deleted_90.log") -Force
    }
}

Write-Host ""
Write-Host "RIFT_TEST_SUMMARY"
$summary | ForEach-Object { Write-Host ("  {0,-22} exit={1} problems={2} warnings={3}" -f $_.name, $_.exit, $_.problems, $_.warnings) }
$bad = @($summary | Where-Object { $_.problems -gt 0 })
if ($bad.Count -gt 0) {
    exit 1
}
exit 0
