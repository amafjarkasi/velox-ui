unit Velox.ViewModel;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.ViewModel
  Purpose:
    Makes the "MVVM" in VeloxUI concrete (inspired by Grijjy MVVM and Spring4D
    data binding):
    1. `TVeloxViewModel`: property-changed notification base class with
       dirty tracking and `BeginUpdate` / `EndUpdate` batching (duplicate
       property names are coalesced).
    2. `TVeloxBinder`: two-way binding between `TVeloxObservable<T>` and
       `TEdit`, `TCheckBox`, `TVeloxToggleSwitch`, `TVeloxSlider`, plus
       one-way `Visible` / `Enabled` bindings. Feedback loops are guarded.
    Lifetime rule: create the binder with the form and keep the observables
    alive at least as long as the binder.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Controls,
  StdCtrls,
  Velox.Reactive,
  Velox.ToggleSwitch;

type
  TVeloxPropertyChangedEvent = procedure(const APropName: string) of object;

  /// <summary>
  /// Property-changed notification base class for ViewModels
  /// </summary>
  TVeloxViewModel = class
  private
    FHandlers: array of TVeloxPropertyChangedEvent;
    FDirty: Boolean;
    FUpdateDepth: Integer;
    FPending: TStringList;
    procedure NotifyHandlers(const AProp: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Subscribe(const AHandler: TVeloxPropertyChangedEvent);
    procedure Unsubscribe(const AHandler: TVeloxPropertyChangedEvent);
    procedure RaisePropertyChanged(const AProp: string);
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure ClearDirty;

    property IsDirty: Boolean read FDirty;
  end;

  /// <summary>
  /// Two-way control <-> observable binder
  /// </summary>
  TVeloxBinder = class(TComponent)
  private
    FBindings: TList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure BindEdit(const AEdit: TEdit; const AObs: TVeloxObservable<string>);
    procedure BindCheckBox(const ACheck: TCheckBox; const AObs: TVeloxObservable<Boolean>);
    procedure BindToggle(const ASwitch: TVeloxToggleSwitch; const AObs: TVeloxObservable<Boolean>);
    procedure BindSlider(const ASlider: TVeloxSlider; const AObs: TVeloxObservable<Integer>);
    procedure BindVisible(const AControl: TControl; const AObs: TVeloxObservable<Boolean>);
    procedure BindEnabled(const AControl: TControl; const AObs: TVeloxObservable<Boolean>);

    function BindingCount: Integer;
  end;

implementation

type
  TEditBinding = class
  public
    Edit: TEdit;
    Obs: TVeloxObservable<string>;
    Busy: Boolean;
    procedure OnObs(const AValue: string);
    procedure OnEdit(Sender: TObject);
  end;

  TCheckBinding = class
  public
    Check: TCheckBox;
    Obs: TVeloxObservable<Boolean>;
    Busy: Boolean;
    procedure OnObs(const AValue: Boolean);
    procedure OnClick(Sender: TObject);
  end;

  TToggleBinding = class
  public
    Switch: TVeloxToggleSwitch;
    Obs: TVeloxObservable<Boolean>;
    Busy: Boolean;
    procedure OnObs(const AValue: Boolean);
    procedure OnToggle(Sender: TObject);
  end;

  TSliderBinding = class
  public
    Slider: TVeloxSlider;
    Obs: TVeloxObservable<Integer>;
    Busy: Boolean;
    procedure OnObs(const AValue: Integer);
    procedure OnSlide(Sender: TObject);
  end;

  TFlagBinding = class
  public
    Ctl: TControl;
    IsVisibleMode: Boolean;
    procedure OnObs(const AValue: Boolean);
  end;

function SameHandler(const A, B: TVeloxPropertyChangedEvent): Boolean;
begin
  Result := (TMethod(A).Code = TMethod(B).Code) and (TMethod(A).Data = TMethod(B).Data);
end;

{ TEditBinding }

procedure TEditBinding.OnObs(const AValue: string);
begin
  if Busy then Exit;
  Busy := True;
  try
    if Edit.Text <> AValue then
      Edit.Text := AValue;
  finally
    Busy := False;
  end;
end;

procedure TEditBinding.OnEdit(Sender: TObject);
begin
  if Busy then Exit;
  Busy := True;
  try
    Obs.Value := Edit.Text;
  finally
    Busy := False;
  end;
end;

{ TCheckBinding }

procedure TCheckBinding.OnObs(const AValue: Boolean);
begin
  if Busy then Exit;
  Busy := True;
  try
    if Check.Checked <> AValue then
      Check.Checked := AValue;
  finally
    Busy := False;
  end;
end;

procedure TCheckBinding.OnClick(Sender: TObject);
begin
  if Busy then Exit;
  Busy := True;
  try
    Obs.Value := Check.Checked;
  finally
    Busy := False;
  end;
end;

{ TToggleBinding }

procedure TToggleBinding.OnObs(const AValue: Boolean);
begin
  if Busy then Exit;
  Busy := True;
  try
    if Switch.Checked <> AValue then
      Switch.Checked := AValue;
  finally
    Busy := False;
  end;
end;

procedure TToggleBinding.OnToggle(Sender: TObject);
begin
  if Busy then Exit;
  Busy := True;
  try
    Obs.Value := Switch.Checked;
  finally
    Busy := False;
  end;
end;

{ TSliderBinding }

procedure TSliderBinding.OnObs(const AValue: Integer);
begin
  if Busy then Exit;
  Busy := True;
  try
    if Slider.Position <> AValue then
      Slider.Position := AValue;
  finally
    Busy := False;
  end;
end;

procedure TSliderBinding.OnSlide(Sender: TObject);
begin
  if Busy then Exit;
  Busy := True;
  try
    Obs.Value := Slider.Position;
  finally
    Busy := False;
  end;
end;

{ TFlagBinding }

procedure TFlagBinding.OnObs(const AValue: Boolean);
begin
  if IsVisibleMode then
    Ctl.Visible := AValue
  else
    Ctl.Enabled := AValue;
end;

{ TVeloxViewModel }

constructor TVeloxViewModel.Create;
begin
  inherited Create;
  SetLength(FHandlers, 0);
  FPending := TStringList.Create;
  FPending.CaseSensitive := True;
  FPending.Duplicates := dupIgnore;
  FDirty := False;
  FUpdateDepth := 0;
end;

destructor TVeloxViewModel.Destroy;
begin
  FPending.Free;
  inherited Destroy;
end;

procedure TVeloxViewModel.Subscribe(const AHandler: TVeloxPropertyChangedEvent);
var
  Idx: Integer;
begin
  if not Assigned(AHandler) then Exit;
  Idx := Length(FHandlers);
  SetLength(FHandlers, Idx + 1);
  FHandlers[Idx] := AHandler;
end;

procedure TVeloxViewModel.Unsubscribe(const AHandler: TVeloxPropertyChangedEvent);
var
  I, J: Integer;
begin
  for I := 0 to High(FHandlers) do
    if SameHandler(FHandlers[I], AHandler) then
    begin
      for J := I to High(FHandlers) - 1 do
        FHandlers[J] := FHandlers[J + 1];
      SetLength(FHandlers, Length(FHandlers) - 1);
      Exit;
    end;
end;

procedure TVeloxViewModel.NotifyHandlers(const AProp: string);
var
  I: Integer;
begin
  for I := 0 to High(FHandlers) do
    if Assigned(FHandlers[I]) then
      FHandlers[I](AProp);
end;

procedure TVeloxViewModel.RaisePropertyChanged(const AProp: string);
begin
  FDirty := True;
  if FUpdateDepth > 0 then
  begin
    if FPending.IndexOf(AProp) < 0 then
      FPending.Add(AProp);
  end
  else
    NotifyHandlers(AProp);
end;

procedure TVeloxViewModel.BeginUpdate;
begin
  Inc(FUpdateDepth);
end;

procedure TVeloxViewModel.EndUpdate;
var
  Names: TStringList;
  I: Integer;
begin
  if FUpdateDepth = 0 then Exit;
  Dec(FUpdateDepth);
  if FUpdateDepth > 0 then Exit;
  Names := TStringList.Create;
  try
    Names.Assign(FPending);
    FPending.Clear;
    for I := 0 to Names.Count - 1 do
      NotifyHandlers(Names[I]);
  finally
    Names.Free;
  end;
end;

procedure TVeloxViewModel.ClearDirty;
begin
  FDirty := False;
end;

{ TVeloxBinder }

constructor TVeloxBinder.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBindings := TList.Create;
end;

destructor TVeloxBinder.Destroy;
var
  I: Integer;
begin
  for I := 0 to FBindings.Count - 1 do
    TObject(FBindings[I]).Free;
  FBindings.Free;
  inherited Destroy;
end;

function TVeloxBinder.BindingCount: Integer;
begin
  Result := FBindings.Count;
end;

procedure TVeloxBinder.BindEdit(const AEdit: TEdit; const AObs: TVeloxObservable<string>);
var
  B: TEditBinding;
begin
  B := TEditBinding.Create;
  B.Edit := AEdit;
  B.Obs := AObs;
  FBindings.Add(B);
  AEdit.OnChange := B.OnEdit;
  AObs.Subscribe(B.OnObs, True);
end;

procedure TVeloxBinder.BindCheckBox(const ACheck: TCheckBox; const AObs: TVeloxObservable<Boolean>);
var
  B: TCheckBinding;
begin
  B := TCheckBinding.Create;
  B.Check := ACheck;
  B.Obs := AObs;
  FBindings.Add(B);
  ACheck.OnClick := B.OnClick;
  AObs.Subscribe(B.OnObs, True);
end;

procedure TVeloxBinder.BindToggle(const ASwitch: TVeloxToggleSwitch; const AObs: TVeloxObservable<Boolean>);
var
  B: TToggleBinding;
begin
  B := TToggleBinding.Create;
  B.Switch := ASwitch;
  B.Obs := AObs;
  FBindings.Add(B);
  ASwitch.OnToggle := B.OnToggle;
  AObs.Subscribe(B.OnObs, True);
end;

procedure TVeloxBinder.BindSlider(const ASlider: TVeloxSlider; const AObs: TVeloxObservable<Integer>);
var
  B: TSliderBinding;
begin
  B := TSliderBinding.Create;
  B.Slider := ASlider;
  B.Obs := AObs;
  FBindings.Add(B);
  ASlider.OnChange := B.OnSlide;
  AObs.Subscribe(B.OnObs, True);
end;

procedure TVeloxBinder.BindVisible(const AControl: TControl; const AObs: TVeloxObservable<Boolean>);
var
  B: TFlagBinding;
begin
  B := TFlagBinding.Create;
  B.Ctl := AControl;
  B.IsVisibleMode := True;
  FBindings.Add(B);
  AObs.Subscribe(B.OnObs, True);
end;

procedure TVeloxBinder.BindEnabled(const AControl: TControl; const AObs: TVeloxObservable<Boolean>);
var
  B: TFlagBinding;
begin
  B := TFlagBinding.Create;
  B.Ctl := AControl;
  B.IsVisibleMode := False;
  FBindings.Add(B);
  AObs.Subscribe(B.OnObs, True);
end;

end.
