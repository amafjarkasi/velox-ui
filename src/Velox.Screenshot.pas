unit Velox.Screenshot;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Screenshot
  Purpose:
    1. Programmatic Control & Window Screenshot Exporter (`TVeloxScreenshot`)
       that captures any `TWinControl` / `TForm` (`PaintTo` / `BitBlt`) or
       `TBitmap` directly to PNG (`.png`) or BMP (`.bmp`).
    2. Automated Component Showcase Gallery Renderer (`RenderComponentShowcase`)
       that renders a live 1120x620 Windows 11 Dark Mode preview of all VeloxUI
       visual components (KPI Cards, Donut Gauges, Dual Sparklines, HeatGrids,
       Inline SparkGrid Bars, Filter Chips, and Toasts) to an image file for
       documentation and visual regression testing.
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
  Velox.GdiPlus,
  Velox.Charts,
  Velox.SparkGrid;

type
  /// <summary>
  /// Control/Form screenshot capture & automated component showcase generator
  /// </summary>
  TVeloxScreenshot = class
  public
    /// <summary>
    /// Captures any TWinControl or TForm into a new TBitmap via PaintTo.
    /// Caller is responsible for freeing the returned TBitmap.
    /// </summary>
    class function CaptureControlToBitmap(const AControl: TWinControl): TBitmap; static;

    /// <summary>
    /// Saves a TBitmap to a PNG (.png) or BMP (.bmp) file.
    /// </summary>
    class function SaveBitmapToPng(const ABitmap: TBitmap; const AFilePath: string): Boolean; static;

    /// <summary>
    /// Captures any TWinControl or TForm directly to a PNG file in 1 call.
    /// </summary>
    class function CaptureControlToPng(const AControl: TWinControl; const AFilePath: string): Boolean; static;

    /// <summary>
    /// Renders a comprehensive 1120x620 VeloxUI Component Gallery Showcase
    /// using live GDI+ calls and saves it as a crisp PNG image.
    /// </summary>
    class function RenderComponentShowcase(const AFilePath: string;
      const ATheme: TVeloxTheme = vtDark): Boolean; static;
  end;

implementation

{ TVeloxScreenshot }

class function TVeloxScreenshot.CaptureControlToBitmap(const AControl: TWinControl): TBitmap;
begin
  Result := TBitmap.Create;
  if not Assigned(AControl) then Exit;
  Result.PixelFormat := pf24bit;
  Result.SetSize(AControl.Width, AControl.Height);
  Result.Canvas.Brush.Color := AControl.Color;
  Result.Canvas.FillRect(Rect(0, 0, AControl.Width, AControl.Height));
  AControl.PaintTo(Result.Canvas.Handle, 0, 0);
end;

class function TVeloxScreenshot.SaveBitmapToPng(const ABitmap: TBitmap;
  const AFilePath: string): Boolean;
var
  Png: TPortableNetworkGraphic;
  Dir: string;
begin
  Result := False;
  if (ABitmap = nil) or (AFilePath = '') then Exit;
  Dir := ExtractFileDir(AFilePath);
  if (Dir <> '') and (not DirectoryExists(Dir)) then
    ForceDirectories(Dir);

  Png := TPortableNetworkGraphic.Create;
  try
    Png.Assign(ABitmap);
    Png.SaveToFile(AFilePath);
    Result := FileExists(AFilePath);
  finally
    Png.Free;
  end;
end;

class function TVeloxScreenshot.CaptureControlToPng(const AControl: TWinControl;
  const AFilePath: string): Boolean;
var
  Bmp: TBitmap;
begin
  Result := False;
  if not Assigned(AControl) then Exit;
  Bmp := CaptureControlToBitmap(AControl);
  try
    Result := SaveBitmapToPng(Bmp, AFilePath);
  finally
    Bmp.Free;
  end;
end;

class function TVeloxScreenshot.RenderComponentShowcase(const AFilePath: string;
  const ATheme: TVeloxTheme): Boolean;
const
  W = 1120;
  H = 620;
var
  Bmp: TBitmap;
  C: TCanvas;
  Colors: TVeloxThemeColors;
  SparkA, SparkB, HeatVals: TSingleDynArray;
  I, RowY: Integer;
