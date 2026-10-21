unit Velox.NetworkMonitor;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.NetworkMonitor (#69)
  Purpose:
    Composite Multi-Host Ping & Latency Matrix Monitor combining:
      - TVeloxNetwork (Win32 icmp.dll ICMP Echo ping & network adapters)
      - TVeloxRingBuffer (O(1) rolling latency histories)
      - TVeloxGdiPlus (Card containers, status dots, sparklines & latency bars)
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
  Velox.Network;

type
  TVeloxPingTarget = record
    Address: string;
    LabelText: string;
    LastMs: Integer;
    IsOnline: Boolean;
    History: TVeloxRingBuffer;
    TotalPings: Integer;
    FailedPings: Integer;
  end;

  TVeloxNetworkMonitor = class(TCustomControl)
  private
    FTargets: array of TVeloxPingTarget;
    FTargetCount: Integer;
    FTimer: TTimer;
    FColors: TVeloxThemeColors;
    FAutoPing: Boolean;
    FOnPingComplete: TNotifyEvent;
    procedure HandleTimer(Sender: TObject);
    procedure SetAutoPing(const Value: Boolean);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    function AddHost(const AAddress, ALabel: string): Integer;
    procedure Clear;
    procedure PingAll;

    function HostCount: Integer;
    function GetLatency(const AIndex: Integer): Integer;
    function IsHostOnline(const AIndex: Integer): Boolean;
    function GetPacketLoss(const AIndex: Integer): Single;

    property AutoPing: Boolean read FAutoPing write SetAutoPing default True;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
    property OnPingComplete: TNotifyEvent read FOnPingComplete write FOnPingComplete;
  end;

implementation

constructor TVeloxNetworkMonitor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 460;
  Height := 280;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FTargetCount := 0;
  SetLength(FTargets, 0);

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 1000;
  FTimer.Enabled := True;
  FTimer.OnTimer := HandleTimer;
  FAutoPing := True;

  ApplyColors(FColors);
end;

destructor TVeloxNetworkMonitor.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure TVeloxNetworkMonitor.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  Invalidate;
end;

function TVeloxNetworkMonitor.AddHost(const AAddress, ALabel: string): Integer;
begin
  Inc(FTargetCount);
  SetLength(FTargets, FTargetCount);
  Result := FTargetCount - 1;
  FTargets[Result].Address := AAddress;
  FTargets[Result].LabelText := ALabel;
  FTargets[Result].LastMs := 0;
  FTargets[Result].IsOnline := True;
  FTargets[Result].History.Clear(30);
  FTargets[Result].TotalPings := 0;
  FTargets[Result].FailedPings := 0;
  Invalidate;
end;

procedure TVeloxNetworkMonitor.Clear;
begin
  FTargetCount := 0;
  SetLength(FTargets, 0);
  Invalidate;
end;

procedure TVeloxNetworkMonitor.PingAll;
var
  I: Integer;
  Rtt: Cardinal;
begin
  for I := 0 to FTargetCount - 1 do
  begin
    Inc(FTargets[I].TotalPings);
    if TVeloxPing.Ping(FTargets[I].Address, 400, Rtt) then
    begin
      FTargets[I].IsOnline := True;
      FTargets[I].LastMs := Integer(Rtt);
      FTargets[I].History.Add(Rtt);
    end
    else
    begin
      FTargets[I].IsOnline := False;
      FTargets[I].LastMs := 999;
      Inc(FTargets[I].FailedPings);
      FTargets[I].History.Add(999);
    end;
  end;
  Invalidate;
  if Assigned(FOnPingComplete) then
    FOnPingComplete(Self);
end;

procedure TVeloxNetworkMonitor.HandleTimer(Sender: TObject);
begin
  if FAutoPing and (FTargetCount > 0) then
    PingAll;
end;

procedure TVeloxNetworkMonitor.SetAutoPing(const Value: Boolean);
begin
  FAutoPing := Value;
  FTimer.Enabled := Value;
end;

function TVeloxNetworkMonitor.HostCount: Integer;
begin
  Result := FTargetCount;
end;

function TVeloxNetworkMonitor.GetLatency(const AIndex: Integer): Integer;
begin
  if (AIndex >= 0) and (AIndex < FTargetCount) then
    Result := FTargets[AIndex].LastMs
  else
    Result := -1;
end;

function TVeloxNetworkMonitor.IsHostOnline(const AIndex: Integer): Boolean;
begin
  if (AIndex >= 0) and (AIndex < FTargetCount) then
    Result := FTargets[AIndex].IsOnline
  else
    Result := False;
end;

function TVeloxNetworkMonitor.GetPacketLoss(const AIndex: Integer): Single;
begin
  if (AIndex >= 0) and (AIndex < FTargetCount) and (FTargets[AIndex].TotalPings > 0) then
    Result := (FTargets[AIndex].FailedPings * 100.0) / FTargets[AIndex].TotalPings
  else
    Result := 0.0;
end;

procedure TVeloxNetworkMonitor.Paint;
var
  I, RowY, MidY: Integer;
  RowR, SparkR, TextR: TRect;
  DotColor: TColor;
  HeaderTitle, StatusStr, LatencyStr: string;
begin
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);

  // Header Title
  HeaderTitle := 'NETWORK HOSTS & LATENCY MONITOR';
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := FColors.TextSecondary;
  TextR := Rect(14, 8, Width - 14, 28);
  DrawText(Canvas.Handle, PChar(HeaderTitle), -1,
    TextR, DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  for I := 0 to FTargetCount - 1 do
  begin
    RowY := 36 + I * 54;
    RowR := Rect(12, RowY, Width - 12, RowY + 48);

    // Card background
    TVeloxGdiPlus.DrawCard(Canvas, RowR, FColors.SurfaceCard, FColors.Border, 6);

    MidY := RowY + 24;

    // Status dot (10px diameter)
    if FTargets[I].IsOnline then
      DotColor := $10B981 // Emerald
    else
      DotColor := $F43F5E; // Rose red

    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := DotColor;
    Canvas.Pen.Color := DotColor;
    Canvas.Ellipse(RowR.Left + 14, MidY - 5, RowR.Left + 24, MidY + 5);

    // Host Label & Address
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := FColors.TextPrimary;
    TextR := Rect(RowR.Left + 32, RowY + 6, RowR.Left + 200, RowY + 26);
    DrawText(Canvas.Handle, PChar(FTargets[I].LabelText), -1, TextR,
      DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_END_ELLIPSIS);

    Canvas.Font.Size := 8;
    Canvas.Font.Style := [];
    Canvas.Font.Color := FColors.TextSecondary;
    TextR := Rect(RowR.Left + 32, RowY + 26, RowR.Left + 200, RowY + 44);
    DrawText(Canvas.Handle, PChar(FTargets[I].Address), -1, TextR,
      DT_SINGLELINE or DT_VCENTER or DT_LEFT);

    // Mini Sparkline (Width 100px)
    SparkR := Rect(RowR.Right - 210, RowY + 10, RowR.Right - 90, RowY + 38);
    TVeloxGdiPlus.DrawSparkline(Canvas, SparkR, FTargets[I].History.ToArray, FColors.Accent,
      TVeloxUtils.BlendColor(FColors.SurfaceCard, FColors.Accent, 0.25));

    // Latency badge on right
    if FTargets[I].IsOnline then
      LatencyStr := Format('%d ms', [FTargets[I].LastMs])
    else
      LatencyStr := 'TIMEOUT';

    TVeloxGdiPlus.DrawCard(Canvas, Rect(RowR.Right - 80, RowY + 12, RowR.Right - 10, RowY + 36),
      TVeloxUtils.BlendColor(FColors.SurfaceCard, DotColor, 0.20), DotColor, 4);

    Canvas.Font.Size := 8;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := DotColor;
    TextR := Rect(RowR.Right - 80, RowY + 12, RowR.Right - 10, RowY + 36);
    DrawText(Canvas.Handle, PChar(LatencyStr), -1, TextR,
      DT_SINGLELINE or DT_VCENTER or DT_CENTER);
  end;
end;

end.
