program MasterStudio;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — Master Showcase Studio
  Demonstrates all 10 Flagship Features & Components in a Single Application:
    1. Windows 11 Fluent Dark Mode, Mica / Acrylic & Dynamic Palette Switcher
    2. Turnkey 1-Line Desktop AppShell (Collapsible Sidebar, Router, Status Bar)
    3. Anti-Aliased GDI+ Vector Suite (KPI Cards, Donut Gauges, Sparklines, Glow)
    4. High-Frequency VirtualGrid with Inline SparkGrid micro-cells
    5. Raycast / VS Code Fuzzy Command Palette (Ctrl+K)
    6. Live Transactional Property Inspector Studio (Undo/Redo & Apply/Discard)
    7. Interactive RFC-8259 JSON Document & Hierarchy Tree Explorer
    8. Side-by-Side & Unified Diff Visualizer with Line Statistics
    9. Windows 11 Win+V Clipboard Manager & History Palette
   10. Zero-Dependency Native Security Core (CNG SHA-256 & Audit Timeline)
==============================================================================}

uses
  {$IFDEF FPC}
  Interfaces,
  {$ENDIF}
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  Controls,
  Forms,
  StdCtrls,
  ExtCtrls,
  ComCtrls,
  Generics.Collections,
  Velox.Types,
  Velox.Theme,
  Velox.GdiPlus,
  Velox.Controls,
  Velox.StyledButton,
  Velox.AppShell,
  Velox.Charts,
  Velox.SparkGrid,
  Velox.VirtualGrid,
  Velox.CommandPalette,
  Velox.InspectorStudio,
  Velox.JsonTreeViewer,
  Velox.DiffInspector,
  Velox.ClipboardPalette,
  Velox.AuditSecurityLog,
  Velox.ToggleSwitch,
  Velox.Icons,
  Velox.Layout,
  Velox.System,
  Velox.Memory;

type
  TTelemetryRow = record
    Pid: Cardinal;
    Name: string;
    CpuPercent: Single;
    MemoryMB: Single;
    State: TVeloxSeverity;
    History: TSingleDynArray;
  end;

  TStudioMainForm = class(TForm)
  private
    FColors: TVeloxThemeColors;
    FCurrentTheme: TVeloxCustomTheme;
    FShell: TVeloxAppShell;
    FPalette: TVeloxCommandPalette;
    FTimer: TTimer;

    // Telemetry Dashboard controls
    FChartBox: TPaintBox;
    FListView: TListView;
    FGrid: TVeloxVirtualGrid<TTelemetryRow>;
    FRows: TList<TTelemetryRow>;
    FCpuRing: TVeloxRingBuffer;
    FRamRing: TVeloxRingBuffer;

    // Composite Flagship Studios
    FInspector: TVeloxInspectorStudio;
    FJsonViewer: TVeloxJsonTreeViewer;
    FDiffInspector: TVeloxDiffInspector;
    FClipboard: TVeloxClipboardPalette;
    FAuditLog: TVeloxAuditSecurityLog;

    // Design Sandbox & Icons controls
    FSandboxStack: TVeloxStackPanel;
    FToggle60Fps: TVeloxToggleSwitch;
    FToggleStatusLabel: TLabel;
    FIconPaintBox: TPaintBox;

    procedure SetupPages;
    procedure SetupCommandPalette;
    procedure SetupTelemetryPage(APanel: TPanel);
    procedure SetupInspectorPage(APanel: TPanel);
    procedure SetupJsonPage(APanel: TPanel);
    procedure SetupDiffPage(APanel: TPanel);
    procedure SetupClipboardPage(APanel: TPanel);
    procedure SetupSecurityPage(APanel: TPanel);
    procedure SetupSandboxPage(APanel: TPanel);

    procedure OnTimerTick(Sender: TObject);
    procedure OnChartBoxPaint(Sender: TObject);
    procedure OnIconPaintBoxPaint(Sender: TObject);
    procedure OnToggle60FpsClick(Sender: TObject);
    procedure OnListViewData(Sender: TObject; Item: TListItem);
    procedure OnCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure OnCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; var DefaultDraw: Boolean);
    function CompareRows(const A, B: TTelemetryRow; const ACol: Integer): Integer;

    procedure SwitchToTheme(const ATheme: TVeloxCustomTheme);
    procedure HandleSearchClick(Sender: TObject);
    procedure TrimWorkingSetAction;

    // Button event handlers
    procedure HandleBtnDarkClick(Sender: TObject);
    procedure HandleBtnLightClick(Sender: TObject);
    procedure HandleBtnMidClick(Sender: TObject);
    procedure HandleBtnNordClick(Sender: TObject);
    procedure HandleBtnTrimClick(Sender: TObject);
    procedure HandleBtnStackHorz(Sender: TObject);
    procedure HandleBtnStackVert(Sender: TObject);
    procedure HandleBtnStackWrap(Sender: TObject);
    procedure HandleBtnStackGap(Sender: TObject);

    // Command Palette callbacks
    procedure CmdNavDash;
    procedure CmdNavInsp;
    procedure CmdNavJson;
    procedure CmdNavDiff;
    procedure CmdNavClip;
    procedure CmdNavSec;
    procedure CmdNavSandbox;
    procedure CmdThemeDark;
    procedure CmdThemeLight;
    procedure CmdThemeMid;
    procedure CmdThemeNord;
    procedure CmdThemeHc;
    procedure CmdTrimRam;
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor CreateStudio(AOwner: TComponent);
    destructor Destroy; override;
  end;

{ TStudioMainForm }

