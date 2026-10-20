unit Velox.Updater;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Updater
  Purpose:
    Self-update engine (`TVeloxUpdater`) driven by the GitHub Releases API.
    Combines `Velox.Http` + `Velox.Json`: semantic-version comparison,
    release/asset selection, download with progress, and a detached batch
    script that waits for the running exe to exit, swaps the binary, and
    restarts it.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Velox.Json,
  Velox.Http;

type
  TVeloxUpdateInfo = record
    Ok: Boolean;
    Available: Boolean;
    ErrorText: string;
    CurrentVersion: string;
    LatestVersion: string;
    AssetName: string;
    AssetUrl: string;
    ReleaseNotes: string;
    HtmlUrl: string;
  end;

  /// <summary>
  /// GitHub Releases based self-updater
  /// </summary>
  TVeloxUpdater = class
  public
    /// <summary>Semantic compare: -1 if A &lt; B, 0 if equal, 1 if A &gt; B (handles v-prefix and -prerelease).</summary>
    class function CompareVersions(const A, B: string): Integer; static;

    /// <summary>Parses a GitHub "latest release" JSON document (offline-testable).</summary>
    class function ParseRelease(const AJson, ACurrentVersion: string;
      const AAssetSuffix: string = '.exe'): TVeloxUpdateInfo; static;

    /// <summary>Queries https://api.github.com/repos/{owner}/{repo}/releases/latest.</summary>
    class function CheckLatest(const AOwner, ARepo, ACurrentVersion: string;
      const AAssetSuffix: string = '.exe'): TVeloxUpdateInfo; static;

    class function DownloadUpdate(const AInfo: TVeloxUpdateInfo;
      const ADestPath: string; const AProgress: TVeloxProgressProc = nil): Boolean; static;

    /// <summary>Builds the batch script that swaps ATargetExe with ANewExe once PID exits.</summary>
    class function BuildSwapScript(const ANewExe, ATargetExe: string;
      const APid: Cardinal): string; static;

    /// <summary>Writes + launches the swap script (hidden). Caller should terminate the app afterwards.</summary>
    class function ApplyUpdateAndRestart(const ANewExe: string): Boolean; static;
  end;

implementation

type
  TVerParts = array[0..3] of Integer;

procedure ParseVer(const S: string; out AParts: TVerParts; out APre: Boolean);
var
  T, Seg: string;
  I, P, N: Integer;
begin
  for I := 0 to 3 do
    AParts[I] := 0;
  APre := False;
  T := Trim(S);
  if (T <> '') and (UpCase(T[1]) = 'V') then
    Delete(T, 1, 1);
  P := Pos('+', T);
  if P > 0 then T := Copy(T, 1, P - 1);
  P := Pos('-', T);
  if P > 0 then
  begin
    APre := True;
    T := Copy(T, 1, P - 1);
  end;
  N := 0;
  while (T <> '') and (N < 4) do
  begin
    P := Pos('.', T);
    if P > 0 then
    begin
      Seg := Copy(T, 1, P - 1);
      T := Copy(T, P + 1, MaxInt);
    end
    else
    begin
      Seg := T;
      T := '';
    end;
    AParts[N] := StrToIntDef(Seg, 0);
    Inc(N);
  end;
end;

class function TVeloxUpdater.CompareVersions(const A, B: string): Integer;
var
  PA, PB: TVerParts;
  PreA, PreB: Boolean;
  I: Integer;
begin
  ParseVer(A, PA, PreA);
  ParseVer(B, PB, PreB);
  for I := 0 to 3 do
  begin
    if PA[I] < PB[I] then Exit(-1);
    if PA[I] > PB[I] then Exit(1);
  end;
  if PreA and (not PreB) then Exit(-1);
  if (not PreA) and PreB then Exit(1);
  Result := 0;
end;

class function TVeloxUpdater.ParseRelease(const AJson, ACurrentVersion,
  AAssetSuffix: string): TVeloxUpdateInfo;
var
  Doc, Assets, Asset, Tag: TVeloxJson;
  Err, Name, Suffix: string;
  I: Integer;
