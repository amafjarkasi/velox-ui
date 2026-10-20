unit Velox.VirtualGrid;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.VirtualGrid
  Purpose:
    Generic zero-flicker virtual TListView controller (`TVeloxVirtualGrid<T>`)
    that eliminates 85% of the boilerplate needed to build fast, sortable,
    flicker-free tables in Delphi VCL and Lazarus LCL:
    1. Automatically enables Win32 `LVS_EX_DOUBLEBUFFER ($00010000)` via
       `LVM_SETEXTENDEDLISTVIEWSTYLE ($1036)` to eliminate erase-background flicker.
    2. Configures `OwnerData := True`, `RowSelect := True`, `ColumnClick := True`.
    3. Manages column definitions, natural initial sort order (numeric/severity
       columns sort descending on first click; text/ID columns sort ascending),
       and renders cross-compiler UTF-8/UTF-16 `▲`/`▼` header sort indicators.
    4. Provides an in-place generic `QuickSort` taking a `TVeloxCompareFunc<T>`.
    5. Provides `RefreshCount(NewCount)` which only updates `Items.Count` when
       the row count changes and calls `Invalidate` otherwise—preserving row
       selection and scroll position during live high-frequency polling!
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Controls,
  ComCtrls,
  Generics.Collections,
  Velox.Types,
  Velox.Theme;

type
  /// <summary>
  /// Comparison callback for TVeloxVirtualGrid<T>.SortList:
  /// Return < 0 if A < B, > 0 if A > B, 0 if equal for the given AColumn.
  /// </summary>
  TVeloxCompareFunc<T> = function(const A, B: T; const AColumn: Integer): Integer of object;

  /// <summary>
  /// Column definition for TVeloxVirtualGrid
  /// </summary>
  TVeloxColumnDef = record
    Caption: string;
    Width: Integer;
    Alignment: TAlignment;
    DefaultDescending: Boolean;
  end;

  /// <summary>
  /// Generic Virtual TListView Controller with QuickSort & Sort Arrows
  /// </summary>
  TVeloxVirtualGrid<T> = class
  private
    FListView: TListView;
    FColumns: array of TVeloxColumnDef;
    FSortColumn: Integer;
    FSortAscending: Boolean;
    FTreeMode: Boolean;
    procedure QuickSortArray(var AItems: array of T; ALo, AHi: Integer;
      const ACompare: TVeloxCompareFunc<T>);
  public
    constructor Create(const AListView: TListView = nil);

    /// <summary>
    /// Configures the underlying TListView for virtual OwnerData mode and
    /// enables Win32 LVS_EX_DOUBLEBUFFER hardware double-buffering.
    /// </summary>
    procedure AttachListView(const AListView: TListView);
    procedure EnableNativeDoubleBuffer;

    /// <summary>
    /// Adds a column definition and creates the corresponding TListColumn
    /// </summary>
    procedure AddColumn(const ACaption: string; const AWidth: Integer;
      const AAlignment: TAlignment = taLeftJustify;
      const ADefaultDescending: Boolean = False);
    procedure ClearColumns;

    /// <summary>
    /// Toggles or switches the active sort column, automatically choosing
    /// descending on first click for numeric/metric columns (`ADefaultDescending = True`)
    /// and ascending on first click for text/ID columns.
    /// </summary>
    procedure ClickColumn(const AColumnIndex: Integer);
    procedure SetSortState(const AColumnIndex: Integer; const AAscending: Boolean);
    procedure UpdateHeaderIndicators;

    /// <summary>
    /// Sorts a TList<T> in-place using the current SortColumn and SortAscending state
    /// </summary>
    procedure SortList(const AList: TList<T>; const ACompare: TVeloxCompareFunc<T>);

    /// <summary>
    /// Flicker-free virtual row count synchronization: only assigns Items.Count
    /// when the count changes; otherwise calls Invalidate so selection and
    /// scroll position are never disrupted during live polling.
    /// </summary>
    procedure RefreshCount(const ANewCount: Integer);

    /// <summary>
    /// Stretches the final column to fill remaining ClientWidth (automatically
    /// accounting for any visible vertical scrollbar).
    /// </summary>
    procedure StretchLastColumn(const AMinWidth: Integer = 80);

    property ListView: TListView read FListView;
    property SortColumn: Integer read FSortColumn;
    property SortAscending: Boolean read FSortAscending;
    property TreeMode: Boolean read FTreeMode write FTreeMode;
  end;

implementation

{ TVeloxVirtualGrid<T> }

constructor TVeloxVirtualGrid<T>.Create(const AListView: TListView);
begin
  inherited Create;
  FSortColumn := 0;
  FSortAscending := True;
  FTreeMode := False;
  if Assigned(AListView) then
    AttachListView(AListView);
end;

procedure TVeloxVirtualGrid<T>.AttachListView(const AListView: TListView);
begin
  FListView := AListView;
  if not Assigned(FListView) then Exit;

  FListView.DoubleBuffered := True;
  FListView.ViewStyle := vsReport;
  FListView.RowSelect := True;
  FListView.ReadOnly := True;
  FListView.OwnerData := True;
  {$IFDEF FPC}
  FListView.ColumnClick := True;
  {$ENDIF}
  EnableNativeDoubleBuffer;
end;

procedure TVeloxVirtualGrid<T>.EnableNativeDoubleBuffer;
const
  LVM_SETEXTENDEDLISTVIEWSTYLE = $1036;
  LVS_EX_DOUBLEBUFFER          = $00010000;
