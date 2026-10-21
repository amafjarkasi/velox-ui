unit Velox.Services;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes;

type
  TVeloxServiceState = (
    vssStopped,
    vssStartPending,
    vssStopPending,
    vssRunning,
    vssContinuePending,
    vssPausePending,
    vssPaused,
    vssUnknown
  );

  TVeloxServiceInfo = record
    ServiceName: string;
    DisplayName: string;
    State: TVeloxServiceState;
    ProcessId: Cardinal;
  end;

  TVeloxServiceArray = array of TVeloxServiceInfo;

  TVeloxServices = class
  public
    /// <summary>Queries the current run state of a named Windows service.</summary>
    class function GetServiceState(const AServiceName: string): TVeloxServiceState; static;
    /// <summary>Starts a Windows service via Service Control Manager.</summary>
    class function StartService(const AServiceName: string; TimeoutSec: Integer = 10): Boolean; static;
    /// <summary>Stops a running Windows service.</summary>
    class function StopService(const AServiceName: string; TimeoutSec: Integer = 10): Boolean; static;
    /// <summary>Restarts a Windows service (stops, waits, then starts).</summary>
    class function RestartService(const AServiceName: string): Boolean; static;
    /// <summary>Enumerates active or all registered Windows services.</summary>
    class function EnumServices(AOnlyRunning: Boolean = False): TVeloxServiceArray; static;
    /// <summary>Formats service state into a user-readable string.</summary>
    class function StateToString(const AState: TVeloxServiceState): string; static;
  end;

implementation

const
  SC_MANAGER_CONNECT             = $0001;
  SC_MANAGER_ENUMERATE_SERVICE   = $0004;
  SERVICE_QUERY_STATUS           = $0004;
  SERVICE_START                  = $0010;
  SERVICE_STOP                   = $0020;
  SERVICE_STATE_ALL              = $00000003;
  SERVICE_WIN32                  = $00000030;

  SERVICE_STOPPED          = $00000001;
  SERVICE_START_PENDING    = $00000002;
  SERVICE_STOP_PENDING     = $00000003;
  SERVICE_RUNNING          = $00000004;
  SERVICE_CONTINUE_PENDING = $00000005;
  SERVICE_PAUSE_PENDING    = $00000006;
  SERVICE_PAUSED           = $00000007;

type
  _SERVICE_STATUS_PROCESS = record
    dwServiceType: DWORD;
    dwCurrentState: DWORD;
    dwControlsAccepted: DWORD;
    dwWin32ExitCode: DWORD;
    dwServiceSpecificExitCode: DWORD;
    dwCheckPoint: DWORD;
    dwWaitHint: DWORD;
    dwProcessId: DWORD;
    dwServiceFlags: DWORD;
  end;
  SERVICE_STATUS_PROCESS = _SERVICE_STATUS_PROCESS;

  _ENUM_SERVICE_STATUS_PROCESSW = record
    lpServiceName: LPWSTR;
    lpDisplayName: LPWSTR;
    ServiceStatusProcess: SERVICE_STATUS_PROCESS;
  end;
  ENUM_SERVICE_STATUS_PROCESSW = _ENUM_SERVICE_STATUS_PROCESSW;
  PENUM_SERVICE_STATUS_PROCESSW = ^ENUM_SERVICE_STATUS_PROCESSW;

function OpenSCManagerW(lpMachineName, lpDatabaseName: LPCWSTR; dwDesiredAccess: DWORD): SC_HANDLE;
  stdcall; external 'advapi32.dll' name 'OpenSCManagerW';

function CloseServiceHandle(hSCObject: SC_HANDLE): BOOL;
  stdcall; external 'advapi32.dll' name 'CloseServiceHandle';

function OpenServiceW(hSCManager: SC_HANDLE; lpServiceName: LPCWSTR; dwDesiredAccess: DWORD): SC_HANDLE;
  stdcall; external 'advapi32.dll' name 'OpenServiceW';