constructor TStudioMainForm.CreateStudio(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'VeloxUI Master Showcase Studio — 10 Flagship Features';
  SetBounds(80, 60, 1180, 740);
  Position := poScreenCenter;
  KeyPreview := True;

  FCurrentTheme := vctDark;
  FColors := TVeloxUtils.GetCustomThemeColors(FCurrentTheme);

  FCpuRing.Clear(30);
  FRamRing.Clear(30);
  FRows := TList<TTelemetryRow>.Create;

  // 1. Desktop Shell (#2)
  FShell := TVeloxAppShell.CreateShell(Self, 'VeloxUI Studio', 'v1.0 · 75 Zero-Dep Units', FColors, 220);
  FShell.SearchBox.Text := 'Search studio (Ctrl+K)...';
  FShell.SearchBox.Edit.ReadOnly := True;
  FShell.SearchBox.Edit.OnClick := HandleSearchClick;
  FShell.SearchBox.Container.OnClick := HandleSearchClick;

  SetupPages;
  SetupCommandPalette;

  // Apply Win11 Titlebar Dark Mode & Mica (#1)
  TVeloxThemeEngine.ApplyFormTheme(Self, vtDark);
  TVeloxThemeEngine.ApplySystemBackdrop(Handle, vbtMica);

  // Live Timer for Charts & Telemetry (#3 & #4)
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 1000;
  FTimer.OnTimer := OnTimerTick;
  FTimer.Enabled := True;
  OnTimerTick(nil);
end;

destructor TStudioMainForm.Destroy;
begin
  FTimer.Free;
  FGrid.Free;
  FRows.Free;
  inherited Destroy;
end;

procedure TStudioMainForm.SetupPages;
var
  PnlDash, PnlInsp, PnlJson, PnlDiff, PnlClip, PnlSec, PnlBox: TPanel;
begin
  PnlDash := FShell.AddPage('dashboard', 'Telemetry & Charts');
  PnlInsp := FShell.AddPage('inspector', 'Property Studio');
  PnlJson := FShell.AddPage('jsontree', 'JSON Explorer');
  PnlDiff := FShell.AddPage('diff', 'Diff Inspector');
  PnlClip := FShell.AddPage('clipboard', 'Clipboard (Win+V)');
  PnlSec  := FShell.AddPage('security', 'Security Audit');
  PnlBox  := FShell.AddPage('sandbox', 'Design Sandbox & Icons');

  SetupTelemetryPage(PnlDash);
  SetupInspectorPage(PnlInsp);
  SetupJsonPage(PnlJson);
  SetupDiffPage(PnlDiff);
  SetupClipboardPage(PnlClip);
  SetupSecurityPage(PnlSec);
  SetupSandboxPage(PnlBox);

  FShell.SwitchPage('dashboard');
  FShell.SetStatusMessage('Studio Ready. Press Ctrl+K for Fuzzy Command Palette.', vsNormal);
end;

procedure TStudioMainForm.SetupTelemetryPage(APanel: TPanel);
var
  TopBar: TPanel;
  BtnDark, BtnLight, BtnMid, BtnNord, BtnTrim: TVeloxStyledButton;
begin
  // Top Quick-Action Bar
  TopBar := TPanel.Create(Self);
  TopBar.Parent := APanel;
  TopBar.Align := alTop;
  TopBar.Height := 42;
  TopBar.BevelOuter := bvNone;
  TopBar.Color := FColors.Surface;

  BtnDark := TVeloxStyledButton.Create(Self);
  BtnDark.Parent := TopBar;
  BtnDark.Caption := 'Dark';
  BtnDark.Variant := vsbSurface;
  BtnDark.SetBounds(12, 7, 60, 28);
  BtnDark.OnClick := HandleBtnDarkClick;

  BtnLight := TVeloxStyledButton.Create(Self);
  BtnLight.Parent := TopBar;
  BtnLight.Caption := 'Light';
  BtnLight.Variant := vsbSurface;
  BtnLight.SetBounds(78, 7, 60, 28);
  BtnLight.OnClick := HandleBtnLightClick;

  BtnMid := TVeloxStyledButton.Create(Self);
  BtnMid.Parent := TopBar;
  BtnMid.Caption := 'Midnight';
  BtnMid.Variant := vsbSurface;
  BtnMid.SetBounds(144, 7, 72, 28);
  BtnMid.OnClick := HandleBtnMidClick;

  BtnNord := TVeloxStyledButton.Create(Self);
  BtnNord.Parent := TopBar;
  BtnNord.Caption := 'Nord';
  BtnNord.Variant := vsbSurface;
  BtnNord.SetBounds(222, 7, 60, 28);
  BtnNord.OnClick := HandleBtnNordClick;

  BtnTrim := TVeloxStyledButton.Create(Self);
  BtnTrim.Parent := TopBar;
  BtnTrim.Caption := 'Trim RAM';
  BtnTrim.Variant := vsbPrimary;
  BtnTrim.SetBounds(290, 7, 84, 28);
  BtnTrim.OnClick := HandleBtnTrimClick;

  // GDI+ Donut Gauges & Dual Sparkline Card (#3)
  FChartBox := TPaintBox.Create(Self);
  FChartBox.Parent := APanel;
  FChartBox.Align := alTop;
  FChartBox.Height := 170;
  FChartBox.OnPaint := OnChartBoxPaint;

  // High-Frequency VirtualGrid & SparkGrid (#4)
  FListView := TListView.Create(Self);
  FListView.Parent := APanel;
  FListView.Align := alClient;
  FListView.ViewStyle := vsReport;
  FListView.ReadOnly := True;
  FListView.RowSelect := True;
  FListView.OwnerData := True;
  FListView.DoubleBuffered := True;
  FListView.Color := FColors.Background;
  FListView.Font.Color := FColors.TextPrimary;
  FListView.Font.Name := 'Segoe UI';
  FListView.Font.Size := 9;
  FListView.OnData := OnListViewData;
  FListView.OnCustomDrawItem := OnCustomDrawItem;
  FListView.OnCustomDrawSubItem := OnCustomDrawSubItem;

  FGrid := TVeloxVirtualGrid<TTelemetryRow>.Create(FListView);
  FGrid.AddColumn('PID', 70, taLeftJustify, False);
  FGrid.AddColumn('Process Name', 210, taLeftJustify, False);
  FGrid.AddColumn('CPU Usage (%)', 160, taRightJustify, True);
  FGrid.AddColumn('Memory Working Set', 160, taRightJustify, True);
  FGrid.AddColumn('Health Status', 140, taLeftJustify, False);
  FGrid.AddColumn('Sparkline Telemetry', 180, taCenter, False);
end;

procedure TStudioMainForm.SetupInspectorPage(APanel: TPanel);
begin
  FInspector := TVeloxInspectorStudio.Create(Self);
  FInspector.Parent := APanel;
  FInspector.Align := alClient;
  FInspector.ApplyColors(FColors);

  // Seed sample enterprise properties
  FInspector.AddString('Application', 'AppName', 'VeloxUI Master Studio');
  FInspector.AddString('Application', 'Version', '1.0.0');
  FInspector.AddBoolean('UI Engine', 'HardwareAcceleration', True);
  FInspector.AddBoolean('UI Engine', 'FluentAcrylic', True);
  FInspector.AddInteger('Telemetry', 'RefreshRateMs', 1000);
  FInspector.AddInteger('Telemetry', 'RingCapacity', 60);
  FInspector.AddColor('Theming', 'AccentColor', FColors.Accent);
  FInspector.AddBoolean('Security', 'AuditHashChecking', True);
end;

procedure TStudioMainForm.SetupJsonPage(APanel: TPanel);
const
  SAMPLE_JSON =
    '{\n' +
    '  "framework": "VeloxUI",\n' +
    '  "version": 1.0,\n' +
    '  "zeroDependency": true,\n' +
    '  "metrics": {\n' +
    '    "modules": 73,\n' +
    '    "testAssertions": 286,\n' +
    '    "passRate": 100.0\n' +
    '  },\n' +
    '  "features": ["Fluent Dark Mode", "Virtual Grid", "GDI+ Antialiasing", "JSON DOM", "CNG Crypto"],\n' +
    '  "compiler": {\n' +
    '    "fpc": "3.2.2",\n' +
    '    "delphi": "11/12",\n' +
    '    "platforms": ["Win64", "Win32"]\n' +
    '  }\n' +
    '}';
begin
  FJsonViewer := TVeloxJsonTreeViewer.Create(Self);
  FJsonViewer.Parent := APanel;
  FJsonViewer.Align := alClient;
  FJsonViewer.ApplyColors(FColors);
  FJsonViewer.LoadJson(SAMPLE_JSON);
end;

procedure TStudioMainForm.SetupDiffPage(APanel: TPanel);
const
  OLD_CODE =
    'procedure TLegacyForm.UpdateView;\n' +
    'begin\n' +
    '  // Slow manual Win32 repainting\n' +
    '  ListView1.Items.Clear;\n' +
    '  PopulateItems;\n' +
    '  Sleep(100);\n' +
    'end;\n';
  NEW_CODE =
    'procedure TVeloxForm.UpdateView;\n' +
    'begin\n' +
    '  // Zero-allocation high-frequency VirtualGrid\n' +
    '  FGrid.RefreshCount(FRows.Count);\n' +
    '  FPoller.NotifyChanges;\n' +
    '  TVeloxGdiPlus.DrawGlowBorder(Canvas, ClientRect, FColors.Accent);\n' +
    'end;\n';
begin
  FDiffInspector := TVeloxDiffInspector.Create(Self);
  FDiffInspector.Parent := APanel;
  FDiffInspector.Align := alClient;
  FDiffInspector.ApplyColors(FColors);
  FDiffInspector.CompareTexts(OLD_CODE, NEW_CODE, 'Legacy VCL vs VeloxUI High-Velocity Architecture');
end;

procedure TStudioMainForm.SetupClipboardPage(APanel: TPanel);
begin
  FClipboard := TVeloxClipboardPalette.Create(Self);
  FClipboard.Parent := APanel;
  FClipboard.Align := alClient;
  FClipboard.ApplyColors(FColors);

  // Add initial clips
  FClipboard.AddClip('git clone https://github.com/amafjarkasi/velox-ui.git', True);
  FClipboard.AddClip('lazbuild -B tests/veloxtest.lpi', True);
  FClipboard.AddClip('TVeloxAppShell.CreateShell(Self, "AppTitle", "Subtitle", Colors);', False);
  FClipboard.AddClip('TVeloxGdiPlus.DrawGlowBorder(Canvas, Rect, AccentColor, 8);', False);
end;

procedure TStudioMainForm.SetupSecurityPage(APanel: TPanel);
begin
  FAuditLog := TVeloxAuditSecurityLog.Create(Self);
  FAuditLog.Parent := APanel;
  FAuditLog.Align := alClient;
  FAuditLog.ApplyColors(FColors);

  FAuditLog.LogEvent('System Startup', 'VeloxUI Windows 11 Engine initialized', vsNormal);
  FAuditLog.LogEvent('CNG Crypto Engine', 'BCrypt SHA-256 hardware acceleration verified', vsNormal);
  FAuditLog.LogEvent('Memory Working Set', 'Process trimmed and cached pages freed', vsNormal);
  FAuditLog.LogEvent('Audit Alert', 'Non-blocking directory integrity monitoring active', vsWarning);
end;

procedure TStudioMainForm.SetupSandboxPage(APanel: TPanel);
var
  HeaderCard, StackControlsCard, IconGalleryCard: TPanel;
  TitleLbl, SubtitleLbl, StackLbl, GalleryLbl: TLabel;
  BtnHorz, BtnVert, BtnWrap, BtnGap: TVeloxStyledButton;
  BtnItem1, BtnItem2, BtnItem3, BtnItem4: TVeloxStyledButton;
begin
  APanel.Color := FColors.Background;

  // 1. Header Card
  HeaderCard := TPanel.Create(Self);
  HeaderCard.Parent := APanel;
  HeaderCard.Align := alTop;
  HeaderCard.Height := 58;
  HeaderCard.BevelOuter := bvNone;
  HeaderCard.Color := FColors.Surface;

  TitleLbl := TLabel.Create(Self);
  TitleLbl.Parent := HeaderCard;
  TitleLbl.Left := 16;
  TitleLbl.Top := 8;
  TitleLbl.Font.Name := 'Segoe UI';
  TitleLbl.Font.Size := 12;
  TitleLbl.Font.Style := [fsBold];
  TitleLbl.Font.Color := FColors.TextPrimary;
  TitleLbl.Caption := 'Design System Sandbox & Vector Icon Engine';

  SubtitleLbl := TLabel.Create(Self);
  SubtitleLbl.Parent := HeaderCard;
  SubtitleLbl.Left := 16;
  SubtitleLbl.Top := 32;
  SubtitleLbl.Font.Name := 'Segoe UI';
  SubtitleLbl.Font.Size := 9;
  SubtitleLbl.Font.Color := FColors.TextSecondary;
  SubtitleLbl.Caption := 'Scalable resolution-independent GDI+ Fluent vector glyphs, responsive TVeloxStackPanel, and 60 FPS micro-animations';

  // 2. Interactive Stack & Micro-Animation Demo Card
  StackControlsCard := TPanel.Create(Self);
  StackControlsCard.Parent := APanel;
  StackControlsCard.Align := alTop;
  StackControlsCard.Height := 170;
  StackControlsCard.BevelOuter := bvNone;
  StackControlsCard.Color := FColors.Surface;

  StackLbl := TLabel.Create(Self);
  StackLbl.Parent := StackControlsCard;
  StackLbl.Left := 16;
  StackLbl.Top := 10;
  StackLbl.Font.Name := 'Segoe UI';
  StackLbl.Font.Size := 10;
  StackLbl.Font.Style := [fsBold];
  StackLbl.Font.Color := FColors.Accent;
  StackLbl.Caption := 'Responsive TVeloxStackPanel (Auto-Wrap, Gap Spacing & Cross-Alignment)';

  BtnHorz := TVeloxStyledButton.Create(Self);
  BtnHorz.Parent := StackControlsCard;
  BtnHorz.SetBounds(16, 32, 90, 26);
  BtnHorz.Caption := 'Horizontal';
  BtnHorz.Variant := vsbOutline;
  BtnHorz.OnClick := HandleBtnStackHorz;

  BtnVert := TVeloxStyledButton.Create(Self);
  BtnVert.Parent := StackControlsCard;
  BtnVert.SetBounds(112, 32, 80, 26);
  BtnVert.Caption := 'Vertical';
  BtnVert.Variant := vsbOutline;
  BtnVert.OnClick := HandleBtnStackVert;

  BtnWrap := TVeloxStyledButton.Create(Self);
  BtnWrap.Parent := StackControlsCard;
  BtnWrap.SetBounds(198, 32, 90, 26);
  BtnWrap.Caption := 'Toggle Wrap';
  BtnWrap.Variant := vsbOutline;
  BtnWrap.OnClick := HandleBtnStackWrap;

  BtnGap := TVeloxStyledButton.Create(Self);
  BtnGap.Parent := StackControlsCard;
  BtnGap.SetBounds(294, 32, 80, 26);
  BtnGap.Caption := 'Cycle Gap';
  BtnGap.Variant := vsbOutline;
  BtnGap.OnClick := HandleBtnStackGap;

  // 60 FPS Micro-Animation Toggle
  FToggle60Fps := TVeloxToggleSwitch.CreateSwitch(Self, StackControlsCard, 390, 32, 175, 'Hardware 60 FPS', FColors, True, OnToggle60FpsClick);

  FToggleStatusLabel := TLabel.Create(Self);
  FToggleStatusLabel.Parent := StackControlsCard;
  FToggleStatusLabel.Left := 580;
  FToggleStatusLabel.Top := 37;
  FToggleStatusLabel.Font.Name := 'Segoe UI';
  FToggleStatusLabel.Font.Size := 9;
  FToggleStatusLabel.Font.Color := FColors.Success;
  FToggleStatusLabel.Caption := 'Interpolated Smooth Sliding Active';

  // Live StackPanel host
  FSandboxStack := TVeloxStackPanel.CreateHorizontal(Self, StackControlsCard, 8, 8);
  FSandboxStack.SetBounds(16, 68, 700, 90);
  FSandboxStack.ApplyColors(FColors);

  BtnItem1 := TVeloxStyledButton.Create(Self);
  BtnItem1.SetBounds(0, 0, 110, 30);
  BtnItem1.Caption := 'viShield Secure';
  BtnItem1.Variant := vsbPrimary;
  FSandboxStack.Add(BtnItem1);

  BtnItem2 := TVeloxStyledButton.Create(Self);
  BtnItem2.SetBounds(0, 0, 100, 30);
  BtnItem2.Caption := 'viCpu Telemetry';
  BtnItem2.Variant := vsbSurface;
  FSandboxStack.Add(BtnItem2);

  BtnItem3 := TVeloxStyledButton.Create(Self);
  BtnItem3.SetBounds(0, 0, 120, 30);
  BtnItem3.Caption := 'viTerminal Shell';
  BtnItem3.Variant := vsbOutline;
  FSandboxStack.Add(BtnItem3);

  BtnItem4 := TVeloxStyledButton.Create(Self);
  BtnItem4.SetBounds(0, 0, 95, 30);
  BtnItem4.Caption := 'viCloud Sync';
  BtnItem4.Variant := vsbSurface;
  FSandboxStack.Add(BtnItem4);

  // 3. Vector Icon Gallery Card
  IconGalleryCard := TPanel.Create(Self);
  IconGalleryCard.Parent := APanel;
  IconGalleryCard.Align := alClient;
  IconGalleryCard.BevelOuter := bvNone;
  IconGalleryCard.Color := FColors.Background;

  GalleryLbl := TLabel.Create(Self);
  GalleryLbl.Parent := IconGalleryCard;
  GalleryLbl.Left := 16;
  GalleryLbl.Top := 8;
  GalleryLbl.Font.Name := 'Segoe UI';
  GalleryLbl.Font.Size := 10;
  GalleryLbl.Font.Style := [fsBold];
  GalleryLbl.Font.Color := FColors.Accent;
  GalleryLbl.Caption := 'Scalable Windows 11 Fluent Vector Icons (TVeloxIcons — 36 Built-in Glyphs)';

  FIconPaintBox := TPaintBox.Create(Self);
  FIconPaintBox.Parent := IconGalleryCard;
  FIconPaintBox.SetBounds(16, 32, 900, 360);
  FIconPaintBox.OnPaint := OnIconPaintBoxPaint;
end;

procedure TStudioMainForm.OnIconPaintBoxPaint(Sender: TObject);
var
  Idx, Col, Row, CellW, CellH, X, Y: Integer;
  IconKind: TVeloxIcon;
  NameStr: string;
  R: TRect;
begin
  FIconPaintBox.Canvas.Brush.Color := FColors.Background;
  FIconPaintBox.Canvas.FillRect(FIconPaintBox.ClientRect);
  FIconPaintBox.Canvas.Font.Name := 'Segoe UI';
  FIconPaintBox.Canvas.Font.Size := 8;

  CellW := 95;
  CellH := 58;
  Idx := 0;

  for IconKind := Succ(viNone) to High(TVeloxIcon) do
  begin
    Col := Idx mod 9;
    Row := Idx div 9;
    X := Col * CellW;
    Y := Row * CellH;

    R := Rect(X, Y, X + CellW - 4, Y + CellH - 4);
    FIconPaintBox.Canvas.Brush.Color := FColors.Surface;
    FIconPaintBox.Canvas.Pen.Color := FColors.Border;
    FIconPaintBox.Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 6, 6);

    TVeloxIcons.Draw(FIconPaintBox.Canvas, Rect(X + 6, Y + 6, X + 34, Y + 34), IconKind, FColors.Accent, 20);

    NameStr := TVeloxIcons.IconName(IconKind);
    FIconPaintBox.Canvas.Font.Color := FColors.TextPrimary;
    FIconPaintBox.Canvas.Brush.Style := bsClear;
    FIconPaintBox.Canvas.TextOut(X + 6, Y + 38, NameStr);

    Inc(Idx);
  end;
