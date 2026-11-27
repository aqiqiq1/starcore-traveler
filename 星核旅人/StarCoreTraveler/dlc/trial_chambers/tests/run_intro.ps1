# DLC1 opening-film acceptance shortcut.
#
# The chapter suite now includes `intro_test` itself, so this runner simply
# delegates to `run_all.ps1` and keeps the old path working.  Use run_all.ps1
# directly for the full report (intro, gates, route, title, pause, ambience,
# chapter 90 and the three base levels).
#   powershell -NoProfile -ExecutionPolicy Bypass -File dlc\trial_chambers\tests\run_intro.ps1

param(
    [string]$Godot = "D:/Godot/Godot_v4.7.2-stable_win64_console.exe"
)

$runner = Join-Path $PSScriptRoot "run_all.ps1"
& $runner -Godot $Godot
exit $LASTEXITCODE
