# DLC3 星核织机: opening film, mechanics, route, guide, music, title,
# chapter smoke and the three base levels.
# Writes every log next to this script.  No git, no export.
#   powershell -NoProfile -ExecutionPolicy Bypass -File dlc\star_loom\tests\run_all.ps1

param(
    [string]$Godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location $root
$tests = "dlc/star_loom/tests"
$summary = @()

function Invoke-Case([string]$name, [string]$scene, [string]$logName, [bool]$strict) {
    $out = & $Godot --headless --path . $scene 2>&1
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $tests "$logName.log") -Encoding UTF8
    $problems = @($out | Select-String -Pattern "FAIL:|SCRIPT ERROR|Parse Error|Failed to load|ERROR:")
    Write-Host ("{0}: exit={1} problems={2}" -f $name, $code, $problems.Count)
    if ($problems.Count -gt 0) {
        $problems | Select-Object -First 8 | ForEach-Object { Write-Host ("   " + $_.Line) }
    }
    return @{ name = $name; exit = $code; problems = $problems.Count; strict = $strict }
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

if (-not (Test-Path $Godot)) {
    throw "Godot console binary not found: $Godot"
}

$summary += Invoke-Case "loom_intro" "res://dlc/star_loom/tests/intro_test.tscn" "intro_test" $true
$summary += Invoke-Case "loom_mech" "res://dlc/star_loom/tests/mechanics_test.tscn" "mechanics_test" $true
$summary += Invoke-Case "loom_route" "res://dlc/star_loom/tests/route_test.tscn" "route_test" $true
$summary += Invoke-Case "loom_guide" "res://dlc/star_loom/tests/guide_test.tscn" "guide_test" $true
$summary += Invoke-Case "loom_ui_parity" "res://dlc/star_loom/tests/ui_parity_test.tscn" "ui_parity_test" $true
# music_test needs a real audio device and a real window; run it by hand:
#   ... --path . --position 60,60 res://dlc/star_loom/tests/music_test.tscn
$summary += Invoke-Case "loom_title" "res://dlc/star_loom/tests/title_test.tscn" "title_test" $true
$summary += Invoke-Smoke "loom_90" "res://dlc/star_loom/star_loom.tscn" "loom_90"
$summary += Invoke-Smoke "level_01_90" "res://scenes/level_01.tscn" "level_01_90"
$summary += Invoke-Smoke "level_02_90" "res://scenes/level_02.tscn" "level_02_90"
$summary += Invoke-Smoke "level_03_90" "res://scenes/level_03.tscn" "level_03_90"

Write-Host ""
Write-Host "LOOM_RUN_ALL"
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
