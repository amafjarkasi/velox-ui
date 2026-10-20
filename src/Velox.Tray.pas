unit Velox.Tray;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Tray
  Purpose:
    Themed system-tray integration (`TVeloxTray`) wrapping `TTrayIcon`:
    native balloon notifications mapped from `TVeloxSeverity`, a dynamic
    badge icon rendered with GDI+ (e.g. a live CPU% in the tray), a Win11
    quick-settings style flyout card anchored to the bottom-right work area,
    and `HideToTray` / `RestoreFromTray` helpers for minimize-to-tray.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  Controls,
  Forms,
  StdCtrls,
  ExtCtrls,
  Velox.Types,
  Velox.GdiPlus;

type
  /// <summary>
  /// Themed tray icon, badge, balloon and flyout manager
  /// </summary>
  TVeloxTray = class(TComponent)
  private
    FIcon: TTrayIcon;
    FColors: TVeloxThemeColors;
    FFlyout: TForm;
    procedure FlyoutDeactivate(Sender: TObject);
  public
    constructor CreateTray(AOwner: TComponent; const AHint: string;
      const AColors: TVeloxThemeColors);
    destructor Destroy; override;

    procedure ShowIcon;
    procedure HideIcon;
    procedure SetTooltip(const AHint: string);
    procedure ShowBalloon(const ATitle, AText: string;
      const ASeverity: TVeloxSeverity = vsIdle);

    /// <summary>Renders a 16x16 severity-colored badge bitmap. Caller frees the result.</summary>
    class function RenderBadgeBitmap(const AText: string;
      const AColors: TVeloxThemeColors; const ASeverity: TVeloxSeverity): TBitmap; static;
    /// <summary>Replaces the tray icon with a live badge (e.g. '42').</summary>
    function SetBadge(const AText: string; const ASeverity: TVeloxSeverity = vsNormal): Boolean;

    /// <summary>Bottom-right anchored popup position inside a work area.</summary>
    class function CalcFlyoutPos(const AWorkArea: TRect; const AWidth, AHeight,
      AMargin: Integer): TPoint; static;
    /// <summary>Builds (does not show) the flyout card form. Owned by the tray.</summary>
    function BuildFlyout(const ATitle: string; const ALines: array of string): TForm;
    procedure ShowFlyout(const ATitle: string; const ALines: array of string);
    procedure CloseFlyout;

    procedure HideToTray(const AForm: TForm);
    procedure RestoreFromTray(const AForm: TForm);

    property TrayIcon: TTrayIcon read FIcon;
    property Flyout: TForm read FFlyout;
  end;

implementation

constructor TVeloxTray.CreateTray(AOwner: TComponent; const AHint: string;
  const AColors: TVeloxThemeColors);
begin
  inherited Create(AOwner);
  FColors := AColors;
  FIcon := TTrayIcon.Create(Self);
  FIcon.Hint := AHint;
  FIcon.Visible := False;
end;

destructor TVeloxTray.Destroy;
begin
  if Assigned(FIcon) then
    FIcon.Visible := False;
  inherited Destroy;
end;

procedure TVeloxTray.ShowIcon;
begin
  FIcon.Visible := True;
end;

procedure TVeloxTray.HideIcon;
begin
  FIcon.Visible := False;
end;

procedure TVeloxTray.SetTooltip(const AHint: string);
begin
  FIcon.Hint := AHint;
end;

procedure TVeloxTray.ShowBalloon(const ATitle, AText: string;
  const ASeverity: TVeloxSeverity);
begin
  FIcon.BalloonTitle := ATitle;
  FIcon.BalloonHint := AText;
  case ASeverity of
    vsWarning:  FIcon.BalloonFlags := bfWarning;
    vsCritical: FIcon.BalloonFlags := bfError;
  else
    FIcon.BalloonFlags := bfInfo;
  end;
  FIcon.ShowBalloonHint;
end;

class function TVeloxTray.RenderBadgeBitmap(const AText: string;
  const AColors: TVeloxThemeColors; const ASeverity: TVeloxSeverity): TBitmap;
