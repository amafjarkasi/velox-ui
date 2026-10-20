unit Velox.Types;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Types
  Purpose:
    1. Cross-compiler (Delphi VCL + Lazarus/FPC LCL) type & glyph definitions
    2. Pre-tuned Fluent Dark & Light design token palettes (TVeloxThemeColors)
    3. Zero-allocation circular ring buffer (TVeloxRingBuffer) for sparklines
    4. Color blending & human-readable telemetry/unit formatters

  IMPORTANT UNIT ORDERING RULE (Delphi & FPC Compatibility):
    Whenever both `Windows` and `Types` are in a unit's `uses` clause,
    `Windows` MUST precede `Types` so that `Types.Rect()` is not shadowed
    by `Windows.TRect`.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics;

const
  VELOX_VERSION = '1.0.0';
  VELOX_RING_CAPACITY = 60;

  // Cross-compiler UTF-8 (LCL) vs UTF-16 (Delphi VCL) Unicode glyphs.
  // Using literal byte/codepoint sequences guarantees zero mojibake regardless
  // of source file BOM or compiler string encoding settings.
  {$IFDEF FPC}
  VELOX_ARROW_ASC   = #$E2#$96#$B2; // ▲ (U+25B2)
  VELOX_ARROW_DESC  = #$E2#$96#$BC; // ▼ (U+25BC)
  VELOX_TREE_BRANCH = #$E2#$94#$94#$E2#$94#$80' '; // └─
  VELOX_BULLET      = #$E2#$80#$A2; // • (U+2022)
  VELOX_MIDDOT      = #$C2#$B7;     // · (U+00B7)
  {$ELSE}
  VELOX_ARROW_ASC   = #$25B2;
  VELOX_ARROW_DESC  = #$25BC;
  VELOX_TREE_BRANCH = #$2514#$2500' ';
  VELOX_BULLET      = #$2022;
  VELOX_MIDDOT      = #$00B7;
  {$ENDIF}

type
  TSingleDynArray = array of Single;

  /// <summary>
  /// Application theme mode (Dark, Light, or System Auto-Detect)
  /// </summary>
  TVeloxTheme = (vtDark, vtLight);

  /// <summary>
  /// Windows 11 DWM System Backdrop Material (DWMWA_SYSTEMBACKDROP_TYPE = 38)
  /// </summary>
  TVeloxBackdropType = (
    vbtAuto      = 0,
    vbtNone      = 1,
    vbtMica      = 2, // DWMSBT_MAINWINDOW (Mica subtle desktop tint)
    vbtAcrylic   = 3, // DWMSBT_TRANSIENTWINDOW (Acrylic translucent blur)
    vbtTabbed    = 4  // DWMSBT_TABBEDWINDOW (Mica Alt)
  );

  /// <summary>
  /// Universal health/severity state for rows, badges, and threshold alerts
  /// </summary>
  TVeloxSeverity = (vsIdle, vsNormal, vsWarning, vsCritical);

  /// <summary>
  /// Semantic Fluent UI design tokens for zero-hardcoded-color rendering
  /// </summary>
  TVeloxThemeColors = record
    Background: TColor;
    Surface: TColor;
    SurfaceCard: TColor;
    SurfaceHover: TColor;
    TextPrimary: TColor;
    TextSecondary: TColor;
    Accent: TColor;
    AccentSecondary: TColor;
    Border: TColor;
    Success: TColor;
    Warning: TColor;
    Danger: TColor;
    SidebarBg: TColor;
    SidebarText: TColor;
  end;

  /// <summary>
  /// Fixed-capacity O(1) circular ring buffer for zero-allocation sparkline
  /// and rolling average histories.
  /// </summary>
  TVeloxRingBuffer = record
  private
    FData: array[0..VELOX_RING_CAPACITY - 1] of Single;
    FHead: Integer;
    FCount: Integer;
    FCapacity: Integer;
    procedure EnsureCapacity;
  public
    procedure Clear(const AMaxCapacity: Integer = 30);
    procedure Add(const AValue: Single);
    function ToArray: TSingleDynArray;
    function Latest: Single;
    function Average: Single;
    function Peak: Single;
    property Count: Integer read FCount;
    property Capacity: Integer read FCapacity;
  end;

  /// <summary>
  /// Formatting, color manipulation, and palette factory helpers
  /// </summary>
  TVeloxUtils = class
  public
    class function GetThemeColors(const ATheme: TVeloxTheme): TVeloxThemeColors; static;
    class function BlendColor(const AFrom, ATo: TColor; const AAlpha: Single): TColor; static;
    class function SeverityToColor(const ASeverity: TVeloxSeverity; const AColors: TVeloxThemeColors): TColor; static;
    class function SeverityToString(const ASeverity: TVeloxSeverity): string; static;

    class function FormatBytes(const ABytes: Int64): string; static;
    class function FormatMegabytes(const AMB: Double): string; static;
    class function FormatRateKBps(const AKBps: Double): string; static;
    class function FormatPercent(const AValue: Single): string; static;
    class function FormatDuration(const ASeconds: UInt64): string; static;
    class function ClampSingle(const AValue, AMin, AMax: Single): Single; static;
  end;