end;

procedure TStudioMainForm.OnToggle60FpsClick(Sender: TObject);
begin
  if FToggle60Fps.Checked then
  begin
    FToggleStatusLabel.Font.Color := FColors.Success;
    FToggleStatusLabel.Caption := 'Interpolated Smooth Sliding Active';
  end
  else
  begin
    FToggleStatusLabel.Font.Color := FColors.TextSecondary;
    FToggleStatusLabel.Caption := 'Toggle Switch Switched OFF';
  end;
end;

procedure TStudioMainForm.HandleBtnStackHorz(Sender: TObject);
begin
  if Assigned(FSandboxStack) then
  begin
    FSandboxStack.Orientation := voHorizontal;
    FSandboxStack.Relayout;
  end;
end;

procedure TStudioMainForm.HandleBtnStackVert(Sender: TObject);
begin
  if Assigned(FSandboxStack) then
  begin
    FSandboxStack.Orientation := voVertical;
    FSandboxStack.Relayout;
  end;
end;

procedure TStudioMainForm.HandleBtnStackWrap(Sender: TObject);
begin
  if Assigned(FSandboxStack) then
  begin
    FSandboxStack.Wrap := not FSandboxStack.Wrap;
    FSandboxStack.Relayout;
  end;
end;

procedure TStudioMainForm.HandleBtnStackGap(Sender: TObject);
begin
  if Assigned(FSandboxStack) then
  begin
    if FSandboxStack.Gap = 4 then
      FSandboxStack.Gap := 8
    else if FSandboxStack.Gap = 8 then
      FSandboxStack.Gap := 16
    else
      FSandboxStack.Gap := 4;
    FSandboxStack.Relayout;
  end;
