unit Velox.ColorPicker;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.ColorPicker
  Purpose:
    Fluent Windows 11 color palette and picker card (`TVeloxColorPicker`)
    inspired by `jackdp/Free-Color-Picker` and `rareMaxim/FluentUI`.
    Features interactive Fluent color swatches, RGB/HSV conversions,
    hex color parsing/formatting (`#38bdf8`), and custom theme swatch selection.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Math,
  Windows,
  Types,
  Graphics,
  Controls,
  Velox.Types,
  Velox.GdiPlus;

type
  /// <summary>
  /// Headless color mathematics and formatting utilities
  /// </summary>
  TVeloxColorUtils = class
  public
    class function ColorToHex(const AColor: TColor; const AIncludeHash: Boolean = True): string; static;
    class function HexToColor(const AHex: string; const ADefault: TColor = clWhite): TColor; static;
    class procedure RgbToHsv(const R, G, B: Byte; out H, S, V: Double); static;
    class procedure HsvToRgb(const H, S, V: Double; out R, G, B: Byte); static;
    class function ColorToHsv(const AColor: TColor; out H, S, V: Double): Boolean; static;
    class function HsvToColor(const H, S, V: Double): TColor; static;
  end;

  /// <summary>
  /// Fluent dark-theme color picker and swatch palette control
  /// </summary>
  TVeloxColorPicker = class(TCustomControl)
  private
    FSelectedColor: TColor;
    FColors: TVeloxThemeColors;
    FSwatches: array[0..15] of TColor;
    FHotSwatch: Integer;
    FOnColorChange: TNotifyEvent;
    procedure InitDefaultSwatches;
    function SwatchRect(const AIndex: Integer): TRect;
    function HitTestSwatch(const X, Y: Integer): Integer;
    procedure SetSelectedColor(const AValue: TColor);
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor CreatePicker(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop: Integer; const AColors: TVeloxThemeColors;
      const AInitialColor: TColor = $F8BD38);
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure SetSwatch(const AIndex: Integer; const AColor: TColor);
    function GetSwatch(const AIndex: Integer): TColor;

    property SelectedColor: TColor read FSelectedColor write SetSelectedColor;
    property OnColorChange: TNotifyEvent read FOnColorChange write FOnColorChange;
  end;

implementation

{ TVeloxColorUtils }

class function TVeloxColorUtils.ColorToHex(const AColor: TColor; const AIncludeHash: Boolean): string;
var
  RGBVal: LongInt;
  R, G, B: Byte;
begin
  RGBVal := ColorToRGB(AColor);
  R := GetRValue(RGBVal);
  G := GetGValue(RGBVal);
  B := GetBValue(RGBVal);
  Result := LowerCase(Format('%.2x%.2x%.2x', [R, G, B]));
  if AIncludeHash then
    Result := '#' + Result;
end;

class function TVeloxColorUtils.HexToColor(const AHex: string; const ADefault: TColor): TColor;
var
  S: string;
  R, G, B: Integer;
begin
  Result := ADefault;
  S := Trim(AHex);
  if (S <> '') and (S[1] = '#') then
    Delete(S, 1, 1);
  if Length(S) = 3 then
    S := S[1] + S[1] + S[2] + S[2] + S[3] + S[3];
  if Length(S) <> 6 then Exit;

  R := StrToIntDef('$' + Copy(S, 1, 2), -1);
  G := StrToIntDef('$' + Copy(S, 3, 2), -1);
  B := StrToIntDef('$' + Copy(S, 5, 2), -1);
  if (R >= 0) and (G >= 0) and (B >= 0) then
    Result := RGB(R, G, B);
end;

class procedure TVeloxColorUtils.RgbToHsv(const R, G, B: Byte; out H, S, V: Double);
var
  Rf, Gf, Bf: Double;
  MinVal, MaxVal, Delta: Double;
