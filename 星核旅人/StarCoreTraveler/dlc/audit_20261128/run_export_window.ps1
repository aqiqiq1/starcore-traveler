Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinRect {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
}
"@
$demoDir = Get-ChildItem "D:\lessons" -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "StarCoreTraveler.exe") } |
    Select-Object -First 1 -ExpandProperty FullName
if ([string]::IsNullOrEmpty($demoDir)) { throw "export demo directory not found" }
$exe = Join-Path $demoDir "StarCoreTraveler.exe"
$out = "C:\Users\aqiqiqi\AppData\Local\Temp\opencode\export_640_out.txt"
$err = "C:\Users\aqiqiqi\AppData\Local\Temp\opencode\export_640_err.txt"
$p = Start-Process -FilePath $exe `
    -ArgumentList '--quit-after','180','--position','60,60','--resolution','640x360' `
    -WorkingDirectory $demoDir -PassThru `
    -RedirectStandardOutput $out -RedirectStandardError $err
Start-Sleep -Milliseconds 1500
$p.Refresh()
$handle = $p.MainWindowHandle
if ($handle -ne [IntPtr]::Zero) {
    $r = New-Object WinRect+RECT
    $c = New-Object WinRect+RECT
    [void][WinRect]::GetWindowRect($handle, [ref]$r)
    [void][WinRect]::GetClientRect($handle, [ref]$c)
    "WINDOW_RECT=$($r.Right-$r.Left)x$($r.Bottom-$r.Top) at $($r.Left),$($r.Top)"
    "CLIENT_RECT=$($c.Right-$c.Left)x$($c.Bottom-$c.Top)"
} else {
    "WINDOW_HANDLE=none"
}
$p.WaitForExit()
"EXIT=$($p.ExitCode)"
if (Test-Path $err) { "STDERR:"; Get-Content $err -Encoding UTF8 }
if (Test-Path $out) { "STDOUT_LAST:"; Get-Content $out -Encoding UTF8 | Select-Object -Last 10 }
