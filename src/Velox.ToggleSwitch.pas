unit Velox.ToggleSwitch;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.ToggleSwitch
  Purpose:
    Windows 11 Fluent Pill Toggle Switch (`TVeloxToggleSwitch`) and Smooth
    GDI+ Track Slider (`TVeloxSlider`) inspired by `rareMaxim/FluentUI` and
    `EtheaDev/StyledComponents`. Replaces legacy Windows 95 TCheckBox and
    TTrackBar widgets with hardware-accelerated GDI+ vector controls.
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
  Velox.GdiPlus;

type
  /// <summary>
  /// Windows 11 Fluent Pill Toggle Switch (On/Off thumb + caption)
  /// </summary>
  TVeloxToggleSwitch = class(TCustomControl)
  private
    FChecked: Boolean;
    FCaption: string;
    FColors: TVeloxThemeColors;
    FHot: Boolean;
    FAnimThumbX: Single;
    FTargetThumbX: Single;
    FAnimTimer: TTimer;
    FOnToggle: TNotifyEvent;
    procedure SetChecked(const AValue: Boolean);
    procedure SetCaptionText(const AValue: string);
    procedure OnAnimTick(Sender: TObject);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure Click; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor CreateSwitch(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth: Integer;
      const ACaption: string; const AColors: TVeloxThemeColors;
      const AChecked: Boolean = False;
      const AOnToggle: TNotifyEvent = nil);
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    property Checked: Boolean read FChecked write SetChecked;
    property CaptionText: string read FCaption write SetCaptionText;
    property TabStop default True;
    property OnToggle: TNotifyEvent read FOnToggle write FOnToggle;
  end;

  /// <summary>
  /// Flat GDI+ Progress/Value Slider (`0..100`)
  /// </summary>
  TVeloxSlider = class(TCustomControl)
  private
    FMin: Integer;
    FMax: Integer;
    FPosition: Integer;
    FColors: TVeloxThemeColors;
    FDragging: Boolean;
    FOnChange: TNotifyEvent;
    procedure SetPosition(const AValue: Integer);
    procedure UpdateFromMouseX(const AX: Integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor CreateSlider(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth: Integer;
      const AMin, AMax, APosition: Integer;
      const AColors: TVeloxThemeColors;
      const AOnChange: TNotifyEvent = nil);
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    property Min: Integer read FMin write FMin;
    property Max: Integer read FMax write FMax;
    property Position: Integer read FPosition write SetPosition;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

{ TVeloxToggleSwitch }

constructor TVeloxToggleSwitch.CreateSwitch(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth: Integer;
  const ACaption: string; const AColors: TVeloxThemeColors;
  const AChecked: Boolean; const AOnToggle: TNotifyEvent);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  TabStop := True;
  SetBounds(ALeft, ATop, AWidth, 26);
  Cursor := crHandPoint;
  FCaption := ACaption;
  FColors := AColors;
  FChecked := AChecked;
  FHot := False;
  FOnToggle := AOnToggle;

  if FChecked then
    FAnimThumbX := 24.0
  else
    FAnimThumbX := 4.0;
  FTargetThumbX := FAnimThumbX;

  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 15;
  FAnimTimer.Enabled := False;
  FAnimTimer.OnTimer := OnAnimTick;
end;

procedure TVeloxToggleSwitch.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TVeloxToggleSwitch.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TVeloxToggleSwitch.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_SPACE) or (Key = VK_RETURN) then
  begin
    Click;
    Key := 0;
    Exit;
  end;
  inherited KeyDown(Key, Shift);
end;

destructor TVeloxToggleSwitch.Destroy;
begin
  FAnimTimer.Free;
  inherited Destroy;
end;

procedure TVeloxToggleSwitch.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxToggleSwitch.OnAnimTick(Sender: TObject);
begin
  // Smooth exponential dampening towards target thumb coordinate (60 FPS)
  FAnimThumbX := FAnimThumbX + (FTargetThumbX - FAnimThumbX) * 0.35;
  if Abs(FAnimThumbX - FTargetThumbX) < 0.5 then
  begin
    FAnimThumbX := FTargetThumbX;
    FAnimTimer.Enabled := False;
  end;
  Invalidate;
end;

procedure TVeloxToggleSwitch.SetChecked(const AValue: Boolean);
begin
  if FChecked <> AValue then
  begin
    FChecked := AValue;
    if FChecked then
      FTargetThumbX := 24.0
    else
      FTargetThumbX := 4.0;
    if Assigned(FAnimTimer) then
      FAnimTimer.Enabled := True;
    Invalidate;
    if Assigned(FOnToggle) then
      FOnToggle(Self);
  end;
end;

procedure TVeloxToggleSwitch.SetCaptionText(const AValue: string);
begin
  if FCaption <> AValue then
  begin
    FCaption := AValue;
    Invalidate;
  end;
end;

procedure TVeloxToggleSwitch.MouseEnter;
begin
  inherited MouseEnter;
  FHot := True;
  Invalidate;
