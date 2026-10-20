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

procedure DrawShowcaseText(const ACanvas: TCanvas; const ARect: TRect;
  const AText: string; const AFlags: Cardinal = DT_SINGLELINE or DT_VCENTER or DT_LEFT);
var
  R: TRect;
begin
  R := ARect;
  Windows.DrawText(ACanvas.Handle, PChar(AText), Length(AText), R, AFlags or DT_NOPREFIX);
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
  R: TRect;
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

    // Sidebar Navigation Buttons (Centered Vertically)
    TVeloxGdiPlus.DrawCard(C, Rect(14, 76, 196, 110),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.30), Colors.Accent, 6);
    C.Brush.Style := bsClear;
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(28, 76, 196, 110), 'Overview & Telemetry', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    TVeloxGdiPlus.DrawCard(C, Rect(14, 118, 196, 152), Colors.SidebarBg, Colors.Border, 6);
    C.Brush.Style := bsClear;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(28, 118, 196, 152), 'Virtual SparkGrid (O(1))', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    TVeloxGdiPlus.DrawCard(C, Rect(14, 160, 196, 194), Colors.SidebarBg, Colors.Border, 6);
    C.Brush.Style := bsClear;
    DrawShowcaseText(C, Rect(28, 160, 196, 194), 'Command Palette (Ctrl+K)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Sidebar Toggle Switches Preview (Pill & Label Vertically Centered to Each Other)
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(18, 222, 'FLUENT TOGGLE SWITCHES');

    // Toggle 1: Active
    TVeloxGdiPlus.DrawCard(C, Rect(18, 246, 60, 268), Colors.Accent, Colors.Accent, 11);
    TVeloxGdiPlus.DrawCard(C, Rect(42, 250, 56, 264), Colors.Background, Colors.Background, 7);
    C.Brush.Style := bsClear;
    C.Font.Size := 9;
    C.Font.Style := [];
    C.Font.Color := Colors.SidebarText;
    DrawShowcaseText(C, Rect(68, 246, 204, 268), 'Win11 Mica Backdrop', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Toggle 2: Active
    TVeloxGdiPlus.DrawCard(C, Rect(18, 280, 60, 302), Colors.Accent, Colors.Accent, 11);
    TVeloxGdiPlus.DrawCard(C, Rect(42, 284, 56, 298), Colors.Background, Colors.Background, 7);
    C.Brush.Style := bsClear;
    DrawShowcaseText(C, Rect(68, 280, 204, 302), 'Dark Scrollbars (135)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Top Header Bar
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(210, 0, W, 56));
    C.Brush.Style := bsClear;
    C.Font.Size := 13;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(230, 0, 570, 56), 'VeloxUI Live GDI+ Component Showcase', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Centered SearchBox in Header (Card at 14..42 -> Text Centered in 14..42)
    TVeloxGdiPlus.DrawCard(C, Rect(576, 14, 804, 42), Colors.SurfaceCard, Colors.Accent, 6);
    C.Brush.Style := bsClear;
    C.Font.Size := 9;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(590, 14, 796, 42), 'Search processes... (Ctrl+F)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Segmented Filter Chips in Header (Each Chip Centered Horizontally and Vertically)
    TVeloxGdiPlus.DrawCard(C, Rect(816, 14, 876, 42),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.32), Colors.Accent, 14);
    C.Brush.Style := bsClear;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(816, 14, 876, 42), 'All', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(884, 14, 984, 42), Colors.SurfaceCard, Colors.Border, 14);
    C.Brush.Style := bsClear;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(884, 14, 984, 42), 'Heavy RAM', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(992, 14, 1096, 42), Colors.SurfaceCard, Colors.Border, 14);
    C.Brush.Style := bsClear;
    DrawShowcaseText(C, Rect(992, 14, 1096, 42), 'Active CPU', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Prepare Telemetry Series
    SetLength(SparkA, 16);
    SetLength(SparkB, 16);
    for I := 0 to 15 do
    begin
      SparkA[I] := 28.0 + Sin(I * 0.55) * 22.0 + (I * 2.1);
      SparkB[I] := 16.0 + Cos(I * 0.45) * 14.0 + (I * 1.1);
    end;

    // 2. Top Row Cards: KPI Metric Card + Donut Gauge Card + Dual Sparkline + HeatGrid
    TVeloxGdiPlus.DrawCard(C, Rect(228, 70, 478, 206), Colors.SurfaceCard, Colors.Border, 8);
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(244, 82, 'CPU UTILIZATION');
    C.Font.Size := 22;
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(244, 98, '42.8%');
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(244, 142, '8 P-Cores / 16 Threads @ 5.1 GHz');
    TVeloxGdiPlus.DrawSparkline(C, Rect(364, 82, 464, 138), SparkA, Colors.Accent,
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.28));
    TVeloxGdiPlus.DrawProgressBar(C, Rect(244, 178, 462, 188), 42.8, Colors.Border, Colors.Accent);

    // Donut Gauge Card
    TVeloxGdiPlus.DrawCard(C, Rect(492, 70, 672, 206), Colors.SurfaceCard, Colors.Border, 8);
    TVeloxCharts.DrawDonutGauge(C, Rect(512, 78, 652, 198), 68.4, '68.4%', 'RAM Load', Colors, Colors.Success, 9.0);

    // Dual Sparkline Card
    TVeloxGdiPlus.DrawCard(C, Rect(686, 70, 896, 206), Colors.SurfaceCard, Colors.Border, 8);
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(700, 82, 'DUAL SPARKLINE (RX / TX)');
    C.Font.Size := 13;
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(700, 100, '148.2 MB/s');
    TVeloxCharts.DrawDualSparkline(C, Rect(700, 128, 882, 194),
      SparkA, SparkB, Colors.Accent, Colors.Success, Colors.SurfaceCard);

    // Per-Core HeatGrid Card
    TVeloxGdiPlus.DrawCard(C, Rect(910, 70, 1102, 206), Colors.SurfaceCard, Colors.Border, 8);
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    C.TextOut(924, 82, 'CORE HEATGRID (8 CORES)');
    SetLength(HeatVals, 8);
    HeatVals[0] := 92.0; HeatVals[1] := 74.0; HeatVals[2] := 45.0; HeatVals[3] := 28.0;
    HeatVals[4] := 64.0; HeatVals[5] := 19.0; HeatVals[6] := 88.0; HeatVals[7] := 35.0;
    TVeloxCharts.DrawHeatGrid(C, Rect(924, 104, 1088, 194), HeatVals, Colors, 4);

    // 3. Fluent Tab Strip Bar (TVeloxTabStrip Preview)
    // Tab 1: Selected
    TVeloxGdiPlus.DrawCard(C, Rect(228, 218, 332, 248),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.22), Colors.Accent, 6);
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(228, 218, 332, 248), 'Processes', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Tab 2: Normal
    TVeloxGdiPlus.DrawCard(C, Rect(338, 218, 436, 248), Colors.SurfaceCard, Colors.Border, 6);
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(338, 218, 436, 248), 'Services', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Tab 3: Normal
    TVeloxGdiPlus.DrawCard(C, Rect(442, 218, 552, 248), Colors.SurfaceCard, Colors.Border, 6);
    DrawShowcaseText(C, Rect(442, 218, 552, 248), 'Performance', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Tab 4: Add Button '+'
    TVeloxGdiPlus.DrawCard(C, Rect(558, 218, 588, 248), Colors.SurfaceCard, Colors.Border, 6);
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(558, 218, 588, 248), '+', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // 4. Bottom Virtual SparkGrid Table Preview (Cards + Column Headers)
    TVeloxGdiPlus.DrawCard(C, Rect(228, 254, 1102, 574), Colors.SurfaceCard, Colors.Border, 8);
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(230, 256, 1100, 288));

    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(244, 256, 450, 288), 'PROCESS NAME', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    DrawShowcaseText(C, Rect(454, 256, 574, 288), 'STATUS', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    DrawShowcaseText(C, Rect(584, 256, 750, 288), 'CPU HEATBAR', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    DrawShowcaseText(C, Rect(764, 256, 944, 288), 'WORKING SET (RAM) ' + VELOX_ARROW_DESC, DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    DrawShowcaseText(C, Rect(956, 256, 1086, 288), 'LIVE TREND', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    for I := 0 to 5 do
    begin
      RowY := 294 + I * 44;
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
      R := Rect(244, RowY, 440, RowY + 40);
      case I of
        0: DrawShowcaseText(C, R, 'novamonitor.exe', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
        1: DrawShowcaseText(C, R, '   ' + VELOX_TREE_BRANCH + 'velox-worker.exe', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
        2: DrawShowcaseText(C, R, 'pwsh.exe', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
        3: DrawShowcaseText(C, R, 'lazarus.exe', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
        4: DrawShowcaseText(C, R, 'dwm.exe', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
        5: DrawShowcaseText(C, R, 'svchost.exe', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
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

    // 5. Floating Non-Blocking Toast Notification Preview (Bottom-Right, Centered Vertically)
    TVeloxGdiPlus.DrawCard(C, Rect(740, 506, 1086, 564), Colors.Surface, Colors.Warning, 8);
    TVeloxGdiPlus.DrawCard(C, Rect(748, 516, 753, 554), Colors.Warning, Colors.Warning, 2);
    C.Brush.Style := bsClear;
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(764, 514, 1076, 534), 'TVeloxToast — Sustained Threshold Alert', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(764, 536, 1076, 554), 'Render latency: 0.12 ms | 100% Zero-Flicker GDI+', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    Result := SaveBitmapToPng(Bmp, AFilePath);
  finally
    Bmp.Free;
  end;
end;

end.
