unit Velox.Json;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Json
  Purpose:
    Zero-dependency JSON reader + builder (`TVeloxJson`) inspired by
    `ahausladen/JsonDataObjects` and `neslib/Neslib.Json`.
    Parses RFC-8259 JSON into a lightweight DOM, supports `Path('a.b[0].c')`
    navigation, typed accessors with defaults, fluent object/array building,
    and compact or pretty serialization. Locale-independent number handling.
==============================================================================}

interface

uses
  SysUtils,
  Classes;

type
  TVeloxJsonKind = (jkNull, jkBool, jkNumber, jkString, jkArray, jkObject);

  /// <summary>
  /// JSON DOM node (null, bool, number, string, array, or object)
  /// </summary>
  TVeloxJson = class
  private
    FKind: TVeloxJsonKind;
    FBool: Boolean;
    FNum: Double;
    FStr: string;
    FItems: TList;
    FKeys: TStringList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TVeloxJson;
    function GetKey(Index: Integer): string;
    procedure Emit(var ABuf: string; const APretty: Boolean; const ALevel: Integer);
  public
    constructor Create(const AKind: TVeloxJsonKind = jkNull);
    destructor Destroy; override;

    /// <summary>
    /// Parses JSON text. Returns nil and sets AError on failure. Caller frees the result.
    /// </summary>
    class function Parse(const AText: string; out AError: string): TVeloxJson; static;
    class function NewObject: TVeloxJson; static;
    class function NewArray: TVeloxJson; static;

    /// <summary>Object member lookup (nil when missing or not an object).</summary>
    function Find(const AKey: string): TVeloxJson;
    /// <summary>Dotted path navigation, e.g. 'assets[0].name'. Returns nil when missing.</summary>
    function Path(const APath: string): TVeloxJson;

    function AsString(const ADefault: string = ''): string;
    function AsInt(const ADefault: Integer = 0): Integer;
    function AsFloat(const ADefault: Double = 0.0): Double;
    function AsBool(const ADefault: Boolean = False): Boolean;

    { Object builders (replace existing key). Return the stored node. }
    function PutChild(const AKey: string; const AChild: TVeloxJson): TVeloxJson;
    procedure PutStr(const AKey, AValue: string);
    procedure PutNum(const AKey: string; const AValue: Double);
    procedure PutBool(const AKey: string; const AValue: Boolean);
    { Array builders }
    function AddChild(const AChild: TVeloxJson): TVeloxJson;
    procedure AddStr(const AValue: string);
    procedure AddNum(const AValue: Double);

    function Serialize(const APretty: Boolean = False): string;

    property Kind: TVeloxJsonKind read FKind;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TVeloxJson read GetItem; default;
    property KeyAt[Index: Integer]: string read GetKey;
  end;

implementation

{ ---- helpers ---- }

function NumToStr(const AValue: Double): string;
var
  S: string;
begin
  if (Frac(AValue) = 0.0) and (Abs(AValue) < 1.0e15) then
    Result := IntToStr(Trunc(AValue))
  else
  begin
    Str(AValue:0:10, S);
    while (Length(S) > 1) and (S[Length(S)] = '0') do
      Delete(S, Length(S), 1);
    if (Length(S) > 0) and (S[Length(S)] = '.') then
      Delete(S, Length(S), 1);
    Result := S;
  end;
end;

function EscapeJson(const AValue: string): string;
var
  I: Integer;
  Ch: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    Ch := AValue[I];
    case Ch of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #8:   Result := Result + '\b';
      #9:   Result := Result + '\t';
      #10:  Result := Result + '\n';
      #12:  Result := Result + '\f';
      #13:  Result := Result + '\r';
    else
      if Ord(Ch) < 32 then
        Result := Result + '\u' + IntToHex(Ord(Ch), 4)
      else
        Result := Result + Ch;
    end;
  end;
end;

procedure AppendCodepoint(var ABuf: string; var AIdx: Integer; const ACode: Cardinal);
begin
  {$IFDEF FPC}
  if ACode < $80 then
  begin
    Inc(AIdx);
    ABuf[AIdx] := Chr(ACode);
  end
  else if ACode < $800 then
  begin
    ABuf[AIdx + 1] := Chr($C0 or (ACode shr 6));
    ABuf[AIdx + 2] := Chr($80 or (ACode and $3F));
    Inc(AIdx, 2);
  end
  else
  begin
    ABuf[AIdx + 1] := Chr($E0 or (ACode shr 12));
    ABuf[AIdx + 2] := Chr($80 or ((ACode shr 6) and $3F));
    ABuf[AIdx + 3] := Chr($80 or (ACode and $3F));
    Inc(AIdx, 3);
  end;
  {$ELSE}
  Inc(AIdx);
  ABuf[AIdx] := Char(ACode);
  {$ENDIF}
