unit Velox.Hotkeys;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Hotkeys
  Purpose:
    Declarative Keyboard Shortcut & Action Registry (`TVeloxHotkeyRegistry`)
    that replaces sprawling `FormKeyDown` `if/else` chains with 1-line shortcut
    bindings and auto-generates a formatted "Keyboard Shortcuts Cheat Sheet"
    modal on demand (e.g. `F1` or `Ctrl+?`).
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Controls,
  Forms,
  Velox.Types,
  Velox.Controls;

type
  TVeloxHotkeyBinding = record
    Key: Word;
    Shift: TShiftState;
    ShortcutText: string;
    Description: string;
    Category: string;
    OnExecute: TNotifyEvent;
  end;

  /// <summary>
  /// Declarative keyboard shortcut dispatcher and cheat-sheet generator
  /// </summary>
  TVeloxHotkeyRegistry = class
  private
    FBindings: array of TVeloxHotkeyBinding;
    function GetCount: Integer;
    function GetBinding(Index: Integer): TVeloxHotkeyBinding;
  public
    constructor Create;

    /// <summary>
    /// Registers a keyboard shortcut binding.
    /// Example: Registry.Bind(Ord('F'), [ssCtrl], 'Ctrl+F', 'Focus search bar', 'Navigation', OnFocusSearch);
    /// </summary>
    procedure Bind(const AKey: Word; const AShift: TShiftState;
      const AShortcutText, ADescription: string;
      const AOnExecute: TNotifyEvent; const ACategory: string = 'General');

    procedure Clear;

    /// <summary>
    /// Call inside FormKeyDown: checks registered bindings, executes the
    /// matching callback, sets Key := 0, and returns True if handled.
    /// </summary>
    function HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState): Boolean;

    /// <summary>
    /// Auto-generates a formatted plain-text cheat sheet of all registered shortcuts.
    /// </summary>
    function GenerateCheatSheet(const AAppTitle: string = 'VeloxUI Application'): string;

    /// <summary>
    /// Opens a themed modal dialog displaying all registered keyboard shortcuts.
    /// </summary>
    procedure ShowCheatSheetModal(const AOwner: TComponent;
      const AAppTitle: string; const AColors: TVeloxThemeColors);

    property Count: Integer read GetCount;
    property Bindings[Index: Integer]: TVeloxHotkeyBinding read GetBinding; default;
  end;

implementation

{ TVeloxHotkeyRegistry }

constructor TVeloxHotkeyRegistry.Create;
begin
  inherited Create;
  SetLength(FBindings, 0);
end;

function TVeloxHotkeyRegistry.GetCount: Integer;
begin
  Result := Length(FBindings);
end;

function TVeloxHotkeyRegistry.GetBinding(Index: Integer): TVeloxHotkeyBinding;
begin
  Result := FBindings[Index];
end;

procedure TVeloxHotkeyRegistry.Clear;
begin
  SetLength(FBindings, 0);
end;

procedure TVeloxHotkeyRegistry.Bind(const AKey: Word; const AShift: TShiftState;
  const AShortcutText, ADescription: string;
  const AOnExecute: TNotifyEvent; const ACategory: string);
var
  I, Idx: Integer;
  CoreShift: TShiftState;
begin
  CoreShift := AShift * [ssShift, ssAlt, ssCtrl];

  // Update in place if same Key + Shift already exists
  for I := 0 to High(FBindings) do
  begin
    if (FBindings[I].Key = AKey) and (FBindings[I].Shift = CoreShift) then
    begin
      FBindings[I].ShortcutText := AShortcutText;
      FBindings[I].Description  := ADescription;
      FBindings[I].Category     := ACategory;
      FBindings[I].OnExecute    := AOnExecute;
      Exit;
    end;
  end;

  Idx := Length(FBindings);
  SetLength(FBindings, Idx + 1);
  FBindings[Idx].Key          := AKey;
  FBindings[Idx].Shift        := CoreShift;
  FBindings[Idx].ShortcutText := AShortcutText;
  FBindings[Idx].Description  := ADescription;
  FBindings[Idx].Category     := ACategory;
  FBindings[Idx].OnExecute    := AOnExecute;
end;

function TVeloxHotkeyRegistry.HandleKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState): Boolean;
var
  I: Integer;
  CoreShift: TShiftState;
begin
  Result := False;
  if Key = 0 then Exit;
  CoreShift := Shift * [ssShift, ssAlt, ssCtrl];

  for I := 0 to High(FBindings) do
  begin
    if (FBindings[I].Key = Key) and (FBindings[I].Shift = CoreShift) then
    begin
      if Assigned(FBindings[I].OnExecute) then
        FBindings[I].OnExecute(Sender);
      Key := 0;
      Exit(True);
    end;
  end;
end;

function TVeloxHotkeyRegistry.GenerateCheatSheet(const AAppTitle: string): string;
var
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('====================================================================');
    Lines.Add(Format('  KEYBOARD SHORTCUTS REFERENCE — %s', [UpperCase(AAppTitle)]));
    Lines.Add('====================================================================');
    for I := 0 to High(FBindings) do
    begin
      Lines.Add(Format('  %-18s  [%s]  %s',
        [FBindings[I].ShortcutText, FBindings[I].Category, FBindings[I].Description]));
    end;
    if Length(FBindings) = 0 then
      Lines.Add('  No keyboard shortcuts registered.');
    Lines.Add('====================================================================');
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure TVeloxHotkeyRegistry.ShowCheatSheetModal(const AOwner: TComponent;
  const AAppTitle: string; const AColors: TVeloxThemeColors);
var
  Dlg: TVeloxModalDialog;
begin
  Dlg := TVeloxControls.CreateModalDialog(AOwner,
    AAppTitle + ' — Keyboard Shortcuts',
    'Keyboard Shortcuts Cheat Sheet',
    Format('%d active keybindings registered', [Length(FBindings)]),
    620, 420, AColors, '', 'Close', True);
  try
    Dlg.Memo.Lines.Text := GenerateCheatSheet(AAppTitle);
    Dlg.Form.ShowModal;
  finally
    Dlg.Form.Free;
  end;
end;

end.
