unit Velox.SparkGrid;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.SparkGrid
  Purpose:
    Inline Table Cell Micro-Bars, Sparklines & Status Pills (`TVeloxCellRenderer`)
    inspired by `winsiderss/systeminformer` and `JAM-Software/Virtual-TreeView`.
    Renders proportional utilization heat-bars, mini sparklines, and status
    dots directly inside `TListView` / grid cell rectangles.
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
  /// Inline cell renderer for proportional heat-bars, sparklines, and status dots
  /// </summary>
  TVeloxCellRenderer = class
  public
    /// <summary>
    /// Draws a System Informer-style proportional background heat bar inside
    /// a grid cell with right-aligned or left-aligned text overlay.
    /// </summary>
    class procedure DrawInlineBar(const ACanvas: TCanvas; const ACellRect: TRect;
      const APercent: Single; const AText: string;
      const AColors: TVeloxThemeColors;
      const ASeverity: TVeloxSeverity = vsNormal;
      const ARightAlignText: Boolean = True); static;

    /// <summary>
    /// Draws an inline mini sparkline inside a grid cell rectangle.
    /// </summary>
    class procedure DrawInlineSparkline(const ACanvas: TCanvas; const ACellRect: TRect;
      const AValues: TSingleDynArray; const AColors: TVeloxThemeColors;
      const AAccentColor: TColor); static;

    /// <summary>
    /// Draws a status dot + label inside a grid cell (e.g. `● Running`).
    /// </summary>
    class procedure DrawStatusDotCell(const ACanvas: TCanvas; const ACellRect: TRect;
      const AText: string; const ASeverity: TVeloxSeverity;
      const AColors: TVeloxThemeColors); static;
  end;

implementation

{ TVeloxCellRenderer }

class procedure TVeloxCellRenderer.DrawInlineBar(const ACanvas: TCanvas;
  const ACellRect: TRect; const APercent: Single; const AText: string;
  const AColors: TVeloxThemeColors; const ASeverity: TVeloxSeverity;
  const ARightAlignText: Boolean);
var
  BarR, FillR: TRect;
  Clamped: Single;
  FillW, TW, TH, TextX, TextY: Integer;
  AccentCol, FillCol: TColor;
begin
  if (ACellRect.Right - ACellRect.Left < 16) or (ACellRect.Bottom - ACellRect.Top < 10) then
    Exit;

  BarR := Rect(ACellRect.Left + 3, ACellRect.Top + 3, ACellRect.Right - 3, ACellRect.Bottom - 3);
  Clamped := TVeloxUtils.ClampSingle(APercent, 0.0, 100.0);

  AccentCol := TVeloxUtils.SeverityToColor(ASeverity, AColors);
  FillCol := TVeloxUtils.BlendColor(AColors.SurfaceCard, AccentCol, 0.32);

  TVeloxGdiPlus.DrawCard(ACanvas, BarR, AColors.SurfaceCard, AColors.Border, 3);

  FillW := Round(((BarR.Right - BarR.Left - 2) * Clamped) / 100.0);
  if FillW > 2 then
  begin
    FillR := Rect(BarR.Left + 1, BarR.Top + 1, BarR.Left + 1 + FillW, BarR.Bottom - 1);
    TVeloxGdiPlus.DrawCard(ACanvas, FillR, FillCol, FillCol, 2);
  end;

  if AText <> '' then
  begin
    ACanvas.Brush.Style := bsClear;
    ACanvas.Font.Name := 'Segoe UI';
    ACanvas.Font.Size := 8;
    ACanvas.Font.Style := [fsBold];
    ACanvas.Font.Color := AColors.TextPrimary;
    TW := ACanvas.TextWidth(AText);
    TH := ACanvas.TextHeight(AText);
    TextY := ACellRect.Top + ((ACellRect.Bottom - ACellRect.Top) - TH) div 2;
    if ARightAlignText then
      TextX := BarR.Right - TW - 6
    else
      TextX := BarR.Left + 6;
    ACanvas.TextOut(TextX, TextY, AText);
  end;
end;

class procedure TVeloxCellRenderer.DrawInlineSparkline(const ACanvas: TCanvas;
  const ACellRect: TRect; const AValues: TSingleDynArray;
  const AColors: TVeloxThemeColors; const AAccentColor: TColor);
var
  SparkR: TRect;
begin
  if Length(AValues) < 2 then Exit;
  SparkR := Rect(ACellRect.Left + 4, ACellRect.Top + 3, ACellRect.Right - 4, ACellRect.Bottom - 3);
  TVeloxGdiPlus.DrawSparkline(ACanvas, SparkR, AValues, AAccentColor,
    TVeloxUtils.BlendColor(AColors.SurfaceCard, AAccentColor, 0.25));
end;

class procedure TVeloxCellRenderer.DrawStatusDotCell(const ACanvas: TCanvas;
  const ACellRect: TRect; const AText: string; const ASeverity: TVeloxSeverity;
  const AColors: TVeloxThemeColors);
var
  DotR: TRect;
  DotCol: TColor;
  MidY, TH: Integer;
begin
  DotCol := TVeloxUtils.SeverityToColor(ASeverity, AColors);
  MidY := ACellRect.Top + (ACellRect.Bottom - ACellRect.Top) div 2;
  DotR := Rect(ACellRect.Left + 6, MidY - 4, ACellRect.Left + 14, MidY + 4);
  TVeloxGdiPlus.DrawCard(ACanvas, DotR, DotCol, DotCol, 4);

  if AText <> '' then
  begin
    ACanvas.Brush.Style := bsClear;
    ACanvas.Font.Name := 'Segoe UI';
    ACanvas.Font.Size := 9;
    ACanvas.Font.Style := [];
    ACanvas.Font.Color := AColors.TextPrimary;
    TH := ACanvas.TextHeight(AText);
    ACanvas.TextOut(ACellRect.Left + 20, MidY - (TH div 2), AText);
  end;
end;

end.
