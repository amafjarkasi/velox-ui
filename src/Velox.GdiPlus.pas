unit Velox.GdiPlus;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.GdiPlus
  Purpose:
    Zero-dependency dynamic GDI+ Flat API bindings (`gdiplus.dll`) for
    hardware-accelerated, sub-pixel anti-aliased UI cards, progress bars,
    status pills, glowing telemetry sparklines, and complete KPI metric cards.
    Automatically falls back to standard Win32 GDI if GDI+ is unavailable.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  ExtCtrls,
  Velox.Types;

type
  /// <summary>
  /// Hardware-accelerated GDI+ vector & telemetry drawing primitives
  /// </summary>
  TVeloxGdiPlus = class
  public
    /// <summary>
    /// Draws an anti-aliased rounded rectangle card with 1px crisp border
    /// </summary>
    class procedure DrawCard(const ACanvas: TCanvas; const ARect: TRect;
      const AFillColor, ABorderColor: TColor; const ARadius: Integer = 8); static;

    /// <summary>
    /// Draws a dual-tone rounded progress bar (clamped 0..100%)
    /// </summary>
    class procedure DrawProgressBar(const ACanvas: TCanvas; const ARect: TRect;
      const APercent: Single; const ATrackColor, AFillColor: TColor); static;

    /// <summary>
    /// Draws a rounded status badge pill with centered bold label
    /// </summary>
    class procedure DrawBadge(const ACanvas: TCanvas; const ARect: TRect;
      const AText: string; const ABackColor, ATextColor: TColor); static;

    /// <summary>
    /// Draws an anti-aliased time-series sparkline with translucent area fill
    /// </summary>
    class procedure DrawSparkline(const ACanvas: TCanvas; const ARect: TRect;
      const AValues: TSingleDynArray; const ALineColor, AFillColor: TColor); static;

    /// <summary>
    /// Draws a soft translucent glowing focus ring around a rounded rect
    /// </summary>
    class procedure DrawGlowBorder(const ACanvas: TCanvas; const ARect: TRect;
      const AGlowColor: TColor; const ARadius: Integer = 8; const AGlowSpread: Integer = 3); static;

    /// <summary>
    /// Draws an ambient soft drop shadow beneath a floating card or modal
    /// </summary>
    class procedure DrawDropShadow(const ACanvas: TCanvas; const ARect: TRect;
      const ARadius: Integer = 8; const AOffset: Integer = 4); static;

    /// <summary>
    /// Complete one-call KPI Metric Card renderer with automatic primary font
    /// collision avoidance against the upper-right sparkline, secondary caption,
    /// and bottom progress bar. Pass AHistory = nil to omit the sparkline.
    /// </summary>
    class procedure DrawMetricCard(const APaintBox: TPaintBox;
      const AColors: TVeloxThemeColors; const ATitle, APrimaryValue, ASecondaryValue: string;
      const APercent: Single; const AAccentColor: TColor;
      const AHistory: TSingleDynArray = nil); static;
  end;

implementation

type
  TGpStatus = Integer;
  TGpGraphics = Pointer;
  TGpBrush = Pointer;
  TGpSolidFill = Pointer;
  TGpPen = Pointer;
  TGpPath = Pointer;
  TARGB = Cardinal;

  TGpPointF = packed record
    X: Single;
    Y: Single;
  end;
  PGpPointF = ^TGpPointF;

  TGdiplusStartupInput = packed record
    GdiplusVersion: Cardinal;
    DebugEventCallback: Pointer;
    SuppressBackgroundThread: BOOL;
    SuppressExternalCodecs: BOOL;
  end;
  PGdiplusStartupInput = ^TGdiplusStartupInput;

const
  SmoothingModeAntiAlias = 4;
  FillModeAlternate = 0;
  UnitPixel = 2;

