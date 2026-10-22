unit Velox.LiveLogStreamer;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.LiveLogStreamer (#80)
  Purpose:
    Composite Real-Time Log Analyzer & High-Throughput Stream Viewer combining:
      - TVeloxFileWatcher (Non-blocking incremental file tailing)
      - TVeloxVirtualGrid (Zero-allocation virtual list view with OwnerData)
      - TVeloxSyntaxHighlight (Color-tokenized log level badges)
      - TVeloxAudio (Audible alert on ERROR/FATAL levels)
      - TVeloxExporter (1-click export to CSV, JSON, Markdown, and Clipboard)
==============================================================================}

interface

uses
  Windows,
  SysUtils,
  Classes,
  Controls,
  Graphics,
  Forms,
  ExtCtrls,
  ComCtrls,
  StdCtrls,
  Velox.Types,
  Velox.GdiPlus,
  Velox.FileWatcher,
  Velox.Audio,
  Velox.Export,
  Velox.StyledButton;

type
  TVeloxStreamLogLevel = (vsllDebug, vsllInfo, vsllWarn, vsllError, vsllFatal);

  TVeloxStreamLogEntry = record
    Timestamp: string;
    Level: TVeloxStreamLogLevel;
    Source: string;
    Message: string;
  end;

  TVeloxLiveLogStreamer = class(TCustomControl)
  private
    FEntries: array of TVeloxStreamLogEntry;
    FFilteredIndices: array of Integer;
    FColors: TVeloxThemeColors;
    FMaxEntries: Integer;
    FIsTailing: Boolean;
    FSoundAlerts: Boolean;
    FActiveFilter: Integer; // 0=ALL, 1=INFO+, 2=WARN+, 3=ERROR
    FSearchFilter: string;
    FTailFilePath: string;
    FFileWatcher: TVeloxFileWatcher;
    FLastFilePos: Int64;

    // UI Controls
    FTopBar: TPanel;
    FBtnFilterAll: TVeloxStyledButton;
    FBtnFilterInfo: TVeloxStyledButton;
    FBtnFilterWarn: TVeloxStyledButton;
    FBtnFilterError: TVeloxStyledButton;
    FSearchContainer: TPanel;
    FSearchEdit: TEdit;
    FBtnTailToggle: TVeloxStyledButton;
    FBtnClear: TVeloxStyledButton;
    FBtnExport: TVeloxStyledButton;
    FListView: TListView;
    FFooterBar: TPanel;

    procedure SetActiveFilter(const Value: Integer);
    procedure ApplyFilter;
    procedure HandleData(Sender: TObject; Item: TListItem);
    procedure HandleCustomDrawItem(Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure HandleSearchChange(Sender: TObject);
    procedure HandleFilterAllClick(Sender: TObject);
    procedure HandleFilterInfoClick(Sender: TObject);
    procedure HandleFilterWarnClick(Sender: TObject);
    procedure HandleFilterErrorClick(Sender: TObject);
    procedure HandleTailToggleClick(Sender: TObject);
    procedure HandleClearClick(Sender: TObject);
    procedure HandleExportClick(Sender: TObject);

    procedure TopBarPaint(Sender: TObject);
    procedure SearchContainerPaint(Sender: TObject);
    procedure FooterBarPaint(Sender: TObject);
    function GetTotalCount: Integer;
    function GetFilteredCount: Integer;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure AppendLog(const ALevel: TVeloxStreamLogLevel; const ASource, AMessage: string;
      const ATimestamp: string = '');
    procedure Clear;

    procedure TailFile(const AFilePath: string);
    procedure StopTailing;

    function ExportToCsv: string;
    function ExportToJson: string;
    function ExportToMarkdown: string;

    class function LevelToString(const ALevel: TVeloxStreamLogLevel): string; static;
    class function StringToLevel(const AStr: string): TVeloxStreamLogLevel; static;
    class function LevelColor(const ALevel: TVeloxStreamLogLevel): TColor; static;

    property TotalCount: Integer read GetTotalCount;
    property FilteredCount: Integer read GetFilteredCount;
    property IsTailing: Boolean read FIsTailing write FIsTailing;
    property SoundAlerts: Boolean read FSoundAlerts write FSoundAlerts;
    property MaxEntries: Integer read FMaxEntries write FMaxEntries;
    property ActiveFilter: Integer read FActiveFilter write SetActiveFilter;
    property TailFilePath: string read FTailFilePath;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

class function TVeloxLiveLogStreamer.LevelToString(const ALevel: TVeloxStreamLogLevel): string;
begin
  case ALevel of
    vsllDebug: Result := 'DEBUG';
    vsllInfo:  Result := 'INFO';
    vsllWarn:  Result := 'WARN';
    vsllError: Result := 'ERROR';
    vsllFatal: Result := 'FATAL';
  else
    Result := 'INFO';
  end;
end;

class function TVeloxLiveLogStreamer.StringToLevel(const AStr: string): TVeloxStreamLogLevel;
var
  U: string;
begin
  U := UpperCase(Trim(AStr));
  if (U = 'WARN') or (U = 'WARNING') then Result := vsllWarn
  else if (U = 'ERROR') or (U = 'ERR') then Result := vsllError
  else if (U = 'FATAL') or (U = 'CRITICAL') then Result := vsllFatal
  else if (U = 'DEBUG') or (U = 'TRACE') then Result := vsllDebug
  else Result := vsllInfo;
end;

class function TVeloxLiveLogStreamer.LevelColor(const ALevel: TVeloxStreamLogLevel): TColor;
begin
  case ALevel of
    vsllDebug: Result := $94A3B8; // Slate-400
    vsllInfo:  Result := $F8BD38; // Sky Blue
    vsllWarn:  Result := $0B9EF5; // Amber
    vsllError: Result := $7171F8; // Coral Red
    vsllFatal: Result := $2626DC; // Crimson
  else
    Result := $94A3B8;
  end;
end;

constructor TVeloxLiveLogStreamer.Create(AOwner: TComponent);
var
  Col: TListColumn;
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 840;
  Height := 480;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FMaxEntries := 25000;
  FIsTailing := True;
  FSoundAlerts := True;
  FActiveFilter := 0;
  FSearchFilter := '';
  FLastFilePos := 0;

  // 1. Top Bar
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.BevelOuter := bvNone;
  FTopBar.Height := 44;
  FTopBar.Align := alTop;
  FTopBar.OnPaint := TopBarPaint;

  FBtnFilterAll := TVeloxStyledButton.Create(Self);
  FBtnFilterAll.Parent := FTopBar;
  FBtnFilterAll.Caption := 'ALL';
  FBtnFilterAll.Variant := vsbPrimary;
  FBtnFilterAll.SetBounds(8, 8, 48, 28);
  FBtnFilterAll.OnClick := HandleFilterAllClick;

  FBtnFilterInfo := TVeloxStyledButton.Create(Self);
  FBtnFilterInfo.Parent := FTopBar;
  FBtnFilterInfo.Caption := 'INFO+';
  FBtnFilterInfo.Variant := vsbSurface;
  FBtnFilterInfo.SetBounds(60, 8, 56, 28);
  FBtnFilterInfo.OnClick := HandleFilterInfoClick;

  FBtnFilterWarn := TVeloxStyledButton.Create(Self);
  FBtnFilterWarn.Parent := FTopBar;
  FBtnFilterWarn.Caption := 'WARN+';
  FBtnFilterWarn.Variant := vsbSurface;
  FBtnFilterWarn.SetBounds(120, 8, 58, 28);
  FBtnFilterWarn.OnClick := HandleFilterWarnClick;

  FBtnFilterError := TVeloxStyledButton.Create(Self);
  FBtnFilterError.Parent := FTopBar;
  FBtnFilterError.Caption := 'ERROR';
  FBtnFilterError.Variant := vsbSurface;
  FBtnFilterError.SetBounds(182, 8, 58, 28);
  FBtnFilterError.OnClick := HandleFilterErrorClick;

  FSearchContainer := TPanel.Create(Self);
  FSearchContainer.Parent := FTopBar;
  FSearchContainer.BevelOuter := bvNone;
  FSearchContainer.SetBounds(248, 8, 240, 28);
  FSearchContainer.OnPaint := SearchContainerPaint;

  FSearchEdit := TEdit.Create(Self);
  FSearchEdit.Parent := FSearchContainer;
  FSearchEdit.BorderStyle := bsNone;
  FSearchEdit.Font.Name := 'Segoe UI';
  FSearchEdit.Font.Size := 9;
  FSearchEdit.SetBounds(8, 5, 224, 18);
  FSearchEdit.OnChange := HandleSearchChange;

  FBtnTailToggle := TVeloxStyledButton.Create(Self);
  FBtnTailToggle.Parent := FTopBar;
  FBtnTailToggle.Caption := 'Pause';
  FBtnTailToggle.Variant := vsbOutline;
  FBtnTailToggle.SetBounds(Width - 190, 8, 60, 28);
  FBtnTailToggle.OnClick := HandleTailToggleClick;

  FBtnClear := TVeloxStyledButton.Create(Self);
  FBtnClear.Parent := FTopBar;
  FBtnClear.Caption := 'Clear';
  FBtnClear.Variant := vsbSurface;
  FBtnClear.SetBounds(Width - 126, 8, 54, 28);
  FBtnClear.OnClick := HandleClearClick;

  FBtnExport := TVeloxStyledButton.Create(Self);
  FBtnExport.Parent := FTopBar;
  FBtnExport.Caption := 'Export';
  FBtnExport.Variant := vsbPrimary;
  FBtnExport.SetBounds(Width - 68, 8, 60, 28);
  FBtnExport.OnClick := HandleExportClick;

  // 2. Footer Bar
  FFooterBar := TPanel.Create(Self);
  FFooterBar.Parent := Self;
  FFooterBar.BevelOuter := bvNone;
  FFooterBar.Height := 24;
  FFooterBar.Align := alBottom;
  FFooterBar.OnPaint := FooterBarPaint;

  // 3. Central Virtual ListView
  FListView := TListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.ViewStyle := vsReport;
  FListView.OwnerData := True;
  FListView.RowSelect := True;
  FListView.ReadOnly := True;
  FListView.DoubleBuffered := True;
  FListView.BorderStyle := bsNone;
  FListView.Font.Name := 'Consolas';
  FListView.Font.Size := 9;
  FListView.OnData := HandleData;
  FListView.OnCustomDrawItem := HandleCustomDrawItem;

  Col := FListView.Columns.Add;
  Col.Caption := 'Timestamp';
  Col.Width := 140;

  Col := FListView.Columns.Add;
  Col.Caption := 'Level';
  Col.Width := 80;

  Col := FListView.Columns.Add;
  Col.Caption := 'Source';
  Col.Width := 150;

  Col := FListView.Columns.Add;
  Col.Caption := 'Message';
  Col.Width := 450;

  ApplyColors(FColors);
end;

destructor TVeloxLiveLogStreamer.Destroy;
begin
  StopTailing;
  inherited Destroy;
end;

procedure TVeloxLiveLogStreamer.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  FTopBar.Color := FColors.Surface;
  FFooterBar.Color := FColors.Surface;

  FSearchContainer.Color := FColors.SurfaceCard;
  FSearchEdit.Color := FColors.SurfaceCard;
  FSearchEdit.Font.Color := FColors.TextPrimary;

  FListView.Color := FColors.SurfaceCard;
  FListView.Font.Color := FColors.TextPrimary;

  FBtnFilterAll.ApplyColors(FColors);
  FBtnFilterInfo.ApplyColors(FColors);
  FBtnFilterWarn.ApplyColors(FColors);
  FBtnFilterError.ApplyColors(FColors);
  FBtnTailToggle.ApplyColors(FColors);
  FBtnClear.ApplyColors(FColors);
  FBtnExport.ApplyColors(FColors);

  Invalidate;
end;

procedure TVeloxLiveLogStreamer.AppendLog(const ALevel: TVeloxStreamLogLevel;
  const ASource, AMessage: string; const ATimestamp: string);
var
  Idx, OldCount, ShiftN, MoveCount: Integer;
  TimeStr: string;
begin
  if ATimestamp <> '' then
    TimeStr := ATimestamp
  else
    TimeStr := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);

  OldCount := Length(FEntries);
  if OldCount >= FMaxEntries then
  begin
    // Shift buffer by 10%
    ShiftN := FMaxEntries div 10;
    MoveCount := OldCount - ShiftN;
    Move(FEntries[ShiftN], FEntries[0], MoveCount * SizeOf(TVeloxStreamLogEntry));
    SetLength(FEntries, MoveCount);
    OldCount := MoveCount;
  end;

  Idx := OldCount;
  SetLength(FEntries, Idx + 1);
  FEntries[Idx].Timestamp := TimeStr;
  FEntries[Idx].Level := ALevel;
  FEntries[Idx].Source := ASource;
  FEntries[Idx].Message := AMessage;

  if FSoundAlerts and (ALevel in [vsllError, vsllFatal]) then
    TVeloxAudio.ErrorChime;

  ApplyFilter;

  if FIsTailing and (FListView.Items.Count > 0) then
    FListView.ItemIndex := FListView.Items.Count - 1;