begin
  Rf := R / 255.0;
  Gf := G / 255.0;
  Bf := B / 255.0;

  MaxVal := Rf;
  if Gf > MaxVal then MaxVal := Gf;
  if Bf > MaxVal then MaxVal := Bf;

  MinVal := Rf;
  if Gf < MinVal then MinVal := Gf;
  if Bf < MinVal then MinVal := Bf;

  V := MaxVal;
  Delta := MaxVal - MinVal;

  if MaxVal > 0.00001 then
    S := Delta / MaxVal
  else
    S := 0.0;

  if S <= 0.00001 then
  begin
    H := 0.0;
    Exit;
  end;

  if Abs(Rf - MaxVal) < 0.0001 then
    H := (Gf - Bf) / Delta
  else if Abs(Gf - MaxVal) < 0.0001 then
    H := 2.0 + (Bf - Rf) / Delta
  else
    H := 4.0 + (Rf - Gf) / Delta;

  H := H * 60.0;
  if H < 0.0 then
    H := H + 360.0;
end;

class procedure TVeloxColorUtils.HsvToRgb(const H, S, V: Double; out R, G, B: Byte);
var
  Hi: Integer;
  F, P, Q, T: Double;
  Rf, Gf, Bf: Double;
begin
  if S <= 0.00001 then
  begin
    R := Round(V * 255.0);
    G := R;
    B := R;
    Exit;
  end;

  Hi := Floor(H / 60.0) mod 6;
  F := (H / 60.0) - Floor(H / 60.0);
  P := V * (1.0 - S);
  Q := V * (1.0 - F * S);
  T := V * (1.0 - (1.0 - F) * S);

  case Hi of
    0: begin Rf := V; Gf := T; Bf := P; end;
    1: begin Rf := Q; Gf := V; Bf := P; end;
    2: begin Rf := P; Gf := V; Bf := T; end;
    3: begin Rf := P; Gf := Q; Bf := V; end;
    4: begin Rf := T; Gf := P; Bf := V; end;
  else
    Rf := V; Gf := P; Bf := Q;
  end;

  R := Round(Rf * 255.0);
  G := Round(Gf * 255.0);
  B := Round(Bf * 255.0);
end;

class function TVeloxColorUtils.ColorToHsv(const AColor: TColor; out H, S, V: Double): Boolean;
var
  RGBVal: LongInt;
begin
  RGBVal := ColorToRGB(AColor);
  RgbToHsv(GetRValue(RGBVal), GetGValue(RGBVal), GetBValue(RGBVal), H, S, V);
  Result := True;
end;

class function TVeloxColorUtils.HsvToColor(const H, S, V: Double): TColor;
var
  R, G, B: Byte;
begin
  HsvToRgb(H, S, V, R, G, B);
  Result := RGB(R, G, B);
end;

{ TVeloxColorPicker }

constructor TVeloxColorPicker.CreatePicker(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop: Integer; const AColors: TVeloxThemeColors;
  const AInitialColor: TColor);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, 260, 150);
  FColors := AColors;
  FSelectedColor := AInitialColor;
  FHotSwatch := -1;
  InitDefaultSwatches;
end;

procedure TVeloxColorPicker.InitDefaultSwatches;
begin
  // Row 1: Vibrant accents
  FSwatches[0]  := RGB(56, 189, 248);  // Cyan
  FSwatches[1]  := RGB(99, 102, 241);  // Indigo
  FSwatches[2]  := RGB(168, 85, 247);  // Purple
  FSwatches[3]  := RGB(236, 72, 153);  // Pink
  FSwatches[4]  := RGB(239, 68, 68);   // Red
  FSwatches[5]  := RGB(249, 115, 22);  // Orange
  FSwatches[6]  := RGB(234, 179, 8);   // Amber
  FSwatches[7]  := RGB(16, 185, 129);  // Emerald

  // Row 2: Deep / pastel tones & neutrals
  FSwatches[8]  := RGB(2, 132, 199);   // Deep Cyan
  FSwatches[9]  := RGB(79, 70, 229);   // Deep Indigo
  FSwatches[10] := RGB(126, 34, 206);  // Deep Purple
  FSwatches[11] := RGB(190, 24, 93);   // Deep Pink
  FSwatches[12] := RGB(248, 250, 252); // White
  FSwatches[13] := RGB(148, 163, 184); // Slate Light
  FSwatches[14] := RGB(71, 85, 105);   // Slate Dark
  FSwatches[15] := RGB(15, 23, 42);    // Obsidian
