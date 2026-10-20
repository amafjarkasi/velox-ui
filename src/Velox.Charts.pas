unit Velox.Charts;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Charts
  Purpose:
    Advanced hardware-accelerated GDI+ data visualizations (`TVeloxCharts`):
    1. `DrawDonutGauge`: Anti-aliased circular radial gauge (`GdipDrawArc`) with
       track ring, active progress arc, and centered bold value + caption.
    2. `DrawDualSparkline`: Two-series overlapping telemetry area chart (e.g.,
       Network Download vs. Upload, or Disk Read vs. Write) on a shared scale.
    3. `DrawHeatGrid`: Multi-cell utilization heatmap grid (e.g., 4..64 logical
       CPU cores or storage blocks) colored dynamically by load severity.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  Velox.Types,
  Velox.GdiPlus;

type
  /// <summary>
  /// Advanced GDI+ telemetry charts (Donut Gauges, Dual Sparklines, HeatGrids)
  /// </summary>
  TVeloxCharts = class
  public
    /// <summary>
    /// Draws an anti-aliased circular donut gauge (`0..100%`) with centered
    /// primary label and sub-label.
    /// </summary>
    class procedure DrawDonutGauge(const ACanvas: TCanvas; const ARect: TRect;
      const APercent: Single; const APrimaryText, ASubText: string;
      const AColors: TVeloxThemeColors; const AAccentColor: TColor;
      const AThickness: Single = 8.0); static;

    /// <summary>
    /// Draws a two-series overlapping sparkline chart (Series A + Series B)
    /// with independent colors and translucent polygon fills.
    /// </summary>
    class procedure DrawDualSparkline(const ACanvas: TCanvas; const ARect: TRect;
      const ASeriesA, ASeriesB: TSingleDynArray;
      const AColorA, AColorB: TColor;
      const ABackgroundCardColor: TColor); static;

    /// <summary>
    /// Draws a responsive multi-cell heatmap grid (e.g. per-core CPU load
    /// percentages `0..100%`) with automatic column/row layout and dynamic
    /// severity color interpolation.
    /// </summary>
    class procedure DrawHeatGrid(const ACanvas: TCanvas; const ARect: TRect;
      const AValues: TSingleDynArray; const AColors: TVeloxThemeColors;
      const AColumns: Integer = 4); static;
  end;

implementation

type
  TGpStatus = Integer;
  TGpGraphics = Pointer;
  TGpPen = Pointer;
  TARGB = Cardinal;

  TGdiplusStartupInput = packed record
    GdiplusVersion: Cardinal;
    DebugEventCallback: Pointer;
    SuppressBackgroundThread: BOOL;
    SuppressExternalCodecs: BOOL;
  end;
  PGdiplusStartupInput = ^TGdiplusStartupInput;

const
  SmoothingModeAntiAlias = 4;
  UnitPixel = 2;

var
  GChartsGdiLoaded: Boolean = False;
  GChartsGdiLib: HMODULE = 0;
  GChartsGdiToken: NativeUInt = 0;

  GdiplusStartup: function(out token: NativeUInt; input: PGdiplusStartupInput; output: Pointer): TGpStatus; stdcall;
  GdipCreateFromHDC: function(hdc: HDC; out graphics: TGpGraphics): TGpStatus; stdcall;
  GdipDeleteGraphics: function(graphics: TGpGraphics): TGpStatus; stdcall;
  GdipSetSmoothingMode: function(graphics: TGpGraphics; smoothingMode: Integer): TGpStatus; stdcall;
  GdipCreatePen1: function(color: TARGB; width: Single; unit_: Integer; out pen: TGpPen): TGpStatus; stdcall;
  GdipDeletePen: function(pen: TGpPen): TGpStatus; stdcall;
  GdipDrawArc: function(graphics: TGpGraphics; pen: TGpPen; x, y, width, height, startAngle, sweepAngle: Single): TGpStatus; stdcall;

function InitChartsGdiPlus: Boolean;
var
  Input: TGdiplusStartupInput;