var
  GGdiPlusLoaded: Boolean = False;
  GGdiPlusLib: HMODULE = 0;
  GGdiPlusToken: NativeUInt = 0;

  GdiplusStartup: function(out token: NativeUInt; input: PGdiplusStartupInput; output: Pointer): TGpStatus; stdcall;
  GdipCreateFromHDC: function(hdc: HDC; out graphics: TGpGraphics): TGpStatus; stdcall;
  GdipDeleteGraphics: function(graphics: TGpGraphics): TGpStatus; stdcall;
  GdipSetSmoothingMode: function(graphics: TGpGraphics; smoothingMode: Integer): TGpStatus; stdcall;
  GdipCreateSolidFill: function(color: TARGB; out brush: TGpSolidFill): TGpStatus; stdcall;
  GdipDeleteBrush: function(brush: TGpBrush): TGpStatus; stdcall;
  GdipCreatePen1: function(color: TARGB; width: Single; unit_: Integer; out pen: TGpPen): TGpStatus; stdcall;
  GdipDeletePen: function(pen: TGpPen): TGpStatus; stdcall;
  GdipCreatePath: function(brushMode: Integer; out path: TGpPath): TGpStatus; stdcall;
  GdipDeletePath: function(path: TGpPath): TGpStatus; stdcall;
  GdipAddPathArc: function(path: TGpPath; x, y, width, height, startAngle, sweepAngle: Single): TGpStatus; stdcall;
  GdipAddPathLine: function(path: TGpPath; x1, y1, x2, y2: Single): TGpStatus; stdcall;
  GdipClosePathFigure: function(path: TGpPath): TGpStatus; stdcall;
  GdipFillPath: function(graphics: TGpGraphics; brush: TGpBrush; path: TGpPath): TGpStatus; stdcall;
  GdipDrawPath: function(graphics: TGpGraphics; pen: TGpPen; path: TGpPath): TGpStatus; stdcall;
  GdipDrawLines: function(graphics: TGpGraphics; pen: TGpPen; points: PGpPointF; count: Integer): TGpStatus; stdcall;
  GdipFillPolygon: function(graphics: TGpGraphics; brush: TGpBrush; points: PGpPointF; count: Integer; fillMode: Integer): TGpStatus; stdcall;

function InitGdiPlus: Boolean;
var
  Input: TGdiplusStartupInput;
begin
  if GGdiPlusLoaded then
    Exit(GGdiPlusToken <> 0);
  GGdiPlusLoaded := True;

  GGdiPlusLib := LoadLibrary('gdiplus.dll');
  if GGdiPlusLib = 0 then Exit(False);

  @GdiplusStartup       := GetProcAddress(GGdiPlusLib, 'GdiplusStartup');
  @GdipCreateFromHDC    := GetProcAddress(GGdiPlusLib, 'GdipCreateFromHDC');
  @GdipDeleteGraphics   := GetProcAddress(GGdiPlusLib, 'GdipDeleteGraphics');
  @GdipSetSmoothingMode := GetProcAddress(GGdiPlusLib, 'GdipSetSmoothingMode');
  @GdipCreateSolidFill  := GetProcAddress(GGdiPlusLib, 'GdipCreateSolidFill');
  @GdipDeleteBrush      := GetProcAddress(GGdiPlusLib, 'GdipDeleteBrush');
  @GdipCreatePen1       := GetProcAddress(GGdiPlusLib, 'GdipCreatePen1');
  @GdipDeletePen        := GetProcAddress(GGdiPlusLib, 'GdipDeletePen');
  @GdipCreatePath       := GetProcAddress(GGdiPlusLib, 'GdipCreatePath');
  @GdipDeletePath       := GetProcAddress(GGdiPlusLib, 'GdipDeletePath');
  @GdipAddPathArc       := GetProcAddress(GGdiPlusLib, 'GdipAddPathArc');
  @GdipAddPathLine      := GetProcAddress(GGdiPlusLib, 'GdipAddPathLine');
  @GdipClosePathFigure  := GetProcAddress(GGdiPlusLib, 'GdipClosePathFigure');
  @GdipFillPath         := GetProcAddress(GGdiPlusLib, 'GdipFillPath');
  @GdipDrawPath         := GetProcAddress(GGdiPlusLib, 'GdipDrawPath');
  @GdipDrawLines        := GetProcAddress(GGdiPlusLib, 'GdipDrawLines');
  @GdipFillPolygon      := GetProcAddress(GGdiPlusLib, 'GdipFillPolygon');

  if Assigned(GdiplusStartup) and Assigned(GdipCreateFromHDC) then
  begin
    FillChar(Input, SizeOf(Input), 0);
    Input.GdiplusVersion := 1;
    if GdiplusStartup(GGdiPlusToken, @Input, nil) <> 0 then
      GGdiPlusToken := 0;
  end;
  Result := GGdiPlusToken <> 0;
