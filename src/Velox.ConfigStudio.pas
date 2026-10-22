unit Velox.ConfigStudio;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.ConfigStudio (#81)
  Purpose:
    Composite Profile, Environment & Application Configuration Studio combining:
      - TVeloxPropertyGrid (Two-column typed property editors)
      - TVeloxDiffView (Side-by-side & unified diff against default baseline)
      - TVeloxUndoStack (Transactional Undo/Redo rollback stack)
      - TVeloxJson (RFC-8259 profile serializer & exporter)
      - TVeloxTabs / Environment profile switcher
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
  StdCtrls,
  Velox.Types,
  Velox.GdiPlus,
  Velox.PropertyGrid,
  Velox.DiffView,
  Velox.Undo,
  Velox.Json,
  Velox.StyledButton;

type
  TVeloxConfigStudioView = (vcsvEditor, vcsvDiff);

  TVeloxConfigStudio = class(TCustomControl)
  private
    FColors: TVeloxThemeColors;
    FViewMode: TVeloxConfigStudioView;
    FActiveProfile: string;
    FDefaultJson: string;
    FProfiles: TStringList; // Name -> JSON
    FUndoStack: TVeloxUndoStack;
    FIsDirty: Boolean;

    // UI Controls
    FTopBar: TPanel;
    FBtnProfileDev: TVeloxStyledButton;
    FBtnProfileStaging: TVeloxStyledButton;
    FBtnProfileProd: TVeloxStyledButton;
    FBtnUndo: TVeloxStyledButton;
    FBtnRedo: TVeloxStyledButton;
    FBtnToggleView: TVeloxStyledButton;
    FBtnApply: TVeloxStyledButton;
    FBtnRevert: TVeloxStyledButton;

    FWorkContainer: TPanel;
    FPropGrid: TVeloxPropertyGrid;
    FDiffView: TVeloxDiffView;
    FFooterBar: TPanel;

    procedure SetViewMode(const Value: TVeloxConfigStudioView);
    procedure SwitchProfile(const AProfileName: string);
    procedure HandlePropertyChange(Sender: TObject; const AKey: string; const ANewVal: string);
    procedure HandleDevClick(Sender: TObject);
    procedure HandleStagingClick(Sender: TObject);
    procedure HandleProdClick(Sender: TObject);
    procedure HandleUndoClick(Sender: TObject);
    procedure HandleRedoClick(Sender: TObject);
    procedure HandleToggleViewClick(Sender: TObject);
    procedure HandleApplyClick(Sender: TObject);
    procedure HandleRevertClick(Sender: TObject);

    procedure TopBarPaint(Sender: TObject);
    procedure FooterBarPaint(Sender: TObject);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure RegisterDefaultSettings;
    function ExportProfileJson(const AProfileName: string): string;
    procedure ImportProfileJson(const AProfileName, AJsonText: string);
    procedure ApplyChanges;
    procedure DiscardChanges;

    property ActiveProfile: string read FActiveProfile;
    property ViewMode: TVeloxConfigStudioView read FViewMode write SetViewMode;
    property IsDirty: Boolean read FIsDirty;
    property PropertyGrid: TVeloxPropertyGrid read FPropGrid;
    property DiffView: TVeloxDiffView read FDiffView;
    property UndoStack: TVeloxUndoStack read FUndoStack;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

type
  TConfigUndoAction = class(TInterfacedObject, IVeloxCommand)
  private
    FStudio: TVeloxConfigStudio;
    FKey: string;
    FOldVal: string;
    FNewVal: string;
    function GetDescription: string;
  public
    constructor Create(AStudio: TVeloxConfigStudio; const AKey, AOldVal, ANewVal: string);
    procedure Execute;
    procedure Unexecute;
    property Description: string read GetDescription;
  end;

constructor TConfigUndoAction.Create(AStudio: TVeloxConfigStudio; const AKey, AOldVal, ANewVal: string);
begin
  inherited Create;
  FStudio := AStudio;
  FKey := AKey;
  FOldVal := AOldVal;
  FNewVal := ANewVal;
end;

procedure TConfigUndoAction.Unexecute;
begin
  if Assigned(FStudio) and Assigned(FStudio.FPropGrid) then
  begin
    FStudio.FPropGrid.SetString(FKey, FOldVal);
    FStudio.FPropGrid.Invalidate;
  end;
end;

procedure TConfigUndoAction.Execute;
begin
  if Assigned(FStudio) and Assigned(FStudio.FPropGrid) then
  begin
    FStudio.FPropGrid.SetString(FKey, FNewVal);
    FStudio.FPropGrid.Invalidate;
  end;
end;

function TConfigUndoAction.GetDescription: string;
begin
  Result := 'Change ' + FKey + ' to ' + FNewVal;
end;

{ TVeloxConfigStudio }

constructor TVeloxConfigStudio.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 840;
  Height := 520;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FViewMode := vcsvEditor;
  FActiveProfile := 'Development';
  FProfiles := TStringList.Create;
  FUndoStack := TVeloxUndoStack.Create(50);
  FIsDirty := False;

  // 1. Top Bar
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.BevelOuter := bvNone;
  FTopBar.Height := 44;
  FTopBar.Align := alTop;
  FTopBar.OnPaint := TopBarPaint;

  FBtnProfileDev := TVeloxStyledButton.Create(Self);
  FBtnProfileDev.Parent := FTopBar;
  FBtnProfileDev.Caption := 'Development';
  FBtnProfileDev.Variant := vsbPrimary;
  FBtnProfileDev.SetBounds(8, 8, 96, 28);
  FBtnProfileDev.OnClick := HandleDevClick;

  FBtnProfileStaging := TVeloxStyledButton.Create(Self);
  FBtnProfileStaging.Parent := FTopBar;
  FBtnProfileStaging.Caption := 'Staging';
  FBtnProfileStaging.Variant := vsbSurface;
  FBtnProfileStaging.SetBounds(108, 8, 76, 28);
  FBtnProfileStaging.OnClick := HandleStagingClick;

  FBtnProfileProd := TVeloxStyledButton.Create(Self);
  FBtnProfileProd.Parent := FTopBar;
  FBtnProfileProd.Caption := 'Production';
  FBtnProfileProd.Variant := vsbSurface;
  FBtnProfileProd.SetBounds(188, 8, 88, 28);
  FBtnProfileProd.OnClick := HandleProdClick;

  FBtnUndo := TVeloxStyledButton.Create(Self);
  FBtnUndo.Parent := FTopBar;
  FBtnUndo.Caption := 'Undo';
  FBtnUndo.Variant := vsbSurface;
  FBtnUndo.SetBounds(Width - 296, 8, 54, 28);
  FBtnUndo.OnClick := HandleUndoClick;

  FBtnRedo := TVeloxStyledButton.Create(Self);
  FBtnRedo.Parent := FTopBar;
  FBtnRedo.Caption := 'Redo';
  FBtnRedo.Variant := vsbSurface;
  FBtnRedo.SetBounds(Width - 238, 8, 54, 28);
  FBtnRedo.OnClick := HandleRedoClick;

  FBtnToggleView := TVeloxStyledButton.Create(Self);
  FBtnToggleView.Parent := FTopBar;
  FBtnToggleView.Caption := 'Diff vs Default';
  FBtnToggleView.Variant := vsbOutline;
  FBtnToggleView.SetBounds(Width - 180, 8, 100, 28);
  FBtnToggleView.OnClick := HandleToggleViewClick;

  FBtnApply := TVeloxStyledButton.Create(Self);
  FBtnApply.Parent := FTopBar;
  FBtnApply.Caption := 'Apply';
  FBtnApply.Variant := vsbPrimary;
  FBtnApply.SetBounds(Width - 76, 8, 64, 28);
  FBtnApply.OnClick := HandleApplyClick;

  // 2. Footer Bar
  FFooterBar := TPanel.Create(Self);
  FFooterBar.Parent := Self;
  FFooterBar.BevelOuter := bvNone;
  FFooterBar.Height := 24;
  FFooterBar.Align := alBottom;
  FFooterBar.OnPaint := FooterBarPaint;

  // 3. Work Container
  FWorkContainer := TPanel.Create(Self);
  FWorkContainer.Parent := Self;
  FWorkContainer.BevelOuter := bvNone;
  FWorkContainer.Align := alClient;

  FPropGrid := TVeloxPropertyGrid.Create(Self);
  FPropGrid.Parent := FWorkContainer;
  FPropGrid.Align := alClient;
  FPropGrid.OnChange := HandlePropertyChange;

  FDiffView := TVeloxDiffView.Create(Self);
  FDiffView.Parent := FWorkContainer;
  FDiffView.Align := alClient;
  FDiffView.Visible := False;

  RegisterDefaultSettings;
  ApplyColors(FColors);
end;

destructor TVeloxConfigStudio.Destroy;
begin
  FProfiles.Free;
  FUndoStack.Free;
  inherited Destroy;
end;

procedure TVeloxConfigStudio.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  FTopBar.Color := FColors.Surface;
  FFooterBar.Color := FColors.Surface;

  FPropGrid.ApplyColors(FColors);
  FDiffView.ApplyColors(FColors);

  FBtnProfileDev.ApplyColors(FColors);
  FBtnProfileStaging.ApplyColors(FColors);
  FBtnProfileProd.ApplyColors(FColors);
  FBtnUndo.ApplyColors(FColors);
  FBtnRedo.ApplyColors(FColors);
  FBtnToggleView.ApplyColors(FColors);
  FBtnApply.ApplyColors(FColors);

  Invalidate;
end;

procedure TVeloxConfigStudio.RegisterDefaultSettings;
begin
  FPropGrid.Clear;
  FPropGrid.AddCategory('Database & Cache', True);
  FPropGrid.AddString('Database & Cache', 'db.host', 'Host Address', '127.0.0.1');
  FPropGrid.AddInteger('Database & Cache', 'db.port', 'Port', 5432);
  FPropGrid.AddString('Database & Cache', 'db.name', 'Database Name', 'velox_dev');
  FPropGrid.AddBoolean('Database & Cache', 'db.pool', 'Connection Pooling', True);

  FPropGrid.AddCategory('Logging & Telemetry', True);
  FPropGrid.AddString('Logging & Telemetry', 'log.level', 'Log Verbosity', 'DEBUG');
  FPropGrid.AddBoolean('Logging & Telemetry', 'log.telemetry', 'Emit QPC Metrics', True);
  FPropGrid.AddInteger('Logging & Telemetry', 'log.retention_days', 'Retention Days', 7);

  FPropGrid.AddCategory('Security & Identity', True);
  FPropGrid.AddBoolean('Security & Identity', 'sec.enforce_tls', 'Enforce TLS 1.3', True);
  FPropGrid.AddString('Security & Identity', 'sec.api_key', 'API Secret Key', 'dev_key_sec_99182');

  FDefaultJson := ExportProfileJson('Default');
  FProfiles.Values['Development'] := FDefaultJson;
  FProfiles.Values['Staging'] := FDefaultJson;
  FProfiles.Values['Production'] := FDefaultJson;
end;

function TVeloxConfigStudio.ExportProfileJson(const AProfileName: string): string;
var
  J: TVeloxJson;
  I: Integer;
begin
  J := TVeloxJson.NewObject;
  try
    J.PutStr('profile', AProfileName);
    for I := 0 to FPropGrid.ItemCount - 1 do
    begin
      case FPropGrid.Items[I].PropType of
        vptBoolean: J.PutBool(FPropGrid.Items[I].Key, FPropGrid.Items[I].BoolValue);
        vptInteger: J.PutNum(FPropGrid.Items[I].Key, FPropGrid.Items[I].IntValue);
      else
        J.PutStr(FPropGrid.Items[I].Key, FPropGrid.Items[I].StringValue);
      end;
    end;
    Result := J.Serialize(True);
  finally
    J.Free;
  end;
end;

procedure TVeloxConfigStudio.ImportProfileJson(const AProfileName, AJsonText: string);
var
  J, Node: TVeloxJson;
  Err: string;
  I: Integer;
  K: string;
begin
  J := TVeloxJson.Parse(AJsonText, Err);
  if Assigned(J) then
  begin
    try
      for I := 0 to FPropGrid.ItemCount - 1 do
      begin
        K := FPropGrid.Items[I].Key;
        Node := J.Find(K);
        if Assigned(Node) then
        begin
          case FPropGrid.Items[I].PropType of
            vptBoolean: FPropGrid.SetBoolean(K, Node.AsBool(False));
            vptInteger: FPropGrid.SetInteger(K, Node.AsInt(0));
          else
            FPropGrid.SetString(K, Node.AsString(''));
          end;
        end;
      end;
    finally
      J.Free;
    end;
    FPropGrid.Invalidate;
  end;
end;

procedure TVeloxConfigStudio.SwitchProfile(const AProfileName: string);
begin
  if FIsDirty then
    ApplyChanges;

  FActiveProfile := AProfileName;
  FBtnProfileDev.Variant := vsbSurface;
  FBtnProfileStaging.Variant := vsbSurface;
  FBtnProfileProd.Variant := vsbSurface;

  if AProfileName = 'Development' then FBtnProfileDev.Variant := vsbPrimary
  else if AProfileName = 'Staging' then FBtnProfileStaging.Variant := vsbPrimary
  else if AProfileName = 'Production' then FBtnProfileProd.Variant := vsbPrimary;

  FBtnProfileDev.Invalidate;
  FBtnProfileStaging.Invalidate;
  FBtnProfileProd.Invalidate;

  if FProfiles.IndexOfName(AProfileName) >= 0 then
    ImportProfileJson(AProfileName, FProfiles.Values[AProfileName]);

  FUndoStack.Clear;
  FIsDirty := False;
  FFooterBar.Invalidate;
end;

procedure TVeloxConfigStudio.SetViewMode(const Value: TVeloxConfigStudioView);
var
  CurrentJson: string;
begin
  FViewMode := Value;
  if FViewMode = vcsvEditor then
  begin
    FBtnToggleView.Caption := 'Diff vs Default';
    FBtnToggleView.Variant := vsbOutline;
    FPropGrid.Visible := True;
    FDiffView.Visible := False;
  end
  else
  begin
    FBtnToggleView.Caption := 'Settings Grid';
    FBtnToggleView.Variant := vsbPrimary;
    CurrentJson := ExportProfileJson(FActiveProfile);
    FDiffView.SetDiff(FDefaultJson, CurrentJson);
    FPropGrid.Visible := False;
    FDiffView.Visible := True;
  end;
  FBtnToggleView.Invalidate;
  FFooterBar.Invalidate;
end;

procedure TVeloxConfigStudio.ApplyChanges;
begin
  FProfiles.Values[FActiveProfile] := ExportProfileJson(FActiveProfile);
  FIsDirty := False;
  FFooterBar.Invalidate;
end;

procedure TVeloxConfigStudio.DiscardChanges;
begin
  if FProfiles.IndexOfName(FActiveProfile) >= 0 then
    ImportProfileJson(FActiveProfile, FProfiles.Values[FActiveProfile]);
  FUndoStack.Clear;
  FIsDirty := False;
  FFooterBar.Invalidate;
end;

procedure TVeloxConfigStudio.HandlePropertyChange(Sender: TObject; const AKey, ANewVal: string);
var
  OldVal: string;
begin
  OldVal := FPropGrid.GetString(AKey);
  FUndoStack.Push(TConfigUndoAction.Create(Self, AKey, OldVal, ANewVal));
  FIsDirty := True;
  FFooterBar.Invalidate;
end;

procedure TVeloxConfigStudio.HandleDevClick(Sender: TObject);
begin
  SwitchProfile('Development');
end;

procedure TVeloxConfigStudio.HandleStagingClick(Sender: TObject);
begin
  SwitchProfile('Staging');
end;

procedure TVeloxConfigStudio.HandleProdClick(Sender: TObject);
begin
  SwitchProfile('Production');
end;

procedure TVeloxConfigStudio.HandleUndoClick(Sender: TObject);
begin
  if FUndoStack.CanUndo then
  begin
    FUndoStack.Undo;
    FIsDirty := True;
    FFooterBar.Invalidate;
  end;
end;

procedure TVeloxConfigStudio.HandleRedoClick(Sender: TObject);
begin
  if FUndoStack.CanRedo then
  begin
    FUndoStack.Redo;
    FIsDirty := True;
    FFooterBar.Invalidate;
  end;
end;

procedure TVeloxConfigStudio.HandleToggleViewClick(Sender: TObject);
begin
  if FViewMode = vcsvEditor then
    SetViewMode(vcsvDiff)
  else
    SetViewMode(vcsvEditor);
end;

procedure TVeloxConfigStudio.HandleApplyClick(Sender: TObject);
begin
  ApplyChanges;
end;

procedure TVeloxConfigStudio.HandleRevertClick(Sender: TObject);
begin
  DiscardChanges;
end;

procedure TVeloxConfigStudio.TopBarPaint(Sender: TObject);
var
  C: TCanvas;
begin
  C := FTopBar.Canvas;
  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, FTopBar.Height - 1);
  C.LineTo(FTopBar.Width, FTopBar.Height - 1);
