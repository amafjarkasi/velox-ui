unit Velox.DragDrop;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.DragDrop
  Purpose:
    Lightweight, zero-dependency Win32 shell drag-and-drop file target (`TVeloxDropTarget`)
    inspired by `landrix/The-Drag-and-Drop-Component-Suite-for-Delphi` and `SynEdit`.
    Eliminates heavyweight OLE/COM IDropTarget boilerplate by wrapping Win32
    `shell32.dll` (`DragAcceptFiles`, `DragQueryFileW`, `DragFinish`, `WM_DROPFILES`)
    and clean window subclassing.
    Register any `TWinControl` with 1 line of code.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Controls,
  Forms;

type
  TVeloxDropFilesEvent = procedure(Sender: TObject; const AFiles: TStrings) of object;

  /// <summary>
  /// Attached drop target descriptor
  /// </summary>
  TVeloxDropTarget = class(TComponent)
  private
    FControl: TWinControl;
    FPrevWndProc: Pointer;
    FNewWndProc: Pointer;
    FOnDropFiles: TVeloxDropFilesEvent;
    procedure Attach;
    procedure Detach;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>Attaches a shell file-drop listener to any TWinControl.</summary>
    class function Register(const AControl: TWinControl;
      const AOnDrop: TVeloxDropFilesEvent): TVeloxDropTarget; static;

    /// <summary>Detaches the drop target from the control.</summary>
    class procedure Unregister(const AControl: TWinControl); static;

    property Control: TWinControl read FControl;
    property OnDropFiles: TVeloxDropFilesEvent read FOnDropFiles write FOnDropFiles;
  end;

implementation

const
  WM_DROPFILES = $0233;

var
  GDropTargets: TList = nil;

function DragQueryFileW(hDrop: THandle; iFile: UINT; lpszFile: PWideChar; cch: UINT): UINT; stdcall;
  external 'shell32.dll' name 'DragQueryFileW';
procedure DragFinish(hDrop: THandle); stdcall;
  external 'shell32.dll' name 'DragFinish';
procedure DragAcceptFiles(hWnd: HWND; fAccept: BOOL); stdcall;
  external 'shell32.dll' name 'DragAcceptFiles';

function SubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  Target: TVeloxDropTarget;
  I, Count, Len: Integer;
  hDrop: THandle;
  Buffer: array[0..MAX_PATH + 1] of WCHAR;
  FileList: TStringList;
  PrevProc: Pointer;
begin
  Target := nil;
  if Assigned(GDropTargets) then
  begin
    for I := 0 to GDropTargets.Count - 1 do
    begin
      if (TVeloxDropTarget(GDropTargets[I]).Control <> nil) and
         (TVeloxDropTarget(GDropTargets[I]).Control.Handle = hWnd) then
      begin
        Target := TVeloxDropTarget(GDropTargets[I]);
        Break;
      end;
    end;
  end;

  if (Target <> nil) and (uMsg = WM_DROPFILES) then
  begin
    hDrop := THandle(wParam);
    Count := DragQueryFileW(hDrop, $FFFFFFFF, nil, 0);
    if (Count > 0) and Assigned(Target.FOnDropFiles) then
    begin
      FileList := TStringList.Create;
      try
        for I := 0 to Count - 1 do
        begin
          Len := DragQueryFileW(hDrop, I, @Buffer[0], MAX_PATH);
          if Len > 0 then
            FileList.Add(string(WideString(Buffer)));
        end;
        Target.FOnDropFiles(Target.FControl, FileList);
      finally
        FileList.Free;
      end;
    end;
    DragFinish(hDrop);
    Result := 0;
    Exit;
  end;

  if Target <> nil then
    PrevProc := Target.FPrevWndProc
  else
    PrevProc := Pointer(GetWindowLongPtrW(hWnd, GWLP_WNDPROC));

  Result := CallWindowProcW(PrevProc, hWnd, uMsg, wParam, lParam);
end;

{ TVeloxDropTarget }

constructor TVeloxDropTarget.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FControl := nil;
  FPrevWndProc := nil;
  FNewWndProc := @SubclassProc;
  FOnDropFiles := nil;
  if GDropTargets = nil then
    GDropTargets := TList.Create;
  GDropTargets.Add(Self);
end;

destructor TVeloxDropTarget.Destroy;
begin
  Detach;
  if Assigned(GDropTargets) then
    GDropTargets.Remove(Self);
  inherited Destroy;
end;

procedure TVeloxDropTarget.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FControl) then
  begin
    Detach;
    FControl := nil;
  end;
end;

procedure TVeloxDropTarget.Attach;
begin
  if (FControl = nil) or (not FControl.HandleAllocated) then Exit;
  DragAcceptFiles(FControl.Handle, True);
  FPrevWndProc := Pointer(SetWindowLongPtrW(FControl.Handle, GWLP_WNDPROC, LONG_PTR(FNewWndProc)));
end;

procedure TVeloxDropTarget.Detach;
begin
  if (FControl <> nil) and FControl.HandleAllocated and (FPrevWndProc <> nil) then
  begin
    SetWindowLongPtrW(FControl.Handle, GWLP_WNDPROC, LONG_PTR(FPrevWndProc));
    DragAcceptFiles(FControl.Handle, False);
    FPrevWndProc := nil;
  end;
end;

class function TVeloxDropTarget.Register(const AControl: TWinControl;
  const AOnDrop: TVeloxDropFilesEvent): TVeloxDropTarget;
begin
  Result := nil;
  if AControl = nil then Exit;
  Unregister(AControl);
  Result := TVeloxDropTarget.Create(AControl);
  Result.FControl := AControl;
  Result.FOnDropFiles := AOnDrop;
  Result.Attach;
end;

class procedure TVeloxDropTarget.Unregister(const AControl: TWinControl);
var
  I: Integer;
  Target: TVeloxDropTarget;
begin
  if (AControl = nil) or (GDropTargets = nil) then Exit;
  for I := GDropTargets.Count - 1 downto 0 do
  begin
    Target := TVeloxDropTarget(GDropTargets[I]);
    if Target.Control = AControl then
    begin
      Target.Free;
      Break;
    end;
  end;
end;

initialization

finalization
  if Assigned(GDropTargets) then
    FreeAndNil(GDropTargets);

end.
