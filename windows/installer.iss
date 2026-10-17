; (3.19.0, asked 17-10-2026: "windows ... app banaw direct app ya windows war chaltil browser open krnechi garaj nahi updet pn in
; app ch yeil") THE WINDOWS SETUP of RCL ERP - made by the build (Inno Setup): iscc /DAppVer=3.19.0 /DAppBuild=122 installer.iss
; * Installed for the person signed in to Windows (no administrator needed): %LOCALAPPDATA%\Programs\RCL ERP
; * RCL ERP in the Start menu and on the Desktop; opened at the end.
; * The app's own update (lib/core/update.dart) runs this same file with /SILENT: the open app is closed, the new version put in
;   its place and opened again - the person's sign-in and settings stay (they are not in this folder).
#ifndef AppVer
  #define AppVer "0.0.0"
#endif
#ifndef AppBuild
  #define AppBuild "0"
#endif

[Setup]
AppId={{0A1904F8-0768-4E2B-BAFD-D52DAB1CA4EA}
AppName=RCL ERP
AppVersion={#AppVer} ({#AppBuild})
AppVerName=RCL ERP {#AppVer}
AppPublisher=Rachana Construction Limited
VersionInfoVersion={#AppVer}.{#AppBuild}
VersionInfoCompany=Rachana Construction Limited
VersionInfoProductName=RCL ERP
VersionInfoDescription=RCL ERP setup
DefaultDirName={localappdata}\Programs\RCL ERP
DisableDirPage=yes
DefaultGroupName=RCL ERP
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\build\installer
OutputBaseFilename=RCL-ERP-Setup-{#AppVer}-{#AppBuild}
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\rcl_erp.exe
UninstallDisplayName=RCL ERP
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; the screens' files of the version before (a file the new version no longer has must not stay)
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\RCL ERP"; Filename: "{app}\rcl_erp.exe"
Name: "{autodesktop}\RCL ERP"; Filename: "{app}\rcl_erp.exe"; Tasks: desktopicon

[Run]
; opened at the end - also after the app's own update (/SILENT), so the person is back in the app
Filename: "{app}\rcl_erp.exe"; Description: "{cm:LaunchProgram,RCL ERP}"; Flags: nowait postinstall
