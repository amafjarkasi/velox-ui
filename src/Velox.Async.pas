unit Velox.Async;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Async
  Purpose:
    1. Generic interruptible background polling engine (`TVeloxPoller<T>`)
       that executes expensive I/O or Win32/NT kernel queries off the main GUI
       thread and marshals snapshots to the UI via `TThread.Queue`.
       Uses 50ms sleep slices so application shutdown is instantaneous (<50ms)
       even when polling interval is 5000ms.
    2. Hysteresis + Streak + Cooldown threshold alert state machine
       (`TVeloxThresholdAlert`) to prevent notification spam on noisy metrics.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Velox.Types;

type
  TVeloxCollectFunc<T> = function: T of object;
  TVeloxDeliverProc<T> = procedure(const AData: T) of object;

  /// <summary>
  /// Internal worker thread for TVeloxPoller<T>
  /// </summary>
  TVeloxWorkerThread<T> = class(TThread)
  private
    FIntervalMs: Cardinal;
    FOnCollect: TVeloxCollectFunc<T>;
    FOnDeliver: TVeloxDeliverProc<T>;
    FPendingData: T;
    procedure SyncDeliver;
  protected
    procedure Execute; override;
  public
    constructor Create(const AIntervalMs: Cardinal;
      const AOnCollect: TVeloxCollectFunc<T>;
      const AOnDeliver: TVeloxDeliverProc<T>);
    property IntervalMs: Cardinal read FIntervalMs write FIntervalMs;
  end;

  /// <summary>
  /// Generic async background poller with live interval control and
  /// sub-50ms interruptible shutdown.
  /// </summary>
  TVeloxPoller<T> = class
  private
    FWorker: TVeloxWorkerThread<T>;
    FIntervalMs: Cardinal;
    FOnCollect: TVeloxCollectFunc<T>;
    FOnDeliver: TVeloxDeliverProc<T>;
    function GetIsRunning: Boolean;
  public
    constructor Create(const AIntervalMs: Cardinal;
      const AOnCollect: TVeloxCollectFunc<T>;
      const AOnDeliver: TVeloxDeliverProc<T>);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;
    procedure Toggle;
    procedure SetInterval(const AIntervalMs: Cardinal);

    property IsRunning: Boolean read GetIsRunning;
    property IntervalMs: Cardinal read FIntervalMs;
  end;

  /// <summary>
  /// Reusable threshold alert detector with sustained-streak gating,
  /// cooldown suppression, and hysteresis recovery.
  /// </summary>
  TVeloxThresholdAlert = record
  private
    FWarningThreshold: Single;
    FDangerThreshold: Single;
    FHysteresisMargin: Single;
    FRequiredStreak: Integer;
    FCooldownMs: UInt64;
    FCurrentStreak: Integer;
    FLastAlertTick: UInt64;
    FActiveSeverity: TVeloxSeverity;
  public
    procedure Configure(const AWarning, ADanger: Single;
      const ARequiredStreak: Integer = 2;
      const ACooldownMs: UInt64 = 30000;
      const AHysteresisMargin: Single = 5.0);
    function Evaluate(const AValue: Single; const ANowTick: UInt64;
      out ANewSeverity: TVeloxSeverity): Boolean;
    property ActiveSeverity: TVeloxSeverity read FActiveSeverity;
    property CurrentStreak: Integer read FCurrentStreak;
  end;

implementation

{ TVeloxWorkerThread<T> }

constructor TVeloxWorkerThread<T>.Create(const AIntervalMs: Cardinal;
  const AOnCollect: TVeloxCollectFunc<T>;
  const AOnDeliver: TVeloxDeliverProc<T>);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIntervalMs := AIntervalMs;
  FOnCollect := AOnCollect;
  FOnDeliver := AOnDeliver;
  Start;
end;

procedure TVeloxWorkerThread<T>.SyncDeliver;
begin
  if (not Terminated) and Assigned(FOnDeliver) then
    FOnDeliver(FPendingData);
end;

procedure TVeloxWorkerThread<T>.Execute;
var
  SleepRemaining, StepMs: Integer;
