unit Velox.Animation;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Animation
  Purpose:
    60 FPS Easing & Smooth Property Tweener (`TVeloxAnimator`) inspired by
    `caesar2011/DelphiUIAnimation` and `bgrabitmap/bgracontrols`. Provides
    standard easing curves (`vekLinear`, `vekEaseOutQuad`, `vekEaseOutCubic`,
    `vekEaseInOutCubic`, `vekEaseOutBack`) and non-blocking integer, float, and
    color interpolation.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Graphics,
  ExtCtrls,
  Velox.Types;

type
  TVeloxEasingKind = (
    vekLinear,
    vekEaseOutQuad,
    vekEaseOutCubic,
    vekEaseInOutCubic,
    vekEaseOutBack
  );

  TVeloxIntTweenStep = procedure(const ACurrentValue: Integer) of object;
  TVeloxColorTweenStep = procedure(const ACurrentColor: TColor) of object;

  /// <summary>
  /// 60 FPS Easing Evaluator & Non-Blocking Property Tweener
  /// </summary>
  TVeloxAnimator = class(TComponent)
  private
    FTimer: TTimer;
    FStartInt: Integer;
    FEndInt: Integer;
    FStartColor: TColor;
    FEndColor: TColor;
    FCurrentStep: Integer;
    FTotalSteps: Integer;
    FEasing: TVeloxEasingKind;
    FOnIntStep: TVeloxIntTweenStep;
    FOnColorStep: TVeloxColorTweenStep;
    FIsColorMode: Boolean;
    procedure OnTimerTick(Sender: TObject);
    function GetIsRunning: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    /// Evaluates a normalized progress `AT` (0.0 .. 1.0) using the specified easing curve.
    /// </summary>
    class function EvaluateEasing(const AT: Single; const AEasing: TVeloxEasingKind): Single; static;

    /// <summary>
    /// Interpolates an integer between `AStart` and `AEnd` at normalized progress `AT` (0.0 .. 1.0).
    /// </summary>
    class function LerpInt(const AStart, AEnd: Integer; const AT: Single;
      const AEasing: TVeloxEasingKind = vekEaseOutCubic): Integer; static;

    /// <summary>
    /// Interpolates a TColor between `AStart` and `AEnd` at normalized progress `AT` (0.0 .. 1.0).
    /// </summary>
    class function LerpColor(const AStart, AEnd: TColor; const AT: Single;
      const AEasing: TVeloxEasingKind = vekEaseOutCubic): TColor; static;

    /// <summary>
    /// Starts a 60 FPS integer tween (e.g. sidebar width or scroll offset).
    /// </summary>
    procedure StartIntTween(const AStart, AEnd: Integer; const ADurationMs: Cardinal;
      const AEasing: TVeloxEasingKind; const AOnStep: TVeloxIntTweenStep);

    /// <summary>
    /// Starts a 60 FPS TColor transition (e.g. card hover or alert flash).
    /// </summary>
    procedure StartColorTween(const AStart, AEnd: TColor; const ADurationMs: Cardinal;
      const AEasing: TVeloxEasingKind; const AOnStep: TVeloxColorTweenStep);

    /// <summary>
    /// Immediately jumps to the final target value and stops the timer.
    /// </summary>
    procedure CompleteImmediately;
    procedure Stop;

    property IsRunning: Boolean read GetIsRunning;
  end;

implementation

{ TVeloxAnimator }

constructor TVeloxAnimator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 16; // ~60 FPS
  FTimer.OnTimer := OnTimerTick;
end;

destructor TVeloxAnimator.Destroy;
begin
  FTimer.Enabled := False;
  inherited Destroy;
end;

function TVeloxAnimator.GetIsRunning: Boolean;
begin
  Result := Assigned(FTimer) and FTimer.Enabled;
end;

class function TVeloxAnimator.EvaluateEasing(const AT: Single;
  const AEasing: TVeloxEasingKind): Single;
const
  C1 = 1.70158;
  C3 = C1 + 1.0;
var
  T, Inv, BackT: Single;
