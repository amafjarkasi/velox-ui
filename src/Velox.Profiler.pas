unit Velox.Profiler;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Profiler
  Purpose:
    High-Resolution Hardware `QueryPerformanceCounter` Micro-Profiler
    (`TVeloxStopwatch` & `TVeloxFrameProfiler`) inspired by `Spring4D` and
    `GpProfile`. Measures sub-millisecond GDI+ render passes and Win32/NT
    syscalls with microsecond precision and computes rolling Average, Peak,
    and P95 frame latencies.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Velox.Types;

type
  /// <summary>
  /// Sub-microsecond hardware stopwatch backed by QueryPerformanceCounter
  /// </summary>
  TVeloxStopwatch = record
  private
    FStartTicks: Int64;
    FStopTicks: Int64;
    FFreq: Int64;
    FRunning: Boolean;
    function GetCurrentTicks: Int64;
  public
    class function StartNew: TVeloxStopwatch; static;
    procedure Start;
    procedure Stop;
    procedure Reset;
    function ElapsedMicroseconds: Int64;
    function ElapsedMillisecondsFloat: Double;
    property IsRunning: Boolean read FRunning;
  end;

  /// <summary>
  /// Rolling frame/operation latency tracker (Avg, Peak, P95 in milliseconds)
  /// </summary>
  TVeloxFrameProfiler = class
  private
    FSamples: TVeloxRingBuffer;
  public
    constructor Create(const ACapacity: Integer = 60);
    procedure RecordSampleMs(const AElapsedMs: Single);
    procedure Clear;

    function AverageMs: Single;
    function PeakMs: Single;
    function P95Ms: Single;
    function SampleCount: Integer;
    function FormatSummary(const ALabel: string = 'Render'): string;
  end;

implementation

{ TVeloxStopwatch }

function TVeloxStopwatch.GetCurrentTicks: Int64;
begin
  Result := 0;
  QueryPerformanceCounter(Result);
end;

class function TVeloxStopwatch.StartNew: TVeloxStopwatch;
begin
  Result.FFreq := 0;
  QueryPerformanceFrequency(Result.FFreq);
  if Result.FFreq <= 0 then
    Result.FFreq := 1000000;
  Result.FStartTicks := 0;
  QueryPerformanceCounter(Result.FStartTicks);
  Result.FStopTicks := Result.FStartTicks;
  Result.FRunning := True;
end;

procedure TVeloxStopwatch.Start;
begin
  if FFreq <= 0 then
    QueryPerformanceFrequency(FFreq);
  if FFreq <= 0 then
    FFreq := 1000000;
  QueryPerformanceCounter(FStartTicks);
  FRunning := True;
end;

procedure TVeloxStopwatch.Stop;
begin
  if FRunning then
  begin
    QueryPerformanceCounter(FStopTicks);
    FRunning := False;
  end;
end;

procedure TVeloxStopwatch.Reset;
begin
  QueryPerformanceCounter(FStartTicks);
  FStopTicks := FStartTicks;
  FRunning := False;
end;

function TVeloxStopwatch.ElapsedMicroseconds: Int64;
var
  EndTicks: Int64;
begin
  if FRunning then
    EndTicks := GetCurrentTicks
  else
    EndTicks := FStopTicks;
  if FFreq <= 0 then
    Exit(0);
  Result := ((EndTicks - FStartTicks) * 1000000) div FFreq;
end;

function TVeloxStopwatch.ElapsedMillisecondsFloat: Double;
var
  EndTicks: Int64;
begin
  if FRunning then
    EndTicks := GetCurrentTicks
  else
    EndTicks := FStopTicks;
  if FFreq <= 0 then
    Exit(0.0);
  Result := ((EndTicks - FStartTicks) * 1000.0) / FFreq;
end;

{ TVeloxFrameProfiler }

constructor TVeloxFrameProfiler.Create(const ACapacity: Integer);
begin
  inherited Create;
  FSamples.Clear(ACapacity);
end;

procedure TVeloxFrameProfiler.RecordSampleMs(const AElapsedMs: Single);
begin
  FSamples.Add(AElapsedMs);
end;

procedure TVeloxFrameProfiler.Clear;
begin
  FSamples.Clear(FSamples.Capacity);
end;

function TVeloxFrameProfiler.AverageMs: Single;
begin
  Result := FSamples.Average;
end;

function TVeloxFrameProfiler.PeakMs: Single;
begin
  Result := FSamples.Peak;
end;

function TVeloxFrameProfiler.SampleCount: Integer;
begin
  Result := FSamples.Count;
end;

function TVeloxFrameProfiler.P95Ms: Single;
var
  Arr: TSingleDynArray;
  I, J, Idx95: Integer;
  Tmp: Single;
begin
  Arr := FSamples.ToArray;
  if Length(Arr) = 0 then
    Exit(0.0);

  for I := 0 to High(Arr) - 1 do
    for J := I + 1 to High(Arr) do
      if Arr[J] < Arr[I] then
      begin
        Tmp := Arr[I];
        Arr[I] := Arr[J];
        Arr[J] := Tmp;
      end;

  Idx95 := Round((Length(Arr) - 1) * 0.95);
  if Idx95 < 0 then Idx95 := 0;
  if Idx95 > High(Arr) then Idx95 := High(Arr);
  Result := Arr[Idx95];
end;

function TVeloxFrameProfiler.FormatSummary(const ALabel: string): string;
begin
  Result := Format('%s: Avg %.2f ms | P95 %.2f ms | Max %.2f ms (%d samples)',
    [ALabel, AverageMs, P95Ms, PeakMs, SampleCount]);
end;

end.
