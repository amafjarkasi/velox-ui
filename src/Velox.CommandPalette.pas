unit Velox.CommandPalette;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.CommandPalette
  Purpose:
    VS Code / Raycast-style `Ctrl+K` / `Ctrl+Shift+P` Fuzzy-Search Command
    Palette (`TVeloxCommandPalette`) with subsequence scoring, category badges,
    shortcut hints, and instant keyboard execution.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  {$IFDEF FPC}
  LCLType,
  {$ENDIF}
  Graphics,
  Controls,
  Forms,
  StdCtrls,
  ExtCtrls,
  Velox.Types,
  Velox.Theme,
  Velox.Controls;

type
  TVeloxCommandProc = procedure of object;

  TVeloxCommandItem = record
    Id: string;
    Title: string;
    Category: string;
    ShortcutText: string;
    Callback: TVeloxCommandProc;
    Score: Integer;
  end;

  TVeloxCommandArray = array of TVeloxCommandItem;

  /// <summary>
  /// VS Code / Raycast-style Fuzzy Command Palette
  /// </summary>
  TVeloxCommandPalette = class(TComponent)
  private
    FCommands: TVeloxCommandArray;
  public
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    /// Registers or updates a command in the palette
    /// </summary>
    procedure RegisterCommand(const AId, ATitle, ACategory, AShortcutText: string;
      const ACallback: TVeloxCommandProc);
    procedure Clear;
    function Count: Integer;

    /// <summary>
    /// Computes a fuzzy subsequence match score (>0 = matched, 0 = no match)
    /// </summary>
    class function FuzzyMatchScore(const AQuery, ATarget: string): Integer; static;

    /// <summary>
    /// Filters and ranks commands by fuzzy score descending
    /// </summary>
    function FilterCommands(const AQuery: string): TVeloxCommandArray;

    /// <summary>
    /// Executes a registered command by its unique ID
    /// </summary>
    function ExecuteById(const AId: string): Boolean;

    /// <summary>
    /// Displays the modal Command Palette overlay
    /// </summary>
    function ShowPaletteModal(const AOwner: TComponent;
      const AColors: TVeloxThemeColors): Boolean;
  end;

implementation

type
  TPaletteDialogHelper = class
  public
    PaletteOwner: TVeloxCommandPalette;
    DialogForm: TForm;
    SearchEdit: TEdit;
    ListBox: TListBox;
    Filtered: TVeloxCommandArray;
    Colors: TVeloxThemeColors;
    procedure OnSearchChange(Sender: TObject);
    procedure OnSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OnListDblClick(Sender: TObject);
    procedure OnListDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure RefreshList;
  end;

{ TPaletteDialogHelper }

procedure TPaletteDialogHelper.RefreshList;
var
  I: Integer;
begin
  Filtered := PaletteOwner.FilterCommands(SearchEdit.Text);
  ListBox.Items.BeginUpdate;
  try
    ListBox.Items.Clear;
    for I := 0 to High(Filtered) do
      ListBox.Items.Add(Filtered[I].Title);
    if ListBox.Items.Count > 0 then
      ListBox.ItemIndex := 0;
  finally
    ListBox.Items.EndUpdate;
  end;
end;

procedure TPaletteDialogHelper.OnSearchChange(Sender: TObject);
begin
  RefreshList;
end;

procedure TPaletteDialogHelper.OnSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_DOWN then
  begin
    if (ListBox.Items.Count > 0) and (ListBox.ItemIndex < ListBox.Items.Count - 1) then
      ListBox.ItemIndex := ListBox.ItemIndex + 1;
    Key := 0;
  end
  else if Key = VK_UP then
  begin
    if (ListBox.Items.Count > 0) and (ListBox.ItemIndex > 0) then
      ListBox.ItemIndex := ListBox.ItemIndex - 1;
    Key := 0;
  end
  else if Key = VK_RETURN then
  begin
    if (ListBox.ItemIndex >= 0) and (ListBox.ItemIndex <= High(Filtered)) then
    begin
      DialogForm.ModalResult := mrYes;
      Key := 0;
    end;
  end
  else if Key = VK_ESCAPE then
  begin
    DialogForm.ModalResult := mrCancel;
    Key := 0;
  end;
