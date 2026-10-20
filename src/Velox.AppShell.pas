unit Velox.AppShell;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.AppShell
  Purpose:
    1-Line Windows 11 Fluent Desktop Application Shell (`TVeloxAppShell`)
    that scaffolds:
    1. Left navigation `SidebarPanel` + `BrandPanel` (Title + Accent Subtitle)
    2. Top `HeaderPanel` with active page title and `TVeloxSearchBox`
    3. Multi-page View Router (`AddPage` / `SwitchPage`) inside `ContentPanel`
    4. Bottom `FooterPanel` status bar (`SetStatusMessage`)
    5. Optional `TTrayIcon` system tray integration (`EnableTrayIcon`)
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
  Velox.Theme,
  Velox.Controls,
  Velox.StyledButton;

type
  TVeloxPageRoute = record
    PageId: string;
    Caption: string;
    NavButton: TVeloxStyledButton;
    PagePanel: TPanel;
  end;

  TVeloxPageSwitchEvent = procedure(const APageId: string; APagePanel: TPanel) of object;

  /// <summary>
  /// Turnkey Windows 11 Desktop Application Shell & Multi-Page View Router
  /// </summary>
  TVeloxAppShell = class(TComponent)
  private
    FForm: TForm;
    FSidebarPanel: TPanel;
    FBrandPanel: TPanel;
    FTitleLabel: TLabel;
    FSubtitleLabel: TLabel;
    FHeaderPanel: TPanel;
    FPageTitleLabel: TLabel;
    FSearchBox: TVeloxSearchBox;
    FContentPanel: TPanel;
    FFooterPanel: TPanel;
    FStatusLabel: TLabel;
    FTrayIcon: TTrayIcon;
    FColors: TVeloxThemeColors;
    FPages: array of TVeloxPageRoute;
    FActivePageId: string;
    FOnPageSwitch: TVeloxPageSwitchEvent;
    procedure NavButtonClick(Sender: TObject);
  public
    constructor CreateShell(AForm: TForm; const AAppTitle, AAppSubtitle: string;
      const AColors: TVeloxThemeColors; const ASidebarWidth: Integer = 210);
    destructor Destroy; override;

    /// <summary>
    /// Registers a navigation page into the sidebar and returns its client TPanel container
    /// </summary>
    function AddPage(const APageId, ACaption: string): TPanel;

    /// <summary>
    /// Switches the active view page by PageId
    /// </summary>
    function SwitchPage(const APageId: string): Boolean;

    /// <summary>
    /// Updates the footer status bar text and severity accent color
    /// </summary>
    procedure SetStatusMessage(const AText: string; const ASeverity: TVeloxSeverity = vsNormal);

    /// <summary>
    /// Re-applies Dark/Light theme colors across the entire shell and registered pages
    /// </summary>
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    /// <summary>
    /// Enables a system tray icon with tooltip hint
    /// </summary>
    procedure EnableTrayIcon(const AHint: string);

    function PageCount: Integer;
    property ActivePageId: string read FActivePageId;
    property SidebarPanel: TPanel read FSidebarPanel;
    property BrandPanel: TPanel read FBrandPanel;
    property HeaderPanel: TPanel read FHeaderPanel;
    property SearchBox: TVeloxSearchBox read FSearchBox;
    property ContentPanel: TPanel read FContentPanel;
    property FooterPanel: TPanel read FFooterPanel;
    property StatusLabel: TLabel read FStatusLabel;
    property TrayIcon: TTrayIcon read FTrayIcon;
    property OnPageSwitch: TVeloxPageSwitchEvent read FOnPageSwitch write FOnPageSwitch;
  end;

implementation

{ TVeloxAppShell }

constructor TVeloxAppShell.CreateShell(AForm: TForm;
  const AAppTitle, AAppSubtitle: string; const AColors: TVeloxThemeColors;
  const ASidebarWidth: Integer);
