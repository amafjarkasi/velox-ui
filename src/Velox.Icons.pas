unit Velox.Icons;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Icons (#74)
  Purpose:
    Built-in Scalable Windows 11 Fluent Vector Icon Engine:
      - 36 standard vector icons rendered via sub-pixel antialiased GDI+ geometry.
      - Zero external font files (.ttf), zero raster PNG files, zero DLLs.
      - Resolution-independent: scales perfectly to 12px, 16px, 24px, 32px, 48px
        at any High-DPI scaling factor (100%, 125%, 150%, 200%).
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
  Velox.GdiPlus;

type
  /// <summary>
  /// Built-in scalable Windows 11 Fluent vector icon glyph identifiers
  /// </summary>
  TVeloxIcon = (
    viNone,
    viHome,
    viSettings,
    viSearch,
    viRefresh,
    viFolder,
    viTerminal,
    viGrid,
    viFilter,
    viSliders,
    viCopy,
    viCheck,
    viClose,
    viTrash,
    viPlay,
    viPause,
    viDownload,
    viUpload,
    viUndo,
    viRedo,
    viInfo,
    viWarning,
    viError,
    viShield,
    viCpu,
    viMemory,
    viCloud,
    viBell,
    viUser,
    viStar,
    viPin,
    viLock,
    viChevronDown,
    viChevronRight,
    viChevronLeft,
    viChevronUp
  );

  /// <summary>
  /// Resolution-independent GDI+ vector icon renderer
  /// </summary>
  TVeloxIcons = class
  public
    /// <summary>
    /// Renders a scalable vector icon into ARect centered at ASize pixels.
    /// </summary>
    class procedure Draw(const ACanvas: TCanvas; const ARect: TRect;
      const AIcon: TVeloxIcon; const AColor: TColor; const ASize: Integer = 16); static;

    /// <summary>
    /// Returns the canonical display name of an icon
    /// </summary>
    class function IconName(const AIcon: TVeloxIcon): string; static;

    /// <summary>
    /// Resolves an icon enum from its canonical display name
    /// </summary>
    class function FromName(const AName: string): TVeloxIcon; static;

    /// <summary>
    /// Total number of built-in vector icons
    /// </summary>
    class function Count: Integer; static;
  end;

implementation

type
  TGpStatus = Integer;
  TGpGraphics = Pointer;
  TGpPen = Pointer;
  TGpBrush = Pointer;
  TGpSolidFill = Pointer;
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
  GIconsGdiLoaded: Boolean = False;
  GIconsGdiLib: HMODULE = 0;
  GIconsGdiToken: NativeUInt = 0;

  GdiplusStartup: function(out token: NativeUInt; input: PGdiplusStartupInput; output: Pointer): TGpStatus; stdcall;
  GdipCreateFromHDC: function(hdc: HDC; out graphics: TGpGraphics): TGpStatus; stdcall;
  GdipDeleteGraphics: function(graphics: TGpGraphics): TGpStatus; stdcall;
  GdipSetSmoothingMode: function(graphics: TGpGraphics; smoothingMode: Integer): TGpStatus; stdcall;
  GdipCreatePen1: function(color: TARGB; width: Single; unit_: Integer; out pen: TGpPen): TGpStatus; stdcall;
  GdipDeletePen: function(pen: TGpPen): TGpStatus; stdcall;
  GdipCreateSolidFill: function(color: TARGB; out brush: TGpSolidFill): TGpStatus; stdcall;
  GdipDeleteBrush: function(brush: TGpBrush): TGpStatus; stdcall;
  GdipDrawLine: function(graphics: TGpGraphics; pen: TGpPen; x1, y1, x2, y2: Single): TGpStatus; stdcall;
  GdipDrawArc: function(graphics: TGpGraphics; pen: TGpPen; x, y, width, height, startAngle, sweepAngle: Single): TGpStatus; stdcall;
  GdipDrawEllipse: function(graphics: TGpGraphics; pen: TGpPen; x, y, width, height: Single): TGpStatus; stdcall;
  GdipDrawRectangle: function(graphics: TGpGraphics; pen: TGpPen; x, y, width, height: Single): TGpStatus; stdcall;
  GdipFillRectangle: function(graphics: TGpGraphics; brush: TGpBrush; x, y, width, height: Single): TGpStatus; stdcall;
  GdipFillEllipse: function(graphics: TGpGraphics; brush: TGpBrush; x, y, width, height: Single): TGpStatus; stdcall;
  GdipFillPolygon: function(graphics: TGpGraphics; brush: TGpBrush; points: PGpPointF; count: Integer; fillMode: Integer): TGpStatus; stdcall;

function ColorToARGB(const AColor: TColor; const AAlpha: Byte = 255): TARGB;
var
  C: LongInt;
  R, G, B: Byte;
begin
  C := ColorToRGB(AColor);
  R := Byte(C and $FF);
  G := Byte((C shr 8) and $FF);
  B := Byte((C shr 16) and $FF);
  Result := (Cardinal(AAlpha) shl 24) or (Cardinal(R) shl 16) or (Cardinal(G) shl 8) or Cardinal(B);
end;

function InitIconsGdiPlus: Boolean;
var
  Input: TGdiplusStartupInput;
begin
  if GIconsGdiLoaded then
    Exit(GIconsGdiToken <> 0);
  GIconsGdiLoaded := True;

  GIconsGdiLib := LoadLibrary('gdiplus.dll');
  if GIconsGdiLib = 0 then Exit(False);

  @GdiplusStartup       := GetProcAddress(GIconsGdiLib, 'GdiplusStartup');
  @GdipCreateFromHDC    := GetProcAddress(GIconsGdiLib, 'GdipCreateFromHDC');
  @GdipDeleteGraphics   := GetProcAddress(GIconsGdiLib, 'GdipDeleteGraphics');
  @GdipSetSmoothingMode := GetProcAddress(GIconsGdiLib, 'GdipSetSmoothingMode');
  @GdipCreatePen1       := GetProcAddress(GIconsGdiLib, 'GdipCreatePen1');
  @GdipDeletePen        := GetProcAddress(GIconsGdiLib, 'GdipDeletePen');
  @GdipCreateSolidFill  := GetProcAddress(GIconsGdiLib, 'GdipCreateSolidFill');
  @GdipDeleteBrush      := GetProcAddress(GIconsGdiLib, 'GdipDeleteBrush');
  @GdipDrawLine         := GetProcAddress(GIconsGdiLib, 'GdipDrawLine');
  @GdipDrawArc          := GetProcAddress(GIconsGdiLib, 'GdipDrawArc');
  @GdipDrawEllipse      := GetProcAddress(GIconsGdiLib, 'GdipDrawEllipse');
  @GdipDrawRectangle    := GetProcAddress(GIconsGdiLib, 'GdipDrawRectangle');
  @GdipFillRectangle    := GetProcAddress(GIconsGdiLib, 'GdipFillRectangle');
  @GdipFillEllipse      := GetProcAddress(GIconsGdiLib, 'GdipFillEllipse');
  @GdipFillPolygon      := GetProcAddress(GIconsGdiLib, 'GdipFillPolygon');

  if Assigned(GdiplusStartup) and Assigned(GdipDrawLine) then
  begin
    FillChar(Input, SizeOf(Input), 0);
    Input.GdiplusVersion := 1;
    if GdiplusStartup(GIconsGdiToken, @Input, nil) = 0 then
      Result := True
    else
      Result := False;
  end
  else
    Result := False;
end;

{ TVeloxIcons }

class function TVeloxIcons.Count: Integer;
begin
  Result := Ord(High(TVeloxIcon)) + 1;
end;

class function TVeloxIcons.IconName(const AIcon: TVeloxIcon): string;
begin
  case AIcon of
    viHome:         Result := 'Home';
    viSettings:     Result := 'Settings';
    viSearch:       Result := 'Search';
    viRefresh:      Result := 'Refresh';
    viFolder:       Result := 'Folder';
    viTerminal:     Result := 'Terminal';
    viGrid:         Result := 'Grid';
    viFilter:       Result := 'Filter';
    viSliders:      Result := 'Sliders';
    viCopy:         Result := 'Copy';
    viCheck:        Result := 'Check';
    viClose:        Result := 'Close';
    viTrash:        Result := 'Trash';
    viPlay:         Result := 'Play';
    viPause:        Result := 'Pause';
    viDownload:     Result := 'Download';
    viUpload:       Result := 'Upload';
    viUndo:         Result := 'Undo';
    viRedo:         Result := 'Redo';
    viInfo:         Result := 'Info';
    viWarning:      Result := 'Warning';
    viError:        Result := 'Error';
    viShield:       Result := 'Shield';
    viCpu:          Result := 'CPU';
    viMemory:       Result := 'Memory';
    viCloud:        Result := 'Cloud';
    viBell:         Result := 'Bell';
    viUser:         Result := 'User';
    viStar:         Result := 'Star';
    viPin:          Result := 'Pin';
    viLock:         Result := 'Lock';
    viChevronDown:  Result := 'ChevronDown';
    viChevronRight: Result := 'ChevronRight';
    viChevronLeft:  Result := 'ChevronLeft';
    viChevronUp:    Result := 'ChevronUp';
  else
    Result := 'None';
  end;
end;

class function TVeloxIcons.FromName(const AName: string): TVeloxIcon;
var
  I: TVeloxIcon;
begin
  for I := Low(TVeloxIcon) to High(TVeloxIcon) do
  begin
    if SameText(IconName(I), AName) then
      Exit(I);
  end;
  Result := viNone;
end;

class procedure TVeloxIcons.Draw(const ACanvas: TCanvas; const ARect: TRect;
  const AIcon: TVeloxIcon; const AColor: TColor; const ASize: Integer);
var
  G: TGpGraphics;
  Pen: TGpPen;
  Brush: TGpBrush;
  CX, CY, HalfS, DrawSize: Integer;
  S, X, Y: Single;
  Pts: array[0..4] of TGpPointF;
begin
  if (AIcon = viNone) or (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then
    Exit;

  DrawSize := ASize;
  if DrawSize <= 0 then
    DrawSize := 16;

  CX := (ARect.Left + ARect.Right) div 2;
  CY := (ARect.Top + ARect.Bottom) div 2;
  HalfS := DrawSize div 2;

  X := CX - HalfS;
  Y := CY - HalfS;
  S := DrawSize;

  if not InitIconsGdiPlus or (GdipCreateFromHDC(ACanvas.Handle, G) <> 0) then
    Exit;

  try
    GdipSetSmoothingMode(G, SmoothingModeAntiAlias);

    // Default 1.5px stroke scaled proportionally
    if GdipCreatePen1(ColorToARGB(AColor, 255), S / 12.0, UnitPixel, Pen) <> 0 then
      Exit;

    try
      GdipCreateSolidFill(ColorToARGB(AColor, 255), Brush);
      try
        case AIcon of
          viHome:
            begin
              // Roof triangle + house body
              GdipDrawLine(G, Pen, X + S * 0.1, Y + S * 0.5, X + S * 0.5, Y + S * 0.15);
              GdipDrawLine(G, Pen, X + S * 0.5, Y + S * 0.15, X + S * 0.9, Y + S * 0.5);
              GdipDrawLine(G, Pen, X + S * 0.25, Y + S * 0.45, X + S * 0.25, Y + S * 0.85);
              GdipDrawLine(G, Pen, X + S * 0.75, Y + S * 0.45, X + S * 0.75, Y + S * 0.85);
              GdipDrawLine(G, Pen, X + S * 0.25, Y + S * 0.85, X + S * 0.75, Y + S * 0.85);
              // Door
              GdipDrawLine(G, Pen, X + S * 0.42, Y + S * 0.85, X + S * 0.42, Y + S * 0.60);
              GdipDrawLine(G, Pen, X + S * 0.58, Y + S * 0.85, X + S * 0.58, Y + S * 0.60);
              GdipDrawLine(G, Pen, X + S * 0.42, Y + S * 0.60, X + S * 0.58, Y + S * 0.60);
            end;

          viSettings:
            begin
              // Cog center circle
              GdipDrawEllipse(G, Pen, X + S * 0.32, Y + S * 0.32, S * 0.36, S * 0.36);
              // 4 outer teeth
              GdipDrawLine(G, Pen, X + S * 0.5, Y + S * 0.12, X + S * 0.5, Y + S * 0.28);
              GdipDrawLine(G, Pen, X + S * 0.5, Y + S * 0.72, X + S * 0.5, Y + S * 0.88);
              GdipDrawLine(G, Pen, X + S * 0.12, Y + S * 0.5, X + S * 0.28, Y + S * 0.5);
              GdipDrawLine(G, Pen, X + S * 0.72, Y + S * 0.5, X + S * 0.88, Y + S * 0.5);
              // 4 diagonal teeth
              GdipDrawLine(G, Pen, X + S * 0.24, Y + S * 0.24, X + S * 0.34, Y + S * 0.34);
              GdipDrawLine(G, Pen, X + S * 0.66, Y + S * 0.66, X + S * 0.76, Y + S * 0.76);
              GdipDrawLine(G, Pen, X + S * 0.76, Y + S * 0.24, X + S * 0.66, Y + S * 0.34);
              GdipDrawLine(G, Pen, X + S * 0.34, Y + S * 0.66, X + S * 0.24, Y + S * 0.76);
            end;

          viSearch:
            begin
              // Magnifier glass circle + handle
              GdipDrawEllipse(G, Pen, X + S * 0.15, Y + S * 0.15, S * 0.52, S * 0.52);
              GdipDrawLine(G, Pen, X + S * 0.55, Y + S * 0.55, X + S * 0.85, Y + S * 0.85);
            end;

          viRefresh:
            begin
              // Arc arrow
              GdipDrawArc(G, Pen, X + S * 0.15, Y + S * 0.15, S * 0.7, S * 0.7, 30, 270);
              // Arrowhead
              GdipDrawLine(G, Pen, X + S * 0.75, Y + S * 0.5, X + S * 0.75, Y + S * 0.25);
              GdipDrawLine(G, Pen, X + S * 0.75, Y + S * 0.25, X + S * 0.55, Y + S * 0.25);
            end;

          viFolder:
            begin
              // Folder tab + body
              GdipDrawLine(G, Pen, X + S * 0.12, Y + S * 0.28, X + S * 0.40, Y + S * 0.28);
              GdipDrawLine(G, Pen, X + S * 0.40, Y + S * 0.28, X + S * 0.50, Y + S * 0.38);
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.38, X + S * 0.88, Y + S * 0.38);
              GdipDrawLine(G, Pen, X + S * 0.88, Y + S * 0.38, X + S * 0.88, Y + S * 0.78);
              GdipDrawLine(G, Pen, X + S * 0.88, Y + S * 0.78, X + S * 0.12, Y + S * 0.78);
              GdipDrawLine(G, Pen, X + S * 0.12, Y + S * 0.78, X + S * 0.12, Y + S * 0.28);
            end;

          viTerminal:
            begin
              // Prompt prompt >_
              GdipDrawLine(G, Pen, X + S * 0.20, Y + S * 0.30, X + S * 0.42, Y + S * 0.48);
              GdipDrawLine(G, Pen, X + S * 0.42, Y + S * 0.48, X + S * 0.20, Y + S * 0.66);
              GdipDrawLine(G, Pen, X + S * 0.52, Y + S * 0.66, X + S * 0.80, Y + S * 0.66);
            end;

          viGrid:
            begin
              // 4 grid squares
              GdipDrawRectangle(G, Pen, X + S * 0.16, Y + S * 0.16, S * 0.30, S * 0.30);
              GdipDrawRectangle(G, Pen, X + S * 0.54, Y + S * 0.16, S * 0.30, S * 0.30);
              GdipDrawRectangle(G, Pen, X + S * 0.16, Y + S * 0.54, S * 0.30, S * 0.30);
              GdipDrawRectangle(G, Pen, X + S * 0.54, Y + S * 0.54, S * 0.30, S * 0.30);
            end;

          viFilter:
            begin
              // Funnel
              GdipDrawLine(G, Pen, X + S * 0.15, Y + S * 0.20, X + S * 0.85, Y + S * 0.20);
              GdipDrawLine(G, Pen, X + S * 0.85, Y + S * 0.20, X + S * 0.58, Y + S * 0.55);
              GdipDrawLine(G, Pen, X + S * 0.58, Y + S * 0.55, X + S * 0.58, Y + S * 0.82);
              GdipDrawLine(G, Pen, X + S * 0.58, Y + S * 0.82, X + S * 0.42, Y + S * 0.75);
              GdipDrawLine(G, Pen, X + S * 0.42, Y + S * 0.75, X + S * 0.42, Y + S * 0.55);
              GdipDrawLine(G, Pen, X + S * 0.42, Y + S * 0.55, X + S * 0.15, Y + S * 0.20);
            end;

          viSliders:
            begin
              // Horizontal track lines + thumb ticks
              GdipDrawLine(G, Pen, X + S * 0.15, Y + S * 0.32, X + S * 0.85, Y + S * 0.32);
              GdipDrawEllipse(G, Pen, X + S * 0.32, Y + S * 0.22, S * 0.20, S * 0.20);
              GdipDrawLine(G, Pen, X + S * 0.15, Y + S * 0.68, X + S * 0.85, Y + S * 0.68);
              GdipDrawEllipse(G, Pen, X + S * 0.56, Y + S * 0.58, S * 0.20, S * 0.20);
            end;

          viCopy:
            begin
              // Back sheet
              GdipDrawRectangle(G, Pen, X + S * 0.32, Y + S * 0.15, S * 0.52, S * 0.56);
              // Front sheet
              GdipDrawRectangle(G, Pen, X + S * 0.16, Y + S * 0.28, S * 0.52, S * 0.56);
            end;

          viCheck:
            begin
              // Checkmark tick
              GdipDrawLine(G, Pen, X + S * 0.18, Y + S * 0.52, X + S * 0.42, Y + S * 0.76);
              GdipDrawLine(G, Pen, X + S * 0.42, Y + S * 0.76, X + S * 0.82, Y + S * 0.26);
            end;

          viClose:
            begin
              // X cross
              GdipDrawLine(G, Pen, X + S * 0.24, Y + S * 0.24, X + S * 0.76, Y + S * 0.76);
              GdipDrawLine(G, Pen, X + S * 0.76, Y + S * 0.24, X + S * 0.24, Y + S * 0.76);
            end;

          viTrash:
            begin
              // Bin body + lid
              GdipDrawLine(G, Pen, X + S * 0.18, Y + S * 0.28, X + S * 0.82, Y + S * 0.28);
              GdipDrawLine(G, Pen, X + S * 0.38, Y + S * 0.28, X + S * 0.38, Y + S * 0.18);
              GdipDrawLine(G, Pen, X + S * 0.38, Y + S * 0.18, X + S * 0.62, Y + S * 0.18);
              GdipDrawLine(G, Pen, X + S * 0.62, Y + S * 0.18, X + S * 0.62, Y + S * 0.28);
              GdipDrawLine(G, Pen, X + S * 0.26, Y + S * 0.28, X + S * 0.30, Y + S * 0.82);
              GdipDrawLine(G, Pen, X + S * 0.30, Y + S * 0.82, X + S * 0.70, Y + S * 0.82);
              GdipDrawLine(G, Pen, X + S * 0.70, Y + S * 0.82, X + S * 0.74, Y + S * 0.28);
              // Center slashes
              GdipDrawLine(G, Pen, X + S * 0.42, Y + S * 0.38, X + S * 0.42, Y + S * 0.72);
              GdipDrawLine(G, Pen, X + S * 0.58, Y + S * 0.38, X + S * 0.58, Y + S * 0.72);
            end;

          viPlay:
            begin
              // Triangle
              Pts[0].X := X + S * 0.25; Pts[0].Y := Y + S * 0.18;
              Pts[1].X := X + S * 0.82; Pts[1].Y := Y + S * 0.50;
              Pts[2].X := X + S * 0.25; Pts[2].Y := Y + S * 0.82;
              GdipFillPolygon(G, Brush, @Pts[0], 3, FillModeAlternate);
            end;

          viPause:
            begin
              // Two vertical bars
              GdipFillRectangle(G, Brush, X + S * 0.24, Y + S * 0.20, S * 0.18, S * 0.60);
              GdipFillRectangle(G, Brush, X + S * 0.58, Y + S * 0.20, S * 0.18, S * 0.60);
            end;

          viDownload:
            begin
              // Arrow down + tray
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.15, X + S * 0.50, Y + S * 0.65);
              GdipDrawLine(G, Pen, X + S * 0.28, Y + S * 0.45, X + S * 0.50, Y + S * 0.65);
              GdipDrawLine(G, Pen, X + S * 0.72, Y + S * 0.45, X + S * 0.50, Y + S * 0.65);
              GdipDrawLine(G, Pen, X + S * 0.18, Y + S * 0.80, X + S * 0.82, Y + S * 0.80);
            end;

          viUpload:
            begin
              // Arrow up + tray
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.65, X + S * 0.50, Y + S * 0.15);
              GdipDrawLine(G, Pen, X + S * 0.28, Y + S * 0.35, X + S * 0.50, Y + S * 0.15);
              GdipDrawLine(G, Pen, X + S * 0.72, Y + S * 0.35, X + S * 0.50, Y + S * 0.15);
              GdipDrawLine(G, Pen, X + S * 0.18, Y + S * 0.80, X + S * 0.82, Y + S * 0.80);
            end;

          viUndo:
            begin
              // Curved arrow counter-clockwise
              GdipDrawArc(G, Pen, X + S * 0.20, Y + S * 0.30, S * 0.60, S * 0.55, 0, -180);
              GdipDrawLine(G, Pen, X + S * 0.20, Y + S * 0.55, X + S * 0.20, Y + S * 0.30);
              GdipDrawLine(G, Pen, X + S * 0.20, Y + S * 0.30, X + S * 0.40, Y + S * 0.30);
            end;

          viRedo:
            begin
              // Curved arrow clockwise
              GdipDrawArc(G, Pen, X + S * 0.20, Y + S * 0.30, S * 0.60, S * 0.55, 180, 180);
              GdipDrawLine(G, Pen, X + S * 0.80, Y + S * 0.55, X + S * 0.80, Y + S * 0.30);
              GdipDrawLine(G, Pen, X + S * 0.80, Y + S * 0.30, X + S * 0.60, Y + S * 0.30);
            end;

          viInfo:
            begin
              // Circle + 'i'
              GdipDrawEllipse(G, Pen, X + S * 0.15, Y + S * 0.15, S * 0.70, S * 0.70);
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.42, X + S * 0.50, Y + S * 0.70);
              GdipFillEllipse(G, Brush, X + S * 0.44, Y + S * 0.26, S * 0.12, S * 0.12);
            end;

          viWarning:
            begin
              // Triangle + '!'
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.15, X + S * 0.88, Y + S * 0.82);
              GdipDrawLine(G, Pen, X + S * 0.88, Y + S * 0.82, X + S * 0.12, Y + S * 0.82);
              GdipDrawLine(G, Pen, X + S * 0.12, Y + S * 0.82, X + S * 0.50, Y + S * 0.15);
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.36, X + S * 0.50, Y + S * 0.60);
              GdipFillEllipse(G, Brush, X + S * 0.45, Y + S * 0.68, S * 0.10, S * 0.10);
            end;

          viError:
            begin
              // Circle + X
              GdipDrawEllipse(G, Pen, X + S * 0.15, Y + S * 0.15, S * 0.70, S * 0.70);
              GdipDrawLine(G, Pen, X + S * 0.34, Y + S * 0.34, X + S * 0.66, Y + S * 0.66);
              GdipDrawLine(G, Pen, X + S * 0.66, Y + S * 0.34, X + S * 0.34, Y + S * 0.66);
            end;

          viShield:
            begin
              // Shield badge
              GdipDrawLine(G, Pen, X + S * 0.18, Y + S * 0.20, X + S * 0.82, Y + S * 0.20);
              GdipDrawLine(G, Pen, X + S * 0.82, Y + S * 0.20, X + S * 0.82, Y + S * 0.50);
              GdipDrawLine(G, Pen, X + S * 0.82, Y + S * 0.50, X + S * 0.50, Y + S * 0.85);
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.85, X + S * 0.18, Y + S * 0.50);
              GdipDrawLine(G, Pen, X + S * 0.18, Y + S * 0.50, X + S * 0.18, Y + S * 0.20);
            end;

          viCpu:
            begin
              // Microchip square + pins
              GdipDrawRectangle(G, Pen, X + S * 0.28, Y + S * 0.28, S * 0.44, S * 0.44);
              GdipDrawLine(G, Pen, X + S * 0.40, Y + S * 0.12, X + S * 0.40, Y + S * 0.28);
              GdipDrawLine(G, Pen, X + S * 0.60, Y + S * 0.12, X + S * 0.60, Y + S * 0.28);
              GdipDrawLine(G, Pen, X + S * 0.40, Y + S * 0.72, X + S * 0.40, Y + S * 0.88);
              GdipDrawLine(G, Pen, X + S * 0.60, Y + S * 0.72, X + S * 0.60, Y + S * 0.88);
              GdipDrawLine(G, Pen, X + S * 0.12, Y + S * 0.40, X + S * 0.28, Y + S * 0.40);
              GdipDrawLine(G, Pen, X + S * 0.12, Y + S * 0.60, X + S * 0.28, Y + S * 0.60);
              GdipDrawLine(G, Pen, X + S * 0.72, Y + S * 0.40, X + S * 0.88, Y + S * 0.40);
              GdipDrawLine(G, Pen, X + S * 0.72, Y + S * 0.60, X + S * 0.88, Y + S * 0.60);
            end;

          viMemory:
            begin
              // RAM stick
              GdipDrawRectangle(G, Pen, X + S * 0.15, Y + S * 0.32, S * 0.70, S * 0.36);
              // Notches
              GdipDrawLine(G, Pen, X + S * 0.25, Y + S * 0.68, X + S * 0.25, Y + S * 0.78);
              GdipDrawLine(G, Pen, X + S * 0.40, Y + S * 0.68, X + S * 0.40, Y + S * 0.78);
              GdipDrawLine(G, Pen, X + S * 0.60, Y + S * 0.68, X + S * 0.60, Y + S * 0.78);
              GdipDrawLine(G, Pen, X + S * 0.75, Y + S * 0.68, X + S * 0.75, Y + S * 0.78);
            end;

          viCloud:
            begin
              // Cloud arcs + base line
              GdipDrawArc(G, Pen, X + S * 0.18, Y + S * 0.42, S * 0.32, S * 0.32, 90, 180);
              GdipDrawArc(G, Pen, X + S * 0.36, Y + S * 0.24, S * 0.36, S * 0.36, 160, 180);
              GdipDrawArc(G, Pen, X + S * 0.58, Y + S * 0.38, S * 0.26, S * 0.26, 270, 140);
              GdipDrawLine(G, Pen, X + S * 0.30, Y + S * 0.74, X + S * 0.76, Y + S * 0.74);
            end;

          viBell:
            begin
              // Bell body + clapper
              GdipDrawArc(G, Pen, X + S * 0.25, Y + S * 0.22, S * 0.50, S * 0.50, 180, 180);
              GdipDrawLine(G, Pen, X + S * 0.25, Y + S * 0.47, X + S * 0.18, Y + S * 0.72);
              GdipDrawLine(G, Pen, X + S * 0.75, Y + S * 0.47, X + S * 0.82, Y + S * 0.72);
              GdipDrawLine(G, Pen, X + S * 0.18, Y + S * 0.72, X + S * 0.82, Y + S * 0.72);
              GdipDrawEllipse(G, Pen, X + S * 0.42, Y + S * 0.74, S * 0.16, S * 0.14);
            end;

          viUser:
            begin
              // Head + shoulders
              GdipDrawEllipse(G, Pen, X + S * 0.35, Y + S * 0.18, S * 0.30, S * 0.30);
              GdipDrawArc(G, Pen, X + S * 0.18, Y + S * 0.52, S * 0.64, S * 0.45, 180, 180);
            end;

          viStar:
            begin
              // 5-point star
              Pts[0].X := X + S * 0.50; Pts[0].Y := Y + S * 0.15;
              Pts[1].X := X + S * 0.62; Pts[1].Y := Y + S * 0.40;
              Pts[2].X := X + S * 0.88; Pts[2].Y := Y + S * 0.40;
              Pts[3].X := X + S * 0.66; Pts[3].Y := Y + S * 0.58;
              Pts[4].X := X + S * 0.74; Pts[4].Y := Y + S * 0.85;
              GdipDrawLine(G, Pen, Pts[0].X, Pts[0].Y, Pts[1].X, Pts[1].Y);
              GdipDrawLine(G, Pen, Pts[1].X, Pts[1].Y, Pts[2].X, Pts[2].Y);
              GdipDrawLine(G, Pen, Pts[2].X, Pts[2].Y, Pts[3].X, Pts[3].Y);
              GdipDrawLine(G, Pen, Pts[3].X, Pts[3].Y, Pts[4].X, Pts[4].Y);
              GdipDrawLine(G, Pen, Pts[4].X, Pts[4].Y, X + S * 0.50, Y + S * 0.70);
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.70, X + S * 0.26, Y + S * 0.85);
              GdipDrawLine(G, Pen, X + S * 0.26, Y + S * 0.85, X + S * 0.34, Y + S * 0.58);
              GdipDrawLine(G, Pen, X + S * 0.34, Y + S * 0.58, X + S * 0.12, Y + S * 0.40);
              GdipDrawLine(G, Pen, X + S * 0.12, Y + S * 0.40, X + S * 0.38, Y + S * 0.40);
              GdipDrawLine(G, Pen, X + S * 0.38, Y + S * 0.40, Pts[0].X, Pts[0].Y);
            end;

          viPin:
            begin
              // Pushpin
              GdipDrawLine(G, Pen, X + S * 0.35, Y + S * 0.18, X + S * 0.65, Y + S * 0.18);
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.18, X + S * 0.50, Y + S * 0.55);
              GdipDrawLine(G, Pen, X + S * 0.25, Y + S * 0.55, X + S * 0.75, Y + S * 0.55);
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.55, X + S * 0.50, Y + S * 0.85);
            end;

          viLock:
            begin
              // Shackle + body
              GdipDrawArc(G, Pen, X + S * 0.30, Y + S * 0.18, S * 0.40, S * 0.40, 180, 180);
              GdipDrawRectangle(G, Pen, X + S * 0.22, Y + S * 0.42, S * 0.56, S * 0.44);
              GdipDrawEllipse(G, Pen, X + S * 0.45, Y + S * 0.56, S * 0.10, S * 0.12);
            end;

          viChevronDown:
            begin
              GdipDrawLine(G, Pen, X + S * 0.25, Y + S * 0.38, X + S * 0.50, Y + S * 0.63);
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.63, X + S * 0.75, Y + S * 0.38);
            end;

          viChevronRight:
            begin
              GdipDrawLine(G, Pen, X + S * 0.38, Y + S * 0.25, X + S * 0.63, Y + S * 0.50);
              GdipDrawLine(G, Pen, X + S * 0.63, Y + S * 0.50, X + S * 0.38, Y + S * 0.75);
            end;

          viChevronLeft:
            begin
              GdipDrawLine(G, Pen, X + S * 0.63, Y + S * 0.25, X + S * 0.38, Y + S * 0.50);
              GdipDrawLine(G, Pen, X + S * 0.38, Y + S * 0.50, X + S * 0.63, Y + S * 0.75);
            end;

          viChevronUp:
            begin
              GdipDrawLine(G, Pen, X + S * 0.25, Y + S * 0.63, X + S * 0.50, Y + S * 0.38);
              GdipDrawLine(G, Pen, X + S * 0.50, Y + S * 0.38, X + S * 0.75, Y + S * 0.63);
            end;
        end;
      finally
        GdipDeleteBrush(Brush);
      end;
    finally
      GdipDeletePen(Pen);
    end;
  finally
    GdipDeleteGraphics(G);
  end;
end;

end.
