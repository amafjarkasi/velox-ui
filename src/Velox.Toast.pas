unit Velox.Toast;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Toast
  Purpose:
    Non-blocking floating GDI+ in-app Toast Notification Banner (`TVeloxToast`)
    that anchors to the bottom-right of any parent TWinControl/TForm, displays
    a severity-colored accent pill + message, and auto-dismisses after a
    configurable duration without blocking the UI thread.
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
  /// Non-blocking floating toast notification component
  /// </summary>
  TVeloxToast = class(TComponent)
  private
    FPanel: TPanel;
    FPaintBox: TPaintBox;
    FTimer: TTimer;
    FTitle: string;
    FMessage: string;
    FSeverity: TVeloxSeverity;
    FColors: TVeloxThemeColors;
    procedure OnPaintToast(Sender: TObject);
    procedure OnToastClick(Sender: TObject);
    procedure OnTimerExpired(Sender: TObject);
    function GetIsVisible: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    /// Displays or updates the floating toast banner inside AParent and
    /// schedules auto-dismiss after ADurationMs (default 3500ms).
    /// </summary>
    procedure ShowToast(AParent: TWinControl; const ATitle, AMessage: string;
      const ASeverity: TVeloxSeverity; const AColors: TVeloxThemeColors;
      const ADurationMs: Cardinal = 3500);
    procedure Dismiss;

    property IsVisible: Boolean read GetIsVisible;
    property Title: string read FTitle;
    property MessageText: string read FMessage;
    property Severity: TVeloxSeverity read FSeverity;
  end;

implementation

{ TVeloxToast }

constructor TVeloxToast.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPanel := TPanel.Create(Self);
  FPanel.BevelOuter := bvNone;
  FPanel.DoubleBuffered := True;
  FPanel.Visible := False;
  FPanel.Width := 340;
  FPanel.Height := 58;

  FPaintBox := TPaintBox.Create(Self);
  FPaintBox.Parent := FPanel;
  FPaintBox.Align := alClient;
  FPaintBox.Cursor := crHandPoint;
  FPaintBox.OnPaint := OnPaintToast;
  FPaintBox.OnClick := OnToastClick;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.OnTimer := OnTimerExpired;
end;

destructor TVeloxToast.Destroy;
begin
  FTimer.Enabled := False;
  inherited Destroy;
end;

function TVeloxToast.GetIsVisible: Boolean;
begin
  Result := Assigned(FPanel) and FPanel.Visible;
end;

procedure TVeloxToast.ShowToast(AParent: TWinControl; const ATitle, AMessage: string;
  const ASeverity: TVeloxSeverity; const AColors: TVeloxThemeColors;
  const ADurationMs: Cardinal);
const
  ToastW = 340;
  ToastH = 58;
  Margin = 16;
begin
  if AParent = nil then Exit;
  FTitle := ATitle;
  FMessage := AMessage;
  FSeverity := ASeverity;
  FColors := AColors;

  FPanel.Parent := AParent;
  FPanel.Color := AColors.SurfaceCard;
  FPanel.SetBounds(
    AParent.ClientWidth - ToastW - Margin,
    AParent.ClientHeight - ToastH - Margin,
    ToastW,
    ToastH
  );
  FPanel.Anchors := [akRight, akBottom];
  FPanel.Visible := True;
  FPanel.BringToFront;
  FPaintBox.Invalidate;

  FTimer.Enabled := False;
  if ADurationMs > 0 then
  begin
    FTimer.Interval := ADurationMs;
    FTimer.Enabled := True;
  end;
end;

procedure TVeloxToast.Dismiss;
begin
  FTimer.Enabled := False;
  if Assigned(FPanel) then
    FPanel.Visible := False;
end;

procedure TVeloxToast.OnToastClick(Sender: TObject);
begin
  Dismiss;
end;

procedure TVeloxToast.OnTimerExpired(Sender: TObject);
begin
  Dismiss;
end;

procedure TVeloxToast.OnPaintToast(Sender: TObject);
var
  C: TCanvas;
  R, StripR: TRect;
  AccentCol: TColor;
begin
  C := FPaintBox.Canvas;
  R := Rect(0, 0, FPaintBox.Width, FPaintBox.Height);
  AccentCol := TVeloxUtils.SeverityToColor(FSeverity, FColors);

  TVeloxGdiPlus.DrawCard(C, R, FColors.SurfaceCard, AccentCol, 8);

  // Left vertical severity indicator pill
  StripR := Rect(R.Left + 8, R.Top + 10, R.Left + 13, R.Bottom - 10);
  TVeloxGdiPlus.DrawCard(C, StripR, AccentCol, AccentCol, 2);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';

  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  C.TextOut(R.Left + 22, R.Top + 10, FTitle);

  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  C.TextOut(R.Left + 22, R.Top + 30, FMessage);
end;

end.
