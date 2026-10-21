unit Velox.ClipboardPalette;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.ClipboardPalette (#68)
  Purpose:
    Composite Windows 11 Win+V Clipboard History Palette combining:
      - TVeloxClipboard & TVeloxClipboardWatcher (AddClipboardFormatListener)
      - TVeloxSearchBox (Fuzzy search & instant filtering)
      - TVeloxMru (Deduplication, pinning & JSON persistence)
      - Live custom cards list with pin toggle and click-to-copy
==============================================================================}

interface

uses
  Windows,
  Types,
  {$IFDEF FPC}
  LCLType,
  {$ENDIF}
  SysUtils,
  Classes,
  Controls,
  Graphics,
  Forms,
  StdCtrls,
  ExtCtrls,
  Velox.Types,
  Velox.GdiPlus,
  Velox.Clipboard,
  Velox.Controls,
  Velox.Mru;

type
  TVeloxClipCategory = (vccAll, vccText, vccCode, vccUrls, vccPinned);

  TVeloxClipSelectEvent = procedure(Sender: TObject; const AText: string) of object;

  TVeloxClipboardPalette = class(TCustomControl)
  private
    FWatcher: TVeloxClipboardWatcher;
    FMru: TVeloxMru;
    FTopPanel: TPanel;
    FSearchBox: TVeloxSearchBox;
    FListBox: TListBox;
    FColors: TVeloxThemeColors;
    FFilterCategory: TVeloxClipCategory;
    FOnSelectClip: TVeloxClipSelectEvent;
    procedure HandleClipboardChange(Sender: TObject; const ANewText: string);
    procedure HandleSearchChange(Sender: TObject);
    procedure HandleListClick(Sender: TObject);
    procedure HandleDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    function ClassifyClip(const AText: string): TVeloxClipCategory;
    function GetItemCount: Integer;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure RefreshList;
    procedure AddClip(const AText: string; const APinned: Boolean = False);
    procedure Clear;
    function SelectedText: string;

    property Mru: TVeloxMru read FMru;
    property FilterCategory: TVeloxClipCategory read FFilterCategory write FFilterCategory;
    property ItemCount: Integer read GetItemCount;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
    property OnSelectClip: TVeloxClipSelectEvent read FOnSelectClip write FOnSelectClip;
  end;

implementation

constructor TVeloxClipboardPalette.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 340;
  Height := 460;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FFilterCategory := vccAll;

  FMru := TVeloxMru.Create(Self);
  FMru.MaxItems := 50;

  // 1. Top Panel with Search Box
  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := Self;
  FTopPanel.Align := alTop;
  FTopPanel.Height := 46;
  FTopPanel.BevelOuter := bvNone;
  FTopPanel.Color := FColors.Surface;

  FSearchBox := TVeloxSearchBox.CreateBox(Self, FTopPanel, 10, 8, Width - 20, 30,
    'Search clipboard history...', FColors, HandleSearchChange);

  // 2. Owner-Drawn ListBox for clips
  FListBox := TListBox.Create(Self);
  FListBox.Parent := Self;
  FListBox.Align := alClient;
  FListBox.Style := lbOwnerDrawFixed;
  FListBox.ItemHeight := 48;
  FListBox.BorderStyle := bsNone;
  FListBox.Color := FColors.Background;
  FListBox.OnDrawItem := HandleDrawItem;
  FListBox.OnClick := HandleListClick;

  // 3. Modern Clipboard Listener
  FWatcher := TVeloxClipboardWatcher.Create(Self);
  FWatcher.OnChange := HandleClipboardChange;
  FWatcher.Active := True;

  ApplyColors(FColors);
end;

destructor TVeloxClipboardPalette.Destroy;
begin
  FWatcher.Active := False;
  inherited Destroy;
end;

procedure TVeloxClipboardPalette.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  if Assigned(FTopPanel) then FTopPanel.Color := FColors.Surface;
  if Assigned(FSearchBox) then FSearchBox.ApplyColors(FColors);
  if Assigned(FListBox) then FListBox.Color := FColors.Background;
  Invalidate;
end;

function TVeloxClipboardPalette.ClassifyClip(const AText: string): TVeloxClipCategory;
var
  Trimmed: string;
begin
  Trimmed := Trim(AText);
  if (Pos('http://', Trimmed) = 1) or (Pos('https://', Trimmed) = 1) then
    Exit(vccUrls);
  if (Pos('{', Trimmed) > 0) or (Pos('begin', Trimmed) > 0) or
     (Pos('function', Trimmed) > 0) or (Pos('class', Trimmed) > 0) or
     (Pos('select', LowerCase(Trimmed)) = 1) then
    Exit(vccCode);
  Result := vccText;