begin
  if GChartsGdiLoaded then
    Exit(GChartsGdiToken <> 0);
  GChartsGdiLoaded := True;

  GChartsGdiLib := LoadLibrary('gdiplus.dll');
  if GChartsGdiLib = 0 then Exit(False);

  @GdiplusStartup       := GetProcAddress(GChartsGdiLib, 'GdiplusStartup');
  @GdipCreateFromHDC    := GetProcAddress(GChartsGdiLib, 'GdipCreateFromHDC');
  @GdipDeleteGraphics   := GetProcAddress(GChartsGdiLib, 'GdipDeleteGraphics');
  @GdipSetSmoothingMode := GetProcAddress(GChartsGdiLib, 'GdipSetSmoothingMode');
  @GdipCreatePen1       := GetProcAddress(GChartsGdiLib, 'GdipCreatePen1');
  @GdipDeletePen        := GetProcAddress(GChartsGdiLib, 'GdipDeletePen');
  @GdipDrawArc          := GetProcAddress(GChartsGdiLib, 'GdipDrawArc');

  if Assigned(GdiplusStartup) and Assigned(GdipDrawArc) then
  begin
    FillChar(Input, SizeOf(Input), 0);
    Input.GdiplusVersion := 1;
    if GdiplusStartup(GChartsGdiToken, @Input, nil) <> 0 then
      GChartsGdiToken := 0;
  end;
  Result := GChartsGdiToken <> 0;
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

{ TVeloxCharts }

class procedure TVeloxCharts.DrawDonutGauge(const ACanvas: TCanvas; const ARect: TRect;
  const APercent: Single; const APrimaryText, ASubText: string;
  const AColors: TVeloxThemeColors; const AAccentColor: TColor;
  const AThickness: Single);
var
  G: TGpGraphics;
  TrackPen, FillPen: TGpPen;
  W, H, Size: Integer;
  CX, CY, X, Y, D, Sweep: Single;
  Clamped: Single;
  TW, TH: Integer;
begin
  W := ARect.Right - ARect.Left;
  H := ARect.Bottom - ARect.Top;
  if (W < 24) or (H < 24) then Exit;

  if W < H then Size := W else Size := H;
  D := Size - (AThickness * 2.0) - 4.0;
  if D < 10.0 then D := 10.0;

  CX := ARect.Left + (W * 0.5);
  CY := ARect.Top + (H * 0.5);
  X := CX - (D * 0.5);
  Y := CY - (D * 0.5);

  Clamped := TVeloxUtils.ClampSingle(APercent, 0.0, 100.0);
  Sweep := (Clamped / 100.0) * 360.0;

  if InitChartsGdiPlus and (GdipCreateFromHDC(ACanvas.Handle, G) = 0) then
  begin
    try
      GdipSetSmoothingMode(G, SmoothingModeAntiAlias);
      if GdipCreatePen1(ColorToARGB(AColors.Border, 255), AThickness, UnitPixel, TrackPen) = 0 then
      begin
        GdipDrawArc(G, TrackPen, X, Y, D, D, 0.0, 360.0);
        GdipDeletePen(TrackPen);
      end;

      if (Sweep > 0.5) and (GdipCreatePen1(ColorToARGB(AAccentColor, 255), AThickness, UnitPixel, FillPen) = 0) then
      begin
        // Start at top (-90 degrees) and sweep clockwise
        GdipDrawArc(G, FillPen, X, Y, D, D, -90.0, Sweep);
        GdipDeletePen(FillPen);
      end;
    finally
      GdipDeleteGraphics(G);
    end;
  end;

  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Name := 'Segoe UI';
  if APrimaryText <> '' then
  begin
    ACanvas.Font.Size := 11;
    ACanvas.Font.Style := [fsBold];
    ACanvas.Font.Color := AColors.TextPrimary;
    TW := ACanvas.TextWidth(APrimaryText);
    TH := ACanvas.TextHeight(APrimaryText);
    if ASubText <> '' then
      ACanvas.TextOut(Round(CX) - (TW div 2), Round(CY) - TH, APrimaryText)
    else
      ACanvas.TextOut(Round(CX) - (TW div 2), Round(CY) - (TH div 2), APrimaryText);
  end;

  if ASubText <> '' then
  begin
    ACanvas.Font.Size := 8;
    ACanvas.Font.Style := [];
    ACanvas.Font.Color := AColors.TextSecondary;
    TW := ACanvas.TextWidth(ASubText);
    ACanvas.TextOut(Round(CX) - (TW div 2), Round(CY) + 2, ASubText);
  end;
