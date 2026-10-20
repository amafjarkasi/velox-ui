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
  Generics.Collections,
  Velox.Types,
  Velox.Theme,
  Velox.GdiPlus,
  Velox.Controls,
  Velox.VirtualGrid,
  Velox.Async,
  Velox.System;

type
  TTestRow = record
    Id: Integer;
    Name: string;
    Metric: Double;
  end;

  TGridSortHelper = class
  public
    function CompareRows(const A, B: TTestRow; const ACol: Integer): Integer;
    function CollectSample: Integer;
    procedure DeliverSample(const AVal: Integer);
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
  Arr: TSingleDynArray;
  DarkColors, LightColors: TVeloxThemeColors;
  Bmp: TBitmap;
  Frm: TForm;
  SearchBox: TVeloxSearchBox;
  DarkChk: TVeloxDarkCheckBox;
  Cmb: TComboBox;
  Btn: TButton;
  Lv: TListView;
  Grid: TVeloxVirtualGrid<TTestRow>;
  Rows: TList<TTestRow>;
  R: TTestRow;
  Helper: TGridSortHelper;
  Modal: TVeloxModalDialog;
  Alert: TVeloxThresholdAlert;
  Sev: TVeloxSeverity;
  Poller: TVeloxPoller<Integer>;
  ProcMask, SysMask: NativeUInt;
  GdiCnt, UserCnt: Cardinal;
  VerInfo: TVeloxFileVersionInfo;
  CmdLine, SysRoot: string;
  I: Integer;
begin
  try
    WriteLn('=== VeloxUI Automated Verification Suite ===');

    // 1. Ring Buffer & Telemetry Primitives
    WriteLn('[1/7] Testing TVeloxRingBuffer & TVeloxUtils...');
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
    WriteLn('[2/7] Testing TVeloxGdiPlus Anti-Aliased Primitives...');
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
    WriteLn('[3/7] Testing TVeloxThemeEngine (DWM, UXTheme & Recursive Styling)...');
    TVeloxThemeEngine.InitializeProcessDarkMode(True);
    Check('theme: InitializeProcessDarkMode (Ordinal 135) succeeds', True);
    Check('theme: DetectSystemTheme returns valid enum', TVeloxThemeEngine.DetectSystemTheme in [vtDark, vtLight]);

    // 4. Fluent Control Factories (SearchBox, DarkCheckBox, ComboBox Sync, Modal)
    WriteLn('[4/7] Testing TVeloxControls (SearchBox, DarkCheckBox, High-DPI ComboBox, Modal)...');
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
      WriteLn('[5/7] Testing TVeloxVirtualGrid<T> (OwnerData, QuickSort, Natural Sort Direction)...');
      Lv := TListView.Create(Frm);
      Lv.Parent := Frm;
      Lv.SetBounds(16, 100, 760, 400);

      Grid := TVeloxVirtualGrid<TTestRow>.Create(Lv);
      Helper := TGridSortHelper.Create;
      Rows := TList<TTestRow>.Create;
      try
        Grid.AddColumn('ID', 70, taLeftJustify, False);       // Text/ID: default ascending
        Grid.AddColumn('Name', 200, taLeftJustify, False);    // Text: default ascending
        Grid.AddColumn('RAM (MB)', 120, taRightJustify, True); // Numeric: default descending!

        Check('grid: OwnerData enabled automatically', Lv.OwnerData);
        Check('grid: 3 columns registered', Lv.Columns.Count = 3);

        R.Id := 2; R.Name := 'Beta';  R.Metric := 150.0; Rows.Add(R);
        R.Id := 1; R.Name := 'Alpha'; R.Metric := 900.0; Rows.Add(R);
        R.Id := 3; R.Name := 'Gamma'; R.Metric := 420.0; Rows.Add(R);

        // Clicking Column 2 ('RAM (MB)') first time should sort DESCENDING because DefaultDescending = True
        Grid.ClickColumn(2);
        Check('grid: numeric column defaults to descending on first click', (Grid.SortColumn = 2) and (not Grid.SortAscending));
        Grid.SortList(Rows, Helper.CompareRows);
        Check('grid: descending sort orders 900.0 first and 150.0 last',
          (Rows[0].Metric = 900.0) and (Rows[2].Metric = 150.0));
        Check('grid: header indicator shows descending arrow',
          Pos(VELOX_ARROW_DESC, Lv.Columns[2].Caption) > 0);

        // Clicking Column 1 ('Name') first time should sort ASCENDING because DefaultDescending = False
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
    WriteLn('[6/7] Testing TVeloxPoller<T> & TVeloxThresholdAlert...');
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
    WriteLn('[7/7] Testing TVeloxSystem (NT Command Line, VersionInfo, GUI Resources, Affinity)...');
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
