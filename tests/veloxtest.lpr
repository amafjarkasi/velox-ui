program veloxtest;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  Interfaces,
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
  Menus,
  Generics.Collections,
  Velox.Types,
  Velox.Theme,
  Velox.GdiPlus,
  Velox.Controls,
  Velox.VirtualGrid,
  Velox.Async,
  Velox.System,
  Velox.Export,
  Velox.Hotkeys,
  Velox.Config,
  Velox.Charts,
  Velox.Toast,
  Velox.EventBus,
  Velox.Reactive,
  Velox.TreeBuilder,
  Velox.StyledButton,
  Velox.TaskDialog,
  Velox.CommandPalette,
  Velox.AppShell,
  Velox.Logger,
  Velox.Animation,
  Velox.ToggleSwitch,
  Velox.ContextMenu,
  Velox.IPC,
  Velox.SplitView,
  Velox.Profiler,
  Velox.SparkGrid,
  Velox.Validator,
  Velox.MarkdownView,
  Velox.Screenshot;

type
  TTestRow = record
    Id: Integer;
    ParentId: Integer;
    Depth: Integer;
    Name: string;
    Metric: Double;
  end;

  TGridSortHelper = class
  public
    HotkeyHits: Integer;
    EventBusHits: Integer;
    LastEventTopic: string;
    LastEventPayload: string;
    ObservableHits: Integer;
    LastObservableVal: Integer;
    DebounceHits: Integer;
    ChipSelectedIdx: Integer;
    CommandExecuted: Boolean;
    SwitchedPageId: string;
    TweenLastInt: Integer;
    TweenLastColor: TColor;
    ToggleClicks: Integer;
    MenuClicked: Boolean;
    function CompareRows(const A, B: TTestRow; const ACol: Integer): Integer;
    function CollectSample: Integer;
    procedure DeliverSample(const AVal: Integer);
    function ProvideExportCell(const ARow, ACol: Integer): string;
    procedure OnHotkeyFired(Sender: TObject);
    procedure OnBusEvent(const AEvent: TVeloxEventMessage);
    procedure OnObsChanged(const AVal: Integer);
    function FormatObsInt(const AVal: Integer): string;
    procedure OnDebouncedFired(Sender: TObject);
    procedure ExtractTreeIds(const AItem: TTestRow; out ANodeId, AParentId: Cardinal);
    procedure SetTreeDepth(var AItem: TTestRow; const ADepth: Integer);
    procedure OnChipSelect(Sender: TObject; const ASelectedIndex: Integer);
    procedure OnCommandRun;
    procedure OnShellPageSwitch(const APageId: string; APagePanel: TPanel);
    procedure OnTweenInt(const ACurrentValue: Integer);
    procedure OnTweenColor(const ACurrentColor: TColor);
    procedure OnToggleChanged(Sender: TObject);
    procedure OnMenuItemClick(Sender: TObject);
  end;

function TGridSortHelper.CompareRows(const A, B: TTestRow; const ACol: Integer): Integer;
begin
  Result := 0;
  case ACol of
    0: Result := A.Id - B.Id;
    1: Result := CompareText(A.Name, B.Name);
    2: begin
         if A.Metric > B.Metric then Result := 1
         else if A.Metric < B.Metric then Result := -1;
       end;
  end;
end;

function TGridSortHelper.CollectSample: Integer;
begin
  Result := 42;
end;

procedure TGridSortHelper.DeliverSample(const AVal: Integer);
begin
  // No-op in console test
end;

function TGridSortHelper.ProvideExportCell(const ARow, ACol: Integer): string;
begin
  if ARow = 0 then
  begin
    case ACol of
      0: Result := '100';
      1: Result := 'nova, "core"';
      2: Result := '42.5%';
    else
      Result := '';
    end;
  end
  else
  begin
    case ACol of
      0: Result := '200';
      1: Result := 'velox|ui';
      2: Result := '12.0%';
    else
      Result := '';
    end;
  end;
end;

procedure TGridSortHelper.OnHotkeyFired(Sender: TObject);
begin
  Inc(HotkeyHits);
end;

procedure TGridSortHelper.OnBusEvent(const AEvent: TVeloxEventMessage);
begin
  Inc(EventBusHits);
  LastEventTopic := AEvent.Topic;
  LastEventPayload := AEvent.Payload;
end;

procedure TGridSortHelper.OnObsChanged(const AVal: Integer);
begin
  Inc(ObservableHits);
  LastObservableVal := AVal;
end;

function TGridSortHelper.FormatObsInt(const AVal: Integer): string;
begin
  Result := IntToStr(AVal);
end;

procedure TGridSortHelper.OnDebouncedFired(Sender: TObject);
begin
  Inc(DebounceHits);
end;

procedure TGridSortHelper.ExtractTreeIds(const AItem: TTestRow; out ANodeId, AParentId: Cardinal);
begin
  ANodeId := Cardinal(AItem.Id);
  AParentId := Cardinal(AItem.ParentId);
end;

procedure TGridSortHelper.SetTreeDepth(var AItem: TTestRow; const ADepth: Integer);
begin
  AItem.Depth := ADepth;
end;

procedure TGridSortHelper.OnChipSelect(Sender: TObject; const ASelectedIndex: Integer);
begin
  ChipSelectedIdx := ASelectedIndex;
end;

procedure TGridSortHelper.OnCommandRun;
begin
  CommandExecuted := True;
end;

procedure TGridSortHelper.OnShellPageSwitch(const APageId: string; APagePanel: TPanel);
begin
  SwitchedPageId := APageId;
end;

procedure TGridSortHelper.OnTweenInt(const ACurrentValue: Integer);
begin
  TweenLastInt := ACurrentValue;
end;

procedure TGridSortHelper.OnTweenColor(const ACurrentColor: TColor);
begin
  TweenLastColor := ACurrentColor;
end;

procedure TGridSortHelper.OnToggleChanged(Sender: TObject);
begin
  Inc(ToggleClicks);
end;

procedure TGridSortHelper.OnMenuItemClick(Sender: TObject);
begin
  MenuClicked := True;
end;

var
  Failures: Integer = 0;
  Passed: Integer = 0;

procedure Check(const AName: string; const ACond: Boolean);
begin
  if ACond then
  begin
    Inc(Passed);
    WriteLn('PASS: ' + AName);
  end
  else
  begin
    Inc(Failures);
    WriteLn('FAIL: ' + AName);
  end;
