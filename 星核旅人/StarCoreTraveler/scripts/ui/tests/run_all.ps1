# Shared HUD / UI acceptance gate (dlc/PRESENTATION_SYSTEM.md).
# Runs the unified-HUD, phase-icon, UiReveal and completion-reveal suites.
# Writes every log next to this script.  No git, no export.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ui\tests\run_all.ps1

param(
    [string]$Godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location $root
$tests = "scripts/ui/tests"
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
    return @{ name = $name; exit = $code; problems = $problems.Count }
}

if (-not (Test-Path $Godot)) {
    throw "Godot console binary not found: $Godot"
}

$summary += Invoke-Case "hud_unified" "res://scripts/ui/tests/hud_unified_test.tscn" "hud_unified_test"
$summary += Invoke-Case "phase_icon" "res://scripts/ui/tests/phase_icon_test.tscn" "phase_icon_test"
$summary += Invoke-Case "ui_reveal" "res://scripts/ui/tests/ui_reveal_test.tscn" "ui_reveal_test"
$summary += Invoke-Case "completion_reveal" "res://scripts/ui/tests/completion_reveal_test.tscn" "completion_reveal_test"
$summary += Invoke-Case "prompt_footer" "res://scripts/ui/tests/prompt_footer_test.tscn" "prompt_footer_test"
$summary += Invoke-Case "level03_health" "res://scripts/level03/tests/health_bar_test.tscn" "health_bar_test"

Write-Host ""
Write-Host "SHARED_UI_RUN_ALL"
$summary | ForEach-Object {
    Write-Host ("  {0,-18} exit={1} problems={2}" -f $_.name, $_.exit, $_.problems)
}
$bad = @($summary | Where-Object { $_.exit -ne 0 -or $_.problems -gt 0 })
if ($bad.Count -gt 0) {
    exit 1
}
exit 0