end;

procedure TVeloxClipboardPalette.HandleClipboardChange(Sender: TObject; const ANewText: string);
begin
  if ANewText <> '' then
    AddClip(ANewText);
end;

procedure TVeloxClipboardPalette.AddClip(const AText: string; const APinned: Boolean);
var
  Idx: Integer;
begin
  FMru.Add(AText);
  if APinned and (FMru.Count > 0) then
  begin
    Idx := 0;
    FMru.Pin(Idx);
  end;
  RefreshList;
end;

procedure TVeloxClipboardPalette.Clear;
begin
  FMru.Clear;
  RefreshList;
end;

function TVeloxClipboardPalette.SelectedText: string;
begin
  Result := '';
  if (FListBox.ItemIndex >= 0) and (FListBox.ItemIndex < FListBox.Items.Count) then
    Result := FListBox.Items[FListBox.ItemIndex];
end;

function TVeloxClipboardPalette.GetItemCount: Integer;
begin
  Result := FMru.Count;
end;

procedure TVeloxClipboardPalette.HandleSearchChange(Sender: TObject);
begin
  RefreshList;
end;

procedure TVeloxClipboardPalette.RefreshList;
var
  I: Integer;
  Query, ItemTxt: string;
  Match: Boolean;
  Cat: TVeloxClipCategory;
begin
  FListBox.Items.BeginUpdate;
  try
    FListBox.Items.Clear;
    Query := LowerCase(Trim(FSearchBox.Text));

    for I := 0 to FMru.Count - 1 do
    begin
      ItemTxt := FMru.ItemPath(I);
      Cat := ClassifyClip(ItemTxt);

      Match := True;
      if (FFilterCategory = vccPinned) and (not FMru.IsPinned(I)) then
        Match := False
      else if (FFilterCategory = vccCode) and (Cat <> vccCode) then
        Match := False
      else if (FFilterCategory = vccUrls) and (Cat <> vccUrls) then
        Match := False;

      if Match and (Query <> '') and (Pos(Query, LowerCase(ItemTxt)) = 0) then
        Match := False;

      if Match then
        FListBox.Items.Add(ItemTxt);
    end;
  finally
    FListBox.Items.EndUpdate;
  end;
end;

procedure TVeloxClipboardPalette.HandleListClick(Sender: TObject);
var
  Sel: string;
begin
  Sel := SelectedText;
  if (Sel <> '') and Assigned(FOnSelectClip) then
    FOnSelectClip(Self, Sel);
end;

procedure TVeloxClipboardPalette.HandleDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  ItemStr, DisplayStr: string;
  CardR, TextR: TRect;
  BgColor: TColor;
begin
  C := FListBox.Canvas;
  if (Index < 0) or (Index >= FListBox.Items.Count) then Exit;
  ItemStr := FListBox.Items[Index];

  // Card bounds with 4px margin
  CardR := ARect;
  InflateRect(CardR, -4, -3);

  if odSelected in State then
    BgColor := FColors.SurfaceHover
  else
    BgColor := FColors.SurfaceCard;

  TVeloxGdiPlus.DrawCard(C, CardR, BgColor, FColors.Border, 6);

  // Single-line sanitized preview
  DisplayStr := StringReplace(ItemStr, #13#10, ' ', [rfReplaceAll]);
  DisplayStr := StringReplace(DisplayStr, #10, ' ', [rfReplaceAll]);
  DisplayStr := StringReplace(DisplayStr, #13, ' ', [rfReplaceAll]);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 9;
  if odSelected in State then
    C.Font.Color := FColors.Accent
  else
    C.Font.Color := FColors.TextPrimary;

  TextR := Rect(CardR.Left + 10, CardR.Top + 4, CardR.Right - 10, CardR.Bottom - 4);
  DrawText(C.Handle, PChar(DisplayStr), Length(DisplayStr), TextR,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_END_ELLIPSIS or DT_NOPREFIX);
end;

procedure TVeloxClipboardPalette.Paint;
begin
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);
end;

procedure TVeloxClipboardPalette.Resize;
begin
  inherited Resize;
  if Assigned(FSearchBox) and Assigned(FSearchBox.Container) then
    FSearchBox.Container.Width := Width - 20;
end;

end.
