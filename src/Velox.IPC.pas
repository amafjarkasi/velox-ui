unit Velox.IPC;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.IPC
  Purpose:
    Single-Instance Application Mutex & Local `WM_COPYDATA` IPC Message Bridge
    (`TVeloxSingleInstance`) inspired by `Alexey-T/Lazarus-WinAPI-examples`.
    Prevents duplicate instances of desktop utilities, forwards command-line
    arguments to an already-running window, and brings it to the foreground.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows;

type
  /// <summary>
  /// Win32 Named Mutex Single-Instance Guard & WM_COPYDATA IPC Sender
  /// </summary>
  TVeloxSingleInstance = class
  private
    FMutexHandle: THandle;
    FMutexName: string;
    FIsPrimaryInstance: Boolean;
  public
    constructor Create(const AMutexName: string);
    destructor Destroy; override;

    /// <summary>
    /// Sends a UTF-8 string payload to a target window HWND via WM_COPYDATA.
    /// </summary>
    class function SendIpcString(const ATargetWnd: HWND; const AMessage: string;
      const ADataTag: NativeUInt = $564C5831): Boolean; static;

    /// <summary>
    /// Extracts a UTF-8 string payload from a WM_COPYDATA PCopyDataStruct pointer.
    /// </summary>
    class function ExtractIpcString(const ACopyDataPtr: Pointer): string; static;

    /// <summary>
    /// Finds a top-level window by exact title, restores it if minimized,
    /// and brings it to the foreground.
    /// </summary>
    class function ActivateExistingWindow(const AWindowTitle: string): Boolean; static;

    property IsPrimaryInstance: Boolean read FIsPrimaryInstance;
    property MutexName: string read FMutexName;
  end;

implementation

type
  TCopyDataStruct = packed record
    dwData: NativeUInt;
    cbData: DWORD;
    lpData: Pointer;
  end;
  PCopyDataStruct = ^TCopyDataStruct;

const
  WM_COPYDATA_MSG = $004A;

{ TVeloxSingleInstance }

constructor TVeloxSingleInstance.Create(const AMutexName: string);
var
  SafeName: WideString;
  LastErr: DWORD;
begin
  inherited Create;
  FMutexName := AMutexName;
  if FMutexName = '' then
    FMutexName := 'Local\VeloxUI.DefaultMutex';

  SafeName := WideString(FMutexName);
  FMutexHandle := CreateMutexW(nil, False, PWideChar(SafeName));
  LastErr := GetLastError;
  FIsPrimaryInstance := (FMutexHandle <> 0) and (LastErr <> ERROR_ALREADY_EXISTS);
end;

destructor TVeloxSingleInstance.Destroy;
begin
  if FMutexHandle <> 0 then
  begin
    CloseHandle(FMutexHandle);
    FMutexHandle := 0;
  end;
  inherited Destroy;
end;

class function TVeloxSingleInstance.SendIpcString(const ATargetWnd: HWND;
  const AMessage: string; const ADataTag: NativeUInt): Boolean;
var
  CDS: TCopyDataStruct;
  Bytes: TBytes;
begin
  Result := False;
  if (ATargetWnd = 0) or (not IsWindow(ATargetWnd)) then Exit;

  Bytes := TEncoding.UTF8.GetBytes(AMessage);
  CDS.dwData := ADataTag;
  CDS.cbData := Length(Bytes);
  if CDS.cbData > 0 then
    CDS.lpData := @Bytes[0]
  else
    CDS.lpData := nil;

  SendMessageW(ATargetWnd, WM_COPYDATA_MSG, 0, LPARAM(@CDS));
  Result := True;
end;

class function TVeloxSingleInstance.ExtractIpcString(const ACopyDataPtr: Pointer): string;
var
  CDS: PCopyDataStruct;
  Bytes: TBytes;
begin
  Result := '';
  if ACopyDataPtr = nil then Exit;
  CDS := PCopyDataStruct(ACopyDataPtr);
  if (CDS^.cbData = 0) or (CDS^.lpData = nil) then Exit;

  SetLength(Bytes, CDS^.cbData);
  Move(CDS^.lpData^, Bytes[0], CDS^.cbData);
  Result := TEncoding.UTF8.GetString(Bytes);
end;

class function TVeloxSingleInstance.ActivateExistingWindow(const AWindowTitle: string): Boolean;
var
  WTitle: WideString;
  Wnd: HWND;
begin
  Result := False;
  if AWindowTitle = '' then Exit;
  WTitle := WideString(AWindowTitle);
  Wnd := FindWindowW(nil, PWideChar(WTitle));
  if Wnd <> 0 then
  begin
    if IsIconic(Wnd) then
      ShowWindow(Wnd, SW_RESTORE);
    SetForegroundWindow(Wnd);
    Result := True;
  end;
end;

end.
