unit Velox.Mru;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Mru
  Purpose:
    Persistent Most Recently Used (MRU) history manager (`TVeloxMru`) inspired
    by JEDI VCL (`TJvMRUManager`) and Windows Shell Recent Documents.
    Supports capacity limits, deduplication, item pinning, auto-pruning of
    deleted files, JSON/INI persistence, path ellipsis truncation, and
    automatic popup menu or list synchronization with numbered accelerators.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Velox.Types,
  Velox.Json,
  Velox.ContextMenu;

type
  TVeloxMruItem = record
    Path: string;
    Pinned: Boolean;
    LastAccess: TDateTime;
  end;

  TVeloxMruClickEvent = procedure(Sender: TObject; const APath: string) of object;

  /// <summary>
  /// Most Recently Used (MRU) list and menu manager
  /// </summary>
  TVeloxMru = class(TComponent)
  private
    FItems: array of TVeloxMruItem;
    FMaxItems: Integer;
    FStorageFile: string;
    function FindIndex(const APath: string): Integer;
  public
    constructor Create(AOwner: TComponent); override;

    /// <summary>Adds or promotes a path to the top of the MRU list.</summary>
    procedure Add(const APath: string);
    procedure Remove(const AIndex: Integer); overload;
    procedure Remove(const APath: string); overload;
    procedure Clear;

    procedure Pin(const AIndex: Integer);
    procedure Unpin(const AIndex: Integer);
    function IsPinned(const AIndex: Integer): Boolean;

    /// <summary>Prunes items whose files no longer exist on disk.</summary>
    procedure RemoveNonExistent;

    function Count: Integer;
    function ItemPath(const AIndex: Integer): string;
    function ItemAt(const AIndex: Integer): TVeloxMruItem;

    /// <summary>Formats path with accelerator and compact middle ellipsis (e.g. '&1 C:\...\file.txt').</summary>
    class function FormatMenuCaption(const AIndex: Integer; const APath: string;
      const AMaxLen: Integer = 45): string; static;

    /// <summary>Populates a TVeloxPopupMenu with recent items.</summary>
    procedure PopulateMenu(const AMenu: TVeloxPopupMenu; const AOnClick: TNotifyEvent);

    function SaveToJson: string;
    function LoadFromJson(const AJson: string): Boolean;
    procedure SaveToFile(const AFilePath: string);
    procedure LoadFromFile(const AFilePath: string);

    property MaxItems: Integer read FMaxItems write FMaxItems default 10;
    property StorageFile: string read FStorageFile write FStorageFile;
  end;

implementation

constructor TVeloxMru.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMaxItems := 10;
  FStorageFile := '';
  SetLength(FItems, 0);
end;

function TVeloxMru.Count: Integer;
begin
  Result := Length(FItems);
end;

function TVeloxMru.ItemPath(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex <= High(FItems)) then
    Result := FItems[AIndex].Path
  else
    Result := '';
end;

function TVeloxMru.ItemAt(const AIndex: Integer): TVeloxMruItem;
begin
  if (AIndex >= 0) and (AIndex <= High(FItems)) then
    Result := FItems[AIndex]
  else
  begin
    FillChar(Result, SizeOf(Result), 0);
  end;
end;

function TVeloxMru.FindIndex(const APath: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FItems) do
    if SameText(FItems[I].Path, APath) then
      Exit(I);
end;

procedure TVeloxMru.Add(const APath: string);
var
  Idx, I: Integer;
  WasPinned: Boolean;
  Item: TVeloxMruItem;
begin
  if Trim(APath) = '' then Exit;
  Idx := FindIndex(APath);
  WasPinned := False;
  if Idx >= 0 then
  begin
    WasPinned := FItems[Idx].Pinned;
    // Shift elements
    for I := Idx downto 1 do
      FItems[I] := FItems[I - 1];
  end
  else
  begin
    SetLength(FItems, Length(FItems) + 1);
    for I := High(FItems) downto 1 do
      FItems[I] := FItems[I - 1];
  end;

  Item.Path := APath;
  Item.Pinned := WasPinned;
  Item.LastAccess := Now;
  FItems[0] := Item;

  // Trim unpinned items from the tail if exceeding MaxItems
  if Length(FItems) > FMaxItems then
  begin
    for I := High(FItems) downto FMaxItems do
    begin
      if not FItems[I].Pinned then
      begin
        Remove(I);
        Break;
      end;
    end;
  end;
end;

