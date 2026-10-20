unit Velox.Feedback;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Feedback
  Purpose:
    WinUI-style feedback widgets drawn with GDI+ (inspired by
    `microsoft/microsoft-ui-xaml`):
    1. `TVeloxInfoBar`      — inline severity banner with glyph + dismiss (X)
    2. `TVeloxProgressRing` — determinate donut or indeterminate 8-dot spinner
    3. `TVeloxSkeleton`     — shimmering placeholder lines while data loads
    Animated controls expose `Step` (advance one frame) and a `Running`
    property that drives an internal 16..90 ms TTimer.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  Controls,
  ExtCtrls,
  Velox.Types,
  Velox.GdiPlus,
  Velox.Charts;

const
  {$IFDEF FPC}
  VELOX_GLYPH_CHECK = #$E2#$9C#$93; // ✓
  {$ELSE}
  VELOX_GLYPH_CHECK = #$2713;
  {$ENDIF}

type
  /// <summary>
  /// Inline severity banner (info / success / warning / error) with dismiss button
  /// </summary>
  TVeloxInfoBar = class(TCustomControl)
  private
    FTitle: string;
    FMessage: string;
    FSeverity: TVeloxSeverity;
    FColors: TVeloxThemeColors;
    FClosable: Boolean;
    FOnClosed: TNotifyEvent;
    procedure SetSeverity(const AValue: TVeloxSeverity);
    function SeverityColor: TColor;
    function SeverityGlyph: string;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor CreateBar(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth: Integer;
      const ATitle, AMessage: string; const ASeverity: TVeloxSeverity;
      const AColors: TVeloxThemeColors; const AClosable: Boolean = True);
    procedure ApplyColors(const AColors: TVeloxThemeColors);
    function CloseRect: TRect;
    function IsCloseHit(const X, Y: Integer): Boolean;
    procedure Dismiss;

    property Title: string read FTitle write FTitle;
    property MessageText: string read FMessage write FMessage;
    property Severity: TVeloxSeverity read FSeverity write SetSeverity;
    property Closable: Boolean read FClosable write FClosable;
    property OnClosed: TNotifyEvent read FOnClosed write FOnClosed;
  end;

  /// <summary>
  /// Determinate donut / indeterminate dot-spinner progress ring
  /// </summary>
  TVeloxProgressRing = class(TCustomControl)
  private
    FColors: TVeloxThemeColors;
    FPercent: Single;
    FIndeterminate: Boolean;
    FPhase: Integer;
    FTimer: TTimer;
    procedure SetPercent(const AValue: Single);
    procedure SetIndeterminate(const AValue: Boolean);
    function GetRunning: Boolean;
    procedure SetRunning(const AValue: Boolean);
    procedure OnTick(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor CreateRing(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, ASize: Integer; const AColors: TVeloxThemeColors);
    procedure ApplyColors(const AColors: TVeloxThemeColors);
    procedure Step;

    property Percent: Single read FPercent write SetPercent;
    property Indeterminate: Boolean read FIndeterminate write SetIndeterminate;
    property Phase: Integer read FPhase;
    property Running: Boolean read GetRunning write SetRunning;
  end;

  /// <summary>
  /// Shimmering skeleton placeholder lines
  /// </summary>
  TVeloxSkeleton = class(TCustomControl)
  private
    FColors: TVeloxThemeColors;
    FLineCount: Integer;
    FOffset: Integer;
    FTimer: TTimer;
    procedure SetLineCount(const AValue: Integer);
    function GetRunning: Boolean;
    procedure SetRunning(const AValue: Boolean);
    procedure OnTick(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor CreateSkeleton(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth, AHeight, ALineCount: Integer;
      const AColors: TVeloxThemeColors);
    procedure ApplyColors(const AColors: TVeloxThemeColors);
    procedure Step;

    property LineCount: Integer read FLineCount write SetLineCount;
    property Offset: Integer read FOffset;
    property Running: Boolean read GetRunning write SetRunning;
  end;

implementation

{ TVeloxInfoBar }

constructor TVeloxInfoBar.CreateBar(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth: Integer; const ATitle, AMessage: string;
  const ASeverity: TVeloxSeverity; const AColors: TVeloxThemeColors;
  const AClosable: Boolean);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, AWidth, 48);
  FTitle := ATitle;
  FMessage := AMessage;
  FSeverity := ASeverity;
  FColors := AColors;
  FClosable := AClosable;
end;

procedure TVeloxInfoBar.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxInfoBar.SetSeverity(const AValue: TVeloxSeverity);
begin
  if FSeverity <> AValue then
  begin
    FSeverity := AValue;
    Invalidate;
  end;
end;

function TVeloxInfoBar.SeverityColor: TColor;
begin
  if FSeverity = vsIdle then
    Result := FColors.Accent
  else
    Result := TVeloxUtils.SeverityToColor(FSeverity, FColors);
end;

function TVeloxInfoBar.SeverityGlyph: string;
begin
  case FSeverity of
    vsNormal:   Result := VELOX_GLYPH_CHECK;
    vsWarning:  Result := '!';
    vsCritical: Result := 'x';
  else
    Result := 'i';
  end;
end;

function TVeloxInfoBar.CloseRect: TRect;
begin
  Result := Rect(Width - 36, (Height - 24) div 2, Width - 12, (Height - 24) div 2 + 24);
end;

function TVeloxInfoBar.IsCloseHit(const X, Y: Integer): Boolean;
var
  R: TRect;
begin
  R := CloseRect;
  Result := FClosable and (X >= R.Left) and (X < R.Right) and (Y >= R.Top) and (Y < R.Bottom);
end;

procedure TVeloxInfoBar.Dismiss;
begin
  Visible := False;
  if Assigned(FOnClosed) then
    FOnClosed(Self);
end;

procedure TVeloxInfoBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and IsCloseHit(X, Y) then
    Dismiss;
end;

procedure TVeloxInfoBar.Paint;
var
  Col: TColor;
  R, GlyphR, CR: TRect;
  TW, TH: Integer;
  G: string;
begin
  Col := SeverityColor;
  Canvas.Brush.Style := bsSolid;
  if Assigned(Parent) then
    Canvas.Brush.Color := Parent.Color
  else
    Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(Rect(0, 0, Width, Height));

  R := Rect(0, 0, Width, Height);
  TVeloxGdiPlus.DrawCard(Canvas, R, TVeloxUtils.BlendColor(FColors.SurfaceCard, Col, 0.14), Col, 8);

  GlyphR := Rect(14, (Height - 22) div 2, 36, (Height - 22) div 2 + 22);
  TVeloxGdiPlus.DrawCard(Canvas, GlyphR, Col, Col, 11);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clWhite;
  G := SeverityGlyph;
  TW := Canvas.TextWidth(G);
  TH := Canvas.TextHeight(G);
  Canvas.TextOut(GlyphR.Left + (22 - TW) div 2, GlyphR.Top + (22 - TH) div 2, G);

  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := FColors.TextPrimary;
  Canvas.TextOut(48, 7, FTitle);
  Canvas.Font.Style := [];
  Canvas.Font.Size := 8;
  Canvas.Font.Color := FColors.TextSecondary;
  Canvas.TextOut(48, 26, FMessage);

  if FClosable then
  begin
    CR := CloseRect;
    Canvas.Font.Size := 10;
    Canvas.Font.Color := FColors.TextSecondary;
    TW := Canvas.TextWidth('x');
    TH := Canvas.TextHeight('x');
    Canvas.TextOut(CR.Left + (24 - TW) div 2, CR.Top + (24 - TH) div 2, 'x');
  end;
end;

{ TVeloxProgressRing }

constructor TVeloxProgressRing.CreateRing(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, ASize: Integer; const AColors: TVeloxThemeColors);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, ASize, ASize);
  FColors := AColors;
  FPercent := 0.0;
  FIndeterminate := True;
  FPhase := 0;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 90;
  FTimer.OnTimer := OnTick;