begin
  while not Terminated do
  begin
    SleepRemaining := Integer(FIntervalMs);
    if SleepRemaining < 100 then
      SleepRemaining := 100;

    // 50ms interruptible slices guarantee <50ms thread join on app exit
    while (SleepRemaining > 0) and (not Terminated) do
    begin
      if SleepRemaining > 50 then
        StepMs := 50
      else
        StepMs := SleepRemaining;
      Sleep(StepMs);
      Dec(SleepRemaining, StepMs);
    end;

    if Terminated then Break;

    if Assigned(FOnCollect) and Assigned(FOnDeliver) then
    begin
      try
        FPendingData := FOnCollect();
        if not Terminated then
          Queue(SyncDeliver);
      except
        // Swallow transient collection exceptions to keep worker alive
      end;
    end;
  end;
end;

{ TVeloxPoller<T> }

constructor TVeloxPoller<T>.Create(const AIntervalMs: Cardinal;
  const AOnCollect: TVeloxCollectFunc<T>;
  const AOnDeliver: TVeloxDeliverProc<T>);
begin
  inherited Create;
  FWorker := nil;
  if AIntervalMs < 100 then
    FIntervalMs := 100
  else
    FIntervalMs := AIntervalMs;
  FOnCollect := AOnCollect;
  FOnDeliver := AOnDeliver;
end;

destructor TVeloxPoller<T>.Destroy;
begin
  Stop;
  inherited Destroy;
end;

function TVeloxPoller<T>.GetIsRunning: Boolean;
begin
  Result := Assigned(FWorker);
end;

procedure TVeloxPoller<T>.Start;
begin
  if Assigned(FWorker) then Exit;
  FWorker := TVeloxWorkerThread<T>.Create(FIntervalMs, FOnCollect, FOnDeliver);
end;

procedure TVeloxPoller<T>.Stop;
begin
  if Assigned(FWorker) then
  begin
    FWorker.Terminate;
    TThread.RemoveQueuedEvents(FWorker);
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
end;

procedure TVeloxPoller<T>.Toggle;
begin
  if IsRunning then
    Stop
  else
    Start;
end;

procedure TVeloxPoller<T>.SetInterval(const AIntervalMs: Cardinal);
begin
  if AIntervalMs < 100 then
    FIntervalMs := 100
  else
    FIntervalMs := AIntervalMs;
  if Assigned(FWorker) then
    FWorker.IntervalMs := FIntervalMs;
end;

{ TVeloxThresholdAlert }

procedure TVeloxThresholdAlert.Configure(const AWarning, ADanger: Single;
  const ARequiredStreak: Integer; const ACooldownMs: UInt64;
  const AHysteresisMargin: Single);
begin
  FWarningThreshold := AWarning;
  FDangerThreshold := ADanger;
  if ARequiredStreak < 1 then
    FRequiredStreak := 1
  else
    FRequiredStreak := ARequiredStreak;
  FCooldownMs := ACooldownMs;
  FHysteresisMargin := AHysteresisMargin;
  FCurrentStreak := 0;
  FLastAlertTick := 0;
  FActiveSeverity := vsNormal;
end;

function TVeloxThresholdAlert.Evaluate(const AValue: Single; const ANowTick: UInt64;
  out ANewSeverity: TVeloxSeverity): Boolean;
var
  Candidate: TVeloxSeverity;
begin
  Result := False;
  ANewSeverity := FActiveSeverity;

  if AValue >= FDangerThreshold then
    Candidate := vsCritical
  else if AValue >= FWarningThreshold then
    Candidate := vsWarning
  else
    Candidate := vsNormal;

  if Candidate in [vsWarning, vsCritical] then
  begin
    Inc(FCurrentStreak);
    if FCurrentStreak >= FRequiredStreak then
    begin
      if (Ord(Candidate) > Ord(FActiveSeverity)) or
         ((FLastAlertTick > 0) and ((ANowTick - FLastAlertTick) >= FCooldownMs)) then
      begin
        FActiveSeverity := Candidate;
        ANewSeverity := Candidate;
        FLastAlertTick := ANowTick;
        Result := True;
      end;
    end;
  end
  else
  begin
    // Hysteresis recovery: only clear active alert once value drops below Warning - HysteresisMargin
    if AValue <= (FWarningThreshold - FHysteresisMargin) then
    begin
      FCurrentStreak := 0;
      FActiveSeverity := vsNormal;
      ANewSeverity := vsNormal;
    end;
  end;
end;

end.
