unit Velox.DpiCanvas;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.DpiCanvas (Unit #76)
  Purpose:
    Per-Monitor v2 Auto-Rescaling GDI+ Drawing Context (`TVeloxDpiCanvas`).
    Eliminates manual `MulDiv` and High-DPI coordinate calculations by
    automatically scaling logical 96-DPI coordinates, radii, stroke widths,
    and icon glyphs to the target monitor's physical resolution on the fly.
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
  Velox.Icons,
  Velox.Dpi;

type
  /// <summary>
  /// DPI-aware auto-rescaling GDI+ drawing context.
  /// Translates logical 96-DPI (100%) coordinates and dimensions into
  /// device physical pixels with sub-pixel antialiasing.
  /// </summary>
  TVeloxDpiCanvas = class
  private
    FCanvas: TCanvas;
    FDpi: Integer;
    FScaleFactor: Single;
    procedure SetDpi(const AValue: Integer);
  public
    constructor Create(const ACanvas: TCanvas; const ADpi: Integer = 96);
    constructor CreateForControl(const ACanvas: TCanvas; const AControl: TControl);

    /// <summary>
    /// Scales a scalar integer pixel dimension by the active DPI ratio
    /// </summary>
    function Scale(const AVal: Integer): Integer; inline;

    /// <summary>
    /// Scales a single-precision floating point dimension
    /// </summary>
    function ScaleSingle(const AVal: Single): Single; inline;

    /// <summary>
    /// Scales a 96-DPI logical rectangle into device coordinates
    /// </summary>
    function ScaleRect(const ARect: TRect): TRect;

    /// <summary>
    /// Scales logical (X, Y) coordinates into device TPoint
    /// </summary>
    function ScalePoint(const X, Y: Integer): TPoint;

    // --- High-DPI Auto-Scaled GDI+ Primitives ---

    /// <summary>
    /// Renders a rounded card with auto-scaled corner radius and border
    /// </summary>
    procedure DrawCard(const ARect: TRect; const AFillColor, ABorderColor: TColor;
      const ARadius: Integer = 8);

    /// <summary>
    /// Renders a horizontal progress bar with auto-scaled dimensions
    /// </summary>
    procedure DrawProgressBar(const ARect: TRect; const APercent: Single;
      const ABgColor, ABarColor: TColor);

    /// <summary>
    /// Renders a text pill badge with auto-scaled padding
    /// </summary>
    procedure DrawBadge(const ARect: TRect; const AText: string;
      const ABgColor, ATextColor: TColor);

    /// <summary>
    /// Renders a soft glowing focus border with auto-scaled radius and spread
    /// </summary>
    procedure DrawGlowBorder(const ARect: TRect; const AGlowColor: TColor;
      const ARadius: Integer = 8; const AGlowSpread: Integer = 3);

    /// <summary>
    /// Renders a Windows 11 Fluent vector icon glyph scaled to current DPI
    /// </summary>
    procedure DrawIcon(const ARect: TRect; const AIcon: TVeloxIcon;
      const AColor: TColor; const ASize: Integer = 16);

    property Canvas: TCanvas read FCanvas write FCanvas;
    property Dpi: Integer read FDpi write SetDpi;
    property ScaleFactor: Single read FScaleFactor;
  end;

implementation

{ TVeloxDpiCanvas }

constructor TVeloxDpiCanvas.Create(const ACanvas: TCanvas; const ADpi: Integer);
begin
  inherited Create;
  FCanvas := ACanvas;
  SetDpi(ADpi);
end;

constructor TVeloxDpiCanvas.CreateForControl(const ACanvas: TCanvas; const AControl: TControl);
var
  TargetDpi: Integer;
begin
  TargetDpi := 96;
  if Assigned(AControl) then
  begin
    if (AControl is TWinControl) and TWinControl(AControl).HandleAllocated then
      TargetDpi := TVeloxDpi.GetWindowDpi(TWinControl(AControl).Handle)
    else
      TargetDpi := TVeloxDpi.GetSystemDpi;
  end;
  Create(ACanvas, TargetDpi);
end;

procedure TVeloxDpiCanvas.SetDpi(const AValue: Integer);
begin
  if AValue > 0 then
    FDpi := AValue
  else
    FDpi := 96;
  FScaleFactor := FDpi / 96.0;
end;

function TVeloxDpiCanvas.Scale(const AVal: Integer): Integer;
begin
  if FDpi = 96 then
    Result := AVal
  else
    Result := Round(AVal * FScaleFactor);
end;

function TVeloxDpiCanvas.ScaleSingle(const AVal: Single): Single;
begin
  Result := AVal * FScaleFactor;
end;

function TVeloxDpiCanvas.ScaleRect(const ARect: TRect): TRect;
begin
  if FDpi = 96 then
    Result := ARect
  else
  begin
    Result.Left := Scale(ARect.Left);
    Result.Top := Scale(ARect.Top);
    Result.Right := Scale(ARect.Right);
    Result.Bottom := Scale(ARect.Bottom);
  end;
end;

function TVeloxDpiCanvas.ScalePoint(const X, Y: Integer): TPoint;
begin
  Result.X := Scale(X);
  Result.Y := Scale(Y);
end;

procedure TVeloxDpiCanvas.DrawCard(const ARect: TRect; const AFillColor, ABorderColor: TColor;
  const ARadius: Integer);
var
  DevR: TRect;
  DevRad: Integer;
begin
  if not Assigned(FCanvas) then Exit;
  DevR := ScaleRect(ARect);
  DevRad := Scale(ARadius);
  TVeloxGdiPlus.DrawCard(FCanvas, DevR, AFillColor, ABorderColor, DevRad);
end;

procedure TVeloxDpiCanvas.DrawProgressBar(const ARect: TRect; const APercent: Single;
  const ABgColor, ABarColor: TColor);
var
  DevR: TRect;
begin
  if not Assigned(FCanvas) then Exit;
  DevR := ScaleRect(ARect);
  TVeloxGdiPlus.DrawProgressBar(FCanvas, DevR, APercent, ABgColor, ABarColor);
end;

procedure TVeloxDpiCanvas.DrawBadge(const ARect: TRect; const AText: string;
  const ABgColor, ATextColor: TColor);
var
  DevR: TRect;
begin
  if not Assigned(FCanvas) then Exit;
  DevR := ScaleRect(ARect);
  TVeloxGdiPlus.DrawBadge(FCanvas, DevR, AText, ABgColor, ATextColor);
end;

procedure TVeloxDpiCanvas.DrawGlowBorder(const ARect: TRect; const AGlowColor: TColor;
  const ARadius: Integer; const AGlowSpread: Integer);
var
  DevR: TRect;
  DevRad, DevSpread: Integer;
begin
  if not Assigned(FCanvas) then Exit;
  DevR := ScaleRect(ARect);
  DevRad := Scale(ARadius);
  DevSpread := Scale(AGlowSpread);
  TVeloxGdiPlus.DrawGlowBorder(FCanvas, DevR, AGlowColor, DevRad, DevSpread);
end;

procedure TVeloxDpiCanvas.DrawIcon(const ARect: TRect; const AIcon: TVeloxIcon;
  const AColor: TColor; const ASize: Integer);
var
  DevR: TRect;
  DevSize: Integer;
begin
  if not Assigned(FCanvas) then Exit;
  DevR := ScaleRect(ARect);
  DevSize := Scale(ASize);
  TVeloxIcons.Draw(FCanvas, DevR, AIcon, AColor, DevSize);
end;

end.
