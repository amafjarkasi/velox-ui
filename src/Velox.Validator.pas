unit Velox.Validator;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Validator
  Purpose:
    Declarative Input Validation & Error Reporting Engine (`TVeloxValidator`)
    inspired by `danieleteti/delphimvcframework` and `Grijjy` MVVM.
    Validates `TEdit` controls against `Required`, `IntRange`, `FloatRange`,
    and `Custom` predicates, collecting structured error messages.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  StdCtrls;

type
  TVeloxRuleKind = (vrkRequired, vrkIntRange, vrkFloatRange, vrkCustom);

  TVeloxCustomValidateFunc = function(const AText: string; out AErrorMessage: string): Boolean of object;

  TVeloxValidationRule = record
    EditControl: TCustomEdit;
    FieldName: string;
    Kind: TVeloxRuleKind;
    MinInt: Integer;
    MaxInt: Integer;
    MinFloat: Double;
    MaxFloat: Double;
    CustomFunc: TVeloxCustomValidateFunc;
  end;

  /// <summary>
  /// Declarative form input validator
  /// </summary>
  TVeloxValidator = class(TComponent)
  private
    FRules: array of TVeloxValidationRule;
    function GetRuleCount: Integer;
  public
    constructor Create(AOwner: TComponent); override;

    procedure AddRequired(const AEdit: TCustomEdit; const AFieldName: string);
    procedure AddIntRange(const AEdit: TCustomEdit; const AFieldName: string;
      const AMin, AMax: Integer);
    procedure AddFloatRange(const AEdit: TCustomEdit; const AFieldName: string;
      const AMin, AMax: Double);
    procedure AddCustom(const AEdit: TCustomEdit; const AFieldName: string;
      const ACustomFunc: TVeloxCustomValidateFunc);
    procedure Clear;

    /// <summary>
    /// Evaluates all registered rules. Returns True if all pass; otherwise
    /// returns False and populates AFirstError and AAllErrors.
    /// </summary>
    function ValidateAll(out AFirstError: string): Boolean;

    property RuleCount: Integer read GetRuleCount;
  end;

implementation

{ TVeloxValidator }

constructor TVeloxValidator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetLength(FRules, 0);
end;

function TVeloxValidator.GetRuleCount: Integer;
begin
  Result := Length(FRules);
end;

procedure TVeloxValidator.Clear;
begin
  SetLength(FRules, 0);
end;

procedure TVeloxValidator.AddRequired(const AEdit: TCustomEdit;
  const AFieldName: string);
var
  Idx: Integer;
begin
  Idx := Length(FRules);
  SetLength(FRules, Idx + 1);
  FRules[Idx].EditControl := AEdit;
  FRules[Idx].FieldName   := AFieldName;
  FRules[Idx].Kind        := vrkRequired;
end;

procedure TVeloxValidator.AddIntRange(const AEdit: TCustomEdit;
  const AFieldName: string; const AMin, AMax: Integer);
var
  Idx: Integer;
begin
  Idx := Length(FRules);
  SetLength(FRules, Idx + 1);
  FRules[Idx].EditControl := AEdit;
  FRules[Idx].FieldName   := AFieldName;
  FRules[Idx].Kind        := vrkIntRange;
  FRules[Idx].MinInt      := AMin;
  FRules[Idx].MaxInt      := AMax;
end;

procedure TVeloxValidator.AddFloatRange(const AEdit: TCustomEdit;
  const AFieldName: string; const AMin, AMax: Double);
var
  Idx: Integer;
begin
  Idx := Length(FRules);
  SetLength(FRules, Idx + 1);
  FRules[Idx].EditControl := AEdit;
  FRules[Idx].FieldName   := AFieldName;
  FRules[Idx].Kind        := vrkFloatRange;
  FRules[Idx].MinFloat    := AMin;
  FRules[Idx].MaxFloat    := AMax;
end;

procedure TVeloxValidator.AddCustom(const AEdit: TCustomEdit;
  const AFieldName: string; const ACustomFunc: TVeloxCustomValidateFunc);
var
  Idx: Integer;
begin
  Idx := Length(FRules);
  SetLength(FRules, Idx + 1);
  FRules[Idx].EditControl := AEdit;
  FRules[Idx].FieldName   := AFieldName;
  FRules[Idx].Kind        := vrkCustom;
  FRules[Idx].CustomFunc  := ACustomFunc;
end;

function TVeloxValidator.ValidateAll(out AFirstError: string): Boolean;
var
  I, IntVal: Integer;
  FloatVal: Double;
  Txt, CustomErr: string;
  R: TVeloxValidationRule;
begin
  Result := True;
  AFirstError := '';

  for I := 0 to High(FRules) do
  begin
    R := FRules[I];
    if R.EditControl = nil then Continue;
    Txt := Trim(R.EditControl.Text);

    case R.Kind of
      vrkRequired:
        begin
          if Txt = '' then
          begin
            AFirstError := Format('%s is required.', [R.FieldName]);
            Exit(False);
          end;
        end;
      vrkIntRange:
        begin
          if (not TryStrToInt(Txt, IntVal)) or (IntVal < R.MinInt) or (IntVal > R.MaxInt) then
          begin
            AFirstError := Format('%s must be an integer between %d and %d.',
              [R.FieldName, R.MinInt, R.MaxInt]);
            Exit(False);
          end;
        end;
      vrkFloatRange:
        begin
          if (not TryStrToFloat(Txt, FloatVal)) or (FloatVal < R.MinFloat) or (FloatVal > R.MaxFloat) then
          begin
            AFirstError := Format('%s must be between %.2f and %.2f.',
              [R.FieldName, R.MinFloat, R.MaxFloat]);
            Exit(False);
          end;
        end;
      vrkCustom:
        begin
          if Assigned(R.CustomFunc) and (not R.CustomFunc(Txt, CustomErr)) then
          begin
            if CustomErr <> '' then
              AFirstError := CustomErr
            else
              AFirstError := Format('%s is invalid.', [R.FieldName]);
            Exit(False);
          end;
        end;
    end;
  end;
end;

end.
