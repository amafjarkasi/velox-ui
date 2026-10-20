unit Velox.Tabs;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Tabs
  Purpose:
    Edge / Windows Terminal style Fluent tab strip (`TVeloxTabStrip`) drawn
    with GDI+: selected-tab accent, per-tab close button, trailing "+" add
    button, drag-to-reorder, mouse-wheel overflow scrolling, and a testable
    `HitTest`. Wire `OnSelectChange` to show/hide page panels (alternative to
    the `TVeloxAppShell` sidebar router).
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  Controls,
  Velox.Types,
  Velox.GdiPlus;

type
  TVeloxTabHit = (vthNone, vthTab, vthClose, vthAdd);

  TVeloxTabItem = record
    Caption: string;
    Closable: Boolean;
    Tag: Integer;
  end;

  TVeloxTabSelectEvent = procedure(Sender: TObject; const AIndex: Integer) of object;
  TVeloxTabClosingEvent = procedure(Sender: TObject; const AIndex: Integer;
    var ACanClose: Boolean) of object;

  /// <summary>
  /// Fluent tab strip with close, add, reorder and scroll
  /// </summary>
  TVeloxTabStrip = class(TCustomControl)
  private
    FTabs: array of TVeloxTabItem;
    FSelected: Integer;
    FHot: Integer;
    FDragIndex: Integer;
    FScrollX: Integer;
    FShowAdd: Boolean;
    FColors: TVeloxThemeColors;
    FOnSelectChange: TVeloxTabSelectEvent;
    FOnTabClosing: TVeloxTabClosingEvent;
    FOnAddClick: TNotifyEvent;
    procedure SetSelectedIndex(const AValue: Integer);
    function TabWidth(const AIndex: Integer): Integer;
    function TotalWidth: Integer;
    procedure ClampScroll;
    function TruncateCaption(const ACaption: string; const AMaxChars: Integer): string;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor CreateStrip(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth: Integer; const AColors: TVeloxThemeColors;
      const AHeight: Integer = 36);
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    function AddTab(const ACaption: string; const AClosable: Boolean = True;
      const ATag: Integer = 0): Integer;
    procedure RemoveTab(const AIndex: Integer);
    procedure MoveTab(const AFromIndex, AToIndex: Integer);
    function TabCount: Integer;
    function TabCaption(const AIndex: Integer): string;
    function TabTag(const AIndex: Integer): Integer;

    function TabRect(const AIndex: Integer): TRect;
    function CloseRect(const AIndex: Integer): TRect;
    function AddButtonRect: TRect;
    function HitTest(const X, Y: Integer; out AIndex: Integer): TVeloxTabHit;

    property SelectedIndex: Integer read FSelected write SetSelectedIndex;
    property ShowAddButton: Boolean read FShowAdd write FShowAdd;
    property OnSelectChange: TVeloxTabSelectEvent read FOnSelectChange write FOnSelectChange;
    property OnTabClosing: TVeloxTabClosingEvent read FOnTabClosing write FOnTabClosing;
    property OnAddClick: TNotifyEvent read FOnAddClick write FOnAddClick;
  end;

implementation

const
  TAB_MIN_W = 96;
  TAB_MAX_W = 220;
  TAB_GAP = 4;
  TAB_PAD = 6;
  ADD_W = 30;

constructor TVeloxTabStrip.CreateStrip(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth: Integer; const AColors: TVeloxThemeColors;
  const AHeight: Integer);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, AWidth, AHeight);
  FColors := AColors;
  FSelected := -1;
  FHot := -1;
  FDragIndex := -1;
  FScrollX := 0;
  FShowAdd := True;
  SetLength(FTabs, 0);
end;

procedure TVeloxTabStrip.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

function TVeloxTabStrip.TabWidth(const AIndex: Integer): Integer;
begin
  Result := Length(FTabs[AIndex].Caption) * 7 + 44;
  if Result < TAB_MIN_W then Result := TAB_MIN_W;
  if Result > TAB_MAX_W then Result := TAB_MAX_W;
end;

function TVeloxTabStrip.TotalWidth: Integer;
var
  I: Integer;
begin
  Result := TAB_PAD;
  for I := 0 to High(FTabs) do
    Inc(Result, TabWidth(I) + TAB_GAP);
  if FShowAdd then
    Inc(Result, ADD_W + TAB_PAD);
end;

procedure TVeloxTabStrip.ClampScroll;
var
  MaxScroll: Integer;
begin
  MaxScroll := TotalWidth - Width;
  if MaxScroll < 0 then MaxScroll := 0;
  if FScrollX > MaxScroll then FScrollX := MaxScroll;
  if FScrollX < 0 then FScrollX := 0;
end;

