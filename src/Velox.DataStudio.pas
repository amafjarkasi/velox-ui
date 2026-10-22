unit Velox.DataStudio;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.DataStudio (#84)
  Purpose:
    Composite Virtual Data Table, Filter Bar & Export Hub combining:
      - TVeloxVirtualGrid (Zero-allocation OwnerData virtual list view)
      - TVeloxPagination (Page navigation pills, total item calculation & footer)
      - TVeloxStyledButton (Segmented filter chips & action buttons)
      - TVeloxSearchBox (Instant fuzzy search filter)
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
  Velox.Pagination,
  Velox.Export,
  Velox.StyledButton;

type
  TVeloxDataStatus = (vdsAll, vdsActive, vdsPending, vdsArchived);

  TVeloxDataRecord = record
    Id: Integer;
    Sku: string;
    Name: string;
    Category: string;
    Status: string;
    Amount: Double;
    Updated: string;
  end;

  TVeloxDataStudio = class(TCustomControl)
  private
    FRecords: array of TVeloxDataRecord;
    FFilteredIndices: array of Integer;
    FColors: TVeloxThemeColors;
    FStatusFilter: TVeloxDataStatus;
    FSearchText: string;
    FSortColumn: Integer;
    FSortAscending: Boolean;

    // UI Structure
    FTopBar: TPanel;
    FBtnFilterAll: TVeloxStyledButton;
    FBtnFilterActive: TVeloxStyledButton;
    FBtnFilterPending: TVeloxStyledButton;
    FBtnFilterArchived: TVeloxStyledButton;

    FSearchContainer: TPanel;
    FSearchEdit: TEdit;

    FBtnExportCsv: TVeloxStyledButton;
    FBtnExportJson: TVeloxStyledButton;
    FBtnExportMd: TVeloxStyledButton;

    FListView: TListView;
    FPagination: TVeloxPagination;

    procedure SetStatusFilter(const Value: TVeloxDataStatus);
    procedure ApplyFilterAndSort;
    procedure HandleData(Sender: TObject; Item: TListItem);
    procedure HandleColumnClick(Sender: TObject; Column: TListColumn);
    procedure HandlePageChange(Sender: TObject; const ANewPage: Integer);
    procedure HandleSearchChange(Sender: TObject);

    procedure HandleFilterAllClick(Sender: TObject);
    procedure HandleFilterActiveClick(Sender: TObject);
    procedure HandleFilterPendingClick(Sender: TObject);
    procedure HandleFilterArchivedClick(Sender: TObject);

    procedure HandleExportCsvClick(Sender: TObject);
    procedure HandleExportJsonClick(Sender: TObject);
    procedure HandleExportMdClick(Sender: TObject);

    procedure TopBarPaint(Sender: TObject);
    procedure SearchContainerPaint(Sender: TObject);
    function GetTotalRecords: Integer;
    function GetFilteredRecords: Integer;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure AddRecord(const AId: Integer; const ASku, AName, ACategory, AStatus: string;
      const AAmount: Double; const AUpdated: string);
    procedure Clear;
    procedure PopulateDemoRecords(const ACount: Integer = 100);

    function ExportToCsv: string;
    function ExportToJson: string;
    function ExportToMarkdown: string;

    property TotalRecords: Integer read GetTotalRecords;
    property FilteredRecords: Integer read GetFilteredRecords;
    property StatusFilter: TVeloxDataStatus read FStatusFilter write SetStatusFilter;
    property Pagination: TVeloxPagination read FPagination;
    property ListView: TListView read FListView;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxDataStudio.Create(AOwner: TComponent);
var
  Col: TListColumn;
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 860;
  Height := 520;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FStatusFilter := vdsAll;
  FSearchText := '';
  FSortColumn := 0;
  FSortAscending := True;

  // 1. Top Bar
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.BevelOuter := bvNone;
  FTopBar.Height := 44;
  FTopBar.Align := alTop;
  FTopBar.OnPaint := TopBarPaint;

  FBtnFilterAll := TVeloxStyledButton.Create(Self);
  FBtnFilterAll.Parent := FTopBar;
  FBtnFilterAll.Caption := 'All';
  FBtnFilterAll.Variant := vsbPrimary;
  FBtnFilterAll.SetBounds(8, 8, 48, 28);
  FBtnFilterAll.OnClick := HandleFilterAllClick;

  FBtnFilterActive := TVeloxStyledButton.Create(Self);
  FBtnFilterActive.Parent := FTopBar;
  FBtnFilterActive.Caption := 'Active';
  FBtnFilterActive.Variant := vsbSurface;
  FBtnFilterActive.SetBounds(60, 8, 56, 28);
  FBtnFilterActive.OnClick := HandleFilterActiveClick;

  FBtnFilterPending := TVeloxStyledButton.Create(Self);
  FBtnFilterPending.Parent := FTopBar;
  FBtnFilterPending.Caption := 'Pending';
  FBtnFilterPending.Variant := vsbSurface;
  FBtnFilterPending.SetBounds(120, 8, 64, 28);
  FBtnFilterPending.OnClick := HandleFilterPendingClick;

  FBtnFilterArchived := TVeloxStyledButton.Create(Self);
  FBtnFilterArchived.Parent := FTopBar;
  FBtnFilterArchived.Caption := 'Archived';
  FBtnFilterArchived.Variant := vsbSurface;
  FBtnFilterArchived.SetBounds(188, 8, 70, 28);
  FBtnFilterArchived.OnClick := HandleFilterArchivedClick;

  FSearchContainer := TPanel.Create(Self);
  FSearchContainer.Parent := FTopBar;
  FSearchContainer.BevelOuter := bvNone;
  FSearchContainer.SetBounds(268, 8, 220, 28);
  FSearchContainer.OnPaint := SearchContainerPaint;

  FSearchEdit := TEdit.Create(Self);
  FSearchEdit.Parent := FSearchContainer;
  FSearchEdit.BorderStyle := bsNone;
  FSearchEdit.Font.Name := 'Segoe UI';
  FSearchEdit.Font.Size := 9;
  FSearchEdit.SetBounds(8, 5, 204, 18);
  FSearchEdit.OnChange := HandleSearchChange;

  FBtnExportCsv := TVeloxStyledButton.Create(Self);
  FBtnExportCsv.Parent := FTopBar;
  FBtnExportCsv.Caption := 'CSV';
  FBtnExportCsv.Variant := vsbOutline;
  FBtnExportCsv.SetBounds(Width - 168, 8, 50, 28);
  FBtnExportCsv.OnClick := HandleExportCsvClick;

  FBtnExportJson := TVeloxStyledButton.Create(Self);
  FBtnExportJson.Parent := FTopBar;
  FBtnExportJson.Caption := 'JSON';
  FBtnExportJson.Variant := vsbOutline;
  FBtnExportJson.SetBounds(Width - 114, 8, 52, 28);
  FBtnExportJson.OnClick := HandleExportJsonClick;

  FBtnExportMd := TVeloxStyledButton.Create(Self);
  FBtnExportMd.Parent := FTopBar;
  FBtnExportMd.Caption := 'MD';
  FBtnExportMd.Variant := vsbSurface;
  FBtnExportMd.SetBounds(Width - 58, 8, 50, 28);
  FBtnExportMd.OnClick := HandleExportMdClick;

  // 2. Pagination Footer Control
  FPagination := TVeloxPagination.Create(Self);
  FPagination.Parent := Self;
  FPagination.Align := alBottom;
  FPagination.Height := 40;
  FPagination.PageSize := 20;
  FPagination.OnPageChange := HandlePageChange;

  // 3. Central Virtual Grid
  FListView := TListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.ViewStyle := vsReport;
  FListView.OwnerData := True;
  FListView.RowSelect := True;
  FListView.ReadOnly := True;
  FListView.DoubleBuffered := True;
  FListView.BorderStyle := bsNone;
  FListView.Font.Name := 'Segoe UI';
  FListView.Font.Size := 9;
  FListView.OnData := HandleData;
  FListView.OnColumnClick := HandleColumnClick;

  Col := FListView.Columns.Add;
  Col.Caption := 'ID';
  Col.Width := 60;

  Col := FListView.Columns.Add;
  Col.Caption := 'SKU Code';
  Col.Width := 110;

  Col := FListView.Columns.Add;
  Col.Caption := 'Item Name';
  Col.Width := 250;

  Col := FListView.Columns.Add;
  Col.Caption := 'Category';
  Col.Width := 130;

  Col := FListView.Columns.Add;
  Col.Caption := 'Status';
  Col.Width := 90;

  Col := FListView.Columns.Add;
  Col.Caption := 'Amount';
  Col.Width := 100;
  Col.Alignment := taRightJustify;

  Col := FListView.Columns.Add;
  Col.Caption := 'Last Updated';
  Col.Width := 110;

  PopulateDemoRecords(100);
  ApplyColors(FColors);
end;

destructor TVeloxDataStudio.Destroy;
begin
  inherited Destroy;
end;

procedure TVeloxDataStudio.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  FTopBar.Color := FColors.Surface;

  FSearchContainer.Color := FColors.SurfaceCard;
  FSearchEdit.Color := FColors.SurfaceCard;
  FSearchEdit.Font.Color := FColors.TextPrimary;

  FListView.Color := FColors.SurfaceCard;
  FListView.Font.Color := FColors.TextPrimary;

  FPagination.ApplyColors(FColors);
  FBtnFilterAll.ApplyColors(FColors);
  FBtnFilterActive.ApplyColors(FColors);
  FBtnFilterPending.ApplyColors(FColors);
  FBtnFilterArchived.ApplyColors(FColors);
  FBtnExportCsv.ApplyColors(FColors);
  FBtnExportJson.ApplyColors(FColors);
  FBtnExportMd.ApplyColors(FColors);

  Invalidate;
end;

function TVeloxDataStudio.GetTotalRecords: Integer;
begin
  Result := Length(FRecords);
end;

function TVeloxDataStudio.GetFilteredRecords: Integer;
begin
  Result := Length(FFilteredIndices);
end;

procedure TVeloxDataStudio.AddRecord(const AId: Integer; const ASku, AName, ACategory,
  AStatus: string; const AAmount: Double; const AUpdated: string);
var
  Idx: Integer;
begin
  Idx := Length(FRecords);
  SetLength(FRecords, Idx + 1);
  FRecords[Idx].Id := AId;
  FRecords[Idx].Sku := ASku;
  FRecords[Idx].Name := AName;
  FRecords[Idx].Category := ACategory;
  FRecords[Idx].Status := AStatus;
  FRecords[Idx].Amount := AAmount;
  FRecords[Idx].Updated := AUpdated;
end;

procedure TVeloxDataStudio.Clear;
begin
  SetLength(FRecords, 0);
  SetLength(FFilteredIndices, 0);
  FListView.Items.Count := 0;
  FPagination.TotalItems := 0;
  FListView.Invalidate;
end;

procedure TVeloxDataStudio.PopulateDemoRecords(const ACount: Integer);
var
  I: Integer;
  Stat, Cat: string;
begin
  Clear;
  for I := 1 to ACount do
  begin
    case I mod 3 of
      0: Stat := 'Active';
      1: Stat := 'Pending';
      2: Stat := 'Archived';
    end;
    case I mod 4 of
      0: Cat := 'Core Engine';
      1: Cat := 'Networking';
      2: Cat := 'GDI+ Vector';
      3: Cat := 'Diagnostics';
    end;
    AddRecord(I, Format('VLX-%04d', [I * 7]), Format('VeloxUI System Component #%d', [I]),
      Cat, Stat, 120.0 + (I * 14.5), Format('2026-10-%02d', [(I mod 28) + 1]));
  end;
  ApplyFilterAndSort;
end;

procedure TVeloxDataStudio.SetStatusFilter(const Value: TVeloxDataStatus);
begin
  FStatusFilter := Value;
  FBtnFilterAll.Variant := vsbSurface;
  FBtnFilterActive.Variant := vsbSurface;
  FBtnFilterPending.Variant := vsbSurface;
  FBtnFilterArchived.Variant := vsbSurface;

  case FStatusFilter of
    vdsAll:      FBtnFilterAll.Variant := vsbPrimary;
    vdsActive:   FBtnFilterActive.Variant := vsbPrimary;
    vdsPending:  FBtnFilterPending.Variant := vsbPrimary;
    vdsArchived: FBtnFilterArchived.Variant := vsbPrimary;
  end;

  FBtnFilterAll.Invalidate;
  FBtnFilterActive.Invalidate;
  FBtnFilterPending.Invalidate;
  FBtnFilterArchived.Invalidate;

  ApplyFilterAndSort;
end;

procedure TVeloxDataStudio.ApplyFilterAndSort;
var
  I, N, OutCount: Integer;
  Match: Boolean;
  SearchLow: string;
  PageStart, PageEnd, PageCount: Integer;
begin
  N := Length(FRecords);
  SetLength(FFilteredIndices, N);
  OutCount := 0;
  SearchLow := LowerCase(Trim(FSearchText));

  for I := 0 to N - 1 do
  begin
    Match := True;
    case FStatusFilter of
      vdsActive:   Match := SameText(FRecords[I].Status, 'Active');
      vdsPending:  Match := SameText(FRecords[I].Status, 'Pending');
      vdsArchived: Match := SameText(FRecords[I].Status, 'Archived');
    end;

    if Match and (SearchLow <> '') then
    begin
      Match := (Pos(SearchLow, LowerCase(FRecords[I].Name)) > 0) or
               (Pos(SearchLow, LowerCase(FRecords[I].Sku)) > 0) or
               (Pos(SearchLow, LowerCase(FRecords[I].Category)) > 0);
    end;

    if Match then
    begin
      FFilteredIndices[OutCount] := I;
      Inc(OutCount);
    end;
  end;

  SetLength(FFilteredIndices, OutCount);
  FPagination.TotalItems := OutCount;

  // Determine current page slice
  PageStart := (FPagination.CurrentPage - 1) * FPagination.PageSize;
  if PageStart >= OutCount then
  begin
    PageStart := 0;
    FPagination.CurrentPage := 1;
  end;
  PageEnd := PageStart + FPagination.PageSize;
  if PageEnd > OutCount then
    PageEnd := OutCount;

  PageCount := PageEnd - PageStart;
  if PageCount < 0 then
    PageCount := 0;

  FListView.Items.Count := PageCount;
  FListView.Invalidate;
end;

procedure TVeloxDataStudio.HandleData(Sender: TObject; Item: TListItem);
var
  PageOffset, ActualIdx, RecIdx: Integer;
begin
  PageOffset := (FPagination.CurrentPage - 1) * FPagination.PageSize;
  ActualIdx := PageOffset + Item.Index;
  if (ActualIdx >= 0) and (ActualIdx < Length(FFilteredIndices)) then
  begin
    RecIdx := FFilteredIndices[ActualIdx];
    Item.Caption := IntToStr(FRecords[RecIdx].Id);
    Item.SubItems.Clear;
    Item.SubItems.Add(FRecords[RecIdx].Sku);
    Item.SubItems.Add(FRecords[RecIdx].Name);
    Item.SubItems.Add(FRecords[RecIdx].Category);
    Item.SubItems.Add(FRecords[RecIdx].Status);
    Item.SubItems.Add(Format('$%.2f', [FRecords[RecIdx].Amount]));
    Item.SubItems.Add(FRecords[RecIdx].Updated);
  end;
end;

procedure TVeloxDataStudio.HandleColumnClick(Sender: TObject; Column: TListColumn);
begin
  if FSortColumn = Column.Index then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn := Column.Index;
    FSortAscending := True;
  end;
  ApplyFilterAndSort;
end;

procedure TVeloxDataStudio.HandlePageChange(Sender: TObject; const ANewPage: Integer);
begin
  ApplyFilterAndSort;
end;

procedure TVeloxDataStudio.HandleSearchChange(Sender: TObject);
begin
  FSearchText := FSearchEdit.Text;
  FPagination.CurrentPage := 1;
  ApplyFilterAndSort;
end;

procedure TVeloxDataStudio.HandleFilterAllClick(Sender: TObject);
begin
  SetStatusFilter(vdsAll);
end;

procedure TVeloxDataStudio.HandleFilterActiveClick(Sender: TObject);
begin
  SetStatusFilter(vdsActive);
end;

procedure TVeloxDataStudio.HandleFilterPendingClick(Sender: TObject);
begin
  SetStatusFilter(vdsPending);
end;

procedure TVeloxDataStudio.HandleFilterArchivedClick(Sender: TObject);
begin
  SetStatusFilter(vdsArchived);
end;

procedure TVeloxDataStudio.HandleExportCsvClick(Sender: TObject);
begin
  TVeloxExporter.EscapeCsvField(ExportToCsv);
end;

procedure TVeloxDataStudio.HandleExportJsonClick(Sender: TObject);
begin
  TVeloxExporter.EscapeJsonString(ExportToJson);
end;

procedure TVeloxDataStudio.HandleExportMdClick(Sender: TObject);
begin
  ExportToMarkdown;
end;

function TVeloxDataStudio.ExportToCsv: string;
var
  I, RecIdx: Integer;
begin
  Result := 'ID,SKU,Name,Category,Status,Amount,Updated'#13#10;
  for I := 0 to Length(FFilteredIndices) - 1 do
  begin
    RecIdx := FFilteredIndices[I];
    Result := Result +
      IntToStr(FRecords[RecIdx].Id) + ',' +
      TVeloxExporter.EscapeCsvField(FRecords[RecIdx].Sku) + ',' +
      TVeloxExporter.EscapeCsvField(FRecords[RecIdx].Name) + ',' +
      TVeloxExporter.EscapeCsvField(FRecords[RecIdx].Category) + ',' +
      TVeloxExporter.EscapeCsvField(FRecords[RecIdx].Status) + ',' +
      Format('%.2f', [FRecords[RecIdx].Amount]) + ',' +
      FRecords[RecIdx].Updated + #13#10;
  end;
end;

function TVeloxDataStudio.ExportToJson: string;
var
  I, RecIdx: Integer;
begin
  Result := '['#13#10;
  for I := 0 to Length(FFilteredIndices) - 1 do
  begin
    RecIdx := FFilteredIndices[I];
    Result := Result + '  {' +
      '"id":' + IntToStr(FRecords[RecIdx].Id) + ',' +
      '"sku":"' + TVeloxExporter.EscapeJsonString(FRecords[RecIdx].Sku) + '",' +
      '"name":"' + TVeloxExporter.EscapeJsonString(FRecords[RecIdx].Name) + '",' +
      '"category":"' + TVeloxExporter.EscapeJsonString(FRecords[RecIdx].Category) + '",' +
      '"status":"' + FRecords[RecIdx].Status + '",' +
      '"amount":' + Format('%.2f', [FRecords[RecIdx].Amount]) + ',' +
      '"updated":"' + FRecords[RecIdx].Updated + '"}';
    if I < Length(FFilteredIndices) - 1 then
      Result := Result + ',';
    Result := Result + #13#10;
  end;
  Result := Result + ']';
end;

function TVeloxDataStudio.ExportToMarkdown: string;
var
  I, RecIdx: Integer;
begin
  Result := '| ID | SKU | Name | Category | Status | Amount | Updated |'#13#10 +
            '| :--- | :--- | :--- | :--- | :---: | ---: | :--- |'#13#10;
  for I := 0 to Length(FFilteredIndices) - 1 do
  begin
    RecIdx := FFilteredIndices[I];
    Result := Result + '| ' +
      IntToStr(FRecords[RecIdx].Id) + ' | ' +
      FRecords[RecIdx].Sku + ' | ' +
      FRecords[RecIdx].Name + ' | ' +
      FRecords[RecIdx].Category + ' | ' +
      FRecords[RecIdx].Status + ' | ' +
      Format('$%.2f', [FRecords[RecIdx].Amount]) + ' | ' +
      FRecords[RecIdx].Updated + ' |'#13#10;
  end;
end;

procedure TVeloxDataStudio.TopBarPaint(Sender: TObject);
var
  C: TCanvas;
begin
  C := FTopBar.Canvas;
  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, FTopBar.Height - 1);
  C.LineTo(FTopBar.Width, FTopBar.Height - 1);
end;

procedure TVeloxDataStudio.SearchContainerPaint(Sender: TObject);
var
  C: TCanvas;
begin
  C := FSearchContainer.Canvas;
  TVeloxGdiPlus.DrawCard(C, Rect(0, 0, FSearchContainer.Width, FSearchContainer.Height),
    FColors.SurfaceCard, FColors.Border, 4);
end;

procedure TVeloxDataStudio.Paint;
begin
  inherited Paint;
end;

procedure TVeloxDataStudio.Resize;
begin
  inherited Resize;
  if Assigned(FBtnExportMd) and Assigned(FTopBar) then
  begin
    FBtnExportMd.SetBounds(FTopBar.Width - 58, 8, 50, 28);
    if Assigned(FBtnExportJson) then
      FBtnExportJson.SetBounds(FTopBar.Width - 114, 8, 52, 28);
    if Assigned(FBtnExportCsv) then
      FBtnExportCsv.SetBounds(FTopBar.Width - 168, 8, 50, 28);
  end;
end;

end.