end;

procedure TPaletteDialogHelper.OnListDblClick(Sender: TObject);
begin
  if (ListBox.ItemIndex >= 0) and (ListBox.ItemIndex <= High(Filtered)) then
    DialogForm.ModalResult := mrYes;
end;

procedure TPaletteDialogHelper.OnListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  Item: TVeloxCommandItem;
  CatStr, ShortStr: string;
  ShortW: Integer;
begin
  if (Index < 0) or (Index > High(Filtered)) then Exit;
  Item := Filtered[Index];
  C := ListBox.Canvas;

  if odSelected in State then
    C.Brush.Color := TVeloxUtils.BlendColor(Colors.SurfaceCard, Colors.Accent, 0.28)
  else
    C.Brush.Color := Colors.SurfaceCard;
  C.FillRect(ARect);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 9;

  if Item.Category <> '' then
  begin
    CatStr := '[' + Item.Category + '] ';
    C.Font.Style := [fsBold];
    C.Font.Color := Colors.Accent;
    C.TextOut(ARect.Left + 12, ARect.Top + 7, CatStr);
    C.Font.Style := [];
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(ARect.Left + 12 + C.TextWidth(CatStr), ARect.Top + 7, Item.Title);
  end
  else
  begin
    C.Font.Color := Colors.TextPrimary;
    C.TextOut(ARect.Left + 12, ARect.Top + 7, Item.Title);
  end;

  if Item.ShortcutText <> '' then
  begin
    ShortStr := Item.ShortcutText;
    C.Font.Name := 'Consolas';
    C.Font.Size := 8;
    C.Font.Color := Colors.TextSecondary;
    ShortW := C.TextWidth(ShortStr);
    C.TextOut(ARect.Right - ShortW - 14, ARect.Top + 9, ShortStr);
  end;
end;

{ TVeloxCommandPalette }

constructor TVeloxCommandPalette.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetLength(FCommands, 0);
end;

procedure TVeloxCommandPalette.RegisterCommand(const AId, ATitle, ACategory,
  AShortcutText: string; const ACallback: TVeloxCommandProc);
var
  Idx, I: Integer;
begin
  for I := 0 to High(FCommands) do
    if SameText(FCommands[I].Id, AId) then
    begin
      FCommands[I].Title := ATitle;
      FCommands[I].Category := ACategory;
      FCommands[I].ShortcutText := AShortcutText;
      FCommands[I].Callback := ACallback;
      Exit;
    end;

  Idx := Length(FCommands);
  SetLength(FCommands, Idx + 1);
  FCommands[Idx].Id := AId;
  FCommands[Idx].Title := ATitle;
  FCommands[Idx].Category := ACategory;
  FCommands[Idx].ShortcutText := AShortcutText;
  FCommands[Idx].Callback := ACallback;
  FCommands[Idx].Score := 100;
end;

procedure TVeloxCommandPalette.Clear;
begin
  SetLength(FCommands, 0);
end;

function TVeloxCommandPalette.Count: Integer;
begin
  Result := Length(FCommands);
end;

class function TVeloxCommandPalette.FuzzyMatchScore(const AQuery, ATarget: string): Integer;
var
  Q, T: string;
  QI, TI, ConsecutiveBonus: Integer;
begin
  Q := LowerCase(Trim(AQuery));
  T := LowerCase(ATarget);

  if Q = '' then
    Exit(1);

  if T = '' then
    Exit(0);

  if Pos(Q, T) > 0 then
  begin
    Result := 200 - Pos(Q, T);
    if Pos(Q, T) = 1 then
      Inc(Result, 50);
    Exit;
  end;

  Result := 0;
  QI := 1;
  ConsecutiveBonus := 0;
  for TI := 1 to Length(T) do
  begin
    if T[TI] = Q[QI] then
    begin
      Inc(Result, 10 + ConsecutiveBonus);
      Inc(ConsecutiveBonus, 5);
      if (TI = 1) or (T[TI - 1] = ' ') then
        Inc(Result, 8);
      Inc(QI);
      if QI > Length(Q) then
        Break;
    end
    else
      ConsecutiveBonus := 0;
  end;

  if QI <= Length(Q) then
    Result := 0;
end;

