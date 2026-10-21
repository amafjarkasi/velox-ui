unit Velox.Breadcrumb;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Breadcrumb
  Purpose:
    Windows 11 Explorer-style breadcrumb path navigation control (`TVeloxBreadcrumb`).
    Renders clickable path segments separated by subtle chevrons (`›` or `/`),
    hover states, active leaf styling, and testable `HitTest`.
    Eliminates deep menu diving in hierarchical dashboards and file viewers.
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
  TVeloxBreadcrumbItem = record
    Caption: string;
    Key: string;
    Tag: Integer;
  end;

  TVeloxSegmentClickEvent = procedure(Sender: TObject; const AIndex: Integer;
    const AKey: string) of object;

  /// <summary>
  /// Windows 11 Fluent Breadcrumb Navigation Control
  /// </summary>
  TVeloxBreadcrumb = class(TCustomControl)
  private
    FItems: array of TVeloxBreadcrumbItem;
    FColors: TVeloxThemeColors;
    FHotIndex: Integer;
    FSeparator: string;
    FOnSegmentClick: TVeloxSegmentClickEvent;
    function ItemWidth(const AIndex: Integer): Integer;
    function SeparatorWidth: Integer;
    function SegmentRect(const AIndex: Integer): TRect;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor CreateBreadcrumb(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth: Integer; const AColors: TVeloxThemeColors;
      const AHeight: Integer = 32);
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    function AddSegment(const ACaption: string; const AKey: string = '';
      const ATag: Integer = 0): Integer;
    procedure SetPath(const ASegments: array of string);
    procedure Clear;
    function Count: Integer;
    function SegmentCaption(const AIndex: Integer): string;
    function SegmentKey(const AIndex: Integer): string;

    /// <summary>Tests coordinates against segments. Returns -1 if no segment hit.</summary>
    function HitTest(const X, Y: Integer): Integer;

    property Separator: string read FSeparator write FSeparator;
    property OnSegmentClick: TVeloxSegmentClickEvent read FOnSegmentClick write FOnSegmentClick;
  end;

implementation

const
  DEFAULT_SEP = '›';
  PAD_X = 8;
  ITEM_PAD_X = 8;

constructor TVeloxBreadcrumb.CreateBreadcrumb(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth: Integer; const AColors: TVeloxThemeColors;
  const AHeight: Integer);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, AWidth, AHeight);
  FColors := AColors;
  FHotIndex := -1;
  FSeparator := DEFAULT_SEP;
  SetLength(FItems, 0);
end;

procedure TVeloxBreadcrumb.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

function TVeloxBreadcrumb.Count: Integer;
begin
  Result := Length(FItems);
end;

function TVeloxBreadcrumb.SegmentCaption(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex <= High(FItems)) then
    Result := FItems[AIndex].Caption
  else
    Result := '';
end;

function TVeloxBreadcrumb.SegmentKey(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex <= High(FItems)) then
    Result := FItems[AIndex].Key
  else
    Result := '';
end;

function TVeloxBreadcrumb.SeparatorWidth: Integer;
begin
  if HandleAllocated then
  begin
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Size := 9;
    Result := Canvas.TextWidth(FSeparator) + 12;
  end
  else
    Result := Length(FSeparator) * 7 + 12;
end;

function TVeloxBreadcrumb.ItemWidth(const AIndex: Integer): Integer;
begin
  if (AIndex < 0) or (AIndex > High(FItems)) then
    Result := 0
  else if HandleAllocated then
  begin
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Size := 9;
    if AIndex = High(FItems) then
      Canvas.Font.Style := [fsBold]
    else
      Canvas.Font.Style := [];
    Result := Canvas.TextWidth(FItems[AIndex].Caption) + (ITEM_PAD_X * 2);
  end
  else
    Result := Length(FItems[AIndex].Caption) * 7 + (ITEM_PAD_X * 2);

  if Result < 20 then
    Result := 20;
end;

function TVeloxBreadcrumb.SegmentRect(const AIndex: Integer): TRect;
var
  I, CurX, IW, SW: Integer;
begin
  CurX := PAD_X;
  SW := SeparatorWidth;
  for I := 0 to AIndex - 1 do
  begin
    Inc(CurX, ItemWidth(I));
    Inc(CurX, SW);
  end;
  IW := ItemWidth(AIndex);
  Result := Rect(CurX, 4, CurX + IW, Height - 4);
