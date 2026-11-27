# DLC1 星核试炼场: gates, route, title, pause and the three base levels.
# Writes every log next to this script.  No git, no export.
#   powershell -NoProfile -ExecutionPolicy Bypass -File dlc\trial_chambers\tests\run_all.ps1

param(
    [string]$Godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location $root
$tests = "dlc/trial_chambers/tests"
$summary = @()

function Invoke-Case([string]$name, [string]$scene, [string]$logName) {
    $out = & $Godot --headless --path . $scene 2>&1
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $tests "$logName.log") -Encoding UTF8
    $problems = @($out | Select-String -Pattern "FAIL:|SCRIPT ERROR|Parse Error|Failed to load|ERROR:")
    Write-Host ("{0}: exit={1} problems={2}" -f $name, $code, $problems.Count)
    if ($problems.Count -gt 0) {
        $problems | Select-Object -First 8 | ForEach-Object { Write-Host ("   " + $_.Line) }
    }
    return @{ name = $name; exit = $code; problems = $problems.Count; strict = $true }
}

function Invoke-Smoke([string]$name, [string]$scene, [string]$logName) {
    $out = & $Godot --headless --path . $scene --quit-after 90 2>&1
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $tests "$logName.log") -Encoding UTF8
    $problems = @($out | Select-String -Pattern "SCRIPT ERROR|Parse Error|Failed to load|ERROR:")
    Write-Host ("{0}: exit={1} problems={2}" -f $name, $code, $problems.Count)
    if ($problems.Count -gt 0) {
        $problems | Select-Object -First 8 | ForEach-Object { Write-Host ("   " + $_.Line) }
    }
    return @{ name = $name; exit = $code; problems = $problems.Count; strict = $false }
}

function Invoke-CleanSmoke([string]$name, [string]$scene, [string]$levelKey, [string]$logName) {
    # Base levels: same 90-frame load/run, plus a teardown that releases the
    # title BGM before quit (the raw --quit-after path leaves the OGG playback
    # alive and the engine reports a false resource-leak ERROR).
    $out = & $Godot --headless --path . $scene -- $levelKey 2>&1
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $tests "$logName.log") -Encoding UTF8
    $problems = @($out | Select-String -Pattern "SCRIPT ERROR|Parse Error|Failed to load|ERROR:")
    Write-Host ("{0}: exit={1} problems={2}" -f $name, $code, $problems.Count)
    if ($problems.Count -gt 0) {
        $problems | Select-Object -First 8 | ForEach-Object { Write-Host ("   " + $_.Line) }
    }
    return @{ name = $name; exit = $code; problems = $problems.Count; strict = $false }
}

if (-not (Test-Path $Godot)) {
    throw "Godot console binary not found: $Godot"
}

$summary += Invoke-Case "trial_intro" "res://dlc/trial_chambers/tests/intro_test.tscn" "intro_test"
$summary += Invoke-Case "trial_gate" "res://dlc/trial_chambers/tests/gate_test.tscn" "gate_test"
$summary += Invoke-Case "trial_route" "res://dlc/trial_chambers/tests/route_test.tscn" "route_test"
$summary += Invoke-Case "trial_title" "res://dlc/trial_chambers/tests/title_test.tscn" "title_test"
$summary += Invoke-Case "trial_pause" "res://dlc/trial_chambers/tests/pause_title_test.tscn" "pause_title_test"
$summary += Invoke-Case "trial_ambience" "res://dlc/trial_chambers/tests/ambience_test.tscn" "ambience_test"
$summary += Invoke-Smoke "trial_90" "res://dlc/trial_chambers/trial_chambers.tscn" "trial_90"
$summary += Invoke-CleanSmoke "level_01_90" "res://dlc/trial_chambers/tests/base_level_90_clean.tscn" "level_01" "level_01_90"
$summary += Invoke-CleanSmoke "level_02_90" "res://dlc/trial_chambers/tests/base_level_90_clean.tscn" "level_02" "level_02_90"
$summary += Invoke-CleanSmoke "level_03_90" "res://dlc/trial_chambers/tests/base_level_90_clean.tscn" "level_03" "level_03_90"

Write-Host ""
Write-Host "TRIAL_RUN_ALL"
$summary | ForEach-Object {
    Write-Host ("  {0,-18} exit={1} problems={2}" -f $_.name, $_.exit, $_.problems)
}
$bad = @($summary | Where-Object {
    ($_.strict -and $_.exit -ne 0) -or $_.problems -gt 0
})
if ($bad.Count -gt 0) {
    exit 1
}
exit 0
