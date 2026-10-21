unit Velox.Undo;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  SysUtils, Classes;

type
  IVeloxCommand = interface
    ['{B0795CE0-5BD3-40A1-8079-5CE05BD340A1}']
    procedure Execute;
    procedure Unexecute;
    function GetDescription: string;
    property Description: string read GetDescription;
  end;

  TVeloxCommandProc = procedure of object;

  TVeloxActionCommand = class(TInterfacedObject, IVeloxCommand)
  private
    FDescription: string;
    FDoAction: TVeloxCommandProc;
    FUndoAction: TVeloxCommandProc;
  public
    constructor Create(const ADescription: string; const ADo, AUndo: TVeloxCommandProc);
    procedure Execute;
    procedure Unexecute;
    function GetDescription: string;
  end;

  TVeloxGroupCommand = class(TInterfacedObject, IVeloxCommand)
  private
    FDescription: string;
    FCommands: array of IVeloxCommand;
  public
    constructor Create(const ADescription: string = '');
    procedure Add(const ACmd: IVeloxCommand);
    procedure Execute;
    procedure Unexecute;
    function GetDescription: string;
    function Count: Integer;
  end;

  TVeloxUndoStack = class
  private
    FUndoList: array of IVeloxCommand;
    FRedoList: array of IVeloxCommand;
    FMaxCapacity: Integer;
    FActiveGroup: TVeloxGroupCommand;
    FCleanIndex: Integer;
    FOnStateChange: TNotifyEvent;
    procedure NotifyChanged;
    function GetCanUndo: Boolean;
    function GetCanRedo: Boolean;
    function GetUndoDescription: string;
    function GetRedoDescription: string;
    function GetIsDirty: Boolean;
  public
    constructor Create(const AMaxCapacity: Integer = 50);
    destructor Destroy; override;

    procedure Push(const ACmd: IVeloxCommand);
    function Undo: Boolean;
    function Redo: Boolean;

    procedure BeginGroup(const ADescription: string = '');
    procedure EndGroup;

    procedure Clear;
    procedure MarkClean;

    property CanUndo: Boolean read GetCanUndo;
    property CanRedo: Boolean read GetCanRedo;
    property UndoDescription: string read GetUndoDescription;
    property RedoDescription: string read GetRedoDescription;
    property IsDirty: Boolean read GetIsDirty;
    property MaxCapacity: Integer read FMaxCapacity write FMaxCapacity default 50;
    property OnStateChange: TNotifyEvent read FOnStateChange write FOnStateChange;
  end;

implementation

{ TVeloxActionCommand }

constructor TVeloxActionCommand.Create(const ADescription: string; const ADo, AUndo: TVeloxCommandProc);
begin
  inherited Create;
  FDescription := ADescription;
  FDoAction := ADo;
  FUndoAction := AUndo;
end;

procedure TVeloxActionCommand.Execute;
begin
  if Assigned(FDoAction) then
    FDoAction();
end;

procedure TVeloxActionCommand.Unexecute;
begin
  if Assigned(FUndoAction) then
    FUndoAction();
end;

function TVeloxActionCommand.GetDescription: string;
begin
  Result := FDescription;
end;

{ TVeloxGroupCommand }

constructor TVeloxGroupCommand.Create(const ADescription: string);
begin
  inherited Create;
  FDescription := ADescription;
  SetLength(FCommands, 0);
end;

procedure TVeloxGroupCommand.Add(const ACmd: IVeloxCommand);
var
  L: Integer;
begin
  L := Length(FCommands);
  SetLength(FCommands, L + 1);
  FCommands[L] := ACmd;
end;

procedure TVeloxGroupCommand.Execute;
var
  I: Integer;
begin
  for I := 0 to High(FCommands) do
    FCommands[I].Execute;
end;

procedure TVeloxGroupCommand.Unexecute;
var
  I: Integer;
begin
  for I := High(FCommands) downto 0 do
    FCommands[I].Unexecute;
end;

function TVeloxGroupCommand.GetDescription: string;
begin
  Result := FDescription;
end;

