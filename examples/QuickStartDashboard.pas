unit QuickStartDashboard;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI Quick-Start Reference Example:
  Demonstrates how a complete Windows 11 Dark-Themed Telemetry & Virtual Table
  application (normally ~650 lines of raw Win32/LCL/VCL code) is built in
  ~90 lines using VeloxUI.
==============================================================================}

interface

uses
  SysUtils, Classes, Windows, Types, Graphics, Controls, Forms,
  StdCtrls, ExtCtrls, ComCtrls, Generics.Collections,
  Velox.Types, Velox.Theme, Velox.GdiPlus, Velox.Controls,
  Velox.VirtualGrid, Velox.Async, Velox.System;

type
  TServiceRow = record
    Pid: Cardinal;
    Name: string;
    MemoryMB: Double;
    CommandLine: string;
  end;

  TQuickStartForm = class(TForm)
  private
    FColors: TVeloxThemeColors;
    FCpuRing: TVeloxRingBuffer;
    FSearchBox: TVeloxSearchBox;
    FTrayCheck: TVeloxDarkCheckBox;
    FIntervalCombo: TComboBox;
    FCpuCard: TPaintBox;
    FListView: TListView;
    FGrid: TVeloxVirtualGrid<TServiceRow>;
    FRows: TList<TServiceRow>;
    FPoller: TVeloxPoller<Single>;

    function CollectCpuSample: Single;
    procedure OnCpuDelivered(const ACpuPct: Single);
    procedure OnCpuCardPaint(Sender: TObject);
    procedure OnListViewData(Sender: TObject; Item: TListItem);
    function CompareRows(const A, B: TServiceRow; const ACol: Integer): Integer;
  public
    constructor CreateNewDashboard(AOwner: TComponent);
    destructor Destroy; override;
  end;

implementation

constructor TQuickStartForm.CreateNewDashboard(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'VeloxUI QuickStart Dashboard';
  SetBounds(120, 120, 1080, 680);
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FCpuRing.Clear(30);
  FRows := TList<TServiceRow>.Create;

  // 1. Centered Fluent Search Box (solves Win32 TEdit top-left clipping automatically)
  FSearchBox := TVeloxSearchBox.CreateBox(Self, Self, 16, 16, 220, 28, 'Search processes...', FColors);

  // 2. Dark-Panel Safe CheckBox (solves Win32 UXTheme black caption bug)
  FTrayCheck := TVeloxDarkCheckBox.CreateCheck(Self, Self, 252, 20, 160, 'Minimize to tray', FColors, True);

  // 3. Hardware-Accelerated GDI+ KPI Card with Rolling Sparkline
  FCpuCard := TPaintBox.Create(Self);
  FCpuCard.Parent := Self;
  FCpuCard.SetBounds(16, 58, 280, 104);
  FCpuCard.OnPaint := OnCpuCardPaint;

  // 4. Flicker-Free Virtual Grid (OwnerData + LVS_EX_DOUBLEBUFFER + Natural Sort)
  FListView := TListView.Create(Self);
  FListView.Parent := Self;
  FListView.SetBounds(16, 176, 1040, 480);
  FListView.OnData := OnListViewData;

  FGrid := TVeloxVirtualGrid<TServiceRow>.Create(FListView);
  FGrid.AddColumn('PID', 80, taLeftJustify, False);
  FGrid.AddColumn('Process Name', 220, taLeftJustify, False);
  FGrid.AddColumn('Working Set (RAM)', 140, taRightJustify, True); // Numeric: Descending first!
  FGrid.AddColumn('Command Line', 480, taLeftJustify, False);

  // 5. Apply DWM Dark Title Bar, Mica Backdrop, Dark Scrollbars & Recursive Theme in 1 line
  TVeloxThemeEngine.ApplyFormTheme(Self, vtDark);
  TVeloxThemeEngine.ApplySystemBackdrop(Handle, vbtMica);

  // 6. Start Interruptible Async Background Poller (<50ms shutdown guarantee)
  FPoller := TVeloxPoller<Single>.Create(1000, CollectCpuSample, OnCpuDelivered);
  FPoller.Start;
end;

destructor TQuickStartForm.Destroy;
begin
  FPoller.Free;
  FGrid.Free;
  FRows.Free;
  inherited Destroy;
end;

function TQuickStartForm.CollectCpuSample: Single;
begin
  Result := 15.0 + Random(40);
end;

procedure TQuickStartForm.OnCpuDelivered(const ACpuPct: Single);
begin
  FCpuRing.Add(ACpuPct);
  FCpuCard.Invalidate;
end;

procedure TQuickStartForm.OnCpuCardPaint(Sender: TObject);
begin
  TVeloxGdiPlus.DrawMetricCard(FCpuCard, FColors, 'CPU UTILIZATION',
    TVeloxUtils.FormatPercent(FCpuRing.Latest),
    Format('Peak: %s · Avg: %s', [TVeloxUtils.FormatPercent(FCpuRing.Peak), TVeloxUtils.FormatPercent(FCpuRing.Average)]),
    FCpuRing.Latest, FColors.Accent, FCpuRing.ToArray);
end;

procedure TQuickStartForm.OnListViewData(Sender: TObject; Item: TListItem);
var
  R: TServiceRow;
begin
  if (Item = nil) or (Item.Index < 0) or (Item.Index >= FRows.Count) then Exit;
  R := FRows[Item.Index];
  Item.Caption := IntToStr(R.Pid);
  Item.SubItems.Add(R.Name);
  Item.SubItems.Add(TVeloxUtils.FormatMegabytes(R.MemoryMB));
  Item.SubItems.Add(R.CommandLine);
end;

function TQuickStartForm.CompareRows(const A, B: TServiceRow; const ACol: Integer): Integer;
begin
  Result := 0;
  case ACol of
    0: Result := Integer(A.Pid) - Integer(B.Pid);
    1: Result := CompareText(A.Name, B.Name);
    2: if A.MemoryMB > B.MemoryMB then Result := 1 else if A.MemoryMB < B.MemoryMB then Result := -1;
    3: Result := CompareText(A.CommandLine, B.CommandLine);
  end;
end;

end.