end;

procedure TStudioMainForm.SetupCommandPalette;
begin
  FPalette := TVeloxCommandPalette.Create(Self);

  // Navigation commands
  FPalette.RegisterCommand('nav_dash', 'Go to Telemetry & Charts', 'Navigation', 'Alt+1', CmdNavDash);
  FPalette.RegisterCommand('nav_insp', 'Go to Property Studio', 'Navigation', 'Alt+2', CmdNavInsp);
  FPalette.RegisterCommand('nav_json', 'Go to JSON Explorer', 'Navigation', 'Alt+3', CmdNavJson);
  FPalette.RegisterCommand('nav_diff', 'Go to Diff Inspector', 'Navigation', 'Alt+4', CmdNavDiff);
  FPalette.RegisterCommand('nav_clip', 'Go to Clipboard (Win+V)', 'Navigation', 'Alt+5', CmdNavClip);
  FPalette.RegisterCommand('nav_sec', 'Go to Security Audit', 'Navigation', 'Alt+6', CmdNavSec);
  FPalette.RegisterCommand('nav_box', 'Go to Design Sandbox & Icons', 'Navigation', 'Alt+7', CmdNavSandbox);

  // Theme commands
  FPalette.RegisterCommand('theme_dark', 'Switch Theme: Dark', 'Theme', '', CmdThemeDark);
  FPalette.RegisterCommand('theme_light', 'Switch Theme: Light', 'Theme', '', CmdThemeLight);
  FPalette.RegisterCommand('theme_mid', 'Switch Theme: Midnight', 'Theme', '', CmdThemeMid);
  FPalette.RegisterCommand('theme_nord', 'Switch Theme: Nord', 'Theme', '', CmdThemeNord);
  FPalette.RegisterCommand('theme_hc', 'Switch Theme: High Contrast', 'Theme', '', CmdThemeHc);

  // System commands
  FPalette.RegisterCommand('sys_trim', 'Trim Process Working Set RAM', 'System', '', CmdTrimRam);
