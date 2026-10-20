unit Velox.Logger;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Logger
  Purpose:
    Structured, thread-safe circular ring-buffer logger (`TVeloxLogger`)
    inspired by `danieleteti/loggerpro`. Supports zero-allocation in-memory
    ring buffering, optional `.log` / `.jsonl` file appending, and a 1-call
    themed Live Diagnostics Log Viewer modal (`ShowLogViewerModal`).
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  Controls,
  Forms,
  Velox.Types,
  Velox.Controls;

const
  VELOX_LOG_CAPACITY = 256;

type
  TVeloxLogLevel = (vllDebug, vllInfo, vllWarn, vllError);

  TVeloxLogEntry = record
    Timestamp: TDateTime;
    Level: TVeloxLogLevel;
    Category: string;
    MessageText: string;
  end;

  TVeloxLogArray = array of TVeloxLogEntry;

  /// <summary>
  /// Thread-safe circular ring-buffer logger with JSONL/Text export & modal viewer
  /// </summary>
  TVeloxLogger = class
  private
    FLock: TCriticalSection;
    FEntries: array[0..VELOX_LOG_CAPACITY - 1] of TVeloxLogEntry;
    FHead: Integer;
    FCount: Integer;
    FMinLevel: TVeloxLogLevel;
    FLogFilePath: string;
    class var FDefaultLogger: TVeloxLogger;
    class function GetDefault: TVeloxLogger; static;
    procedure AppendToDisk(const AEntry: TVeloxLogEntry);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Log(const ALevel: TVeloxLogLevel; const ACategory, AMessage: string);
    procedure Debug(const ACategory, AMessage: string);
    procedure Info(const ACategory, AMessage: string);
    procedure Warn(const ACategory, AMessage: string);
    procedure Error(const ACategory, AMessage: string);
    procedure Clear;

    function GetEntries: TVeloxLogArray;
    function FormatAsText: string;
    function FormatAsJsonLines: string;
    function SaveToFile(const AFilePath: string): Boolean;

    /// <summary>
    /// Opens a themed modal dialog displaying all recent log entries in Consolas.
    /// </summary>
    procedure ShowLogViewerModal(const AOwner: TComponent; const AColors: TVeloxThemeColors);

    class function LevelToString(const ALevel: TVeloxLogLevel): string; static;

    property Count: Integer read FCount;
    property MinLevel: TVeloxLogLevel read FMinLevel write FMinLevel;
    property LogFilePath: string read FLogFilePath write FLogFilePath;

    class property Default: TVeloxLogger read GetDefault;
    class procedure ReleaseDefault; static;
  end;

implementation

{ TVeloxLogger }

constructor TVeloxLogger.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FHead := 0;
  FCount := 0;
  FMinLevel := vllDebug;
  FLogFilePath := '';
end;

destructor TVeloxLogger.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

class function TVeloxLogger.GetDefault: TVeloxLogger;
begin
  if FDefaultLogger = nil then
    FDefaultLogger := TVeloxLogger.Create;
  Result := FDefaultLogger;
end;

class procedure TVeloxLogger.ReleaseDefault;
begin
  FreeAndNil(FDefaultLogger);
end;

class function TVeloxLogger.LevelToString(const ALevel: TVeloxLogLevel): string;
begin
  case ALevel of
    vllDebug: Result := 'DEBUG';
    vllInfo:  Result := 'INFO ';
    vllWarn:  Result := 'WARN ';
    vllError: Result := 'ERROR';
  else
    Result := 'INFO ';
  end;
end;

procedure TVeloxLogger.AppendToDisk(const AEntry: TVeloxLogEntry);
var
  F: TextFile;
  LineStr: string;
begin
  if FLogFilePath = '' then Exit;
  LineStr := Format('[%s] [%s] [%s] %s', [
    FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AEntry.Timestamp),
    LevelToString(AEntry.Level),
    AEntry.Category,
    AEntry.MessageText
  ]);
  {$I-}
  AssignFile(F, FLogFilePath);
  if FileExists(FLogFilePath) then
    Append(F)
  else
    Rewrite(F);
  if IOResult = 0 then
  begin
    WriteLn(F, LineStr);
    CloseFile(F);
  end;
  {$I+}
end;

procedure TVeloxLogger.Log(const ALevel: TVeloxLogLevel; const ACategory, AMessage: string);
var
  Entry: TVeloxLogEntry;