end;

procedure TVeloxProgressRing.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxProgressRing.SetPercent(const AValue: Single);
begin
  FPercent := TVeloxUtils.ClampSingle(AValue, 0.0, 100.0);
  Invalidate;
end;

procedure TVeloxProgressRing.SetIndeterminate(const AValue: Boolean);
begin
  FIndeterminate := AValue;
  Invalidate;
end;

function TVeloxProgressRing.GetRunning: Boolean;
begin
  Result := Assigned(FTimer) and FTimer.Enabled;
end;

procedure TVeloxProgressRing.SetRunning(const AValue: Boolean);
begin
  FTimer.Enabled := AValue;
end;

procedure TVeloxProgressRing.OnTick(Sender: TObject);
begin
  Step;
end;

procedure TVeloxProgressRing.Step;
begin
  FPhase := (FPhase + 1) mod 8;
  Invalidate;
end;

procedure TVeloxProgressRing.Paint;
var
  I, Age, CX, CY, R, DX, DY: Integer;
  Ang: Double;
  Col: TColor;
begin
  Canvas.Brush.Style := bsSolid;
  if Assigned(Parent) then
    Canvas.Brush.Color := Parent.Color
  else
    Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(Rect(0, 0, Width, Height));

  if FIndeterminate then
  begin
    CX := Width div 2;
    CY := Height div 2;
    if Width < Height then R := Width div 2 - 6 else R := Height div 2 - 6;
    if R < 4 then R := 4;
    for I := 0 to 7 do
    begin
      Ang := I * (Pi / 4.0);
      DX := CX + Round(R * Cos(Ang));
      DY := CY + Round(R * Sin(Ang));
      Age := (FPhase - I + 8) mod 8;
      Col := TVeloxUtils.BlendColor(FColors.Accent, FColors.Background, (Age / 8.0) * 0.85);
      TVeloxGdiPlus.DrawCard(Canvas, Rect(DX - 3, DY - 3, DX + 4, DY + 4), Col, Col, 3);
    end;
  end
  else
    TVeloxCharts.DrawDonutGauge(Canvas, Rect(0, 0, Width, Height), FPercent,
      Format('%d%%', [Round(FPercent)]), '', FColors, FColors.Accent, 5.0);