end;

procedure TStudioMainForm.HandleBtnDarkClick(Sender: TObject);  begin SwitchToTheme(vctDark); end;
procedure TStudioMainForm.HandleBtnLightClick(Sender: TObject); begin SwitchToTheme(vctLight); end;
procedure TStudioMainForm.HandleBtnMidClick(Sender: TObject);   begin SwitchToTheme(vctMidnight); end;
procedure TStudioMainForm.HandleBtnNordClick(Sender: TObject);  begin SwitchToTheme(vctNord); end;
procedure TStudioMainForm.HandleBtnTrimClick(Sender: TObject);  begin TrimWorkingSetAction; end;

procedure TStudioMainForm.CmdNavDash;   begin FShell.SwitchPage('dashboard'); end;
procedure TStudioMainForm.CmdNavInsp;   begin FShell.SwitchPage('inspector'); end;
procedure TStudioMainForm.CmdNavJson;   begin FShell.SwitchPage('jsontree'); end;
procedure TStudioMainForm.CmdNavDiff;   begin FShell.SwitchPage('diff'); end;
procedure TStudioMainForm.CmdNavClip;   begin FShell.SwitchPage('clipboard'); end;
procedure TStudioMainForm.CmdNavSec;    begin FShell.SwitchPage('security'); end;
procedure TStudioMainForm.CmdNavSandbox;begin FShell.SwitchPage('sandbox'); end;

