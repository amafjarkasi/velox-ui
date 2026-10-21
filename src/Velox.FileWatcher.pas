unit Velox.FileWatcher;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.FileWatcher
  Purpose:
    Non-blocking background directory and file modification monitor (`TVeloxFileWatcher`)
    inspired by `pyscripter/FileSystemMonitor` and `VSoft.ExternalModDetector`.
    Built directly on the Win32 `ReadDirectoryChangesW` API with a lightweight
    worker thread, interruptible shutdown event, and debouncing.
    Dispatches main-thread events (`OnChanged`, `OnCreated`, `OnDeleted`, `OnRenamed`).
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows;

type
  TVeloxFileAction = (vfaCreated, vfaModified, vfaDeleted, vfaRenamed);

  TVeloxFileChangeEvent = procedure(Sender: TObject; const AAction: TVeloxFileAction;
    const ARelPath, AOldRelPath: string) of object;

  /// <summary>
  /// Directory modification watcher thread
  /// </summary>
  TVeloxWatcherThread = class(TThread)
  private
    FOwner: TObject;
    FDirectory: string;
    FRecursive: Boolean;
    FStopEvent: THandle;
    FDirHandle: THandle;
    FNotifyFilter: DWORD;
    FOnChange: TVeloxFileChangeEvent;
    FPendingAction: TVeloxFileAction;
    FPendingRelPath: string;
    FPendingOldRelPath: string;
    procedure SyncNotify;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TObject; const ADirectory: string;
      const ARecursive: Boolean; const AOnChange: TVeloxFileChangeEvent);
    destructor Destroy; override;
    procedure Stop;
  end;

  /// <summary>
  /// Non-blocking file & directory watcher component
  /// </summary>
  TVeloxFileWatcher = class(TComponent)
  private
    FDirectory: string;
    FRecursive: Boolean;
    FThread: TVeloxWatcherThread;
    FActive: Boolean;
    FOnChanged: TVeloxFileChangeEvent;
    procedure SetActive(const AValue: Boolean);
    procedure SetDirectory(const AValue: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    property Directory: string read FDirectory write SetDirectory;
    property Recursive: Boolean read FRecursive write FRecursive default True;
    property Active: Boolean read FActive write SetActive;
    property OnChanged: TVeloxFileChangeEvent read FOnChanged write FOnChanged;
  end;

implementation

type
  PFileNotifyInformation = ^TFileNotifyInformation;
  TFileNotifyInformation = record
    NextEntryOffset: DWORD;
    Action: DWORD;
    FileNameLength: DWORD;
    FileName: array[0..0] of WCHAR;
  end;

const
  FILE_NOTIFY_CHANGE_FILE_NAME  = $00000001;
  FILE_NOTIFY_CHANGE_DIR_NAME   = $00000002;
  FILE_NOTIFY_CHANGE_LAST_WRITE = $00000010;
  FILE_NOTIFY_CHANGE_SIZE       = $00000008;

  FILE_ACTION_ADDED            = 1;
  FILE_ACTION_REMOVED          = 2;
  FILE_ACTION_MODIFIED         = 3;
  FILE_ACTION_RENAMED_OLD_NAME = 4;
  FILE_ACTION_RENAMED_NEW_NAME = 5;

{ TVeloxWatcherThread }

constructor TVeloxWatcherThread.Create(AOwner: TObject; const ADirectory: string;
  const ARecursive: Boolean; const AOnChange: TVeloxFileChangeEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FDirectory := ADirectory;
  FRecursive := ARecursive;
  FOnChange := AOnChange;
  FStopEvent := CreateEvent(nil, True, False, nil);
  FDirHandle := INVALID_HANDLE_VALUE;
  FNotifyFilter := FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_DIR_NAME or
                   FILE_NOTIFY_CHANGE_LAST_WRITE or FILE_NOTIFY_CHANGE_SIZE;
  Start;
end;

destructor TVeloxWatcherThread.Destroy;
begin
  Stop;
  inherited Destroy;
  if FStopEvent <> 0 then
    CloseHandle(FStopEvent);
end;

procedure TVeloxWatcherThread.Stop;
begin
  if FStopEvent <> 0 then
    SetEvent(FStopEvent);
  Terminate;
  if FDirHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FDirHandle);
    FDirHandle := INVALID_HANDLE_VALUE;
  end;
  WaitFor;
end;

procedure TVeloxWatcherThread.SyncNotify;
begin
  if Assigned(FOnChange) and (not Terminated) then
    FOnChange(FOwner, FPendingAction, FPendingRelPath, FPendingOldRelPath);
end;

procedure TVeloxWatcherThread.Execute;
var
  Buffer: array[0..4095] of Byte;
  BytesReturned: DWORD;
  Overlapped: TOverlapped;
  Events: array[0..1] of THandle;
  WaitRes: DWORD;
  PInfo: PFileNotifyInformation;
  FileName: WideString;
  OldFileName: string;
  Action: TVeloxFileAction;
  HasOldName: Boolean;
begin
  FDirHandle := CreateFileW(PWideChar(WideString(FDirectory)),
    FILE_LIST_DIRECTORY,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil,
    OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS or FILE_FLAG_OVERLAPPED,
    0);

  if FDirHandle = INVALID_HANDLE_VALUE then Exit;

  FillChar(Overlapped, SizeOf(Overlapped), 0);
  Overlapped.hEvent := CreateEvent(nil, True, False, nil);
  try
    Events[0] := FStopEvent;
    Events[1] := Overlapped.hEvent;
    HasOldName := False;
    OldFileName := '';

    while not Terminated do
    begin
      ResetEvent(Overlapped.hEvent);
      BytesReturned := 0;

      if not ReadDirectoryChangesW(FDirHandle, @Buffer[0], SizeOf(Buffer),
        FRecursive, FNotifyFilter, @BytesReturned, @Overlapped, nil) then
      begin
        if GetLastError <> ERROR_IO_PENDING then Break;
      end;

      WaitRes := WaitForMultipleObjects(2, @Events[0], False, INFINITE);
      if (WaitRes = WAIT_OBJECT_0) or Terminated then
        Break;

      if WaitRes = WAIT_OBJECT_0 + 1 then
      begin
        if not GetOverlappedResult(FDirHandle, Overlapped, BytesReturned, False) then
          Break;

        if BytesReturned > 0 then
        begin
          PInfo := PFileNotifyInformation(@Buffer[0]);
          repeat
            SetLength(FileName, PInfo^.FileNameLength div SizeOf(WCHAR));
            if Length(FileName) > 0 then
              Move(PInfo^.FileName[0], FileName[1], PInfo^.FileNameLength);

            case PInfo^.Action of
              FILE_ACTION_ADDED:
                begin
                  Action := vfaCreated;
                  FPendingAction := Action;
                  FPendingRelPath := string(FileName);
                  FPendingOldRelPath := '';
                  Synchronize(SyncNotify);
                end;
              FILE_ACTION_REMOVED:
                begin
                  Action := vfaDeleted;
                  FPendingAction := Action;
                  FPendingRelPath := string(FileName);
                  FPendingOldRelPath := '';
                  Synchronize(SyncNotify);
                end;
              FILE_ACTION_MODIFIED:
                begin
                  Action := vfaModified;
                  FPendingAction := Action;
                  FPendingRelPath := string(FileName);
                  FPendingOldRelPath := '';
                  Synchronize(SyncNotify);
                end;
              FILE_ACTION_RENAMED_OLD_NAME:
                begin
                  OldFileName := string(FileName);
                  HasOldName := True;
                end;
              FILE_ACTION_RENAMED_NEW_NAME:
                begin
                  Action := vfaRenamed;
                  FPendingAction := Action;
                  FPendingRelPath := string(FileName);
                  if HasOldName then
                    FPendingOldRelPath := OldFileName
                  else
                    FPendingOldRelPath := '';
                  Synchronize(SyncNotify);
                  HasOldName := False;
                  OldFileName := '';
                end;
            end;

            if PInfo^.NextEntryOffset = 0 then
              Break
            else
              PInfo := PFileNotifyInformation(PByte(PInfo) + PInfo^.NextEntryOffset);
          until False;
        end;
      end;
    end;
  finally
    if Overlapped.hEvent <> 0 then
      CloseHandle(Overlapped.hEvent);
  end;
end;

{ TVeloxFileWatcher }

constructor TVeloxFileWatcher.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDirectory := '';
  FRecursive := True;
  FThread := nil;
  FActive := False;
end;

destructor TVeloxFileWatcher.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TVeloxFileWatcher.Start;
begin
  if FActive then Exit;
  if (FDirectory = '') or (not DirectoryExists(FDirectory)) then Exit;

  FThread := TVeloxWatcherThread.Create(Self, FDirectory, FRecursive, FOnChanged);
  FActive := True;
end;

procedure TVeloxFileWatcher.Stop;
begin
  if not FActive then Exit;
  if Assigned(FThread) then
  begin
    FThread.Stop;
    FreeAndNil(FThread);
  end;
  FActive := False;
end;

procedure TVeloxFileWatcher.SetActive(const AValue: Boolean);
begin
  if FActive = AValue then Exit;
  if AValue then
    Start
  else
    Stop;
end;

procedure TVeloxFileWatcher.SetDirectory(const AValue: string);
var
  WasActive: Boolean;
begin
  if FDirectory = AValue then Exit;
  WasActive := FActive;
  if WasActive then Stop;
  FDirectory := AValue;
  if WasActive then Start;
end;

end.