var
  Col: TColor;
  TW, TH: Integer;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize(16, 16);
  Col := TVeloxUtils.SeverityToColor(ASeverity, AColors);
  if ASeverity = vsIdle then
    Col := AColors.Accent;
  Result.Canvas.Brush.Color := AColors.SidebarBg;
  Result.Canvas.FillRect(Rect(0, 0, 16, 16));
  TVeloxGdiPlus.DrawCard(Result.Canvas, Rect(0, 0, 16, 16), Col, Col, 7);
  Result.Canvas.Brush.Style := bsClear;
  Result.Canvas.Font.Name := 'Segoe UI';
  Result.Canvas.Font.Size := 7;
  Result.Canvas.Font.Style := [fsBold];
  Result.Canvas.Font.Color := clWhite;
  TW := Result.Canvas.TextWidth(AText);
  TH := Result.Canvas.TextHeight(AText);
  Result.Canvas.TextOut((16 - TW) div 2, (16 - TH) div 2, AText);
end;

function TVeloxTray.SetBadge(const AText: string; const ASeverity: TVeloxSeverity): Boolean;
var
  Bmp: TBitmap;
begin
  Result := False;
  Bmp := RenderBadgeBitmap(AText, FColors, ASeverity);
  try
    try
      FIcon.Icon.Assign(Bmp);
      Result := True;
    except
      Result := False;
    end;
  finally
    Bmp.Free;
  end;
end;

class function TVeloxTray.CalcFlyoutPos(const AWorkArea: TRect; const AWidth,
  AHeight, AMargin: Integer): TPoint;
begin
  Result.X := AWorkArea.Right - AWidth - AMargin;
  Result.Y := AWorkArea.Bottom - AHeight - AMargin;
  if Result.X < AWorkArea.Left then Result.X := AWorkArea.Left;
  if Result.Y < AWorkArea.Top then Result.Y := AWorkArea.Top;
end;

procedure TVeloxTray.FlyoutDeactivate(Sender: TObject);
begin
  if Sender is TForm then
    TForm(Sender).Hide;
end;

function TVeloxTray.BuildFlyout(const ATitle: string; const ALines: array of string): TForm;
const
  FlyW = 320;
var
  H, I: Integer;
  Pnl: TPanel;
  Lbl: TLabel;
begin
  H := 56 + Length(ALines) * 22 + 14;
  if FFlyout <> nil then
  begin
    FFlyout.Free;
    FFlyout := nil;
  end;
  Result := TForm.CreateNew(Self);
  Result.BorderStyle := bsNone;
  Result.Position := poDesigned;
  Result.Color := FColors.Accent;
  Result.SetBounds(0, 0, FlyW, H);
  Result.OnDeactivate := FlyoutDeactivate;

  Pnl := TPanel.Create(Result);
  Pnl.Parent := Result;
  Pnl.BevelOuter := bvNone;
  Pnl.Color := FColors.Surface;
  Pnl.SetBounds(1, 1, FlyW - 2, H - 2);

  Lbl := TLabel.Create(Result);
  Lbl.Parent := Pnl;
  Lbl.SetBounds(18, 14, FlyW - 40, 24);
  Lbl.Caption := ATitle;
  Lbl.Font.Name := 'Segoe UI';
  Lbl.Font.Size := 11;
  Lbl.Font.Style := [fsBold];
  Lbl.Font.Color := FColors.TextPrimary;

  for I := 0 to High(ALines) do
  begin
    Lbl := TLabel.Create(Result);
    Lbl.Parent := Pnl;
    Lbl.SetBounds(18, 48 + I * 22, FlyW - 40, 18);
    Lbl.Caption := ALines[I];
    Lbl.Font.Name := 'Segoe UI';
    Lbl.Font.Size := 9;
    Lbl.Font.Color := FColors.TextSecondary;
  end;
  FFlyout := Result;
end;

procedure TVeloxTray.ShowFlyout(const ATitle: string; const ALines: array of string);
var
  F: TForm;
  P: TPoint;
begin
  F := BuildFlyout(ATitle, ALines);
  P := CalcFlyoutPos(Screen.WorkAreaRect, F.Width, F.Height, 12);
  F.Left := P.X;
  F.Top := P.Y;
  F.Show;
end;

procedure TVeloxTray.CloseFlyout;
begin
  if FFlyout <> nil then
    FFlyout.Hide;
end;

procedure TVeloxTray.HideToTray(const AForm: TForm);
begin
  if AForm = nil then Exit;
  ShowIcon;
  AForm.Hide;
end;

procedure TVeloxTray.RestoreFromTray(const AForm: TForm);
begin
  if AForm = nil then Exit;
  AForm.Show;
  AForm.WindowState := wsNormal;
  AForm.BringToFront;
end;

end.