procedure TStudioMainForm.CmdThemeDark;  begin SwitchToTheme(vctDark); end;
procedure TStudioMainForm.CmdThemeLight; begin SwitchToTheme(vctLight); end;
procedure TStudioMainForm.CmdThemeMid;   begin SwitchToTheme(vctMidnight); end;
procedure TStudioMainForm.CmdThemeNord;  begin SwitchToTheme(vctNord); end;
procedure TStudioMainForm.CmdThemeHc;    begin SwitchToTheme(vctHighContrast); end;
procedure TStudioMainForm.CmdTrimRam;    begin TrimWorkingSetAction; end;

procedure TStudioMainForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  // Ctrl+K opens Command Palette (#5)
  if (Key = Ord('K')) and (ssCtrl in Shift) then
  begin
    FPalette.ShowPaletteModal(Self, FColors);
    Key := 0;
    Exit;
  end;

  if (Key = VK_ESCAPE) then
  begin
    FShell.SetStatusMessage('Press Ctrl+K for Fuzzy Command Palette', vsNormal);
    Key := 0;
    Exit;
  end;

  inherited KeyDown(Key, Shift);
end;

procedure TStudioMainForm.HandleSearchClick(Sender: TObject);
begin
  FPalette.ShowPaletteModal(Self, FColors);
end;

procedure TStudioMainForm.SwitchToTheme(const ATheme: TVeloxCustomTheme);
var
  SysTheme: TVeloxTheme;
