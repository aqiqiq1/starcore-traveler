# Repro runner for dlc/ui/tests (PowerShell).
#
# Does NOT touch git, does NOT export.  Writes every log next to this script.
#   powershell -NoProfile -ExecutionPolicy Bypass -File dlc\ui\tests\run_all.ps1
#
# The 640x360 screenshots are a separate non-headless run:
#   ...\Godot_v4.7.2-stable_win64_console.exe --path . --position 60,60 \
#     res://dlc/ui/tests/capture_guide.tscn

param(
    [string]$Godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location $root
$tests = "dlc/ui/tests"
$summary = @()

function Invoke-Logged([string]$name, [string]$scene, [string]$logName) {
    $out = & $Godot --headless --path . $scene 2>&1
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $tests "$logName.log") -Encoding UTF8
    $problems = @($out | Select-String -Pattern "ERROR|SCRIPT ERROR|Parse Error|Failed to load")
    Write-Host ("{0}: exit={1} problems={2}" -f $name, $code, $problems.Count)
    if ($problems.Count -gt 0) {
        $problems | ForEach-Object { Write-Host ("   " + $_.Line) }
    }
    return @{ name = $name; exit = $code; problems = $problems.Count }
}

if (-not (Test-Path $Godot)) {
    throw "Godot console binary not found: $Godot"
}

$summary += Invoke-Logged "real_j" "res://dlc/ui/tests/real_j_damage_test.tscn" "real_j_damage_test"
$summary += Invoke-Logged "guide" "res://dlc/ui/tests/guide_test.tscn" "guide_test"

Write-Host ""
Write-Host "DLC_UI_TEST_SUMMARY"
$summary | ForEach-Object { Write-Host ("  {0,-10} exit={1} problems={2}" -f $_.name, $_.exit, $_.problems) }
$bad = @($summary | Where-Object { $_.exit -ne 0 -or $_.problems -gt 0 })
if ($bad.Count -gt 0) {
    exit 1
}
exit 0