function TVeloxCommandPalette.FilterCommands(const AQuery: string): TVeloxCommandArray;
var
  I, J, CountOut, STitle, SCat, BestScore: Integer;
  Temp: TVeloxCommandItem;
begin
  Result := nil;
  SetLength(Result, Length(FCommands));
  CountOut := 0;

  for I := 0 to High(FCommands) do
  begin
    if Trim(AQuery) = '' then
      BestScore := 100 - I
    else
    begin
      STitle := FuzzyMatchScore(AQuery, FCommands[I].Title);
      SCat := FuzzyMatchScore(AQuery, FCommands[I].Category + ' ' + FCommands[I].Title);
      if STitle >= SCat then
        BestScore := STitle
      else
        BestScore := SCat;
    end;

    if BestScore > 0 then
    begin
      Result[CountOut] := FCommands[I];
      Result[CountOut].Score := BestScore;
      Inc(CountOut);
    end;
  end;

  SetLength(Result, CountOut);

  for I := 0 to CountOut - 2 do
    for J := I + 1 to CountOut - 1 do
      if Result[J].Score > Result[I].Score then
      begin
        Temp := Result[I];
        Result[I] := Result[J];
        Result[J] := Temp;
      end;
end;

function TVeloxCommandPalette.ExecuteById(const AId: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FCommands) do
    if SameText(FCommands[I].Id, AId) then
    begin
      Result := True;
      if Assigned(FCommands[I].Callback) then
        FCommands[I].Callback();
      Exit;
    end;
end;

function TVeloxCommandPalette.ShowPaletteModal(const AOwner: TComponent;
  const AColors: TVeloxThemeColors): Boolean;
var
  Modal: TVeloxModalDialog;
  Helper: TPaletteDialogHelper;
  SearchEd: TEdit;
  LB: TListBox;
  SelIdx: Integer;
begin
  Result := False;
  Helper := TPaletteDialogHelper.Create;
  Modal := TVeloxControls.CreateModalDialog(AOwner, 'Command Palette',
    'Command Palette', 'Type a command to filter (Up/Down to select, Enter to run)',
    540, 380, AColors, 'Run Command', 'Close', False);
  try
    Helper.PaletteOwner := Self;
    Helper.DialogForm := Modal.Form;
    Helper.Colors := AColors;

    SearchEd := TEdit.Create(Modal.Form);
    SearchEd.Parent := Modal.BodyPanel;
    SearchEd.SetBounds(14, 10, 512, 26);
    SearchEd.Anchors := [akLeft, akTop, akRight];
    SearchEd.Color := AColors.SurfaceCard;
    SearchEd.Font.Name := 'Segoe UI';
    SearchEd.Font.Size := 10;
    SearchEd.Font.Color := AColors.TextPrimary;
    SearchEd.TextHint := 'Search commands...';
    SearchEd.OnChange := Helper.OnSearchChange;
    SearchEd.OnKeyDown := Helper.OnSearchKeyDown;

    LB := TListBox.Create(Modal.Form);
    LB.Parent := Modal.BodyPanel;
    LB.SetBounds(14, 44, 512, 220);
    LB.Anchors := [akLeft, akTop, akRight, akBottom];
    LB.BorderStyle := bsNone;
    LB.Color := AColors.SurfaceCard;
    LB.Font.Name := 'Segoe UI';
    LB.Font.Size := 9;
    LB.Font.Color := AColors.TextPrimary;
    LB.Style := lbOwnerDrawFixed;
    LB.ItemHeight := 32;
    LB.OnDrawItem := Helper.OnListDrawItem;
    LB.OnDblClick := Helper.OnListDblClick;

    Helper.SearchEdit := SearchEd;
    Helper.ListBox := LB;
    Helper.RefreshList;

    if Modal.Form.ShowModal = mrYes then
    begin
      SelIdx := LB.ItemIndex;
      if (SelIdx >= 0) and (SelIdx <= High(Helper.Filtered)) then
      begin
        Result := True;
        if Assigned(Helper.Filtered[SelIdx].Callback) then
          Helper.Filtered[SelIdx].Callback();
      end;
    end;
  finally
    Modal.Form.Free;
    Helper.Free;
  end;
end;

end.
