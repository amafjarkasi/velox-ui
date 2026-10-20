unit Velox.System;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.System
  Purpose:
    Reusable, zero-dependency Win32 & NT Kernel (`ntdll.dll`, `version.dll`,
    `user32.dll`, `psapi.dll`, `shell32.dll`, `advapi32.dll`) wrappers for:
    1. Extracting remote process command lines via `NtQueryInformationProcess`
       (Class 60 `ProcessCommandLineInformation`) using only
       `PROCESS_QUERY_LIMITED_INFORMATION ($1000)`—no `PROCESS_VM_READ` needed.
    2. Extracting PE executable version metadata (`FileDescription`,
       `CompanyName`, `FileVersion`) via `version.dll`.
    3. Reading per-process GDI & USER object counts via `GetGuiResources`.
    4. Managing process CPU core affinity masks (`GetProcessAffinityMask` /
       `SetProcessAffinityMask`) with safety guards for PID 0 / PID 4.
    5. Trimming process working set RAM via `EmptyWorkingSet` (`psapi.dll`).
    6. Launching tasks with optional UAC Administrator elevation (`runas`).
    7. Checking process elevation token (`TokenElevation`).
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  {$IFDEF FPC}
  ShellApi
  {$ELSE}
  Winapi.ShellApi
  {$ENDIF};

type
  /// <summary>
  /// Extracted PE FileVersionInfo metadata
  /// </summary>
  TVeloxFileVersionInfo = record
    FileDescription: string;
    CompanyName: string;
    FileVersion: string;
  end;

  /// <summary>
  /// High-performance Win32 & NT Kernel system helpers
  /// </summary>
  TVeloxSystem = class
  public
    /// <summary>
    /// Returns True if the current process is running with elevated
    /// Administrator privileges (TokenElevation).
    /// </summary>
    class function IsCurrentProcessElevated: Boolean; static;

    /// <summary>
    /// Queries a process's full command-line arguments via
    /// NtQueryInformationProcess(ProcessCommandLineInformation = 60)
    /// using only PROCESS_QUERY_LIMITED_INFORMATION ($1000).
    /// </summary>
    class function GetProcessCommandLine(const AProcessId: Cardinal): string; static;

    /// <summary>
    /// Extracts FileDescription, CompanyName (Digital Publisher), and
    /// FileVersion from a PE binary on disk via version.dll.
    /// </summary>
    class function GetFileVersionMetadata(const AFilePath: string): TVeloxFileVersionInfo; static;

    /// <summary>
    /// Queries GDI and USER handle counts for a process via GetGuiResources.
    /// Useful for detecting GUI handle leaks (>2000 objects).
    /// </summary>
    class function GetProcessGuiResources(const AProcessId: Cardinal;
      out AGdiObjects, AUserObjects: Cardinal): Boolean; static;

    /// <summary>
    /// Queries or updates the logical CPU core affinity mask for a process.
    /// </summary>
    class function GetProcessAffinity(const AProcessId: Cardinal;
      out AProcessMask, ASystemMask: NativeUInt): Boolean; static;
    class function SetProcessAffinity(const AProcessId: Cardinal;
      const AProcessMask: NativeUInt): Boolean; static;

    /// <summary>
    /// Reclaims unused physical RAM pages from a process's working set via
    /// EmptyWorkingSet (psapi.dll).
    /// </summary>
    class function TrimProcessWorkingSet(const AProcessId: Cardinal): Boolean; static;

    /// <summary>
    /// Launches an executable, script, or command with optional UAC
    /// Administrator elevation ('runas' verb via ShellExecuteExW).
    /// </summary>
    class function RunTask(const ACommandLine: string; const ARunAsAdmin: Boolean = False): Boolean; static;

    /// <summary>
    /// Opens Windows Explorer with the specified file selected.
    /// </summary>
    class procedure ExploreFileLocation(const AFilePath: string); static;
  end;

implementation

const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  PROCESS_SET_INFORMATION           = $0200;
  PROCESS_SET_QUOTA                 = $0100;
  ProcessCommandLineInformation     = 60;
  GR_GDIOBJECTS                     = 0;
  GR_USEROBJECTS                    = 1;