end;

function TVeloxBreadcrumb.HitTest(const X, Y: Integer): Integer;
var
  I: Integer;
  R: TRect;
  P: TPoint;
begin
  Result := -1;
  P := Point(X, Y);
  for I := 0 to High(FItems) do
  begin
    R := SegmentRect(I);
    if PtInRect(R, P) then
      Exit(I);
  end;
end;

function TVeloxBreadcrumb.AddSegment(const ACaption, AKey: string;
  const ATag: Integer): Integer;
begin
  Result := Length(FItems);
  SetLength(FItems, Result + 1);
  FItems[Result].Caption := ACaption;
  if AKey <> '' then
    FItems[Result].Key := AKey
  else
    FItems[Result].Key := ACaption;
  FItems[Result].Tag := ATag;
  Invalidate;
end;

procedure TVeloxBreadcrumb.SetPath(const ASegments: array of string);
var
  I: Integer;
begin
  SetLength(FItems, Length(ASegments));
  for I := 0 to High(ASegments) do
  begin
    FItems[I].Caption := ASegments[I];
    FItems[I].Key := ASegments[I];
    FItems[I].Tag := I;
  end;
  Invalidate;
end;

procedure TVeloxBreadcrumb.Clear;
begin
  SetLength(FItems, 0);
  FHotIndex := -1;
  Invalidate;
end;

procedure TVeloxBreadcrumb.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewHot: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  NewHot := HitTest(X, Y);
  if NewHot <> FHotIndex then
  begin
    FHotIndex := NewHot;
    if FHotIndex >= 0 then
      Cursor := crHandPoint
    else
      Cursor := crDefault;
    Invalidate;
  end;
end;

procedure TVeloxBreadcrumb.MouseLeave;
begin
  inherited MouseLeave;
  if FHotIndex <> -1 then
  begin
    FHotIndex := -1;
    Cursor := crDefault;
    Invalidate;
  end;
end;

procedure TVeloxBreadcrumb.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    Idx := HitTest(X, Y);
    if (Idx >= 0) and Assigned(FOnSegmentClick) then
      FOnSegmentClick(Self, Idx, FItems[Idx].Key);
  end;
end;

procedure TVeloxBreadcrumb.Paint;
var
  I, SW: Integer;
  R, SepR, TextR: TRect;
  FillCol, TextCol: TColor;
  Cap: string;
begin
  Canvas.Brush.Style := bsSolid;
  if Assigned(Parent) then
    Canvas.Brush.Color := Parent.Color
  else
    Canvas.Brush.Color := FColors.Surface;
  Canvas.FillRect(Rect(0, 0, Width, Height));

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  SW := SeparatorWidth;

  for I := 0 to High(FItems) do
  begin
    R := SegmentRect(I);
    if (R.Right < 0) or (R.Left > Width) then Continue;

    if I = FHotIndex then
    begin
      FillCol := FColors.SurfaceHover;
      TVeloxGdiPlus.DrawCard(Canvas, R, FillCol, FColors.Border, 4);
    end;

    Canvas.Brush.Style := bsClear;
    if I = High(FItems) then
    begin
      Canvas.Font.Style := [fsBold];
      TextCol := FColors.TextPrimary;
    end
    else
    begin
      Canvas.Font.Style := [];
      TextCol := FColors.TextSecondary;
    end;
    Canvas.Font.Color := TextCol;

    Cap := FItems[I].Caption;
    TextR := R;
    DrawText(Canvas.Handle, PChar(Cap), Length(Cap), TextR,
      DT_SINGLELINE or DT_VCENTER or DT_CENTER or DT_NOPREFIX);

    // Separator
    if I < High(FItems) then
    begin
      SepR := Rect(R.Right, 4, R.Right + SW, Height - 4);
      Canvas.Font.Style := [];
      Canvas.Font.Color := FColors.Border;
      DrawText(Canvas.Handle, PChar(FSeparator), Length(FSeparator), SepR,
        DT_SINGLELINE or DT_VCENTER or DT_CENTER or DT_NOPREFIX);
    end;
  end;
end;

end.