function StartServiceW(hService: SC_HANDLE; dwNumServiceArgs: DWORD; lpServiceArgVectors: Pointer): BOOL;
  stdcall; external 'advapi32.dll' name 'StartServiceW';

function ControlService(hService: SC_HANDLE; dwControl: DWORD; lpServiceStatus: Pointer): BOOL;
  stdcall; external 'advapi32.dll' name 'ControlService';

function QueryServiceStatusEx(hService: SC_HANDLE; InfoLevel: Integer;
  lpBuffer: Pointer; cbBufSize: DWORD; var pcbBytesNeeded: DWORD): BOOL;
  stdcall; external 'advapi32.dll' name 'QueryServiceStatusEx';

function EnumServicesStatusExW(hSCManager: SC_HANDLE; InfoLevel: Integer; dwServiceType: DWORD;
  dwServiceState: DWORD; lpServices: Pointer; cbBufSize: DWORD;
  var pcbBytesNeeded: DWORD; var lpServicesReturned: DWORD;
  var lpResumeHandle: DWORD; pszGroupName: LPCWSTR): BOOL;
  stdcall; external 'advapi32.dll' name 'EnumServicesStatusExW';

function NativeStateToVelox(const S: DWORD): TVeloxServiceState;
begin
  case S of
    SERVICE_STOPPED:          Result := vssStopped;
    SERVICE_START_PENDING:    Result := vssStartPending;
    SERVICE_STOP_PENDING:     Result := vssStopPending;
    SERVICE_RUNNING:          Result := vssRunning;
    SERVICE_CONTINUE_PENDING: Result := vssContinuePending;
    SERVICE_PAUSE_PENDING:    Result := vssPausePending;
    SERVICE_PAUSED:           Result := vssPaused;
  else
    Result := vssUnknown;
  end;
end;

{ TVeloxServices }

class function TVeloxServices.StateToString(const AState: TVeloxServiceState): string;
begin
  case AState of
    vssStopped:          Result := 'Stopped';
    vssStartPending:     Result := 'Starting...';
    vssStopPending:      Result := 'Stopping...';
    vssRunning:          Result := 'Running';
    vssContinuePending: Result := 'Resuming...';
    vssPausePending:    Result := 'Pausing...';
    vssPaused:           Result := 'Paused';
  else
    Result := 'Unknown';
  end;
end;

class function TVeloxServices.GetServiceState(const AServiceName: string): TVeloxServiceState;
var
  hSCM, hSvc: SC_HANDLE;
  SSP: SERVICE_STATUS_PROCESS;
  BytesNeeded: DWORD;
  WideName: WideString;
begin
  Result := vssUnknown;
  hSCM := OpenSCManagerW(nil, nil, SC_MANAGER_CONNECT);
  if hSCM = 0 then Exit;
  try
    WideName := WideString(AServiceName);
    hSvc := OpenServiceW(hSCM, PWideChar(WideName), SERVICE_QUERY_STATUS);
    if hSvc = 0 then Exit;
    try
      BytesNeeded := 0;
      if QueryServiceStatusEx(hSvc, 0 { SC_STATUS_PROCESS_INFO },
         @SSP, SizeOf(SSP), BytesNeeded) then
      begin
        Result := NativeStateToVelox(SSP.dwCurrentState);
      end;
    finally
      CloseServiceHandle(hSvc);
    end;
  finally
    CloseServiceHandle(hSCM);
  end;
end;

class function TVeloxServices.StartService(const AServiceName: string; TimeoutSec: Integer): Boolean;
var
  hSCM, hSvc: SC_HANDLE;
  WideName: WideString;
  WaitCount: Integer;
