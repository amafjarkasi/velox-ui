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

end.
