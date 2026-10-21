unit Velox.Timeline;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Controls, Graphics, Forms, Types,
  Velox.Types;

type
  TVeloxTimelineItem = record
    TimestampStr: string;
    Title: string;
    Description: string;
    Severity: TVeloxSeverity;
  end;

  TVeloxTimeline = class(TCustomControl)
  private
    FItems: array of TVeloxTimelineItem;
    FColors: TVeloxThemeColors;
    FItemHeight: Integer;
    FScrollY: Integer;
    FTimeColWidth: Integer;
    procedure SetItemHeight(const Value: Integer);
    function TotalHeight: Integer;
    procedure ClampScroll;
  protected
    procedure Paint; override;
    procedure Resize; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    function AddItem(const ATimestamp, ATitle: string; const ADescription: string = '';
      const ASeverity: TVeloxSeverity = vsNormal): Integer;
    procedure Clear;
    function Count: Integer;
  published
    property Align;
    property Anchors;
    property ItemHeight: Integer read FItemHeight write SetItemHeight default 52;
    property TimeColWidth: Integer read FTimeColWidth write FTimeColWidth default 70;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxTimeline.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 400;
  Height := 300;
  FItemHeight := 52;
  FTimeColWidth := 70;
  FScrollY := 0;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  SetLength(FItems, 0);
end;

procedure TVeloxTimeline.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxTimeline.SetItemHeight(const Value: Integer);
begin
  if (FItemHeight <> Value) and (Value >= 36) then
  begin
    FItemHeight := Value;
    Invalidate;
  end;
end;

procedure TVeloxTimeline.Clear;
begin
  SetLength(FItems, 0);
  FScrollY := 0;
  Invalidate;
end;

function TVeloxTimeline.Count: Integer;
begin
  Result := Length(FItems);
end;

function TVeloxTimeline.AddItem(const ATimestamp, ATitle, ADescription: string;
  const ASeverity: TVeloxSeverity): Integer;
var
  L: Integer;
begin
  L := Length(FItems);
  SetLength(FItems, L + 1);
  FItems[L].TimestampStr := ATimestamp;
  FItems[L].Title        := ATitle;
  FItems[L].Description  := ADescription;
  FItems[L].Severity     := ASeverity;
  Invalidate;
  Result := L;
end;

function TVeloxTimeline.TotalHeight: Integer;
begin
  Result := Length(FItems) * FItemHeight;
end;

procedure TVeloxTimeline.ClampScroll;
var
  MaxScroll: Integer;
begin
  MaxScroll := TotalHeight - Height;
  if MaxScroll < 0 then MaxScroll := 0;
  if FScrollY > MaxScroll then FScrollY := MaxScroll;
  if FScrollY < 0 then FScrollY := 0;
end;

function TVeloxTimeline.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  Inc(FScrollY, -(WheelDelta div 120) * (FItemHeight * 2));
  ClampScroll;
  Invalidate;
end;

procedure TVeloxTimeline.Resize;
begin
  inherited Resize;
  ClampScroll;
  Invalidate;
end;

procedure TVeloxTimeline.Paint;
var
  I, Y, DotX, DotY, DotR: Integer;
  NodeCol: TColor;
  TimeR, TitleR, DescR, LocalR: TRect;
begin
  // Background
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);

  if Length(FItems) = 0 then Exit;

  DotX := FTimeColWidth + 14;
  DotR := 5;

  // 1. Vertical timeline continuous track line
  Canvas.Pen.Color := FColors.Border;
  Canvas.Pen.Width := 2;
  Canvas.MoveTo(DotX, 0);
  Canvas.LineTo(DotX, Height);

  Canvas.Font.Name := 'Segoe UI';

  // 2. Timeline nodes
  for I := 0 to High(FItems) do
  begin
    Y := (I * FItemHeight) - FScrollY;
    if (Y + FItemHeight < 0) or (Y > Height) then
      Continue;

    DotY := Y + (FItemHeight div 2);

    case FItems[I].Severity of
      vsWarning:  NodeCol := $F59E0B; // Amber
      vsCritical: NodeCol := $EF4444; // Red
    else
      NodeCol := FColors.Accent;      // Sky blue / Green
    end;

    // Node Circle (filled with node color, border matches background)
    Canvas.Brush.Color := NodeCol;
    Canvas.Pen.Color := FColors.Background;
    Canvas.Pen.Width := 2;
    Canvas.Ellipse(DotX - DotR - 1, DotY - DotR - 1, DotX + DotR + 1, DotY + DotR + 1);

    // Timestamp text (left of track line, right aligned, vertically centered to DotY)
    Canvas.Font.Size := 8;
    Canvas.Font.Style := [];
    Canvas.Font.Color := FColors.TextSecondary;
    TimeR := Rect(4, DotY - 10, DotX - 10, DotY + 10);
    LocalR := TimeR;
    DrawText(Canvas.Handle, PChar(FItems[I].TimestampStr), Length(FItems[I].TimestampStr), LocalR,
      DT_SINGLELINE or DT_RIGHT or DT_VCENTER);

    // Title (right of track line, bold, vertically aligned above description or centered)
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := FColors.TextPrimary;

    if FItems[I].Description <> '' then
    begin
      TitleR := Rect(DotX + 14, DotY - 16, Width - 10, DotY);
      DescR  := Rect(DotX + 14, DotY + 1, Width - 10, DotY + 16);

      LocalR := TitleR;
      DrawText(Canvas.Handle, PChar(FItems[I].Title), Length(FItems[I].Title), LocalR,
        DT_SINGLELINE or DT_LEFT or DT_VCENTER);

      // Description
      Canvas.Font.Size := 8;
      Canvas.Font.Style := [];
      Canvas.Font.Color := FColors.TextSecondary;
      LocalR := DescR;
      DrawText(Canvas.Handle, PChar(FItems[I].Description), Length(FItems[I].Description), LocalR,
        DT_SINGLELINE or DT_LEFT or DT_VCENTER);
    end
    else
    begin
      TitleR := Rect(DotX + 14, DotY - 10, Width - 10, DotY + 10);
      LocalR := TitleR;
      DrawText(Canvas.Handle, PChar(FItems[I].Title), Length(FItems[I].Title), LocalR,
        DT_SINGLELINE or DT_LEFT or DT_VCENTER);
    end;
  end;
end;

end.