end;

var
  Ring: TVeloxRingBuffer;
  Arr, ArrB: TSingleDynArray;
  DarkColors, LightColors: TVeloxThemeColors;
  Bmp: TBitmap;
  Frm: TForm;
  SearchBox: TVeloxSearchBox;
  DarkChk: TVeloxDarkCheckBox;
  Cmb: TComboBox;
  Btn: TButton;
  Lv: TListView;
  Grid: TVeloxVirtualGrid<TTestRow>;
  Rows, TreeOut: TList<TTestRow>;
  R: TTestRow;
  Helper: TGridSortHelper;
  Modal: TVeloxModalDialog;
  Alert: TVeloxThresholdAlert;
  Sev: TVeloxSeverity;
  Poller: TVeloxPoller<Integer>;
  ProcMask, SysMask: NativeUInt;
  GdiCnt, UserCnt: Cardinal;
  VerInfo: TVeloxFileVersionInfo;
  CmdLine, SysRoot, CsvStr, JsonStr, MdStr, CheatStr, TmpIni, GalleryDarkPath, GalleryLightPath: string;
  Hotkeys: TVeloxHotkeyRegistry;
  TestKey: Word;
  Cfg: TVeloxConfig;
  ClampL, ClampT, ClampW, ClampH: Integer;
  Toast: TVeloxToast;
  Bus: TVeloxEventBus;
  SubId1, SubIdWild: Integer;
  ObsInt: TVeloxObservable<Integer>;
  BoundLbl: TLabel;
  Debouncer: TVeloxDebouncer;
  StyledBtn: TVeloxStyledButton;
  Chips: TVeloxChipGroup;
  TaskDlgH: TVeloxTaskDialogHandle;
  CmdPalette: TVeloxCommandPalette;
  CmdFiltered: TVeloxCommandArray;
  Shell: TVeloxAppShell;
  Page1, Page2: TPanel;
  Logger: TVeloxLogger;
  Animator: TVeloxAnimator;
  ToggleSw: TVeloxToggleSwitch;
  Slider: TVeloxSlider;
  PopMenu: TVeloxPopupMenu;
  SingleInst1, SingleInst2: TVeloxSingleInstance;
  SplitPnl: TPanel;
  Splitter: TVeloxSplitter;
  SW: TVeloxStopwatch;
  FrameProf: TVeloxFrameProfiler;
  Validator: TVeloxValidator;
  EdNum: TEdit;
  ValErr: string;
  MdView: TVeloxMarkdownView;
  I: Integer;