type
  TNtUnicodeString = record
    Length: Word;
    MaximumLength: Word;
    {$IFDEF CPU64}
    Padding: Cardinal;
    {$ENDIF}
    Buffer: PWideChar;
  end;
  PNtUnicodeString = ^TNtUnicodeString;

  TNtQueryInformationProcess = function(
    ProcessHandle: THandle;
    ProcessInformationClass: Cardinal;
    ProcessInformation: Pointer;
    ProcessInformationLength: Cardinal;
    ReturnLength: PCardinal
  ): LongInt; stdcall;

  TEmptyWorkingSet = function(hProcess: THandle): BOOL; stdcall;

function GetGuiResources(hProcess: THandle; uiFlags: DWORD): DWORD; stdcall;
  external 'user32.dll' name 'GetGuiResources';
function GetFileVersionInfoSizeW(lptstrFilename: PWideChar; var lpdwHandle: DWORD): DWORD; stdcall;
  external 'version.dll' name 'GetFileVersionInfoSizeW';
function GetFileVersionInfoW(lptstrFilename: PWideChar; dwHandle, dwLen: DWORD; lpData: Pointer): BOOL; stdcall;
  external 'version.dll' name 'GetFileVersionInfoW';
function VerQueryValueW(pBlock: Pointer; lpSubBlock: PWideChar; var lplpBuffer: Pointer; var puLen: UINT): BOOL; stdcall;
  external 'version.dll' name 'VerQueryValueW';

var
  GNtdllLoaded: Boolean = False;
  GNtQueryInfoProcess: TNtQueryInformationProcess = nil;
  GPsapiLoaded: Boolean = False;
  GEmptyWorkingSet: TEmptyWorkingSet = nil;

procedure EnsureNtProcessLoaded;
var
  Lib: HMODULE;
begin
  if GNtdllLoaded then Exit;
  GNtdllLoaded := True;
  Lib := GetModuleHandle('ntdll.dll');
  if Lib <> 0 then
    @GNtQueryInfoProcess := GetProcAddress(Lib, 'NtQueryInformationProcess');
end;

procedure EnsurePsapiLoaded;
var
  Lib: HMODULE;
begin
  if GPsapiLoaded then Exit;
  GPsapiLoaded := True;
  Lib := GetModuleHandle('psapi.dll');
  if Lib = 0 then
    Lib := LoadLibrary('psapi.dll');
  if Lib <> 0 then
  begin
    @GEmptyWorkingSet := GetProcAddress(Lib, 'EmptyWorkingSet');
    if not Assigned(GEmptyWorkingSet) then
    begin
      Lib := GetModuleHandle('kernel32.dll');
      if Lib <> 0 then
        @GEmptyWorkingSet := GetProcAddress(Lib, 'K32EmptyWorkingSet');
    end;
  end;
end;

{ TVeloxSystem }

class function TVeloxSystem.IsCurrentProcessElevated: Boolean;
const
  TokenElevation = 20;
var
  Token: THandle;
  Elevation: DWORD;
  RetLen: DWORD;
begin
  Result := False;
  if OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, Token) then
  begin
    try
      Elevation := 0;
      RetLen := 0;
      if GetTokenInformation(Token, TTokenInformationClass(TokenElevation),
         @Elevation, SizeOf(Elevation), RetLen) then
      begin
        Result := Elevation <> 0;
      end;
    finally
      CloseHandle(Token);
    end;
  end;
end;

class function TVeloxSystem.GetProcessCommandLine(const AProcessId: Cardinal): string;
var
  ProcHandle: THandle;
  BufSize: Cardinal;
  Buf: Pointer;
  Status: LongInt;
  Ustr: PNtUnicodeString;
