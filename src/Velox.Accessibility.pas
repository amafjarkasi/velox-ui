unit Velox.Accessibility;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Accessibility (Unit #77)
  Purpose:
    Universal Keyboard Focus Rings & Accessibility Engine.
    Provides Windows 11 Fluent 2-tone focus indicators, keyboard Tab-order
    traversal (`TVeloxFocusManager`), Space/Enter activation dispatch,
    and assistive feedback hooks for custom GDI+ controls.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  Controls,
  Generics.Collections,
  Velox.Types,
  Velox.GdiPlus;

type
  /// <summary>
  /// Windows 11 Fluent Focus Indicator Renderer
  /// </summary>
  TVeloxFocusRing = class
  public
    /// <summary>
    /// Renders a crisp 2px high-visibility double focus ring around ARect
    /// </summary>
    class procedure DrawFocusRing(const ACanvas: TCanvas; const ARect: TRect;
      const AAccentColor: TColor; const ARadius: Integer = 6;
      const AThickness: Integer = 2); static;
  end;

  /// <summary>
  /// Container Keyboard Tab-Order & Focus Traversal Manager
  /// </summary>
  TVeloxFocusManager = class(TComponent)
  private
    FControls: TList<TControl>;
    FFocusedIndex: Integer;
    function GetCount: Integer;
    function GetFocusedControl: TControl;
    procedure SetFocusedControl(const AControl: TControl);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    /// Registers a custom control into the keyboard tab sequence
    /// </summary>
    procedure RegisterControl(const AControl: TControl);

    /// <summary>
    /// Unregisters a custom control from the keyboard sequence
    /// </summary>
    procedure UnregisterControl(const AControl: TControl);

    /// <summary>
    /// Advances keyboard focus forward or backward
    /// </summary>
    procedure FocusNext(const AForward: Boolean = True);

    /// <summary>
    /// Intercepts Tab, Shift+Tab, and arrow keys to navigate controls
    /// </summary>
    function HandleKeyDown(var Key: Word; Shift: TShiftState): Boolean;

    /// <summary>
    /// Clears all registered controls
    /// </summary>
    procedure Clear;

    property Count: Integer read GetCount;
    property FocusedIndex: Integer read FFocusedIndex;
    property FocusedControl: TControl read GetFocusedControl write SetFocusedControl;
  end;

  /// <summary>
  /// Assistive keyboard dispatcher and accessibility utilities
  /// </summary>
  TVeloxAccessibility = class
  public
    /// <summary>
    /// Returns True if Key is Spacebar or Enter
    /// </summary>
    class function IsActivationKey(const Key: Word): Boolean; static; inline;

    /// <summary>
    /// Returns True if Key is Tab or Arrow navigation key
    /// </summary>
    class function IsNavigationKey(const Key: Word): Boolean; static; inline;

    /// <summary>
    /// Headless/UI announcement hook for screen readers and status telemetry
    /// </summary>
    class procedure Announce(const AMessage: string); static;
  end;

implementation

{ TVeloxFocusRing }

class procedure TVeloxFocusRing.DrawFocusRing(const ACanvas: TCanvas; const ARect: TRect;
  const AAccentColor: TColor; const ARadius: Integer; const AThickness: Integer);
var
  R: TRect;
  Thick, Rad: Integer;
begin
  if (not Assigned(ACanvas)) or (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then
    Exit;

  Thick := AThickness;
  if Thick < 1 then Thick := 1;
  Rad := ARadius;
  if Rad < 0 then Rad := 0;

  R := ARect;
  // Inner margin 1px to prevent clipping
  InflateRect(R, -1, -1);

  // Outer ambient glow (alpha 120)
  TVeloxGdiPlus.DrawGlowBorder(ACanvas, R, AAccentColor, Rad, 120);

  // High-contrast sharp accent outline
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := AAccentColor;
  ACanvas.Pen.Width := Thick;
  ACanvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, Rad * 2, Rad * 2);
  ACanvas.Pen.Width := 1;
end;

{ TVeloxFocusManager }

constructor TVeloxFocusManager.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FControls := TList<TControl>.Create;
  FFocusedIndex := -1;
end;

destructor TVeloxFocusManager.Destroy;
begin
  FControls.Free;
  inherited Destroy;
end;

procedure TVeloxFocusManager.RegisterControl(const AControl: TControl);
begin
  if Assigned(AControl) and not FControls.Contains(AControl) then
  begin
    FControls.Add(AControl);
    if FFocusedIndex < 0 then
      FFocusedIndex := 0;
  end;
end;

procedure TVeloxFocusManager.UnregisterControl(const AControl: TControl);
var
  Idx: Integer;
begin
  Idx := FControls.IndexOf(AControl);
  if Idx >= 0 then
  begin
    FControls.Delete(Idx);
    if FFocusedIndex >= FControls.Count then
      FFocusedIndex := FControls.Count - 1;
  end;
end;

procedure TVeloxFocusManager.Clear;
begin
  FControls.Clear;
  FFocusedIndex := -1;
end;

function TVeloxFocusManager.GetCount: Integer;
begin
  Result := FControls.Count;
end;

function TVeloxFocusManager.GetFocusedControl: TControl;
begin
  if (FFocusedIndex >= 0) and (FFocusedIndex < FControls.Count) then
    Result := FControls[FFocusedIndex]
  else
    Result := nil;
end;

procedure TVeloxFocusManager.SetFocusedControl(const AControl: TControl);
var
  Idx: Integer;
  OldCtrl, NewCtrl: TControl;
begin
  Idx := FControls.IndexOf(AControl);
  if Idx <> FFocusedIndex then
  begin
    OldCtrl := GetFocusedControl;
    FFocusedIndex := Idx;
    NewCtrl := GetFocusedControl;

    if Assigned(OldCtrl) then
      OldCtrl.Invalidate;

    if Assigned(NewCtrl) then
    begin
      if (NewCtrl is TWinControl) and TWinControl(NewCtrl).CanFocus then
      try
        TWinControl(NewCtrl).SetFocus;
      except
        // Guard against headless test forms that cannot receive Windows focus
      end;
      NewCtrl.Invalidate;
    end;
  end;
end;

procedure TVeloxFocusManager.FocusNext(const AForward: Boolean);
var
  OldIdx, NewIdx, StepVal: Integer;
begin
  if FControls.Count = 0 then Exit;

  if AForward then
    StepVal := 1
  else
    StepVal := -1;

  OldIdx := FFocusedIndex;
  NewIdx := (OldIdx + StepVal + FControls.Count) mod FControls.Count;

  SetFocusedControl(FControls[NewIdx]);
end;

function TVeloxFocusManager.HandleKeyDown(var Key: Word; Shift: TShiftState): Boolean;
begin
  Result := False;
  if FControls.Count = 0 then Exit;

  if Key = VK_TAB then
  begin
    if ssShift in Shift then
      FocusNext(False)
    else
      FocusNext(True);
    Key := 0;
    Result := True;
  end
  else if (Key = VK_DOWN) or (Key = VK_RIGHT) then
  begin
    FocusNext(True);
    Key := 0;
    Result := True;
  end
  else if (Key = VK_UP) or (Key = VK_LEFT) then
  begin
    FocusNext(False);
    Key := 0;
    Result := True;
  end;
end;

{ TVeloxAccessibility }

class function TVeloxAccessibility.IsActivationKey(const Key: Word): Boolean;
begin
  Result := (Key = VK_SPACE) or (Key = VK_RETURN);
end;

class function TVeloxAccessibility.IsNavigationKey(const Key: Word): Boolean;
begin
  Result := (Key = VK_TAB) or (Key = VK_LEFT) or (Key = VK_RIGHT) or
            (Key = VK_UP) or (Key = VK_DOWN);
end;

class procedure TVeloxAccessibility.Announce(const AMessage: string);
begin
  // Assistive hook: outputs to debugger/event log
  OutputDebugStringW(PWideChar(UnicodeString('VeloxAccessibility: ' + AMessage)));
end;

end.
