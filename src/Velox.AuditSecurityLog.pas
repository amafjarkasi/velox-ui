unit Velox.AuditSecurityLog;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.AuditSecurityLog (#71)
  Purpose:
    Composite Real-Time File Integrity & Audit Security Tracker combining:
      - TVeloxFileWatcher (Non-blocking Win32 ReadDirectoryChangesW)
      - TVeloxCrypto (BCrypt CNG SHA-256 / SHA-1 cryptographic fingerprinting)
      - TVeloxTimeline (Chronological event audit nodes with severity colors)
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
  Velox.FileWatcher,
  Velox.Crypto,
  Velox.Timeline;

type
  TVeloxAuditSecurityLog = class(TCustomControl)
  private
    FWatcher: TVeloxFileWatcher;
    FTimeline: TVeloxTimeline;
    FTopBar: TPanel;
    FColors: TVeloxThemeColors;
    FDirectory: string;
    FIsActive: Boolean;
    function GetEventCount: Integer;
    procedure HandleFileEvent(Sender: TObject; const AAction: TVeloxFileAction; const ARelPath, AOldRelPath: string);
    procedure TopBarPaint(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure StartWatch(const ADirectory: string);
    procedure StopWatch;
    procedure ClearLog;
    procedure LogEvent(const ATitle, ADetail: string; const ASeverity: TVeloxSeverity = vsNormal);

    property Timeline: TVeloxTimeline read FTimeline;
    property Directory: string read FDirectory;
    property IsActive: Boolean read FIsActive;
    property EventCount: Integer read GetEventCount;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxAuditSecurityLog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 460;
  Height := 380;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FDirectory := '';
  FIsActive := False;

  // 1. Top Panel
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.Align := alTop;
  FTopBar.Height := 40;
  FTopBar.BevelOuter := bvNone;
  FTopBar.Color := FColors.Surface;
  FTopBar.OnPaint := TopBarPaint;

  // 2. Timeline
  FTimeline := TVeloxTimeline.Create(Self);
  FTimeline.Parent := Self;
  FTimeline.Align := alClient;

  // 3. File Watcher
  FWatcher := TVeloxFileWatcher.Create(Self);
  FWatcher.OnChanged := HandleFileEvent;

  ApplyColors(FColors);
end;

destructor TVeloxAuditSecurityLog.Destroy;
begin
  FWatcher.Stop;
  FWatcher.Free;
  inherited Destroy;
end;

procedure TVeloxAuditSecurityLog.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  if Assigned(FTopBar) then FTopBar.Color := FColors.Surface;
  if Assigned(FTimeline) then FTimeline.ApplyColors(FColors);
  Invalidate;
end;

procedure TVeloxAuditSecurityLog.StartWatch(const ADirectory: string);
begin
  FDirectory := ADirectory;
  FWatcher.Directory := ADirectory;
  FWatcher.Start;
  FIsActive := True;
  LogEvent('Audit Monitoring Started', 'Watching: ' + ADirectory, vsNormal);
  FTopBar.Invalidate;
end;

procedure TVeloxAuditSecurityLog.StopWatch;
begin
  FWatcher.Stop;
  FIsActive := False;
  LogEvent('Audit Monitoring Stopped', 'Directory watcher paused', vsWarning);
  FTopBar.Invalidate;
end;

procedure TVeloxAuditSecurityLog.ClearLog;
begin
  FTimeline.Clear;
end;

function TVeloxAuditSecurityLog.GetEventCount: Integer;
begin
  if Assigned(FTimeline) then
    Result := FTimeline.Count
  else
    Result := 0;
end;

procedure TVeloxAuditSecurityLog.LogEvent(const ATitle, ADetail: string; const ASeverity: TVeloxSeverity);
begin
  FTimeline.AddItem(FormatDateTime('hh:nn:ss', Now), ATitle, ADetail, ASeverity);
end;

procedure TVeloxAuditSecurityLog.HandleFileEvent(Sender: TObject; const AAction: TVeloxFileAction; const ARelPath, AOldRelPath: string);
var
  FullP: string;
  HashStr, DetailStr, TitleStr: string;
  Sev: TVeloxSeverity;
begin
  FullP := IncludeTrailingPathDelimiter(FDirectory) + ARelPath;
  HashStr := '';

  case AAction of
    vfaCreated:
      begin
        TitleStr := 'File Created: ' + ARelPath;
        Sev := vsNormal;
        if FileExists(FullP) then
          HashStr := 'SHA256: ' + Copy(TVeloxCrypto.HashFile(FullP, vhaSha256), 1, 16) + '...';
      end;
    vfaModified:
      begin
        TitleStr := 'File Modified: ' + ARelPath;
        Sev := vsWarning;
        if FileExists(FullP) then
          HashStr := 'SHA256: ' + Copy(TVeloxCrypto.HashFile(FullP, vhaSha256), 1, 16) + '...';
      end;
    vfaDeleted:
      begin
        TitleStr := 'File Deleted: ' + ARelPath;
        Sev := vsCritical;
        HashStr := 'Removed from disk';
      end;
    vfaRenamed:
      begin
        TitleStr := 'File Renamed: ' + AOldRelPath + ' -> ' + ARelPath;
        Sev := vsNormal;
      end;
  end;

  DetailStr := HashStr;
  LogEvent(TitleStr, DetailStr, Sev);
end;

procedure TVeloxAuditSecurityLog.TopBarPaint(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
  HeaderTitle, StatusText: string;
begin
  C := FTopBar.Canvas;
  C.Brush.Color := FColors.Surface;
  C.FillRect(FTopBar.ClientRect);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;

  HeaderTitle := 'SECURITY AUDIT LOG';
  R := Rect(12, 0, 260, FTopBar.Height);
  DrawText(C.Handle, PChar(HeaderTitle), -1, R, DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  if FIsActive then
  begin
    StatusText := 'ACTIVE MONITORING';
    C.Font.Color := $10B981;
  end
  else
  begin
    StatusText := 'PAUSED';
    C.Font.Color := FColors.TextSecondary;
  end;

  C.Font.Size := 8;
  R := Rect(280, 0, FTopBar.Width - 12, FTopBar.Height);
  DrawText(C.Handle, PChar(StatusText), -1, R, DT_SINGLELINE or DT_VCENTER or DT_RIGHT);

  // Border bottom
  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, FTopBar.Height - 1);
  C.LineTo(FTopBar.Width, FTopBar.Height - 1);
end;

procedure TVeloxAuditSecurityLog.Paint;
begin
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);
end;

end.
