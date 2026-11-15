param(
    [string]$Godot = "D:\Godot\Godot_v4.7.2-stable_win64.exe",
    [switch]$Full
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $project "tests\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

if (-not (Test-Path $Godot)) {
    Write-Error "Godot GUI executable not found: $Godot"
    exit 1
}

if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$godotArgs = @("--path", $project, "res://tools/capture_screenshots.tscn")
if ($Full) {
    $godotArgs += @("--", "--full")
    Write-Host "Full capture: regenerates 01-22 and removes the pre-walk legacy status of 01-20."
} else {
    $godotArgs += @("--", "--walk-only")
    Write-Host "Capturing only the walk addendum (21/22); old 01-20 are preserved. Use -Full to regenerate all."
}
$captureOutput = & $Godot @godotArgs 2>&1 | Out-String
$captureExit = $LASTEXITCODE
Write-Host $captureOutput
Set-Content -Path (Join-Path $logs "capture.log") -Value $captureOutput -Encoding utf8
Write-Host "Capture process exit code: $captureExit"
Write-Host "Images: $project\screenshots"
exit $captureExit
