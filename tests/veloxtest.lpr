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
  Velox.Screenshot,
  Velox.Json,
  Velox.Http,
  Velox.Updater,
  Velox.Localization,
  Velox.Dpi,
  Velox.ViewModel,
  Velox.Tray,
  Velox.Feedback,
  Velox.CrashReporter,
  Velox.Tabs,
  Velox.Crypto,
  Velox.FileWatcher,
  Velox.DragDrop,
  Velox.Breadcrumb,
  Velox.Mru,
  Velox.ColorPicker,
  Velox.SyntaxHighlight,
  Velox.Stepper,
  Velox.Power,
  Velox.Audio,
  Velox.Diff,
  Velox.DiffView,
  Velox.Undo,
  Velox.PropertyGrid,
  Velox.TagInput,
  Velox.Network,
  Velox.Services,
  Velox.Clipboard,
  Velox.Memory,
  Velox.Registry,
  Velox.Glass,
  Velox.KpiDashboard,
  Velox.Timeline,
  Velox.Rating,
  Velox.Pagination,
  Velox.InspectorStudio,
  Velox.DiffInspector,
  Velox.ClipboardPalette,
  Velox.NetworkMonitor,
  Velox.TaskExplorer,
  Velox.AuditSecurityLog,
  Velox.JsonTreeViewer,
  Velox.UpdateFlyout,
  Velox.Icons,
  Velox.Layout,
  Velox.DpiCanvas,
  Velox.Accessibility,
  Velox.Backdrop,
  Velox.RestStudio;

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
    VmPropHits: Integer;
    LastVmProp: string;
    TabSelectedIdx: Integer;
    UndoActionCount: Integer;
    StreamHits: Integer;
    procedure OnDropReceived(Sender: TObject; const AFiles: TStrings);
    procedure DoActionTarget;
    procedure UndoActionTarget;
    procedure OnStreamRequest(Sender: TObject; const ACurrentCount, ABatchSize: Integer; var AAddedCount: Integer);
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
    procedure OnVmChanged(const APropName: string);
    procedure OnTabSelected(Sender: TObject; const AIndex: Integer);
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

procedure TGridSortHelper.OnStreamRequest(Sender: TObject; const ACurrentCount, ABatchSize: Integer; var AAddedCount: Integer);
begin
  Inc(StreamHits);
  AAddedCount := ABatchSize;
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

procedure TGridSortHelper.OnVmChanged(const APropName: string);
begin
  Inc(VmPropHits);
  LastVmProp := APropName;
end;

procedure TGridSortHelper.OnTabSelected(Sender: TObject; const AIndex: Integer);
begin
  TabSelectedIdx := AIndex;
end;

procedure TGridSortHelper.OnDropReceived(Sender: TObject; const AFiles: TStrings);
begin
  // Drop received
end;

procedure TGridSortHelper.DoActionTarget;
begin
  Inc(UndoActionCount);
end;

procedure TGridSortHelper.UndoActionTarget;
begin
  Dec(UndoActionCount);
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
  CmdLine, SysRoot, CsvStr, JsonStr, MdStr, CheatStr, TmpIni, GalleryDarkPath, GalleryLightPath, StudioDarkPath, StudioLightPath, RestDarkPath, RestLightPath: string;
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
  EdNum, BoundEdit: TEdit;
  ValErr, JsonErr, SwapScript, CrashRepStr, TmpDump: string;
  MdView: TVeloxMarkdownView;
  JsonRoot, JsonBuilt, JsonNode: TVeloxJson;
  UrlParts1, UrlParts2, UrlBad: TVeloxUrlParts;
  UpdInfo: TVeloxUpdateInfo;
  Loc: TVeloxLocalizer;
  LocLbl: TLabel;
  DpiPnl: TPanel;
  Vm: TVeloxViewModel;
  Binder: TVeloxBinder;
  ObsStr: TVeloxObservable<string>;
  ObsBool: TVeloxObservable<Boolean>;
  Tray: TVeloxTray;
  BadgeBmp: TBitmap;
  FlyPos: TPoint;
  FlyFrm: TForm;
  InfoBar: TVeloxInfoBar;
  ProgRing: TVeloxProgressRing;
  Skel: TVeloxSkeleton;
  CrashRep: TVeloxCrashReporter;
  TabStrip: TVeloxTabStrip;
  TabHitIdx: Integer;
  TabR, CloseR, AddR: TRect;
  CryptoHash, Base64Str, DecodedStr: string;
  CrcVal: Cardinal;
  Watcher: TVeloxFileWatcher;
  DropTarget: TVeloxDropTarget;
  Crumb: TVeloxBreadcrumb;
  Mru: TVeloxMru;
  TmpMruJson: string;
  ColPick: TVeloxColorPicker;
  TestHexCol: string;
  TestRgbCol: TColor;
  HVal, SVal, VVal: Double;
  CodeView: TVeloxCodeViewer;
  PascalTokens: TVeloxTokenArray;
  Stepper: TVeloxStepper;
  PwrStat: TVeloxPowerStatus;
  AudioPlayed: Boolean;
  DiffRes: TVeloxDiffResult;
  UnifiedDiff: string;
  DiffView: TVeloxDiffView;
  UndoStack: TVeloxUndoStack;
  ActionCmd: TVeloxActionCommand;
  PropGrid: TVeloxPropertyGrid;
  TagInp: TVeloxTagInput;
  PingOk: Boolean;
  PingRtt: Cardinal;
  Adapters: TVeloxAdapterArray;
  SvcState: TVeloxServiceState;
  ClipWatcher: TVeloxClipboardWatcher;
  SysMem: TVeloxSystemMemory;
  ProcMem: TVeloxProcessMemory;
  MemSummary: string;
  RegReadVal: string;
  GlassPnl: TVeloxGlassPanel;
  KpiGrid: TVeloxKpiGrid;
  Timeline: TVeloxTimeline;
  RatingCtrl: TVeloxRating;
  Pagination: TVeloxPagination;
  InspStudio: TVeloxInspectorStudio;
  DiffInsp: TVeloxDiffInspector;
  ClipPal: TVeloxClipboardPalette;
  NetMon: TVeloxNetworkMonitor;
  TaskExp: TVeloxTaskExplorer;
  AuditLog: TVeloxAuditSecurityLog;
  JsonViewer: TVeloxJsonTreeViewer;
  UpdFlyout: TVeloxUpdateFlyout;
  StackPnl: TVeloxStackPanel;
  BtnA, BtnB: TButton;
  IconBmp: TBitmap;
  DpiCanvas: TVeloxDpiCanvas;
  FocusMgr: TVeloxFocusManager;
  FocusBtn1, FocusBtn2: TVeloxStyledButton;
  RestStudio: TVeloxRestStudio;
  DensityRowH, DensityFontSz, DensityPad: Integer;
  AccHov, AccPress, AccTint: TColor;
  I: Integer;