function TVeloxTabStrip.TruncateCaption(const ACaption: string; const AMaxChars: Integer): string;
begin
  if (AMaxChars > 3) and (Length(ACaption) > AMaxChars) then
    Result := Copy(ACaption, 1, AMaxChars - 2) + '..'
  else
    Result := ACaption;
end;

function TVeloxTabStrip.TabCount: Integer;
begin
  Result := Length(FTabs);
end;

function TVeloxTabStrip.TabCaption(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex <= High(FTabs)) then
    Result := FTabs[AIndex].Caption
  else
    Result := '';
end;

function TVeloxTabStrip.TabTag(const AIndex: Integer): Integer;
begin
  if (AIndex >= 0) and (AIndex <= High(FTabs)) then
    Result := FTabs[AIndex].Tag
  else
    Result := 0;
end;

function TVeloxTabStrip.TabRect(const AIndex: Integer): TRect;
var
  I, X: Integer;
begin
  X := TAB_PAD - FScrollX;
  for I := 0 to AIndex - 1 do
    Inc(X, TabWidth(I) + TAB_GAP);
  Result := Rect(X, 4, X + TabWidth(AIndex), Height - 4);
end;

function TVeloxTabStrip.CloseRect(const AIndex: Integer): TRect;
var
  R: TRect;
begin
  R := TabRect(AIndex);
  Result := Rect(R.Right - 26, R.Top + ((R.Bottom - R.Top) - 18) div 2,
    R.Right - 8, R.Top + ((R.Bottom - R.Top) - 18) div 2 + 18);
end;

function TVeloxTabStrip.AddButtonRect: TRect;
var
  X: Integer;
begin
  X := TAB_PAD - FScrollX;
  if Length(FTabs) > 0 then
    X := TabRect(High(FTabs)).Right + TAB_GAP
  else
    X := TAB_PAD;
  Result := Rect(X, 4, X + ADD_W, Height - 4);
end;

function TVeloxTabStrip.HitTest(const X, Y: Integer; out AIndex: Integer): TVeloxTabHit;
var
  I: Integer;
  P: TPoint;
  R: TRect;
begin
  AIndex := -1;
  Result := vthNone;
  P := Point(X, Y);
  for I := 0 to High(FTabs) do
  begin
    R := TabRect(I);
    if PtInRect(R, P) then
    begin
      AIndex := I;
      if FTabs[I].Closable and PtInRect(CloseRect(I), P) then
        Result := vthClose
      else
        Result := vthTab;
      Exit;
    end;
  end;
  if FShowAdd and PtInRect(AddButtonRect, P) then
    Result := vthAdd;
end;

function TVeloxTabStrip.AddTab(const ACaption: string; const AClosable: Boolean;
  const ATag: Integer): Integer;
begin
  Result := Length(FTabs);
  SetLength(FTabs, Result + 1);
  FTabs[Result].Caption := ACaption;
  FTabs[Result].Closable := AClosable;
  FTabs[Result].Tag := ATag;
  if FSelected < 0 then
    SetSelectedIndex(Result)
  else
    Invalidate;
end;

procedure TVeloxTabStrip.SetSelectedIndex(const AValue: Integer);
begin
  if (AValue < 0) or (AValue > High(FTabs)) or (AValue = FSelected) then Exit;
  FSelected := AValue;
  Invalidate;
  if Assigned(FOnSelectChange) then
    FOnSelectChange(Self, FSelected);
end;

procedure TVeloxTabStrip.RemoveTab(const AIndex: Integer);
var
  I, OldSel: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FTabs)) then Exit;
  OldSel := FSelected;
  for I := AIndex to High(FTabs) - 1 do
    FTabs[I] := FTabs[I + 1];
  SetLength(FTabs, Length(FTabs) - 1);

  if Length(FTabs) = 0 then
    FSelected := -1
  else if AIndex < FSelected then
    Dec(FSelected)
  else if (AIndex = FSelected) and (FSelected > High(FTabs)) then
    FSelected := High(FTabs);

  ClampScroll;
  Invalidate;
  if (AIndex = OldSel) and (FSelected >= 0) and Assigned(FOnSelectChange) then
    FOnSelectChange(Self, FSelected);
end;

procedure TVeloxTabStrip.MoveTab(const AFromIndex, AToIndex: Integer);
var
  Item: TVeloxTabItem;
  I, NewSel: Integer;
begin
  if (AFromIndex < 0) or (AFromIndex > High(FTabs)) or
     (AToIndex < 0) or (AToIndex > High(FTabs)) or (AFromIndex = AToIndex) then Exit;

  if AFromIndex = FSelected then
    NewSel := AToIndex
  else if (AFromIndex < FSelected) and (AToIndex >= FSelected) then
    NewSel := FSelected - 1
  else if (AFromIndex > FSelected) and (AToIndex <= FSelected) then
    NewSel := FSelected + 1
  else
    NewSel := FSelected;

  Item := FTabs[AFromIndex];
  if AFromIndex < AToIndex then
    for I := AFromIndex to AToIndex - 1 do
      FTabs[I] := FTabs[I + 1]
  else
    for I := AFromIndex downto AToIndex + 1 do
      FTabs[I] := FTabs[I - 1];
  FTabs[AToIndex] := Item;
  FSelected := NewSel;
  Invalidate;