procedure TVeloxMru.Remove(const AIndex: Integer);
var
  I: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FItems)) then Exit;
  for I := AIndex to High(FItems) - 1 do
    FItems[I] := FItems[I + 1];
  SetLength(FItems, Length(FItems) - 1);
end;

procedure TVeloxMru.Remove(const APath: string);
var
  Idx: Integer;
begin
  Idx := FindIndex(APath);
  if Idx >= 0 then
    Remove(Idx);
end;

procedure TVeloxMru.Clear;
begin
  SetLength(FItems, 0);
end;

procedure TVeloxMru.Pin(const AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex <= High(FItems)) then
    FItems[AIndex].Pinned := True;
end;

procedure TVeloxMru.Unpin(const AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex <= High(FItems)) then
    FItems[AIndex].Pinned := False;
end;

function TVeloxMru.IsPinned(const AIndex: Integer): Boolean;
begin
  if (AIndex >= 0) and (AIndex <= High(FItems)) then
    Result := FItems[AIndex].Pinned
  else
    Result := False;
end;

procedure TVeloxMru.RemoveNonExistent;
var
  I: Integer;
begin
  for I := High(FItems) downto 0 do
    if not FileExists(FItems[I].Path) then
      Remove(I);
end;

class function TVeloxMru.FormatMenuCaption(const AIndex: Integer; const APath: string;
  const AMaxLen: Integer): string;
var
  Prefix, Display: string;
  Half: Integer;
begin
  if AIndex < 9 then
    Prefix := '&' + IntToStr(AIndex + 1) + ' '
  else if AIndex = 9 then
    Prefix := '1&0 '
  else
    Prefix := '   ';

  Display := APath;
  if (AMaxLen > 12) and (Length(Display) > AMaxLen) then
  begin
    Half := (AMaxLen - 5) div 2;
    Display := Copy(Display, 1, Half) + '...' + Copy(Display, Length(Display) - Half + 1, Half);
  end;
  Result := Prefix + Display;
end;

procedure TVeloxMru.PopulateMenu(const AMenu: TVeloxPopupMenu; const AOnClick: TNotifyEvent);
var
  I: Integer;
  Cap: string;
begin
  if AMenu = nil then Exit;
  for I := 0 to High(FItems) do
  begin
    Cap := FormatMenuCaption(I, FItems[I].Path);
    if FItems[I].Pinned then
      Cap := '[*] ' + Cap;
    AMenu.AddItem('mru_' + IntToStr(I), Cap, '', AOnClick, vsNormal);
  end;
end;

function TVeloxMru.SaveToJson: string;
var
  Root, Arr, Item: TVeloxJson;
  I: Integer;
begin
  Root := TVeloxJson.NewObject;
  try
    Root.PutNum('version', 1);
    Arr := TVeloxJson.NewArray;
    for I := 0 to High(FItems) do
    begin
      Item := TVeloxJson.NewObject;
      Item.PutStr('path', FItems[I].Path);
      Item.PutBool('pinned', FItems[I].Pinned);
      Item.PutStr('last_access', DateTimeToStr(FItems[I].LastAccess));
      Arr.AddChild(Item);
    end;
    Root.PutChild('items', Arr);
    Result := Root.Serialize(True);
  finally
    Root.Free;
  end;
end;

function TVeloxMru.LoadFromJson(const AJson: string): Boolean;
var
  Root, Arr, Node: TVeloxJson;
  Err: string;
  I: Integer;
begin
  Result := False;
  Root := TVeloxJson.Parse(AJson, Err);
  if Root = nil then Exit;
  try
    Arr := Root.Find('items');
    if (Arr = nil) or (Arr.Kind <> jkArray) then Exit;
    SetLength(FItems, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Node := Arr[I];
      if Node <> nil then
      begin
        if Node.Find('path') <> nil then
          FItems[I].Path := Node.Find('path').AsString;
        if Node.Find('pinned') <> nil then
          FItems[I].Pinned := Node.Find('pinned').AsBool;
        if Node.Find('last_access') <> nil then
          FItems[I].LastAccess := StrToDateTimeDef(Node.Find('last_access').AsString, Now);
      end;
    end;
    Result := True;
  finally
    Root.Free;
  end;
end;

procedure TVeloxMru.SaveToFile(const AFilePath: string);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := SaveToJson;
    L.SaveToFile(AFilePath);
  finally
    L.Free;
  end;
end;

procedure TVeloxMru.LoadFromFile(const AFilePath: string);
var
  L: TStringList;
begin
  if not FileExists(AFilePath) then Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(AFilePath);
    LoadFromJson(L.Text);
  finally
    L.Free;
  end;
end;

end.