begin
  FCurrentTheme := ATheme;
  FColors := TVeloxUtils.GetCustomThemeColors(ATheme);

  if ATheme = vctLight then
    SysTheme := vtLight
  else
    SysTheme := vtDark;

  TVeloxThemeEngine.ApplyFormTheme(Self, SysTheme);
  TVeloxThemeEngine.ApplySystemBackdrop(Handle, vbtMica);

  FShell.ApplyColors(FColors);
  if Assigned(FInspector) then FInspector.ApplyColors(FColors);
  if Assigned(FJsonViewer) then FJsonViewer.ApplyColors(FColors);
  if Assigned(FDiffInspector) then FDiffInspector.ApplyColors(FColors);
  if Assigned(FClipboard) then FClipboard.ApplyColors(FColors);
  if Assigned(FAuditLog) then FAuditLog.ApplyColors(FColors);
  if Assigned(FSandboxStack) then FSandboxStack.ApplyColors(FColors);
  if Assigned(FToggle60Fps) then FToggle60Fps.ApplyColors(FColors);
  if Assigned(FIconPaintBox) then FIconPaintBox.Invalidate;

  FListView.Color := FColors.Background;
  FListView.Font.Color := FColors.TextPrimary;

  FShell.SetStatusMessage('Applied Theme: ' + IntToStr(Ord(ATheme)), vsNormal);
  Invalidate;
end;

procedure TStudioMainForm.TrimWorkingSetAction;
var
  BeforeMb, AfterMb: Double;
  ProcMem: TVeloxProcessMemory;
begin
  ProcMem := TVeloxMemory.GetProcessMemory(GetCurrentProcessId);
  BeforeMb := ProcMem.WorkingSetBytes / (1024.0 * 1024.0);

  TVeloxSystem.TrimProcessWorkingSet(GetCurrentProcessId);

  ProcMem := TVeloxMemory.GetProcessMemory(GetCurrentProcessId);
  AfterMb := ProcMem.WorkingSetBytes / (1024.0 * 1024.0);

  FShell.SetStatusMessage(Format('Trimmed RAM: %.1f MB -> %.1f MB', [BeforeMb, AfterMb]), vsNormal);
  if Assigned(FAuditLog) then
    FAuditLog.LogEvent('Working Set Trim', Format('Freed from %.1f MB to %.1f MB', [BeforeMb, AfterMb]), vsNormal);
end;

procedure TStudioMainForm.OnTimerTick(Sender: TObject);
var
  CpuVal, RamVal: Single;
  I: Integer;
  Row: TTelemetryRow;
begin
  // Generate smooth telemetry curves
  CpuVal := 22.0 + (Sin(Now * 86400 * 0.1) * 15.0) + Random(12);
  RamVal := 48.0 + (Cos(Now * 86400 * 0.08) * 10.0) + Random(8);
  FCpuRing.Add(CpuVal);
  FRamRing.Add(RamVal);

  if FRows.Count = 0 then
  begin
    // Seed sample telemetry processes
    for I := 1 to 12 do
    begin
      Row.Pid := 1000 + I * 137;
      case I of
        1: Row.Name := 'VeloxUI.Studio.exe';
        2: Row.Name := 'System Telemetry Broker';
        3: Row.Name := 'GDI+ Surface Compositor';
        4: Row.Name := 'CNG Security Watcher';
        5: Row.Name := 'JSON RFC-8259 Worker';
        6: Row.Name := 'LCS Diff Staging Host';
        7: Row.Name := 'DWM Mica Backdrop Sync';
        8: Row.Name := 'Fast VirtualGrid Engine';
        9: Row.Name := 'High-DPI PerMonitorV2 Daemon';
        10: Row.Name := 'Fuzzy Raycast Dispatcher';
        11: Row.Name := 'Clipboard Listener Host';
        12: Row.Name := 'BCrypt Hash Verifier';
      end;
      Row.CpuPercent := 2.0 + Random(25);
      Row.MemoryMB := 12.0 + Random(90);
      Row.State := vsNormal;
      SetLength(Row.History, 10);
      Row.History[0] := 10.0; Row.History[1] := 15.0; Row.History[2] := 25.0;
      Row.History[3] := 18.0; Row.History[4] := 32.0; Row.History[5] := 22.0;
      Row.History[6] := 28.0; Row.History[7] := 16.0; Row.History[8] := 24.0;
      Row.History[9] := Row.CpuPercent;
      FRows.Add(Row);
    end;
  end
  else
  begin
    // Jiggle values
    for I := 0 to FRows.Count - 1 do
    begin
      Row := FRows[I];
      Row.CpuPercent := Abs(Row.CpuPercent + (Random(11) - 5) * 0.8);
      if Row.CpuPercent > 99.0 then Row.CpuPercent := 85.0;
      if Row.CpuPercent > 45.0 then
        Row.State := vsWarning
      else
        Row.State := vsNormal;
      Row.History[9] := Row.CpuPercent;
      FRows[I] := Row;
    end;
  end;

  FGrid.RefreshCount(FRows.Count);
  if Assigned(FChartBox) then FChartBox.Invalidate;
end;

procedure TStudioMainForm.OnChartBoxPaint(Sender: TObject);
var
  C: TCanvas;
  Card1R, Card2R, Card3R: TRect;
  W: Integer;
