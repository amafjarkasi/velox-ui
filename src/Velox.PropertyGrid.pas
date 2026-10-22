unit Velox.PropertyGrid;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Controls, Graphics, Forms, Types,
  Velox.Types;

type
  TVeloxPropType = (vptString, vptBoolean, vptInteger, vptColor);

  TVeloxPropItem = record
    Key: string;
    DisplayName: string;
    Category: string;
    PropType: TVeloxPropType;
    StringValue: string;
    BoolValue: Boolean;
    IntValue: Integer;
    ColorValue: TColor;
    ReadOnly: Boolean;
  end;

  TVeloxPropCategory = record
    Name: string;
    Expanded: Boolean;
  end;

  TVeloxPropChangeEvent = procedure(Sender: TObject; const AKey: string; const ANewVal: string) of object;

  TVeloxPropertyGrid = class(TCustomControl)
  private
    FItems: array of TVeloxPropItem;
    FCategories: array of TVeloxPropCategory;
    FColors: TVeloxThemeColors;
    FRowHeight: Integer;
    FSplitterX: Integer;
    FScrollY: Integer;
    FHotRowIndex: Integer;
    FSelectedKey: string;
    FOnChange: TVeloxPropChangeEvent;
    function FindCategoryIndex(const AName: string): Integer;
    function IsCategoryExpanded(const AName: string): Boolean;
    procedure ToggleCategory(const AName: string);
    function TotalVisibleRows: Integer;
    procedure ClampScroll;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Resize; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure Clear;
    function AddCategory(const AName: string; const AExpanded: Boolean = True): Integer;
    function AddString(const ACategory, AKey, ADisplayName, AValue: string; const AReadOnly: Boolean = False): Integer;
    function AddBoolean(const ACategory, AKey, ADisplayName: string; const AValue: Boolean; const AReadOnly: Boolean = False): Integer;
    function AddInteger(const ACategory, AKey, ADisplayName: string; const AValue: Integer; const AReadOnly: Boolean = False): Integer;
    function AddColor(const ACategory, AKey, ADisplayName: string; const AValue: TColor; const AReadOnly: Boolean = False): Integer;

    function GetString(const AKey: string; const ADef: string = ''): string;
    function GetBoolean(const AKey: string; const ADef: Boolean = False): Boolean;
    function GetInteger(const AKey: string; const ADef: Integer = 0): Integer;
    function GetPropColor(const AKey: string; const ADef: TColor = clWhite): TColor;

    procedure SetString(const AKey, AValue: string);
    procedure SetBoolean(const AKey: string; const AValue: Boolean);
    procedure SetInteger(const AKey: string; const AValue: Integer);
    procedure SetPropColor(const AKey: string; const AValue: TColor);

    function Count: Integer;
    function GetItem(Index: Integer): TVeloxPropItem;
    property Items[Index: Integer]: TVeloxPropItem read GetItem; default;
    property ItemCount: Integer read Count;
    property SelectedKey: string read FSelectedKey write FSelectedKey;
    property OnChange: TVeloxPropChangeEvent read FOnChange write FOnChange;
  published
    property Align;
    property Anchors;
    property RowHeight: Integer read FRowHeight write FRowHeight default 24;
    property SplitterX: Integer read FSplitterX write FSplitterX default 180;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxPropertyGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 340;
  Height := 380;
  FRowHeight := 24;
  FSplitterX := 160;
  FScrollY := 0;
  FHotRowIndex := -1;
  FSelectedKey := '';
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  SetLength(FItems, 0);
  SetLength(FCategories, 0);
end;

procedure TVeloxPropertyGrid.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxPropertyGrid.Clear;
begin
  SetLength(FItems, 0);
  SetLength(FCategories, 0);
  FSelectedKey := '';
  FScrollY := 0;
  Invalidate;
end;

function TVeloxPropertyGrid.Count: Integer;
begin
  Result := Length(FItems);
end;

function TVeloxPropertyGrid.GetItem(Index: Integer): TVeloxPropItem;
begin
  if (Index >= 0) and (Index < Length(FItems)) then
    Result := FItems[Index]
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function TVeloxPropertyGrid.FindCategoryIndex(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FCategories) do
    if SameText(FCategories[I].Name, AName) then
      Exit(I);
end;

function TVeloxPropertyGrid.AddCategory(const AName: string; const AExpanded: Boolean): Integer;
var
  Idx, L: Integer;
begin
  Idx := FindCategoryIndex(AName);
  if Idx >= 0 then
    Exit(Idx);
  L := Length(FCategories);
  SetLength(FCategories, L + 1);
  FCategories[L].Name := AName;
  FCategories[L].Expanded := AExpanded;
  Invalidate;
  Result := L;
