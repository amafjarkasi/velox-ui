unit Velox.CrashReporter;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.CrashReporter
  Purpose:
    Global unhandled-exception reporter (`TVeloxCrashReporter`) inspired by
    JclDebug / madExcept / EurekaLog but dependency-free:
    - hooks `Application.OnException` (`Install` / `Uninstall`)
    - builds a plain-text report (app, version, time, exception, stack trace,
      recent `TVeloxLogger` ring-buffer entries)
    - writes `crash_*.txt` and a `crash_*.dmp` minidump (`dbghelp.dll`
      `MiniDumpWriteDump`)
    - shows a themed crash dialog with a "Copy Report" button
    Stack traces require debug line info (`-gl` for FPC).
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Graphics,
  Controls,
  Forms,
  Clipbrd,
  Velox.Types,
  Velox.Controls,
  Velox.Logger;

type
  /// <summary>
  /// Unhandled exception capture, report + minidump writer, and crash dialog
  /// </summary>
  TVeloxCrashReporter = class
  private
    FAppName: string;
    FAppVersion: string;
    FReportDir: string;
    FColors: TVeloxThemeColors;
    FShowDialog: Boolean;
    FInstalled: Boolean;
    FPrevHandler: TExceptionEvent;
    FLastReportPath: string;
    FLastDumpPath: string;
  public
    constructor Create(const AAppName, AAppVersion, AReportDir: string;
      const AColors: TVeloxThemeColors);
    destructor Destroy; override;

    procedure Install;
    procedure Uninstall;
    procedure OnAppException(Sender: TObject; E: Exception);

    /// <summary>Logs, writes report + minidump, optionally shows dialog. Returns the report path.</summary>
    function HandleException(const E: Exception): string;

    class function BuildReport(const AAppName, AAppVersion, AExceptionClass,
      AExceptionMessage, AStackTrace, ALogText: string): string; static;
    class function CaptureStackTrace: string; static;
    class function WriteMiniDump(const AFilePath: string): Boolean; static;
    class procedure ShowCrashDialog(const AOwner: TComponent;
      const AColors: TVeloxThemeColors; const AReport: string); static;

    property ShowDialog: Boolean read FShowDialog write FShowDialog;
    property ReportDir: string read FReportDir write FReportDir;
    property LastReportPath: string read FLastReportPath;
    property LastDumpPath: string read FLastDumpPath;
    property Installed: Boolean read FInstalled;
  end;

implementation

constructor TVeloxCrashReporter.Create(const AAppName, AAppVersion, AReportDir: string;
  const AColors: TVeloxThemeColors);
begin
  inherited Create;
  FAppName := AAppName;
  FAppVersion := AAppVersion;
  FReportDir := AReportDir;
  FColors := AColors;
  FShowDialog := True;
  FInstalled := False;
end;

destructor TVeloxCrashReporter.Destroy;
begin
  Uninstall;
  inherited Destroy;
end;

procedure TVeloxCrashReporter.Install;
begin
  if FInstalled then Exit;
  FPrevHandler := Application.OnException;
  Application.OnException := OnAppException;
  FInstalled := True;
end;

procedure TVeloxCrashReporter.Uninstall;
begin
  if not FInstalled then Exit;
  Application.OnException := FPrevHandler;
  FInstalled := False;
end;

procedure TVeloxCrashReporter.OnAppException(Sender: TObject; E: Exception);
begin
  HandleException(E);
end;

class function TVeloxCrashReporter.CaptureStackTrace: string;
{$IFDEF FPC}
var
  I: Integer;
{$ENDIF}
begin
  Result := '';
  {$IFDEF FPC}
  if ExceptAddr = nil then
  begin
    Result := BackTraceStrFunc(get_caller_addr(get_frame));
    Exit;
  end;
  Result := BackTraceStrFunc(ExceptAddr);
  for I := 0 to ExceptFrameCount - 1 do
    Result := Result + LineEnding + BackTraceStrFunc(ExceptFrames[I]);
  {$ENDIF}
end;

class function TVeloxCrashReporter.BuildReport(const AAppName, AAppVersion,
  AExceptionClass, AExceptionMessage, AStackTrace, ALogText: string): string;
var
  L: TStringList;
  SI: TSystemInfo;
