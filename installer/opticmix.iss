; OpticMix Installer — Inno Setup Script
; Wraps Ultraleap Tracking Service + OpticMixTray into a single installer

#define MyAppName "OpticMix"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "OpticMix"
#define MyAppURL "https://opticmix.com"

; Source directories — adjust these paths for your build environment
#define TrackingSvcDir "C:\Program Files\Ultraleap\TrackingService\bin"
#define LeapSDKDir    "C:\Program Files\Ultraleap\LeapSDK\lib\x64"
#define TrayBuildDir  "..\edge\tools\tray\bin\Release\net8.0-windows\win-x64\publish"
#define EdgeDllDir    "..\edge\build\dll\Release"
#define EdgeStreamerDir "..\edge\build\streamer\Release"
#define AeroMixSvcDir  "..\aeromix\TF_Service_dotNet\TouchFree_Service\bin\Release\net10.0"
#define CursorOverlayDir "..\aeromix\CursorOverlay\bin\Release\net8.0-windows"

[Setup]
AppId={{29FA6342-8B1C-4E5A-9D3F-OPTICMIX0001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputBaseFilename=OpticMixSetup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\edge\tools\tray\opticmix.ico
UninstallDisplayIcon={app}\Tray\OpticMixTray.exe
MinVersion=10.0.17763
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "basic"; Description: "Basic (단일 PC + 센서)"
Name: "pro"; Description: "Pro (엣지컴퓨팅 + 멀티센서)"

[Components]
Name: "core"; Description: "OpticMix Tracking Engine"; Types: basic pro; Flags: fixed
Name: "tray"; Description: "OpticMix Tray (시스템 트레이 앱)"; Types: basic pro; Flags: fixed
Name: "aeromix"; Description: "AeroMix (에어 커서 오버레이)"; Types: basic pro
Name: "pro"; Description: "Pro — 네트워크 DLL + Streamer"; Types: pro

[Files]
; === Core: Tracking Service ===
Source: "{#TrackingSvcDir}\LeapSvc.exe"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: ignoreversion
Source: "{#TrackingSvcDir}\opencv_world4100.dll"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: ignoreversion
Source: "{#TrackingSvcDir}\libusb-1.0.dll"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: ignoreversion
Source: "{#TrackingSvcDir}\pthreadVC3.dll"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: ignoreversion
Source: "{#TrackingSvcDir}\Hyperion_Leap2.tok"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: ignoreversion
Source: "{#TrackingSvcDir}\leapctl.exe"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: ignoreversion
Source: "{#TrackingSvcDir}\hand_tracker_config.json"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: onlyifdoesntexist
Source: "{#TrackingSvcDir}\analytics_config.json"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: onlyifdoesntexist
Source: "{#TrackingSvcDir}\license_keys.json"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: onlyifdoesntexist

; ML model files
Source: "{#TrackingSvcDir}\ldat-*.ldat"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: ignoreversion

; Firmware
Source: "{#TrackingSvcDir}\firmware\*"; DestDir: "{app}\TrackingService\bin\firmware"; Components: core; Flags: ignoreversion recursesubdirs

; Basic: original librealuvc.dll (direct USB)
Source: "{#TrackingSvcDir}\librealuvc.dll"; DestDir: "{app}\TrackingService\bin"; Components: core; Flags: ignoreversion; Check: not IsComponentSelected('pro')
; Also save original for Pro rollback
Source: "{#TrackingSvcDir}\librealuvc.dll"; DestDir: "{app}\TrackingService\bin"; DestName: "librealuvc.dll.orig"; Components: pro; Flags: ignoreversion

; === Pro: Network DLL + Streamer ===
Source: "{#EdgeDllDir}\librealuvc.dll"; DestDir: "{app}\TrackingService\bin"; Components: pro; Flags: ignoreversion
Source: "{#EdgeStreamerDir}\leap_streamer.exe"; DestDir: "{app}\TrackingService\bin"; Components: pro; Flags: ignoreversion

; === AeroMix Service ===
Source: "{#AeroMixSvcDir}\AeroMix_Service.exe"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: ignoreversion
Source: "{#AeroMixSvcDir}\AeroMix_Service.dll"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: ignoreversion
Source: "{#AeroMixSvcDir}\AeroMix_Service.deps.json"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: ignoreversion
Source: "{#AeroMixSvcDir}\AeroMix_Service.runtimeconfig.json"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: ignoreversion
Source: "{#AeroMixSvcDir}\TouchFreeLib.dll"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: ignoreversion
Source: "{#AeroMixSvcDir}\Newtonsoft.Json.dll"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: ignoreversion
Source: "{#AeroMixSvcDir}\System.Reactive.dll"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: ignoreversion
Source: "{#AeroMixSvcDir}\Websocket.Client.dll"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: ignoreversion
Source: "{#AeroMixSvcDir}\LeapC.dll"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: ignoreversion
Source: "{#AeroMixSvcDir}\interaction-tuning.json"; DestDir: "{app}\AeroMix\Service"; Components: aeromix; Flags: onlyifdoesntexist
; Settings web UI
Source: "..\aeromix\SettingsUI_Web\dist\*"; DestDir: "{app}\AeroMix\Service\wwwroot"; Components: aeromix; Flags: ignoreversion recursesubdirs

; === CursorOverlay ===
Source: "{#CursorOverlayDir}\CursorOverlay.exe"; DestDir: "{app}\AeroMix\Overlay"; Components: aeromix; Flags: ignoreversion
Source: "{#CursorOverlayDir}\CursorOverlay.dll"; DestDir: "{app}\AeroMix\Overlay"; Components: aeromix; Flags: ignoreversion
Source: "{#CursorOverlayDir}\CursorOverlay.deps.json"; DestDir: "{app}\AeroMix\Overlay"; Components: aeromix; Flags: ignoreversion
Source: "{#CursorOverlayDir}\CursorOverlay.runtimeconfig.json"; DestDir: "{app}\AeroMix\Overlay"; Components: aeromix; Flags: ignoreversion

; === LeapC SDK ===
Source: "{#LeapSDKDir}\LeapC.dll"; DestDir: "{app}\LeapSDK\lib\x64"; Components: core; Flags: ignoreversion
; Also put LeapC.dll alongside tray app
Source: "{#LeapSDKDir}\LeapC.dll"; DestDir: "{app}\Tray"; Components: tray; Flags: ignoreversion

; === Tray App (self-contained publish) ===
Source: "{#TrayBuildDir}\*"; DestDir: "{app}\Tray"; Components: tray; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\OpticMix Visualizer"; Filename: "{app}\Tray\OpticMixTray.exe"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

[Registry]
; Auto-start tray app on login
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "OpticMixTray"; ValueData: """{app}\Tray\OpticMixTray.exe"""; Flags: uninsdeletevalue
; AeroMix is now managed as child processes by OpticMixTray — no separate autostart needed
; Store install info
Root: HKLM; Subkey: "SOFTWARE\OpticMix"; ValueType: string; ValueName: "InstallType"; ValueData: "pro"; Components: pro; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\OpticMix"; ValueType: string; ValueName: "InstallType"; ValueData: "basic"; Components: core; Check: not IsComponentSelected('pro'); Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\OpticMix"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\OpticMix"; ValueType: string; ValueName: "InstallDir"; ValueData: "{app}"; Flags: uninsdeletekey

[Run]
; Post-install: register and start service
Filename: "{sys}\sc.exe"; Parameters: "stop UltraleapTracking"; Flags: runhidden waituntilterminated; StatusMsg: "Stopping existing services..."
Filename: "{sys}\sc.exe"; Parameters: "config UltraleapTracking start= disabled"; Flags: runhidden waituntilterminated; StatusMsg: "Disabling Ultraleap service..."
Filename: "{sys}\sc.exe"; Parameters: "stop LeapService"; Flags: runhidden waituntilterminated; StatusMsg: "Stopping existing services..."
Filename: "{sys}\sc.exe"; Parameters: "config LeapService start= disabled"; Flags: runhidden waituntilterminated; StatusMsg: "Disabling Ultraleap service..."
Filename: "{sys}\sc.exe"; Parameters: "create OpticMixTracking binPath= ""{app}\TrackingService\bin\LeapSvc.exe --bg"" start= auto DisplayName= ""OpticMix Tracking Service"""; Flags: runhidden waituntilterminated; StatusMsg: "Registering OpticMix service..."
Filename: "{sys}\sc.exe"; Parameters: "start OpticMixTracking"; Flags: runhidden waituntilterminated; StatusMsg: "Starting OpticMix service..."
; Pro: add firewall rule
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""OpticMix Streamer"" dir=in action=allow program=""{app}\TrackingService\bin\leap_streamer.exe"" protocol=TCP"; Components: pro; Flags: runhidden waituntilterminated; StatusMsg: "Adding firewall rule..."
; Launch tray app (tray manages AeroMix child processes)
Filename: "{app}\Tray\OpticMixTray.exe"; Description: "OpticMix 시작"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop and delete service
Filename: "{sys}\sc.exe"; Parameters: "stop OpticMixTracking"; Flags: runhidden waituntilterminated
Filename: "{sys}\sc.exe"; Parameters: "delete OpticMixTracking"; Flags: runhidden waituntilterminated
; Remove firewall rule
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""OpticMix Streamer"""; Flags: runhidden waituntilterminated
; Kill AeroMix processes
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM CursorOverlay.exe"; Flags: runhidden waituntilterminated
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM AeroMix_Service.exe"; Flags: runhidden waituntilterminated
; Kill tray app
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM OpticMixTray.exe"; Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}\TrackingService\bin\crashes"
Type: filesandordirs; Name: "{app}\TrackingService\bin\captured_models"

[Code]
// Pre-install checks
function InitializeSetup(): Boolean;
var
  WinVer: TWindowsVersion;
begin
  Result := True;

  // Check Windows version
  GetWindowsVersionEx(WinVer);
  if (WinVer.Major < 10) or ((WinVer.Major = 10) and (WinVer.Build < 17763)) then
  begin
    MsgBox('OpticMix requires Windows 10 version 1809 or later.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

end;

// Stop existing service before install
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    // Stop OpticMixTracking if exists (upgrade scenario)
    Exec(ExpandConstant('{sys}\sc.exe'), 'stop OpticMixTracking', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    // Wait for service to fully stop
    Sleep(2000);
    // Delete old service before re-creating
    Exec(ExpandConstant('{sys}\sc.exe'), 'delete OpticMixTracking', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(1000);
    // Kill tray app and AeroMix if running
    Exec(ExpandConstant('{cmd}'), '/C taskkill /F /IM OpticMixTray.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec(ExpandConstant('{cmd}'), '/C taskkill /F /IM CursorOverlay.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec(ExpandConstant('{cmd}'), '/C taskkill /F /IM AeroMix_Service.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

// Cleanup on uninstall
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    // Remove auto-start registry
    RegDeleteValue(HKEY_CURRENT_USER, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'OpticMixTray');
    // Clean up OpticMix registry
    RegDeleteKeyIncludingSubkeys(HKEY_LOCAL_MACHINE, 'SOFTWARE\OpticMix');
  end;
end;