begin
  Result.Ok := False;
  Result.Available := False;
  Result.ErrorText := '';
  Result.CurrentVersion := ACurrentVersion;
  Result.LatestVersion := '';
  Result.AssetName := '';
  Result.AssetUrl := '';
  Result.ReleaseNotes := '';
  Result.HtmlUrl := '';

  Doc := TVeloxJson.Parse(AJson, Err);
  if Doc = nil then
  begin
    Result.ErrorText := 'Invalid release JSON: ' + Err;
    Exit;
  end;
  try
    Tag := Doc.Find('tag_name');
    if Tag = nil then
    begin
      Result.ErrorText := 'Release has no tag_name';
      Exit;
    end;
    Result.LatestVersion := Tag.AsString;
    if (Result.LatestVersion <> '') and (UpCase(Result.LatestVersion[1]) = 'V') then
      Delete(Result.LatestVersion, 1, 1);
    if Doc.Find('body') <> nil then
      Result.ReleaseNotes := Doc.Find('body').AsString;
    if Doc.Find('html_url') <> nil then
      Result.HtmlUrl := Doc.Find('html_url').AsString;

    Suffix := LowerCase(AAssetSuffix);
    Assets := Doc.Find('assets');
    if (Assets <> nil) and (Assets.Kind = jkArray) then
    begin
      for I := 0 to Assets.Count - 1 do
      begin
        Asset := Assets[I];
        if Asset = nil then Continue;
        if Asset.Find('name') = nil then Continue;
        Name := Asset.Find('name').AsString;
        if (Suffix = '') or (Copy(LowerCase(Name), Length(Name) - Length(Suffix) + 1, Length(Suffix)) = Suffix) then
        begin
          Result.AssetName := Name;
          if Asset.Find('browser_download_url') <> nil then
            Result.AssetUrl := Asset.Find('browser_download_url').AsString;
          Break;
        end;
      end;
    end;

    Result.Ok := True;
    Result.Available := CompareVersions(Result.LatestVersion, ACurrentVersion) > 0;
  finally
    Doc.Free;
  end;
end;

class function TVeloxUpdater.CheckLatest(const AOwner, ARepo, ACurrentVersion,
  AAssetSuffix: string): TVeloxUpdateInfo;
var
  Resp: TVeloxHttpResponse;
begin
  Resp := TVeloxHttp.Get(
    Format('https://api.github.com/repos/%s/%s/releases/latest', [AOwner, ARepo]),
    'Accept: application/vnd.github+json' + #13#10 + 'X-GitHub-Api-Version: 2022-11-28');
  if not Resp.Ok then
  begin
    Result.Ok := False;
    Result.Available := False;
    Result.ErrorText := Resp.ErrorText;
    Result.CurrentVersion := ACurrentVersion;
    Result.LatestVersion := '';
    Result.AssetName := '';
    Result.AssetUrl := '';
    Result.ReleaseNotes := '';
    Result.HtmlUrl := '';
    Exit;
  end;
  Result := ParseRelease(Resp.Body, ACurrentVersion, AAssetSuffix);
end;

class function TVeloxUpdater.DownloadUpdate(const AInfo: TVeloxUpdateInfo;
  const ADestPath: string; const AProgress: TVeloxProgressProc): Boolean;
var
  Resp: TVeloxHttpResponse;
begin
  Result := False;
  if AInfo.AssetUrl = '' then Exit;
  Resp := TVeloxHttp.DownloadToFile(AInfo.AssetUrl, ADestPath, AProgress);
  Result := Resp.Ok and FileExists(ADestPath);
end;

class function TVeloxUpdater.BuildSwapScript(const ANewExe, ATargetExe: string;
  const APid: Cardinal): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Add('@echo off');
    L.Add(':wait');
    L.Add(Format('tasklist /FI "PID eq %d" 2>nul | find "%d" >nul', [APid, APid]));
    L.Add('if not errorlevel 1 (');
    L.Add('  ping 127.0.0.1 -n 2 >nul');
    L.Add('  goto wait');
    L.Add(')');
    L.Add(Format('copy /Y "%s" "%s" >nul', [ANewExe, ATargetExe]));
    L.Add(Format('start "" "%s"', [ATargetExe]));
    L.Add('del "%~f0"');
    Result := L.Text;
  finally
    L.Free;
  end;
end;

class function TVeloxUpdater.ApplyUpdateAndRestart(const ANewExe: string): Boolean;
var
  ScriptPath: string;
  CmdW: WideString;
  L: TStringList;
  SI: TStartupInfoW;
  PI: TProcessInformation;
begin
  Result := False;
  if not FileExists(ANewExe) then Exit;
  ScriptPath := ChangeFileExt(ANewExe, '.swap.cmd');
  L := TStringList.Create;
  try
    L.Text := BuildSwapScript(ANewExe, ParamStr(0), GetCurrentProcessId);
    L.SaveToFile(ScriptPath);
  finally
    L.Free;
  end;
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  FillChar(PI, SizeOf(PI), 0);
  CmdW := WideString('cmd.exe /C "' + ScriptPath + '"');
  UniqueString(CmdW);
  if CreateProcessW(nil, PWideChar(CmdW), nil, nil, False, CREATE_NO_WINDOW, nil, nil, SI, PI) then
  begin
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
    Result := True;
  end;
end;

end.