end;

function TVeloxPropertyGrid.IsCategoryExpanded(const AName: string): Boolean;
var
  Idx: Integer;
begin
  Idx := FindCategoryIndex(AName);
  if Idx >= 0 then
    Result := FCategories[Idx].Expanded
  else
    Result := True;
end;

procedure TVeloxPropertyGrid.ToggleCategory(const AName: string);
var
  Idx: Integer;
begin
  Idx := FindCategoryIndex(AName);
  if Idx >= 0 then
  begin
    FCategories[Idx].Expanded := not FCategories[Idx].Expanded;
    ClampScroll;
    Invalidate;
  end;
end;

function TVeloxPropertyGrid.AddString(const ACategory, AKey, ADisplayName, AValue: string; const AReadOnly: Boolean): Integer;
var
  L: Integer;
begin
  AddCategory(ACategory);
  L := Length(FItems);
  SetLength(FItems, L + 1);
  FItems[L].Category := ACategory;
  FItems[L].Key := AKey;
  FItems[L].DisplayName := ADisplayName;
  FItems[L].PropType := vptString;
  FItems[L].StringValue := AValue;
  FItems[L].ReadOnly := AReadOnly;
  Invalidate;
  Result := L;
end;

function TVeloxPropertyGrid.AddBoolean(const ACategory, AKey, ADisplayName: string; const AValue: Boolean; const AReadOnly: Boolean): Integer;
var
  L: Integer;
begin
  AddCategory(ACategory);
  L := Length(FItems);
  SetLength(FItems, L + 1);
  FItems[L].Category := ACategory;
  FItems[L].Key := AKey;
  FItems[L].DisplayName := ADisplayName;
  FItems[L].PropType := vptBoolean;
  FItems[L].BoolValue := AValue;
  FItems[L].ReadOnly := AReadOnly;
  Invalidate;
  Result := L;
end;

function TVeloxPropertyGrid.AddInteger(const ACategory, AKey, ADisplayName: string; const AValue: Integer; const AReadOnly: Boolean): Integer;
var
  L: Integer;
begin
  AddCategory(ACategory);
  L := Length(FItems);
  SetLength(FItems, L + 1);
  FItems[L].Category := ACategory;
  FItems[L].Key := AKey;
  FItems[L].DisplayName := ADisplayName;
  FItems[L].PropType := vptInteger;
  FItems[L].IntValue := AValue;
  FItems[L].ReadOnly := AReadOnly;
  Invalidate;
  Result := L;
end;

function TVeloxPropertyGrid.AddColor(const ACategory, AKey, ADisplayName: string; const AValue: TColor; const AReadOnly: Boolean): Integer;
var
  L: Integer;
begin
  AddCategory(ACategory);
  L := Length(FItems);
  SetLength(FItems, L + 1);
  FItems[L].Category := ACategory;
  FItems[L].Key := AKey;
  FItems[L].DisplayName := ADisplayName;
  FItems[L].PropType := vptColor;
  FItems[L].ColorValue := AValue;
  FItems[L].ReadOnly := AReadOnly;
  Invalidate;
  Result := L;
end;

function TVeloxPropertyGrid.GetString(const AKey: string; const ADef: string): string;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if SameText(FItems[I].Key, AKey) then
      Exit(FItems[I].StringValue);
  Result := ADef;
end;

function TVeloxPropertyGrid.GetBoolean(const AKey: string; const ADef: Boolean): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if SameText(FItems[I].Key, AKey) then
      Exit(FItems[I].BoolValue);
  Result := ADef;
end;

