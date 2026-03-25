; OpticMix Edge Installer — Inno Setup Script
; Mini-PC streamer setup: deploys streamer + installs WinUSB driver

#define MyAppName "OpticMix Edge"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "OpticMix"
#define MyAppURL "https://opticmix.com"

; Source directories — all from assets (no build dependency)
#define AssetsDir "assets"

[Setup]
AppId={{29FA6342-8B1C-4E5A-9D3F-OPTICMIX0002}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\OpticMix\Edge
DefaultGroupName=OpticMix Edge
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputBaseFilename=OpticMixEdge_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\edge\tools\tray\opticmix.ico
MinVersion=10.0.17763
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Streamer + dependencies (all from assets)
Source: "{#AssetsDir}\leap_streamer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AssetsDir}\libusb-1.0.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AssetsDir}\pthreadVC3.dll"; DestDir: "{app}"; Flags: ignoreversion
; WinUSB installer tool (libwdi)
Source: "{#AssetsDir}\wdi-simple.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\OpticMix Streamer"; Filename: "{app}\leap_streamer.exe"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

[Registry]
; Store edge install info
Root: HKLM; Subkey: "SOFTWARE\OpticMix\Edge"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\OpticMix\Edge"; ValueType: string; ValueName: "InstallDir"; ValueData: "{app}"; Flags: uninsdeletekey
; Auto-start streamer on login
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "OpticMixStreamer"; ValueData: """{app}\leap_streamer.exe"""; Flags: uninsdeletevalue

[Run]
; Install WinUSB driver for IR-170 camera (VID=2936, PID=1202)
Filename: "{app}\wdi-simple.exe"; Parameters: "--vid 0x2936 --pid 0x1202 --type 0 --name ""OpticMix IR Camera"""; Flags: runhidden waituntilterminated; StatusMsg: "Installing WinUSB driver for IR camera..."; Check: FileExists(ExpandConstant('{app}\wdi-simple.exe'))
; Add firewall rule for streamer
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""OpticMix Streamer"" dir=in action=allow program=""{app}\leap_streamer.exe"" protocol=TCP"; Flags: runhidden waituntilterminated; StatusMsg: "Adding firewall rule..."
; Launch streamer
Filename: "{app}\leap_streamer.exe"; Description: "스트리머 시작"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Remove firewall rule
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""OpticMix Streamer"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveFirewall"
; Kill streamer
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM leap_streamer.exe"; Flags: runhidden waituntilterminated; RunOnceId: "KillStreamer"

[Code]
function InitializeSetup(): Boolean;
var
  WinVer: TWindowsVersion;
begin
  Result := True;
  GetWindowsVersionEx(WinVer);
  if (WinVer.Major < 10) or ((WinVer.Major = 10) and (WinVer.Build < 17763)) then
  begin
    MsgBox('OpticMix Edge requires Windows 10 version 1809 or later.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
end;