end;

function ColorToARGB(const AColor: TColor; const AAlpha: Byte = 255): TARGB;
var
  RGBVal: LongInt;
begin
  RGBVal := ColorToRGB(AColor);
  Result := (TARGB(AAlpha) shl 24) or
            (TARGB(GetRValue(RGBVal)) shl 16) or
            (TARGB(GetGValue(RGBVal)) shl 8) or
            TARGB(GetBValue(RGBVal));
end;

function BuildRoundedPath(const X, Y, W, H, Radius: Single): TGpPath;
var
  D: Single;
begin
  Result := nil;
  if GdipCreatePath(FillModeAlternate, Result) <> 0 then Exit;
  D := Radius * 2.0;
  if D > W then D := W;
  if D > H then D := H;
  if D <= 1.0 then
  begin
    GdipAddPathLine(Result, X, Y, X + W, Y);
    GdipAddPathLine(Result, X + W, Y, X + W, Y + H);
    GdipAddPathLine(Result, X + W, Y + H, X, Y + H);
    GdipClosePathFigure(Result);
    Exit;
  end;
  GdipAddPathArc(Result, X, Y, D, D, 180.0, 90.0);
  GdipAddPathArc(Result, X + W - D, Y, D, D, 270.0, 90.0);
  GdipAddPathArc(Result, X + W - D, Y + H - D, D, D, 0.0, 90.0);
  GdipAddPathArc(Result, X, Y + H - D, D, D, 90.0, 90.0);
  GdipClosePathFigure(Result);
end;

{ TVeloxGdiPlus }

class procedure TVeloxGdiPlus.DrawCard(const ACanvas: TCanvas; const ARect: TRect;
  const AFillColor, ABorderColor: TColor; const ARadius: Integer);
var
  G: TGpGraphics;
  Path: TGpPath;
  Brush: TGpSolidFill;
  Pen: TGpPen;
begin
  if InitGdiPlus and (GdipCreateFromHDC(ACanvas.Handle, G) = 0) then
  begin
    try
      GdipSetSmoothingMode(G, SmoothingModeAntiAlias);
      Path := BuildRoundedPath(ARect.Left + 0.5, ARect.Top + 0.5,
        (ARect.Right - ARect.Left) - 1.0, (ARect.Bottom - ARect.Top) - 1.0, ARadius);
      if Path <> nil then
      begin
        try
          if GdipCreateSolidFill(ColorToARGB(AFillColor, 255), Brush) = 0 then
          begin
            GdipFillPath(G, Brush, Path);
            GdipDeleteBrush(Brush);
          end;
          if GdipCreatePen1(ColorToARGB(ABorderColor, 255), 1.0, UnitPixel, Pen) = 0 then
          begin
            GdipDrawPath(G, Pen, Path);
            GdipDeletePen(Pen);
          end;
        finally
          GdipDeletePath(Path);
        end;
      end;
      Exit;
    finally
      GdipDeleteGraphics(G);
    end;
  end;

  // Fallback GDI
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := AFillColor;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Color := ABorderColor;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, ARadius * 2, ARadius * 2);
end;

class procedure TVeloxGdiPlus.DrawGlowBorder(const ACanvas: TCanvas; const ARect: TRect;
  const AGlowColor: TColor; const ARadius: Integer; const AGlowSpread: Integer);
var
  G: TGpGraphics;
  Path: TGpPath;
  Pen: TGpPen;
  I, Spread: Integer;
  Alpha: Byte;
  R: TRect;
  W, H: Single;
