unit Velox.Rating;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Controls, Graphics, Forms, Types, Math,
  Velox.Types;

type
  TVeloxRatingChangeEvent = procedure(Sender: TObject; const NewRating: Single) of object;

  TVeloxRating = class(TCustomControl)
  private
    FRating: Single;
    FMaxRating: Integer;
    FStarSize: Integer;
    FStarSpacing: Integer;
    FStarColor: TColor;
    FEmptyColor: TColor;
    FReadOnly: Boolean;
    FShowLabel: Boolean;
    FHoverRating: Single;
    FColors: TVeloxThemeColors;
    FOnRate: TVeloxRatingChangeEvent;
    procedure SetRating(const Value: Single);
    procedure SetMaxRating(const Value: Integer);
    procedure SetStarSize(const Value: Integer);
    function StarHitTest(X, Y: Integer): Single;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);
  published
    property Align;
    property Anchors;
    property Rating: Single read FRating write SetRating;
    property MaxRating: Integer read FMaxRating write SetMaxRating default 5;
    property StarSize: Integer read FStarSize write SetStarSize default 18;
    property StarSpacing: Integer read FStarSpacing write FStarSpacing default 4;
    property StarColor: TColor read FStarColor write FStarColor default $F59E0B;
    property EmptyColor: TColor read FEmptyColor write FEmptyColor default $334155;
    property ReadOnly: Boolean read FReadOnly write FReadOnly default False;
    property ShowLabel: Boolean read FShowLabel write FShowLabel default True;
    property OnRate: TVeloxRatingChangeEvent read FOnRate write FOnRate;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxRating.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 150;
  Height := 28;
  FRating := 4.0;
  FMaxRating := 5;
  FStarSize := 18;
  FStarSpacing := 4;
  FStarColor := $F59E0B; // Amber gold
  FEmptyColor := $334155; // Slate muted
  FReadOnly := False;
  FShowLabel := True;
  FHoverRating := -1;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
end;

procedure TVeloxRating.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxRating.SetRating(const Value: Single);
var
  Clamped: Single;
begin
  Clamped := Value;
  if Clamped < 0 then Clamped := 0;
  if Clamped > FMaxRating then Clamped := FMaxRating;

  if FRating <> Clamped then
  begin
    FRating := Clamped;
    Invalidate;
    if Assigned(FOnRate) then
      FOnRate(Self, FRating);
  end;
end;

procedure TVeloxRating.SetMaxRating(const Value: Integer);
begin
  if (FMaxRating <> Value) and (Value >= 1) then
  begin
    FMaxRating := Value;
    if FRating > FMaxRating then
      FRating := FMaxRating;
    Invalidate;
  end;
end;

procedure TVeloxRating.SetStarSize(const Value: Integer);
begin
  if (FStarSize <> Value) and (Value >= 10) then
  begin
    FStarSize := Value;
    Invalidate;
  end;
end;

function TVeloxRating.StarHitTest(X, Y: Integer): Single;
var
  TotalStarsW: Integer;
  Idx: Integer;
begin
  TotalStarsW := FMaxRating * (FStarSize + FStarSpacing);
  if (X < 4) or (X > TotalStarsW + 4) then
    Exit(-1);

  Idx := (X - 4) div (FStarSize + FStarSpacing);
  if Idx < 0 then Idx := 0;
  if Idx >= FMaxRating then Idx := FMaxRating - 1;

  Result := Idx + 1.0;
end;

procedure TVeloxRating.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  NewRate: Single;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and (not FReadOnly) then
  begin
    NewRate := StarHitTest(X, Y);
    if NewRate >= 0 then
      Rating := NewRate;
  end;
end;

procedure TVeloxRating.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Hit: Single;
begin
  inherited MouseMove(Shift, X, Y);
  if not FReadOnly then
  begin
    Hit := StarHitTest(X, Y);
    if Hit <> FHoverRating then
    begin
      FHoverRating := Hit;
      Invalidate;
    end;
  end;
end;

procedure TVeloxRating.MouseLeave;
begin
  inherited MouseLeave;
  if FHoverRating <> -1 then
  begin
    FHoverRating := -1;
    Invalidate;
  end;
end;

procedure TVeloxRating.Resize;
begin
  inherited Resize;
  Invalidate;
end;

procedure TVeloxRating.Paint;
var
  I, X, Step: Integer;
  DisplayRate: Single;
  LabelStr: string;
  LabelR, LocalR: TRect;
  StarPts: array[0..9] of TPoint;
  Cx, Cy: Integer;
  Radius, InnerRadius: Double;
  Angle, R: Double;
begin
  // Background
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);

  if FHoverRating >= 0 then
    DisplayRate := FHoverRating
  else
    DisplayRate := FRating;

  X := 4;
  Cy := Height div 2;
  Radius := FStarSize * 0.48;
  InnerRadius := Radius * 0.45;

  for I := 1 to FMaxRating do
  begin
    Cx := X + (FStarSize div 2);

    for Step := 0 to 9 do
    begin
      if (Step mod 2) = 0 then
        R := Radius
      else
        R := InnerRadius;
      Angle := (Step * 36 - 90) * (PI / 180.0);
      StarPts[Step].X := Cx + Round(R * Cos(Angle));
      StarPts[Step].Y := Cy + Round(R * Sin(Angle));
    end;

    if DisplayRate >= I then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := FStarColor;
      Canvas.Pen.Color := FStarColor;
    end
    else
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := FEmptyColor;
      Canvas.Pen.Color := FEmptyColor;
    end;

    Canvas.Pen.Width := 1;
    Canvas.Polygon(StarPts);

    Inc(X, FStarSize + FStarSpacing);
  end;

  // Rating label on right (e.g. "4.0 / 5", exact vertical center)
  if FShowLabel then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := FColors.TextPrimary;
    LabelStr := Format('%.1f', [DisplayRate]);

    LabelR := Rect(X + 6, 0, Width, Height);
    LocalR := LabelR;
    DrawText(Canvas.Handle, PChar(LabelStr), Length(LabelStr), LocalR,
      DT_SINGLELINE or DT_LEFT or DT_VCENTER);
  end;
end;

end.