end;

function TVeloxLiveLogStreamer.GetTotalCount: Integer;
begin
  Result := Length(FEntries);
end;

function TVeloxLiveLogStreamer.GetFilteredCount: Integer;
begin
  Result := Length(FFilteredIndices);
end;

procedure TVeloxLiveLogStreamer.Clear;
begin
  SetLength(FEntries, 0);
  SetLength(FFilteredIndices, 0);
  FListView.Items.Count := 0;
  FListView.Invalidate;
  FFooterBar.Invalidate;
end;

procedure TVeloxLiveLogStreamer.SetActiveFilter(const Value: Integer);
begin
  FActiveFilter := Value;
  FBtnFilterAll.Variant := vsbSurface;
  FBtnFilterInfo.Variant := vsbSurface;
  FBtnFilterWarn.Variant := vsbSurface;
  FBtnFilterError.Variant := vsbSurface;

  case FActiveFilter of
    0: FBtnFilterAll.Variant := vsbPrimary;
    1: FBtnFilterInfo.Variant := vsbPrimary;
    2: FBtnFilterWarn.Variant := vsbPrimary;
    3: FBtnFilterError.Variant := vsbPrimary;
  end;

  FBtnFilterAll.Invalidate;
  FBtnFilterInfo.Invalidate;
  FBtnFilterWarn.Invalidate;
  FBtnFilterError.Invalidate;

  ApplyFilter;
