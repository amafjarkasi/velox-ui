unit Velox.StyledButton;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.StyledButton
  Purpose:
    1. Hardware-accelerated GDI+ custom-drawn Fluent button (`TVeloxStyledButton`)
       inspired by `EtheaDev/StyledComponents` and `bgrabitmap/bgracontrols`.
       Bypasses the legacy Win32 light button bevel in dark mode and supports
       rounded corners, hover/press states, and semantic variants
       (`vsbPrimary`, `vsbSurface`, `vsbDanger`, `vsbOutline`).
    2. Segmented Filter Chip Group (`TVeloxChipGroup`) that renders pill-shaped
       filter chips with true active accent fills (replacing `[Bracket]` text
       workarounds).
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
  TVeloxButtonVariant = (vsbSurface, vsbPrimary, vsbDanger, vsbOutline);

  /// <summary>
  /// GDI+ Custom-Drawn Fluent Button with Hover/Press States
  /// </summary>
  TVeloxStyledButton = class(TCustomControl)
  private
    FCaption: string;
    FVariant: TVeloxButtonVariant;
    FColors: TVeloxThemeColors;
    FRadius: Integer;
    FHot: Boolean;
    FPressed: Boolean;
    FActive: Boolean;
    procedure SetCaptionText(const AValue: string);
    procedure SetVariant(const AValue: TVeloxButtonVariant);
    procedure SetActive(const AValue: Boolean);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor CreateButton(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth, AHeight: Integer;
      const ACaption: string; const AColors: TVeloxThemeColors;
      const AVariant: TVeloxButtonVariant = vsbSurface;
      const AOnClick: TNotifyEvent = nil);
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    property CaptionText: string read FCaption write SetCaptionText;
    property Variant: TVeloxButtonVariant read FVariant write SetVariant;
    property Active: Boolean read FActive write SetActive;
    property Radius: Integer read FRadius write FRadius;
    property OnClick;
  end;

  TVeloxChipSelectEvent = procedure(Sender: TObject; const ASelectedIndex: Integer) of object;

  /// <summary>
  /// Mutual-exclusion segmented pill filter chip bar (e.g. All | Heavy RAM | Active CPU | Alerts)
  /// </summary>
  TVeloxChipGroup = class(TComponent)
  private
    FChips: array of TVeloxStyledButton;
    FSelectedIndex: Integer;
    FColors: TVeloxThemeColors;
    FOnChipSelected: TVeloxChipSelectEvent;
    procedure HandleChipClick(Sender: TObject);
    procedure SetSelectedIndex(const AValue: Integer);
    function GetChipCount: Integer;
  public
    constructor CreateGroup(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AHeight: Integer;
      const ALabels: array of string; const AColors: TVeloxThemeColors;
      const AOnSelect: TVeloxChipSelectEvent = nil);
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    property ChipCount: Integer read GetChipCount;
    property OnChipSelected: TVeloxChipSelectEvent read FOnChipSelected write FOnChipSelected;
  end;

implementation

{ TVeloxStyledButton }

constructor TVeloxStyledButton.CreateButton(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth, AHeight: Integer;
  const ACaption: string; const AColors: TVeloxThemeColors;
  const AVariant: TVeloxButtonVariant;
  const AOnClick: TNotifyEvent);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, AWidth, AHeight);
  Cursor := crHandPoint;
  FCaption := ACaption;
  FColors := AColors;
  FVariant := AVariant;
  FRadius := 6;
  FHot := False;
  FPressed := False;
  FActive := False;
  OnClick := AOnClick;
end;

procedure TVeloxStyledButton.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxStyledButton.SetCaptionText(const AValue: string);
begin
  if FCaption <> AValue then
  begin
    FCaption := AValue;
    Invalidate;
  end;
end;

procedure TVeloxStyledButton.SetVariant(const AValue: TVeloxButtonVariant);
begin
  if FVariant <> AValue then
  begin
    FVariant := AValue;
    Invalidate;
  end;
end;

procedure TVeloxStyledButton.SetActive(const AValue: Boolean);
begin
  if FActive <> AValue then
  begin
    FActive := AValue;
    Invalidate;
  end;
end;

procedure TVeloxStyledButton.MouseEnter;
begin
  inherited MouseEnter;
  FHot := True;
  Invalidate;
end;

procedure TVeloxStyledButton.MouseLeave;
begin
  inherited MouseLeave;
  FHot := False;
  FPressed := False;
  Invalidate;
end;

procedure TVeloxStyledButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    FPressed := True;
    Invalidate;
  end;
end;

procedure TVeloxStyledButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FPressed then
  begin
    FPressed := False;
    Invalidate;
  end;
