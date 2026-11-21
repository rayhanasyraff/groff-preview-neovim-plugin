# Open a PDF in SumatraPDF and tile it beside the Windows Terminal window,
# so the two look like a split; then give focus back to the terminal.
# Called by :GroffPreview (lua/groff-preview/init.lua).
param(
    [Parameter(Mandatory)] [string]$Pdf,
    [string]$Sumatra = "$env:LOCALAPPDATA\SumatraPDF\SumatraPDF.exe",
    [double]$Ratio = 0.55   # share of the screen width for the terminal
)

Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class Tile {
  public delegate bool EP(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Ri, B; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP f, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out R r, int size);
  public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassName(h, s, 256); return s.ToString(); }
  public static string Title(IntPtr h) { var s = new StringBuilder(512); GetWindowText(h, s, 512); return s.ToString(); }
  public static IntPtr FindWin(string cls, string titlePrefix) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      if (IsWindowVisible(h) && Cls(h) == cls && (titlePrefix == "" || Title(h).StartsWith(titlePrefix))) { found = h; return false; }
      return true; }, IntPtr.Zero);
    return found;
  }
  // Place a window so its *visible* frame fills x,y,w,h (Win10/11 windows
  // have invisible resize borders that would otherwise leave gaps).
  public static void Place(IntPtr h, int x, int y, int w, int hh) {
    if (IsZoomed(h)) ShowWindow(h, 9);          // SW_RESTORE
    MoveWindow(h, x, y, w, hh, true);
    R outer, vis;
    GetWindowRect(h, out outer);
    if (DwmGetWindowAttribute(h, 9, out vis, Marshal.SizeOf(typeof(R))) == 0) {
      int l = vis.L - outer.L, t = vis.T - outer.T, r = outer.Ri - vis.Ri, b = outer.B - vis.B;
      MoveWindow(h, x - l, y - t, w + l + r, hh + t + b, true);
    }
  }
  // Foreground-lock workaround: a synthetic Alt tap lets us take focus.
  public static void Focus(IntPtr h) {
    keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero);
    SetForegroundWindow(h);
  }
}
'@
Add-Type -AssemblyName System.Windows.Forms
[Tile]::SetProcessDPIAware() | Out-Null

# The terminal the user just typed :GroffPreview in is the foreground window.
$term = [Tile]::GetForegroundWindow()
if ([Tile]::Cls($term) -ne 'CASCADIA_HOSTING_WINDOW_CLASS') {
    $term = [Tile]::FindWin('CASCADIA_HOSTING_WINDOW_CLASS', '')
}

Start-Process -FilePath $Sumatra -ArgumentList '-reuse-instance', "`"$Pdf`""

# Wait for Sumatra to show this file (title starts with the file name).
$name = [System.IO.Path]::GetFileName($Pdf)
$viewer = [IntPtr]::Zero
for ($i = 0; $i -lt 50 -and $viewer -eq [IntPtr]::Zero; $i++) {
    Start-Sleep -Milliseconds 100
    $viewer = [Tile]::FindWin('SUMATRA_PDF_FRAME', $name)
}
if ($viewer -eq [IntPtr]::Zero -or $term -eq [IntPtr]::Zero) { exit 1 }

$area = [System.Windows.Forms.Screen]::FromHandle($term).WorkingArea
$tw = [int]($area.Width * $Ratio)
[Tile]::Place($term, $area.X, $area.Y, $tw, $area.Height)
[Tile]::Place($viewer, $area.X + $tw, $area.Y, $area.Width - $tw, $area.Height)
Start-Sleep -Milliseconds 150
[Tile]::Focus($term)