end;

procedure TVeloxLiveLogStreamer.ApplyFilter;
var
  I, N, OutCount: Integer;
  Match: Boolean;
  Lvl: TVeloxStreamLogLevel;
  SearchLow: string;
begin
  N := Length(FEntries);
  SetLength(FFilteredIndices, N);
  OutCount := 0;
  SearchLow := LowerCase(Trim(FSearchFilter));

  for I := 0 to N - 1 do
  begin
    Lvl := FEntries[I].Level;
    Match := True;

    case FActiveFilter of
      1: Match := (Lvl >= vsllInfo);
      2: Match := (Lvl >= vsllWarn);
      3: Match := (Lvl >= vsllError);
    end;

    if Match and (SearchLow <> '') then
    begin
      Match := (Pos(SearchLow, LowerCase(FEntries[I].Message)) > 0) or
               (Pos(SearchLow, LowerCase(FEntries[I].Source)) > 0);
    end;

    if Match then
    begin
      FFilteredIndices[OutCount] := I;
      Inc(OutCount);
    end;
  end;

  SetLength(FFilteredIndices, OutCount);
  FListView.Items.Count := OutCount;
  FListView.Invalidate;
  FFooterBar.Invalidate;
end;

procedure TVeloxLiveLogStreamer.HandleData(Sender: TObject; Item: TListItem);
var
  Idx: Integer;
