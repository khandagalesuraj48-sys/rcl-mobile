# (3.19.0) THE WINDOWS SETUP - run by the build and the release on Windows, after `flutter build windows --release`.
#   -Step crt    the Visual C++ files (msvcp140, vcruntime140, vcruntime140_1) put next to rcl_erp.exe - a computer without
#                the Visual C++ package still opens the app
#   -Step setup  the setup made with Inno Setup (windows/installer.iss) -> build/installer/RCL-ERP-Setup-<version>-<build>.exe
#   -Step smoke  (the build only, on GitHub's Windows computer) the setup installed as a person would, the app opened by it and
#                still open after 25 seconds (a picture of the screen in -Out); then the app's own update - the same setup run
#                with the app's arguments while the app is open: the open app closed, the new one put in its place and opened
#                again (a second picture). Nothing is signed in: the app shows its sign-in, nothing reaches the live servers.
#   -Ver / -Build  the version and build number (the release's); left out: from pubspec.yaml
param(
  [Parameter(Mandatory = $true)][ValidateSet('crt', 'setup', 'smoke')][string]$Step,
  [string]$Ver = '',
  [string]$Build = '',
  [string]$Out = 'shots'
)
$ErrorActionPreference = 'Stop'
$app = 'build\windows\x64\runner\Release'
if (-not (Test-Path "$app\rcl_erp.exe")) { throw "The Windows app is not built ($app\rcl_erp.exe is missing)." }

if ($Step -eq 'crt') {
  $files = 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll'
  $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
  $vs = if (Test-Path $vswhere) { & $vswhere -latest -products * -property installationPath } else { '' }
  $crt = $null
  if ($vs) {
    $crt = Get-ChildItem "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT" -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\MSVC\\14\.' } | Sort-Object FullName | Select-Object -Last 1
  }
  $from = if ($crt) { $crt.FullName } else { "$env:WINDIR\System32" }
  foreach ($f in $files) { Copy-Item "$from\$f" $app -Force }
  Write-Host "Visual C++ files from $from"
  # the app's update compares its build number with the release's: Windows must give it (ProductVersion "3.19.0+122")
  $vi = (Get-Item "$app\rcl_erp.exe").VersionInfo
  Write-Host "rcl_erp.exe: $($vi.ProductName) / $($vi.CompanyName) / $($vi.ProductVersion)"
  if ($vi.ProductVersion -notmatch '^\d+\.\d+\.\d+\+\d+$') { throw "rcl_erp.exe has no build number in its version ($($vi.ProductVersion)) - the update could not tell it is up to date." }
  if ($vi.ProductName -ne 'RCL ERP' -or $vi.CompanyName -ne 'Rachana Construction Limited') { throw 'rcl_erp.exe: the product or company name is not RCL ERP / Rachana Construction Limited.' }
  Get-ChildItem $app -File | Select-Object Name, Length | Format-Table | Out-Host
  exit 0
}

if ($Step -eq 'smoke') {
  Add-Type -AssemblyName System.Windows.Forms, System.Drawing
  function Shot([string]$path) {
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Host "picture: $path"
  }
  function RunSetup([string[]]$a) {
    $p = Start-Process $setup -ArgumentList $a -PassThru
    if (-not $p.WaitForExit(240000)) { throw 'The setup did not finish in 4 minutes.' }
    if ($p.ExitCode -ne 0) { throw "The setup stopped with $($p.ExitCode)." }
  }
  New-Item -ItemType Directory -Force $Out | Out-Null
  $setup = (Get-ChildItem build\installer\*.exe | Select-Object -First 1).FullName
  if (-not $setup) { throw 'No setup to try.' }
  # 1. installed (silently here - a person sees the usual pages); the setup opens the app at the end
  RunSetup @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
  $dir = "$env:LOCALAPPDATA\Programs\RCL ERP"
  foreach ($f in 'rcl_erp.exe', 'flutter_windows.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'data\app.so', 'data\icudtl.dat') {
    if (-not (Test-Path "$dir\$f")) { throw "Not installed: $f" }
  }
  if (-not (Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\RCL ERP.lnk")) { throw 'No RCL ERP in the Start menu.' }
  if (-not (Test-Path ([Environment]::GetFolderPath('Desktop') + '\RCL ERP.lnk'))) { throw 'No RCL ERP on the Desktop.' }
  Write-Host "installed in $dir (Start menu and Desktop)"
  Start-Sleep -Seconds 25
  $first = @(Get-Process rcl_erp -ErrorAction SilentlyContinue)
  Shot "$Out\win_1_installed.png"
  if ($first.Count -ne 1) { throw "The app is not open after the install ($($first.Count) open)." }
  Write-Host "open after the install: process $($first[0].Id)"
  # 2. the app's own update (lib/core/update.dart runs the setup with these arguments)
  RunSetup @('/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS')
  Start-Sleep -Seconds 25
  $now = @(Get-Process rcl_erp -ErrorAction SilentlyContinue)
  Shot "$Out\win_2_updated.png"
  if ($now | Where-Object { $_.Id -eq $first[0].Id }) { throw 'The update did not close the open app.' }
  if ($now.Count -ne 1) { throw "The app is not open again after the update ($($now.Count) open)." }
  Write-Host "the update closed process $($first[0].Id) and opened process $($now[0].Id)"
  $now | Stop-Process -Force
  exit 0
}

# the setup
if (-not $Ver -or -not $Build) {
  $m = Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)\+(\d+)'
  if (-not $m) { throw 'pubspec.yaml has no version line' }
  if (-not $Ver) { $Ver = $m.Matches[0].Groups[1].Value }
  if (-not $Build) { $Build = $m.Matches[0].Groups[2].Value }
}
choco upgrade innosetup -y --no-progress | Out-Host
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) { $iscc = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source }
if (-not $iscc) { throw 'Inno Setup (ISCC.exe) could not be found.' }
& $iscc /Qp "/DAppVer=$Ver" "/DAppBuild=$Build" windows\installer.iss
if ($LASTEXITCODE -ne 0) { throw "Inno Setup stopped ($LASTEXITCODE)." }
$out = Get-ChildItem build\installer\*.exe | Select-Object -First 1
Write-Host "::notice::Windows setup: $($out.Name) - $([math]::Round($out.Length / 1MB, 1)) MB"
