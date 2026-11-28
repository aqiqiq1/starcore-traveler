# DLC2 裂隙工坊: opening film, mechanics, route, polish, title,
# chapter smoke and the three base levels.
# Writes every log next to this script.  No git, no export.
#   powershell -NoProfile -ExecutionPolicy Bypass -File dlc\rift_workshop\tests\run_all.ps1

param(
    [string]$Godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location $root
$tests = "dlc/rift_workshop/tests"
$summary = @()

function Invoke-Case([string]$name, [string]$scene, [string]$logName, [bool]$strict) {
    $env:STAR_CORE_MECHANIC_PROGRESS = Join-Path $env:TEMP ("starcore_mechanic_rift_" + $logName + ".cfg")
    Remove-Item $env:STAR_CORE_MECHANIC_PROGRESS -ErrorAction SilentlyContinue
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
    $env:STAR_CORE_MECHANIC_PROGRESS = Join-Path $env:TEMP ("starcore_mechanic_rift_" + $logName + ".cfg")
    Remove-Item $env:STAR_CORE_MECHANIC_PROGRESS -ErrorAction SilentlyContinue
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
    # new title BGM before quit (the raw --quit-after path leaves the OGG
    # playback alive and the engine reports a false resource-leak ERROR).
    $env:STAR_CORE_MECHANIC_PROGRESS = Join-Path $env:TEMP ("starcore_mechanic_rift_" + $logName + ".cfg")
    Remove-Item $env:STAR_CORE_MECHANIC_PROGRESS -ErrorAction SilentlyContinue
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

$summary += Invoke-Case "rift_intro" "res://dlc/rift_workshop/tests/intro_test.tscn" "intro_test" $true
$summary += Invoke-Case "rift_mech" "res://dlc/rift_workshop/tests/mechanics_test.tscn" "mechanics_test" $true
$summary += Invoke-Case "rift_boss_v2" "res://dlc/rift_workshop/tests/boss_v2_test.tscn" "boss_v2_test" $true
$summary += Invoke-Case "rift_mirror" "res://dlc/rift_workshop/tests/mirror_pass_test.tscn" "mirror_pass_test" $true
$summary += Invoke-Case "rift_route" "res://dlc/rift_workshop/tests/route_test.tscn" "route_test" $true
$summary += Invoke-Case "rift_polish" "res://dlc/rift_workshop/tests/polish_test.tscn" "polish_test" $true
$summary += Invoke-Case "rift_parity" "res://dlc/rift_workshop/tests/parity_test.tscn" "parity_test" $true
$summary += Invoke-Case "rift_title" "res://dlc/rift_workshop/tests/title_test.tscn" "title_test" $true
$summary += Invoke-Smoke "rift_90" "res://dlc/rift_workshop/rift_workshop.tscn" "rift_90"
$summary += Invoke-CleanSmoke "level_01_90" "res://dlc/rift_workshop/tests/base_level_90_clean.tscn" "level_01" "level_01_90"
$summary += Invoke-CleanSmoke "level_02_90" "res://dlc/rift_workshop/tests/base_level_90_clean.tscn" "level_02" "level_02_90"
$summary += Invoke-CleanSmoke "level_03_90" "res://dlc/rift_workshop/tests/base_level_90_clean.tscn" "level_03" "level_03_90"

Write-Host ""
Write-Host "RIFT_RUN_ALL"
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