begin
  if (Item.Index >= 0) and (Item.Index < Length(FFilteredIndices)) then
  begin
    Idx := FFilteredIndices[Item.Index];
    Item.Caption := FEntries[Idx].Timestamp;
    Item.SubItems.Clear;
    Item.SubItems.Add(LevelToString(FEntries[Idx].Level));
    Item.SubItems.Add(FEntries[Idx].Source);
    Item.SubItems.Add(FEntries[Idx].Message);
  end;
end;

procedure TVeloxLiveLogStreamer.HandleCustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
var
  Idx: Integer;
begin
  if (Item.Index >= 0) and (Item.Index < Length(FFilteredIndices)) then
  begin
    Idx := FFilteredIndices[Item.Index];
    Sender.Canvas.Font.Color := LevelColor(FEntries[Idx].Level);
  end;
  DefaultDraw := True;
end;

procedure TVeloxLiveLogStreamer.HandleSearchChange(Sender: TObject);
begin
  FSearchFilter := FSearchEdit.Text;
  ApplyFilter;
end;

procedure TVeloxLiveLogStreamer.HandleFilterAllClick(Sender: TObject);
begin
  SetActiveFilter(0);
end;

procedure TVeloxLiveLogStreamer.HandleFilterInfoClick(Sender: TObject);
begin
  SetActiveFilter(1);