begin
  T := TVeloxUtils.ClampSingle(AT, 0.0, 1.0);
  case AEasing of
    vekLinear:
      Result := T;
    vekEaseOutQuad:
      Result := 1.0 - (1.0 - T) * (1.0 - T);
    vekEaseOutCubic:
      begin
        Inv := 1.0 - T;
        Result := 1.0 - (Inv * Inv * Inv);
      end;
    vekEaseInOutCubic:
      begin
        if T < 0.5 then
          Result := 4.0 * T * T * T
        else
        begin
          Inv := -2.0 * T + 2.0;
          Result := 1.0 - (Inv * Inv * Inv) * 0.5;
        end;
      end;
    vekEaseOutBack:
      begin
        BackT := T - 1.0;
        Result := 1.0 + C3 * (BackT * BackT * BackT) + C1 * (BackT * BackT);
      end;
  else
    Result := T;
  end;
end;

class function TVeloxAnimator.LerpInt(const AStart, AEnd: Integer;
  const AT: Single; const AEasing: TVeloxEasingKind): Integer;
var
  Eased: Single;
begin
  Eased := EvaluateEasing(AT, AEasing);
  Result := Round(AStart + (AEnd - AStart) * Eased);
end;

class function TVeloxAnimator.LerpColor(const AStart, AEnd: TColor;
  const AT: Single; const AEasing: TVeloxEasingKind): TColor;
var
  Eased: Single;
begin
  Eased := EvaluateEasing(AT, AEasing);
  Result := TVeloxUtils.BlendColor(AStart, AEnd, Eased);
end;

procedure TVeloxAnimator.StartIntTween(const AStart, AEnd: Integer;
  const ADurationMs: Cardinal; const AEasing: TVeloxEasingKind;
  const AOnStep: TVeloxIntTweenStep);
begin
  FTimer.Enabled := False;
  FIsColorMode := False;
  FStartInt := AStart;
  FEndInt := AEnd;
  FEasing := AEasing;
  FOnIntStep := AOnStep;
  FCurrentStep := 0;
  FTotalSteps := Integer(ADurationMs) div 16;
  if FTotalSteps < 1 then FTotalSteps := 1;
  FTimer.Enabled := True;
end;

procedure TVeloxAnimator.StartColorTween(const AStart, AEnd: TColor;
  const ADurationMs: Cardinal; const AEasing: TVeloxEasingKind;
  const AOnStep: TVeloxColorTweenStep);
begin
  FTimer.Enabled := False;
  FIsColorMode := True;
  FStartColor := AStart;
  FEndColor := AEnd;
  FEasing := AEasing;
  FOnColorStep := AOnStep;
  FCurrentStep := 0;
  FTotalSteps := Integer(ADurationMs) div 16;
  if FTotalSteps < 1 then FTotalSteps := 1;
  FTimer.Enabled := True;
end;

procedure TVeloxAnimator.CompleteImmediately;
begin
  FTimer.Enabled := False;
  FCurrentStep := FTotalSteps;
  if FIsColorMode then
  begin
    if Assigned(FOnColorStep) then
      FOnColorStep(FEndColor);
  end
  else
  begin
    if Assigned(FOnIntStep) then
      FOnIntStep(FEndInt);
  end;
end;

procedure TVeloxAnimator.Stop;
begin
  FTimer.Enabled := False;
end;

procedure TVeloxAnimator.OnTimerTick(Sender: TObject);
var
  Progress: Single;
begin
  Inc(FCurrentStep);
  if FCurrentStep >= FTotalSteps then
  begin
    CompleteImmediately;
    Exit;
  end;

  Progress := FCurrentStep / FTotalSteps;
  if FIsColorMode then
  begin
    if Assigned(FOnColorStep) then
      FOnColorStep(LerpColor(FStartColor, FEndColor, Progress, FEasing));
  end
  else
  begin
    if Assigned(FOnIntStep) then
      FOnIntStep(LerpInt(FStartInt, FEndInt, Progress, FEasing));
  end;
end;

end.
