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

    /// <summary>
    /// Renders a comprehensive 1120x640 VeloxUI Controls Studio Showcase
    /// (PropertyGrid, Timeline, TagInput, Stepper, Breadcrumb, Rating,
    /// Pagination, DiffView & GlassPanel) and saves it as a crisp PNG.
    /// </summary>
    class function RenderStudioShowcase(const AFilePath: string;
      const ATheme: TVeloxTheme = vtDark): Boolean; static;

    /// <summary>
    /// Renders an end-to-end pixel-perfect screenshot of the REST API Workbench & Debugger Studio (TVeloxRestStudio)
    /// </summary>
    class function RenderRestStudioShowcase(const AFilePath: string;
      const ATheme: TVeloxTheme = vtDark): Boolean; static;

    /// <summary>
    /// Renders an end-to-end pixel-perfect screenshot of the Mission Control Telemetry Wall (TVeloxTelemetryWall)
    /// </summary>
    class function RenderTelemetryWallShowcase(const AFilePath: string;
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
  WStr: WideString;
begin
  R := ARect;
  WStr := UTF8Decode(AText);
  Windows.DrawTextW(ACanvas.Handle, PWideChar(WStr), Length(WStr), R, AFlags or DT_NOPREFIX);
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

procedure DrawStarShape(const ACanvas: TCanvas; const ACx, ACy, ARadius: Integer;
  const AFillColor, ABorderColor: TColor);
var
  Pts: array[0..9] of TPoint;
  Step: Integer;
  Angle, R, InnerR: Double;
begin
  InnerR := ARadius * 0.44;
  for Step := 0 to 9 do
  begin
    if (Step mod 2) = 0 then
      R := ARadius
    else
      R := InnerR;
    Angle := (Step * 36 - 90) * (PI / 180.0);
    Pts[Step].X := ACx + Round(R * Cos(Angle));
    Pts[Step].Y := ACy + Round(R * Sin(Angle));
  end;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := AFillColor;
  ACanvas.Pen.Color := ABorderColor;
  ACanvas.Pen.Width := 1;
  ACanvas.Polygon(Pts);
end;

class function TVeloxScreenshot.RenderStudioShowcase(const AFilePath: string;
  const ATheme: TVeloxTheme): Boolean;
const
  W = 1120;
  H = 640;
var
  Bmp: TBitmap;
  C: TCanvas;
  Colors: TVeloxThemeColors;
  I, RowY, DotX, DotY, DotR: Integer;
  DelBg, AddBg, DelSignCol, AddSignCol, PillBg, PillBorder, PillText: TColor;
begin
  Colors := TVeloxUtils.GetThemeColors(ATheme);

  if ATheme = vtLight then
  begin
    DelBg := $E2E2FE;
    AddBg := $E7FCDC;
    DelSignCol := $2626DC;
    AddSignCol := $4AA316;
    PillBg := $E2E8F0;
    PillBorder := Colors.Border;
    PillText := Colors.TextPrimary;
  end
  else
  begin
    DelBg := $1F1836;
    AddBg := $1B351E;
    DelSignCol := $7171F8;
    AddSignCol := $99D334;
    PillBg := $1E293B;
    PillBorder := $38BDF8;
    PillText := $F8FAFC;
  end;

  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(W, H);
    C := Bmp.Canvas;

    // Background
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Background;
    C.FillRect(Rect(0, 0, W, H));

    // 1. Top Header Bar
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(0, 0, W, 52));

    C.Brush.Style := bsClear;
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 13;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(20, 0, 560, 52), 'VeloxUI Controls Studio - PropertyGrid, Timeline, DiffView & Diagnostics',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Header Specification Badge on Right
    TVeloxGdiPlus.DrawCard(C, Rect(830, 12, 1100, 40), Colors.SurfaceCard, Colors.Accent, 6);
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(830, 12, 1100, 40), '65 ZERO-DEPENDENCY NATIVE PASCAL MODULES',
      DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // 2. Left Column: Fluent Property Inspector Grid (TVeloxPropertyGrid)
    TVeloxGdiPlus.DrawCard(C, Rect(16, 64, 380, 624), Colors.SurfaceCard, Colors.Border, 8);

    // PropertyGrid Title
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(18, 66, 378, 96));
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(30, 66, 370, 96), 'PROPERTY INSPECTOR (TVeloxPropertyGrid)',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Category 1: Application Architecture (Expanded, MidY = 114)
    TVeloxGdiPlus.DrawCard(C, Rect(20, 102, 376, 126),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.15), Colors.Border, 4);
    C.Pen.Color := Colors.Accent;
    C.Pen.Width := 2;
    C.MoveTo(30, 114);
    C.LineTo(38, 114);
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(48, 102, 370, 126), 'Application Architecture', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Prop 1.1: Framework Name
    DrawShowcaseText(C, Rect(36, 130, 180, 154), 'Framework', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Style := [];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(190, 130, 360, 154), 'VeloxUI v2.4', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Prop 1.2: Theme Mode
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 158, 180, 182), 'Theme Mode', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    TVeloxGdiPlus.DrawCard(C, Rect(190, 160, 246, 180), $10B981, $10B981, 4);
    C.Font.Size := 8;
    C.Font.Color := $FFFFFF;
    DrawShowcaseText(C, Rect(190, 160, 246, 180), 'vtDark', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Prop 1.3: Accent Color
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 186, 180, 210), 'Accent Color', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Brush.Style := bsSolid;
    C.Brush.Color := $38BDF8;
    C.Pen.Color := Colors.Border;
    C.Rectangle(190, 190, 208, 206);
    C.Brush.Style := bsClear;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(216, 186, 360, 210), '#38BDF8', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Prop 1.4: Zero Dependencies
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 214, 180, 238), 'Zero Dependency', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Style := [];
    C.Font.Color := $10B981;
    DrawShowcaseText(C, Rect(190, 214, 360, 238), 'True (100% Native)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Category 2: Systems Diagnostics & Telemetry (Expanded, MidY = 258)
    TVeloxGdiPlus.DrawCard(C, Rect(20, 246, 376, 270),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.15), Colors.Border, 4);
    C.Pen.Color := Colors.Accent;
    C.Pen.Width := 2;
    C.MoveTo(30, 258);
    C.LineTo(38, 258);
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(48, 246, 370, 270), 'Systems Diagnostics & SCM', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Prop 2.1: Polling Interval
    DrawShowcaseText(C, Rect(36, 274, 180, 298), 'Polling Rate', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(190, 274, 360, 298), '250 ms (slice: 50ms)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Prop 2.2: Working Set
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 302, 180, 326), 'Working Set', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Style := [];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(190, 302, 360, 326), '48.2 MB (Commit: 62 MB)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Prop 2.3: Windows Service
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 330, 180, 354), 'SCM Service', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Style := [];
    C.Font.Color := $10B981;
    DrawShowcaseText(C, Rect(190, 330, 360, 354), 'LanmanServer (Running)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Prop 2.4: Autostart (HKCU)
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 358, 180, 382), 'Autostart (Run)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(190, 358, 360, 382), 'HKCU\...\Run (Active)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Prop 2.5: Crypto Hashing
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 386, 180, 410), 'Crypto Engine', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(190, 386, 360, 410), 'BCrypt CNG SHA-256', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Category 3: Undo/Redo & Transactions (Collapsed, MidY = 430)
    TVeloxGdiPlus.DrawCard(C, Rect(20, 418, 376, 442), Colors.SurfaceCard, Colors.Border, 4);
    C.Pen.Color := Colors.Accent;
    C.Pen.Width := 2;
    C.MoveTo(30, 430);
    C.LineTo(38, 430);
    C.MoveTo(34, 426);
    C.LineTo(34, 435);
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(48, 418, 370, 442), 'Command Transactions & Undo Stack', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Category 4: Storage & IPC (Collapsed, MidY = 462)
    TVeloxGdiPlus.DrawCard(C, Rect(20, 450, 376, 474), Colors.SurfaceCard, Colors.Border, 4);
    C.Pen.Color := Colors.Accent;
    C.Pen.Width := 2;
    C.MoveTo(30, 462);
    C.LineTo(38, 462);
    C.MoveTo(34, 458);
    C.LineTo(34, 467);
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(48, 450, 370, 474), 'Named Mutex IPC & Single Instance', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 3. Middle Top Panel: Interactive Controls (Breadcrumb, Stepper, TagInput, Rating, Pagination)
    TVeloxGdiPlus.DrawCard(C, Rect(396, 64, 746, 362), Colors.SurfaceCard, Colors.Border, 8);

    // Title
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(398, 66, 744, 96));
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(408, 66, 736, 96), 'INTERACTIVE DEVELOPER CONTROLS & WIDGETS',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 3.1 Explorer Breadcrumb Navigation (TVeloxBreadcrumb, MidY = 119)
    TVeloxGdiPlus.DrawCard(C, Rect(408, 104, 734, 134), Colors.Background, Colors.Border, 6);
    C.Font.Size := 9;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(418, 104, 482, 134), 'Workspace', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Vector Chevron 1 (MidX = 492, MidY = 119)
    C.Pen.Color := Colors.TextSecondary;
    C.Pen.Width := 1;
    C.MoveTo(490, 115); C.LineTo(494, 119); C.LineTo(490, 123);

    DrawShowcaseText(C, Rect(504, 104, 574, 134), 'Diagnostics', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Vector Chevron 2 (MidX = 586, MidY = 119)
    C.MoveTo(584, 115); C.LineTo(588, 119); C.LineTo(584, 123);

    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(598, 104, 726, 134), 'Process Tree (dwm.exe)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 3.2 Pipeline Setup Stepper (TVeloxStepper, MidY = 156)
    // Step 1: Completed
    TVeloxGdiPlus.DrawCard(C, Rect(416, 146, 436, 166), $10B981, $10B981, 10);
    // Crisp checkmark inside circle (center: 426, 156)
    C.Pen.Color := $FFFFFF;
    C.Pen.Width := 2;
    C.MoveTo(422, 156);
    C.LineTo(425, 159);
    C.LineTo(431, 152);

    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(442, 144, 498, 168), 'Download', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Step Connector 1 -> 2
    C.Pen.Color := $10B981;
    C.Pen.Width := 2;
    C.MoveTo(504, 156);
    C.LineTo(526, 156);

    // Step 2: Active
    TVeloxGdiPlus.DrawCard(C, Rect(532, 146, 552, 166), Colors.Accent, Colors.Accent, 10);
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Background;
    DrawShowcaseText(C, Rect(532, 146, 552, 166), '2', DT_SINGLELINE or DT_VCENTER or DT_CENTER);
    C.Font.Size := 9;
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(558, 144, 608, 168), 'Verify', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Step Connector 2 -> 3
    C.Pen.Color := Colors.Border;
    C.Pen.Width := 2;
    C.MoveTo(614, 156);
    C.LineTo(636, 156);

    // Step 3: Pending
    TVeloxGdiPlus.DrawCard(C, Rect(642, 146, 662, 166), Colors.SurfaceCard, Colors.Border, 10);
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(642, 146, 662, 166), '3', DT_SINGLELINE or DT_VCENTER or DT_CENTER);
    C.Font.Size := 9;
    C.Font.Style := [];
    DrawShowcaseText(C, Rect(668, 144, 724, 168), 'Deploy', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 3.3 Pill Tokenizer & Tag Input (TVeloxTagInput, MidY = 197)
    TVeloxGdiPlus.DrawCard(C, Rect(408, 178, 734, 216), Colors.Background, Colors.Accent, 6);

    // Pill 1: 'delphi'
    TVeloxGdiPlus.DrawCard(C, Rect(416, 185, 482, 209), PillBg, PillBorder, 8);
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := PillText;
    DrawShowcaseText(C, Rect(424, 185, 464, 209), 'delphi', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Pen.Color := $94A3B8;
    C.Pen.Width := 1;
    C.MoveTo(469, 194); C.LineTo(475, 200);
    C.MoveTo(474, 194); C.LineTo(468, 200);

    // Pill 2: 'pascal'
    TVeloxGdiPlus.DrawCard(C, Rect(488, 185, 554, 209), PillBg, PillBorder, 8);
    DrawShowcaseText(C, Rect(496, 185, 536, 209), 'pascal', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.MoveTo(541, 194); C.LineTo(547, 200);
    C.MoveTo(546, 194); C.LineTo(540, 200);

    // Pill 3: 'fluent-ui'
    TVeloxGdiPlus.DrawCard(C, Rect(560, 185, 638, 209), PillBg, PillBorder, 8);
    DrawShowcaseText(C, Rect(568, 185, 620, 209), 'fluent-ui', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.MoveTo(625, 194); C.LineTo(631, 200);
    C.MoveTo(630, 194); C.LineTo(624, 200);

    // Pill 4: 'zero-dep'
    TVeloxGdiPlus.DrawCard(C, Rect(644, 185, 724, 209), PillBg, PillBorder, 8);
    DrawShowcaseText(C, Rect(652, 185, 706, 209), 'zero-dep', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.MoveTo(711, 194); C.LineTo(717, 200);
    C.MoveTo(716, 194); C.LineTo(710, 200);

    // 3.4 Star & Severity Rating (TVeloxRating, MidY = 240)
    DrawStarShape(C, 424, 240, 8, $F59E0B, $F59E0B);
    DrawStarShape(C, 444, 240, 8, $F59E0B, $F59E0B);
    DrawStarShape(C, 464, 240, 8, $F59E0B, $F59E0B);
    DrawStarShape(C, 484, 240, 8, $F59E0B, $F59E0B);
    DrawStarShape(C, 504, 240, 8, Colors.SurfaceCard, $F59E0B);

    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(522, 224, 730, 256), '4.5 / 5.0 (High Precision Rating)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 3.5 Compact Pagination Bar (TVeloxPagination, MidY = 285)
    TVeloxGdiPlus.DrawCard(C, Rect(408, 266, 734, 304), Colors.Background, Colors.Border, 6);
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(418, 266, 550, 304), 'Showing 1-25 of 120 items', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Prev Button '<'
    TVeloxGdiPlus.DrawCard(C, Rect(556, 273, 580, 297), Colors.SurfaceCard, Colors.Border, 4);
    C.Pen.Color := Colors.TextSecondary;
    C.Pen.Width := 2;
    C.MoveTo(570, 281); C.LineTo(566, 285); C.LineTo(570, 289);

    // Page 1 (Active)
    TVeloxGdiPlus.DrawCard(C, Rect(586, 273, 610, 297), Colors.Accent, Colors.Accent, 4);
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Background;
    DrawShowcaseText(C, Rect(586, 273, 610, 297), '1', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Page 2
    TVeloxGdiPlus.DrawCard(C, Rect(616, 273, 640, 297), Colors.SurfaceCard, Colors.Border, 4);
    C.Font.Style := [];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(616, 273, 640, 297), '2', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Page 3
    TVeloxGdiPlus.DrawCard(C, Rect(646, 273, 670, 297), Colors.SurfaceCard, Colors.Border, 4);
    DrawShowcaseText(C, Rect(646, 273, 670, 297), '3', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Page 5
    TVeloxGdiPlus.DrawCard(C, Rect(676, 273, 700, 297), Colors.SurfaceCard, Colors.Border, 4);
    DrawShowcaseText(C, Rect(676, 273, 700, 297), '5', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Next Button '>'
    TVeloxGdiPlus.DrawCard(C, Rect(706, 273, 730, 297), Colors.SurfaceCard, Colors.Border, 4);
    C.Pen.Color := Colors.TextSecondary;
    C.Pen.Width := 2;
    C.MoveTo(716, 281); C.LineTo(720, 285); C.LineTo(716, 289);

    // 3.6 Translucent Acrylic Glass Container (TVeloxGlassPanel, MidY = 332)
    TVeloxGdiPlus.DrawCard(C, Rect(408, 314, 734, 350), Colors.SurfaceCard, Colors.Border, 6);
    // Specular top highlight reflection
    C.Pen.Color := $50FFFFFF;
    C.Pen.Width := 1;
    C.MoveTo(414, 315);
    C.LineTo(728, 315);
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(420, 314, 724, 350), 'TVeloxGlassPanel - Translucent Fluent Acrylic Panel with Specular Highlight',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 4. Right Column: Chronological Audit Timeline (TVeloxTimeline)
    TVeloxGdiPlus.DrawCard(C, Rect(762, 64, 1104, 362), Colors.SurfaceCard, Colors.Border, 8);

    // Title
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(764, 66, 1102, 96));
    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(776, 66, 1094, 96), 'EVENT AUDIT TIMELINE (TVeloxTimeline)',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    DotX := 832;
    DotR := 5;

    // Timeline continuous vertical track line
    C.Pen.Color := Colors.Border;
    C.Pen.Width := 2;
    C.MoveTo(DotX, 106);
    C.LineTo(DotX, 350);

    // Timeline Node 1: SCM Service Online (Emerald, MidY = 126)
    DotY := 126;
    C.Brush.Style := bsSolid;
    C.Brush.Color := $10B981;
    C.Pen.Color := Colors.Background;
    C.Pen.Width := 2;
    C.Ellipse(DotX - DotR - 1, DotY - DotR - 1, DotX + DotR + 1, DotY + DotR + 1);

    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(764, DotY - 10, DotX - 10, DotY + 10), '10:42:15', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(DotX + 16, DotY - 10, 1096, DotY + 10), 'Windows Service SCM Online', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(DotX + 16, DotY + 9, 1096, DotY + 25), 'LanmanServer service started successfully', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Timeline Node 2: Memory Spike Hysteresis (Amber, MidY = 182)
    DotY := 182;
    C.Brush.Style := bsSolid;
    C.Brush.Color := $F59E0B;
    C.Pen.Color := Colors.Background;
    C.Ellipse(DotX - DotR - 1, DotY - DotR - 1, DotX + DotR + 1, DotY + DotR + 1);

    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(764, DotY - 10, DotX - 10, DotY + 10), '10:43:08', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(DotX + 16, DotY - 10, 1096, DotY + 10), 'Memory Load Alert (Streak 2/2)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(DotX + 16, DotY + 9, 1096, DotY + 25), 'Physical RAM load hit 78.4% (hysteresis active)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Timeline Node 3: UAC Process Elevation (Cyan, MidY = 238)
    DotY := 238;
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Accent;
    C.Pen.Color := Colors.Background;
    C.Ellipse(DotX - DotR - 1, DotY - DotR - 1, DotX + DotR + 1, DotY + DotR + 1);

    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(764, DotY - 10, DotX - 10, DotY + 10), '10:44:00', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(DotX + 16, DotY - 10, 1096, DotY + 10), 'RunTask UAC Elevation', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(DotX + 16, DotY + 9, 1096, DotY + 25), 'NtQueryInformationProcess(60) acquired', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Timeline Node 4: Clipboard Update (Violet, MidY = 294)
    DotY := 294;
    C.Brush.Style := bsSolid;
    C.Brush.Color := $818CF8;
    C.Pen.Color := Colors.Background;
    C.Ellipse(DotX - DotR - 1, DotY - DotR - 1, DotX + DotR + 1, DotY + DotR + 1);

    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(764, DotY - 10, DotX - 10, DotY + 10), '10:45:22', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(DotX + 16, DotY - 10, 1096, DotY + 10), 'WM_CLIPBOARDUPDATE Event', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(DotX + 16, DotY + 9, 1096, DotY + 25), 'Deduplicated clipboard history updated (420 chars)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 5. Bottom Panel: Side-by-Side & Unified Diff Visualizer (TVeloxDiffView)
    TVeloxGdiPlus.DrawCard(C, Rect(396, 374, 1104, 624), Colors.SurfaceCard, Colors.Border, 8);

    // Header bar with diff tabs
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(398, 376, 1102, 408));

    C.Brush.Style := bsClear;
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(408, 376, 680, 408), 'DIFF VISUALIZER & LINE COMPARISON (TVeloxDiffView)',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // View Mode Tabs on Right
    TVeloxGdiPlus.DrawCard(C, Rect(890, 380, 992, 404),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.28), Colors.Accent, 4);
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(890, 380, 992, 404), 'Unified Diff', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(998, 380, 1096, 404), Colors.SurfaceCard, Colors.Border, 4);
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(998, 380, 1096, 404), 'Side-by-Side', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Diff Header line
    C.Font.Name := 'Consolas';
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(412, 412, 1096, 432), '--- a/src/Velox.Theme.pas    +++ b/src/Velox.Theme.pas',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Diff Lines with Gutter (Y: 436..616)
    for I := 0 to 6 do
    begin
      RowY := 436 + I * 25;

      // 1. Line Background for added/deleted rows (covers code and sign area)
      if I = 1 then
      begin
        C.Brush.Style := bsSolid;
        C.Brush.Color := DelBg;
        C.FillRect(Rect(465, RowY, 1100, RowY + 24));
      end
      else if (I = 2) or (I = 3) then
      begin
        C.Brush.Style := bsSolid;
        C.Brush.Color := AddBg;
        C.FillRect(Rect(465, RowY, 1100, RowY + 24));
      end;

      // 2. Gutter Old & New Line Numbers Background
      C.Brush.Style := bsSolid;
      C.Brush.Color := Colors.Surface;
      C.FillRect(Rect(400, RowY, 464, RowY + 24));

      // 3. Gutter Separator Line
      C.Pen.Color := Colors.Border;
      C.Pen.Width := 1;
      C.MoveTo(464, RowY);
      C.LineTo(464, RowY + 24);

      // 4. Line Numbers (Gutter Old: 402..430, Gutter New: 432..460)
      C.Brush.Style := bsClear;
      C.Font.Name := 'Consolas';
      C.Font.Size := 8;
      C.Font.Style := [];
      C.Font.Color := Colors.TextSecondary;

      case I of
        0:
          begin
            DrawShowcaseText(C, Rect(402, RowY, 430, RowY + 24), '42', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
            DrawShowcaseText(C, Rect(432, RowY, 460, RowY + 24), '42', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
          end;
        1:
          DrawShowcaseText(C, Rect(402, RowY, 430, RowY + 24), '43', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
        2:
          DrawShowcaseText(C, Rect(432, RowY, 460, RowY + 24), '43', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
        3:
          DrawShowcaseText(C, Rect(432, RowY, 460, RowY + 24), '44', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
        4:
          begin
            DrawShowcaseText(C, Rect(402, RowY, 430, RowY + 24), '44', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
            DrawShowcaseText(C, Rect(432, RowY, 460, RowY + 24), '45', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
          end;
        5:
          begin
            DrawShowcaseText(C, Rect(402, RowY, 430, RowY + 24), '45', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
            DrawShowcaseText(C, Rect(432, RowY, 460, RowY + 24), '46', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
          end;
        6:
          begin
            DrawShowcaseText(C, Rect(402, RowY, 430, RowY + 24), '46', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
            DrawShowcaseText(C, Rect(432, RowY, 460, RowY + 24), '47', DT_SINGLELINE or DT_VCENTER or DT_RIGHT);
          end;
      end;

      // 5. Dedicated 20px Sign Column (+ / -) perfectly centered at Rect(465, RowY, 485, RowY + 24)
      C.Font.Size := 9;
      C.Font.Style := [fsBold];
      if I = 1 then
      begin
        C.Font.Color := DelSignCol;
        DrawShowcaseText(C, Rect(465, RowY, 485, RowY + 24), '-', DT_SINGLELINE or DT_VCENTER or DT_CENTER);
      end
      else if (I = 2) or (I = 3) then
      begin
        C.Font.Color := AddSignCol;
        DrawShowcaseText(C, Rect(465, RowY, 485, RowY + 24), '+', DT_SINGLELINE or DT_VCENTER or DT_CENTER);
      end;

      // 6. Code Text at uniform column starting at Rect(488, RowY, 1096, RowY + 24)
      C.Font.Size := 8;
      C.Font.Style := [];
      case I of
        0:
          begin
            C.Font.Color := Colors.TextSecondary;
            DrawShowcaseText(C, Rect(488, RowY, 1096, RowY + 24), '  // Query undocumented uxtheme ordinals for dark scrollbars',
              DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        1:
          begin
            C.Font.Color := DelSignCol;
            DrawShowcaseText(C, Rect(488, RowY, 1096, RowY + 24), '  SetWindowTheme(Handle, ''Explorer'', nil);',
              DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        2:
          begin
            C.Font.Color := AddSignCol;
            DrawShowcaseText(C, Rect(488, RowY, 1096, RowY + 24), '  SetPreferredAppMode(AllowDarkMode); // Ordinal 135',
              DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        3:
          begin
            C.Font.Color := AddSignCol;
            DrawShowcaseText(C, Rect(488, RowY, 1096, RowY + 24), '  SetWindowTheme(Handle, ''DarkMode_Explorer'', nil);',
              DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        4:
          begin
            C.Font.Color := Colors.TextSecondary;
            DrawShowcaseText(C, Rect(488, RowY, 1096, RowY + 24), '  DwmSetWindowAttribute(Handle, DWMWA_USE_IMMERSIVE_DARK_MODE, 1);',
              DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        5:
          begin
            C.Font.Color := Colors.TextSecondary;
            DrawShowcaseText(C, Rect(488, RowY, 1096, RowY + 24), '  ApplySystemBackdrop(Handle, vsbMica); // Windows 11 22H2+ Mica',
              DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        6:
          begin
            C.Font.Color := Colors.TextSecondary;
            DrawShowcaseText(C, Rect(488, RowY, 1096, RowY + 24), 'end;',
              DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
      end;
    end;

    Result := SaveBitmapToPng(Bmp, AFilePath);
  finally
    Bmp.Free;
  end;
end;

class function TVeloxScreenshot.RenderRestStudioShowcase(const AFilePath: string;
  const ATheme: TVeloxTheme): Boolean;
const
  W = 1120;
  H = 640;
var
  Bmp: TBitmap;
  C: TCanvas;
  Colors: TVeloxThemeColors;
  MethodPillBg, KeyCol, StrCol, NumCol, BoolCol, StatusBg, StatusBorder, StatusTextCol: TColor;
  I, RowY, CurX, FirstQuote, SecondQuote, ColonPos: Integer;
  BadgeW, BadgeH, DotD, DotGap, TextW, TotalW, StartX, DotY: Integer;
  LeadSpaces, KeyText, ColonText, ValText, NumStr: string;
  HasComma: Boolean;
  JsonLines: array[0..20] of string;
begin
  Result := False;
  Colors := TVeloxUtils.GetThemeColors(ATheme);

  if ATheme = vtLight then
  begin
    MethodPillBg := $D97706; // Blue/Amber
    KeyCol := $B45309;
    StrCol := $15803D;
    NumCol := $C2410C;
    BoolCol := $B91C1C;
    StatusBg := $DCFCE7;
    StatusBorder := $16A34A;
    StatusTextCol := $15803D;
  end
  else
  begin
    MethodPillBg := $F8BD38; // Sky Blue #38BDF8
    KeyCol := $F8BD38;       // #38BDF8 Sky Blue
    StrCol := $99D334;       // #34D399 Emerald Green
    NumCol := $0B9EF5;       // #F59E0B Amber
    BoolCol := $7171F8;      // #F87171 Coral Rose
    StatusBg := $143820;     // Dark Translucent Emerald
    StatusBorder := $99D334; // Vibrant Emerald Border
    StatusTextCol := $99D334;
  end;

  JsonLines[0]  := '{';
  JsonLines[1]  := '  "id": 149827361,';
  JsonLines[2]  := '  "sha": "bada74e7c10b4f8a9102c77d612e",';
  JsonLines[3]  := '  "ref": "refs/heads/master",';
  JsonLines[4]  := '  "task": "deploy:production",';
  JsonLines[5]  := '  "environment": "production",';
  JsonLines[6]  := '  "description": "Deploying VeloxUI v2.5.0 to cluster",';
  JsonLines[7]  := '  "creator": {';
  JsonLines[8]  := '    "login": "amafjarkasi",';
  JsonLines[9]  := '    "id": 482019,';
  JsonLines[10] := '    "type": "User",';
  JsonLines[11] := '    "site_admin": false';
  JsonLines[12] := '  },';
  JsonLines[13] := '  "created_at": "2026-10-22T04:29:31Z",';
  JsonLines[14] := '  "updated_at": "2026-10-22T04:29:32Z",';
  JsonLines[15] := '  "statuses_url": "https://api.github.com/.../statuses",';
  JsonLines[16] := '  "repository_url": "https://api.github.com/repos/amafjarkasi/velox-ui",';
  JsonLines[17] := '  "auto_merge": false,';
  JsonLines[18] := '  "transient_environment": false,';
  JsonLines[19] := '  "production_environment": true';
  JsonLines[20] := '}';

  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(W, H);
    C := Bmp.Canvas;

    // 1. Background fill
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Background;
    C.FillRect(Rect(0, 0, W, H));

    // Outer Main Window Frame
    TVeloxGdiPlus.DrawCard(C, Rect(16, 14, W - 16, H - 14), Colors.Surface, Colors.Border, 10);

    // 2. Title Bar (Y: 14..50)
    C.Brush.Style := bsClear;
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 18, 700, 48),
      'VeloxUI REST Studio - Native WinHTTP API Workbench, JSON Inspector & Telemetry');

    // Titlebar Window Controls (_ [] X)
    C.Font.Size := 9;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(W - 100, 18, W - 78, 48), '_', DT_SINGLELINE or DT_VCENTER or DT_CENTER);
    DrawShowcaseText(C, Rect(W - 74, 18, W - 52, 48), '[ ]', DT_SINGLELINE or DT_VCENTER or DT_CENTER);
    DrawShowcaseText(C, Rect(W - 48, 18, W - 26, 48), 'X', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Titlebar bottom separator line
    C.Pen.Color := Colors.Border;
    C.Pen.Width := 1;
    C.MoveTo(16, 50); C.LineTo(W - 16, 50);

    // 3. Top Address & Control Bar (Y: 58..98)
    TVeloxGdiPlus.DrawCard(C, Rect(28, 58, W - 28, 98), Colors.SurfaceCard, Colors.Border, 6);

    // 3.1 Method Pill Selector: 'POST' with crisp vector chevron
    TVeloxGdiPlus.DrawBadge(C, Rect(36, 64, 114, 92), 'POST', MethodPillBg, $000000);
    C.Pen.Color := $000000;
    C.Pen.Width := 2;
    C.MoveTo(92, 76); C.LineTo(96, 80); C.LineTo(100, 76);

    // 3.2 URL Address Bar
    TVeloxGdiPlus.DrawCard(C, Rect(122, 64, W - 238, 92), Colors.Background, Colors.Border, 4);
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 9;
    C.Font.Style := [];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(134, 64, W - 248, 92),
      'https://api.github.com/repos/amafjarkasi/velox-ui/deployments', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 3.3 Action Buttons
    // Send Button (Primary Accent)
    TVeloxGdiPlus.DrawCard(C, Rect(W - 230, 64, W - 164, 92), Colors.Accent, Colors.Accent, 4);
    C.Font.Style := [fsBold];
    C.Font.Color := $FFFFFF;
    DrawShowcaseText(C, Rect(W - 230, 64, W - 164, 92), 'Send', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // cURL Export Button (Outline)
    TVeloxGdiPlus.DrawCard(C, Rect(W - 158, 64, W - 100, 92), Colors.SurfaceCard, Colors.Border, 4);
    C.Font.Style := [];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(W - 158, 64, W - 100, 92), 'cURL', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Baseline Snapshot Button (Surface)
    TVeloxGdiPlus.DrawCard(C, Rect(W - 94, 64, W - 36, 92), Colors.SurfaceCard, Colors.Border, 4);
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(W - 94, 64, W - 36, 92), 'Baseline', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // 4. Split Body Panels (Y: 106..594)
    // 4.1 LEFT PANEL: Request Configuration (Width 370px, Rect(28, 106, 400, 594))
    TVeloxGdiPlus.DrawCard(C, Rect(28, 106, 400, 594), Colors.SurfaceCard, Colors.Border, 8);

    // Request Tabs
    TVeloxGdiPlus.DrawCard(C, Rect(36, 114, 180, 138),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.28), Colors.Accent, 4);
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 114, 180, 138), 'Headers & Params (6)', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(186, 114, 280, 138), Colors.SurfaceCard, Colors.Border, 4);
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(186, 114, 280, 138), 'Body (JSON)', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(286, 114, 346, 138), Colors.SurfaceCard, Colors.Border, 4);
    DrawShowcaseText(C, Rect(286, 114, 346, 138), 'Format', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Section Category 1: Headers
    TVeloxGdiPlus.DrawCard(C, Rect(36, 148, 392, 172), Colors.Surface, Colors.Border, 4);
    C.Pen.Color := Colors.Accent;
    C.Pen.Width := 2;
    C.MoveTo(44, 158); C.LineTo(48, 162); C.LineTo(52, 158);
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(58, 148, 384, 172), 'REQUEST HEADERS', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Property Grid Rows (Headers)
    for I := 0 to 3 do
    begin
      RowY := 176 + I * 26;
      C.Font.Name := 'Consolas';
      C.Font.Size := 8;
      C.Font.Style := [];
      C.Font.Color := Colors.TextSecondary;
      case I of
        0:
          begin
            DrawShowcaseText(C, Rect(44, RowY, 170, RowY + 24), 'Content-Type', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(174, RowY, 388, RowY + 24), 'application/json', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        1:
          begin
            DrawShowcaseText(C, Rect(44, RowY, 170, RowY + 24), 'Authorization', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(174, RowY, 388, RowY + 24), 'Bearer ghp_9xK8...4bQ', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        2:
          begin
            DrawShowcaseText(C, Rect(44, RowY, 170, RowY + 24), 'Accept', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(174, RowY, 388, RowY + 24), 'application/vnd.github.v3+json', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        3:
          begin
            DrawShowcaseText(C, Rect(44, RowY, 170, RowY + 24), 'User-Agent', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(174, RowY, 388, RowY + 24), 'VeloxUI-RestStudio/2.5', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
      end;
      C.Pen.Color := Colors.Border;
      C.Pen.Width := 1;
      C.MoveTo(44, RowY + 25); C.LineTo(388, RowY + 25);
    end;

    // Section Category 2: Query Parameters
    TVeloxGdiPlus.DrawCard(C, Rect(36, 290, 392, 314), Colors.Surface, Colors.Border, 4);
    C.Pen.Color := Colors.Accent;
    C.Pen.Width := 2;
    C.MoveTo(44, 300); C.LineTo(48, 304); C.LineTo(52, 300);
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(58, 290, 384, 314), 'QUERY PARAMETERS', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    for I := 0 to 2 do
    begin
      RowY := 318 + I * 26;
      C.Font.Name := 'Consolas';
      C.Font.Size := 8;
      C.Font.Style := [];
      C.Font.Color := Colors.TextSecondary;
      case I of
        0:
          begin
            DrawShowcaseText(C, Rect(44, RowY, 170, RowY + 24), 'environment', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(174, RowY, 388, RowY + 24), 'production', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        1:
          begin
            DrawShowcaseText(C, Rect(44, RowY, 170, RowY + 24), 'per_page', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(174, RowY, 388, RowY + 24), '50', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
        2:
          begin
            DrawShowcaseText(C, Rect(44, RowY, 170, RowY + 24), 'page', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(174, RowY, 388, RowY + 24), '1', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
          end;
      end;
      C.Pen.Color := Colors.Border;
      C.Pen.Width := 1;
      C.MoveTo(44, RowY + 25); C.LineTo(388, RowY + 25);
    end;

    // cURL Preview Card in Left Panel
    TVeloxGdiPlus.DrawCard(C, Rect(36, 408, 392, 584), Colors.Background, Colors.Border, 6);
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(46, 414, 382, 432), 'GENERATED cURL COMMAND:', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    C.Font.Name := 'Consolas';
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(46, 436, 382, 452), 'curl -X POST \', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(46, 454, 382, 470), '  "https://api.github.com/.../deployments" \', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(46, 472, 382, 488), '  -H "Content-Type: application/json" \', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    DrawShowcaseText(C, Rect(46, 490, 382, 506), '  -H "Authorization: Bearer ghp_9x..." \', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    DrawShowcaseText(C, Rect(46, 508, 382, 524), '  -H "Accept: application/vnd.github..." \', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Color := StrCol;
    DrawShowcaseText(C, Rect(46, 526, 382, 542), '  -d ''{"ref":"master","task":"deploy"}''', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // cURL Copy Hint with green vector checkmark
    C.Pen.Color := $34D399;
    C.Pen.Width := 2;
    C.MoveTo(48, 562); C.LineTo(51, 565); C.LineTo(57, 558);

    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(62, 552, 382, 574), 'Click "cURL" button to copy command', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 4.2 RIGHT PANEL: Response & Full Height Code Viewer (Width 692px, Rect(410, 106, W - 28, 594))
    TVeloxGdiPlus.DrawCard(C, Rect(410, 106, W - 28, 594), Colors.SurfaceCard, Colors.Border, 8);

    // Response Status Bar (Y: 112..146)
    // Fluent Status Badge: 201 Created (Emerald) - perfectly aligned in the middle
    TVeloxGdiPlus.DrawCard(C, Rect(420, 114, 526, 140), StatusBg, StatusBorder, 4);
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := StatusTextCol;

    BadgeW := 526 - 420;
    BadgeH := 140 - 114;
    DotD := 6;
    DotGap := 6;
    TextW := C.TextWidth('201 Created');
    TotalW := DotD + DotGap + TextW;
    StartX := 420 + (BadgeW - TotalW) div 2;
    DotY := 114 + (BadgeH - DotD) div 2;

    // Smooth anti-aliased dot aligned with the center of the text
    TVeloxGdiPlus.DrawCard(C, Rect(StartX, DotY, StartX + DotD, DotY + DotD), StatusTextCol, StatusTextCol, DotD div 2);

    // Text aligned in the middle
    DrawShowcaseText(C, Rect(StartX + DotD + DotGap, 114, StartX + TotalW + 4, 140), '201 Created',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // LATENCY IS FIXED TO THE TOP: Telemetry Capsule in Header Bar
    TVeloxGdiPlus.DrawCard(C, Rect(532, 114, 714, 140), Colors.Surface, Colors.Border, 4);
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(542, 114, 592, 140), '118 ms', DT_SINGLELINE or DT_VCENTER or DT_LEFT);
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(592, 114, 708, 140), '(avg 124ms · pk 145ms)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Response Payload Size Badge
    TVeloxGdiPlus.DrawCard(C, Rect(720, 114, 796, 140), Colors.Surface, Colors.Border, 4);
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(720, 114, 796, 140), '2.45 KB', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // View Mode Tabs on Right
    TVeloxGdiPlus.DrawCard(C, Rect(806, 114, 894, 140),
      TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.28), Colors.Accent, 4);
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(806, 114, 894, 140), 'Pretty JSON', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(900, 114, 948, 140), Colors.SurfaceCard, Colors.Border, 4);
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(900, 114, 948, 140), 'Raw', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(954, 114, 1038, 140), Colors.SurfaceCard, Colors.Border, 4);
    DrawShowcaseText(C, Rect(954, 114, 1038, 140), 'Diff Baseline', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(1044, 114, 1076, 140), Colors.SurfaceCard, Colors.Border, 4);
    DrawShowcaseText(C, Rect(1044, 114, 1076, 140), 'Latency', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Separator line under response header
    C.Pen.Color := Colors.Border;
    C.Pen.Width := 1;
    C.MoveTo(410, 148); C.LineTo(W - 28, 148);

    // Response Body: FULL HEIGHT SYNTAX-HIGHLIGHTED JSON (Y: 152..592)
    // Left Line Numbers Gutter
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(412, 150, 450, 592));

    C.Pen.Color := Colors.Border;
    C.Pen.Width := 1;
    C.MoveTo(450, 150); C.LineTo(450, 592);

    C.Font.Name := 'Consolas';
    C.Font.Size := 8;

    for I := 0 to 20 do
    begin
      RowY := 156 + I * 20;

      // Line number in gutter
      NumStr := IntToStr(I + 1);
      C.Brush.Style := bsClear;
      C.Font.Style := [];
      C.Font.Color := Colors.TextSecondary;
      C.TextOut(444 - C.TextWidth(NumStr), RowY + 2, NumStr);

      CurX := 462;
      FirstQuote := Pos('"', JsonLines[I]);

      if (FirstQuote = 0) or (Pos(':', JsonLines[I]) = 0) then
      begin
        // Braces / Structural lines: '{', '}', '  },'
        C.Font.Color := Colors.TextSecondary;
        C.TextOut(CurX, RowY + 2, JsonLines[I]);
      end
      else
      begin
        // 1. Leading Indent
        if FirstQuote > 1 then
        begin
          LeadSpaces := Copy(JsonLines[I], 1, FirstQuote - 1);
          C.TextOut(CurX, RowY + 2, LeadSpaces);
          Inc(CurX, C.TextWidth(LeadSpaces));
        end;

        // 2. Key
        SecondQuote := FirstQuote + 1;
        while (SecondQuote <= Length(JsonLines[I])) and (JsonLines[I][SecondQuote] <> '"') do
          Inc(SecondQuote);

        KeyText := Copy(JsonLines[I], FirstQuote, SecondQuote - FirstQuote + 1);
        C.Font.Color := KeyCol;
        C.TextOut(CurX, RowY + 2, KeyText);
        Inc(CurX, C.TextWidth(KeyText));

        // 3. Colon & separator
        ColonPos := Pos(':', JsonLines[I]);
        ColonText := ': ';
        C.Font.Color := Colors.TextSecondary;
        C.TextOut(CurX, RowY + 2, ColonText);
        Inc(CurX, C.TextWidth(ColonText));

        // 4. Value
        ValText := Trim(Copy(JsonLines[I], ColonPos + 1, Length(JsonLines[I])));
        HasComma := False;
        if (Length(ValText) > 0) and (ValText[Length(ValText)] = ',') then
        begin
          HasComma := True;
          Delete(ValText, Length(ValText), 1);
        end;

        if (Length(ValText) > 0) and (ValText[1] = '"') then
          C.Font.Color := StrCol
        else if (ValText = 'true') or (ValText = 'false') or (ValText = 'null') then
          C.Font.Color := BoolCol
        else if (Length(ValText) > 0) and (ValText[1] in ['0'..'9', '-']) then
          C.Font.Color := NumCol
        else
          C.Font.Color := Colors.TextSecondary;

        C.TextOut(CurX, RowY + 2, ValText);
        Inc(CurX, C.TextWidth(ValText));

        if HasComma then
        begin
          C.Font.Color := Colors.TextSecondary;
          C.TextOut(CurX, RowY + 2, ',');
        end;
      end;
    end;

    // 5. Bottom Footer Status Bar (Y: 602..628)
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(18, 602, W - 18, 628));

    C.Pen.Color := Colors.Border;
    C.Pen.Width := 1;
    C.MoveTo(18, 602); C.LineTo(W - 18, 602);

    C.Brush.Style := bsClear;
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(30, 604, W - 30, 626),
      'WinHTTP 5.1 TLS 1.3  |  HTTP/2 Multiplexing  |  Payload: 2.45 KB  |  Response Time: 118 ms  |  TVeloxRestStudio v2.5.0',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    Result := SaveBitmapToPng(Bmp, AFilePath);
  finally
    Bmp.Free;
  end;
end;

class function TVeloxScreenshot.RenderTelemetryWallShowcase(const AFilePath: string;
  const ATheme: TVeloxTheme): Boolean;
const
  W = 1120;
  H = 640;
var
  Bmp: TBitmap;
  C: TCanvas;
  Colors: TVeloxThemeColors;
  CpuSamples, RamSamples, NetSamples: TSingleDynArray;
  I, CardW, CardSpacing, LeftX: Integer;
  CardR, DonutR, SparkR: TRect;
begin
  Result := False;
  Colors := TVeloxUtils.GetThemeColors(ATheme);

  SetLength(CpuSamples, 16);
  CpuSamples[0] := 18; CpuSamples[1] := 22; CpuSamples[2] := 19; CpuSamples[3] := 25;
  CpuSamples[4] := 21; CpuSamples[5] := 28; CpuSamples[6] := 24; CpuSamples[7] := 32;
  CpuSamples[8] := 26; CpuSamples[9] := 30; CpuSamples[10] := 27; CpuSamples[11] := 23;
  CpuSamples[12] := 29; CpuSamples[13] := 25; CpuSamples[14] := 24; CpuSamples[15] := 25;

  SetLength(RamSamples, 16);
  RamSamples[0] := 64; RamSamples[1] := 65; RamSamples[2] := 65; RamSamples[3] := 66;
  RamSamples[4] := 66; RamSamples[5] := 67; RamSamples[6] := 67; RamSamples[7] := 68;
  RamSamples[8] := 68; RamSamples[9] := 68; RamSamples[10] := 67; RamSamples[11] := 68;
  RamSamples[12] := 68; RamSamples[13] := 68; RamSamples[14] := 68; RamSamples[15] := 68;

  SetLength(NetSamples, 16);
  NetSamples[0] := 12; NetSamples[1] := 15; NetSamples[2] := 14; NetSamples[3] := 18;
  NetSamples[4] := 22; NetSamples[5] := 19; NetSamples[6] := 26; NetSamples[7] := 31;
  NetSamples[8] := 28; NetSamples[9] := 24; NetSamples[10] := 29; NetSamples[11] := 33;
  NetSamples[12] := 27; NetSamples[13] := 25; NetSamples[14] := 30; NetSamples[15] := 28;

  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.SetSize(W, H);
    C := Bmp.Canvas;

    // 1. Background fill
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Background;
    C.FillRect(Rect(0, 0, W, H));

    // Outer Main Window Frame
    TVeloxGdiPlus.DrawCard(C, Rect(16, 14, W - 16, H - 14), Colors.Surface, Colors.Border, 10);

    // 2. Title Bar (Y: 14..50)
    C.Brush.Style := bsClear;
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(36, 18, 700, 48),
      'VeloxUI Telemetry Wall - Executive Mission Control & Multi-Stream Operations Hub');

    // Titlebar Window Controls (_ [] X)
    C.Font.Size := 9;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(W - 100, 18, W - 78, 48), '_', DT_SINGLELINE or DT_VCENTER or DT_CENTER);
    DrawShowcaseText(C, Rect(W - 74, 18, W - 52, 48), #$25A2, DT_SINGLELINE or DT_VCENTER or DT_CENTER);
    DrawShowcaseText(C, Rect(W - 48, 18, W - 26, 48), #$2715, DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Titlebar bottom separator line
    C.Pen.Color := Colors.Border;
    C.Pen.Width := 1;
    C.MoveTo(16, 50); C.LineTo(W - 16, 50);

    // 3. Top Control Bar (Y: 58..98)
    TVeloxGdiPlus.DrawCard(C, Rect(28, 58, W - 28, 98), Colors.SurfaceCard, Colors.Border, 6);

    // Polling rate buttons
    TVeloxGdiPlus.DrawCard(C, Rect(38, 64, 82, 92), Colors.Accent, Colors.Accent, 4);
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := $000000;
    DrawShowcaseText(C, Rect(38, 64, 82, 92), '1s', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(88, 64, 132, 92), Colors.Surface, Colors.Border, 4);
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(88, 64, 132, 92), '2s', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(138, 64, 182, 92), Colors.Surface, Colors.Border, 4);
    DrawShowcaseText(C, Rect(138, 64, 182, 92), '5s', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    TVeloxGdiPlus.DrawCard(C, Rect(188, 64, 248, 92), Colors.Surface, Colors.Border, 4);
    DrawShowcaseText(C, Rect(188, 64, 248, 92), 'Pause', DT_SINGLELINE or DT_VCENTER or DT_CENTER);

    // Operational Status Badge (Green)
    TVeloxGdiPlus.DrawBadge(C, Rect(266, 65, 480, 91), #$25CF'  ALL SYSTEMS OPERATIONAL', $34D399, $000000);

    // Battery / Power Telemetry Badge (Right aligned)
    TVeloxGdiPlus.DrawCard(C, Rect(W - 240, 64, W - 38, 92), Colors.Surface, Colors.Border, 4);
    C.Font.Color := Colors.TextPrimary;
    C.Font.Style := [fsBold];
    DrawShowcaseText(C, Rect(W - 232, 64, W - 46, 92), #$26A1' Power: 98% (AC Plugged)', DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // 4. Central 4 KPI Metric Cards (Y: 106..226)
    CardSpacing := 12;
    CardW := (W - 56 - (CardSpacing * 3)) div 4;

    for I := 0 to 3 do
    begin
      LeftX := 28 + I * (CardW + CardSpacing);
      CardR := Rect(LeftX, 106, LeftX + CardW, 226);
      TVeloxGdiPlus.DrawCard(C, CardR, Colors.SurfaceCard, Colors.Border, 8);

      C.Font.Name := 'Segoe UI';
      C.Font.Size := 8;
      C.Font.Style := [fsBold];
      C.Font.Color := Colors.TextSecondary;

      case I of
        0:
          begin
            DrawShowcaseText(C, Rect(LeftX + 14, 114, LeftX + CardW - 14, 132), 'PROCESSOR LOAD (ALL CORES)');
            C.Font.Size := 16;
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(LeftX + 14, 134, LeftX + 130, 164), '24.8%');
            TVeloxGdiPlus.DrawBadge(C, Rect(LeftX + CardW - 68, 136, LeftX + CardW - 14, 160), '+1.4%', $34D399, $000000);
            TVeloxGdiPlus.DrawSparkline(C, Rect(LeftX + 14, 172, LeftX + CardW - 14, 216), CpuSamples,
              Colors.Accent, TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.25));
          end;
        1:
          begin
            DrawShowcaseText(C, Rect(LeftX + 14, 114, LeftX + CardW - 14, 132), 'COMMITTED MEMORY (RAM)');
            C.Font.Size := 16;
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(LeftX + 14, 134, LeftX + 130, 164), '6.8 GB');
            TVeloxGdiPlus.DrawBadge(C, Rect(LeftX + CardW - 76, 136, LeftX + CardW - 14, 160), '-120 MB', $34D399, $000000);
            TVeloxGdiPlus.DrawSparkline(C, Rect(LeftX + 14, 172, LeftX + CardW - 14, 216), RamSamples,
              $6366F1, TVeloxUtils.BlendColor(Colors.SurfaceCard, $6366F1, 0.25));
          end;
        2:
          begin
            DrawShowcaseText(C, Rect(LeftX + 14, 114, LeftX + CardW - 14, 132), 'NETWORK THROUGHPUT (I/O)');
            C.Font.Size := 16;
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(LeftX + 14, 134, LeftX + 140, 164), '1.85 MB/s');
            TVeloxGdiPlus.DrawBadge(C, Rect(LeftX + CardW - 80, 136, LeftX + CardW - 14, 160), '+420 KB/s', Colors.Accent, $000000);
            TVeloxGdiPlus.DrawSparkline(C, Rect(LeftX + 14, 172, LeftX + CardW - 14, 216), NetSamples,
              $10B981, TVeloxUtils.BlendColor(Colors.SurfaceCard, $10B981, 0.25));
          end;
        3:
          begin
            DrawShowcaseText(C, Rect(LeftX + 14, 114, LeftX + CardW - 14, 132), 'SYSTEM POWER & BATTERY');
            C.Font.Size := 16;
            C.Font.Color := Colors.TextPrimary;
            DrawShowcaseText(C, Rect(LeftX + 14, 134, LeftX + 140, 164), '98% AC');
            TVeloxGdiPlus.DrawBadge(C, Rect(LeftX + CardW - 74, 136, LeftX + CardW - 14, 160), 'Optimal', $34D399, $000000);
            C.Font.Size := 8;
            C.Font.Style := [];
            C.Font.Color := Colors.TextSecondary;
            DrawShowcaseText(C, Rect(LeftX + 14, 174, LeftX + CardW - 14, 192), 'Primary: AC Power Supply Online');
            DrawShowcaseText(C, Rect(LeftX + 14, 194, LeftX + CardW - 14, 212), 'Remaining: Full Capacity (Healthy)');
          end;
      end;
    end;

    // 5. Bottom Section: Left Card (Donut Gauge) & Right Card (Dual Stream) (Y: 236..594)
    // 5.1 Left Card: Memory Allocation & Commit Ratio (Width 480)
    TVeloxGdiPlus.DrawCard(C, Rect(28, 236, 508, 594), Colors.SurfaceCard, Colors.Border, 8);

    C.Font.Name := 'Segoe UI';
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(42, 246, 494, 268), 'Memory Allocation & Commit Ratio');

    DonutR := Rect(44, 280, 184, 420);
    TVeloxCharts.DrawDonutGauge(C, DonutR, 68.0, '68%', 'RAM', Colors, Colors.Accent);

    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(200, 290, 494, 310), 'Working Set:       4.2 GB');
    DrawShowcaseText(C, Rect(200, 316, 494, 336), 'Paged Pool:        380 MB');
    DrawShowcaseText(C, Rect(200, 342, 494, 362), 'Available RAM:     9.4 GB');
    DrawShowcaseText(C, Rect(200, 368, 494, 388), 'Commit Limit:      16.0 GB');
    DrawShowcaseText(C, Rect(200, 394, 494, 414), 'Page Faults:       12 / sec (Normal)');

    // Hysteresis Status Box inside Left Card
    TVeloxGdiPlus.DrawCard(C, Rect(42, 436, 494, 578), Colors.Surface, Colors.Border, 6);
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(54, 444, 482, 464), 'HYSTERESIS ANTI-SPIKE ENGINE');

    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(54, 470, 482, 490), 'Warning Threshold:   75.0% (2 consecutive samples)');
    DrawShowcaseText(C, Rect(54, 492, 482, 512), 'Critical Threshold:  90.0% (immediate escalation)');
    DrawShowcaseText(C, Rect(54, 514, 482, 534), 'Cooldown Period:     5000 ms hysteresis guard');
    C.Font.Color := $34D399;
    DrawShowcaseText(C, Rect(54, 542, 482, 566), #$2713'  Telemetry engine operating within normal baseline');

    // 5.2 Right Card: Rolling Processor & I/O Activity Stream (Width W - 524 - 28 = 568)
    TVeloxGdiPlus.DrawCard(C, Rect(522, 236, W - 28, 594), Colors.SurfaceCard, Colors.Border, 8);

    C.Font.Name := 'Segoe UI';
    C.Font.Size := 9;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(536, 246, W - 42, 268), 'Rolling Multi-Channel Telemetry (30 Rolling Samples)');

    // Legend items
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    DrawShowcaseText(C, Rect(536, 276, 750, 296), #$25CF' Channel 1: Processor Load (QPC)');

    C.Font.Color := $10B981;
    DrawShowcaseText(C, Rect(760, 276, 980, 296), #$25CF' Channel 2: Network I/O Stream');

    // Dual Sparkline
    SparkR := Rect(536, 306, W - 42, 476);
    TVeloxCharts.DrawDualSparkline(C, SparkR, CpuSamples, NetSamples, Colors.Accent, $10B981, Colors.SurfaceCard);

    // Diagnostic Metrics Panel inside Right Card
    TVeloxGdiPlus.DrawCard(C, Rect(536, 490, W - 42, 578), Colors.Surface, Colors.Border, 6);

    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.TextPrimary;
    DrawShowcaseText(C, Rect(550, 498, W - 56, 518), 'HARDWARE DIAGNOSTIC METRICS SUMMARY');

    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(550, 524, 760, 544), 'Min Load:     18.2%');
    DrawShowcaseText(C, Rect(550, 546, 760, 566), 'Peak Spike:   32.0%');

    DrawShowcaseText(C, Rect(770, 524, 950, 544), 'Average Load: 24.5%');
    DrawShowcaseText(C, Rect(770, 546, 950, 566), 'P95 Latency:  28.4%');

    DrawShowcaseText(C, Rect(960, 524, W - 56, 544), 'Sampling:     1000 ms');
    DrawShowcaseText(C, Rect(960, 546, W - 56, 566), 'Jitter:       < 0.4 ms');

    // 6. Bottom Footer Status Bar (Y: 602..628)
    C.Brush.Style := bsSolid;
    C.Brush.Color := Colors.Surface;
    C.FillRect(Rect(18, 602, W - 18, 628));

    C.Pen.Color := Colors.Border;
    C.Pen.Width := 1;
    C.MoveTo(18, 602); C.LineTo(W - 18, 602);

    C.Brush.Style := bsClear;
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 8;
    C.Font.Style := [];
    C.Font.Color := Colors.TextSecondary;
    DrawShowcaseText(C, Rect(30, 604, W - 30, 626),
      'Win32 NT Poller 1000ms  |  QPC Microsecond Telemetry  |  Hysteresis Anti-Spike Guard Active  |  TVeloxTelemetryWall v2.5.0',
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    Result := SaveBitmapToPng(Bmp, AFilePath);
  finally
    Bmp.Free;
  end;
end;

end.