end;

class procedure TVeloxCharts.DrawDualSparkline(const ACanvas: TCanvas; const ARect: TRect;
  const ASeriesA, ASeriesB: TSingleDynArray;
  const AColorA, AColorB: TColor;
  const ABackgroundCardColor: TColor);
begin
  if Length(ASeriesB) >= 2 then
  begin
    TVeloxGdiPlus.DrawSparkline(ACanvas, ARect, ASeriesB, AColorB,
      TVeloxUtils.BlendColor(ABackgroundCardColor, AColorB, 0.18));
  end;
  if Length(ASeriesA) >= 2 then
  begin
    TVeloxGdiPlus.DrawSparkline(ACanvas, ARect, ASeriesA, AColorA,
      TVeloxUtils.BlendColor(ABackgroundCardColor, AColorA, 0.26));
  end;
end;

class procedure TVeloxCharts.DrawHeatGrid(const ACanvas: TCanvas; const ARect: TRect;
  const AValues: TSingleDynArray; const AColors: TVeloxThemeColors;
  const AColumns: Integer);
var
  N, Cols, Rows, I, ColIdx, RowIdx: Integer;
  CellW, CellH, Gap: Integer;
  CellR: TRect;
  Val: Single;
  FillCol: TColor;
  Lbl: string;
  TW, TH: Integer;
begin
  N := Length(AValues);
  if N = 0 then Exit;
  Cols := AColumns;
  if Cols < 1 then Cols := 4;
  if Cols > N then Cols := N;
  Rows := (N + Cols - 1) div Cols;

  Gap := 4;
  CellW := ((ARect.Right - ARect.Left) - (Gap * (Cols - 1))) div Cols;
  CellH := ((ARect.Bottom - ARect.Top) - (Gap * (Rows - 1))) div Rows;
  if (CellW < 12) or (CellH < 12) then Exit;

  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Size := 8;
  ACanvas.Font.Style := [fsBold];

  for I := 0 to N - 1 do
  begin
    ColIdx := I mod Cols;
    RowIdx := I div Cols;
    CellR := Rect(
      ARect.Left + ColIdx * (CellW + Gap),
      ARect.Top + RowIdx * (CellH + Gap),
      ARect.Left + ColIdx * (CellW + Gap) + CellW,
      ARect.Top + RowIdx * (CellH + Gap) + CellH
    );

    Val := TVeloxUtils.ClampSingle(AValues[I], 0.0, 100.0);
    if Val >= 85.0 then
      FillCol := TVeloxUtils.BlendColor(AColors.SurfaceCard, AColors.Danger, 0.45)
    else if Val >= 60.0 then
      FillCol := TVeloxUtils.BlendColor(AColors.SurfaceCard, AColors.Warning, 0.40)
    else
      FillCol := TVeloxUtils.BlendColor(AColors.SurfaceCard, AColors.Accent, (Val / 100.0) * 0.55 + 0.08);

    TVeloxGdiPlus.DrawCard(ACanvas, CellR, FillCol, AColors.Border, 4);

    Lbl := Format('%.0f%%', [Val]);
    ACanvas.Brush.Style := bsClear;
    ACanvas.Font.Color := AColors.TextPrimary;
    TW := ACanvas.TextWidth(Lbl);
    TH := ACanvas.TextHeight(Lbl);
    if (CellW > TW + 4) and (CellH > TH + 2) then
      ACanvas.TextOut(CellR.Left + (CellW - TW) div 2, CellR.Top + (CellH - TH) div 2, Lbl);
  end;
end;

end.