end;

procedure TVeloxConfigStudio.FooterBarPaint(Sender: TObject);
var
  C: TCanvas;
  StatusTxt, DirtyTxt: string;
begin
  C := FFooterBar.Canvas;
  C.Brush.Style := bsSolid;
  C.Brush.Color := FColors.Surface;
  C.FillRect(Rect(0, 0, FFooterBar.Width, FFooterBar.Height));

  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, 0); C.LineTo(FFooterBar.Width, 0);

  if FIsDirty then
    DirtyTxt := 'Unsaved Changes (*)'
  else
    DirtyTxt := 'Saved';

  StatusTxt := Format('Profile: %s   |   Status: %s   |   Undo History: %d items',
    [FActiveProfile, DirtyTxt, FUndoStack.UndoCount]);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  C.TextOut(12, 4, StatusTxt);
end;

procedure TVeloxConfigStudio.Paint;
begin
  inherited Paint;
end;

procedure TVeloxConfigStudio.Resize;
begin
  inherited Resize;
  if Assigned(FBtnApply) and Assigned(FTopBar) then
  begin
    FBtnApply.SetBounds(FTopBar.Width - 76, 8, 64, 28);
    if Assigned(FBtnToggleView) then
      FBtnToggleView.SetBounds(FTopBar.Width - 180, 8, 100, 28);
    if Assigned(FBtnRedo) then
      FBtnRedo.SetBounds(FTopBar.Width - 238, 8, 54, 28);
    if Assigned(FBtnUndo) then
      FBtnUndo.SetBounds(FTopBar.Width - 296, 8, 54, 28);
  end;
end;

end.
