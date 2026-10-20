unit Velox.Localization;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Localization
  Purpose:
    Zero-dependency runtime localization (`TVeloxLocalizer`) inspired by
    `dxgettext` / LCL `.po` workflows but without any external tooling.
    Key/value string tables per language (from `TStrings` or flat JSON),
    fallback language, `Tr` / `TrF` (format args), and `Bind(control, key)`
    so `SetLanguage` re-captions every bound control instantly.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Controls,
  Velox.Json;

type
  /// <summary>
  /// Runtime language switcher with fallback and control binding
  /// </summary>
  TVeloxLocalizer = class(TComponent)
  private
    type
      TBinding = record
        Ctl: TControl;
        Key: string;
      end;
  private
    FLangs: TStringList;
    FBindings: array of TBinding;
    FCurrent: string;
    FFallback: string;
    function FindLang(const ALang: string): TStringList;
    function GetOrAddLang(const ALang: string): TStringList;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddEntry(const ALang, AKey, AValue: string);
    procedure AddLanguage(const ALang: string; const AStrings: TStrings);
    function AddLanguageFromJson(const ALang, AJson: string): Boolean;

    function SetLanguage(const ALang: string): Boolean;
    function HasLanguage(const ALang: string): Boolean;
    function LanguageCount: Integer;
    function HasKey(const AKey: string): Boolean;

    function Tr(const AKey: string): string;
    function TrF(const AKey: string; const AArgs: array of const): string;

    procedure Bind(const AControl: TControl; const AKey: string);
    procedure Refresh;

    property Current: string read FCurrent;
    property Fallback: string read FFallback write FFallback;
  end;

implementation

type
  TControlAccess = class(TControl);

function EscapeValue(const AValue: string): string;
begin
  Result := StringReplace(AValue, #13#10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\n', [rfReplaceAll]);
end;

function UnescapeValue(const AValue: string): string;
begin
  Result := StringReplace(AValue, '\n', LineEnding, [rfReplaceAll]);
end;

{ TVeloxLocalizer }

constructor TVeloxLocalizer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLangs := TStringList.Create;
  FLangs.CaseSensitive := False;
  FCurrent := 'en';
  FFallback := 'en';
  SetLength(FBindings, 0);
end;

destructor TVeloxLocalizer.Destroy;
var
  I: Integer;
begin
  for I := 0 to FLangs.Count - 1 do
    FLangs.Objects[I].Free;
  FLangs.Free;
  inherited Destroy;
end;

procedure TVeloxLocalizer.Notification(AComponent: TComponent; Operation: TOperation);
var
  I, J: Integer;
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    for I := High(FBindings) downto 0 do
      if TComponent(FBindings[I].Ctl) = AComponent then
      begin
        for J := I to High(FBindings) - 1 do
          FBindings[J] := FBindings[J + 1];
        SetLength(FBindings, Length(FBindings) - 1);
      end;
  end;
end;

function TVeloxLocalizer.FindLang(const ALang: string): TStringList;
var
  Idx: Integer;
begin
  Idx := FLangs.IndexOf(ALang);
  if Idx >= 0 then
    Result := TStringList(FLangs.Objects[Idx])
  else
    Result := nil;
end;

function TVeloxLocalizer.GetOrAddLang(const ALang: string): TStringList;
begin
  Result := FindLang(ALang);
  if Result = nil then
  begin
    Result := TStringList.Create;
    Result.CaseSensitive := True;
    FLangs.AddObject(ALang, Result);
  end;
end;

procedure TVeloxLocalizer.AddEntry(const ALang, AKey, AValue: string);
begin
  GetOrAddLang(ALang).Values[AKey] := EscapeValue(AValue);
end;

procedure TVeloxLocalizer.AddLanguage(const ALang: string; const AStrings: TStrings);
var
  I: Integer;
begin
  if AStrings = nil then Exit;
  for I := 0 to AStrings.Count - 1 do
    if AStrings.Names[I] <> '' then
      AddEntry(ALang, AStrings.Names[I], AStrings.ValueFromIndex[I]);
end;

function TVeloxLocalizer.AddLanguageFromJson(const ALang, AJson: string): Boolean;
var
  Doc: TVeloxJson;
  Err: string;
  I: Integer;
begin
  Result := False;
  Doc := TVeloxJson.Parse(AJson, Err);
  if Doc = nil then Exit;
  try
    if Doc.Kind <> jkObject then Exit;
    for I := 0 to Doc.Count - 1 do
      AddEntry(ALang, Doc.KeyAt[I], Doc[I].AsString);
    Result := True;
  finally
    Doc.Free;
  end;
end;

function TVeloxLocalizer.SetLanguage(const ALang: string): Boolean;
begin
  Result := FindLang(ALang) <> nil;
  if Result then
  begin
    FCurrent := ALang;
    Refresh;
  end;
end;

function TVeloxLocalizer.HasLanguage(const ALang: string): Boolean;
begin
  Result := FindLang(ALang) <> nil;
end;

function TVeloxLocalizer.LanguageCount: Integer;
begin
  Result := FLangs.Count;
end;

function TVeloxLocalizer.HasKey(const AKey: string): Boolean;
var
  L: TStringList;
begin
  L := FindLang(FCurrent);
  Result := (L <> nil) and (L.IndexOfName(AKey) >= 0);
  if not Result then
  begin
    L := FindLang(FFallback);
    Result := (L <> nil) and (L.IndexOfName(AKey) >= 0);
  end;
end;

function TVeloxLocalizer.Tr(const AKey: string): string;
var
  L: TStringList;
  Idx: Integer;
begin
  L := FindLang(FCurrent);
  if L <> nil then
  begin
    Idx := L.IndexOfName(AKey);
    if Idx >= 0 then
      Exit(UnescapeValue(L.ValueFromIndex[Idx]));
  end;
  L := FindLang(FFallback);
  if L <> nil then
  begin
    Idx := L.IndexOfName(AKey);
    if Idx >= 0 then
      Exit(UnescapeValue(L.ValueFromIndex[Idx]));
  end;
  Result := AKey;
end;

function TVeloxLocalizer.TrF(const AKey: string; const AArgs: array of const): string;
begin
  Result := Format(Tr(AKey), AArgs);
end;

procedure TVeloxLocalizer.Bind(const AControl: TControl; const AKey: string);
var
  I, Idx: Integer;
begin
  if AControl = nil then Exit;
  for I := 0 to High(FBindings) do
    if FBindings[I].Ctl = AControl then
    begin
      FBindings[I].Key := AKey;
      TControlAccess(AControl).Caption := Tr(AKey);
      Exit;
    end;
  Idx := Length(FBindings);
  SetLength(FBindings, Idx + 1);
  FBindings[Idx].Ctl := AControl;
  FBindings[Idx].Key := AKey;
  AControl.FreeNotification(Self);
  TControlAccess(AControl).Caption := Tr(AKey);
end;

procedure TVeloxLocalizer.Refresh;
var
  I: Integer;
begin
  for I := 0 to High(FBindings) do
    TControlAccess(FBindings[I].Ctl).Caption := Tr(FBindings[I].Key);
end;

end.