begin
  Colors := TVeloxUtils.GetThemeColors(ATheme);
  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(W, H);
    C := Bmp.Canvas;

    // 1. App Shell Background + Left Sidebar + Top Header
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Background;
    C.FillRect(Rect(0, 0, W, H));

    // Left Sidebar
    C.Brush.Color := Colors.SidebarBg;
    C.FillRect(Rect(0, 0, 210, H));
    C.Brush.Style := bsClear;
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 15;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.SidebarText;
    C.TextOut(20, 18, 'VeloxUI Shell');
    C.Font.Size := 8;
    C.Font.Color := Colors.Accent;
    C.TextOut(20, 44, 'LIVE COMPONENT GALLERY');

    // Sidebar Navigation Buttons
    TVeloxGdiPlus.DrawCard(C, Rect(14, 76, 196, 110),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.30), Colors.Accent, 6);
    C.Brush.Style := bsClear;
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(28, 85, 'Overview & Telemetry');

    TVeloxGdiPlus.DrawCard(C, Rect(14, 118, 196, 152), Colors.SidebarBg, Colors.Border, 6);
    C.Brush.Style := bsClear;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(28, 127, 'Virtual SparkGrid (O(1))');

    TVeloxGdiPlus.DrawCard(C, Rect(14, 160, 196, 194), Colors.SidebarBg, Colors.Border, 6);
    C.Brush.Style := bsClear;
    C.TextOut(28, 169, 'Command Palette (Ctrl+K)');

    // Sidebar Toggle Switch Preview
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(18, 224, 'FLUENT TOGGLE SWITCHES');

    TVeloxGdiPlus.DrawCard(C, Rect(18, 248, 60, 270), Colors.Accent, Colors.Accent, 11);
    TVeloxGdiPlus.DrawCard(C, Rect(42, 252, 56, 266), Colors.Background, Colors.Background, 7);
    C.Brush.Style := bsClear;
    C.Font.Size := 9;
    C.Font.Style := [];
    C.Font.Color := Colors.SidebarText;
    C.TextOut(68, 250, 'Win11 Mica Backdrop');

    TVeloxGdiPlus.DrawCard(C, Rect(18, 282, 60, 304), Colors.Accent, Colors.Accent, 11);
    TVeloxGdiPlus.DrawCard(C, Rect(42, 286, 56, 300), Colors.Background, Colors.Background, 7);
    C.Brush.Style := bsClear;
    C.TextOut(68, 284, 'Dark Scrollbars (135)');

    // Top Header Bar
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(210, 0, W, 56));
    C.Brush.Style := bsClear;
    C.Font.Size := 13;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(230, 16, 'VeloxUI Live GDI+ Component Showcase');

    // Centered SearchBox in Header
    TVeloxGdiPlus.DrawCard(C, Rect(580, 14, 820, 42), Colors.SurfaceCard, Colors.Accent, 6);
    C.Brush.Style := bsClear;
    C.Font.Size := 9;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(592, 20, 'Search processes... (Ctrl+F)');

    // Segmented Filter Chips in Header
    TVeloxGdiPlus.DrawCard(C, Rect(836, 14, 896, 42),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.32), Colors.Accent, 14);
    C.Brush.Style := bsClear;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(856, 20, 'All');

    TVeloxGdiPlus.DrawCard(C, Rect(904, 14, 998, 42), Colors.SurfaceCard, Colors.Border, 14);
    C.Brush.Style := bsClear;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(918, 20, 'Heavy RAM');

    TVeloxGdiPlus.DrawCard(C, Rect(1006, 14, 1100, 42), Colors.SurfaceCard, Colors.Border, 14);
    C.Brush.Style := bsClear;
    C.TextOut(1020, 20, 'Active CPU');

    // Prepare Telemetry Series
    SetLength(SparkA, 16);
    SetLength(SparkB, 16);
    for I := 0 to 15 do
    begin
      SparkA[I] := 28.0 + Sin(I * 0.55) * 22.0 + (I * 2.1);
      SparkB[I] := 16.0 + Cos(I * 0.45) * 14.0 + (I * 1.1);
    end;

    // 2. Top Row Cards: KPI Metric Card + Donut Gauge Card + Dual Sparkline + HeatGrid
    TVeloxGdiPlus.DrawCard(C, Rect(228, 72, 478, 212), Colors.SurfaceCard, Colors.Border, 8);
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(244, 84, 'CPU UTILIZATION');
    C.Font.Size := 22;
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(244, 102, '42.8%');
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(244, 146, '8 P-Cores / 16 Threads @ 5.1 GHz');
    TVeloxGdiPlus.DrawSparkline(C, Rect(364, 84, 464, 140), SparkA, Colors.Accent,
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.28));
    TVeloxGdiPlus.DrawProgressBar(C, Rect(244, 184, 462, 194), 42.8, Colors.Border, Colors.Accent);

    // Donut Gauge Card
    TVeloxGdiPlus.DrawCard(C, Rect(492, 72, 672, 212), Colors.SurfaceCard, Colors.Border, 8);
    TVeloxCharts.DrawDonutGauge(C, Rect(512, 82, 652, 202), 68.4, '68.4%', 'RAM Load', Colors, Colors.Success, 9.0);

    // Dual Sparkline Card
    TVeloxGdiPlus.DrawCard(C, Rect(686, 72, 896, 212), Colors.SurfaceCard, Colors.Border, 8);
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(700, 84, 'DUAL SPARKLINE (RX / TX)');
    C.Font.Size := 13;
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(700, 102, '148.2 MB/s');
    TVeloxCharts.DrawDualSparkline(C, Rect(700, 132, 882, 198),
      SparkA, SparkB, Colors.Accent, Colors.Success, Colors.SurfaceCard);

    // Per-Core HeatGrid Card
    TVeloxGdiPlus.DrawCard(C, Rect(910, 72, 1102, 212), Colors.SurfaceCard, Colors.Border, 8);
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(924, 84, 'CORE HEATGRID (8 CORES)');
    SetLength(HeatVals, 8);
    HeatVals[0] := 92.0; HeatVals[1] := 74.0; HeatVals[2] := 45.0; HeatVals[3] := 28.0;
    HeatVals[4] := 64.0; HeatVals[5] := 19.0; HeatVals[6] := 88.0; HeatVals[7] := 35.0;
    TVeloxCharts.DrawHeatGrid(C, Rect(924, 106, 1088, 198), HeatVals, Colors, 4);

    // 3. Bottom Virtual SparkGrid Table Preview
    TVeloxGdiPlus.DrawCard(C, Rect(228, 228, 1102, 572), Colors.SurfaceCard, Colors.Border, 8);
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(230, 230, 1100, 264));

    C.Brush.Style := bsClear;
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(244, 239, 'PROCESS NAME');
    C.TextOut(460, 239, 'STATUS');
    C.TextOut(590, 239, 'CPU HEATBAR');
    C.TextOut(770, 239, 'WORKING SET (RAM) ' + VELOX_ARROW_DESC);
    C.TextOut(960, 239, 'LIVE TREND');

    for I := 0 to 5 do
    begin
      RowY := 270 + I * 44;
      if I = 1 then
      begin
        C.Brush.Style := bsSolid;
        C.Brush.Color := TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.16);
        C.FillRect(Rect(232, RowY, 1098, RowY + 40));
      end;

      C.Brush.Style := bsClear;
      C.Font.Name := 'Segoe UI';
      C.Font.Size := 9;
      C.Font.Style := [fsBold];
      C.Font.Color := Colors.TextPrimary;
      case I of
        0: C.TextOut(244, RowY + 11, 'novamonitor.exe');
        1: C.TextOut(244, RowY + 11, '   ' + VELOX_TREE_BRANCH + 'velox-worker.exe');
        2: C.TextOut(244, RowY + 11, 'pwsh.exe');
        3: C.TextOut(244, RowY + 11, 'lazarus.exe');
        4: C.TextOut(244, RowY + 11, 'dwm.exe');
        5: C.TextOut(244, RowY + 11, 'svchost.exe');
      end;

      if I = 3 then
        TVeloxCellRenderer.DrawStatusDotCell(C, Rect(454, RowY + 4, 576, RowY + 36), 'High Load', vsWarning, Colors)
      else
        TVeloxCellRenderer.DrawStatusDotCell(C, Rect(454, RowY + 4, 576, RowY + 36), 'Normal', vsNormal, Colors);

      TVeloxCellRenderer.DrawInlineBar(C, Rect(584, RowY + 6, 750, RowY + 34),
        85.0 - I * 13.0, Format('%.1f%%', [85.0 - I * 13.0]), Colors,
         TVeloxSeverity(Ord(I = 0) * Ord(vsWarning) + Ord(I <> 0) * Ord(vsNormal)));

      TVeloxCellRenderer.DrawInlineBar(C, Rect(764, RowY + 6, 944, RowY + 34),
        72.0 - I * 10.0, Format('%d MB', [1420 - I * 210]), Colors, vsNormal);

      TVeloxCellRenderer.DrawInlineSparkline(C, Rect(956, RowY + 6, 1086, RowY + 34),
        SparkA, Colors, Colors.Accent);
    end;

    // 4. Floating Non-Blocking Toast Notification Preview (Bottom-Right)
    TVeloxGdiPlus.DrawCard(C, Rect(740, 500, 1086, 560), Colors.Surface, Colors.Warning, 8);
    TVeloxGdiPlus.DrawCard(C, Rect(748, 510, 753, 550), Colors.Warning, Colors.Warning, 2);
    C.Brush.Style := bsClear;
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(764, 510, 'TVeloxToast — Sustained Threshold Alert');
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(764, 530, 'Render latency: 0.12 ms | 100% Zero-Flicker GDI+');

    Result := SaveBitmapToPng(Bmp, AFilePath);
  finally
    Bmp.Free;
  end;
end;

end.
