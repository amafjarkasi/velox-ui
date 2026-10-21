unit Velox.InspectorStudio;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.InspectorStudio (#66)
  Purpose:
    Composite Live Inspector & Config Studio combining:
      - TVeloxPropertyGrid (Two-column categories & inline editing)
      - TVeloxUndoStack (Multi-level undo/redo command transactions)
      - TVeloxColorPicker & TVeloxToggleSwitch
      - Top Toolbar with Dirty State Badge, Apply & Discard Actions
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
  Velox.GdiPlus,
  Velox.PropertyGrid,
  Velox.Undo,
  Velox.StyledButton;

type
  TVeloxInspectorStudio = class(TCustomControl)
  private
    FGrid: TVeloxPropertyGrid;
    FUndoStack: TVeloxUndoStack;
    FTopBar: TPanel;
    FBtnUndo: TVeloxStyledButton;
    FBtnRedo: TVeloxStyledButton;
    FBtnApply: TVeloxStyledButton;
    FBtnDiscard: TVeloxStyledButton;
    FColors: TVeloxThemeColors;
    FOnApply: TNotifyEvent;
    FOnDiscard: TNotifyEvent;
    procedure HandleUndoClick(Sender: TObject);
    procedure HandleRedoClick(Sender: TObject);
    procedure HandleApplyClick(Sender: TObject);
    procedure HandleDiscardClick(Sender: TObject);
    procedure UpdateToolbarButtons;
    function GetIsDirty: Boolean;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    // Forwarding helpers to internal PropertyGrid with Undo transaction tracking
    procedure AddString(const ACategory, AKey, AValue: string);
    procedure AddBoolean(const ACategory, AKey: string; const AValue: Boolean);
    procedure AddInteger(const ACategory, AKey: string; const AValue: Integer);
    procedure AddColor(const ACategory, AKey: string; const AValue: TColor);

    procedure SetString(const AKey, AValue: string);
    procedure SetBoolean(const AKey: string; const AValue: Boolean);
    procedure SetInteger(const AKey: string; const AValue: Integer);
    procedure SetPropColor(const AKey: string; const AValue: TColor);

    function GetString(const AKey: string): string;
    function GetBoolean(const AKey: string): Boolean;
    function GetInteger(const AKey: string): Integer;
    function GetPropColor(const AKey: string): TColor;

    procedure Undo;
    procedure Redo;
    procedure ApplyChanges;
    procedure DiscardChanges;

    property Grid: TVeloxPropertyGrid read FGrid;
    property UndoStack: TVeloxUndoStack read FUndoStack;
    property IsDirty: Boolean read GetIsDirty;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
    property OnApply: TNotifyEvent read FOnApply write FOnApply;
    property OnDiscard: TNotifyEvent read FOnDiscard write FOnDiscard;
  end;

implementation

type
  TPropUndoCommand = class(TInterfacedObject, IVeloxCommand)
  private
    FStudio: TVeloxInspectorStudio;
    FKey: string;
    FOldVal: string;
    FNewVal: string;
    FValType: TVeloxPropType;
  public
    constructor Create(AStudio: TVeloxInspectorStudio; const AKey, AOldV, ANewV: string; const AType: TVeloxPropType);
    procedure Execute;
    procedure Unexecute;
    function GetDescription: string;
  end;

{ TPropUndoCommand }

constructor TPropUndoCommand.Create(AStudio: TVeloxInspectorStudio; const AKey, AOldV, ANewV: string; const AType: TVeloxPropType);
begin
  inherited Create;
  FStudio := AStudio;
  FKey := AKey;
  FOldVal := AOldV;
  FNewVal := ANewV;
  FValType := AType;
end;

procedure TPropUndoCommand.Execute;
begin
  case FValType of
    vptString:  FStudio.Grid.SetString(FKey, FNewVal);
    vptBoolean: FStudio.Grid.SetBoolean(FKey, FNewVal = '1');
    vptInteger: FStudio.Grid.SetInteger(FKey, StrToIntDef(FNewVal, 0));
    vptColor:   FStudio.Grid.SetPropColor(FKey, StrToIntDef(FNewVal, 0));
  end;
end;

procedure TPropUndoCommand.Unexecute;
begin
  case FValType of
    vptString:  FStudio.Grid.SetString(FKey, FOldVal);
    vptBoolean: FStudio.Grid.SetBoolean(FKey, FOldVal = '1');
    vptInteger: FStudio.Grid.SetInteger(FKey, StrToIntDef(FOldVal, 0));
    vptColor:   FStudio.Grid.SetPropColor(FKey, StrToIntDef(FOldVal, 0));
  end;
end;

function TPropUndoCommand.GetDescription: string;
begin
  Result := Format('Change %s: %s -> %s', [FKey, FOldVal, FNewVal]);
end;

{ TVeloxInspectorStudio }

constructor TVeloxInspectorStudio.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 360;
  Height := 480;
  FColors := TVeloxUtils.GetThemeColors(vtDark);

  FUndoStack := TVeloxUndoStack.Create;

  // 1. Top Bar
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.Align := alTop;
  FTopBar.Height := 40;
  FTopBar.BevelOuter := bvNone;
  FTopBar.Color := FColors.Surface;

  // Buttons on TopBar
  FBtnUndo := TVeloxStyledButton.Create(Self);
  FBtnUndo.Parent := FTopBar;
  FBtnUndo.Caption := 'Undo';
  FBtnUndo.Variant := vsbOutline;
  FBtnUndo.SetBounds(8, 6, 60, 28);
  FBtnUndo.OnClick := HandleUndoClick;

  FBtnRedo := TVeloxStyledButton.Create(Self);
  FBtnRedo.Parent := FTopBar;
  FBtnRedo.Caption := 'Redo';
  FBtnRedo.Variant := vsbOutline;
  FBtnRedo.SetBounds(72, 6, 60, 28);
  FBtnRedo.OnClick := HandleRedoClick;

  FBtnDiscard := TVeloxStyledButton.Create(Self);
  FBtnDiscard.Parent := FTopBar;
  FBtnDiscard.Caption := 'Discard';
  FBtnDiscard.Variant := vsbSurface;
  FBtnDiscard.SetBounds(210, 6, 68, 28);
  FBtnDiscard.OnClick := HandleDiscardClick;

  FBtnApply := TVeloxStyledButton.Create(Self);
  FBtnApply.Parent := FTopBar;
  FBtnApply.Caption := 'Apply';
  FBtnApply.Variant := vsbPrimary;
  FBtnApply.SetBounds(284, 6, 68, 28);
  FBtnApply.OnClick := HandleApplyClick;

  // 2. Main Property Grid
  FGrid := TVeloxPropertyGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;

  ApplyColors(FColors);
  UpdateToolbarButtons;
end;

destructor TVeloxInspectorStudio.Destroy;
begin
  FUndoStack.Free;
  inherited Destroy;
end;

procedure TVeloxInspectorStudio.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  if Assigned(FTopBar) then
    FTopBar.Color := FColors.Surface;
  if Assigned(FGrid) then
    FGrid.ApplyColors(FColors);
  if Assigned(FBtnUndo) then FBtnUndo.ApplyColors(FColors);
  if Assigned(FBtnRedo) then FBtnRedo.ApplyColors(FColors);
  if Assigned(FBtnDiscard) then FBtnDiscard.ApplyColors(FColors);
  if Assigned(FBtnApply) then FBtnApply.ApplyColors(FColors);
  Invalidate;
end;

function TVeloxInspectorStudio.GetIsDirty: Boolean;
begin
  Result := FUndoStack.IsDirty;
end;

procedure TVeloxInspectorStudio.UpdateToolbarButtons;
begin
  if Assigned(FBtnUndo) then
    FBtnUndo.Enabled := FUndoStack.CanUndo;
  if Assigned(FBtnRedo) then
    FBtnRedo.Enabled := FUndoStack.CanRedo;
  if Assigned(FBtnApply) then
    FBtnApply.Enabled := FUndoStack.IsDirty;
  if Assigned(FBtnDiscard) then
    FBtnDiscard.Enabled := FUndoStack.IsDirty;
end;

procedure TVeloxInspectorStudio.HandleUndoClick(Sender: TObject);
begin
  Undo;
end;

procedure TVeloxInspectorStudio.HandleRedoClick(Sender: TObject);
begin
  Redo;
end;

procedure TVeloxInspectorStudio.HandleApplyClick(Sender: TObject);
begin
  ApplyChanges;
end;

procedure TVeloxInspectorStudio.HandleDiscardClick(Sender: TObject);
begin
  DiscardChanges;
end;

procedure TVeloxInspectorStudio.AddString(const ACategory, AKey, AValue: string);
begin
  FGrid.AddString(ACategory, AKey, AKey, AValue);
end;

procedure TVeloxInspectorStudio.AddBoolean(const ACategory, AKey: string; const AValue: Boolean);
begin
  FGrid.AddBoolean(ACategory, AKey, AKey, AValue);
end;

procedure TVeloxInspectorStudio.AddInteger(const ACategory, AKey: string; const AValue: Integer);
begin
  FGrid.AddInteger(ACategory, AKey, AKey, AValue);
end;

procedure TVeloxInspectorStudio.AddColor(const ACategory, AKey: string; const AValue: TColor);
begin
  FGrid.AddColor(ACategory, AKey, AKey, AValue);
end;

procedure TVeloxInspectorStudio.SetString(const AKey, AValue: string);
var
  OldV: string;
begin
  OldV := FGrid.GetString(AKey);
  if OldV <> AValue then
  begin
    FUndoStack.Push(TPropUndoCommand.Create(Self, AKey, OldV, AValue, vptString));
    FGrid.SetString(AKey, AValue);
    UpdateToolbarButtons;
  end;
end;

procedure TVeloxInspectorStudio.SetBoolean(const AKey: string; const AValue: Boolean);
var
  OldV: Boolean;
  OldS, NewS: string;
begin
  OldV := FGrid.GetBoolean(AKey);
  if OldV <> AValue then
  begin
    if OldV then OldS := '1' else OldS := '0';
    if AValue then NewS := '1' else NewS := '0';
    FUndoStack.Push(TPropUndoCommand.Create(Self, AKey, OldS, NewS, vptBoolean));
    FGrid.SetBoolean(AKey, AValue);
    UpdateToolbarButtons;
  end;
end;

procedure TVeloxInspectorStudio.SetInteger(const AKey: string; const AValue: Integer);
var
  OldV: Integer;
begin
  OldV := FGrid.GetInteger(AKey);
  if OldV <> AValue then
  begin
    FUndoStack.Push(TPropUndoCommand.Create(Self, AKey, IntToStr(OldV), IntToStr(AValue), vptInteger));
    FGrid.SetInteger(AKey, AValue);
    UpdateToolbarButtons;
  end;
end;

procedure TVeloxInspectorStudio.SetPropColor(const AKey: string; const AValue: TColor);
var
  OldV: TColor;
begin
  OldV := FGrid.GetPropColor(AKey);
  if OldV <> AValue then
  begin
    FUndoStack.Push(TPropUndoCommand.Create(Self, AKey, IntToStr(OldV), IntToStr(AValue), vptColor));
    FGrid.SetPropColor(AKey, AValue);
    UpdateToolbarButtons;
  end;
end;

function TVeloxInspectorStudio.GetString(const AKey: string): string;
begin
  Result := FGrid.GetString(AKey);
end;

function TVeloxInspectorStudio.GetBoolean(const AKey: string): Boolean;
begin
  Result := FGrid.GetBoolean(AKey);
end;

function TVeloxInspectorStudio.GetInteger(const AKey: string): Integer;
begin
  Result := FGrid.GetInteger(AKey);
end;

function TVeloxInspectorStudio.GetPropColor(const AKey: string): TColor;
begin
  Result := FGrid.GetPropColor(AKey);
end;

procedure TVeloxInspectorStudio.Undo;
begin
  FUndoStack.Undo;
  UpdateToolbarButtons;
  Invalidate;
end;

procedure TVeloxInspectorStudio.Redo;
begin
  FUndoStack.Redo;
  UpdateToolbarButtons;
  Invalidate;
end;

procedure TVeloxInspectorStudio.ApplyChanges;
begin
  FUndoStack.MarkClean;
  UpdateToolbarButtons;
  if Assigned(FOnApply) then
    FOnApply(Self);
end;

procedure TVeloxInspectorStudio.DiscardChanges;
begin
  while FUndoStack.CanUndo and FUndoStack.IsDirty do
    FUndoStack.Undo;
  FUndoStack.MarkClean;
  UpdateToolbarButtons;
  if Assigned(FOnDiscard) then
    FOnDiscard(Self);
end;

procedure TVeloxInspectorStudio.Paint;
begin
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);
end;

procedure TVeloxInspectorStudio.Resize;
begin
  inherited Resize;
  if Assigned(FBtnApply) and Assigned(FBtnDiscard) then
  begin
    FBtnApply.Left := Width - FBtnApply.Width - 8;
    FBtnDiscard.Left := FBtnApply.Left - FBtnDiscard.Width - 6;
  end;
end;

end.
