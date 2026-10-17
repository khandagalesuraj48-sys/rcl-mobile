# (3.19.0) THE WINDOWS SETUP - run by the build and the release on Windows, after `flutter build windows --release`.
#   -Step crt    the Visual C++ files (msvcp140, vcruntime140, vcruntime140_1) put next to rcl_erp.exe - a computer without
#                the Visual C++ package still opens the app
#   -Step setup  the setup made with Inno Setup (windows/installer.iss) -> build/installer/RCL-ERP-Setup-<version>-<build>.exe
#   -Ver / -Build  the version and build number (the release's); left out: from pubspec.yaml
param(
  [Parameter(Mandatory = $true)][ValidateSet('crt', 'setup')][string]$Step,
  [string]$Ver = '',
  [string]$Build = ''
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
