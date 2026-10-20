unit Velox.TaskDialog;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.TaskDialog
  Purpose:
    Dark/Light theme-aware Fluent replacement for VCL/LCL `MessageDlg` and
    `InputQuery` (`TVeloxTaskDialog`) with GDI+ styled action buttons,
    severity color accents, and optional "Don't ask again" checkbox.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  Controls,
  Forms,
  StdCtrls,
  ExtCtrls,
  Velox.Types,
  Velox.Theme,
  Velox.Controls,
  Velox.StyledButton;

type
  /// <summary>
  /// Structured handle to a constructed TaskDialog for headless testing or modal display
  /// </summary>
  TVeloxTaskDialogHandle = record
    Modal: TVeloxModalDialog;
    BodyLabel: TLabel;
    InputEdit: TEdit;
    CheckBox: TVeloxDarkCheckBox;
  end;

  /// <summary>
  /// Theme-aware Fluent TaskDialog (Confirm, ConfirmEx, Alert, Prompt)
  /// </summary>
  TVeloxTaskDialog = class
  public
    /// <summary>
    /// Builds a themed TaskDialog form (can be inspected headlessly in unit tests or shown modally)
    /// </summary>
    class function BuildDialog(const AOwner: TComponent;
      const ATitle, AHeadline, ABody: string;
      const AColors: TVeloxThemeColors;
      const ASeverity: TVeloxSeverity = vsWarning;
      const AConfirmText: string = 'Confirm';
      const ACancelText: string = 'Cancel';
      const AIncludeInput: Boolean = False;
      const ADefaultInput: string = '';
      const ACheckBoxText: string = ''): TVeloxTaskDialogHandle; static;

    /// <summary>
    /// Shows a themed Confirmation dialog and returns True if confirmed
    /// </summary>
    class function Confirm(const AOwner: TComponent;
      const ATitle, AHeadline, ABody: string;
      const AColors: TVeloxThemeColors;
      const ASeverity: TVeloxSeverity = vsWarning;
      const AConfirmText: string = 'Confirm';
      const ACancelText: string = 'Cancel'): Boolean; static;

    /// <summary>
    /// Shows a themed Confirmation dialog with a "Don't ask again" checkbox
    /// </summary>
    class function ConfirmEx(const AOwner: TComponent;
      const ATitle, AHeadline, ABody: string;
      const AColors: TVeloxThemeColors;
      const ASeverity: TVeloxSeverity;
      const ACheckBoxText: string;
      out AChecked: Boolean;
      const AConfirmText: string = 'Confirm';
      const ACancelText: string = 'Cancel'): Boolean; static;

    /// <summary>
    /// Shows a single-button Alert dialog
    /// </summary>
    class procedure Alert(const AOwner: TComponent;
      const ATitle, AHeadline, ABody: string;
      const AColors: TVeloxThemeColors;
      const ASeverity: TVeloxSeverity = vsNormal;
      const AButtonText: string = 'OK'); static;

    /// <summary>
    /// Shows a themed Input Prompt dialog (replacement for InputQuery)
    /// </summary>
    class function Prompt(const AOwner: TComponent;
      const ATitle, AHeadline: string;
      const AColors: TVeloxThemeColors;
      var AValue: string;
      const AConfirmText: string = 'Save';
      const ACancelText: string = 'Cancel'): Boolean; static;
  end;

implementation

{ TVeloxTaskDialog }

class function TVeloxTaskDialog.BuildDialog(const AOwner: TComponent;
  const ATitle, AHeadline, ABody: string;
  const AColors: TVeloxThemeColors;
  const ASeverity: TVeloxSeverity;
  const AConfirmText, ACancelText: string;
  const AIncludeInput: Boolean;
  const ADefaultInput, ACheckBoxText: string): TVeloxTaskDialogHandle;