implementation

{ TVeloxRingBuffer }

procedure TVeloxRingBuffer.EnsureCapacity;
begin
  if (FCapacity <= 0) or (FCapacity > VELOX_RING_CAPACITY) then
    FCapacity := 30;
end;

procedure TVeloxRingBuffer.Clear(const AMaxCapacity: Integer);
var
  I: Integer;
begin
  if (AMaxCapacity > 0) and (AMaxCapacity <= VELOX_RING_CAPACITY) then
    FCapacity := AMaxCapacity
  else
    FCapacity := 30;
  FHead := 0;
  FCount := 0;
  for I := 0 to VELOX_RING_CAPACITY - 1 do
    FData[I] := 0.0;
end;

procedure TVeloxRingBuffer.Add(const AValue: Single);
begin
  EnsureCapacity;
  FData[FHead] := AValue;
  FHead := (FHead + 1) mod FCapacity;
  if FCount < FCapacity then
    Inc(FCount);
end;

function TVeloxRingBuffer.ToArray: TSingleDynArray;
var
  I, StartIdx: Integer;
begin
  EnsureCapacity;
  Result := nil;
  SetLength(Result, FCount);
  if FCount = 0 then
    Exit;

  if FCount < FCapacity then
    StartIdx := 0
  else
    StartIdx := FHead;

  for I := 0 to FCount - 1 do
    Result[I] := FData[(StartIdx + I) mod FCapacity];
end;

function TVeloxRingBuffer.Latest: Single;
var
  LastIdx: Integer;
begin
  EnsureCapacity;
  if FCount = 0 then
    Exit(0.0);
  LastIdx := (FHead - 1 + FCapacity) mod FCapacity;
  Result := FData[LastIdx];
end;

function TVeloxRingBuffer.Average: Single;
var
  Arr: TSingleDynArray;
  I: Integer;
  Sum: Double;
begin
  Arr := ToArray;
  if Length(Arr) = 0 then
    Exit(0.0);
  Sum := 0.0;
  for I := 0 to High(Arr) do
    Sum := Sum + Arr[I];
  Result := Sum / Length(Arr);
end;

function TVeloxRingBuffer.Peak: Single;
var
  Arr: TSingleDynArray;
  I: Integer;
begin
  Arr := ToArray;
  if Length(Arr) = 0 then
    Exit(0.0);
  Result := Arr[0];
  for I := 1 to High(Arr) do
    if Arr[I] > Result then
      Result := Arr[I];
end;

{ TVeloxUtils }

class function TVeloxUtils.GetThemeColors(const ATheme: TVeloxTheme): TVeloxThemeColors;
begin
  if ATheme = vtDark then
  begin
    // Windows 11 Obsidian Slate & Electric Cyan/Indigo Dark Palette (BGR TColor)
    Result.Background      := $001A1410; // #10141A Deep Obsidian
    Result.Surface         := $00241D18; // #181D24 Elevated Surface
    Result.SurfaceCard     := $002E251E; // #1E252E Card Container
    Result.SurfaceHover    := $003A3027; // #27303A Hover State
    Result.TextPrimary     := $00F8FAFC; // #FCFAF8 Crisp Off-White
    Result.TextSecondary   := $00B8A494; // #94A4B8 Muted Slate
    Result.Accent          := $00F8BD38; // #38BDF8 Electric Cyan
    Result.AccentSecondary := $00F16663; // #6366F1 Indigo
    Result.Border          := $0042372D; // #2D3742 Subtle Hairline
    Result.Success         := $0081B910; // #10B981 Emerald
    Result.Warning         := $000B9EF5; // #F59E0B Amber
    Result.Danger          := $005E3FF4; // #F43F5E Rose Red
    Result.SidebarBg       := $00140F0C; // #0C0F14 Sidebar Obsidian
    Result.SidebarText     := $00F0E6E0; // #E0E6F0 Sidebar Caption
  end
  else
  begin
    // Windows 11 Fluent Daylight Palette (BGR TColor)
    Result.Background      := $00F9F6F3; // #F3F6F9 Cool Alabaster
    Result.Surface         := $00FFFFFF; // #FFFFFF Pure White
    Result.SurfaceCard     := $00F8F4F0; // #F0F4F8 Subtle Card
    Result.SurfaceHover    := $00EFE8E1; // #E1E8EF Hover State
    Result.TextPrimary     := $00261C15; // #151C26 Deep Ink
    Result.TextSecondary   := $00766557; // #576576 Slate Gray
    Result.Accent          := $00D66305; // #0563D6 Fluent Blue
    Result.AccentSecondary := $00E5464F; // #4F46E5 Indigo
    Result.Border          := $00E2D8CE; // #CED8E2 Crisp Border
    Result.Success         := $00548A0D; // #0D8A54 Forest Emerald
    Result.Warning         := $000677D9; // #D97706 Warm Amber
    Result.Danger          := $00381DDE; // #DE1D38 Crimson
    Result.SidebarBg       := $00281E17; // #171E28 Contrast Sidebar
    Result.SidebarText     := $00F5F2F0; // #F0F2F5 Light Sidebar Text
  end;
