unit Velox.Clipboard;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Forms;

type
  TVeloxClipboardEvent = procedure(Sender: TObject; const ANewText: string) of object;

  TVeloxClipboardWatcher = class(TComponent)
  private
    FListenerHwnd: HWND;
    FActive: Boolean;
    FMaxHistory: Integer;
    FHistory: TStringList;
    FOnChange: TVeloxClipboardEvent;
    procedure SetActive(const Value: Boolean);
    procedure StartListening;
    procedure StopListening;
    procedure HandleClipboardUpdate;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ClearHistory;
    property History: TStringList read FHistory;
  published
    property Active: Boolean read FActive write SetActive default False;
    property MaxHistory: Integer read FMaxHistory write FMaxHistory default 20;
    property OnChange: TVeloxClipboardEvent read FOnChange write FOnChange;
  end;

  TVeloxClipboard = class
  public
    class function SetText(const AText: string): Boolean; static;
    class function GetText: string; static;
    class function HasText: Boolean; static;
    class procedure Clear; static;
  end;

implementation

const
  WM_CLIPBOARDUPDATE = $031D;
  HWND_MESSAGE = HWND(-3);

function AddClipboardFormatListener(hwnd: HWND): BOOL;
  stdcall; external 'user32.dll' name 'AddClipboardFormatListener';

function RemoveClipboardFormatListener(hwnd: HWND): BOOL;
  stdcall; external 'user32.dll' name 'RemoveClipboardFormatListener';

function ClipboardWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  Watcher: TVeloxClipboardWatcher;
begin
  if uMsg = WM_CLIPBOARDUPDATE then
  begin
    Watcher := TVeloxClipboardWatcher(GetWindowLongPtr(hWnd, GWLP_USERDATA));
    if Assigned(Watcher) then
      Watcher.HandleClipboardUpdate;
    Exit(0);
  end;
  Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
end;

{ TVeloxClipboard }

class function TVeloxClipboard.SetText(const AText: string): Boolean;
var
  hMem: HGLOBAL;
  P: PWideChar;
  W: WideString;
  Bytes: Integer;
begin
  Result := False;
  if not OpenClipboard(0) then Exit;
  try
    EmptyClipboard;
    W := WideString(AText);
    Bytes := (Length(W) + 1) * SizeOf(WideChar);
    hMem := GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE, Bytes);
    if hMem <> 0 then
    begin
      P := GlobalLock(hMem);
      if P <> nil then
      begin
        Move(PWideChar(W)^, P^, Bytes);
        GlobalUnlock(hMem);
        Result := (SetClipboardData(CF_UNICODETEXT, hMem) <> 0);
      end
      else
        GlobalFree(hMem);
    end;
  finally
    CloseClipboard;
  end;
end;

class function TVeloxClipboard.GetText: string;
var
  hMem: HGLOBAL;
  P: PWideChar;
begin
  Result := '';
  if not OpenClipboard(0) then Exit;
  try
    hMem := GetClipboardData(CF_UNICODETEXT);
    if hMem <> 0 then
    begin
      P := GlobalLock(hMem);
      if P <> nil then
      begin
        Result := string(WideString(P));
        GlobalUnlock(hMem);
      end;
    end;
  finally
    CloseClipboard;
  end;
end;

class function TVeloxClipboard.HasText: Boolean;
begin
  Result := IsClipboardFormatAvailable(CF_UNICODETEXT) or
            IsClipboardFormatAvailable(CF_TEXT);
end;

class procedure TVeloxClipboard.Clear;
begin
  if OpenClipboard(0) then
  begin
    EmptyClipboard;
    CloseClipboard;
  end;
end;

{ TVeloxClipboardWatcher }

constructor TVeloxClipboardWatcher.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FActive := False;
  FMaxHistory := 20;
  FListenerHwnd := 0;
  FHistory := TStringList.Create;
end;

destructor TVeloxClipboardWatcher.Destroy;
begin
  StopListening;
  FHistory.Free;
  inherited Destroy;
end;

procedure TVeloxClipboardWatcher.ClearHistory;
begin
  FHistory.Clear;
end;

procedure TVeloxClipboardWatcher.SetActive(const Value: Boolean);
begin
  if FActive <> Value then
  begin
    FActive := Value;
    if FActive then
      StartListening
    else
      StopListening;
  end;
end;

procedure TVeloxClipboardWatcher.StartListening;
var
  WC: WNDCLASSW;
const
  CLS_NAME: UnicodeString = 'VeloxClipboardListener';
begin
  if FListenerHwnd <> 0 then Exit;

  FillChar(WC, SizeOf(WC), 0);
  WC.lpfnWndProc := @ClipboardWndProc;
  WC.hInstance := HInstance;
  WC.lpszClassName := PWideChar(CLS_NAME);
  RegisterClassW(WC);

  FListenerHwnd := CreateWindowExW(0, PWideChar(CLS_NAME), nil, 0,
    0, 0, 0, 0, HWND_MESSAGE, 0, HInstance, nil);

  if FListenerHwnd <> 0 then
  begin
    SetWindowLongPtr(FListenerHwnd, GWLP_USERDATA, LONG_PTR(Self));
    AddClipboardFormatListener(FListenerHwnd);
  end;
end;

procedure TVeloxClipboardWatcher.StopListening;
begin
  if FListenerHwnd <> 0 then
  begin
    RemoveClipboardFormatListener(FListenerHwnd);
    DestroyWindow(FListenerHwnd);
    FListenerHwnd := 0;
  end;
end;

procedure TVeloxClipboardWatcher.HandleClipboardUpdate;
var
  Txt: string;
  Idx: Integer;
begin
  if not TVeloxClipboard.HasText then Exit;
  Txt := TVeloxClipboard.GetText;
  if Txt = '' then Exit;

  // Deduplicate
  Idx := FHistory.IndexOf(Txt);
  if Idx >= 0 then
    FHistory.Delete(Idx);

  FHistory.Insert(0, Txt);
  while FHistory.Count > FMaxHistory do
    FHistory.Delete(FHistory.Count - 1);

  if Assigned(FOnChange) then
    FOnChange(Self, Txt);
end;

end.