var
  TotalH, CurY: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);

  TotalH := 190;
  if ABody <> '' then Inc(TotalH, 44);
  if AIncludeInput then Inc(TotalH, 40);
  if ACheckBoxText <> '' then Inc(TotalH, 32);

  Result.Modal := TVeloxControls.CreateModalDialog(
    AOwner, ATitle, AHeadline, TVeloxUtils.SeverityToString(ASeverity),
    440, TotalH, AColors, AConfirmText, ACancelText, False);

  Result.Modal.SubtitleLabel.Font.Color := TVeloxUtils.SeverityToColor(ASeverity, AColors);

  CurY := 14;
  if ABody <> '' then
  begin
    Result.BodyLabel := TLabel.Create(Result.Modal.Form);
    Result.BodyLabel.Parent := Result.Modal.BodyPanel;
    Result.BodyLabel.AutoSize := False;
    Result.BodyLabel.SetBounds(16, CurY, 404, 40);
    Result.BodyLabel.WordWrap := True;
    Result.BodyLabel.Font.Name := 'Segoe UI';
    Result.BodyLabel.Font.Size := 9;
    Result.BodyLabel.Font.Color := AColors.TextSecondary;
    Result.BodyLabel.Caption := ABody;
    Inc(CurY, 44);
  end;

  if AIncludeInput then
  begin
    Result.InputEdit := TEdit.Create(Result.Modal.Form);
    Result.InputEdit.Parent := Result.Modal.BodyPanel;
    Result.InputEdit.SetBounds(16, CurY, 404, 26);
    Result.InputEdit.Color := AColors.SurfaceCard;
    Result.InputEdit.Font.Name := 'Segoe UI';
    Result.InputEdit.Font.Size := 10;
    Result.InputEdit.Font.Color := AColors.TextPrimary;
    Result.InputEdit.Text := ADefaultInput;
    Inc(CurY, 36);
  end;

  if ACheckBoxText <> '' then
  begin
    Result.CheckBox := TVeloxDarkCheckBox.CreateCheck(
      Result.Modal.Form, Result.Modal.BodyPanel,
      16, CurY, 380, ACheckBoxText, AColors, False);
    Result.CheckBox.ApplyColors(AColors, False);
  end;
end;

class function TVeloxTaskDialog.Confirm(const AOwner: TComponent;
  const ATitle, AHeadline, ABody: string;
  const AColors: TVeloxThemeColors;
  const ASeverity: TVeloxSeverity;
  const AConfirmText, ACancelText: string): Boolean;
var
  DummyChecked: Boolean;
begin
  Result := ConfirmEx(AOwner, ATitle, AHeadline, ABody, AColors, ASeverity,
    '', DummyChecked, AConfirmText, ACancelText);
end;

class function TVeloxTaskDialog.ConfirmEx(const AOwner: TComponent;
  const ATitle, AHeadline, ABody: string;
  const AColors: TVeloxThemeColors;
  const ASeverity: TVeloxSeverity;
  const ACheckBoxText: string;
  out AChecked: Boolean;
  const AConfirmText, ACancelText: string): Boolean;
var
  H: TVeloxTaskDialogHandle;
begin
  AChecked := False;
  H := BuildDialog(AOwner, ATitle, AHeadline, ABody, AColors, ASeverity,
    AConfirmText, ACancelText, False, '', ACheckBoxText);
  try
    Result := (H.Modal.Form.ShowModal = mrYes);
    if Assigned(H.CheckBox) then
      AChecked := H.CheckBox.Checked;
  finally
    H.Modal.Form.Free;
  end;
end;

class procedure TVeloxTaskDialog.Alert(const AOwner: TComponent;
  const ATitle, AHeadline, ABody: string;
  const AColors: TVeloxThemeColors;
  const ASeverity: TVeloxSeverity;
  const AButtonText: string);
var
  H: TVeloxTaskDialogHandle;
begin
  H := BuildDialog(AOwner, ATitle, AHeadline, ABody, AColors, ASeverity,
    '', AButtonText, False, '', '');
  try
    H.Modal.Form.ShowModal;
  finally
    H.Modal.Form.Free;
  end;
end;

class function TVeloxTaskDialog.Prompt(const AOwner: TComponent;
  const ATitle, AHeadline: string;
  const AColors: TVeloxThemeColors;
  var AValue: string;
  const AConfirmText, ACancelText: string): Boolean;
var
  H: TVeloxTaskDialogHandle;
begin
  H := BuildDialog(AOwner, ATitle, AHeadline, '', AColors, vsNormal,
    AConfirmText, ACancelText, True, AValue, '');
  try
    Result := (H.Modal.Form.ShowModal = mrYes);
    if Result and Assigned(H.InputEdit) then
      AValue := H.InputEdit.Text;
  finally
    H.Modal.Form.Free;
  end;
end;

end.