end;

{ TVeloxSkeleton }

constructor TVeloxSkeleton.CreateSkeleton(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth, AHeight, ALineCount: Integer;
  const AColors: TVeloxThemeColors);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, AWidth, AHeight);
  FColors := AColors;
  FLineCount := ALineCount;
  if FLineCount < 1 then FLineCount := 1;
  FOffset := 0;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 33;
  FTimer.OnTimer := OnTick;
end;

procedure TVeloxSkeleton.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxSkeleton.SetLineCount(const AValue: Integer);
begin
  if AValue < 1 then
    FLineCount := 1
  else
    FLineCount := AValue;
  Invalidate;
end;

function TVeloxSkeleton.GetRunning: Boolean;
begin
  Result := Assigned(FTimer) and FTimer.Enabled;
end;

procedure TVeloxSkeleton.SetRunning(const AValue: Boolean);
begin
  FTimer.Enabled := AValue;
end;

procedure TVeloxSkeleton.OnTick(Sender: TObject);
begin
  Step;
end;

procedure TVeloxSkeleton.Step;
var
  Span: Integer;
begin
  Span := Width + 200;
  if Span < 1 then Span := 1;
  FOffset := (FOffset + 24) mod Span;
  Invalidate;
end;

procedure TVeloxSkeleton.Paint;
const
  Ratios: array[0..3] of Double = (1.0, 0.82, 0.94, 0.6);
var
  I, LineH, Gap, LW, MidX, Dist: Integer;
  BaseCol, Col: TColor;
  R: TRect;
begin
  Canvas.Brush.Style := bsSolid;
  if Assigned(Parent) then
    Canvas.Brush.Color := Parent.Color
  else
    Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(Rect(0, 0, Width, Height));

  Gap := 12;
  LineH := (Height - Gap * (FLineCount - 1)) div FLineCount;
  if LineH > 18 then LineH := 18;
  if LineH < 6 then LineH := 6;
  BaseCol := TVeloxUtils.BlendColor(FColors.SurfaceCard, FColors.Border, 0.5);
  for I := 0 to FLineCount - 1 do
  begin
    LW := Round(Width * Ratios[I mod 4]);
    R := Rect(0, I * (LineH + Gap), LW, I * (LineH + Gap) + LineH);
    MidX := LW div 2;
    Dist := Abs(MidX - (FOffset - 100));
    Col := BaseCol;
    if Dist < 160 then
      Col := TVeloxUtils.BlendColor(BaseCol, FColors.SurfaceHover, 0.9 * (1.0 - Dist / 160.0));
    TVeloxGdiPlus.DrawCard(Canvas, R, Col, Col, 4);
  end;
end;

end.
