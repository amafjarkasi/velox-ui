unit Velox.UpdateFlyout;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.UpdateFlyout (#73)
  Purpose:
    Composite WinUI 3 Fluent Self-Updater Flyout combining:
      - TVeloxUpdater (GitHub release SemVer parsing & batch swap script)
      - TVeloxGlassPanel (Translucent acrylic card with specular highlight)
      - TVeloxProgressRing (Smooth indeterminate hardware spinner)
      - TVeloxStyledButton (Primary Install & Ghost Dismiss buttons)
==============================================================================}

interface

uses
  Windows,
  Types,
  SysUtils,
  Classes,
  Controls,
  Graphics,
  Forms,
  ExtCtrls,
  Velox.Types,
  Velox.GdiPlus,
  Velox.Glass,
  Velox.Feedback,
  Velox.StyledButton,
  Velox.Updater;

type
  TVeloxUpdateFlyout = class(TCustomControl)
  private
    FGlass: TVeloxGlassPanel;
    FSpinner: TVeloxProgressRing;
    FBtnInstall: TVeloxStyledButton;
    FBtnDismiss: TVeloxStyledButton;
    FColors: TVeloxThemeColors;
    FReleaseTag: string;
    FReleaseNotes: string;
    FAssetUrl: string;
    FIsDownloading: Boolean;
    FOnInstall: TNotifyEvent;
    FOnDismiss: TNotifyEvent;
    procedure HandleInstallClick(Sender: TObject);
    procedure HandleDismissClick(Sender: TObject);
    procedure GlassPaint(Sender: TObject);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure SetRelease(const ATag, ANotes, AAssetUrl: string);
    procedure StartDownloadProgress;
    procedure StopDownloadProgress;

    property ReleaseTag: string read FReleaseTag;
    property ReleaseNotes: string read FReleaseNotes;
    property AssetUrl: string read FAssetUrl;
    property IsDownloading: Boolean read FIsDownloading;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
    property OnInstall: TNotifyEvent read FOnInstall write FOnInstall;
    property OnDismiss: TNotifyEvent read FOnDismiss write FOnDismiss;
  end;

implementation

constructor TVeloxUpdateFlyout.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 420;
  Height := 180;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FReleaseTag := 'v1.0.0';
  FReleaseNotes := 'Performance improvements and bug fixes.';
  FAssetUrl := '';
  FIsDownloading := False;

  // 1. Acrylic Translucent Glass Container
  FGlass := TVeloxGlassPanel.Create(Self);
  FGlass.Parent := Self;
  FGlass.Align := alClient;
  FGlass.CornerRadius := 10;
  FGlass.Title := '';
  FGlass.OnPaint := GlassPaint;

  // 2. Indeterminate Progress Ring (Hidden initially)
  FSpinner := TVeloxProgressRing.CreateRing(Self, FGlass, Width - 54, 16, 28, FColors);
  FSpinner.Visible := False;

  // 3. Action Buttons
  FBtnDismiss := TVeloxStyledButton.Create(Self);
  FBtnDismiss.Parent := FGlass;
  FBtnDismiss.Caption := 'Later';
  FBtnDismiss.Variant := vsbSurface;
  FBtnDismiss.SetBounds(Width - 190, Height - 44, 80, 30);
  FBtnDismiss.OnClick := HandleDismissClick;

  FBtnInstall := TVeloxStyledButton.Create(Self);
  FBtnInstall.Parent := FGlass;
  FBtnInstall.Caption := 'Install & Restart';
  FBtnInstall.Variant := vsbPrimary;
  FBtnInstall.SetBounds(Width - 104, Height - 44, 94, 30);
  FBtnInstall.OnClick := HandleInstallClick;

  ApplyColors(FColors);
end;

procedure TVeloxUpdateFlyout.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  if Assigned(FGlass) then FGlass.ApplyColors(FColors);
  if Assigned(FSpinner) then FSpinner.ApplyColors(FColors);
  if Assigned(FBtnInstall) then FBtnInstall.ApplyColors(FColors);
  if Assigned(FBtnDismiss) then FBtnDismiss.ApplyColors(FColors);
  Invalidate;
end;

procedure TVeloxUpdateFlyout.SetRelease(const ATag, ANotes, AAssetUrl: string);
begin
  FReleaseTag := ATag;
  FReleaseNotes := ANotes;
  FAssetUrl := AAssetUrl;
  FGlass.Invalidate;
end;

procedure TVeloxUpdateFlyout.StartDownloadProgress;
begin
  FIsDownloading := True;
  FSpinner.Visible := True;
  FSpinner.Running := True;
  FBtnInstall.Enabled := False;
end;

procedure TVeloxUpdateFlyout.StopDownloadProgress;
begin
  FIsDownloading := False;
  FSpinner.Running := False;
  FSpinner.Visible := False;
  FBtnInstall.Enabled := True;
end;

procedure TVeloxUpdateFlyout.HandleInstallClick(Sender: TObject);
begin
  StartDownloadProgress;
  if Assigned(FOnInstall) then
    FOnInstall(Self);
end;

procedure TVeloxUpdateFlyout.HandleDismissClick(Sender: TObject);
begin
  Visible := False;
  if Assigned(FOnDismiss) then
    FOnDismiss(Self);
end;

procedure TVeloxUpdateFlyout.GlassPaint(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
  HeaderStr, DownloadStr: string;
begin
  C := FGlass.Canvas;
  C.Brush.Style := bsClear;

  // Title: "Update Available: v2.5.0"
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 11;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  HeaderStr := 'Update Available: ' + FReleaseTag;
  R := Rect(18, 16, Width - 60, 42);
  DrawText(C.Handle, PChar(HeaderStr), -1, R, DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  // Subtitle / Notes preview
  C.Font.Size := 9;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  R := Rect(18, 48, Width - 18, Height - 52);
  DrawText(C.Handle, PChar(FReleaseNotes), -1, R, DT_WORDBREAK or DT_NOPREFIX);

  // Status indicator
  if FIsDownloading then
  begin
    C.Font.Size := 8;
    C.Font.Style := [fsBold];
    C.Font.Color := FColors.Accent;
    DownloadStr := 'Downloading update package...';
    R := Rect(18, Height - 40, 160, Height - 14);
    DrawText(C.Handle, PChar(DownloadStr), -1, R, DT_SINGLELINE or DT_VCENTER or DT_LEFT);
  end;
end;

procedure TVeloxUpdateFlyout.Paint;
begin
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);
end;

procedure TVeloxUpdateFlyout.Resize;
begin
  inherited Resize;
  if Assigned(FBtnInstall) and Assigned(FBtnDismiss) and Assigned(FSpinner) then
  begin
    FBtnInstall.Left := Width - FBtnInstall.Width - 14;
    FBtnInstall.Top := Height - FBtnInstall.Height - 14;
    FBtnDismiss.Left := FBtnInstall.Left - FBtnDismiss.Width - 8;
    FBtnDismiss.Top := FBtnInstall.Top;
    FSpinner.Left := Width - FSpinner.Width - 16;
  end;
end;

end.