end;

function HexVal(const C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

{ ---- parser ---- }

type
  TJsonParser = class
  public
    S: string;
    P: Integer;
    Err: string;
    procedure SetErr(const AMsg: string);
    procedure SkipWs;
    function ParseStringBody(out AResult: string): Boolean;
    function ParseValue(const ADepth: Integer): TVeloxJson;
    function ParseObject(const ADepth: Integer): TVeloxJson;
    function ParseArray(const ADepth: Integer): TVeloxJson;
    function ParseNumber: TVeloxJson;
  end;

procedure TJsonParser.SetErr(const AMsg: string);
begin
  if Err = '' then
    Err := Format('%s at position %d', [AMsg, P]);
end;

procedure TJsonParser.SkipWs;
begin
  while (P <= Length(S)) and (S[P] in [#9, #10, #13, ' ']) do
    Inc(P);
end;

function TJsonParser.ParseStringBody(out AResult: string): Boolean;
var
  Buf: string;
  Idx, I, H: Integer;
  C: Char;
  Code: Cardinal;
begin
  Result := False;
  AResult := '';
  Buf := '';
  SetLength(Buf, Length(S) - P + 2);
  Idx := 0;
  while P <= Length(S) do
  begin
    C := S[P];
    if C = '"' then
    begin
      Inc(P);
      SetLength(Buf, Idx);
      AResult := Buf;
      Exit(True);
    end
    else if C = '\' then
    begin
      Inc(P);
      if P > Length(S) then
      begin
        SetErr('Unterminated escape');
        Exit;
      end;
      C := S[P];
      case C of
        '"', '\', '/': begin Inc(Idx); Buf[Idx] := C; end;
        'b': begin Inc(Idx); Buf[Idx] := #8; end;
        'f': begin Inc(Idx); Buf[Idx] := #12; end;
        'n': begin Inc(Idx); Buf[Idx] := #10; end;
        'r': begin Inc(Idx); Buf[Idx] := #13; end;
        't': begin Inc(Idx); Buf[Idx] := #9; end;
        'u':
          begin
            if P + 4 > Length(S) then
            begin
              SetErr('Truncated \u escape');
              Exit;
            end;
            Code := 0;
            for I := 1 to 4 do
            begin
              H := HexVal(S[P + I]);
              if H < 0 then
              begin
                SetErr('Invalid \u escape');
                Exit;
              end;
              Code := Code * 16 + Cardinal(H);
            end;
            Inc(P, 4);
            AppendCodepoint(Buf, Idx, Code);
          end;
      else
        SetErr('Invalid escape');
        Exit;
      end;
      Inc(P);
    end
    else
    begin
      Inc(Idx);
      Buf[Idx] := C;
      Inc(P);
    end;
  end;
  SetErr('Unterminated string');
end;

function TJsonParser.ParseNumber: TVeloxJson;
var
  Start, Code: Integer;
  Tok: string;
  D: Double;
begin
  Result := nil;
  Start := P;
  while (P <= Length(S)) and (S[P] in ['+', '-', '.', 'e', 'E', '0'..'9']) do
    Inc(P);
  Tok := Copy(S, Start, P - Start);
  Val(Tok, D, Code);
  if (Tok = '') or (Code <> 0) then
  begin
    P := Start;
    SetErr('Invalid number');
    Exit;
  end;
  Result := TVeloxJson.Create(jkNumber);
  Result.FNum := D;
end;

function TJsonParser.ParseArray(const ADepth: Integer): TVeloxJson;
var
  Child: TVeloxJson;
begin
  Result := TVeloxJson.Create(jkArray);
  Inc(P);
  SkipWs;
  if (P <= Length(S)) and (S[P] = ']') then
  begin
    Inc(P);
    Exit;
  end;
  while True do
  begin
    Child := ParseValue(ADepth + 1);
    if Child = nil then
    begin
      FreeAndNil(Result);
      Exit;
    end;
    Result.AddChild(Child);
    SkipWs;
    if P > Length(S) then
    begin
      SetErr('Unterminated array');
      FreeAndNil(Result);
      Exit;
    end;
    if S[P] = ',' then
      Inc(P)
    else if S[P] = ']' then
    begin
      Inc(P);
      Exit;
    end
    else
    begin
      SetErr('Expected , or ]');
      FreeAndNil(Result);
      Exit;
    end;
  end;
end;

function TJsonParser.ParseObject(const ADepth: Integer): TVeloxJson;
var
  Key: string;
  Child: TVeloxJson;
begin
  Result := TVeloxJson.Create(jkObject);
  Inc(P);
  SkipWs;
  if (P <= Length(S)) and (S[P] = '}') then
  begin
    Inc(P);
    Exit;
  end;
  while True do
  begin
    SkipWs;
    if (P > Length(S)) or (S[P] <> '"') then
    begin
      SetErr('Expected object key');
      FreeAndNil(Result);
      Exit;
    end;
    Inc(P);
    if not ParseStringBody(Key) then
    begin
      FreeAndNil(Result);
      Exit;
    end;
    SkipWs;
    if (P > Length(S)) or (S[P] <> ':') then
    begin
      SetErr('Expected :');
      FreeAndNil(Result);
      Exit;
    end;
    Inc(P);
    Child := ParseValue(ADepth + 1);
    if Child = nil then
    begin
      FreeAndNil(Result);
      Exit;
    end;
    Result.PutChild(Key, Child);
    SkipWs;
    if P > Length(S) then
    begin
      SetErr('Unterminated object');
      FreeAndNil(Result);
      Exit;
    end;
    if S[P] = ',' then
      Inc(P)
    else if S[P] = '}' then
    begin
      Inc(P);
      Exit;
    end
    else
    begin
      SetErr('Expected , or }');
      FreeAndNil(Result);
      Exit;
    end;
  end;
end;

function TJsonParser.ParseValue(const ADepth: Integer): TVeloxJson;
var
  Str: string;
begin
  Result := nil;
  if ADepth > 128 then
  begin
    SetErr('Nesting too deep');
    Exit;
  end;
  SkipWs;
  if P > Length(S) then
  begin
    SetErr('Unexpected end');
    Exit;
  end;
  case S[P] of
    '{': Result := ParseObject(ADepth);
    '[': Result := ParseArray(ADepth);
    '"':
      begin
        Inc(P);
        if ParseStringBody(Str) then
        begin
          Result := TVeloxJson.Create(jkString);
          Result.FStr := Str;
        end;
      end;
    '-', '0'..'9': Result := ParseNumber;
    't':
      if Copy(S, P, 4) = 'true' then
      begin
        Inc(P, 4);
        Result := TVeloxJson.Create(jkBool);
        Result.FBool := True;
      end
      else
        SetErr('Invalid literal');
    'f':
      if Copy(S, P, 5) = 'false' then
      begin
        Inc(P, 5);
        Result := TVeloxJson.Create(jkBool);
        Result.FBool := False;
      end
      else
        SetErr('Invalid literal');
    'n':
      if Copy(S, P, 4) = 'null' then
      begin
        Inc(P, 4);
        Result := TVeloxJson.Create(jkNull);
      end
      else
        SetErr('Invalid literal');
  else
    SetErr('Unexpected character');
  end;
end;

{ ---- TVeloxJson ---- }

constructor TVeloxJson.Create(const AKind: TVeloxJsonKind);
begin
  inherited Create;
  FKind := AKind;
  if AKind in [jkArray, jkObject] then
    FItems := TList.Create;
  if AKind = jkObject then
  begin
    FKeys := TStringList.Create;
    FKeys.CaseSensitive := True;
  end;
end;

destructor TVeloxJson.Destroy;
var
  I: Integer;
begin
  if FItems <> nil then
  begin
    for I := 0 to FItems.Count - 1 do
      TVeloxJson(FItems[I]).Free;
    FItems.Free;
  end;
  FKeys.Free;
  inherited Destroy;
end;

class function TVeloxJson.Parse(const AText: string; out AError: string): TVeloxJson;
var
  Parser: TJsonParser;
begin
  Parser := TJsonParser.Create;
  try
    Parser.S := AText;
    Parser.P := 1;
    Parser.Err := '';
    Result := Parser.ParseValue(0);
    if Result <> nil then
    begin
      Parser.SkipWs;
      if Parser.P <= Length(Parser.S) then
      begin
        Parser.SetErr('Unexpected trailing characters');
        FreeAndNil(Result);
      end;
    end;
    AError := Parser.Err;
    if (Result = nil) and (AError = '') then
      AError := 'Parse error';
  finally
    Parser.Free;
  end;
end;

class function TVeloxJson.NewObject: TVeloxJson;
begin
  Result := TVeloxJson.Create(jkObject);
end;

class function TVeloxJson.NewArray: TVeloxJson;
begin
  Result := TVeloxJson.Create(jkArray);
end;

function TVeloxJson.GetCount: Integer;
begin
  if FItems = nil then
    Result := 0
  else
    Result := FItems.Count;
end;

function TVeloxJson.GetItem(Index: Integer): TVeloxJson;
begin
  if (FItems = nil) or (Index < 0) or (Index >= FItems.Count) then
    Result := nil
  else
    Result := TVeloxJson(FItems[Index]);
end;

function TVeloxJson.GetKey(Index: Integer): string;
begin
  if (FKeys = nil) or (Index < 0) or (Index >= FKeys.Count) then
    Result := ''
  else
    Result := FKeys[Index];
end;

function TVeloxJson.Find(const AKey: string): TVeloxJson;
var
  Idx: Integer;
begin
  Result := nil;
  if (FKind <> jkObject) or (FKeys = nil) then Exit;
  Idx := FKeys.IndexOf(AKey);
  if Idx >= 0 then
    Result := TVeloxJson(FItems[Idx]);
end;

function TVeloxJson.Path(const APath: string): TVeloxJson;
var
  Segs: array of string;
  I, N, K, Idx: Integer;
  Cur: TVeloxJson;
  Seg, Name, Rest, Tok: string;
begin
  Result := nil;
  Cur := Self;
  Segs := nil;
  Tok := '';
  N := 0;
  for I := 1 to Length(APath) do
  begin
    if APath[I] = '.' then
    begin
      SetLength(Segs, N + 1);
      Segs[N] := Tok;
      Inc(N);
      Tok := '';
    end
    else
      Tok := Tok + APath[I];
  end;
  if Tok <> '' then
  begin
    SetLength(Segs, N + 1);
    Segs[N] := Tok;
    Inc(N);
  end;

  for I := 0 to N - 1 do
  begin
    Seg := Segs[I];
    K := Pos('[', Seg);
    if K > 0 then
    begin
      Name := Copy(Seg, 1, K - 1);
      Rest := Copy(Seg, K, MaxInt);
    end
    else
    begin
      Name := Seg;
      Rest := '';
    end;
    if Name <> '' then
    begin
      Cur := Cur.Find(Name);
      if Cur = nil then Exit;
    end;
    while Rest <> '' do
    begin
      if Rest[1] <> '[' then Exit;
      K := Pos(']', Rest);
      if K = 0 then Exit;
      Idx := StrToIntDef(Copy(Rest, 2, K - 2), -1);
      if Cur.FKind <> jkArray then Exit;
      Cur := Cur.GetItem(Idx);
      if Cur = nil then Exit;
      Rest := Copy(Rest, K + 1, MaxInt);
    end;
  end;
  Result := Cur;
end;

function TVeloxJson.AsString(const ADefault: string): string;
begin
  case FKind of
    jkString: Result := FStr;
    jkNumber: Result := NumToStr(FNum);
    jkBool:
      if FBool then Result := 'true' else Result := 'false';
  else
    Result := ADefault;
  end;
end;

function TVeloxJson.AsInt(const ADefault: Integer): Integer;
begin
  case FKind of
    jkNumber: Result := Round(FNum);
    jkString: Result := StrToIntDef(FStr, ADefault);
    jkBool:
      if FBool then Result := 1 else Result := 0;
  else
    Result := ADefault;
  end;
end;

function TVeloxJson.AsFloat(const ADefault: Double): Double;
var
  Code: Integer;
  D: Double;
begin
  case FKind of
    jkNumber: Result := FNum;
    jkString:
      begin
        Val(FStr, D, Code);
        if Code = 0 then Result := D else Result := ADefault;
      end;
  else
    Result := ADefault;
  end;
end;

function TVeloxJson.AsBool(const ADefault: Boolean): Boolean;
begin
  case FKind of
    jkBool: Result := FBool;
    jkNumber: Result := FNum <> 0.0;
    jkString: Result := SameText(FStr, 'true') or (FStr = '1');
  else
    Result := ADefault;
  end;
end;

function TVeloxJson.PutChild(const AKey: string; const AChild: TVeloxJson): TVeloxJson;
var
  Idx: Integer;
begin
  Result := AChild;
  if (FKind <> jkObject) or (AChild = nil) then
  begin
    if AChild <> nil then AChild.Free;
    Result := nil;
    Exit;
  end;
  Idx := FKeys.IndexOf(AKey);
  if Idx >= 0 then
  begin
    TVeloxJson(FItems[Idx]).Free;
    FItems[Idx] := AChild;
  end
  else
  begin
    FKeys.Add(AKey);
    FItems.Add(AChild);
  end;
end;

procedure TVeloxJson.PutStr(const AKey, AValue: string);
var
  N: TVeloxJson;
begin
  N := TVeloxJson.Create(jkString);
  N.FStr := AValue;
  PutChild(AKey, N);
end;

procedure TVeloxJson.PutNum(const AKey: string; const AValue: Double);
var
  N: TVeloxJson;
begin
  N := TVeloxJson.Create(jkNumber);
  N.FNum := AValue;
  PutChild(AKey, N);
end;

procedure TVeloxJson.PutBool(const AKey: string; const AValue: Boolean);
var
  N: TVeloxJson;
begin
  N := TVeloxJson.Create(jkBool);
  N.FBool := AValue;
  PutChild(AKey, N);
end;

function TVeloxJson.AddChild(const AChild: TVeloxJson): TVeloxJson;
begin
  Result := AChild;
  if (FKind <> jkArray) or (AChild = nil) then
  begin
    if AChild <> nil then AChild.Free;
    Result := nil;
    Exit;
  end;
  FItems.Add(AChild);
end;

procedure TVeloxJson.AddStr(const AValue: string);
var
  N: TVeloxJson;
begin
  N := TVeloxJson.Create(jkString);
  N.FStr := AValue;
  AddChild(N);
end;

procedure TVeloxJson.AddNum(const AValue: Double);
var
  N: TVeloxJson;
begin
  N := TVeloxJson.Create(jkNumber);
  N.FNum := AValue;
  AddChild(N);
end;

procedure TVeloxJson.Emit(var ABuf: string; const APretty: Boolean; const ALevel: Integer);
var
  I: Integer;
  Pad, PadIn, Sep, Colon: string;
begin
  if APretty then
  begin
    Pad := StringOfChar(' ', ALevel * 2);
    PadIn := StringOfChar(' ', (ALevel + 1) * 2);
    Sep := LineEnding;
    Colon := ': ';
  end
  else
  begin
    Pad := '';
    PadIn := '';
    Sep := '';
    Colon := ':';
  end;

  case FKind of
    jkNull: ABuf := ABuf + 'null';
    jkBool:
      if FBool then ABuf := ABuf + 'true' else ABuf := ABuf + 'false';
    jkNumber: ABuf := ABuf + NumToStr(FNum);
    jkString: ABuf := ABuf + '"' + EscapeJson(FStr) + '"';
    jkArray:
      begin
        if FItems.Count = 0 then
          ABuf := ABuf + '[]'
        else
        begin
          ABuf := ABuf + '[' + Sep;
          for I := 0 to FItems.Count - 1 do
          begin
            ABuf := ABuf + PadIn;
            TVeloxJson(FItems[I]).Emit(ABuf, APretty, ALevel + 1);
            if I < FItems.Count - 1 then ABuf := ABuf + ',';
            ABuf := ABuf + Sep;
          end;
          ABuf := ABuf + Pad + ']';
        end;
      end;
    jkObject:
      begin
        if FItems.Count = 0 then
          ABuf := ABuf + '{}'
        else
        begin
          ABuf := ABuf + '{' + Sep;
          for I := 0 to FItems.Count - 1 do
          begin
            ABuf := ABuf + PadIn + '"' + EscapeJson(FKeys[I]) + '"' + Colon;
            TVeloxJson(FItems[I]).Emit(ABuf, APretty, ALevel + 1);
            if I < FItems.Count - 1 then ABuf := ABuf + ',';
            ABuf := ABuf + Sep;
          end;
          ABuf := ABuf + Pad + '}';
        end;
      end;
  end;
end;

function TVeloxJson.Serialize(const APretty: Boolean): string;
begin
  Result := '';
  Emit(Result, APretty, 0);
end;

end.