end;

class function TVeloxUtils.BlendColor(const AFrom, ATo: TColor; const AAlpha: Single): TColor;
var
  C1, C2: LongInt;
  R1, G1, B1, R2, G2, B2: Byte;
  R, G, B: Byte;
  T: Single;
begin
  T := ClampSingle(AAlpha, 0.0, 1.0);
  C1 := ColorToRGB(AFrom);
  C2 := ColorToRGB(ATo);
  R1 := GetRValue(C1); G1 := GetGValue(C1); B1 := GetBValue(C1);
  R2 := GetRValue(C2); G2 := GetGValue(C2); B2 := GetBValue(C2);
  R := Round(R1 + (R2 - R1) * T);
  G := Round(G1 + (G2 - G1) * T);
  B := Round(B1 + (B2 - B1) * T);
  Result := RGB(R, G, B);
end;

class function TVeloxUtils.SeverityToColor(const ASeverity: TVeloxSeverity;
  const AColors: TVeloxThemeColors): TColor;
begin
  case ASeverity of
    vsIdle:     Result := AColors.TextSecondary;
    vsNormal:   Result := AColors.Success;
    vsWarning:  Result := AColors.Warning;
    vsCritical: Result := AColors.Danger;
  else
    Result := AColors.TextPrimary;
  end;
end;

class function TVeloxUtils.SeverityToString(const ASeverity: TVeloxSeverity): string;
begin
  case ASeverity of
    vsIdle:     Result := 'Idle';
    vsNormal:   Result := 'Normal';
    vsWarning:  Result := 'Warning';
    vsCritical: Result := 'Critical';
  else
    Result := 'Unknown';
  end;
end;

class function TVeloxUtils.FormatBytes(const ABytes: Int64): string;
const
  KB = 1024.0;
  MB = KB * 1024.0;
  GB = MB * 1024.0;
  TB = GB * 1024.0;
begin
  if ABytes < 0 then
    Result := '0 B'
  else if ABytes >= TB then
    Result := Format('%.2f TB', [ABytes / TB])
  else if ABytes >= GB then
    Result := Format('%.2f GB', [ABytes / GB])
  else if ABytes >= MB then
    Result := Format('%.1f MB', [ABytes / MB])
  else if ABytes >= KB then
    Result := Format('%.1f KB', [ABytes / KB])
  else
    Result := Format('%d B', [ABytes]);
end;

class function TVeloxUtils.FormatMegabytes(const AMB: Double): string;
begin
  if AMB >= 1024.0 then
    Result := Format('%.2f GB', [AMB / 1024.0])
  else
    Result := Format('%.1f MB', [AMB]);
end;

class function TVeloxUtils.FormatRateKBps(const AKBps: Double): string;
begin
  if AKBps <= 0.0 then
    Result := '0.0 KB/s'
  else if AKBps >= 1024.0 then
    Result := Format('%.2f MB/s', [AKBps / 1024.0])
  else
    Result := Format('%.1f KB/s', [AKBps]);
end;

class function TVeloxUtils.FormatPercent(const AValue: Single): string;
begin
  Result := Format('%.1f%%', [ClampSingle(AValue, 0.0, 100.0)]);
end;

class function TVeloxUtils.FormatDuration(const ASeconds: UInt64): string;
var
  Days, Hours, Mins, Secs: UInt64;
begin
  Days  := ASeconds div 86400;
  Hours := (ASeconds mod 86400) div 3600;
  Mins  := (ASeconds mod 3600) div 60;
  Secs  := ASeconds mod 60;

  if Days > 0 then
    Result := Format('%dd %0.2dh %0.2dm', [Days, Hours, Mins])
  else
    Result := Format('%0.2d:%0.2d:%0.2d', [Hours, Mins, Secs]);
end;

class function TVeloxUtils.ClampSingle(const AValue, AMin, AMax: Single): Single;
begin
  if AValue < AMin then
    Result := AMin
  else if AValue > AMax then
    Result := AMax
  else
    Result := AValue;
end;

end.
