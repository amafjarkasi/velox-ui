unit Velox.Power;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes;

type
  TVeloxPowerStatus = record
    IsOnAcPower: Boolean;
    IsBatteryPresent: Boolean;
    IsCharging: Boolean;
    IsBatterySaverActive: Boolean;
    BatteryPercent: Integer;        // 0..100, or -1 if unknown / no battery
    EstimatedLifeRemainingSec: Int64; // Seconds remaining, or -1 if unknown
    EstimatedFullLifeSec: Int64;    // Seconds full capacity, or -1 if unknown
    StatusDescription: string;
  end;

  TVeloxPower = class
  private
    class function FetchNativePowerStatus(out ACStatus, BattFlag, BattPct, SaverFlag: Byte;
      out LifeSec, FullLifeSec: Cardinal): Boolean; static;
  public
    class function GetPowerStatus: TVeloxPowerStatus; static;
    class function IsOnAcPower: Boolean; static;
    class function IsBatteryPresent: Boolean; static;
    class function BatteryPercent: Integer; static;
    class function IsCharging: Boolean; static;
    class function IsBatterySaverActive: Boolean; static;
    class function FormatRemainingTime(Seconds: Int64): string; static;
  end;

implementation

type
  _SYSTEM_POWER_STATUS = record
    ACLineStatus: Byte;
    BatteryFlag: Byte;
    BatteryLifePercent: Byte;
    SystemStatusFlag: Byte;
    BatteryLifeTime: DWORD;
    BatteryFullLifeTime: DWORD;
  end;

function WinGetSystemPowerStatus(var lpSystemPowerStatus: _SYSTEM_POWER_STATUS): BOOL;
  stdcall; external 'kernel32.dll' name 'GetSystemPowerStatus';

{ TVeloxPower }

class function TVeloxPower.FetchNativePowerStatus(out ACStatus, BattFlag, BattPct, SaverFlag: Byte;
  out LifeSec, FullLifeSec: Cardinal): Boolean;
var
  SPS: _SYSTEM_POWER_STATUS;
begin
  FillChar(SPS, SizeOf(SPS), 0);
  Result := WinGetSystemPowerStatus(SPS);
  if Result then
  begin
    ACStatus := SPS.ACLineStatus;
    BattFlag := SPS.BatteryFlag;
    BattPct := SPS.BatteryLifePercent;
    SaverFlag := SPS.SystemStatusFlag;
    LifeSec := SPS.BatteryLifeTime;
    FullLifeSec := SPS.BatteryFullLifeTime;
  end
  else
  begin
    ACStatus := 255;
    BattFlag := 255;
    BattPct := 255;
    SaverFlag := 0;
    LifeSec := $FFFFFFFF;
    FullLifeSec := $FFFFFFFF;
  end;
end;

class function TVeloxPower.FormatRemainingTime(Seconds: Int64): string;
var
  H, M: Int64;
begin
  if Seconds < 0 then
    Result := 'Unknown'
  else if Seconds < 60 then
    Result := Format('%d sec', [Seconds])
  else
  begin
    H := Seconds div 3600;
    M := (Seconds mod 3600) div 60;
    if H > 0 then
      Result := Format('%dh %dm', [H, M])
    else
      Result := Format('%dm', [M]);
  end;
end;

class function TVeloxPower.GetPowerStatus: TVeloxPowerStatus;
var
  AC, Flag, Pct, Saver: Byte;
  Life, FullLife: Cardinal;
  Desc: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  if not FetchNativePowerStatus(AC, Flag, Pct, Saver, Life, FullLife) then
  begin
    Result.BatteryPercent := -1;
    Result.EstimatedLifeRemainingSec := -1;
    Result.EstimatedFullLifeSec := -1;
    Result.StatusDescription := 'Power status unavailable';
    Exit;
  end;

  Result.IsOnAcPower := (AC = 1);
  Result.IsBatteryPresent := (Flag and 128 = 0) and (Flag <> 255);
  Result.IsCharging := (Flag and 8 <> 0);
  Result.IsBatterySaverActive := (Saver = 1);

  if Pct <= 100 then
    Result.BatteryPercent := Pct
  else
    Result.BatteryPercent := -1;

  if Life <> $FFFFFFFF then
    Result.EstimatedLifeRemainingSec := Life
  else
    Result.EstimatedLifeRemainingSec := -1;

  if FullLife <> $FFFFFFFF then
    Result.EstimatedFullLifeSec := FullLife
  else
    Result.EstimatedFullLifeSec := -1;

  // Build readable description
  if not Result.IsBatteryPresent then
  begin
    if Result.IsOnAcPower then
      Desc := 'Desktop / AC Line Powered (No Battery)'
    else
      Desc := 'No Battery Detected';
  end
  else
  begin
    if Result.BatteryPercent >= 0 then
      Desc := Format('%d%%', [Result.BatteryPercent])
    else
      Desc := 'Battery';

    if Result.IsCharging then
      Desc := Desc + ' (Charging, AC)'
    else if Result.IsOnAcPower then
      Desc := Desc + ' (Fully Charged, AC Connected)'
    else
    begin
      Desc := Desc + ' (On Battery';
      if Result.EstimatedLifeRemainingSec > 0 then
        Desc := Desc + ', ' + FormatRemainingTime(Result.EstimatedLifeRemainingSec) + ' remaining';
      Desc := Desc + ')';
    end;

    if Result.IsBatterySaverActive then
      Desc := Desc + ' [Battery Saver On]';
  end;

  Result.StatusDescription := Desc;
end;

class function TVeloxPower.IsOnAcPower: Boolean;
var
  AC, Flag, Pct, Saver: Byte;
  Life, FullLife: Cardinal;
begin
  if FetchNativePowerStatus(AC, Flag, Pct, Saver, Life, FullLife) then
    Result := (AC = 1)
  else
    Result := True; // Default safe assumption on desktop
end;

class function TVeloxPower.IsBatteryPresent: Boolean;
var
  AC, Flag, Pct, Saver: Byte;
  Life, FullLife: Cardinal;
begin
  if FetchNativePowerStatus(AC, Flag, Pct, Saver, Life, FullLife) then
    Result := (Flag and 128 = 0) and (Flag <> 255)
  else
    Result := False;
end;

class function TVeloxPower.BatteryPercent: Integer;
var
  AC, Flag, Pct, Saver: Byte;
  Life, FullLife: Cardinal;
begin
  if FetchNativePowerStatus(AC, Flag, Pct, Saver, Life, FullLife) and (Pct <= 100) then
    Result := Pct
  else
    Result := -1;
end;

class function TVeloxPower.IsCharging: Boolean;
var
  AC, Flag, Pct, Saver: Byte;
  Life, FullLife: Cardinal;
begin
  if FetchNativePowerStatus(AC, Flag, Pct, Saver, Life, FullLife) then
    Result := (Flag and 8 <> 0)
  else
    Result := False;
end;

class function TVeloxPower.IsBatterySaverActive: Boolean;
var
  AC, Flag, Pct, Saver: Byte;
  Life, FullLife: Cardinal;
begin
  if FetchNativePowerStatus(AC, Flag, Pct, Saver, Life, FullLife) then
    Result := (Saver = 1)
  else
    Result := False;
end;

end.