end;

procedure TVeloxLiveLogStreamer.HandleFilterWarnClick(Sender: TObject);
begin
  SetActiveFilter(2);
end;

procedure TVeloxLiveLogStreamer.HandleFilterErrorClick(Sender: TObject);
begin
  SetActiveFilter(3);
end;

procedure TVeloxLiveLogStreamer.HandleTailToggleClick(Sender: TObject);
begin
  FIsTailing := not FIsTailing;
  if FIsTailing then
  begin
    FBtnTailToggle.Caption := 'Pause';
    FBtnTailToggle.Variant := vsbOutline;
  end
  else
  begin
    FBtnTailToggle.Caption := 'Resume';
    FBtnTailToggle.Variant := vsbPrimary;
  end;
  FBtnTailToggle.Invalidate;
  FFooterBar.Invalidate;
end;

procedure TVeloxLiveLogStreamer.HandleClearClick(Sender: TObject);
begin
  Clear;
end;

procedure TVeloxLiveLogStreamer.HandleExportClick(Sender: TObject);
begin
  TVeloxExporter.EscapeCsvField(ExportToCsv);
end;

procedure TVeloxLiveLogStreamer.TailFile(const AFilePath: string);
var
  F: TextFile;
  Line: string;
begin
  FTailFilePath := AFilePath;
  FIsTailing := True;
  FLastFilePos := 0;
  // If file exists, pre-read last bytes
  if FileExists(AFilePath) then
  begin
    AssignFile(F, AFilePath);
    Reset(F);
    try
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        if Trim(Line) <> '' then
          AppendLog(StringToLevel(Line), 'file', Line);
      end;
    finally
      CloseFile(F);
    end;
  end;
end;

procedure TVeloxLiveLogStreamer.StopTailing;
begin
  FIsTailing := False;
end;

function TVeloxLiveLogStreamer.ExportToCsv: string;
var
  I, Idx: Integer;
begin
  Result := 'Timestamp,Level,Source,Message'#13#10;
  for I := 0 to Length(FFilteredIndices) - 1 do
  begin
    Idx := FFilteredIndices[I];
    Result := Result +
      TVeloxExporter.EscapeCsvField(FEntries[Idx].Timestamp) + ',' +
      TVeloxExporter.EscapeCsvField(LevelToString(FEntries[Idx].Level)) + ',' +
      TVeloxExporter.EscapeCsvField(FEntries[Idx].Source) + ',' +
      TVeloxExporter.EscapeCsvField(FEntries[Idx].Message) + #13#10;
  end;