begin
  GetSystemInfo(SI);
  L := TStringList.Create;
  try
    L.Add('==================== VeloxUI Crash Report ====================');
    L.Add('Application : ' + AAppName + ' ' + AAppVersion);
    L.Add('Time        : ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    L.Add('Executable  : ' + ParamStr(0));
    L.Add('Processors  : ' + IntToStr(SI.dwNumberOfProcessors));
    L.Add('Exception   : ' + AExceptionClass + ': ' + AExceptionMessage);
    L.Add('');
    L.Add('---- Stack Trace ----');
    if AStackTrace = '' then
      L.Add('(not available)')
    else
      L.Add(AStackTrace);
    L.Add('');
    L.Add('---- Recent Log ----');
    if ALogText = '' then
      L.Add('(empty)')
    else
      L.Add(ALogText);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

class function TVeloxCrashReporter.WriteMiniDump(const AFilePath: string): Boolean;
type
  TMiniDumpWriteDump = function(hProcess: THandle; ProcessId: DWORD; hFile: THandle;
    DumpType: DWORD; ExceptionParam, UserStreamParam, CallbackParam: Pointer): BOOL; stdcall;
var
  Lib: HMODULE;
  Fn: TMiniDumpWriteDump;
  H: THandle;
  WPath: WideString;
  Dir: string;
begin
  Result := False;
  if AFilePath = '' then Exit;
  Dir := ExtractFileDir(AFilePath);
  if (Dir <> '') and (not DirectoryExists(Dir)) then
    ForceDirectories(Dir);
  Lib := LoadLibrary('dbghelp.dll');
  if Lib = 0 then Exit;
  try
    @Fn := GetProcAddress(Lib, 'MiniDumpWriteDump');
    if not Assigned(Fn) then Exit;
    WPath := WideString(AFilePath);
    H := CreateFileW(PWideChar(WPath), GENERIC_WRITE, 0, nil, CREATE_ALWAYS,
      FILE_ATTRIBUTE_NORMAL, 0);
    if H = INVALID_HANDLE_VALUE then Exit;
    try
      // MiniDumpNormal = 0
      Result := Fn(GetCurrentProcess, GetCurrentProcessId, H, 0, nil, nil, nil);
    finally
      CloseHandle(H);
    end;
  finally
    FreeLibrary(Lib);
  end;
end;

class procedure TVeloxCrashReporter.ShowCrashDialog(const AOwner: TComponent;
  const AColors: TVeloxThemeColors; const AReport: string);
var
  Dlg: TVeloxModalDialog;
begin
  Dlg := TVeloxControls.CreateModalDialog(AOwner,
    'Application Error',
    'Unexpected Error',
    'The application hit an unhandled exception. A report was saved to disk.',
    740, 480, AColors, 'Copy Report', 'Close', True);
  try
    Dlg.Memo.Lines.Text := AReport;
    if Dlg.Form.ShowModal = mrYes then
      Clipboard.AsText := AReport;
  finally
    Dlg.Form.Free;
  end;
end;

function TVeloxCrashReporter.HandleException(const E: Exception): string;
var
  Report, Base, ExcClass, ExcMsg: string;
  L: TStringList;
begin
  Result := '';
  if E <> nil then
  begin
    ExcClass := E.ClassName;
    ExcMsg := E.Message;
  end
  else
  begin
    ExcClass := 'Unknown';
    ExcMsg := '';
  end;

  TVeloxLogger.Default.Error('Crash', ExcClass + ': ' + ExcMsg);
  Report := BuildReport(FAppName, FAppVersion, ExcClass, ExcMsg,
    CaptureStackTrace, TVeloxLogger.Default.FormatAsText);

  if FReportDir = '' then
    FReportDir := ExtractFilePath(ParamStr(0));
  ForceDirectories(FReportDir);
  Base := IncludeTrailingPathDelimiter(FReportDir) +
    'crash_' + FormatDateTime('yyyymmdd_hhnnss_zzz', Now);

  L := TStringList.Create;
  try
    L.Text := Report;
    try
      L.SaveToFile(Base + '.txt');
      FLastReportPath := Base + '.txt';
      Result := FLastReportPath;
    except
      FLastReportPath := '';
    end;
  finally
    L.Free;
  end;

  if WriteMiniDump(Base + '.dmp') then
    FLastDumpPath := Base + '.dmp'
  else
    FLastDumpPath := '';

  if FShowDialog then
    ShowCrashDialog(Application.MainForm, FColors, Report);
end;

end.
