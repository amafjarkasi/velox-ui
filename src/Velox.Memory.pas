unit Velox.Memory;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Velox.Types;

type
  TVeloxSystemMemory = record
    TotalPhysicalBytes: UInt64;
    AvailPhysicalBytes: UInt64;
    UsedPhysicalBytes: UInt64;
    MemoryLoadPercent: Cardinal; // 0..100
    TotalPageFileBytes: UInt64;
    AvailPageFileBytes: UInt64;
  end;

  TVeloxProcessMemory = record
    ProcessId: Cardinal;
    WorkingSetBytes: UInt64;
    PeakWorkingSetBytes: UInt64;
    PrivateBytes: UInt64;
    PeakPrivateBytes: UInt64;
    PageFaultCount: Cardinal;
  end;

  TVeloxMemory = class
  public
    /// <summary>Queries system-wide physical RAM and pagefile metrics via GlobalMemoryStatusEx.</summary>
    class function GetSystemMemory: TVeloxSystemMemory; static;
    /// <summary>Queries Working Set and Private Commit bytes for a target process (or current process if PID=0).</summary>
    class function GetProcessMemory(const APID: Cardinal = 0): TVeloxProcessMemory; static;
    /// <summary>Returns a formatted single-line telemetry string (e.g. "RAM: 42% (6.8 / 16.0 GB) | App: 48 MB").</summary>
    class function FormatMemorySummary(const APID: Cardinal = 0): string; static;
  end;

implementation

type
  _MEMORYSTATUSEX = record
    dwLength: DWORD;
    dwMemoryLoad: DWORD;
    ullTotalPhys: UInt64;
    ullAvailPhys: UInt64;
    ullTotalPageFile: UInt64;
    ullAvailPageFile: UInt64;
    ullTotalVirtual: UInt64;
    ullAvailVirtual: UInt64;
    ullAvailExtendedVirtual: UInt64;
  end;
  MEMORYSTATUSEX = _MEMORYSTATUSEX;

  _PROCESS_MEMORY_COUNTERS_EX = record
    cb: DWORD;
    PageFaultCount: DWORD;
    PeakWorkingSetSize: SIZE_T;
    WorkingSetSize: SIZE_T;
    QuotaPeakPagedPoolUsage: SIZE_T;
    QuotaPagedPoolUsage: SIZE_T;
    QuotaPeakNonPagedPoolUsage: SIZE_T;
    QuotaNonPagedPoolUsage: SIZE_T;
    PagefileUsage: SIZE_T;
    PeakPagefileUsage: SIZE_T;
    PrivateUsage: SIZE_T;
  end;
  PROCESS_MEMORY_COUNTERS_EX = _PROCESS_MEMORY_COUNTERS_EX;

function GlobalMemoryStatusEx(var lpBuffer: MEMORYSTATUSEX): BOOL;
  stdcall; external 'kernel32.dll' name 'GlobalMemoryStatusEx';

function GetProcessMemoryInfo(Process: THandle; var ppsmemCounters: PROCESS_MEMORY_COUNTERS_EX; cb: DWORD): BOOL;
  stdcall; external 'psapi.dll' name 'GetProcessMemoryInfo';

{ TVeloxMemory }

class function TVeloxMemory.GetSystemMemory: TVeloxSystemMemory;
var
  MemStatus: MEMORYSTATUSEX;
begin
  FillChar(Result, SizeOf(Result), 0);
  FillChar(MemStatus, SizeOf(MemStatus), 0);
  MemStatus.dwLength := SizeOf(MemStatus);

  if GlobalMemoryStatusEx(MemStatus) then
  begin
    Result.TotalPhysicalBytes := MemStatus.ullTotalPhys;
    Result.AvailPhysicalBytes := MemStatus.ullAvailPhys;
    if MemStatus.ullTotalPhys >= MemStatus.ullAvailPhys then
      Result.UsedPhysicalBytes := MemStatus.ullTotalPhys - MemStatus.ullAvailPhys
    else
      Result.UsedPhysicalBytes := 0;

    Result.MemoryLoadPercent  := MemStatus.dwMemoryLoad;
    Result.TotalPageFileBytes := MemStatus.ullTotalPageFile;
    Result.AvailPageFileBytes := MemStatus.ullAvailPageFile;
  end;
end;

class function TVeloxMemory.GetProcessMemory(const APID: Cardinal): TVeloxProcessMemory;
var
  hProc: THandle;
  PMC: PROCESS_MEMORY_COUNTERS_EX;
  TargetPID: Cardinal;
begin
  FillChar(Result, SizeOf(Result), 0);

  if APID = 0 then
    TargetPID := GetCurrentProcessId
  else
    TargetPID := APID;

  Result.ProcessId := TargetPID;

  hProc := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, TargetPID);
  if hProc = 0 then
    hProc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, TargetPID);

  if hProc <> 0 then
  begin
    try
      FillChar(PMC, SizeOf(PMC), 0);
      PMC.cb := SizeOf(PMC);
      if GetProcessMemoryInfo(hProc, PMC, SizeOf(PMC)) then
      begin
        Result.WorkingSetBytes     := PMC.WorkingSetSize;
        Result.PeakWorkingSetBytes := PMC.PeakWorkingSetSize;
        Result.PrivateBytes        := PMC.PrivateUsage;
        if Result.PrivateBytes = 0 then
          Result.PrivateBytes      := PMC.PagefileUsage;
        Result.PeakPrivateBytes    := PMC.PeakPagefileUsage;
        Result.PageFaultCount      := PMC.PageFaultCount;
      end;
    finally
      CloseHandle(hProc);
    end;
  end;
end;

class function TVeloxMemory.FormatMemorySummary(const APID: Cardinal): string;
var
  SysMem: TVeloxSystemMemory;
  ProcMem: TVeloxProcessMemory;
begin
  SysMem := GetSystemMemory;
  ProcMem := GetProcessMemory(APID);

  Result := Format('RAM: %d%% (%s / %s) | App: %s', [
    SysMem.MemoryLoadPercent,
    TVeloxUtils.FormatBytes(SysMem.UsedPhysicalBytes),
    TVeloxUtils.FormatBytes(SysMem.TotalPhysicalBytes),
    TVeloxUtils.FormatBytes(ProcMem.WorkingSetBytes)
  ]);
end;

end.