begin
  if Ord(ALevel) < Ord(FMinLevel) then Exit;

  Entry.Timestamp   := Now;
  Entry.Level       := ALevel;
  Entry.Category    := ACategory;
  Entry.MessageText := AMessage;

  FLock.Enter;
  try
    FEntries[FHead] := Entry;
    FHead := (FHead + 1) mod VELOX_LOG_CAPACITY;
    if FCount < VELOX_LOG_CAPACITY then
      Inc(FCount);
    AppendToDisk(Entry);
  finally
    FLock.Leave;
  end;
end;

procedure TVeloxLogger.Debug(const ACategory, AMessage: string);
begin
  Log(vllDebug, ACategory, AMessage);
end;

procedure TVeloxLogger.Info(const ACategory, AMessage: string);
begin
  Log(vllInfo, ACategory, AMessage);
end;

procedure TVeloxLogger.Warn(const ACategory, AMessage: string);
begin
  Log(vllWarn, ACategory, AMessage);
end;

procedure TVeloxLogger.Error(const ACategory, AMessage: string);
begin
  Log(vllError, ACategory, AMessage);
end;

procedure TVeloxLogger.Clear;
begin
  FLock.Enter;
  try
    FHead := 0;
    FCount := 0;
  finally
    FLock.Leave;
  end;
end;

function TVeloxLogger.GetEntries: TVeloxLogArray;
var
  I, StartIdx: Integer;
begin
  Result := nil;
  FLock.Enter;
  try
    SetLength(Result, FCount);
    if FCount = 0 then Exit;
    if FCount < VELOX_LOG_CAPACITY then
      StartIdx := 0
    else
      StartIdx := FHead;
    for I := 0 to FCount - 1 do
      Result[I] := FEntries[(StartIdx + I) mod VELOX_LOG_CAPACITY];
  finally
    FLock.Leave;
  end;
end;

function TVeloxLogger.FormatAsText: string;
var
  Arr: TVeloxLogArray;
  Lines: TStringList;
  I: Integer;
begin
  Arr := GetEntries;
  Lines := TStringList.Create;
  try
    for I := 0 to High(Arr) do
    begin
      Lines.Add(Format('[%s] [%s] [%s] %s', [
        FormatDateTime('hh:nn:ss.zzz', Arr[I].Timestamp),
        LevelToString(Arr[I].Level),
        Arr[I].Category,
        Arr[I].MessageText
      ]));
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function TVeloxLogger.FormatAsJsonLines: string;
var
  Arr: TVeloxLogArray;
  Lines: TStringList;
  I: Integer;
  SafeCat, SafeMsg: string;
begin
  Arr := GetEntries;
  Lines := TStringList.Create;
  try
    for I := 0 to High(Arr) do
    begin
      SafeCat := StringReplace(Arr[I].Category, '"', '\"', [rfReplaceAll]);
      SafeMsg := StringReplace(Arr[I].MessageText, '"', '\"', [rfReplaceAll]);
      Lines.Add(Format('{"ts":"%s","level":"%s","cat":"%s","msg":"%s"}', [
        FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Arr[I].Timestamp),
        Trim(LevelToString(Arr[I].Level)),
        SafeCat,
        SafeMsg
      ]));
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function TVeloxLogger.SaveToFile(const AFilePath: string): Boolean;
var
  Lines: TStringList;
begin
  Result := False;
  if AFilePath = '' then Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := FormatAsText;
    Lines.SaveToFile(AFilePath);
    Result := FileExists(AFilePath);
  finally
    Lines.Free;
  end;
end;

procedure TVeloxLogger.ShowLogViewerModal(const AOwner: TComponent;
  const AColors: TVeloxThemeColors);
var
  Dlg: TVeloxModalDialog;
begin
  Dlg := TVeloxControls.CreateModalDialog(AOwner,
    'Diagnostics Log Viewer',
    'Application Diagnostics Log',
    Format('%d buffered log events (Capacity: %d)', [FCount, VELOX_LOG_CAPACITY]),
    700, 460, AColors, '', 'Close', True);
  try
    Dlg.Memo.Lines.Text := FormatAsText;
    Dlg.Form.ShowModal;
  finally
    Dlg.Form.Free;
  end;
end;

initialization

finalization
  TVeloxLogger.ReleaseDefault;

end.