begin
  Result := False;
  hSCM := OpenSCManagerW(nil, nil, SC_MANAGER_CONNECT);
  if hSCM = 0 then Exit;
  try
    WideName := WideString(AServiceName);
    hSvc := OpenServiceW(hSCM, PWideChar(WideName), SERVICE_START or SERVICE_QUERY_STATUS);
    if hSvc = 0 then Exit;
    try
      if not StartServiceW(hSvc, 0, nil) then
      begin
        if GetLastError = ERROR_SERVICE_ALREADY_RUNNING then
          Exit(True)
        else
          Exit(False);
      end;

      WaitCount := 0;
      while WaitCount < TimeoutSec * 10 do
      begin
        Sleep(100);
        Inc(WaitCount);
        if GetServiceState(AServiceName) = vssRunning then
          Exit(True);
      end;
    finally
      CloseServiceHandle(hSvc);
    end;
  finally
    CloseServiceHandle(hSCM);
  end;
end;

class function TVeloxServices.StopService(const AServiceName: string; TimeoutSec: Integer): Boolean;
var
  hSCM, hSvc: SC_HANDLE;
  WideName: WideString;
  SS: SERVICE_STATUS_PROCESS;
  WaitCount: Integer;
begin
  Result := False;
  hSCM := OpenSCManagerW(nil, nil, SC_MANAGER_CONNECT);
  if hSCM = 0 then Exit;
  try
    WideName := WideString(AServiceName);
    hSvc := OpenServiceW(hSCM, PWideChar(WideName), SERVICE_STOP or SERVICE_QUERY_STATUS);
    if hSvc = 0 then Exit;
    try
      ControlService(hSvc, 1 { SERVICE_CONTROL_STOP }, @SS);

      WaitCount := 0;
      while WaitCount < TimeoutSec * 10 do
      begin
        Sleep(100);
        Inc(WaitCount);
        if GetServiceState(AServiceName) = vssStopped then
          Exit(True);
      end;
    finally
      CloseServiceHandle(hSvc);
    end;
  finally
    CloseServiceHandle(hSCM);
  end;
end;

class function TVeloxServices.RestartService(const AServiceName: string): Boolean;
begin
  StopService(AServiceName, 5);
  Sleep(200);
  Result := StartService(AServiceName, 5);
end;

class function TVeloxServices.EnumServices(AOnlyRunning: Boolean): TVeloxServiceArray;
var
  hSCM: SC_HANDLE;
  BytesNeeded, ServicesReturned, ResumeHandle: DWORD;
  Buf: array of Byte;
  PList: PENUM_SERVICE_STATUS_PROCESSW;
  StateFilter: DWORD;
  I: Integer;
begin
  SetLength(Result, 0);
  hSCM := OpenSCManagerW(nil, nil, SC_MANAGER_ENUMERATE_SERVICE);
  if hSCM = 0 then Exit;
  try
    if AOnlyRunning then
      StateFilter := 1 { SERVICE_ACTIVE }
    else
      StateFilter := SERVICE_STATE_ALL;

    BytesNeeded := 0;
    ServicesReturned := 0;
    ResumeHandle := 0;

    EnumServicesStatusExW(hSCM, 0, SERVICE_WIN32, StateFilter,
      nil, 0, BytesNeeded, ServicesReturned, ResumeHandle, nil);

    if BytesNeeded = 0 then Exit;

    SetLength(Buf, BytesNeeded);
    PList := PENUM_SERVICE_STATUS_PROCESSW(@Buf[0]);

    if EnumServicesStatusExW(hSCM, 0, SERVICE_WIN32, StateFilter,
      PList, BytesNeeded, BytesNeeded, ServicesReturned, ResumeHandle, nil) then
    begin
      SetLength(Result, ServicesReturned);
      for I := 0 to Integer(ServicesReturned) - 1 do
      begin
        Result[I].ServiceName := string(WideString(PList^.lpServiceName));
        Result[I].DisplayName := string(WideString(PList^.lpDisplayName));
        Result[I].State       := NativeStateToVelox(PList^.ServiceStatusProcess.dwCurrentState);
        Result[I].ProcessId   := PList^.ServiceStatusProcess.dwProcessId;
        Inc(PList);
      end;
    end;
  finally
    CloseServiceHandle(hSCM);
  end;
end;

end.