begin
  inherited Create(AForm);
  FForm := AForm;
  FColors := AColors;
  FActivePageId := '';

  // Left Navigation Sidebar
  FSidebarPanel := TPanel.Create(Self);
  FSidebarPanel.Parent := FForm;
  FSidebarPanel.Align := alLeft;
  FSidebarPanel.Width := ASidebarWidth;
  FSidebarPanel.BevelOuter := bvNone;
  FSidebarPanel.Color := AColors.SidebarBg;
  FSidebarPanel.Tag := 3;

  // Brand Header inside Sidebar
  FBrandPanel := TPanel.Create(Self);
  FBrandPanel.Parent := FSidebarPanel;
  FBrandPanel.Align := alTop;
  FBrandPanel.Height := 68;
  FBrandPanel.BevelOuter := bvNone;
  FBrandPanel.Color := AColors.SidebarBg;
  FBrandPanel.Tag := 3;

  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := FBrandPanel;
  FTitleLabel.Left := 18;
  FTitleLabel.Top := 14;
  FTitleLabel.Font.Name := 'Segoe UI';
  FTitleLabel.Font.Size := 13;
  FTitleLabel.Font.Style := [fsBold];
  FTitleLabel.Font.Color := AColors.SidebarText;
  FTitleLabel.Caption := AAppTitle;
  FTitleLabel.Tag := 3;

  FSubtitleLabel := TLabel.Create(Self);
  FSubtitleLabel.Parent := FBrandPanel;
  FSubtitleLabel.Left := 18;
  FSubtitleLabel.Top := 38;
  FSubtitleLabel.Font.Name := 'Segoe UI';
  FSubtitleLabel.Font.Size := 8;
  FSubtitleLabel.Font.Color := AColors.Accent;
  FSubtitleLabel.Caption := AAppSubtitle;
  FSubtitleLabel.Tag := 1;

  // Footer Status Bar
  FFooterPanel := TPanel.Create(Self);
  FFooterPanel.Parent := FForm;
  FFooterPanel.Align := alBottom;
  FFooterPanel.Height := 28;
  FFooterPanel.BevelOuter := bvNone;
  FFooterPanel.Color := AColors.Surface;
  FFooterPanel.Tag := 1;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FFooterPanel;
  FStatusLabel.Left := 14;
  FStatusLabel.Top := 6;
  FStatusLabel.Font.Name := 'Segoe UI';
  FStatusLabel.Font.Size := 8;
  FStatusLabel.Font.Color := AColors.TextSecondary;
  FStatusLabel.Caption := 'Ready';
  FStatusLabel.Tag := 2;

  // Top Header Bar
  FHeaderPanel := TPanel.Create(Self);
  FHeaderPanel.Parent := FForm;
  FHeaderPanel.Align := alTop;
  FHeaderPanel.Height := 52;
  FHeaderPanel.BevelOuter := bvNone;
  FHeaderPanel.Color := AColors.Surface;
  FHeaderPanel.Tag := 1;

  FPageTitleLabel := TLabel.Create(Self);
  FPageTitleLabel.Parent := FHeaderPanel;
  FPageTitleLabel.Left := 20;
  FPageTitleLabel.Top := 14;
  FPageTitleLabel.Font.Name := 'Segoe UI';
  FPageTitleLabel.Font.Size := 13;
  FPageTitleLabel.Font.Style := [fsBold];
  FPageTitleLabel.Font.Color := AColors.TextPrimary;
  FPageTitleLabel.Caption := AAppTitle;

  FSearchBox := TVeloxSearchBox.CreateBox(
    Self, FHeaderPanel,
    FHeaderPanel.Width - 256, 12, 240, 28,
    'Search...', AColors);
  FSearchBox.Container.Anchors := [akTop, akRight];

  // Main Content Area
  FContentPanel := TPanel.Create(Self);
  FContentPanel.Parent := FForm;
  FContentPanel.Align := alClient;
  FContentPanel.BevelOuter := bvNone;
  FContentPanel.Color := AColors.Background;
end;