begin
  if (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then Exit;
  Spread := AGlowSpread;
  if Spread <= 0 then Exit;
  if Spread > 8 then Spread := 8;

  if InitGdiPlus and (GdipCreateFromHDC(ACanvas.Handle, G) = 0) then
  begin
    try
      GdipSetSmoothingMode(G, SmoothingModeAntiAlias);
      for I := Spread downto 1 do
      begin
        Alpha := Round(40 / I);
        if GdipCreatePen1(ColorToARGB(AGlowColor, Alpha), I * 1.5, UnitPixel, Pen) = 0 then
        begin
          try
            R := ARect;
            InflateRect(R, I, I);
            W := (R.Right - R.Left) - 1.0;
            H := (R.Bottom - R.Top) - 1.0;
            Path := BuildRoundedPath(R.Left + 0.5, R.Top + 0.5, W, H, ARadius + I);
            if Path <> nil then
            begin
              try
                GdipDrawPath(G, Pen, Path);
              finally
                GdipDeletePath(Path);
              end;
            end;
          finally
            GdipDeletePen(Pen);
          end;
        end;
      end;
    finally
      GdipDeleteGraphics(G);
    end;
  end;
end;

class procedure TVeloxGdiPlus.DrawDropShadow(const ACanvas: TCanvas; const ARect: TRect;
  const ARadius: Integer; const AOffset: Integer);
var
  G: TGpGraphics;
  Path: TGpPath;
  Pen: TGpPen;
  I, Offset: Integer;
  Alpha: Byte;
  R: TRect;
  W, H: Single;
begin
  if (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then Exit;
  Offset := AOffset;
  if Offset <= 0 then Exit;
  if Offset > 8 then Offset := 8;

  if InitGdiPlus and (GdipCreateFromHDC(ACanvas.Handle, G) = 0) then
  begin
    try
      GdipSetSmoothingMode(G, SmoothingModeAntiAlias);
      for I := Offset downto 1 do
      begin
        Alpha := Round(24 / I);
        if GdipCreatePen1(ColorToARGB($000000, Alpha), I * 2.0, UnitPixel, Pen) = 0 then
        begin
          try
            R := ARect;
            OffsetRect(R, 0, I);
            W := (R.Right - R.Left) - 1.0;
            H := (R.Bottom - R.Top) - 1.0;
            Path := BuildRoundedPath(R.Left + 0.5, R.Top + 0.5, W, H, ARadius);
            if Path <> nil then
            begin
              try
                GdipDrawPath(G, Pen, Path);
              finally
                GdipDeletePath(Path);
              end;
            end;
          finally
            GdipDeletePen(Pen);
          end;
        end;
      end;
    finally
      GdipDeleteGraphics(G);
    end;
  end;
end;

class procedure TVeloxGdiPlus.DrawProgressBar(const ACanvas: TCanvas; const ARect: TRect;
  const APercent: Single; const ATrackColor, AFillColor: TColor);
var
  Clamped: Single;
  W, H, FillW: Integer;
  FillR: TRect;
begin
  W := ARect.Right - ARect.Left;
  H := ARect.Bottom - ARect.Top;
  if (W <= 0) or (H <= 0) then Exit;

  DrawCard(ACanvas, ARect, ATrackColor, ATrackColor, H div 2);

  Clamped := TVeloxUtils.ClampSingle(APercent, 0.0, 100.0);
  FillW := Round((W * Clamped) / 100.0);
  if FillW > 2 then
  begin
    FillR := Rect(ARect.Left, ARect.Top, ARect.Left + FillW, ARect.Bottom);
    DrawCard(ACanvas, FillR, AFillColor, AFillColor, H div 2);
  end;
end;

class procedure TVeloxGdiPlus.DrawBadge(const ACanvas: TCanvas; const ARect: TRect;
  const AText: string; const ABackColor, ATextColor: TColor);
var
  R: TRect;
begin
  DrawCard(ACanvas, ARect, ABackColor, ABackColor, (ARect.Bottom - ARect.Top) div 2);
  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := ATextColor;
  R := ARect;
  DrawText(ACanvas.Handle, PChar(AText), Length(AText), R,
    DT_SINGLELINE or DT_VCENTER or DT_CENTER or DT_NOPREFIX);
end;

class procedure TVeloxGdiPlus.DrawSparkline(const ACanvas: TCanvas; const ARect: TRect;
  const AValues: TSingleDynArray; const ALineColor, AFillColor: TColor);
var
  G: TGpGraphics;
  LinePts: array of TGpPointF;
  PolyPts: array of TGpPointF;
  Pen: TGpPen;
  Brush: TGpSolidFill;
  I, N, W, H: Integer;
  Val: Single;
begin
  N := Length(AValues);
  W := ARect.Right - ARect.Left;
  H := ARect.Bottom - ARect.Top;
  if (N < 2) or (W <= 4) or (H <= 4) then Exit;

  if InitGdiPlus and (GdipCreateFromHDC(ACanvas.Handle, G) = 0) then
  begin
    try
      GdipSetSmoothingMode(G, SmoothingModeAntiAlias);
      SetLength(LinePts, N);
      SetLength(PolyPts, N + 2);
      for I := 0 to N - 1 do
      begin
        Val := TVeloxUtils.ClampSingle(AValues[I], 0.0, 100.0);
        LinePts[I].X := ARect.Left + (I * W) / (N - 1);
        LinePts[I].Y := ARect.Bottom - (Val / 100.0) * (H - 4) - 2.0;
        PolyPts[I] := LinePts[I];
      end;
      PolyPts[N].X := ARect.Right;
      PolyPts[N].Y := ARect.Bottom;
      PolyPts[N + 1].X := ARect.Left;
      PolyPts[N + 1].Y := ARect.Bottom;

      if GdipCreateSolidFill(ColorToARGB(AFillColor, 72), Brush) = 0 then
      begin
        GdipFillPolygon(G, Brush, @PolyPts[0], N + 2, FillModeAlternate);
        GdipDeleteBrush(Brush);
      end;

      if GdipCreatePen1(ColorToARGB(ALineColor, 240), 1.8, UnitPixel, Pen) = 0 then
      begin
        GdipDrawLines(G, Pen, @LinePts[0], N);
        GdipDeletePen(Pen);
      end;
    finally
      GdipDeleteGraphics(G);
    end;
  end;
end;

class procedure TVeloxGdiPlus.DrawMetricCard(const APaintBox: TPaintBox;
  const AColors: TVeloxThemeColors; const ATitle, APrimaryValue, ASecondaryValue: string;
  const APercent: Single; const AAccentColor: TColor;
  const AHistory: TSingleDynArray);
var
  C: TCanvas;
  R, BarR, SparkR: TRect;
  Y, MaxPrimaryWidth: Integer;
const
  PadX = 14;
  LineGap = 6;
begin
  if APaintBox = nil then Exit;
  C := APaintBox.Canvas;
  R := Rect(0, 0, APaintBox.Width, APaintBox.Height);

  DrawCard(C, R, AColors.SurfaceCard, AColors.Border, 8);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';

  Y := R.Top + 10;
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := AColors.TextSecondary;
  C.TextOut(R.Left + PadX, Y, ATitle);
  Inc(Y, C.TextHeight(ATitle) + LineGap);

  // Auto-scale primary value font if a sparkline occupies the upper-right quadrant
  C.Font.Size := 15;
  C.Font.Style := [fsBold];
  C.Font.Color := AColors.TextPrimary;
  if Length(AHistory) >= 2 then
  begin
    MaxPrimaryWidth := (R.Right - 92) - (R.Left + PadX);
    while (C.Font.Size > 11) and (C.TextWidth(APrimaryValue) > MaxPrimaryWidth) do
      C.Font.Size := C.Font.Size - 1;
  end;
  C.TextOut(R.Left + PadX, Y, APrimaryValue);
  Inc(Y, C.TextHeight(APrimaryValue) + LineGap);

  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := AColors.TextSecondary;
  C.TextOut(R.Left + PadX, Y, ASecondaryValue);

  if Length(AHistory) >= 2 then
  begin
    SparkR := Rect(R.Right - 82, R.Top + 12, R.Right - 14, R.Bottom - 26);
    DrawSparkline(C, SparkR, AHistory, AAccentColor,
      TVeloxUtils.BlendColor(AColors.SurfaceCard, AAccentColor, 0.22));
  end;

  if APercent >= 0 then
  begin
    BarR := Rect(R.Left + PadX, R.Bottom - 16, R.Right - PadX, R.Bottom - 10);
    DrawProgressBar(C, BarR, APercent, AColors.Border, AAccentColor);
  end;
end;

end.
