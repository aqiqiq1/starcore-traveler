param(
    [string]$Godot = "D:\Godot\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $project "tests\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

if (-not (Test-Path $Godot)) {
    Write-Error "Godot console executable not found: $Godot"
    exit 1
}

# Keep native stderr from aborting the wrapper before we can record the native
# exit code; Godot writes some diagnostics to stderr.
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

Write-Host "== Godot headless import =="
$importOutput = & $Godot --headless --editor --quit --path $project 2>&1 | Out-String
$importExit = $LASTEXITCODE
Write-Host $importOutput
Set-Content -Path (Join-Path $logs "headless_import.log") -Value $importOutput -Encoding utf8
if ($importExit -ne 0) {
    Write-Error "Headless import failed with exit code $importExit"
    exit $importExit
}

Write-Host "== Headless acceptance tests =="
$testOutput = & $Godot --headless --path $project res://tests/test_runner.tscn 2>&1 | Out-String
$testExit = $LASTEXITCODE
Write-Host $testOutput
Set-Content -Path (Join-Path $logs "headless_test.log") -Value $testOutput -Encoding utf8

Write-Host "Test process exit code: $testExit"
Write-Host "Console log: $logs\headless_test.log"
Write-Host "Runner log: $project\tests\logs\last_run.log"
exit $testExit