begin
  Result := '';
  if AProcessId <= 4 then Exit;
  EnsureNtProcessLoaded;
  if not Assigned(GNtQueryInfoProcess) then Exit;

  ProcHandle := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, AProcessId);
  if ProcHandle = 0 then Exit;
  try
    BufSize := 0;
    Status := GNtQueryInfoProcess(ProcHandle, ProcessCommandLineInformation, nil, 0, @BufSize);
    if (BufSize = 0) or (BufSize > 65536) then Exit;

    GetMem(Buf, BufSize);
    try
      Status := GNtQueryInfoProcess(ProcHandle, ProcessCommandLineInformation, Buf, BufSize, @BufSize);
      if Status >= 0 then
      begin
        Ustr := PNtUnicodeString(Buf);
        if (Ustr^.Length > 0) and (Ustr^.Buffer <> nil) then
          Result := Trim( string(Copy(WideString(Ustr^.Buffer), 1, Ustr^.Length div SizeOf(WideChar))) );
      end;
    finally
      FreeMem(Buf);
    end;
  finally
    CloseHandle(ProcHandle);
  end;
end;

class function TVeloxSystem.GetFileVersionMetadata(const AFilePath: string): TVeloxFileVersionInfo;
type
  TLangAndCodePage = packed record
    wLanguage: Word;
    wCodePage: Word;
  end;
  PLangAndCodePage = ^TLangAndCodePage;
var
  WPath, SubBlock: WideString;
  Dummy, InfoSize: DWORD;
  VerBuf, ValPtr: Pointer;
  ValLen: UINT;
  TransPtr: PLangAndCodePage;
  LangHex: string;

  function QueryField(const AFieldName: string): string;
  begin
    Result := '';
    SubBlock := WideString(Format('\StringFileInfo\%s\%s', [LangHex, AFieldName]));
    ValPtr := nil;
    ValLen := 0;
    if VerQueryValueW(VerBuf, PWideChar(SubBlock), ValPtr, ValLen) and
       (ValPtr <> nil) and (ValLen > 0) then
      Result := Trim(string(WideString(PWideChar(ValPtr))));
  end;

begin
  Result.FileDescription := '';
  Result.CompanyName := '';
  Result.FileVersion := '';
  if (AFilePath = '') or not FileExists(AFilePath) then Exit;

  WPath := WideString(AFilePath);
  Dummy := 0;
  InfoSize := GetFileVersionInfoSizeW(PWideChar(WPath), Dummy);
  if InfoSize = 0 then Exit;

  GetMem(VerBuf, InfoSize);
  try
    if GetFileVersionInfoW(PWideChar(WPath), 0, InfoSize, VerBuf) then
    begin
      ValPtr := nil;
      ValLen := 0;
      if VerQueryValueW(VerBuf, '\VarFileInfo\Translation', ValPtr, ValLen) and
         (ValPtr <> nil) and (ValLen >= SizeOf(TLangAndCodePage)) then
      begin
        TransPtr := PLangAndCodePage(ValPtr);
        LangHex := IntToHex(TransPtr^.wLanguage, 4) + IntToHex(TransPtr^.wCodePage, 4);
        Result.FileDescription := QueryField('FileDescription');
        Result.CompanyName     := QueryField('CompanyName');
        Result.FileVersion     := QueryField('FileVersion');
      end;
    end;
  finally
    FreeMem(VerBuf);
  end;
end;

class function TVeloxSystem.GetProcessGuiResources(const AProcessId: Cardinal;
  out AGdiObjects, AUserObjects: Cardinal): Boolean;
var
  ProcHandle: THandle;
begin
  Result := False;
  AGdiObjects := 0;
  AUserObjects := 0;
  if AProcessId <= 4 then Exit;
  ProcHandle := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, AProcessId);
  if ProcHandle = 0 then Exit;
  try
    AGdiObjects  := GetGuiResources(ProcHandle, GR_GDIOBJECTS);
    AUserObjects := GetGuiResources(ProcHandle, GR_USEROBJECTS);
    Result := True;
  finally
    CloseHandle(ProcHandle);
  end;
end;

class function TVeloxSystem.GetProcessAffinity(const AProcessId: Cardinal;
  out AProcessMask, ASystemMask: NativeUInt): Boolean;