destructor TVeloxAppShell.Destroy;
begin
  SetLength(FPages, 0);
  inherited Destroy;
end;

procedure TVeloxAppShell.NavButtonClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to High(FPages) do
    if FPages[I].NavButton = Sender then
    begin
      SwitchPage(FPages[I].PageId);
      Exit;
    end;
end;

function TVeloxAppShell.AddPage(const APageId, ACaption: string): TPanel;
var
  Idx: Integer;
  Btn: TVeloxStyledButton;
  Pnl: TPanel;
begin
  Idx := Length(FPages);
  SetLength(FPages, Idx + 1);

  Btn := TVeloxStyledButton.CreateButton(
    Self, FSidebarPanel,
    12, 76 + Idx * 40, FSidebarPanel.Width - 24, 34,
    ACaption, FColors, vsbOutline, NavButtonClick);
  Btn.Anchors := [akLeft, akTop, akRight];
  Btn.Radius := 6;

  Pnl := TPanel.Create(Self);
  Pnl.Parent := FContentPanel;
  Pnl.Align := alClient;
  Pnl.BevelOuter := bvNone;
  Pnl.Color := FColors.Background;
  Pnl.Visible := False;

  FPages[Idx].PageId := APageId;
  FPages[Idx].Caption := ACaption;
  FPages[Idx].NavButton := Btn;
  FPages[Idx].PagePanel := Pnl;

  Result := Pnl;

  if Idx = 0 then
    SwitchPage(APageId);
end;

function TVeloxAppShell.SwitchPage(const APageId: string): Boolean;
var
  I: Integer;
  ActivePnl: TPanel;
begin
  Result := False;
  ActivePnl := nil;

  for I := 0 to High(FPages) do
  begin
    if SameText(FPages[I].PageId, APageId) then
    begin
      FPages[I].PagePanel.Visible := True;
      FPages[I].PagePanel.BringToFront;
      FPages[I].NavButton.Active := True;
      FActivePageId := FPages[I].PageId;
      FPageTitleLabel.Caption := FPages[I].Caption;
      ActivePnl := FPages[I].PagePanel;
      Result := True;
    end
    else
    begin
      FPages[I].PagePanel.Visible := False;
      FPages[I].NavButton.Active := False;
    end;
  end;

  if Result and Assigned(FOnPageSwitch) then
    FOnPageSwitch(FActivePageId, ActivePnl);
end;

procedure TVeloxAppShell.SetStatusMessage(const AText: string; const ASeverity: TVeloxSeverity);
begin
  FStatusLabel.Caption := AText;
  FStatusLabel.Font.Color := TVeloxUtils.SeverityToColor(ASeverity, FColors);
end;

procedure TVeloxAppShell.ApplyColors(const AColors: TVeloxThemeColors);
var
  I: Integer;
begin
  FColors := AColors;
  FSidebarPanel.Color := AColors.SidebarBg;
  FBrandPanel.Color := AColors.SidebarBg;
  FTitleLabel.Font.Color := AColors.SidebarText;
  FSubtitleLabel.Font.Color := AColors.Accent;
  FHeaderPanel.Color := AColors.Surface;
  FPageTitleLabel.Font.Color := AColors.TextPrimary;
  FSearchBox.ApplyColors(AColors);
  FContentPanel.Color := AColors.Background;
  FFooterPanel.Color := AColors.Surface;
  FStatusLabel.Font.Color := AColors.TextSecondary;

  for I := 0 to High(FPages) do
  begin
    FPages[I].NavButton.ApplyColors(AColors);
    FPages[I].PagePanel.Color := AColors.Background;
  end;
end;

procedure TVeloxAppShell.EnableTrayIcon(const AHint: string);
begin
  if not Assigned(FTrayIcon) then
    FTrayIcon := TTrayIcon.Create(Self);
  FTrayIcon.Hint := AHint;
  FTrayIcon.Visible := True;
end;

function TVeloxAppShell.PageCount: Integer;
begin
  Result := Length(FPages);
end;

end.
