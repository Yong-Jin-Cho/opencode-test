# Move PoE2 (PathOfExile) to the non-primary monitor and maximize it.
# Usage: run while PoE2 is running or stopped. Right-click > Run with PowerShell.
Add-Type -AssemblyName System.Windows.Forms

$sig = @"
using System;
using System.Runtime.InteropServices;
public static class Win32 {
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hAfter, int X, int Y, int cx, int cy, uint uFlags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
Add-Type -TypeDefinition $sig -ErrorAction SilentlyContinue | Out-Null
$SWP_NOZORDER = 0x0004; $SWP_NOSIZE = 0x0001; $SWP_NOACTIVATE = 0x0010
$SW_RESTORE = 9; $SW_MAXIMIZE = 3

$screens = [System.Windows.Forms.Screen]::AllScreens
$secondary = $screens | Where-Object { -not $_.Primary } | Select-Object -First 1
if (-not $secondary) { Write-Output "RESULT: SECONDARY_NOT_FOUND"; exit 1 }
Write-Output ("TARGET: {0} Bounds={1}" -f $secondary.DeviceName, $secondary.Bounds)

$proc = Get-Process -Name "PathOfExile" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) {
  $exe = "C:\Program Files (x86)\Grinding Gear Games\Path of Exile 2\PathOfExile.exe"
  if (-not (Test-Path -LiteralPath $exe)) { Write-Output "RESULT: EXE_NOT_FOUND"; exit 1 }
  Start-Process -FilePath $exe
  Start-Sleep -Seconds 5
  $proc = Get-Process -Name "PathOfExile" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $proc) { Write-Output "RESULT: PROC_NOT_FOUND"; exit 1 }

$hWnd = 0
for ($i = 0; $i -lt 30; $i++) {
  $proc.Refresh()
  $hWnd = $proc.MainWindowHandle
  if ($hWnd -ne 0) { break }
  Start-Sleep -Seconds 1
}
if ($hWnd -eq 0) { Write-Output "RESULT: HWND_NOT_READY"; exit 1 }

$x = $secondary.WorkingArea.X
$y = $secondary.WorkingArea.Y
[Win32]::ShowWindow($hWnd, $SW_RESTORE) | Out-Null
Start-Sleep -Milliseconds 300
[Win32]::SetWindowPos($hWnd, [IntPtr]::Zero, $x, $y, 0, 0, ($SWP_NOZORDER -bor $SWP_NOSIZE -bor $SWP_NOACTIVATE)) | Out-Null
Start-Sleep -Milliseconds 300
[Win32]::ShowWindow($hWnd, $SW_MAXIMIZE) | Out-Null
Write-Output ("RESULT: MOVED X={0} Y={1}" -f $x, $y)