end;

procedure TVeloxToggleSwitch.MouseLeave;
begin
  inherited MouseLeave;
  FHot := False;
  Invalidate;
end;

procedure TVeloxToggleSwitch.Click;
begin
  inherited Click;
  SetChecked(not FChecked);
end;

procedure TVeloxToggleSwitch.Paint;
const
  PillW = 42;
  PillH = 22;
  ThumbD = 14;
var
  PillR, ThumbR, TextR: TRect;
  PillFill, PillBorder, ThumbCol: TColor;
  ThumbX, ThumbY: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  if Assigned(Parent) then
    Canvas.Brush.Color := Parent.Color
  else
    Canvas.Brush.Color := FColors.Surface;
  Canvas.FillRect(Rect(0, 0, Width, Height));

  PillR := Rect(0, (Height - PillH) div 2, PillW, (Height - PillH) div 2 + PillH);
  if FChecked then
  begin
    PillFill   := FColors.Accent;
    PillBorder := FColors.Accent;
    ThumbCol   := FColors.Background;
  end
  else
  begin
    if FHot then
      PillFill := FColors.SurfaceHover
    else
      PillFill := FColors.SurfaceCard;
    PillBorder := FColors.Border;
    ThumbCol   := FColors.TextSecondary;
  end;

  ThumbX := PillR.Left + Round(FAnimThumbX);

  TVeloxGdiPlus.DrawCard(Canvas, PillR, PillFill, PillBorder, PillH div 2);

  if Focused then
    TVeloxGdiPlus.DrawGlowBorder(Canvas, PillR, FColors.Accent, PillH div 2, 140);

  ThumbY := PillR.Top + (PillH - ThumbD) div 2;
  ThumbR := Rect(ThumbX, ThumbY, ThumbX + ThumbD, ThumbY + ThumbD);
  TVeloxGdiPlus.DrawCard(Canvas, ThumbR, ThumbCol, ThumbCol, ThumbD div 2);

  if FCaption <> '' then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [];
    Canvas.Font.Color := FColors.TextPrimary;
    TextR := Rect(PillW + 10, 0, Width, Height);
    DrawText(Canvas.Handle, PChar(FCaption), Length(FCaption), TextR,
      DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_NOPREFIX);
  end;
end;

{ TVeloxSlider }

constructor TVeloxSlider.CreateSlider(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth: Integer;
  const AMin, AMax, APosition: Integer;
  const AColors: TVeloxThemeColors;
  const AOnChange: TNotifyEvent);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, AWidth, 24);
  Cursor := crHandPoint;
  FMin := AMin;
  FMax := AMax;
  if FMax <= FMin then FMax := FMin + 100;
  FPosition := APosition;
  FColors := AColors;
  FDragging := False;
  FOnChange := AOnChange;
end;

procedure TVeloxSlider.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxSlider.SetPosition(const AValue: Integer);
var
  Clamped: Integer;
begin
  Clamped := AValue;
  if Clamped < FMin then Clamped := FMin;
  if Clamped > FMax then Clamped := FMax;
  if FPosition <> Clamped then
  begin
    FPosition := Clamped;
    Invalidate;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

procedure TVeloxSlider.UpdateFromMouseX(const AX: Integer);
var
  TrackW: Integer;
  Ratio: Double;
begin
  TrackW := Width - 16;
  if TrackW <= 0 then Exit;
  Ratio := (AX - 8) / TrackW;
  if Ratio < 0.0 then Ratio := 0.0;
  if Ratio > 1.0 then Ratio := 1.0;
  SetPosition(Round(FMin + Ratio * (FMax - FMin)));
end;

procedure TVeloxSlider.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    FDragging := True;
    UpdateFromMouseX(X);
  end;
end;

procedure TVeloxSlider.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragging then
    UpdateFromMouseX(X);
end;

procedure TVeloxSlider.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragging := False;
end;

procedure TVeloxSlider.Paint;
var
  TrackR, ThumbR: TRect;
  Pct: Single;
  ThumbX, ThumbY: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  if Assigned(Parent) then
    Canvas.Brush.Color := Parent.Color
  else
    Canvas.Brush.Color := FColors.Surface;
  Canvas.FillRect(Rect(0, 0, Width, Height));

  Pct := ((FPosition - FMin) / (FMax - FMin)) * 100.0;
  TrackR := Rect(8, (Height - 6) div 2, Width - 8, (Height - 6) div 2 + 6);
  TVeloxGdiPlus.DrawProgressBar(Canvas, TrackR, Pct, FColors.Border, FColors.Accent);

  ThumbX := 8 + Round((Pct / 100.0) * (Width - 16)) - 7;
  ThumbY := (Height - 14) div 2;
  ThumbR := Rect(ThumbX, ThumbY, ThumbX + 14, ThumbY + 14);
  TVeloxGdiPlus.DrawCard(Canvas, ThumbR, FColors.Accent, FColors.TextPrimary, 7);
end;

end.
