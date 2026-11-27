# DLC3 opening-film acceptance runner.  Kept separate from run_all.ps1 because
# the shared chapter suite is edited by the presentation/HUD pass.
#   powershell -NoProfile -ExecutionPolicy Bypass -File dlc\star_loom\tests\run_intro.ps1

param(
    [string]$Godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location $root
$tests = "dlc/star_loom/tests"
$summary = @()

function Invoke-Case([string]$name, [string]$scene, [string]$logName, [string[]]$extra = @()) {
    $out = & $Godot --headless --path . $scene @extra 2>&1
    $code = $LASTEXITCODE
    $out | Set-Content -Path (Join-Path $tests "$logName.log") -Encoding UTF8
    $problems = @($out | Select-String -Pattern "FAIL:|SCRIPT ERROR|Parse Error|Failed to load|ERROR:")
    Write-Host ("{0}: exit={1} problems={2}" -f $name, $code, $problems.Count)
    if ($problems.Count -gt 0) {
        $problems | Select-Object -First 8 | ForEach-Object { Write-Host ("   " + $_.Line) }
    }
    return @{ name = $name; exit = $code; problems = $problems.Count }
}

if (-not (Test-Path $Godot)) {
    throw "Godot console binary not found: $Godot"
}

$summary += Invoke-Case "loom_intro" "res://dlc/star_loom/tests/intro_test.tscn" "intro_test"
$summary += Invoke-Case "loom_90" "res://dlc/star_loom/star_loom.tscn" "intro_loom_90" @("--quit-after", "90")
$summary += Invoke-Case "level_01_90" "res://scenes/level_01.tscn" "intro_level_01_90" @("--quit-after", "90")
$summary += Invoke-Case "level_02_90" "res://scenes/level_02.tscn" "intro_level_02_90" @("--quit-after", "90")
$summary += Invoke-Case "level_03_90" "res://scenes/level_03.tscn" "intro_level_03_90" @("--quit-after", "90")

Write-Host ""
Write-Host "LOOM_INTRO_RUN"
$summary | ForEach-Object { Write-Host ("  {0,-14} exit={1} problems={2}" -f $_.name, $_.exit, $_.problems) }
$bad = @($summary | Where-Object { $_.problems -gt 0 })
if ($bad.Count -gt 0) {
    exit 1
}
exit 0
