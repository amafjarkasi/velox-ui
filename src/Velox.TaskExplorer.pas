unit Velox.TaskExplorer;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.TaskExplorer (#70)
  Purpose:
    Composite Process & Service Diagnostics Explorer combining:
      - TVeloxServices (Windows SCM Query, Start, Stop & Restart)
      - TVeloxMemory (Physical RAM, working set & commit diagnostics)
      - TVeloxSystem (PEB command lines, CPU affinity & TrimWorkingSet)
      - Action buttons for memory trimming and service management
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
  Velox.Services,
  Velox.Memory,
  Velox.System,
  Velox.StyledButton;

type
  TVeloxTaskExplorer = class(TCustomControl)
  private
    FTopBar: TPanel;
    FBtnTrimRam: TVeloxStyledButton;
    FBtnRefresh: TVeloxStyledButton;
    FColors: TVeloxThemeColors;
    FMonitoredService: string;
    FServiceState: TVeloxServiceState;
    FWorkingSetBytes: Int64;
    FTotalRamBytes: UInt64;
    FMemoryLoad: Cardinal;
    FProcessCmdLine: string;
    function GetWorkingSetMB: Double;
    procedure HandleTrimClick(Sender: TObject);
    procedure HandleRefreshClick(Sender: TObject);
    procedure SetMonitoredService(const Value: string);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure RefreshDiagnostics;
    function TrimMemory: Boolean;
    function RestartMonitoredService: Boolean;

    property MonitoredService: string read FMonitoredService write SetMonitoredService;
    property ServiceState: TVeloxServiceState read FServiceState;
    property WorkingSetMB: Double read GetWorkingSetMB;
    property MemoryLoadPercent: Cardinal read FMemoryLoad;
    property ProcessCommandLine: string read FProcessCmdLine;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxTaskExplorer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 480;
  Height := 300;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FMonitoredService := 'LanmanServer';

  // Top Bar
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.Align := alTop;
  FTopBar.Height := 42;
  FTopBar.BevelOuter := bvNone;
  FTopBar.Color := FColors.Surface;

  FBtnRefresh := TVeloxStyledButton.Create(Self);
  FBtnRefresh.Parent := FTopBar;
  FBtnRefresh.Caption := 'Refresh';
  FBtnRefresh.Variant := vsbOutline;
  FBtnRefresh.SetBounds(Width - 160, 7, 72, 28);
  FBtnRefresh.OnClick := HandleRefreshClick;

  FBtnTrimRam := TVeloxStyledButton.Create(Self);
  FBtnTrimRam.Parent := FTopBar;
  FBtnTrimRam.Caption := 'Trim RAM';
  FBtnTrimRam.Variant := vsbPrimary;
  FBtnTrimRam.SetBounds(Width - 82, 7, 74, 28);
  FBtnTrimRam.OnClick := HandleTrimClick;

  ApplyColors(FColors);
  RefreshDiagnostics;
end;

procedure TVeloxTaskExplorer.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  if Assigned(FTopBar) then FTopBar.Color := FColors.Surface;
  if Assigned(FBtnRefresh) then FBtnRefresh.ApplyColors(FColors);
  if Assigned(FBtnTrimRam) then FBtnTrimRam.ApplyColors(FColors);
  Invalidate;
end;

procedure TVeloxTaskExplorer.SetMonitoredService(const Value: string);
begin
  FMonitoredService := Value;
  RefreshDiagnostics;
end;

function TVeloxTaskExplorer.GetWorkingSetMB: Double;
begin
  Result := FWorkingSetBytes / (1024.0 * 1024.0);
end;

procedure TVeloxTaskExplorer.RefreshDiagnostics;
var
  SysMem: TVeloxSystemMemory;
  ProcMem: TVeloxProcessMemory;
begin
  SysMem := TVeloxMemory.GetSystemMemory;
  FTotalRamBytes := SysMem.TotalPhysicalBytes;
  FMemoryLoad := SysMem.MemoryLoadPercent;

  ProcMem := TVeloxMemory.GetProcessMemory(GetCurrentProcessId);
  FWorkingSetBytes := ProcMem.WorkingSetBytes;

  FProcessCmdLine := TVeloxSystem.GetProcessCommandLine(GetCurrentProcessId);
  FServiceState := TVeloxServices.GetServiceState(FMonitoredService);

  Invalidate;
end;

function TVeloxTaskExplorer.TrimMemory: Boolean;
begin
  Result := TVeloxSystem.TrimProcessWorkingSet(GetCurrentProcessId);
  RefreshDiagnostics;
end;

function TVeloxTaskExplorer.RestartMonitoredService: Boolean;
begin
  Result := TVeloxServices.RestartService(FMonitoredService);
  RefreshDiagnostics;
end;

procedure TVeloxTaskExplorer.HandleTrimClick(Sender: TObject);
begin
  TrimMemory;
end;

procedure TVeloxTaskExplorer.HandleRefreshClick(Sender: TObject);
begin
  RefreshDiagnostics;
end;

procedure TVeloxTaskExplorer.Paint;
var
  C: TCanvas;
  Card1R, Card2R, Card3R, TR: TRect;
  HalfW: Integer;
  ValStr, HeaderStr: string;
begin
  C := Canvas;
  C.Brush.Color := FColors.Background;
  C.FillRect(ClientRect);

  HalfW := (Width - 32) div 2;

  // Card 1: Process RAM Working Set
  Card1R := Rect(12, 52, 12 + HalfW, 150);
  TVeloxGdiPlus.DrawCard(C, Card1R, FColors.SurfaceCard, FColors.Border, 8);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 8;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextSecondary;
  HeaderStr := 'PROCESS WORKING SET';
  TR := Rect(Card1R.Left + 14, Card1R.Top + 12, Card1R.Right - 14, Card1R.Top + 28);
  DrawText(C.Handle, PChar(HeaderStr), -1, TR,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  C.Font.Size := 18;
  C.Font.Color := FColors.Accent;
  ValStr := Format('%.1f MB', [WorkingSetMB]);
  TR := Rect(Card1R.Left + 14, Card1R.Top + 32, Card1R.Right - 14, Card1R.Top + 62);
  DrawText(C.Handle, PChar(ValStr), -1, TR,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  ValStr := Format('System RAM Load: %d%%', [FMemoryLoad]);
  TR := Rect(Card1R.Left + 14, Card1R.Top + 66, Card1R.Right - 14, Card1R.Top + 86);
  DrawText(C.Handle, PChar(ValStr), -1, TR,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  // Card 2: Monitored Windows Service
  Card2R := Rect(20 + HalfW, 52, Width - 12, 150);
  TVeloxGdiPlus.DrawCard(C, Card2R, FColors.SurfaceCard, FColors.Border, 8);

  C.Font.Size := 8;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextSecondary;
  HeaderStr := 'WINDOWS SCM SERVICE';
  TR := Rect(Card2R.Left + 14, Card2R.Top + 12, Card2R.Right - 14, Card2R.Top + 28);
  DrawText(C.Handle, PChar(HeaderStr), -1, TR,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  C.Font.Size := 14;
  if FServiceState = vssRunning then
    C.Font.Color := $10B981
  else
    C.Font.Color := $F43F5E;

  ValStr := TVeloxServices.StateToString(FServiceState);
  TR := Rect(Card2R.Left + 14, Card2R.Top + 34, Card2R.Right - 14, Card2R.Top + 62);
  DrawText(C.Handle, PChar(ValStr), -1, TR,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  ValStr := 'Service: ' + FMonitoredService;
  TR := Rect(Card2R.Left + 14, Card2R.Top + 66, Card2R.Right - 14, Card2R.Top + 86);
  DrawText(C.Handle, PChar(ValStr), -1, TR,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  // Card 3: Process PEB Command Line
  Card3R := Rect(12, 160, Width - 12, Height - 12);
  TVeloxGdiPlus.DrawCard(C, Card3R, FColors.SurfaceCard, FColors.Border, 8);

  C.Font.Size := 8;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextSecondary;
  HeaderStr := 'COMMAND LINE (PEB NTQUERYINFORMATIONPROCESS)';
  TR := Rect(Card3R.Left + 14, Card3R.Top + 10, Card3R.Right - 14, Card3R.Top + 26);
  DrawText(C.Handle, PChar(HeaderStr), -1, TR,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  C.Font.Name := 'Consolas';
  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextPrimary;
  TR := Rect(Card3R.Left + 14, Card3R.Top + 28, Card3R.Right - 14, Card3R.Bottom - 10);
  DrawText(C.Handle, PChar(FProcessCmdLine), -1, TR,
    DT_WORDBREAK or DT_NOPREFIX);
end;

procedure TVeloxTaskExplorer.Resize;
begin
  inherited Resize;
  if Assigned(FBtnTrimRam) and Assigned(FBtnRefresh) then
  begin
    FBtnTrimRam.Left := Width - FBtnTrimRam.Width - 10;
    FBtnRefresh.Left := FBtnTrimRam.Left - FBtnRefresh.Width - 6;
  end;
end;

end.