begin
  C := FChartBox.Canvas;
  C.Brush.Color := FColors.Background;
  C.FillRect(FChartBox.ClientRect);

  W := (FChartBox.Width - 36) div 3;

  Card1R := Rect(12, 10, 12 + W, FChartBox.Height - 10);
  Card2R := Rect(20 + W, 10, 20 + W * 2, FChartBox.Height - 10);
  Card3R := Rect(28 + W * 2, 10, FChartBox.Width - 12, FChartBox.Height - 10);

  // Card 1: CPU Donut Gauge (#3)
  TVeloxGdiPlus.DrawCard(C, Card1R, FColors.SurfaceCard, FColors.Border, 8);
  TVeloxGdiPlus.DrawGlowBorder(C, Card1R, FColors.Accent, 8, 2);
  TVeloxCharts.DrawDonutGauge(C, Rect(Card1R.Left + 14, Card1R.Top + 14, Card1R.Left + 130, Card1R.Bottom - 14),
    FCpuRing.Latest, Format('%.0f%%', [FCpuRing.Latest]), 'CPU LOAD', FColors, FColors.Accent, 7.0);
  C.Brush.Style := bsClear;
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  C.TextOut(Card1R.Left + 140, Card1R.Top + 24, 'PROCESSOR CORE');
  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  C.TextOut(Card1R.Left + 140, Card1R.Top + 48, Format('Peak: %.1f%%', [FCpuRing.Peak]));
  C.TextOut(Card1R.Left + 140, Card1R.Top + 68, Format('Average: %.1f%%', [FCpuRing.Average]));

  // Card 2: Memory Donut Gauge (#3)
  TVeloxGdiPlus.DrawCard(C, Card2R, FColors.SurfaceCard, FColors.Border, 8);
  TVeloxCharts.DrawDonutGauge(C, Rect(Card2R.Left + 14, Card2R.Top + 14, Card2R.Left + 130, Card2R.Bottom - 14),
    FRamRing.Latest, Format('%.0f%%', [FRamRing.Latest]), 'SYSTEM RAM', FColors, $10B981, 7.0);
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  C.TextOut(Card2R.Left + 140, Card2R.Top + 24, 'MEMORY COMMITTED');
  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  C.TextOut(Card2R.Left + 140, Card2R.Top + 48, Format('Committed: %.1f%%', [FRamRing.Latest]));
  C.TextOut(Card2R.Left + 140, Card2R.Top + 68, 'Hardware CNG: Active');

  // Card 3: Dual Sparkline (#3)
  TVeloxGdiPlus.DrawCard(C, Card3R, FColors.SurfaceCard, FColors.Border, 8);
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  C.TextOut(Card3R.Left + 14, Card3R.Top + 12, 'DUAL TELEMETRY SPARKLINE');
  TVeloxCharts.DrawDualSparkline(C, Rect(Card3R.Left + 14, Card3R.Top + 36, Card3R.Right - 14, Card3R.Bottom - 14),
    FCpuRing.ToArray, FRamRing.ToArray, FColors.Accent, $10B981, FColors.SurfaceCard);
end;

procedure TStudioMainForm.OnListViewData(Sender: TObject; Item: TListItem);
var
  Idx: Integer;
begin
  Idx := Item.Index;
  if (Idx >= 0) and (Idx < FRows.Count) then
  begin
    Item.Caption := IntToStr(FRows[Idx].Pid);
    Item.SubItems.Clear;
    Item.SubItems.Add(FRows[Idx].Name);
    Item.SubItems.Add(Format('%.1f%%', [FRows[Idx].CpuPercent]));
    Item.SubItems.Add(Format('%.1f MB', [FRows[Idx].MemoryMB]));
    if FRows[Idx].State = vsNormal then
      Item.SubItems.Add('Normal')
    else
      Item.SubItems.Add('Warning');
    Item.SubItems.Add(''); // Sparkline column
  end;
end;

procedure TStudioMainForm.OnCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  DefaultDraw := True;
end;

procedure TStudioMainForm.OnCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; var DefaultDraw: Boolean);
var
  Idx: Integer;
  R: TRect;
  StatusStr: string;
begin
  Idx := Item.Index;
  if (Idx < 0) or (Idx >= FRows.Count) then Exit;

  // CPU Inline HeatBar (#4)
  if SubItem = 2 then
  begin
    R := Item.DisplayRectSubItem(SubItem, drBounds);
    TVeloxCellRenderer.DrawInlineBar(Sender.Canvas, R, FRows[Idx].CpuPercent,
      Format('%.1f%%', [FRows[Idx].CpuPercent]), FColors, FRows[Idx].State, True);
    DefaultDraw := False;
  end
  // Health Status Dot (#4)
  else if SubItem = 4 then
  begin
    R := Item.DisplayRectSubItem(SubItem, drBounds);
    if FRows[Idx].State = vsNormal then
      StatusStr := 'Normal'
    else
      StatusStr := 'Elevated';
    TVeloxCellRenderer.DrawStatusDotCell(Sender.Canvas, R, StatusStr, FRows[Idx].State, FColors);
    DefaultDraw := False;
  end
  // Inline Mini Sparkline (#4)
  else if SubItem = 5 then
  begin
    R := Item.DisplayRectSubItem(SubItem, drBounds);
    TVeloxCellRenderer.DrawInlineSparkline(Sender.Canvas, R,
      FRows[Idx].History, FColors, FColors.Accent);
    DefaultDraw := False;
  end
  else
    DefaultDraw := True;
end;

function TStudioMainForm.CompareRows(const A, B: TTelemetryRow; const ACol: Integer): Integer;
begin
  Result := 0;
  case ACol of
    0: Result := A.Pid - B.Pid;
    1: Result := CompareText(A.Name, B.Name);
    2: begin
         if A.CpuPercent > B.CpuPercent then Result := 1
         else if A.CpuPercent < B.CpuPercent then Result := -1;
       end;
    3: begin
         if A.MemoryMB > B.MemoryMB then Result := 1
         else if A.MemoryMB < B.MemoryMB then Result := -1;
       end;
  end;
end;

var
  StudioApp: TStudioMainForm;

begin
  Application.Initialize;
  Application.Title := 'VeloxUI Master Studio';
  TVeloxThemeEngine.InitializeProcessDarkMode;
  StudioApp := TStudioMainForm.CreateStudio(Application);
  StudioApp.Show;
  Application.Run;
end.
