$demoDir = Get-ChildItem "D:\lessons" -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "StarCoreTraveler.exe") } |
    Select-Object -First 1 -ExpandProperty FullName
if ([string]::IsNullOrEmpty($demoDir)) { throw "export demo directory not found" }
$exe = Join-Path $demoDir "StarCoreTraveler.exe"
$out = "C:\Users\aqiqiqi\AppData\Local\Temp\opencode\export_180_out.txt"
$err = "C:\Users\aqiqiqi\AppData\Local\Temp\opencode\export_180_err.txt"
$p = Start-Process -FilePath $exe -ArgumentList '--quit-after','180','--position','60,60' `
    -WorkingDirectory $demoDir -Wait -PassThru `
    -RedirectStandardOutput $out -RedirectStandardError $err
$errBytes = (Get-Item $err).Length
"EXE=$exe"
"EXIT=$($p.ExitCode)"
"STDERR_BYTES=$errBytes"
if ($errBytes -gt 0) { Get-Content $err -Encoding UTF8 }