end;

procedure TVeloxColorPicker.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

function TVeloxColorPicker.SwatchRect(const AIndex: Integer): TRect;
var
  Col, Row, X, Y: Integer;
const
  Size = 24;
  Gap = 6;
  StartX = 12;
  StartY = 50;
begin
  Col := AIndex mod 8;
  Row := AIndex div 8;
  X := StartX + (Col * (Size + Gap));
  Y := StartY + (Row * (Size + Gap));
  Result := Rect(X, Y, X + Size, Y + Size);
end;

function TVeloxColorPicker.HitTestSwatch(const X, Y: Integer): Integer;
var
  I: Integer;
  R: TRect;
  P: TPoint;
begin
  Result := -1;
  P := Point(X, Y);
  for I := 0 to 15 do
  begin
    R := SwatchRect(I);
    if PtInRect(R, P) then
      Exit(I);
  end;
end;

procedure TVeloxColorPicker.SetSelectedColor(const AValue: TColor);
begin
  if FSelectedColor <> AValue then
  begin
    FSelectedColor := AValue;
    Invalidate;
    if Assigned(FOnColorChange) then
      FOnColorChange(Self);
  end;
end;

procedure TVeloxColorPicker.SetSwatch(const AIndex: Integer; const AColor: TColor);
begin
  if (AIndex >= 0) and (AIndex <= 15) then
  begin
    FSwatches[AIndex] := AColor;
    Invalidate;
  end;
end;

function TVeloxColorPicker.GetSwatch(const AIndex: Integer): TColor;
begin
  if (AIndex >= 0) and (AIndex <= 15) then
    Result := FSwatches[AIndex]
  else
    Result := clBlack;
end;

procedure TVeloxColorPicker.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Hit: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  Hit := HitTestSwatch(X, Y);
  if Hit <> FHotSwatch then
  begin
    FHotSwatch := Hit;
    Invalidate;
  end;
end;

procedure TVeloxColorPicker.MouseLeave;
begin
  inherited MouseLeave;
  if FHotSwatch <> -1 then
  begin
    FHotSwatch := -1;
    Invalidate;
  end;
end;

procedure TVeloxColorPicker.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Hit: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    Hit := HitTestSwatch(X, Y);
    if Hit >= 0 then
      SetSelectedColor(FSwatches[Hit]);
  end;
end;

procedure TVeloxColorPicker.Paint;
var
  I: Integer;
  R, SwR, PreviewR, TextR: TRect;
  BorderCol: TColor;
  HexStr: string;
begin
  R := Rect(0, 0, Width, Height);

  // Outer container card
  TVeloxGdiPlus.DrawCard(Canvas, R, FColors.SurfaceCard, FColors.Border, 8);

  // Top Preview Section: Color Swatch + Hex Label
  PreviewR := Rect(12, 12, 44, 40);
  TVeloxGdiPlus.DrawCard(Canvas, PreviewR, FSelectedColor, FColors.Border, 4);

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 10;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := FColors.TextPrimary;

  HexStr := TVeloxColorUtils.ColorToHex(FSelectedColor, True);
  TextR := Rect(52, 12, 180, 40);
  DrawText(Canvas.Handle, PChar(HexStr), Length(HexStr), TextR,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_NOPREFIX);

  // 16 Palette Swatches
  for I := 0 to 15 do
  begin
    SwR := SwatchRect(I);
    if ColorToRGB(FSelectedColor) = ColorToRGB(FSwatches[I]) then
      BorderCol := FColors.Accent
    else if I = FHotSwatch then
      BorderCol := clWhite
    else
      BorderCol := FColors.Border;

    TVeloxGdiPlus.DrawCard(Canvas, SwR, FSwatches[I], BorderCol, 4);
  end;
end;

end.