function TVeloxPropertyGrid.GetInteger(const AKey: string; const ADef: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if SameText(FItems[I].Key, AKey) then
      Exit(FItems[I].IntValue);
  Result := ADef;
end;

function TVeloxPropertyGrid.GetPropColor(const AKey: string; const ADef: TColor): TColor;
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
    if SameText(FItems[I].Key, AKey) then
      Exit(FItems[I].ColorValue);
  Result := ADef;
end;

procedure TVeloxPropertyGrid.SetString(const AKey, AValue: string);
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
  begin
    if SameText(FItems[I].Key, AKey) then
    begin
      FItems[I].StringValue := AValue;
      Invalidate;
      if Assigned(FOnChange) then
        FOnChange(Self, AKey, AValue);
      Exit;
    end;
  end;
end;

procedure TVeloxPropertyGrid.SetBoolean(const AKey: string; const AValue: Boolean);
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
  begin
    if SameText(FItems[I].Key, AKey) then
    begin
      FItems[I].BoolValue := AValue;
      Invalidate;
      if Assigned(FOnChange) then
        FOnChange(Self, AKey, BoolToStr(AValue, True));
      Exit;
    end;
  end;
end;

procedure TVeloxPropertyGrid.SetInteger(const AKey: string; const AValue: Integer);
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
  begin
    if SameText(FItems[I].Key, AKey) then
    begin
      FItems[I].IntValue := AValue;
      Invalidate;
      if Assigned(FOnChange) then
        FOnChange(Self, AKey, IntToStr(AValue));
      Exit;
    end;
  end;
end;

procedure TVeloxPropertyGrid.SetPropColor(const AKey: string; const AValue: TColor);
var
  I: Integer;
begin
  for I := 0 to High(FItems) do
  begin
    if SameText(FItems[I].Key, AKey) then
    begin
      FItems[I].ColorValue := AValue;
      Invalidate;
      if Assigned(FOnChange) then
        FOnChange(Self, AKey, '$' + IntToHex(AValue, 6));
      Exit;
    end;
  end;
end;

function TVeloxPropertyGrid.TotalVisibleRows: Integer;
var
  C, I: Integer;
begin
  Result := Length(FCategories);
  for C := 0 to High(FCategories) do
  begin
    if FCategories[C].Expanded then
    begin
      for I := 0 to High(FItems) do
        if SameText(FItems[I].Category, FCategories[C].Name) then
          Inc(Result);
    end;
  end;
end;

procedure TVeloxPropertyGrid.ClampScroll;
var
  MaxScroll: Integer;
begin
  MaxScroll := TotalVisibleRows * FRowHeight - Height;
  if MaxScroll < 0 then MaxScroll := 0;
  if FScrollY > MaxScroll then FScrollY := MaxScroll;
  if FScrollY < 0 then FScrollY := 0;
end;

function TVeloxPropertyGrid.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  Inc(FScrollY, -(WheelDelta div 120) * (FRowHeight * 2));
  ClampScroll;
  Invalidate;
end;

procedure TVeloxPropertyGrid.Resize;
begin
  inherited Resize;
  ClampScroll;
  Invalidate;
end;

procedure TVeloxPropertyGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  RowIdx: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  RowIdx := (Y + FScrollY) div FRowHeight;
  if RowIdx <> FHotRowIndex then
  begin
    FHotRowIndex := RowIdx;
    Invalidate;
  end;
end;

procedure TVeloxPropertyGrid.MouseLeave;
begin
  inherited MouseLeave;
  if FHotRowIndex <> -1 then
  begin
    FHotRowIndex := -1;
    Invalidate;
  end;
end;

procedure TVeloxPropertyGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  CurY, C, I: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;

  CurY := -FScrollY;
  for C := 0 to High(FCategories) do
  begin
    if (Y >= CurY) and (Y < CurY + FRowHeight) then
    begin
      ToggleCategory(FCategories[C].Name);
      Exit;
    end;
    Inc(CurY, FRowHeight);

    if FCategories[C].Expanded then
    begin
      for I := 0 to High(FItems) do
      begin
        if SameText(FItems[I].Category, FCategories[C].Name) then
        begin
          if (Y >= CurY) and (Y < CurY + FRowHeight) then
          begin
            FSelectedKey := FItems[I].Key;
            // Boolean toggle click on value column
            if (FItems[I].PropType = vptBoolean) and (not FItems[I].ReadOnly) and (X > FSplitterX) then
              SetBoolean(FItems[I].Key, not FItems[I].BoolValue);
            Invalidate;
            Exit;
          end;
          Inc(CurY, FRowHeight);
        end;
      end;
    end;
  end;
end;

procedure TVeloxPropertyGrid.Paint;
var
  CurY, C, I: Integer;
  R, KeyR, ValR, LocalR: TRect;
  ChevronStr, ValStr: string;
begin
  // Background
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);

  CurY := -FScrollY;
  Canvas.Font.Name := 'Segoe UI';

  for C := 0 to High(FCategories) do
  begin
    if (CurY + FRowHeight >= 0) and (CurY <= Height) then
    begin
      // Category Header Bar
      R := Rect(0, CurY, Width, CurY + FRowHeight);
      Canvas.Brush.Color := FColors.SurfaceCard;
      Canvas.FillRect(R);

      // Chevron
      if FCategories[C].Expanded then
        ChevronStr := '-'
      else
        ChevronStr := '+';

      Canvas.Font.Size := 9;
      Canvas.Font.Style := [fsBold];
      Canvas.Font.Color := FColors.Accent;
      LocalR := Rect(6, CurY, 20, CurY + FRowHeight);
      DrawText(Canvas.Handle, PChar(ChevronStr), Length(ChevronStr), LocalR,
        DT_SINGLELINE or DT_CENTER or DT_VCENTER);

      // Category Title
      Canvas.Font.Color := FColors.TextPrimary;
      LocalR := Rect(24, CurY, Width, CurY + FRowHeight);
      DrawText(Canvas.Handle, PChar(FCategories[C].Name), Length(FCategories[C].Name), LocalR,
        DT_SINGLELINE or DT_LEFT or DT_VCENTER);

      // Separator bottom line
      Canvas.Pen.Color := FColors.Border;
      Canvas.MoveTo(0, CurY + FRowHeight - 1);
      Canvas.LineTo(Width, CurY + FRowHeight - 1);
    end;
    Inc(CurY, FRowHeight);

    // Items in Category
    if FCategories[C].Expanded then
    begin
      for I := 0 to High(FItems) do
      begin
        if SameText(FItems[I].Category, FCategories[C].Name) then
        begin
          if (CurY + FRowHeight >= 0) and (CurY <= Height) then
          begin
            R := Rect(0, CurY, Width, CurY + FRowHeight);
            if FItems[I].Key = FSelectedKey then
              Canvas.Brush.Color := $1E293B
            else
              Canvas.Brush.Color := FColors.Background;
            Canvas.FillRect(R);

            // Property Key / DisplayName (Left column, exact vertical center)
            KeyR := Rect(16, CurY, FSplitterX - 4, CurY + FRowHeight);
            Canvas.Font.Size := 9;
            Canvas.Font.Style := [];
            Canvas.Font.Color := FColors.TextPrimary;
            LocalR := KeyR;
            DrawText(Canvas.Handle, PChar(FItems[I].DisplayName), Length(FItems[I].DisplayName), LocalR,
              DT_SINGLELINE or DT_LEFT or DT_VCENTER);

            // Column Splitter vertical line
            Canvas.Pen.Color := FColors.Border;
            Canvas.MoveTo(FSplitterX, CurY);
            Canvas.LineTo(FSplitterX, CurY + FRowHeight);

            // Property Value (Right column, exact vertical center)
            ValR := Rect(FSplitterX + 8, CurY, Width - 6, CurY + FRowHeight);
            case FItems[I].PropType of
              vptBoolean:
                begin
                  if FItems[I].BoolValue then
                  begin
                    Canvas.Font.Color := $34D399; // Emerald green
                    ValStr := 'True';
                  end
                  else
                  begin
                    Canvas.Font.Color := $94A3B8; // Slate muted
                    ValStr := 'False';
                  end;
                  LocalR := ValR;
                  DrawText(Canvas.Handle, PChar(ValStr), Length(ValStr), LocalR,
                    DT_SINGLELINE or DT_LEFT or DT_VCENTER);
                end;

              vptInteger:
                begin
                  Canvas.Font.Color := FColors.Accent;
                  ValStr := IntToStr(FItems[I].IntValue);
                  LocalR := ValR;
                  DrawText(Canvas.Handle, PChar(ValStr), Length(ValStr), LocalR,
                    DT_SINGLELINE or DT_LEFT or DT_VCENTER);
                end;

              vptColor:
                begin
                  // Draw Color Swatch Box
                  Canvas.Brush.Color := FItems[I].ColorValue;
                  Canvas.Pen.Color := FColors.Border;
                  Canvas.Rectangle(ValR.Left, CurY + 4, ValR.Left + 20, CurY + FRowHeight - 4);
                  // Hex string next to swatch
                  Canvas.Font.Color := FColors.TextPrimary;
                  ValStr := '#' + IntToHex(FItems[I].ColorValue, 6);
                  LocalR := Rect(ValR.Left + 26, CurY, ValR.Right, CurY + FRowHeight);
                  DrawText(Canvas.Handle, PChar(ValStr), Length(ValStr), LocalR,
                    DT_SINGLELINE or DT_LEFT or DT_VCENTER);
                end;

            else // vptString
              Canvas.Font.Color := FColors.TextPrimary;
              ValStr := FItems[I].StringValue;
              LocalR := ValR;
              DrawText(Canvas.Handle, PChar(ValStr), Length(ValStr), LocalR,
                DT_SINGLELINE or DT_LEFT or DT_VCENTER);
            end;

            // Row bottom hairline
            Canvas.Pen.Color := FColors.Border;
            Canvas.MoveTo(0, CurY + FRowHeight - 1);
            Canvas.LineTo(Width, CurY + FRowHeight - 1);
          end;
          Inc(CurY, FRowHeight);
        end;
      end;
    end;
  end;
end;

end.