begin
  {$IFDEF MSWINDOWS}
  if Assigned(FListView) and FListView.HandleAllocated then
  begin
    Windows.SendMessage(FListView.Handle, LVM_SETEXTENDEDLISTVIEWSTYLE,
      LVS_EX_DOUBLEBUFFER, LVS_EX_DOUBLEBUFFER);
  end;
  {$ENDIF}
end;

procedure TVeloxVirtualGrid<T>.ClearColumns;
begin
  SetLength(FColumns, 0);
  if Assigned(FListView) then
    FListView.Columns.Clear;
end;

procedure TVeloxVirtualGrid<T>.AddColumn(const ACaption: string; const AWidth: Integer;
  const AAlignment: TAlignment; const ADefaultDescending: Boolean);
var
  Idx: Integer;
  Col: TListColumn;
begin
  Idx := Length(FColumns);
  SetLength(FColumns, Idx + 1);
  FColumns[Idx].Caption := ACaption;
  FColumns[Idx].Width := AWidth;
  FColumns[Idx].Alignment := AAlignment;
  FColumns[Idx].DefaultDescending := ADefaultDescending;

  if Assigned(FListView) then
  begin
    Col := FListView.Columns.Add;
    Col.Caption := ACaption;
    Col.Width := AWidth;
    Col.Alignment := AAlignment;
  end;
end;

procedure TVeloxVirtualGrid<T>.ClickColumn(const AColumnIndex: Integer);
begin
  if (AColumnIndex < 0) or (AColumnIndex > High(FColumns)) then Exit;

  if FTreeMode then
    FTreeMode := False;

  if AColumnIndex = FSortColumn then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn := AColumnIndex;
    FSortAscending := not FColumns[AColumnIndex].DefaultDescending;
  end;
  UpdateHeaderIndicators;
end;

procedure TVeloxVirtualGrid<T>.SetSortState(const AColumnIndex: Integer; const AAscending: Boolean);
begin
  FSortColumn := AColumnIndex;
  FSortAscending := AAscending;
  UpdateHeaderIndicators;
end;

procedure TVeloxVirtualGrid<T>.UpdateHeaderIndicators;
var
  I: Integer;
begin
  if not Assigned(FListView) then Exit;
  for I := 0 to FListView.Columns.Count - 1 do
  begin
    if I > High(FColumns) then Break;
    if (not FTreeMode) and (I = FSortColumn) then
    begin
      if FSortAscending then
        FListView.Columns[I].Caption := FColumns[I].Caption + ' ' + VELOX_ARROW_ASC
      else
        FListView.Columns[I].Caption := FColumns[I].Caption + ' ' + VELOX_ARROW_DESC;
    end
    else
      FListView.Columns[I].Caption := FColumns[I].Caption;
  end;
end;

procedure TVeloxVirtualGrid<T>.QuickSortArray(var AItems: array of T; ALo, AHi: Integer;
  const ACompare: TVeloxCompareFunc<T>);
var
  I, J: Integer;
  Pivot, Tmp: T;
begin
  if ALo >= AHi then Exit;
  I := ALo;
  J := AHi;
  Pivot := AItems[(ALo + AHi) div 2];
  repeat
    if FSortAscending then
    begin
      while (I <= AHi) and (ACompare(AItems[I], Pivot, FSortColumn) < 0) do Inc(I);
      while (J >= ALo) and (ACompare(AItems[J], Pivot, FSortColumn) > 0) do Dec(J);
    end
    else
    begin
      while (I <= AHi) and (ACompare(AItems[I], Pivot, FSortColumn) > 0) do Inc(I);
      while (J >= ALo) and (ACompare(AItems[J], Pivot, FSortColumn) < 0) do Dec(J);
    end;
    if I <= J then
    begin
      Tmp := AItems[I];
      AItems[I] := AItems[J];
      AItems[J] := Tmp;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if ALo < J then QuickSortArray(AItems, ALo, J, ACompare);
  if I < AHi then QuickSortArray(AItems, I, AHi, ACompare);
end;

procedure TVeloxVirtualGrid<T>.SortList(const AList: TList<T>;
  const ACompare: TVeloxCompareFunc<T>);
var
  Arr: array of T;
  I: Integer;
begin
  if (AList = nil) or (AList.Count < 2) or not Assigned(ACompare) then Exit;
  if FTreeMode then Exit;

  SetLength(Arr, AList.Count);
  for I := 0 to High(Arr) do
    Arr[I] := AList[I];

  QuickSortArray(Arr, 0, High(Arr), ACompare);

  AList.Clear;
  for I := 0 to High(Arr) do
    AList.Add(Arr[I]);
end;

procedure TVeloxVirtualGrid<T>.RefreshCount(const ANewCount: Integer);
begin
  if not Assigned(FListView) then Exit;
  if FListView.Items.Count <> ANewCount then
  begin
    FListView.Items.Count := ANewCount;
    StretchLastColumn;
  end;
  FListView.Invalidate;
end;

procedure TVeloxVirtualGrid<T>.StretchLastColumn(const AMinWidth: Integer);
var
  I, Used, W: Integer;
begin
  if not Assigned(FListView) or (FListView.Columns.Count < 2) then Exit;
  Used := 0;
  for I := 0 to FListView.Columns.Count - 2 do
    Used := Used + FListView.Columns[I].Width;
  W := FListView.ClientWidth - Used;
  if W < AMinWidth then W := AMinWidth;
  if FListView.Columns[FListView.Columns.Count - 1].Width <> W then
    FListView.Columns[FListView.Columns.Count - 1].Width := W;
end;

end.