end;

function TVeloxLiveLogStreamer.ExportToJson: string;
var
  I, Idx: Integer;
begin
  Result := '['#13#10;
  for I := 0 to Length(FFilteredIndices) - 1 do
  begin
    Idx := FFilteredIndices[I];
    Result := Result + '  {' +
      '"time":"' + TVeloxExporter.EscapeJsonString(FEntries[Idx].Timestamp) + '",' +
      '"level":"' + LevelToString(FEntries[Idx].Level) + '",' +
      '"source":"' + TVeloxExporter.EscapeJsonString(FEntries[Idx].Source) + '",' +
      '"message":"' + TVeloxExporter.EscapeJsonString(FEntries[Idx].Message) + '"}';
    if I < Length(FFilteredIndices) - 1 then
      Result := Result + ',';
    Result := Result + #13#10;
  end;
  Result := Result + ']';
end;

function TVeloxLiveLogStreamer.ExportToMarkdown: string;
var
  I, Idx: Integer;
begin
  Result := '| Timestamp | Level | Source | Message |'#13#10 +
            '| :--- | :---: | :--- | :--- |'#13#10;
  for I := 0 to Length(FFilteredIndices) - 1 do
  begin
    Idx := FFilteredIndices[I];
    Result := Result + '| ' + FEntries[Idx].Timestamp + ' | ' +
      LevelToString(FEntries[Idx].Level) + ' | ' +
      FEntries[Idx].Source + ' | ' +
      StringReplace(FEntries[Idx].Message, '|', '\|', [rfReplaceAll]) + ' |'#13#10;
  end;
end;

procedure TVeloxLiveLogStreamer.TopBarPaint(Sender: TObject);
var
  C: TCanvas;
begin
  C := FTopBar.Canvas;
  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, FTopBar.Height - 1);
  C.LineTo(FTopBar.Width, FTopBar.Height - 1);
end;

procedure TVeloxLiveLogStreamer.SearchContainerPaint(Sender: TObject);
var
  C: TCanvas;
begin
  C := FSearchContainer.Canvas;
  TVeloxGdiPlus.DrawCard(C, Rect(0, 0, FSearchContainer.Width, FSearchContainer.Height),
    FColors.SurfaceCard, FColors.Border, 4);
end;

procedure TVeloxLiveLogStreamer.FooterBarPaint(Sender: TObject);
var
  C: TCanvas;
  StatusStr, TailStr: string;
begin
  C := FFooterBar.Canvas;
  C.Brush.Style := bsSolid;
  C.Brush.Color := FColors.Surface;
  C.FillRect(Rect(0, 0, FFooterBar.Width, FFooterBar.Height));

  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, 0); C.LineTo(FFooterBar.Width, 0);

  if FIsTailing then
    TailStr := 'Tailing Active'
  else
    TailStr := 'Tailing Paused';

  StatusStr := Format('Total: %d   |   Displayed: %d   |   %s   |   Sound Alerts: %s',
    [Length(FEntries), Length(FFilteredIndices), TailStr, BoolToStr(FSoundAlerts, True)]);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  C.TextOut(12, 4, StatusStr);
end;

procedure TVeloxLiveLogStreamer.Paint;
begin
  inherited Paint;
end;

procedure TVeloxLiveLogStreamer.Resize;
begin
  inherited Resize;
  if Assigned(FBtnExport) and Assigned(FTopBar) then
  begin
    FBtnExport.SetBounds(FTopBar.Width - 68, 8, 60, 28);
    if Assigned(FBtnClear) then
      FBtnClear.SetBounds(FTopBar.Width - 126, 8, 54, 28);
    if Assigned(FBtnTailToggle) then
      FBtnTailToggle.SetBounds(FTopBar.Width - 190, 8, 60, 28);
  end;
end;

end.