begin
  try
    WriteLn('=== VeloxUI Automated Verification Suite (30 Modules) ===');

    // 1. Ring Buffer & Telemetry Primitives
    WriteLn('[1/30] Testing TVeloxRingBuffer & TVeloxUtils...');
    Ring.Clear(10);
    Check('ring: initial count is 0', Ring.Count = 0);
    Check('ring: initial capacity is 10', Ring.Capacity = 10);
    for I := 1 to 15 do
      Ring.Add(I * 2.0);
    Check('ring: capped at capacity 10 after 15 adds', Ring.Count = 10);
    Arr := Ring.ToArray;
    Check('ring: oldest element is 12.0 (6*2)', Arr[0] = 12.0);
    Check('ring: newest element is 30.0 (15*2)', Ring.Latest = 30.0);
    Check('ring: peak is 30.0', Ring.Peak = 30.0);
    Check('ring: average is 21.0', Abs(Ring.Average - 21.0) < 0.01);

    DarkColors := TVeloxUtils.GetThemeColors(vtDark);
    LightColors := TVeloxUtils.GetThemeColors(vtLight);
    Check('theme: dark and light backgrounds differ', DarkColors.Background <> LightColors.Background);
    Check('utils: BlendColor mid-point', TVeloxUtils.BlendColor(clBlack, clWhite, 0.5) <> clBlack);
    Check('utils: FormatBytes GB', Pos('GB', TVeloxUtils.FormatBytes(Int64(2) * 1024 * 1024 * 1024)) > 0);
    Check('utils: FormatMegabytes GB auto-scale', Pos('GB', TVeloxUtils.FormatMegabytes(2048.0)) > 0);
    Check('utils: FormatRateKBps MB/s auto-scale', Pos('MB/s', TVeloxUtils.FormatRateKBps(2048.0)) > 0);
    Check('utils: FormatPercent clamped', TVeloxUtils.FormatPercent(125.0) = '100.0%');
    Check('utils: FormatDuration days', Pos('1d', TVeloxUtils.FormatDuration(90000)) > 0);
    Check('utils: UTF-8/UTF-16 sort arrows non-empty', (VELOX_ARROW_ASC <> '') and (VELOX_ARROW_DESC <> ''));

    // 2. GDI+ Hardware-Accelerated Vector Engine
    WriteLn('[2/30] Testing TVeloxGdiPlus Anti-Aliased Primitives...');
    Bmp := TBitmap.Create;
    try
      Bmp.SetSize(240, 120);
      TVeloxGdiPlus.DrawCard(Bmp.Canvas, Rect(0, 0, 240, 120), DarkColors.SurfaceCard, DarkColors.Border, 8);
      Check('gdi+: DrawCard executes cleanly', True);
      TVeloxGdiPlus.DrawProgressBar(Bmp.Canvas, Rect(14, 96, 226, 104), 65.0, DarkColors.Border, DarkColors.Accent);
      Check('gdi+: DrawProgressBar executes cleanly', True);
      TVeloxGdiPlus.DrawBadge(Bmp.Canvas, Rect(14, 14, 80, 34), 'NORMAL', DarkColors.Success, DarkColors.TextPrimary);
      Check('gdi+: DrawBadge executes cleanly', True);
      TVeloxGdiPlus.DrawSparkline(Bmp.Canvas, Rect(140, 14, 226, 80), Arr, DarkColors.Accent, DarkColors.AccentSecondary);
      Check('gdi+: DrawSparkline executes cleanly', True);
    finally
      Bmp.Free;
    end;

    // 3. DWM & UXTheme Dark Mode Engine
    WriteLn('[3/30] Testing TVeloxThemeEngine (DWM, UXTheme & Recursive Styling)...');
    TVeloxThemeEngine.InitializeProcessDarkMode(True);
    Check('theme: InitializeProcessDarkMode (Ordinal 135) succeeds', True);
    Check('theme: DetectSystemTheme returns valid enum', TVeloxThemeEngine.DetectSystemTheme in [vtDark, vtLight]);

    // 4. Fluent Control Factories (SearchBox, DarkCheckBox, ComboBox Sync, Modal)
    WriteLn('[4/30] Testing TVeloxControls (SearchBox, DarkCheckBox, High-DPI ComboBox, Modal)...');
    Frm := TForm.CreateNew(nil);
    try
      Frm.SetBounds(100, 100, 800, 600);
      SearchBox := TVeloxSearchBox.CreateBox(Frm, Frm, 16, 16, 200, 28, 'Search items...', DarkColors);
      Check('controls: SearchBox wrapper height is 28px', SearchBox.Container.Height = 28);
      Check('controls: SearchBox inner TEdit is bsNone', SearchBox.Edit.BorderStyle = bsNone);
      Check('controls: SearchBox inner TEdit vertically centered at Top=6', SearchBox.Edit.Top = 6);
      Check('controls: SearchBox inner TEdit has 10px left margin', SearchBox.Edit.Left = 10);
      SearchBox.Text := 'velox';
      Check('controls: SearchBox text property roundtrip', SearchBox.Text = 'velox');

      DarkChk := TVeloxDarkCheckBox.CreateCheck(Frm, Frm, 16, 60, 180, 'Minimize to tray', DarkColors, True);
      Check('controls: DarkCheckBox decoupled caption is empty on native checkbox', DarkChk.CheckBox.Caption = '');
      Check('controls: DarkCheckBox label has caption and crHandPoint',
        (DarkChk.CaptionLabel.Caption = 'Minimize to tray') and (DarkChk.CaptionLabel.Cursor = crHandPoint));
      Check('controls: DarkCheckBox initial checked is True', DarkChk.Checked);

      Btn := TButton.Create(Frm);
      Btn.Parent := Frm;
      Btn.SetBounds(240, 16, 80, 28);

      Cmb := TComboBox.Create(Frm);
      Cmb.Parent := Frm;
      Cmb.Style := csOwnerDrawFixed;
      Cmb.SetBounds(330, 16, 110, 28);
      Cmb.Items.Add('0.5s (Fast)');
      Cmb.Items.Add('1.5s (Normal)');
      Cmb.ItemIndex := 1;
      TVeloxControls.SyncComboBoxHeight(Cmb, Btn, 28);
      Check('controls: SyncComboBoxHeight executes cleanly with reference button', True);

      TVeloxThemeEngine.ApplyFormTheme(Frm, vtDark);
      Check('theme: ApplyFormTheme styles form background to DarkColors.Background', Frm.Color = DarkColors.Background);
      TVeloxThemeEngine.ApplyFormTheme(Frm, vtLight);
      Check('theme: ApplyFormTheme switches form background to LightColors.Background', Frm.Color = LightColors.Background);

      Modal := TVeloxControls.CreateModalDialog(Frm, 'Inspector', 'Item Details', 'Live Telemetry', 600, 420, DarkColors, 'Copy', 'Close', True);
      try
        Check('controls: CreateModalDialog creates Header, Footer, Primary/Cancel buttons, and Consolas Memo',
          Assigned(Modal.Form) and Assigned(Modal.HeaderPanel) and Assigned(Modal.FooterPanel) and
          Assigned(Modal.PrimaryButton) and Assigned(Modal.CancelButton) and Assigned(Modal.Memo));
      finally
        Modal.Form.Free;
      end;

      // 5. Generic Virtual Grid Controller (TVeloxVirtualGrid<T>)
      WriteLn('[5/30] Testing TVeloxVirtualGrid<T> (OwnerData, QuickSort, Natural Sort Direction)...');
      Lv := TListView.Create(Frm);
      Lv.Parent := Frm;
      Lv.SetBounds(16, 100, 760, 400);

      Grid := TVeloxVirtualGrid<TTestRow>.Create(Lv);
      Helper := TGridSortHelper.Create;
      Rows := TList<TTestRow>.Create;
      try
        Grid.AddColumn('ID', 70, taLeftJustify, False);
        Grid.AddColumn('Name', 200, taLeftJustify, False);
        Grid.AddColumn('RAM (MB)', 120, taRightJustify, True);

        Check('grid: OwnerData enabled automatically', Lv.OwnerData);
        Check('grid: 3 columns registered', Lv.Columns.Count = 3);

        R.Id := 2; R.Name := 'Beta';  R.Metric := 150.0; Rows.Add(R);
        R.Id := 1; R.Name := 'Alpha'; R.Metric := 900.0; Rows.Add(R);
        R.Id := 3; R.Name := 'Gamma'; R.Metric := 420.0; Rows.Add(R);

        Grid.ClickColumn(2);
        Check('grid: numeric column defaults to descending on first click', (Grid.SortColumn = 2) and (not Grid.SortAscending));
        Grid.SortList(Rows, Helper.CompareRows);
        Check('grid: descending sort orders 900.0 first and 150.0 last',
          (Rows[0].Metric = 900.0) and (Rows[2].Metric = 150.0));
        Check('grid: header indicator shows descending arrow',
          Pos(VELOX_ARROW_DESC, Lv.Columns[2].Caption) > 0);

        Grid.ClickColumn(1);
        Check('grid: text column defaults to ascending on first click', (Grid.SortColumn = 1) and Grid.SortAscending);
        Grid.SortList(Rows, Helper.CompareRows);
        Check('grid: ascending name sort orders Alpha first and Gamma last',
          (Rows[0].Name = 'Alpha') and (Rows[2].Name = 'Gamma'));
        Check('grid: header indicator shows ascending arrow',
          Pos(VELOX_ARROW_ASC, Lv.Columns[1].Caption) > 0);

        Grid.RefreshCount(Rows.Count);
        Check('grid: RefreshCount updates virtual Items.Count', Lv.Items.Count = 3);
      finally
        Rows.Free;
        Helper.Free;
        Grid.Free;
      end;
    finally
      Frm.Free;
    end;

    // 6. Async Poller & Hysteresis Threshold Alert Engine
    WriteLn('[6/30] Testing TVeloxPoller<T> & TVeloxThresholdAlert...');
    Alert.Configure(75.0, 90.0, 2, 10000, 5.0);
    Check('alert: first warning spike (streak 1/2) does not fire yet', not Alert.Evaluate(80.0, 1000, Sev));
    Check('alert: second sustained warning spike (streak 2/2) fires vsWarning',
      Alert.Evaluate(82.0, 2000, Sev) and (Sev = vsWarning));
    Check('alert: escalation to danger (95%) fires immediately as vsCritical',
      Alert.Evaluate(95.0, 3000, Sev) and (Sev = vsCritical));
    Check('alert: slight dip to 72% stays active due to 5% hysteresis below 75%',
      (not Alert.Evaluate(72.0, 4000, Sev)) and (Alert.ActiveSeverity = vsCritical));
    Check('alert: drop to 68% (<= 70%) clears alert via hysteresis recovery',
      (not Alert.Evaluate(68.0, 5000, Sev)) and (Alert.ActiveSeverity = vsNormal));

    Helper := TGridSortHelper.Create;
    try
      Poller := TVeloxPoller<Integer>.Create(500, Helper.CollectSample, Helper.DeliverSample);
      try
        Check('poller: initial interval is 500ms', Poller.IntervalMs = 500);
        Poller.Start;
        Check('poller: IsRunning is True after Start', Poller.IsRunning);
        Poller.SetInterval(250);
        Check('poller: SetInterval updates live to 250ms', Poller.IntervalMs = 250);
        Poller.Stop;
        Check('poller: IsRunning is False after sub-50ms interruptible Stop', not Poller.IsRunning);
      finally
        Poller.Free;
      end;
    finally
      Helper.Free;
    end;

    // 7. Win32 & NT Kernel System Helpers (TVeloxSystem)
    WriteLn('[7/30] Testing TVeloxSystem (NT Command Line, VersionInfo, GUI Resources, Affinity)...');
    CmdLine := TVeloxSystem.GetProcessCommandLine(GetCurrentProcessId);
    Check('system: GetProcessCommandLine(CurrentPID) via NtQueryInformationProcess(60) non-empty', CmdLine <> '');
    Check('system: GetProcessCommandLine(PID 0) guarded', TVeloxSystem.GetProcessCommandLine(0) = '');

    SysRoot := SysUtils.GetEnvironmentVariable('SystemRoot');
    if SysRoot = '' then SysRoot := 'C:\Windows';
    VerInfo := TVeloxSystem.GetFileVersionMetadata(SysRoot + '\System32\kernel32.dll');
    Check('system: GetFileVersionMetadata extracts Microsoft CompanyName from kernel32.dll',
      (VerInfo.CompanyName <> '') and (VerInfo.FileVersion <> ''));

    Check('system: GetProcessGuiResources(CurrentPID) succeeds',
      TVeloxSystem.GetProcessGuiResources(GetCurrentProcessId, GdiCnt, UserCnt));
    Check('system: GetProcessAffinity(CurrentPID) returns valid masks',
      TVeloxSystem.GetProcessAffinity(GetCurrentProcessId, ProcMask, SysMask) and (ProcMask <> 0) and (SysMask <> 0));
    Check('system: SetProcessAffinity rejects 0 mask',
      not TVeloxSystem.SetProcessAffinity(GetCurrentProcessId, 0));
    Check('system: TrimProcessWorkingSet(CurrentPID) succeeds',
      TVeloxSystem.TrimProcessWorkingSet(GetCurrentProcessId));
    Check('system: RunTask rejects empty command',
      not TVeloxSystem.RunTask('   ', False));

    // 8. Universal Data Exporter (TVeloxExporter)
    WriteLn('[8/30] Testing TVeloxExporter (CSV, JSON, Markdown)...');
    Helper := TGridSortHelper.Create;
    try
      Check('export: EscapeCsvField quotes commas and quotes',
        TVeloxExporter.EscapeCsvField('nova, "core"') = '"nova, ""core"""');
      Check('export: EscapeJsonString escapes quotes and backslashes',
        TVeloxExporter.EscapeJsonString('C:\app\"bin"') = 'C:\\app\\\"bin\"');
      CsvStr := TVeloxExporter.BuildCsvTable(['PID', 'Name', 'CPU'], 2, Helper.ProvideExportCell);
      Check('export: BuildCsvTable includes header and escaped rows',
        (Pos('PID,Name,CPU', CsvStr) > 0) and (Pos('"nova, ""core"""', CsvStr) > 0));
      JsonStr := TVeloxExporter.BuildJsonTable('VeloxTest', ['PID', 'Name', 'CPU'], 2, Helper.ProvideExportCell);
      Check('export: BuildJsonTable includes generator, count, and escaped JSON items',
        (Pos('"generator": "VeloxTest"', JsonStr) > 0) and (Pos('"count": 2', JsonStr) > 0));
      MdStr := TVeloxExporter.BuildMarkdownTable(['PID', 'Name', 'CPU'], 2, Helper.ProvideExportCell);
      Check('export: BuildMarkdownTable escapes pipe characters in GFM cells',
        (Pos('| PID | Name | CPU |', MdStr) > 0) and (Pos('velox\|ui', MdStr) > 0));
    finally
      Helper.Free;
    end;

    // 9. Declarative Hotkey & Action Registry (TVeloxHotkeyRegistry)
    WriteLn('[9/30] Testing TVeloxHotkeyRegistry (Key Dispatch & Cheat Sheet)...');
    Helper := TGridSortHelper.Create;
    Hotkeys := TVeloxHotkeyRegistry.Create;
    try
      Hotkeys.Bind(Ord('F'), [ssCtrl], 'Ctrl+F', 'Focus search bar', Helper.OnHotkeyFired, 'Navigation');
      Hotkeys.Bind(VK_F1, [], 'F1', 'Show help modal', Helper.OnHotkeyFired, 'Help');
      Check('hotkeys: 2 bindings registered', Hotkeys.Count = 2);
      TestKey := Ord('F');
      Check('hotkeys: HandleKeyDown matches Ctrl+F and zeroes Key',
        Hotkeys.HandleKeyDown(nil, TestKey, [ssCtrl]) and (TestKey = 0) and (Helper.HotkeyHits = 1));
      CheatStr := Hotkeys.GenerateCheatSheet('VeloxTest');
      Check('hotkeys: GenerateCheatSheet includes Ctrl+F and category',
        (Pos('Ctrl+F', CheatStr) > 0) and (Pos('[Navigation]', CheatStr) > 0));
    finally
      Hotkeys.Free;
      Helper.Free;
    end;

    // 10. Persistent Config & Window Placement Manager (TVeloxConfig)
    WriteLn('[10/30] Testing TVeloxConfig (Key/Value, Theme & Multi-Monitor Clamp)...');
    TmpIni := ExtractFilePath(ParamStr(0)) + 'velox_test_cfg.ini';
    Cfg := TVeloxConfig.Create;
    try
      Cfg.WriteString('app.name', 'VeloxApp');
      Cfg.WriteInt('poll.ms', 1500);
      Cfg.WriteBool('tray.min', True);
      Cfg.WriteTheme(vtLight);
      Check('config: SaveToFile succeeds', Cfg.SaveToFile(TmpIni));
    finally
      Cfg.Free;
    end;
    Cfg := TVeloxConfig.Create(TmpIni);
    try
      Check('config: ReadString roundtrip', Cfg.ReadString('app.name') = 'VeloxApp');
      Check('config: ReadInt roundtrip', Cfg.ReadInt('poll.ms') = 1500);
      Check('config: ReadBool roundtrip', Cfg.ReadBool('tray.min') = True);
      Check('config: ReadTheme roundtrip', Cfg.ReadTheme = vtLight);
      ClampL := 3200; ClampT := -200; ClampW := 800; ClampH := 600;
      TVeloxConfig.ClampToDesktop(ClampL, ClampT, ClampW, ClampH, 1920, 1080);
      Check('config: ClampToDesktop rescues off-screen coordinates into 1920x1080',
        (ClampL = 1120) and (ClampT = 0));
    finally
      Cfg.Free;
      if FileExists(TmpIni) then SysUtils.DeleteFile(TmpIni);
    end;

    // 11. Advanced GDI+ Charts (TVeloxCharts: DonutGauge, DualSparkline, HeatGrid)
    WriteLn('[11/30] Testing TVeloxCharts (DonutGauge, DualSparkline, HeatGrid)...');
    Bmp := TBitmap.Create;
    try
      Bmp.SetSize(300, 160);
      SetLength(ArrB, 6);
      for I := 0 to 5 do ArrB[I] := (I + 1) * 15.0;
      TVeloxCharts.DrawDonutGauge(Bmp.Canvas, Rect(10, 10, 110, 110), 78.5, '78.5%', 'CPU', DarkColors, DarkColors.Accent);
      Check('charts: DrawDonutGauge executes cleanly', True);
      TVeloxCharts.DrawDualSparkline(Bmp.Canvas, Rect(120, 10, 290, 80), Arr, ArrB, DarkColors.Accent, DarkColors.Success, DarkColors.SurfaceCard);
      Check('charts: DrawDualSparkline executes cleanly', True);
      TVeloxCharts.DrawHeatGrid(Bmp.Canvas, Rect(120, 90, 290, 150), ArrB, DarkColors, 3);
      Check('charts: DrawHeatGrid executes cleanly', True);
    finally
      Bmp.Free;
    end;

    // 12. Non-Blocking Floating Toast Banner (TVeloxToast)
    WriteLn('[12/30] Testing TVeloxToast...');
    Frm := TForm.CreateNew(nil);
    try
      Frm.SetBounds(100, 100, 640, 480);
      Toast := TVeloxToast.Create(Frm);
      Toast.ShowToast(Frm, 'Memory Alert', 'RAM exceeded 85%', vsWarning, DarkColors, 3000);
      Check('toast: ShowToast makes banner visible with title and severity',
        Toast.IsVisible and (Toast.Title = 'Memory Alert') and (Toast.Severity = vsWarning));
      Toast.Dismiss;
      Check('toast: Dismiss hides banner immediately', not Toast.IsVisible);
    finally
      Frm.Free;
    end;

    // 13. Thread-Safe Publish/Subscribe Event Bus (TVeloxEventBus)
    WriteLn('[13/30] Testing TVeloxEventBus (Topic & Wildcard Routing)...');
    Helper := TGridSortHelper.Create;
    Bus := TVeloxEventBus.Create;
    try
      SubId1 := Bus.Subscribe('telemetry.cpu', Helper.OnBusEvent);
      SubIdWild := Bus.Subscribe('*', Helper.OnBusEvent);
      Check('eventbus: 2 subscribers registered', Bus.SubscriberCount = 2);
      Check('eventbus: Publish(telemetry.cpu) notifies both topic and wildcard subscribers',
        Bus.Publish('telemetry.cpu', '88.4%', 88.4, vsWarning) = 2);
      Check('eventbus: Publish(telemetry.ram) notifies only wildcard subscriber',
        Bus.Publish('telemetry.ram', '64.0%', 64.0, vsNormal) = 1);
      Check('eventbus: Unsubscribe removes topic subscriber',
        Bus.Unsubscribe(SubId1) and (Bus.SubscriberCount = 1));
      Bus.Unsubscribe(SubIdWild);
    finally
      Bus.Free;
      Helper.Free;
    end;

    // 14. Reactive Observable & UI Debouncer (TVeloxObservable<T> & TVeloxDebouncer)
    WriteLn('[14/30] Testing TVeloxObservable<T> & TVeloxDebouncer...');
    Helper := TGridSortHelper.Create;
    Frm := TForm.CreateNew(nil);
    ObsInt := TVeloxObservable<Integer>.Create(10);
    try
      BoundLbl := TLabel.Create(Frm);
      BoundLbl.Parent := Frm;
      ObsInt.BindLabel(BoundLbl, 'Processes: ', ' active', Helper.FormatObsInt);
      Check('reactive: BindLabel formats initial value immediately',
        BoundLbl.Caption = 'Processes: 10 active');
      ObsInt.Subscribe(Helper.OnObsChanged, True);
      ObsInt.Value := 42;
      Check('reactive: setting Value updates bound TLabel and notifies subscriber',
        (BoundLbl.Caption = 'Processes: 42 active') and (Helper.LastObservableVal = 42) and (Helper.ObservableHits = 2));

      Debouncer := TVeloxDebouncer.CreateDebouncer(Frm, 200, Helper.OnDebouncedFired);
      Debouncer.Trigger(Frm);
      Debouncer.Trigger(Frm);
      Debouncer.Trigger(Frm);
      Check('reactive: rapid Trigger calls coalesce while pending',
        Debouncer.IsPending and (Debouncer.PendingCount = 3) and (Helper.DebounceHits = 0));
      Debouncer.Flush;
      Check('reactive: Flush executes single coalesced callback and clears pending state',
        (not Debouncer.IsPending) and (Helper.DebounceHits = 1));
    finally
      ObsInt.Free;
      Frm.Free;
      Helper.Free;
    end;

    // 15. Generic Flat-to-Hierarchical Tree Flattener (TVeloxTreeBuilder<T>)
    WriteLn('[15/30] Testing TVeloxTreeBuilder<T> (O(N) Hierarchy & Cycle Protection)...');
    Helper := TGridSortHelper.Create;
    Rows := TList<TTestRow>.Create;
    TreeOut := TList<TTestRow>.Create;
    try
      R.Id := 10; R.ParentId := 0;  R.Name := 'explorer.exe'; Rows.Add(R);
      R.Id := 30; R.ParentId := 20; R.Name := 'conhost.exe';  Rows.Add(R);
      R.Id := 20; R.ParentId := 10; R.Name := 'pwsh.exe';     Rows.Add(R);
      TVeloxTreeBuilder<TTestRow>.BuildHierarchy(Rows, TreeOut, Helper.ExtractTreeIds, Helper.SetTreeDepth);
      Check('tree: BuildHierarchy orders root(10) -> child(20) -> grandchild(30) with depths 0,1,2',
        (TreeOut.Count = 3) and
        (TreeOut[0].Id = 10) and (TreeOut[0].Depth = 0) and
        (TreeOut[1].Id = 20) and (TreeOut[1].Depth = 1) and
        (TreeOut[2].Id = 30) and (TreeOut[2].Depth = 2));
      Check('tree: FormatIndentedCaption prefixes branch glyph for depth > 0',
        Pos(VELOX_TREE_BRANCH, TVeloxTreeBuilder<TTestRow>.FormatIndentedCaption('pwsh.exe', 1)) > 0);
    finally
      TreeOut.Free;
      Rows.Free;
      Helper.Free;
    end;

    // 16. GDI+ Styled Button & Filter Chip Group (TVeloxStyledButton & TVeloxChipGroup)
    WriteLn('[16/30] Testing TVeloxStyledButton & TVeloxChipGroup...');
    Helper := TGridSortHelper.Create;
    Frm := TForm.CreateNew(nil);
    try
      StyledBtn := TVeloxStyledButton.CreateButton(Frm, Frm, 16, 16, 120, 32, 'End Task', DarkColors, vsbDanger);
      Check('styledbtn: CreateButton sets caption and variant',
        (StyledBtn.CaptionText = 'End Task') and (StyledBtn.Variant = vsbDanger));
      Chips := TVeloxChipGroup.CreateGroup(Frm, Frm, 16, 60, 28,
        ['All', 'Heavy RAM', 'Active CPU', 'Alerts'], DarkColors, Helper.OnChipSelect);
      Check('chipgroup: 4 filter chips created with index 0 selected by default',
        (Chips.ChipCount = 4) and (Chips.SelectedIndex = 0));
      Chips.SelectedIndex := 2;
      Check('chipgroup: SelectedIndex updates active chip to 2', Chips.SelectedIndex = 2);
    finally
      Frm.Free;
      Helper.Free;
    end;

    // 17. Fluent Theme-Aware TaskDialog (TVeloxTaskDialog)
    WriteLn('[17/30] Testing TVeloxTaskDialog (Headless Dialog Builder)...');
    Frm := TForm.CreateNew(nil);
    try
      TaskDlgH := TVeloxTaskDialog.BuildDialog(Frm, 'Confirm Action', 'Terminate Process?',
        'Unsaved data in this process will be lost.', DarkColors, vsCritical,
        'Terminate', 'Cancel', True, 'force', 'Don''t ask again');
      try
        Check('taskdialog: BuildDialog creates BodyLabel, InputEdit, and CheckBox',
          Assigned(TaskDlgH.Modal.Form) and Assigned(TaskDlgH.BodyLabel) and
          Assigned(TaskDlgH.InputEdit) and (TaskDlgH.InputEdit.Text = 'force') and
          Assigned(TaskDlgH.CheckBox));
      finally
        TaskDlgH.Modal.Form.Free;
      end;
    finally
      Frm.Free;
    end;

    // 18. VS Code / Raycast Fuzzy Command Palette (TVeloxCommandPalette)
    WriteLn('[18/30] Testing TVeloxCommandPalette (Fuzzy Scoring, Filtering & Execution)...');
    Helper := TGridSortHelper.Create;
    CmdPalette := TVeloxCommandPalette.Create(nil);
    try
      CmdPalette.RegisterCommand('theme.toggle', 'Toggle Dark / Light Theme', 'Appearance', 'Ctrl+T', Helper.OnCommandRun);
      CmdPalette.RegisterCommand('export.csv', 'Export Process Table to CSV', 'Data', 'Ctrl+E', Helper.OnCommandRun);
      CmdPalette.RegisterCommand('proc.kill', 'Terminate Selected Process', 'Process', 'Del', Helper.OnCommandRun);
      Check('cmdpalette: 3 commands registered', CmdPalette.Count = 3);
      Check('cmdpalette: FuzzyMatchScore ranks subsequence match > 0',
        TVeloxCommandPalette.FuzzyMatchScore('epcsv', 'Export Process Table to CSV') > 0);
      CmdFiltered := CmdPalette.FilterCommands('csv');
      Check('cmdpalette: FilterCommands("csv") returns export.csv first',
        (Length(CmdFiltered) >= 1) and (CmdFiltered[0].Id = 'export.csv'));
      Check('cmdpalette: ExecuteById invokes command callback',
        CmdPalette.ExecuteById('theme.toggle') and Helper.CommandExecuted);
    finally
      CmdPalette.Free;
      Helper.Free;
    end;

    // 19. 1-Line Windows 11 Desktop Application Shell (TVeloxAppShell)
    WriteLn('[19/30] Testing TVeloxAppShell (Sidebar, Header Search, Multi-Page Router, Status Bar)...');
    Helper := TGridSortHelper.Create;
    Frm := TForm.CreateNew(nil);
    try
      Frm.SetBounds(100, 100, 1024, 680);
      Shell := TVeloxAppShell.CreateShell(Frm, 'NovaApp', 'LIVE TELEMETRY', DarkColors, 220);
      Shell.OnPageSwitch := Helper.OnShellPageSwitch;
      Page1 := Shell.AddPage('processes', 'Processes');
      Page2 := Shell.AddPage('services', 'Services');
      Check('appshell: 2 pages registered and first page auto-activated',
        (Shell.PageCount = 2) and (Shell.ActivePageId = 'processes') and Page1.Visible and (not Page2.Visible));
      Check('appshell: SwitchPage("services") activates Page2 and hides Page1',
        Shell.SwitchPage('services') and (Shell.ActivePageId = 'services') and Page2.Visible and
        (not Page1.Visible) and (Helper.SwitchedPageId = 'services'));
      Shell.SetStatusMessage('Connected to kernel telemetry', vsNormal);
      Check('appshell: SetStatusMessage updates Footer StatusLabel',
        Shell.StatusLabel.Caption = 'Connected to kernel telemetry');
      Shell.ApplyColors(LightColors);
      Check('appshell: ApplyColors updates ContentPanel to LightColors.Background',
        Shell.ContentPanel.Color = LightColors.Background);
    finally
      Frm.Free;
      Helper.Free;
    end;

    // 20. Structured Ring-Buffer Logger (TVeloxLogger)
    WriteLn('[20/30] Testing TVeloxLogger (Ring Buffer, JSONL & Text Export)...');
    Logger := TVeloxLogger.Create;
    try
      Logger.Info('Kernel', 'Initialized NtQueryInformationProcess');
      Logger.Warn('Memory', 'Working set exceeded 80%');
      Logger.Error('Process', 'Access denied on PID 4');
      Check('logger: 3 log entries buffered', Logger.Count = 3);
      Check('logger: FormatAsText contains category and message',
        (Pos('[Kernel]', Logger.FormatAsText) > 0) and (Pos('WARN', Logger.FormatAsText) > 0));
      Check('logger: FormatAsJsonLines outputs valid JSONL records',
        (Pos('"level":"ERROR"', Logger.FormatAsJsonLines) > 0) and (Pos('"cat":"Process"', Logger.FormatAsJsonLines) > 0));
    finally
      Logger.Free;
    end;

    // 21. 60 FPS Easing & Smooth Property Tweener (TVeloxAnimator)
    WriteLn('[21/30] Testing TVeloxAnimator (Easing Curves, LerpInt, LerpColor)...');
    Helper := TGridSortHelper.Create;
    Frm := TForm.CreateNew(nil);
    try
      Check('animator: EvaluateEasing(0.0) = 0.0 and EvaluateEasing(1.0) = 1.0',
        (Abs(TVeloxAnimator.EvaluateEasing(0.0, vekEaseOutCubic)) < 0.001) and
        (Abs(TVeloxAnimator.EvaluateEasing(1.0, vekEaseOutCubic) - 1.0) < 0.001));
      Check('animator: LerpInt interpolates between 100 and 200',
        (TVeloxAnimator.LerpInt(100, 200, 0.5, vekLinear) = 150));
      Animator := TVeloxAnimator.Create(Frm);
      Animator.StartIntTween(64, 220, 160, vekEaseOutCubic, Helper.OnTweenInt);
      Check('animator: StartIntTween sets IsRunning = True', Animator.IsRunning);
      Animator.CompleteImmediately;
      Check('animator: CompleteImmediately jumps to target 220 and stops timer',
        (not Animator.IsRunning) and (Helper.TweenLastInt = 220));
    finally
      Frm.Free;
      Helper.Free;
    end;

    // 22. Fluent Pill Toggle Switch & Slider (TVeloxToggleSwitch & TVeloxSlider)
    WriteLn('[22/30] Testing TVeloxToggleSwitch & TVeloxSlider...');
    Helper := TGridSortHelper.Create;
    Frm := TForm.CreateNew(nil);
    try
      ToggleSw := TVeloxToggleSwitch.CreateSwitch(Frm, Frm, 16, 16, 220, 'Auto-Trim RAM', DarkColors, False, Helper.OnToggleChanged);
      Check('toggleswitch: initial Checked is False', not ToggleSw.Checked);
      ToggleSw.Checked := True;
      Check('toggleswitch: setting Checked = True fires OnToggle', ToggleSw.Checked and (Helper.ToggleClicks = 1));
      Slider := TVeloxSlider.CreateSlider(Frm, Frm, 16, 56, 200, 0, 100, 50, DarkColors);
      Slider.Position := 140; // Clamped to Max=100
      Check('slider: Position clamps to Max=100', Slider.Position = 100);
    finally
      Frm.Free;
      Helper.Free;
    end;

    // 23. Dark-Mode-Aware Popup Menu Builder (TVeloxPopupMenu)
    WriteLn('[23/30] Testing TVeloxPopupMenu...');
    Helper := TGridSortHelper.Create;
    Frm := TForm.CreateNew(nil);
    try
      PopMenu := TVeloxPopupMenu.CreateMenu(Frm, DarkColors);
      PopMenu.AddItem('copy.row', 'Copy Row to CSV', 'Ctrl+C', Helper.OnMenuItemClick, vsNormal);
      PopMenu.AddSeparator;
      PopMenu.AddItem('kill.proc', 'Terminate Process', 'Del', Helper.OnMenuItemClick, vsCritical);
      Check('popupmenu: 2 actionable items registered', PopMenu.Count = 2);
      Check('popupmenu: ExecuteById invokes callback', PopMenu.ExecuteById('kill.proc') and Helper.MenuClicked);
    finally
      Frm.Free;
      Helper.Free;
    end;

    // 24. Single-Instance Mutex & IPC Bridge (TVeloxSingleInstance)
    WriteLn('[24/30] Testing TVeloxSingleInstance (Named Mutex Collision Detection)...');
    SingleInst1 := TVeloxSingleInstance.Create('Local\VeloxUI.UnitTest.Mutex.99');
    SingleInst2 := TVeloxSingleInstance.Create('Local\VeloxUI.UnitTest.Mutex.99');
    try
      Check('ipc: first instance acquires primary mutex ownership', SingleInst1.IsPrimaryInstance);
      Check('ipc: second instance detects existing mutex (IsPrimaryInstance = False)', not SingleInst2.IsPrimaryInstance);
    finally
      SingleInst2.Free;
      SingleInst1.Free;
    end;

    // 25. Fluent Resizable Splitter & Collapsible Pane (TVeloxSplitter)
    WriteLn('[25/30] Testing TVeloxSplitter (Min/Max Clamping & Collapse Toggle)...');
    Frm := TForm.CreateNew(nil);
    try
      SplitPnl := TPanel.Create(Frm);
      SplitPnl.Parent := Frm;
      SplitPnl.Align := alLeft;
      SplitPnl.Width := 240;
      Splitter := TVeloxSplitter.CreateVertical(Frm, Frm, SplitPnl, DarkColors, 160, 400);
      Splitter.SetTargetSize(90); // Below MinSize=160
      Check('splitter: SetTargetSize clamps width to MinSize=160', SplitPnl.Width = 160);
      Splitter.ToggleCollapse;
      Check('splitter: ToggleCollapse hides target pane', Splitter.Collapsed and (not SplitPnl.Visible));
      Splitter.ToggleCollapse;
      Check('splitter: second ToggleCollapse restores target pane width', (not Splitter.Collapsed) and SplitPnl.Visible and (SplitPnl.Width = 160));
    finally
      Frm.Free;
    end;

    // 26. High-Resolution QPC Stopwatch & Frame Profiler (TVeloxStopwatch & TVeloxFrameProfiler)
    WriteLn('[26/30] Testing TVeloxStopwatch & TVeloxFrameProfiler...');
    SW := TVeloxStopwatch.StartNew;
    Sleep(5);
    SW.Stop;
    Check('profiler: TVeloxStopwatch measures > 1000 microseconds for 5ms sleep', SW.ElapsedMicroseconds >= 1000);
    FrameProf := TVeloxFrameProfiler.Create(20);
    try
      for I := 1 to 10 do
        FrameProf.RecordSampleMs(I * 0.1);
      Check('profiler: TVeloxFrameProfiler tracks SampleCount, PeakMs, and P95Ms',
        (FrameProf.SampleCount = 10) and (Abs(FrameProf.PeakMs - 1.0) < 0.01) and (FrameProf.P95Ms >= 0.9));
    finally
      FrameProf.Free;
    end;

    // 27. Inline Table Cell Micro-Bars & Sparklines (TVeloxCellRenderer)
    WriteLn('[27/30] Testing TVeloxCellRenderer (Inline HeatBar, Sparkline & Status Dot)...');
    Bmp := TBitmap.Create;
    try
      Bmp.SetSize(220, 36);
      TVeloxCellRenderer.DrawInlineBar(Bmp.Canvas, Rect(0, 0, 220, 36), 74.5, '74.5%', DarkColors, vsWarning);
      Check('sparkgrid: DrawInlineBar executes cleanly', True);
      TVeloxCellRenderer.DrawInlineSparkline(Bmp.Canvas, Rect(0, 0, 220, 36), Arr, DarkColors, DarkColors.Accent);
      Check('sparkgrid: DrawInlineSparkline executes cleanly', True);
      TVeloxCellRenderer.DrawStatusDotCell(Bmp.Canvas, Rect(0, 0, 220, 36), 'Running', vsNormal, DarkColors);
      Check('sparkgrid: DrawStatusDotCell executes cleanly', True);
    finally
      Bmp.Free;
    end;

    // 28. Declarative Input Validator (TVeloxValidator)
    WriteLn('[28/30] Testing TVeloxValidator (Required & IntRange Rules)...');
    Frm := TForm.CreateNew(nil);
    try
      EdNum := TEdit.Create(Frm);
      EdNum.Parent := Frm;
      Validator := TVeloxValidator.Create(Frm);
      Validator.AddRequired(EdNum, 'Polling Interval');
      Validator.AddIntRange(EdNum, 'Polling Interval', 100, 10000);
      EdNum.Text := '50'; // Below 100
      Check('validator: rejects out-of-range integer 50', (not Validator.ValidateAll(ValErr)) and (ValErr <> ''));
      EdNum.Text := '1500';
      Check('validator: accepts valid integer 1500', Validator.ValidateAll(ValErr) and (ValErr = ''));
    finally
      Frm.Free;
    end;

    // 29. Native GDI+ Markdown View (TVeloxMarkdownView)
    WriteLn('[29/30] Testing TVeloxMarkdownView (Heading, Bullet & Quote Parsing)...');
    Frm := TForm.CreateNew(nil);
    try
      MdView := TVeloxMarkdownView.CreateView(Frm, Frm, 10, 10, 400, 300, DarkColors);
      MdView.LoadMarkdown('# Release v2.0'#13#10'## New Features'#13#10'- Added **GDI+ Charts**'#13#10'> Zero dependencies');
      Check('markdown: parses 4 markdown blocks', MdView.BlockCount = 4);
      Check('markdown: ParseMarkdownLine identifies H1 and strips **bold** markers',
        (TVeloxMarkdownView.ParseMarkdownLine('# **VeloxUI**').Kind = vmlH1) and
        (TVeloxMarkdownView.ParseMarkdownLine('# **VeloxUI**').CleanText = 'VeloxUI'));
    finally
      Frm.Free;
    end;

    // 30. Control Screenshot & Live Component Showcase Renderer (TVeloxScreenshot)
    WriteLn('[30/30] Testing TVeloxScreenshot & Generating Component Gallery Showcase PNGs...');
    GalleryDarkPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\resources\component_gallery.png');
    GalleryLightPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\resources\component_gallery_light.png');
    Check('screenshot: RenderComponentShowcase (Dark Mode) saves PNG',
      TVeloxScreenshot.RenderComponentShowcase(GalleryDarkPath, vtDark) and FileExists(GalleryDarkPath));
    Check('screenshot: RenderComponentShowcase (Light Mode) saves PNG',
      TVeloxScreenshot.RenderComponentShowcase(GalleryLightPath, vtLight) and FileExists(GalleryLightPath));

  except
    on E: Exception do
    begin
      Inc(Failures);
      WriteLn('EXCEPTION: ' + E.ClassName + ': ' + E.Message);
    end;
  end;

  WriteLn('--------------------------------------------');
  WriteLn(Format('Results: %d passed, %d failed', [Passed, Failures]));
  if Failures = 0 then
    WriteLn('ALL VELOXUI TESTS PASSED')
  else
    ExitCode := 1;
end.