end;

procedure TVeloxStyledButton.Paint;
var
  R: TRect;
  FillCol, BorderCol, TextCol: TColor;
  TW, TH: Integer;
begin
  R := Rect(0, 0, Width, Height);

  // Fill parent background first to avoid corner artifacts
  Canvas.Brush.Style := bsSolid;
  if Assigned(Parent) then
    Canvas.Brush.Color := Parent.Color
  else
    Canvas.Brush.Color := FColors.Surface;
  Canvas.FillRect(R);

  if FActive or (FVariant = vsbPrimary) then
  begin
    FillCol   := TVeloxUtils.BlendColor(FColors.SurfaceCard, FColors.Accent, 0.30);
    BorderCol := FColors.Accent;
    TextCol   := FColors.TextPrimary;
  end
  else if FVariant = vsbDanger then
  begin
    FillCol   := TVeloxUtils.BlendColor(FColors.SurfaceCard, FColors.Danger, 0.25);
    BorderCol := FColors.Danger;
    TextCol   := FColors.Danger;
  end
  else if FVariant = vsbOutline then
  begin
    FillCol   := FColors.Surface;
    BorderCol := FColors.Border;
    TextCol   := FColors.TextSecondary;
  end
  else
  begin
    FillCol   := FColors.SurfaceCard;
    BorderCol := FColors.Border;
    TextCol   := FColors.TextPrimary;
  end;

  if FPressed then
    FillCol := TVeloxUtils.BlendColor(FillCol, FColors.Accent, 0.35)
  else if FHot then
  begin
    FillCol := TVeloxUtils.BlendColor(FillCol, FColors.SurfaceHover, 0.55);
    BorderCol := TVeloxUtils.BlendColor(BorderCol, FColors.Accent, 0.45);
  end;

  TVeloxGdiPlus.DrawCard(Canvas, R, FillCol, BorderCol, FRadius);

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  if FActive or (FVariant in [vsbPrimary, vsbDanger]) then
    Canvas.Font.Style := [fsBold]
  else
    Canvas.Font.Style := [];
  Canvas.Font.Color := TextCol;

  TW := Canvas.TextWidth(FCaption);
  TH := Canvas.TextHeight(FCaption);
  Canvas.TextOut((Width - TW) div 2, (Height - TH) div 2, FCaption);
end;

{ TVeloxChipGroup }

constructor TVeloxChipGroup.CreateGroup(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AHeight: Integer;
  const ALabels: array of string; const AColors: TVeloxThemeColors;
  const AOnSelect: TVeloxChipSelectEvent);
var
  I, CurX, ChipW: Integer;
  Btn: TVeloxStyledButton;
begin
  inherited Create(AOwner);
  FColors := AColors;
  FOnChipSelected := AOnSelect;
  FSelectedIndex := 0;
  SetLength(FChips, Length(ALabels));

  CurX := ALeft;
  for I := 0 to High(ALabels) do
  begin
    ChipW := Length(ALabels[I]) * 7 + 26;
    if ChipW < 48 then ChipW := 48;

    Btn := TVeloxStyledButton.CreateButton(Self, AParent, CurX, ATop, ChipW, AHeight,
      ALabels[I], AColors, vsbSurface, HandleChipClick);
    Btn.Tag := I;
    Btn.Radius := AHeight div 2;
    Btn.Active := (I = 0);
    FChips[I] := Btn;
    Inc(CurX, ChipW + 6);
  end;
end;

function TVeloxChipGroup.GetChipCount: Integer;
begin
  Result := Length(FChips);
end;

procedure TVeloxChipGroup.SetSelectedIndex(const AValue: Integer);
var
  I: Integer;
begin
  if (AValue < 0) or (AValue > High(FChips)) then Exit;
  FSelectedIndex := AValue;
  for I := 0 to High(FChips) do
    if Assigned(FChips[I]) then
      FChips[I].Active := (I = FSelectedIndex);
end;

procedure TVeloxChipGroup.HandleChipClick(Sender: TObject);
var
  Btn: TVeloxStyledButton;
begin
  if not (Sender is TVeloxStyledButton) then Exit;
  Btn := TVeloxStyledButton(Sender);
  SetSelectedIndex(Btn.Tag);
  if Assigned(FOnChipSelected) then
    FOnChipSelected(Self, FSelectedIndex);
end;

procedure TVeloxChipGroup.ApplyColors(const AColors: TVeloxThemeColors);
var
  I: Integer;
begin
  FColors := AColors;
  for I := 0 to High(FChips) do
    if Assigned(FChips[I]) then
      FChips[I].ApplyColors(AColors);
end;

end.