end;

procedure TVeloxTabStrip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
  Hit: TVeloxTabHit;
  CanClose: Boolean;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  Hit := HitTest(X, Y, Idx);
  case Hit of
    vthClose:
      begin
        CanClose := True;
        if Assigned(FOnTabClosing) then
          FOnTabClosing(Self, Idx, CanClose);
        if CanClose then
          RemoveTab(Idx);
      end;
    vthTab:
      begin
        SetSelectedIndex(Idx);
        FDragIndex := Idx;
      end;
    vthAdd:
      if Assigned(FOnAddClick) then
        FOnAddClick(Self);
  end;
end;

procedure TVeloxTabStrip.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Idx, NewHot: Integer;
  Hit: TVeloxTabHit;
begin
  inherited MouseMove(Shift, X, Y);
  Hit := HitTest(X, Y, Idx);
  if Hit in [vthTab, vthClose] then NewHot := Idx else NewHot := -1;
  if (FDragIndex >= 0) and (ssLeft in Shift) and (Hit in [vthTab, vthClose]) and
     (Idx <> FDragIndex) then
  begin
    MoveTab(FDragIndex, Idx);
    FDragIndex := Idx;
  end;
  if NewHot <> FHot then
  begin
    FHot := NewHot;
    Invalidate;
  end;
end;

procedure TVeloxTabStrip.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragIndex := -1;
end;

procedure TVeloxTabStrip.MouseLeave;
begin
  inherited MouseLeave;
  if FHot <> -1 then
  begin
    FHot := -1;
    Invalidate;
  end;
end;

function TVeloxTabStrip.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  FScrollX := FScrollX - (WheelDelta div 2);
  ClampScroll;
  Invalidate;
  Result := True;
end;

procedure TVeloxTabStrip.Paint;
var
  I, TW, TH: Integer;
  R, CR, AR: TRect;
  Fill, Bord, TextCol: TColor;
  Cap: string;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FColors.Surface;
  Canvas.FillRect(Rect(0, 0, Width, Height));
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;

  for I := 0 to High(FTabs) do
  begin
    R := TabRect(I);
    if (R.Right < 0) or (R.Left > Width) then Continue;

    if I = FSelected then
    begin
      Fill := TVeloxUtils.BlendColor(FColors.SurfaceCard, FColors.Accent, 0.20);
      Bord := FColors.Accent;
      TextCol := FColors.TextPrimary;
      Canvas.Font.Style := [fsBold];
    end
    else
    begin
      if I = FHot then Fill := FColors.SurfaceHover else Fill := FColors.SurfaceCard;
      Bord := FColors.Border;
      TextCol := FColors.TextSecondary;
      Canvas.Font.Style := [];
    end;
    TVeloxGdiPlus.DrawCard(Canvas, R, Fill, Bord, 8);

    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := TextCol;
    if FTabs[I].Closable then
      Cap := TruncateCaption(FTabs[I].Caption, (R.Right - R.Left - 44) div 7)
    else
      Cap := TruncateCaption(FTabs[I].Caption, (R.Right - R.Left - 24) div 7);
    TH := Canvas.TextHeight(Cap);
    Canvas.TextOut(R.Left + 12, R.Top + ((R.Bottom - R.Top) - TH) div 2, Cap);

    if FTabs[I].Closable then
    begin
      CR := CloseRect(I);
      Canvas.Font.Style := [];
      Canvas.Font.Color := FColors.TextSecondary;
      TW := Canvas.TextWidth('x');
      TH := Canvas.TextHeight('x');
      Canvas.TextOut(CR.Left + ((CR.Right - CR.Left) - TW) div 2,
        CR.Top + ((CR.Bottom - CR.Top) - TH) div 2, 'x');
    end;
  end;

  if FShowAdd then
  begin
    AR := AddButtonRect;
    TVeloxGdiPlus.DrawCard(Canvas, AR, FColors.SurfaceCard, FColors.Border, 8);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Size := 11;
    Canvas.Font.Color := FColors.Accent;
    TW := Canvas.TextWidth('+');
    TH := Canvas.TextHeight('+');
    Canvas.TextOut(AR.Left + ((AR.Right - AR.Left) - TW) div 2,
      AR.Top + ((AR.Bottom - AR.Top) - TH) div 2, '+');
  end;
end;

end.