function TVeloxGroupCommand.Count: Integer;
begin
  Result := Length(FCommands);
end;

{ TVeloxUndoStack }

constructor TVeloxUndoStack.Create(const AMaxCapacity: Integer);
begin
  inherited Create;
  FMaxCapacity := AMaxCapacity;
  SetLength(FUndoList, 0);
  SetLength(FRedoList, 0);
  FActiveGroup := nil;
  FCleanIndex := 0;
end;

destructor TVeloxUndoStack.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TVeloxUndoStack.NotifyChanged;
begin
  if Assigned(FOnStateChange) then
    FOnStateChange(Self);
end;

procedure TVeloxUndoStack.Clear;
begin
  SetLength(FUndoList, 0);
  SetLength(FRedoList, 0);
  FActiveGroup := nil;
  FCleanIndex := 0;
  NotifyChanged;
end;

procedure TVeloxUndoStack.MarkClean;
begin
  FCleanIndex := Length(FUndoList);
  NotifyChanged;
end;

function TVeloxUndoStack.GetIsDirty: Boolean;
begin
  Result := Length(FUndoList) <> FCleanIndex;
end;

function TVeloxUndoStack.GetCanUndo: Boolean;
begin
  Result := Length(FUndoList) > 0;
end;

function TVeloxUndoStack.GetCanRedo: Boolean;
begin
  Result := Length(FRedoList) > 0;
end;

function TVeloxUndoStack.GetUndoDescription: string;
begin
  if CanUndo then
    Result := FUndoList[High(FUndoList)].Description
  else
    Result := '';
end;

function TVeloxUndoStack.GetRedoDescription: string;
begin
  if CanRedo then
    Result := FRedoList[High(FRedoList)].Description
  else
    Result := '';
end;

procedure TVeloxUndoStack.BeginGroup(const ADescription: string);
begin
  if FActiveGroup = nil then
    FActiveGroup := TVeloxGroupCommand.Create(ADescription);
end;

procedure TVeloxUndoStack.EndGroup;
var
  Grp: TVeloxGroupCommand;
begin
  if FActiveGroup <> nil then
  begin
    Grp := FActiveGroup;
    FActiveGroup := nil;
    if Grp.Count > 0 then
      Push(Grp);
  end;
end;

procedure TVeloxUndoStack.Push(const ACmd: IVeloxCommand);
var
  L, I: Integer;
begin
  if FActiveGroup <> nil then
  begin
    FActiveGroup.Add(ACmd);
    Exit;
  end;

  // Clear redo on new push
  SetLength(FRedoList, 0);

  L := Length(FUndoList);
  if L >= FMaxCapacity then
  begin
    // Shift elements left to make room
    for I := 0 to L - 2 do
      FUndoList[I] := FUndoList[I + 1];
    FUndoList[L - 1] := ACmd;
    if FCleanIndex > 0 then
      Dec(FCleanIndex);
  end
  else
  begin
    SetLength(FUndoList, L + 1);
    FUndoList[L] := ACmd;
  end;

  NotifyChanged;
end;

function TVeloxUndoStack.Undo: Boolean;
var
  Cmd: IVeloxCommand;
  L: Integer;
begin
  if not CanUndo then Exit(False);

  L := Length(FUndoList);
  Cmd := FUndoList[L - 1];
  SetLength(FUndoList, L - 1);

  Cmd.Unexecute;

  // Move to redo stack
  L := Length(FRedoList);
  SetLength(FRedoList, L + 1);
  FRedoList[L] := Cmd;

  NotifyChanged;
  Result := True;
end;

function TVeloxUndoStack.Redo: Boolean;
var
  Cmd: IVeloxCommand;
  L: Integer;
begin
  if not CanRedo then Exit(False);

  L := Length(FRedoList);
  Cmd := FRedoList[L - 1];
  SetLength(FRedoList, L - 1);

  Cmd.Execute;

  // Move back to undo stack
  L := Length(FUndoList);
  SetLength(FUndoList, L + 1);
  FUndoList[L] := Cmd;

  NotifyChanged;
  Result := True;
end;

end.