var
  ProcHandle: THandle;
  ProcM, SysM: PtrUInt;
begin
  Result := False;
  AProcessMask := 0;
  ASystemMask := 0;
  if AProcessId <= 4 then Exit;
  ProcHandle := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, AProcessId);
  if ProcHandle = 0 then Exit;
  try
    ProcM := 0;
    SysM := 0;
    if Windows.GetProcessAffinityMask(ProcHandle, ProcM, SysM) then
    begin
      AProcessMask := ProcM;
      ASystemMask := SysM;
      Result := True;
    end;
  finally
    CloseHandle(ProcHandle);
  end;
end;

class function TVeloxSystem.SetProcessAffinity(const AProcessId: Cardinal;
  const AProcessMask: NativeUInt): Boolean;
var
  ProcHandle: THandle;
begin
  Result := False;
  if (AProcessId <= 4) or (AProcessMask = 0) then Exit;
  ProcHandle := OpenProcess(PROCESS_SET_INFORMATION or PROCESS_QUERY_LIMITED_INFORMATION, False, AProcessId);
  if ProcHandle = 0 then Exit;
  try
    Result := Windows.SetProcessAffinityMask(ProcHandle, AProcessMask);
  finally
    CloseHandle(ProcHandle);
  end;
end;

class function TVeloxSystem.TrimProcessWorkingSet(const AProcessId: Cardinal): Boolean;
var
  ProcHandle: THandle;
begin
  Result := False;
  if AProcessId <= 4 then Exit;
  EnsurePsapiLoaded;
  if not Assigned(GEmptyWorkingSet) then Exit;

  ProcHandle := OpenProcess(PROCESS_SET_QUOTA or PROCESS_QUERY_LIMITED_INFORMATION, False, AProcessId);
  if ProcHandle = 0 then Exit;
  try
    Result := GEmptyWorkingSet(ProcHandle);
  finally
    CloseHandle(ProcHandle);
  end;
end;

class function TVeloxSystem.RunTask(const ACommandLine: string; const ARunAsAdmin: Boolean): Boolean;
var
  Trimmed, ExePath, Params: string;
  SpacePos: Integer;
  SEI: TShellExecuteInfoW;
  WExe, WParams, WVerb: WideString;
begin
  Result := False;
  Trimmed := Trim(ACommandLine);
  if Trimmed = '' then Exit;

  if Trimmed[1] = '"' then
  begin
    Delete(Trimmed, 1, 1);
    SpacePos := Pos('"', Trimmed);
    if SpacePos > 0 then
    begin
      ExePath := Copy(Trimmed, 1, SpacePos - 1);
      Params := Trim(Copy(Trimmed, SpacePos + 1, MaxInt));
    end
    else
    begin
      ExePath := Trimmed;
      Params := '';
    end;
  end
  else
  begin
    SpacePos := Pos(' ', Trimmed);
    if SpacePos > 0 then
    begin
      ExePath := Copy(Trimmed, 1, SpacePos - 1);
      Params := Trim(Copy(Trimmed, SpacePos + 1, MaxInt));
    end
    else
    begin
      ExePath := Trimmed;
      Params := '';
    end;
  end;

  WExe := WideString(ExePath);
  WParams := WideString(Params);
  if ARunAsAdmin then
    WVerb := 'runas'
  else
    WVerb := 'open';

  FillChar(SEI, SizeOf(SEI), 0);
  SEI.cbSize := SizeOf(SEI);
  SEI.lpVerb := PWideChar(WVerb);
  SEI.lpFile := PWideChar(WExe);
  if Params <> '' then
    SEI.lpParameters := PWideChar(WParams);
  SEI.nShow := SW_SHOWNORMAL;

  Result := ShellExecuteExW(@SEI);
end;

class procedure TVeloxSystem.ExploreFileLocation(const AFilePath: string);
begin
  if (AFilePath <> '') and FileExists(AFilePath) then
    ShellExecute(0, 'open', 'explorer.exe', PChar('/select,"' + AFilePath + '"'), nil, SW_SHOWNORMAL);
end;

end.
