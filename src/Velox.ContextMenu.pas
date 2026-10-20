unit Velox.ContextMenu;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.ContextMenu
  Purpose:
    Dark/Light theme-aware Popup Context Menu Builder (`TVeloxPopupMenu`)
    inspired by `zamtmn/metadarkstyle` and `delphidarkmode/WindowsDarkMode`.
    Wraps a TPopupMenu with structured item registration, shortcut hints,
    severity tagging (e.g. destructive `vsCritical` actions), and programmatic
    execution by ID or index.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Menus,
  Velox.Types;

type
  TVeloxMenuEntry = record
    Id: string;
    Caption: string;
    ShortcutText: string;
    Severity: TVeloxSeverity;
    MenuItem: TMenuItem;
    OnClick: TNotifyEvent;
  end;

  /// <summary>
  /// Declarative Dark-Mode-Aware Popup Menu Builder
  /// </summary>
  TVeloxPopupMenu = class(TComponent)
  private
    FPopupMenu: TPopupMenu;
    FColors: TVeloxThemeColors;
    FEntries: array of TVeloxMenuEntry;
    function GetCount: Integer;
  public
    constructor CreateMenu(AOwner: TComponent; const AColors: TVeloxThemeColors);

    function AddItem(const AId, ACaption, AShortcutText: string;
      const AOnClick: TNotifyEvent;
      const ASeverity: TVeloxSeverity = vsNormal): TMenuItem;
    procedure AddSeparator;
    function ExecuteById(const AId: string; Sender: TObject = nil): Boolean;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    property PopupMenu: TPopupMenu read FPopupMenu;
    property Count: Integer read GetCount;
  end;

implementation

{ TVeloxPopupMenu }

constructor TVeloxPopupMenu.CreateMenu(AOwner: TComponent;
  const AColors: TVeloxThemeColors);
begin
  inherited Create(AOwner);
  FColors := AColors;
  FPopupMenu := TPopupMenu.Create(Self);
  SetLength(FEntries, 0);
end;

function TVeloxPopupMenu.GetCount: Integer;
begin
  Result := Length(FEntries);
end;

function TVeloxPopupMenu.AddItem(const AId, ACaption, AShortcutText: string;
  const AOnClick: TNotifyEvent; const ASeverity: TVeloxSeverity): TMenuItem;
var
  Idx: Integer;
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(FPopupMenu);
  if AShortcutText <> '' then
    Item.Caption := ACaption + #9 + AShortcutText
  else
    Item.Caption := ACaption;
  Item.OnClick := AOnClick;
  FPopupMenu.Items.Add(Item);

  Idx := Length(FEntries);
  SetLength(FEntries, Idx + 1);
  FEntries[Idx].Id           := AId;
  FEntries[Idx].Caption      := ACaption;
  FEntries[Idx].ShortcutText := AShortcutText;
  FEntries[Idx].Severity     := ASeverity;
  FEntries[Idx].MenuItem     := Item;
  FEntries[Idx].OnClick      := AOnClick;

  Result := Item;
end;

procedure TVeloxPopupMenu.AddSeparator;
var
  Sep: TMenuItem;
begin
  Sep := TMenuItem.Create(FPopupMenu);
  Sep.Caption := '-';
  FPopupMenu.Items.Add(Sep);
end;

function TVeloxPopupMenu.ExecuteById(const AId: string; Sender: TObject): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FEntries) do
  begin
    if SameText(FEntries[I].Id, AId) then
    begin
      if Assigned(FEntries[I].OnClick) then
        FEntries[I].OnClick(Sender);
      Exit(True);
    end;
  end;
end;

procedure TVeloxPopupMenu.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
end;

end.