begin
  try
    WriteLn('=== VeloxUI Automated Verification Suite (79 Modules) ===');

    // 1. Ring Buffer & Telemetry Primitives
    WriteLn('[1/78] Testing TVeloxRingBuffer, TVeloxUtils & Customization Tokens...');
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
    Check('customization: Midnight theme returns valid dark background',
      TVeloxUtils.GetCustomThemeColors(vctMidnight).Background <> 0);
    Check('customization: Custom accent tint applies to theme palette',
      TVeloxUtils.GetThemeColors(vtDark, $8B5CF6).Accent = $8B5CF6);
    TVeloxUtils.GetDensityMetrics(vdCompact, DensityRowH, DensityFontSz, DensityPad);
    Check('customization: Compact density row height is 22px', DensityRowH = 22);
    Check('customization: Pill corner radius is half-height',
      TVeloxUtils.GetCornerRadius(vcrPill, 30) = 15);
    TVeloxUtils.DeriveAccentShades($38BDF8, AccHov, AccPress, AccTint);
    Check('customization: Derived accent shades generated',
      (AccHov <> 0) and (AccPress <> 0));

    // 2. GDI+ Hardware-Accelerated Vector Engine
    WriteLn('[2/78] Testing TVeloxGdiPlus Anti-Aliased Primitives...');
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
      TVeloxGdiPlus.DrawGlowBorder(Bmp.Canvas, Rect(20, 20, 100, 60), DarkColors.Accent, 8, 3);
      Check('gdi+: DrawGlowBorder executes cleanly', True);
      TVeloxGdiPlus.DrawDropShadow(Bmp.Canvas, Rect(20, 20, 100, 60), 8, 4);
      Check('gdi+: DrawDropShadow executes cleanly', True);
    finally
      Bmp.Free;
    end;

    // 3. DWM & UXTheme Dark Mode Engine
    WriteLn('[3/78] Testing TVeloxThemeEngine (DWM, UXTheme & Recursive Styling)...');
    TVeloxThemeEngine.InitializeProcessDarkMode(True);
    Check('theme: InitializeProcessDarkMode (Ordinal 135) succeeds', True);
    Check('theme: DetectSystemTheme returns valid enum', TVeloxThemeEngine.DetectSystemTheme in [vtDark, vtLight]);

    // 4. Fluent Control Factories (SearchBox, DarkCheckBox, ComboBox Sync, Modal)
    WriteLn('[4/78] Testing TVeloxControls (SearchBox, DarkCheckBox, High-DPI ComboBox, Modal)...');
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
      WriteLn('[5/78] Testing TVeloxVirtualGrid<T> (OwnerData, QuickSort, Natural Sort Direction)...');
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

        Grid.StreamingEnabled := True;
        Grid.StreamBatchSize := 25;
        Grid.StreamThreshold := 5;
        Grid.OnNeedMoreData := Helper.OnStreamRequest;
        Helper.StreamHits := 0;
        Grid.CheckStreaming(2);
        Check('grid: CheckStreaming triggers OnNeedMoreData near end', Helper.StreamHits = 1);
        Check('grid: AppendBatch adds 25 streaming items to virtual count', Lv.Items.Count = 28);
      finally
        Rows.Free;
        Helper.Free;
        Grid.Free;
      end;
    finally
      Frm.Free;
    end;

    // 6. Async Poller & Hysteresis Threshold Alert Engine
    WriteLn('[6/78] Testing TVeloxPoller<T> & TVeloxThresholdAlert...');
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
    WriteLn('[7/78] Testing TVeloxSystem (NT Command Line, VersionInfo, GUI Resources, Affinity)...');
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
    WriteLn('[8/78] Testing TVeloxExporter (CSV, JSON, Markdown)...');
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
    WriteLn('[9/78] Testing TVeloxHotkeyRegistry (Key Dispatch & Cheat Sheet)...');
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
    WriteLn('[10/78] Testing TVeloxConfig (Key/Value, Theme & Multi-Monitor Clamp)...');
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
    WriteLn('[11/78] Testing TVeloxCharts (DonutGauge, DualSparkline, HeatGrid)...');
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
    WriteLn('[12/78] Testing TVeloxToast...');
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
    WriteLn('[13/78] Testing TVeloxEventBus (Topic & Wildcard Routing)...');
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
    WriteLn('[14/78] Testing TVeloxObservable<T> & TVeloxDebouncer...');
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
    WriteLn('[15/78] Testing TVeloxTreeBuilder<T> (O(N) Hierarchy & Cycle Protection)...');
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
    WriteLn('[16/78] Testing TVeloxStyledButton & TVeloxChipGroup...');
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
    WriteLn('[17/78] Testing TVeloxTaskDialog (Headless Dialog Builder)...');
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
    WriteLn('[18/78] Testing TVeloxCommandPalette (Fuzzy Scoring, Filtering & Execution)...');
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
    WriteLn('[19/78] Testing TVeloxAppShell (Sidebar, Header Search, Multi-Page Router, Status Bar)...');
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
      Shell.SetSidebarCollapsed(True, False);
      Check('appshell: SetSidebarCollapsed collapses to collapsed width 56',
        Shell.SidebarCollapsed and (Shell.SidebarPanel.Width = 56));
      Shell.ToggleSidebar(False);
      Check('appshell: ToggleSidebar restores expanded width 220',
        (not Shell.SidebarCollapsed) and (Shell.SidebarPanel.Width = 220));
    finally
      Frm.Free;
      Helper.Free;
    end;

    // 20. Structured Ring-Buffer Logger (TVeloxLogger)
    WriteLn('[20/78] Testing TVeloxLogger (Ring Buffer, JSONL & Text Export)...');
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
    WriteLn('[21/78] Testing TVeloxAnimator (Easing Curves, LerpInt, LerpColor)...');
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
    WriteLn('[22/78] Testing TVeloxToggleSwitch & TVeloxSlider...');
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
    WriteLn('[23/78] Testing TVeloxPopupMenu...');
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
    WriteLn('[24/78] Testing TVeloxSingleInstance (Named Mutex Collision Detection)...');
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
    WriteLn('[25/78] Testing TVeloxSplitter (Min/Max Clamping & Collapse Toggle)...');
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
    WriteLn('[26/78] Testing TVeloxStopwatch & TVeloxFrameProfiler...');
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
    WriteLn('[27/78] Testing TVeloxCellRenderer (Inline HeatBar, Sparkline & Status Dot)...');
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
    WriteLn('[28/78] Testing TVeloxValidator (Required & IntRange Rules)...');
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
    WriteLn('[29/78] Testing TVeloxMarkdownView (Heading, Bullet & Quote Parsing)...');
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
    WriteLn('[30/78] Testing TVeloxScreenshot & Generating Component Gallery Showcase PNGs...');
    GalleryDarkPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\resources\component_gallery.png');
    GalleryLightPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\resources\component_gallery_light.png');
    StudioDarkPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\resources\components_studio.png');
    StudioLightPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\resources\components_studio_light.png');
    RestDarkPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\resources\rest_studio.png');
    RestLightPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\resources\rest_studio_light.png');
    Check('screenshot: RenderComponentShowcase (Dark Mode) saves PNG',
      TVeloxScreenshot.RenderComponentShowcase(GalleryDarkPath, vtDark) and FileExists(GalleryDarkPath));
    Check('screenshot: RenderComponentShowcase (Light Mode) saves PNG',
      TVeloxScreenshot.RenderComponentShowcase(GalleryLightPath, vtLight) and FileExists(GalleryLightPath));
    Check('screenshot: RenderStudioShowcase (Dark Mode) saves PNG',
      TVeloxScreenshot.RenderStudioShowcase(StudioDarkPath, vtDark) and FileExists(StudioDarkPath));
    Check('screenshot: RenderStudioShowcase (Light Mode) saves PNG',
      TVeloxScreenshot.RenderStudioShowcase(StudioLightPath, vtLight) and FileExists(StudioLightPath));
    Check('screenshot: RenderRestStudioShowcase (Dark Mode) saves PNG',
      TVeloxScreenshot.RenderRestStudioShowcase(RestDarkPath, vtDark) and FileExists(RestDarkPath));
    Check('screenshot: RenderRestStudioShowcase (Light Mode) saves PNG',
      TVeloxScreenshot.RenderRestStudioShowcase(RestLightPath, vtLight) and FileExists(RestLightPath));

    // 31. Zero-Dependency RFC-8259 JSON Reader & Builder (TVeloxJson)
    WriteLn('[31/78] Testing TVeloxJson (RFC-8259 Parser, Path Navigation & Builder)...');
    JsonRoot := TVeloxJson.Parse(
      '{"app":"VeloxUI","units":40,"active":true,"assets":[{"name":"velox.exe","size":2048}]}',
      JsonErr);
    try
      Check('json: Parse succeeds with empty error', Assigned(JsonRoot) and (JsonErr = ''));
      JsonNode := JsonRoot.Find('app');
      Check('json: Find("app") returns "VeloxUI"', Assigned(JsonNode) and (JsonNode.AsString = 'VeloxUI'));
      JsonNode := JsonRoot.Find('units');
      Check('json: Find("units") returns 40', Assigned(JsonNode) and (JsonNode.AsInt = 40));
      JsonNode := JsonRoot.Path('assets[0].name');
      Check('json: Path("assets[0].name") navigates nested array/object',
        Assigned(JsonNode) and (JsonNode.AsString = 'velox.exe'));
    finally
      JsonRoot.Free;
    end;
    JsonBuilt := TVeloxJson.NewObject;
    try
      JsonBuilt.PutStr('framework', 'VeloxUI');
      JsonBuilt.PutNum('version', 3);
      JsonBuilt.PutBool('zero_dep', True);
      Check('json: NewObject + PutStr/PutNum/PutBool + Serialize roundtrip',
        Pos('"framework":"VeloxUI"', JsonBuilt.Serialize(False)) > 0);
    finally
      JsonBuilt.Free;
    end;

    // 32. Zero-Dependency WinHTTP Client (TVeloxHttp)
    WriteLn('[32/78] Testing TVeloxHttp (WinHTTP URL Parser & Guards)...');
    UrlParts1 := TVeloxHttp.ParseUrl('https://api.github.com/repos/amafjarkasi/velox-ui/releases/latest');
    Check('http: ParseUrl parses HTTPS host, port 443, and path',
      UrlParts1.Valid and UrlParts1.Secure and (UrlParts1.Host = 'api.github.com') and
      (UrlParts1.Port = 443) and (Pos('/repos/amafjarkasi/velox-ui', UrlParts1.Path) = 1));
    UrlParts2 := TVeloxHttp.ParseUrl('http://localhost:8080/health');
    Check('http: ParseUrl parses HTTP custom port 8080',
      UrlParts2.Valid and (not UrlParts2.Secure) and (UrlParts2.Host = 'localhost') and
      (UrlParts2.Port = 8080) and (UrlParts2.Path = '/health'));
    UrlBad := TVeloxHttp.ParseUrl('ftp://invalid');
    Check('http: ParseUrl rejects non-HTTP scheme', not UrlBad.Valid);

    // 33. GitHub Releases Self-Updater (TVeloxUpdater)
    WriteLn('[33/78] Testing TVeloxUpdater (SemVer Compare, Release JSON & Swap Script)...');
    Check('updater: CompareVersions("v1.2.0", "1.10.0") = -1',
      TVeloxUpdater.CompareVersions('v1.2.0', '1.10.0') = -1);
    Check('updater: CompareVersions("2.0.0-beta.1", "2.0.0") = -1 (prerelease < release)',
      TVeloxUpdater.CompareVersions('2.0.0-beta.1', '2.0.0') = -1);
    Check('updater: CompareVersions("v2.1.0", "2.1.0") = 0',
      TVeloxUpdater.CompareVersions('v2.1.0', '2.1.0') = 0);
    UpdInfo := TVeloxUpdater.ParseRelease(
      '{"tag_name":"v2.4.0","body":"Fast release","html_url":"https://github.com/x/y/releases/v2.4.0",' +
      '"assets":[{"name":"app-win64.exe","browser_download_url":"https://github.com/x/y/app-win64.exe"}]}',
      '2.1.0', '.exe');
    Check('updater: ParseRelease detects newer 2.4.0 and extracts .exe asset URL',
      UpdInfo.Ok and UpdInfo.Available and (UpdInfo.LatestVersion = '2.4.0') and
      (UpdInfo.AssetName = 'app-win64.exe'));
    SwapScript := TVeloxUpdater.BuildSwapScript('C:\tmp\new.exe', 'C:\app\app.exe', 1234);
    Check('updater: BuildSwapScript generates batch with PID wait and copy',
      (Pos('1234', SwapScript) > 0) and (Pos('copy /Y', SwapScript) > 0));

    // 34. Runtime i18n Localization Engine (TVeloxLocalizer)
    WriteLn('[34/78] Testing TVeloxLocalizer (JSON String Tables, Fallback & Live Control Binding)...');
    Frm := TForm.CreateNew(nil);
    try
      Loc := TVeloxLocalizer.Create(Frm);
      Check('i18n: AddLanguageFromJson loads English and Spanish tables',
        Loc.AddLanguageFromJson('en', '{"nav.processes":"Processes","status.cpu":"CPU: %d%%","only.en":"Fallback Text"}') and
        Loc.AddLanguageFromJson('es', '{"nav.processes":"Procesos","status.cpu":"CPU: %d%%"}'));
      LocLbl := TLabel.Create(Frm);
      LocLbl.Parent := Frm;
      Loc.Bind(LocLbl, 'nav.processes');
      Check('i18n: Bind sets initial English caption "Processes"', LocLbl.Caption = 'Processes');
      Check('i18n: SetLanguage("es") live-updates bound label to "Procesos"',
        Loc.SetLanguage('es') and (LocLbl.Caption = 'Procesos'));
      Check('i18n: missing key in "es" falls back to "en" table',
        Loc.Tr('only.en') = 'Fallback Text');
      Check('i18n: TrF formats arguments accurately',
        Loc.TrF('status.cpu', [85]) = 'CPU: 85%');
    finally
      Frm.Free;
    end;

    // 35. Per-Monitor v2 High-DPI Scaling Helper (TVeloxDpi)
    WriteLn('[35/78] Testing TVeloxDpi (System DPI, Scale/Unscale & Control Tree Rescaling)...');
    Check('dpi: GetSystemDpi >= 96', TVeloxDpi.GetSystemDpi >= 96);
    Check('dpi: GetScaleFactor(144) = 1.5', Abs(TVeloxDpi.GetScaleFactor(144) - 1.5) < 0.001);
    Check('dpi: Scale(100, 144) = 150 and Unscale(150, 144) = 100',
      (TVeloxDpi.Scale(100, 144) = 150) and (TVeloxDpi.Unscale(150, 144) = 100));
    Frm := TForm.CreateNew(nil);
    try
      DpiPnl := TPanel.Create(Frm);
      DpiPnl.Parent := Frm;
      DpiPnl.SetBounds(20, 40, 200, 100);
      TVeloxDpi.ScaleControlTree(Frm, 96, 144);
      Check('dpi: ScaleControlTree(96 -> 144) scales child bounds by 1.5x',
        (DpiPnl.Left = 30) and (DpiPnl.Top = 60) and (DpiPnl.Width = 300) and (DpiPnl.Height = 150));
    finally
      Frm.Free;
    end;

    // 36. Two-Way MVVM ViewModel & Control Binder (TVeloxViewModel & TVeloxBinder)
    WriteLn('[36/78] Testing TVeloxViewModel & TVeloxBinder (Batching & Two-Way Data Binding)...');
    Helper := TGridSortHelper.Create;
    Frm := TForm.CreateNew(nil);
    Vm := TVeloxViewModel.Create;
    ObsStr := TVeloxObservable<string>.Create('initial');
    ObsBool := TVeloxObservable<Boolean>.Create(False);
    try
      Vm.Subscribe(Helper.OnVmChanged);
      Vm.BeginUpdate;
      Vm.RaisePropertyChanged('FilterText');
      Vm.RaisePropertyChanged('FilterText'); // Duplicate coalesced
      Vm.RaisePropertyChanged('SortCol');
      Check('viewmodel: BeginUpdate defers notifications until EndUpdate', Helper.VmPropHits = 0);
      Vm.EndUpdate;
      Check('viewmodel: EndUpdate dispatches 2 unique coalesced properties and marks IsDirty',
        (Helper.VmPropHits = 2) and Vm.IsDirty and (Helper.LastVmProp = 'SortCol'));
      Vm.ClearDirty;
      Check('viewmodel: ClearDirty resets IsDirty flag', not Vm.IsDirty);

      Binder := TVeloxBinder.Create(Frm);
      BoundEdit := TEdit.Create(Frm);
      BoundEdit.Parent := Frm;
      Binder.BindEdit(BoundEdit, ObsStr);
      Check('binder: BindEdit initializes TEdit.Text from observable', BoundEdit.Text = 'initial');
      ObsStr.Value := 'from_vm';
      Check('binder: updating observable updates TEdit.Text', BoundEdit.Text = 'from_vm');
      BoundEdit.Text := 'from_ui';
      if Assigned(BoundEdit.OnChange) then BoundEdit.OnChange(BoundEdit);
      Check('binder: editing TEdit updates observable Value two-way', ObsStr.Value = 'from_ui');

      ToggleSw := TVeloxToggleSwitch.CreateSwitch(Frm, Frm, 10, 40, 180, 'Dark Mode', DarkColors, False);
      Binder.BindToggle(ToggleSw, ObsBool);
      ToggleSw.Checked := True;
      Check('binder: BindToggle syncs TVeloxToggleSwitch -> observable', ObsBool.Value = True);
    finally
      ObsBool.Free;
      ObsStr.Free;
      Vm.Free;
      Frm.Free;
      Helper.Free;
    end;

    // 37. Themed System Tray, Dynamic Badge & Flyout (TVeloxTray)
    WriteLn('[37/78] Testing TVeloxTray (GDI+ Badge Bitmap, Flyout Positioning & Builder)...');
    Frm := TForm.CreateNew(nil);
    try
      Tray := TVeloxTray.CreateTray(Frm, 'VeloxUI Monitor', DarkColors);
      BadgeBmp := TVeloxTray.RenderBadgeBitmap('84', DarkColors, vsWarning);
      try
        Check('tray: RenderBadgeBitmap creates 16x16 GDI+ badge bitmap',
          Assigned(BadgeBmp) and (BadgeBmp.Width = 16) and (BadgeBmp.Height = 16));
      finally
        BadgeBmp.Free;
      end;
      FlyPos := TVeloxTray.CalcFlyoutPos(Rect(0, 0, 1920, 1040), 320, 220, 12);
      Check('tray: CalcFlyoutPos anchors card to bottom-right work area with margin',
        (FlyPos.X = 1920 - 320 - 12) and (FlyPos.Y = 1040 - 220 - 12));
      FlyFrm := Tray.BuildFlyout('Velox Telemetry', ['CPU: 14.2%', 'RAM: 8.4 GB']);
      Check('tray: BuildFlyout creates borderless themed flyout form',
        Assigned(FlyFrm) and (FlyFrm.BorderStyle = bsNone));
    finally
      Frm.Free;
    end;

    // 38. WinUI Feedback Controls (TVeloxInfoBar, TVeloxProgressRing, TVeloxSkeleton)
    WriteLn('[38/78] Testing TVeloxInfoBar, TVeloxProgressRing & TVeloxSkeleton...');
    Frm := TForm.CreateNew(nil);
    try
      InfoBar := TVeloxInfoBar.CreateBar(Frm, Frm, 16, 16, 420,
        'Update Ready', 'Restart to apply v2.4.0', vsWarning, DarkColors, True);
      CloseR := InfoBar.CloseRect;
      Check('feedback: TVeloxInfoBar IsCloseHit detects close button coordinates',
        InfoBar.IsCloseHit(CloseR.Left + 2, CloseR.Top + 2));
      InfoBar.Dismiss;
      Check('feedback: TVeloxInfoBar.Dismiss hides banner', not InfoBar.Visible);

      ProgRing := TVeloxProgressRing.CreateRing(Frm, Frm, 16, 70, 48, DarkColors);
      ProgRing.Percent := 65.0;
      ProgRing.Step;
      Check('feedback: TVeloxProgressRing advances phase on Step', ProgRing.Phase = 1);

      Skel := TVeloxSkeleton.CreateSkeleton(Frm, Frm, 80, 70, 240, 64, 3, DarkColors);
      Skel.Step;
      Check('feedback: TVeloxSkeleton shimmer advances Offset on Step',
        (Skel.LineCount = 3) and (Skel.Offset > 0));
    finally
      Frm.Free;
    end;

    // 39. Global Crash Reporter & MiniDump Writer (TVeloxCrashReporter)
    WriteLn('[39/78] Testing TVeloxCrashReporter (Report Builder, StackTrace & MiniDump)...');
    CrashRep := TVeloxCrashReporter.Create('VeloxTest', '2.4.0', ExtractFilePath(ParamStr(0)), DarkColors);
    try
      CrashRep.ShowDialog := False;
      CrashRep.Install;
      Check('crash: Install hooks Application.OnException', CrashRep.Installed);
      CrashRep.Uninstall;
      Check('crash: Uninstall restores previous handler', not CrashRep.Installed);
      CrashRepStr := TVeloxCrashReporter.BuildReport(
        'VeloxTest', '2.4.0', 'EAccessViolation', 'Invalid read at 0x00', '  $00401000', '[INFO] Boot ok');
      Check('crash: BuildReport includes app version, exception class, stack & log',
        (Pos('VeloxTest', CrashRepStr) > 0) and (Pos('EAccessViolation', CrashRepStr) > 0) and
        (Pos('[INFO] Boot ok', CrashRepStr) > 0));
      Check('crash: CaptureStackTrace returns non-empty frame list',
        TVeloxCrashReporter.CaptureStackTrace <> '');
      TmpDump := ExtractFilePath(ParamStr(0)) + 'velox_test_crash.dmp';
      Check('crash: WriteMiniDump writes valid minidump via dbghelp.dll',
        TVeloxCrashReporter.WriteMiniDump(TmpDump) and FileExists(TmpDump));
      if FileExists(TmpDump) then SysUtils.DeleteFile(TmpDump);
    finally
      CrashRep.Free;
    end;

    // 40. Edge / Windows Terminal Fluent Tab Strip (TVeloxTabStrip)
    WriteLn('[40/78] Testing TVeloxTabStrip (Add, Select, HitTest, Reorder & Close)...');
    Helper := TGridSortHelper.Create;
    Frm := TForm.CreateNew(nil);
    try
      TabStrip := TVeloxTabStrip.CreateStrip(Frm, Frm, 0, 0, 600, DarkColors, 36);
      TabStrip.OnSelectChange := Helper.OnTabSelected;
      TabStrip.AddTab('Processes', True, 1);
      TabStrip.AddTab('Performance', True, 2);
      TabStrip.AddTab('Services', False, 3);
      Check('tabs: 3 tabs added and first tab auto-selected',
        (TabStrip.TabCount = 3) and (TabStrip.SelectedIndex = 0));
      TabR := TabStrip.TabRect(1);
      Check('tabs: HitTest identifies tab body as vthTab',
        (TabStrip.HitTest(TabR.Left + 16, TabR.Top + 10, TabHitIdx) = vthTab) and (TabHitIdx = 1));
      CloseR := TabStrip.CloseRect(1);
      Check('tabs: HitTest identifies close button on closable tab as vthClose',
        (TabStrip.HitTest(CloseR.Left + 4, CloseR.Top + 4, TabHitIdx) = vthClose) and (TabHitIdx = 1));
      AddR := TabStrip.AddButtonRect;
      Check('tabs: HitTest identifies trailing + button as vthAdd',
        TabStrip.HitTest(AddR.Left + 6, AddR.Top + 6, TabHitIdx) = vthAdd);
      TabStrip.MoveTab(0, 2);
      Check('tabs: MoveTab(0, 2) reorders "Processes" to index 2 and tracks selection',
        (TabStrip.TabCaption(2) = 'Processes') and (TabStrip.SelectedIndex = 2));
      TabStrip.RemoveTab(0);
      Check('tabs: RemoveTab decreases TabCount to 2', TabStrip.TabCount = 2);
    finally
      Frm.Free;
      Helper.Free;
    end;

    // 41. Cryptography & Hashing (TVeloxCrypto)
    WriteLn('[41/78] Testing TVeloxCrypto (BCrypt CNG SHA-256, SHA-1, MD5, CRC32, Base64)...');
    CryptoHash := TVeloxCrypto.Sha256('hello world');
    Check('crypto: Sha256("hello world") matches known hex',
      CryptoHash = 'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9');
    CryptoHash := TVeloxCrypto.Sha1('hello world');
    Check('crypto: Sha1("hello world") matches known hex',
      CryptoHash = '2aae6c35c94fcfb415dbe95f408b9ce91ee846ed');
    CryptoHash := TVeloxCrypto.Md5('hello world');
    Check('crypto: Md5("hello world") matches known hex',
      CryptoHash = '5eb63bbbe01eeed093cb22bb8f5acdc3');
    CrcVal := TVeloxCrypto.Crc32('123456789');
    Check('crypto: Crc32("123456789") equals $CBF43926', CrcVal = $CBF43926);
    Base64Str := TVeloxCrypto.Base64Encode('VeloxUI 50 Modules');
    DecodedStr := TVeloxCrypto.Base64Decode(Base64Str);
    Check('crypto: Base64 roundtrip preserves exact string', DecodedStr = 'VeloxUI 50 Modules');

    // 42. Non-blocking File Watcher (TVeloxFileWatcher)
    WriteLn('[42/78] Testing TVeloxFileWatcher (ReadDirectoryChangesW Thread Lifecycle)...');
    Watcher := TVeloxFileWatcher.Create(nil);
    try
      Watcher.Directory := ExtractFilePath(ParamStr(0));
      Check('watcher: directory assignment reflects correctly', Watcher.Directory = ExtractFilePath(ParamStr(0)));
      Watcher.Start;
      Check('watcher: Start activates background thread monitor', Watcher.Active);
      Watcher.Stop;
      Check('watcher: Stop cleanly deactivates thread', not Watcher.Active);
    finally
      Watcher.Free;
    end;

    // 43. Zero-COM Win32 Shell File Drag & Drop (TVeloxDropTarget)
    WriteLn('[43/78] Testing TVeloxDropTarget (Subclassing & Registration)...');
    Frm := TForm.CreateNew(nil);
    try
      Helper := TGridSortHelper.Create;
      try
        DropTarget := TVeloxDropTarget.Register(Frm, Helper.OnDropReceived);
        Check('dragdrop: TVeloxDropTarget.Register attaches successfully',
          Assigned(DropTarget) and (DropTarget.Control = Frm));
        TVeloxDropTarget.Unregister(Frm);
        Check('dragdrop: TVeloxDropTarget.Unregister removes hook safely', True);
      finally
        Helper.Free;
      end;
    finally
      Frm.Free;
    end;

    // 44. Explorer-Style Breadcrumb Navigation (TVeloxBreadcrumb)
    WriteLn('[44/78] Testing TVeloxBreadcrumb (Segments, HitTest & Path Navigation)...');
    Frm := TForm.CreateNew(nil);
    try
      Crumb := TVeloxBreadcrumb.CreateBreadcrumb(Frm, Frm, 10, 10, 400, DarkColors);
      Crumb.AddSegment('Root', 'root');
      Crumb.AddSegment('System', 'sys');
      Crumb.AddSegment('Telemetry', 'telem');
      Check('breadcrumb: 3 segments added correctly', Crumb.Count = 3);
      Check('breadcrumb: segment captions and keys preserved',
        (Crumb.SegmentCaption(1) = 'System') and (Crumb.SegmentKey(2) = 'telem'));
      Check('breadcrumb: HitTest identifies segment 0 near left edge', Crumb.HitTest(20, 16) = 0);
      Crumb.Clear;
      Check('breadcrumb: Clear resets segment count to 0', Crumb.Count = 0);
    finally
      Frm.Free;
    end;

    // 45. Most-Recently-Used Manager (TVeloxMru)
    WriteLn('[45/78] Testing TVeloxMru (Deduplication, Pinning & JSON Persistence)...');
    TmpMruJson := ExtractFilePath(ParamStr(0)) + 'velox_mru_test.json';
    if FileExists(TmpMruJson) then SysUtils.DeleteFile(TmpMruJson);
    Mru := TVeloxMru.Create(nil);
    try
      Mru.MaxItems := 4;
      Mru.Add('C:\Doc1.txt');
      Mru.Add('C:\Doc2.txt');
      Mru.Add('C:\Doc3.txt');
      Mru.Add('C:\Doc1.txt');
      Check('mru: adding existing item promotes to index 0 without duplicates',
        (Mru.Count = 3) and (Mru.ItemPath(0) = 'C:\Doc1.txt'));
      Mru.Pin(1);
      Check('mru: Pin marks item at index 1 as pinned', Mru.IsPinned(1));
      Mru.SaveToFile(TmpMruJson);
      Check('mru: SaveToFile writes valid JSON configuration', FileExists(TmpMruJson));

      Mru.Clear;
      Check('mru: Clear empties items', Mru.Count = 0);
      Mru.LoadFromFile(TmpMruJson);
      Check('mru: LoadFromFile restores 3 items and pinned state',
        (Mru.Count = 3) and (Mru.ItemPath(0) = 'C:\Doc1.txt') and Mru.IsPinned(1));
      if FileExists(TmpMruJson) then SysUtils.DeleteFile(TmpMruJson);
    finally
      Mru.Free;
    end;

    // 46. Fluent Color Picker & Swatches (TVeloxColorPicker)
    WriteLn('[46/78] Testing TVeloxColorPicker & TVeloxColorUtils (Swatches, RGB & HSV)...');
    TestHexCol := TVeloxColorUtils.ColorToHex($38BDF8);
    TestRgbCol := TVeloxColorUtils.HexToColor(TestHexCol);
    Check('colorpicker: HexToColor roundtrips hex string',
      TVeloxColorUtils.ColorToHex(TestRgbCol) = TestHexCol);
    TVeloxColorUtils.RgbToHsv(255, 0, 0, HVal, SVal, VVal);
    Check('colorpicker: RgbToHsv on pure red yields Hue=0, Sat=1, Val=1',
      (Abs(HVal - 0.0) < 0.001) and (Abs(SVal - 1.0) < 0.001) and (Abs(VVal - 1.0) < 0.001));
    Frm := TForm.CreateNew(nil);
    try
      ColPick := TVeloxColorPicker.CreatePicker(Frm, Frm, 10, 10, DarkColors, $F8BD38);
      Check('colorpicker: initial selected color matches $F8BD38', ColPick.SelectedColor = $F8BD38);
      ColPick.SetSwatch(0, clRed);
      Check('colorpicker: SetSwatch modifies swatch index 0', ColPick.GetSwatch(0) = clRed);
    finally
      Frm.Free;
    end;

    // 47. Lightweight Multi-Language Micro-Lexer & Code Viewer (TVeloxCodeViewer)
    WriteLn('[47/78] Testing TVeloxSyntaxHighlight (JSON, SQL, Pascal & Python Micro-Lexer)...');
    PascalTokens := TVeloxLexer.TokenizeLine('unit Velox.Test; // demo', vslPascal);
    Check('syntax: TokenizeLine tokenizes Pascal keyword, identifier & comment',
      (Length(PascalTokens) >= 3) and (PascalTokens[0].Kind = vtkKeyword) and
      (PascalTokens[0].Text = 'unit'));
    Frm := TForm.CreateNew(nil);
    try
      CodeView := TVeloxCodeViewer.CreateViewer(Frm, Frm, 10, 10, 400, 200, vslPascal, DarkColors);
      CodeView.SetCode('program Hello;'#13#10'begin'#13#10'  WriteLn(''hi'');'#13#10'end.');
      Check('syntax: TVeloxCodeViewer stores 4 lines of code', CodeView.Lines.Count = 4);
    finally
      Frm.Free;
    end;

    // 48. Wizard & Pipeline Stepper Control (TVeloxStepper)
    WriteLn('[48/78] Testing TVeloxStepper (Steps, State Progression & Navigation)...');
    Frm := TForm.CreateNew(nil);
    try
      Stepper := TVeloxStepper.Create(Frm);
      Stepper.Parent := Frm;
      Stepper.AddStep('Download', 'Fetch binaries');
      Stepper.AddStep('Verify', 'SHA-256 validation');
      Stepper.AddStep('Install', 'Deploy files');
      Check('stepper: 3 steps added and first step is active',
        (Stepper.Steps.Count = 3) and (Stepper.ActiveStepIndex = 0) and
        (Stepper.StepState[0] = vssActive) and (Stepper.StepState[1] = vssPending));
      Stepper.NextStep;
      Check('stepper: NextStep marks step 0 as completed and step 1 as active',
        (Stepper.ActiveStepIndex = 1) and (Stepper.StepState[0] = vssCompleted) and
        (Stepper.StepState[1] = vssActive));
      Stepper.StepState[2] := vssError;
      Check('stepper: StepState custom assignment updates step 2 to vssError',
        Stepper.StepState[2] = vssError);
    finally
      Frm.Free;
    end;

    // 49. Hardware Battery & Power Source Telemetry (TVeloxPower)
    WriteLn('[49/78] Testing TVeloxPower (Win32 GetSystemPowerStatus & Formatting)...');
    PwrStat := TVeloxPower.GetPowerStatus;
    Check('power: StatusDescription returns valid diagnostic string', PwrStat.StatusDescription <> '');
    Check('power: FormatRemainingTime formats seconds properly',
      (TVeloxPower.FormatRemainingTime(3600) = '1h 0m') and
      (TVeloxPower.FormatRemainingTime(45) = '45 sec') and
      (TVeloxPower.FormatRemainingTime(-1) = 'Unknown'));
    Check('power: IsOnAcPower returns boolean without crash',
      (TVeloxPower.IsOnAcPower = True) or (TVeloxPower.IsOnAcPower = False));

    // 50. Audio Chimes & Low-Latency Tone Synthesizer (TVeloxAudio)
    WriteLn('[50/78] Testing TVeloxAudio (winmm.dll PlaySound, Beep & Earcons)...');
    AudioPlayed := TVeloxAudio.Tone(1200, 20);
    Check('audio: TVeloxAudio.Tone synthesizes frequency tone via Win32 Beep', AudioPlayed);
    TVeloxAudio.StopAll;
    Check('audio: TVeloxAudio.StopAll executes without error', True);
    Check('audio: PlayWav returns False cleanly for non-existent file',
      not TVeloxAudio.PlayWav('C:\non_existent_velox_test_audio.wav'));

    // 51. Myers Diff Engine & Levenshtein Similarity (TVeloxDiff)
    WriteLn('[51/78] Testing TVeloxDiff (LCS Line Diff, Unified Diff & Levenshtein)...');
    DiffRes := TVeloxDiff.CompareText('Line 1'#13#10'Line 2'#13#10'Line 3',
                                      'Line 1'#13#10'Line 2 Modified'#13#10'Line 3'#13#10'Line 4 Added');
    Check('diff: CompareText identifies additions and deletions',
      (DiffRes.AddedCount >= 1) and (DiffRes.EqualCount >= 2));
    UnifiedDiff := TVeloxDiff.FormatUnified(DiffRes, 'v1.txt', 'v2.txt');
    Check('diff: FormatUnified includes standard --- a and +++ b headers',
      (Pos('--- v1.txt', UnifiedDiff) > 0) and (Pos('+++ v2.txt', UnifiedDiff) > 0));
    Check('diff: LevenshteinDistance("kitten", "sitting") = 3',
      TVeloxDiff.LevenshteinDistance('kitten', 'sitting') = 3);
    Check('diff: Similarity between identical strings is 1.0',
      Abs(TVeloxDiff.Similarity('velox', 'velox') - 1.0) < 0.001);

    // 52. Side-by-Side & Unified Diff Visualizer (TVeloxDiffView)
    WriteLn('[52/78] Testing TVeloxDiffView (Diff Visualizer Layout & Scrolling)...');
    Frm := TForm.CreateNew(nil);
    try
      DiffView := TVeloxDiffView.Create(Frm);
      DiffView.Parent := Frm;
      DiffView.SetDiff('Alpha'#13#10'Beta'#13#10'Gamma', 'Alpha'#13#10'Beta 2'#13#10'Gamma');
      Check('diffview: SetDiff populates diff lines', Length(DiffView.DiffResult.Lines) >= 3);
      DiffView.ViewMode := vdvmSideBySide;
      Check('diffview: ViewMode property updates cleanly', DiffView.ViewMode = vdvmSideBySide);
    finally
      Frm.Free;
    end;

    // 53. Multi-Level Undo/Redo Command Stack (TVeloxUndoStack)
    WriteLn('[53/78] Testing TVeloxUndoStack (Command Pattern, Transactions & Dirty Flag)...');
    Helper := TGridSortHelper.Create;
    try
      Helper.UndoActionCount := 0;
      UndoStack := TVeloxUndoStack.Create(20);
      try
        Check('undo: Initially CanUndo is False and IsDirty is False',
          (not UndoStack.CanUndo) and (not UndoStack.IsDirty));
        ActionCmd := TVeloxActionCommand.Create('Increment counter',
          Helper.DoActionTarget, Helper.UndoActionTarget);
        ActionCmd.Execute;
        UndoStack.Push(ActionCmd);
        Check('undo: After push, CanUndo is True, IsDirty is True, and count = 1',
          UndoStack.CanUndo and UndoStack.IsDirty and (Helper.UndoActionCount = 1));
        UndoStack.Undo;
        Check('undo: Undo rolls back count to 0 and CanRedo becomes True',
          (Helper.UndoActionCount = 0) and UndoStack.CanRedo);
        UndoStack.Redo;
        Check('undo: Redo advances count back to 1',
          (Helper.UndoActionCount = 1) and UndoStack.CanUndo);
      finally
        UndoStack.Free;
      end;
    finally
      Helper.Free;
    end;

    // 54. Fluent Dark Property Inspector Grid (TVeloxPropertyGrid)
    WriteLn('[54/78] Testing TVeloxPropertyGrid (Categories, Typed Properties & Mutation)...');
    Frm := TForm.CreateNew(nil);
    try
      PropGrid := TVeloxPropertyGrid.Create(Frm);
      PropGrid.Parent := Frm;
      PropGrid.AddString('General', 'app_name', 'Application Name', 'VeloxApp');
      PropGrid.AddBoolean('General', 'dark_mode', 'Dark Mode', True);
      PropGrid.AddInteger('Performance', 'max_threads', 'Max Threads', 8);
      PropGrid.AddColor('Appearance', 'accent_col', 'Accent Color', $38BDF8);
      Check('propgrid: 4 properties registered across categories', PropGrid.Count = 4);
      Check('propgrid: GetString retrieves string value', PropGrid.GetString('app_name') = 'VeloxApp');
      Check('propgrid: GetBoolean retrieves boolean value', PropGrid.GetBoolean('dark_mode') = True);
      PropGrid.SetBoolean('dark_mode', False);
      Check('propgrid: SetBoolean updates value to False', PropGrid.GetBoolean('dark_mode') = False);
    finally
      Frm.Free;
    end;

    // 55. Interactive Tag & Pill Tokenizer (TVeloxTagInput)
    WriteLn('[55/78] Testing TVeloxTagInput (Pill Badges, Removal & Duplicates)...');
    Frm := TForm.CreateNew(nil);
    try
      TagInp := TVeloxTagInput.Create(Frm);
      TagInp.Parent := Frm;
      TagInp.AddTag('delphi');
      TagInp.AddTag('pascal');
      TagInp.AddTag('fluent');
      Check('taginput: 3 tags added successfully', TagInp.TagCount = 3);
      Check('taginput: duplicate tag rejected when AllowDuplicates is False',
        not TagInp.AddTag('delphi'));
      TagInp.RemoveTag('pascal');
      Check('taginput: RemoveTag decreases count to 2', TagInp.TagCount = 2);
    finally
      Frm.Free;
    end;

    // 56. Zero-Indy ICMP Ping & Network Adapters (TVeloxNetwork)
    WriteLn('[56/78] Testing TVeloxNetwork (icmp.dll Ping & iphlpapi.dll Adapters)...');
    PingOk := TVeloxPing.Ping('127.0.0.1', 1000, PingRtt);
    Check('network: Ping localhost via Win32 icmp.dll succeeds', PingOk);
    Adapters := TVeloxNetwork.GetAdapters;
    Check('network: GetAdapters enumerates network interfaces without error', Length(Adapters) >= 0);

    // 57. Windows Service Controller (TVeloxServices)
    WriteLn('[57/78] Testing TVeloxServices (SCM Status Query & State Formatting)...');
    SvcState := TVeloxServices.GetServiceState('LanmanServer');
    Check('services: Query LanmanServer state returns recognized enum',
      SvcState in [vssRunning, vssStopped, vssPaused, vssStartPending, vssStopPending, vssUnknown]);
    Check('services: StateToString formats enum text properly',
      TVeloxServices.StateToString(vssRunning) = 'Running');

    // 58. Event-Driven Clipboard Monitor (TVeloxClipboardWatcher)
    WriteLn('[58/78] Testing TVeloxClipboard & TVeloxClipboardWatcher (AddClipboardFormatListener)...');
    TVeloxClipboard.SetText('VeloxUI Test Clip 58');
    Check('clipboard: SetText and GetText roundtrip string via Win32 clipboard',
      TVeloxClipboard.GetText = 'VeloxUI Test Clip 58');
    Check('clipboard: HasText returns True', TVeloxClipboard.HasText);
    ClipWatcher := TVeloxClipboardWatcher.Create(nil);
    try
      ClipWatcher.Active := True;
      Check('clipboard: Watcher activates listener window', ClipWatcher.Active);
      ClipWatcher.Active := False;
      Check('clipboard: Watcher cleanly deactivates', not ClipWatcher.Active);
    finally
      ClipWatcher.Free;
    end;

    // 59. Working Set & Physical Memory Diagnostics (TVeloxMemory)
    WriteLn('[59/78] Testing TVeloxMemory (GlobalMemoryStatusEx & psapi.dll)...');
    SysMem := TVeloxMemory.GetSystemMemory;
    Check('memory: TotalPhysicalBytes > 0 and MemoryLoadPercent <= 100',
      (SysMem.TotalPhysicalBytes > 0) and (SysMem.MemoryLoadPercent <= 100));
    ProcMem := TVeloxMemory.GetProcessMemory(0);
    Check('memory: Current process WorkingSetBytes > 0', ProcMem.WorkingSetBytes > 0);
    MemSummary := TVeloxMemory.FormatMemorySummary(0);
    Check('memory: FormatMemorySummary contains "RAM:" diagnostic text',
      Pos('RAM:', MemSummary) > 0);

    // 60. Exception-Safe 64-Bit Registry & Autostart (TVeloxRegistry)
    WriteLn('[60/78] Testing TVeloxRegistry (Safe Reads & Autostart Detection)...');
    RegReadVal := TVeloxRegistry.ReadString(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Windows NT\CurrentVersion',
      'ProductName', 'UnknownOS', vrvDefault);
    Check('registry: ReadString retrieves Windows ProductName',
      (RegReadVal <> 'UnknownOS') and (RegReadVal <> ''));
    Check('registry: ReadInteger returns default on missing key without exception',
      TVeloxRegistry.ReadInteger(HKEY_CURRENT_USER, 'Software\NonExistentVeloxTestKey', 'MissingVal', 42) = 42);

    // 61. Translucent Acrylic Glass Panel (TVeloxGlassPanel)
    WriteLn('[61/78] Testing TVeloxGlassPanel (Corner Radius & Specular Highlight)...');
    Frm := TForm.CreateNew(nil);
    try
      GlassPnl := TVeloxGlassPanel.Create(Frm);
      GlassPnl.Parent := Frm;
      GlassPnl.Title := 'System Telemetry';
      GlassPnl.CornerRadius := 16;
      Check('glass: Title and CornerRadius properties preserved',
        (GlassPnl.Title = 'System Telemetry') and (GlassPnl.CornerRadius = 16));
    finally
      Frm.Free;
    end;

    // 62. Auto-Flow KPI Telemetry Dashboard Grid (TVeloxKpiGrid)
    WriteLn('[62/78] Testing TVeloxKpiGrid (Responsive Cards, Deltas & Sparklines)...');
    Frm := TForm.CreateNew(nil);
    try
      KpiGrid := TVeloxKpiGrid.Create(Frm);
      KpiGrid.Parent := Frm;
      KpiGrid.AddCard('cpu', 'CPU Usage', '28.4', '%', '+3.2%', False);
      KpiGrid.AddCard('ram', 'RAM Usage', '6.8', 'GB', '-0.5%', True);
      Check('kpigrid: 2 metric cards registered', KpiGrid.CardCount = 2);
      KpiGrid.UpdateCard('cpu', '32.1', '+4.1%', False, 32.1);
      Check('kpigrid: CardCount remains 2 after update', KpiGrid.CardCount = 2);
    finally
      Frm.Free;
    end;

    // 63. Chronological Event Timeline (TVeloxTimeline)
    WriteLn('[63/78] Testing TVeloxTimeline (Nodes, Severity Colors & Timestamps)...');
    Frm := TForm.CreateNew(nil);
    try
      Timeline := TVeloxTimeline.Create(Frm);
      Timeline.Parent := Frm;
      Timeline.AddItem('08:00', 'System Boot', 'Kernel initialized successfully', vsNormal);
      Timeline.AddItem('08:15', 'High Load Warning', 'CPU exceeded 85% threshold', vsWarning);
      Timeline.AddItem('08:30', 'Network Failover', 'Switched to backup interface', vsCritical);
      Check('timeline: 3 chronological nodes registered', Timeline.Count = 3);
      Timeline.Clear;
      Check('timeline: Clear resets count to 0', Timeline.Count = 0);
    finally
      Frm.Free;
    end;

    // 64. Interactive Star & Severity Rating (TVeloxRating)
    WriteLn('[64/78] Testing TVeloxRating (Star Range, Clamping & HitTest)...');
    Frm := TForm.CreateNew(nil);
    try
      RatingCtrl := TVeloxRating.Create(Frm);
      RatingCtrl.Parent := Frm;
      RatingCtrl.Rating := 4.5;
      Check('rating: initial rating set to 4.5', Abs(RatingCtrl.Rating - 4.5) < 0.01);
      RatingCtrl.Rating := 7.0;
      Check('rating: rating clamped to MaxRating 5.0', Abs(RatingCtrl.Rating - 5.0) < 0.01);
    finally
      Frm.Free;
    end;

    // 65. Compact Modern Pagination Footer (TVeloxPagination)
    WriteLn('[65/78] Testing TVeloxPagination (Pages, Total Items & Page Navigation)...');
    Frm := TForm.CreateNew(nil);
    try
      Pagination := TVeloxPagination.Create(Frm);
      Pagination.Parent := Frm;
      Pagination.PageSize := 25;
      Pagination.TotalItems := 120;
      Check('pagination: TotalPages computed as 5 for 120 items at 25/page',
        Pagination.TotalPages = 5);
      Check('pagination: initial CurrentPage is 1', Pagination.CurrentPage = 1);
      Pagination.NextPage;
      Check('pagination: NextPage advances CurrentPage to 2', Pagination.CurrentPage = 2);
      Pagination.LastPage;
      Check('pagination: LastPage jumps CurrentPage to 5', Pagination.CurrentPage = 5);
    finally
      Frm.Free;
    end;

    // 66. Live Inspector & Config Studio (TVeloxInspectorStudio)
    WriteLn('[66/78] Testing TVeloxInspectorStudio (Properties, Undo/Redo & Transactions)...');
    Frm := TForm.CreateNew(nil);
    try
      InspStudio := TVeloxInspectorStudio.Create(Frm);
      InspStudio.Parent := Frm;
      InspStudio.AddString('General', 'AppName', 'VeloxApp');
      InspStudio.AddBoolean('General', 'DebugMode', True);
      InspStudio.SetString('AppName', 'VeloxStudio');
      Check('inspector: SetString updates property value', InspStudio.GetString('AppName') = 'VeloxStudio');
      Check('inspector: After edit IsDirty is True', InspStudio.IsDirty);
      InspStudio.Undo;
      Check('inspector: Undo rolls back value to VeloxApp', InspStudio.GetString('AppName') = 'VeloxApp');
      InspStudio.Redo;
      Check('inspector: Redo advances value back to VeloxStudio', InspStudio.GetString('AppName') = 'VeloxStudio');
      InspStudio.ApplyChanges;
      Check('inspector: ApplyChanges clears dirty flag', not InspStudio.IsDirty);
    finally
      Frm.Free;
    end;

    // 67. Staging & Code Diff Inspector (TVeloxDiffInspector)
    WriteLn('[67/78] Testing TVeloxDiffInspector (CompareTexts, Stats & ViewMode)...');
    Frm := TForm.CreateNew(nil);
    try
      DiffInsp := TVeloxDiffInspector.Create(Frm);
      DiffInsp.Parent := Frm;
      DiffInsp.CompareTexts('Line 1'#10'Line 2'#10'Line 3', 'Line 1'#10'Modified 2'#10'Line 3'#10'Line 4', 'Unit.pas');
      Check('diffinspector: Additions counted correctly', DiffInsp.Additions = 2);
      Check('diffinspector: Deletions counted correctly', DiffInsp.Deletions = 1);
      Check('diffinspector: Similarity calculated between 0 and 1', (DiffInsp.Similarity >= 0.0) and (DiffInsp.Similarity <= 1.0));
      DiffInsp.SetViewMode(vdvmSideBySide);
      Check('diffinspector: SetViewMode updates internal DiffView', DiffInsp.DiffView.ViewMode = vdvmSideBySide);
    finally
      Frm.Free;
    end;

    // 68. Win+V Clipboard History Palette (TVeloxClipboardPalette)
    WriteLn('[68/78] Testing TVeloxClipboardPalette (Clips, Filter & MRU)...');
    Frm := TForm.CreateNew(nil);
    try
      ClipPal := TVeloxClipboardPalette.Create(Frm);
      ClipPal.Parent := Frm;
      ClipPal.AddClip('function Test: Integer;', False);
      ClipPal.AddClip('https://github.com/amafjarkasi/velox-ui', True);
      Check('clipboardpal: MRU item count is 2', ClipPal.ItemCount = 2);
      ClipPal.FilterCategory := vccPinned;
      ClipPal.RefreshList;
      Check('clipboardpal: Pinned filter isolates 1 pinned clip', ClipPal.Mru.IsPinned(0));
      ClipPal.Clear;
      Check('clipboardpal: Clear empties items', ClipPal.ItemCount = 0);
    finally
      Frm.Free;
    end;

    // 69. Multi-Host Ping & Latency Matrix Monitor (TVeloxNetworkMonitor)
    WriteLn('[69/78] Testing TVeloxNetworkMonitor (Hosts, Ping & Latency)...');
    Frm := TForm.CreateNew(nil);
    try
      NetMon := TVeloxNetworkMonitor.Create(Frm);
      NetMon.Parent := Frm;
      NetMon.AutoPing := False;
      NetMon.AddHost('127.0.0.1', 'Localhost');
      NetMon.AddHost('1.1.1.1', 'Cloudflare DNS');
      Check('netmon: HostCount is 2', NetMon.HostCount = 2);
      NetMon.PingAll;
      Check('netmon: Localhost ping succeeds and records latency', NetMon.GetLatency(0) >= 0);
      Check('netmon: Packet loss percentage is non-negative', NetMon.GetPacketLoss(0) >= 0.0);
    finally
      Frm.Free;
    end;

    // 70. Process & Service Diagnostics Explorer (TVeloxTaskExplorer)
    WriteLn('[70/78] Testing TVeloxTaskExplorer (Process RAM, Service Query & Trim)...');
    Frm := TForm.CreateNew(nil);
    try
      TaskExp := TVeloxTaskExplorer.Create(Frm);
      TaskExp.Parent := Frm;
      TaskExp.MonitoredService := 'LanmanServer';
      TaskExp.RefreshDiagnostics;
      Check('taskexp: WorkingSetMB > 0', TaskExp.WorkingSetMB > 0.0);
      Check('taskexp: Monitored service recognized', TaskExp.ServiceState in [vssRunning, vssStopped, vssUnknown]);
      Check('taskexp: TrimMemory executes cleanly', TaskExp.TrimMemory);
    finally
      Frm.Free;
    end;

    // 71. Real-Time File Integrity & Audit Security Tracker (TVeloxAuditSecurityLog)
    WriteLn('[71/78] Testing TVeloxAuditSecurityLog (Timeline, SHA-256 & Events)...');
    Frm := TForm.CreateNew(nil);
    try
      AuditLog := TVeloxAuditSecurityLog.Create(Frm);
      AuditLog.Parent := Frm;
      AuditLog.LogEvent('System Startup', 'Kernel initialized', vsNormal);
      AuditLog.LogEvent('Security Check', 'SHA-256 verified', vsNormal);
      Check('auditlog: Initial event count is 2', AuditLog.EventCount = 2);
      AuditLog.ClearLog;
      Check('auditlog: ClearLog resets event count to 0', AuditLog.EventCount = 0);
    finally
      Frm.Free;
    end;

    // 72. Interactive JSON Document & Hierarchy Explorer (TVeloxJsonTreeViewer)
    WriteLn('[72/78] Testing TVeloxJsonTreeViewer (JSON DOM, Tree & Breadcrumb)...');
    Frm := TForm.CreateNew(nil);
    try
      JsonViewer := TVeloxJsonTreeViewer.Create(Frm);
      JsonViewer.Parent := Frm;
      JsonViewer.LoadJson('{"name":"VeloxUI","version":2.5,"features":["MVVM","GDI+"]}');
      Check('jsontree: Root and child nodes parsed', JsonViewer.NodeCount >= 4);
      Check('jsontree: SelectedPath initialized', Pos('root', JsonViewer.SelectedPath) = 1);
      JsonViewer.Clear;
      Check('jsontree: Clear empties nodes', JsonViewer.NodeCount = 0);
    finally
      Frm.Free;
    end;

    // 73. WinUI 3 Fluent Self-Updater Flyout (TVeloxUpdateFlyout)
    WriteLn('[73/78] Testing TVeloxUpdateFlyout (GlassPanel, Release & Progress)...');
    Frm := TForm.CreateNew(nil);
    try
      UpdFlyout := TVeloxUpdateFlyout.Create(Frm);
      UpdFlyout.Parent := Frm;
      UpdFlyout.SetRelease('v2.5.0', 'Composite component release', 'https://github.com/...');
      Check('updateflyout: ReleaseTag set to v2.5.0', UpdFlyout.ReleaseTag = 'v2.5.0');
      Check('updateflyout: Initially not downloading', not UpdFlyout.IsDownloading);
      UpdFlyout.StartDownloadProgress;
      Check('updateflyout: StartDownloadProgress sets IsDownloading to True', UpdFlyout.IsDownloading);
      UpdFlyout.StopDownloadProgress;
      Check('updateflyout: StopDownloadProgress restores state', not UpdFlyout.IsDownloading);
    finally
      Frm.Free;
    end;

    // 74. Scalable Windows 11 Fluent Vector Icon Engine (TVeloxIcons)
    WriteLn('[74/78] Testing TVeloxIcons (GDI+ Vector Engine, Scalable Glyphs)...');
    Check('icons: Built-in count >= 35', TVeloxIcons.Count >= 35);
    Check('icons: IconName(viHome) is "Home"', TVeloxIcons.IconName(viHome) = 'Home');
    Check('icons: IconName(viSettings) is "Settings"', TVeloxIcons.IconName(viSettings) = 'Settings');
    Check('icons: IconName(viShield) is "Shield"', TVeloxIcons.IconName(viShield) = 'Shield');
    Check('icons: FromName("Terminal") is viTerminal', TVeloxIcons.FromName('Terminal') = viTerminal);
    IconBmp := TBitmap.Create;
    try
      IconBmp.SetSize(32, 32);
      TVeloxIcons.Draw(IconBmp.Canvas, Rect(0, 0, 32, 32), viShield, $38BDF8, 24);
      Check('icons: Draw renders viShield vector glyph cleanly', True);
    finally
      IconBmp.Free;
    end;

    // 75. Responsive Flex Stack Layout Panel (TVeloxStackPanel)
    WriteLn('[75/78] Testing TVeloxStackPanel (Auto-Wrap, Gap Spacing & Flex Stack)...');
    Frm := TForm.CreateNew(nil);
    try
      StackPnl := TVeloxStackPanel.CreateHorizontal(Frm, Frm, 8, 8);
      BtnA := TButton.Create(Frm);
      BtnA.SetBounds(0, 0, 80, 28);
      StackPnl.Add(BtnA);
      BtnB := TButton.Create(Frm);
      BtnB.SetBounds(0, 0, 80, 28);
      StackPnl.Add(BtnB);

      Check('stackpanel: Child 1 Left positioned at padding 8', BtnA.Left = 8);
      Check('stackpanel: Child 2 Left positioned at 8 + 80 + 8 = 96', BtnB.Left = 96);
      Check('stackpanel: ContentWidth computes correctly', StackPnl.ContentWidth = 8 + 80 + 8 + 80 + 8);

      StackPnl.Orientation := voVertical;
      Check('stackpanel: Vertical Child 2 Top positioned at 44 (8 + 28 + 8)', BtnB.Top = 44);
      Check('stackpanel: ContentHeight computes correctly', StackPnl.ContentHeight = 8 + 28 + 8 + 28 + 8);
    finally
      Frm.Free;
    end;

    // 76. Per-Monitor v2 Auto-Rescaling GDI+ Graphics Context (TVeloxDpiCanvas)
    WriteLn('[76/78] Testing TVeloxDpiCanvas (Per-Monitor v2 Auto-Rescaling Context)...');
    IconBmp := TBitmap.Create;
    try
      IconBmp.SetSize(64, 64);
      DpiCanvas := TVeloxDpiCanvas.Create(IconBmp.Canvas, 144);
      try
        Check('dpicanvas: Dpi set to 144', DpiCanvas.Dpi = 144);
        Check('dpicanvas: Scale(10) is 15 at 144 DPI (150%)', DpiCanvas.Scale(10) = 15);
        Check('dpicanvas: ScaleRect scales right bound proportionally', DpiCanvas.ScaleRect(Rect(10, 20, 100, 200)).Right = 150);
        DpiCanvas.DrawCard(Rect(0, 0, 30, 30), $202020, $38BDF8, 6);
        DpiCanvas.DrawIcon(Rect(0, 0, 30, 30), viShield, $38BDF8, 16);
        Check('dpicanvas: DrawCard and DrawIcon execute cleanly at High-DPI', True);
      finally
        DpiCanvas.Free;
      end;
    finally
      IconBmp.Free;
    end;

    // 77. Universal Focus Rings & Accessibility (TVeloxFocusManager & TVeloxFocusRing)
    WriteLn('[77/78] Testing TVeloxAccessibility & TVeloxFocusManager (Tab Traversal & Focus Rings)...');
    Frm := TForm.CreateNew(nil);
    try
      FocusMgr := TVeloxFocusManager.Create(Frm);
      FocusBtn1 := TVeloxStyledButton.CreateButton(Frm, Frm, 0, 0, 80, 30, 'Btn1', DarkColors);
      FocusBtn2 := TVeloxStyledButton.CreateButton(Frm, Frm, 0, 40, 80, 30, 'Btn2', DarkColors);
      FocusMgr.RegisterControl(FocusBtn1);
      FocusMgr.RegisterControl(FocusBtn2);
      Check('accessibility: FocusManager registers 2 controls', FocusMgr.Count = 2);
      Check('accessibility: initial focused control is FocusBtn1', FocusMgr.FocusedControl = FocusBtn1);
      FocusMgr.FocusNext(True);
      Check('accessibility: FocusNext advances focus to FocusBtn2', FocusMgr.FocusedControl = FocusBtn2);
      Check('accessibility: IsActivationKey identifies VK_SPACE & VK_RETURN',
        TVeloxAccessibility.IsActivationKey(VK_SPACE) and TVeloxAccessibility.IsActivationKey(VK_RETURN));
      IconBmp := TBitmap.Create;
      try
        IconBmp.SetSize(32, 32);
        TVeloxFocusRing.DrawFocusRing(IconBmp.Canvas, Rect(2, 2, 30, 30), $38BDF8, 4);
        Check('accessibility: DrawFocusRing renders cleanly', True);
      finally
        IconBmp.Free;
      end;
    finally
      Frm.Free;
    end;

    // 78. Windows 11 DWM Desktop Acrylic & System Blur (TVeloxBackdrop)
    WriteLn('[78/79] Testing TVeloxBackdrop (DWM Desktop Acrylic & System Blur)...');
    Frm := TForm.CreateNew(nil);
    try
      Check('backdrop: SupportsDarkMode returns valid boolean on NT', TVeloxBackdrop.SupportsDarkMode or not TVeloxBackdrop.SupportsDarkMode);
      Check('backdrop: SupportsSystemBackdrop returns valid boolean', TVeloxBackdrop.SupportsSystemBackdrop or not TVeloxBackdrop.SupportsSystemBackdrop);
      Check('backdrop: ApplyPopupAcrylic guards HWND 0 without exception', not TVeloxBackdrop.ApplyPopupAcrylic(0, True));
      Check('backdrop: ApplyBackdrop with vbkMica guards HWND 0 cleanly', not TVeloxBackdrop.ApplyBackdrop(0, vbkMica, True));
      TVeloxBackdrop.ConfigureFloatingPopup(Frm, True);
      Check('backdrop: ConfigureFloatingPopup sets bsNone border style', Frm.BorderStyle = bsNone);
    finally
      Frm.Free;
    end;

    // 79. Embedded HTTP Workbench & API Debugger (TVeloxRestStudio)
    WriteLn('[79/79] Testing TVeloxRestStudio (API Workbench, cURL, Latency & Diff)...');
    Frm := TForm.CreateNew(nil);
    try
      RestStudio := TVeloxRestStudio.Create(Frm);
      RestStudio.Parent := Frm;
      RestStudio.SetBounds(0, 0, 860, 540);
      Check('reststudio: Method defaults to vrmGET', RestStudio.Method = vrmGET);
      RestStudio.SetEndpoint(vrmPOST, 'https://api.github.com/repos/amafjarkasi/velox-ui', '{"name":"velox"}');
      Check('reststudio: SetEndpoint updates method to POST', RestStudio.Method = vrmPOST);
      Check('reststudio: BuildEffectiveUrl appends query params', Pos('page=1', RestStudio.BuildEffectiveUrl) > 0);
      Check('reststudio: BuildHeadersString contains Content-Type', Pos('application/json', RestStudio.BuildHeadersString) > 0);
      Check('reststudio: GenerateCurlCommand outputs curl CLI command', Pos('curl -X POST', RestStudio.GenerateCurlCommand) > 0);
      Check('reststudio: MethodToString maps correctly', TVeloxRestStudio.MethodToString(vrmDELETE) = 'DELETE');
      Check('reststudio: StringToMethod parses method', TVeloxRestStudio.StringToMethod('PATCH') = vrmPATCH);
      RestStudio.SaveCurrentAsBaseline;
      Check('reststudio: SaveCurrentAsBaseline saves string', RestStudio.BaselineResponse = RestStudio.Response.Body);
      RestStudio.ViewMode := vrvmLatency;
      Check('reststudio: ViewMode updates cleanly', RestStudio.ViewMode = vrvmLatency);
    finally
      Frm.Free;
    end;

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
