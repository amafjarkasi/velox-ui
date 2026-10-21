unit Velox.SyntaxHighlight;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.SyntaxHighlight
  Purpose:
    Ultra-lightweight multi-language syntax highlighter and viewer (`TVeloxCodeViewer`)
    inspired by `TurboPack/SynEdit` and Prism.js.
    Pure Object Pascal regex-free micro-lexer supporting JSON, SQL, Pascal,
    and Python without any heavy external dependencies.
    Renders directly to a hardware-accelerated GDI+ / VCL Canvas with line numbers.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  Controls,
  Velox.Types,
  Velox.GdiPlus;

type
  TVeloxSyntaxLang = (vslJson, vslSql, vslPascal, vslPython, vslPlain);

  TVeloxTokenKind = (
    vtkWhitespace,
    vtkKeyword,
    vtkIdentifier,
    vtkNumber,
    vtkString,
    vtkComment,
    vtkSymbol
  );

  TVeloxToken = record
    Kind: TVeloxTokenKind;
    Text: string;
    StartPos: Integer;
    Length: Integer;
  end;

  TVeloxTokenArray = array of TVeloxToken;

  /// <summary>
  /// Micro-lexer scanner for JSON, SQL, Pascal, and Python
  /// </summary>
  TVeloxLexer = class
  private
    class function IsPascalKeyword(const S: string): Boolean; static;
    class function IsSqlKeyword(const S: string): Boolean; static;
    class function IsPythonKeyword(const S: string): Boolean; static;
    class function IsJsonKeyword(const S: string): Boolean; static;
  public
    class function TokenizeLine(const ALine: string; const ALang: TVeloxSyntaxLang): TVeloxTokenArray; static;
    class function TokenColor(const AKind: TVeloxTokenKind; const AColors: TVeloxThemeColors): TColor; static;
  end;

  /// <summary>
  /// Fluent dark-theme syntax highlighted code viewer
  /// </summary>
  TVeloxCodeViewer = class(TCustomControl)
  private
    FLines: TStringList;
    FLang: TVeloxSyntaxLang;
    FColors: TVeloxThemeColors;
    FLineHeight: Integer;
    FShowLineNumbers: Boolean;
    procedure SetLang(const AValue: TVeloxSyntaxLang);
    procedure LinesChanged(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor CreateViewer(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth, AHeight: Integer;
      const ALang: TVeloxSyntaxLang; const AColors: TVeloxThemeColors);
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure SetCode(const AText: string);
    function GetCode: string;

    property Lang: TVeloxSyntaxLang read FLang write SetLang;
    property ShowLineNumbers: Boolean read FShowLineNumbers write FShowLineNumbers default True;
    property Lines: TStringList read FLines;
  end;

implementation

{ TVeloxLexer }

class function TVeloxLexer.IsPascalKeyword(const S: string): Boolean;
const
  Keywords: array[0..27] of string = (
    'BEGIN', 'END', 'PROCEDURE', 'FUNCTION', 'VAR', 'CONST', 'TYPE',
    'CLASS', 'RECORD', 'INTERFACE', 'IMPLEMENTATION', 'USES', 'UNIT',
    'IF', 'THEN', 'ELSE', 'CASE', 'OF', 'FOR', 'TO', 'DOWNTO', 'DO',
    'WHILE', 'REPEAT', 'UNTIL', 'TRY', 'FINALLY', 'EXCEPT'
  );
var
  U: string;
  I: Integer;
begin
  U := UpperCase(S);
  for I := 0 to High(Keywords) do
    if Keywords[I] = U then Exit(True);
  Result := False;
end;

class function TVeloxLexer.IsSqlKeyword(const S: string): Boolean;
const
  Keywords: array[0..21] of string = (
    'SELECT', 'FROM', 'WHERE', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'ON',
    'GROUP', 'BY', 'ORDER', 'HAVING', 'LIMIT', 'INSERT', 'INTO', 'VALUES',
    'UPDATE', 'SET', 'DELETE', 'CREATE', 'TABLE', 'DROP'
  );
var
  U: string;
  I: Integer;
begin
  U := UpperCase(S);
  for I := 0 to High(Keywords) do
    if Keywords[I] = U then Exit(True);
  Result := False;
end;

class function TVeloxLexer.IsPythonKeyword(const S: string): Boolean;
const
  Keywords: array[0..21] of string = (
    'def', 'class', 'import', 'from', 'as', 'if', 'elif', 'else',
    'for', 'while', 'return', 'yield', 'try', 'except', 'finally',
    'with', 'in', 'is', 'not', 'and', 'or', 'pass'
  );
var
  I: Integer;
begin
  for I := 0 to High(Keywords) do
    if Keywords[I] = S then Exit(True);
  Result := False;
end;

class function TVeloxLexer.IsJsonKeyword(const S: string): Boolean;
begin
  Result := (S = 'true') or (S = 'false') or (S = 'null');
end;

class function TVeloxLexer.TokenColor(const AKind: TVeloxTokenKind; const AColors: TVeloxThemeColors): TColor;
begin
  case AKind of
    vtkKeyword:   Result := AColors.Accent;                  // Cyan
    vtkString:    Result := AColors.Success;                 // Emerald Green
    vtkNumber:    Result := AColors.Warning;                 // Amber / Orange
    vtkComment:   Result := AColors.TextSecondary;           // Slate Muted
    vtkSymbol:    Result := TVeloxUtils.BlendColor(AColors.TextPrimary, AColors.Accent, 0.25);
  else
    Result := AColors.TextPrimary;
  end;
end;

class function TVeloxLexer.TokenizeLine(const ALine: string; const ALang: TVeloxSyntaxLang): TVeloxTokenArray;
var
  Tokens: array of TVeloxToken;
  N, Count, I, StartIdx: Integer;
  Ch, QuoteChar: Char;
  WordStr: string;
  Tok: TVeloxToken;

  procedure AddTok(const AKind: TVeloxTokenKind; const AText: string; const APos: Integer);
  begin
    Inc(Count);
    SetLength(Tokens, Count);
    Tok.Kind := AKind;
    Tok.Text := AText;
    Tok.StartPos := APos;
    Tok.Length := Length(AText);
    Tokens[Count - 1] := Tok;
  end;

begin
  Count := 0;
  SetLength(Tokens, 0);
  N := Length(ALine);
  I := 1;

  while I <= N do
  begin
    Ch := ALine[I];

    // 1. Whitespace
    if Ch in [' ', #9] then
    begin
      StartIdx := I;
      while (I <= N) and (ALine[I] in [' ', #9]) do
        Inc(I);
      AddTok(vtkWhitespace, Copy(ALine, StartIdx, I - StartIdx), StartIdx);
      Continue;
    end;

    // 2. Comments
    if (ALang = vslPascal) and (Ch = '/') and (I < N) and (ALine[I + 1] = '/') then
    begin
      AddTok(vtkComment, Copy(ALine, I, N - I + 1), I);
      Break;
    end;
    if (ALang = vslPython) and (Ch = '#') then
    begin
      AddTok(vtkComment, Copy(ALine, I, N - I + 1), I);
      Break;
    end;
    if (ALang = vslSql) and (Ch = '-') and (I < N) and (ALine[I + 1] = '-') then
    begin
      AddTok(vtkComment, Copy(ALine, I, N - I + 1), I);
      Break;
    end;

    // 3. Strings
    if (Ch = '"') or ((Ch = '''') and (ALang in [vslPascal, vslSql, vslPython])) then
    begin
      QuoteChar := Ch;
      StartIdx := I;
      Inc(I);
      while (I <= N) and (ALine[I] <> QuoteChar) do
      begin
        if (ALine[I] = '\') and (I < N) then Inc(I); // Skip escape
        Inc(I);
      end;
      if I <= N then Inc(I); // Include closing quote
      AddTok(vtkString, Copy(ALine, StartIdx, I - StartIdx), StartIdx);
      Continue;
    end;

    // 4. Numbers
    if (Ch in ['0'..'9']) or ((Ch = '-') and (I < N) and (ALine[I + 1] in ['0'..'9'])) then
    begin
      StartIdx := I;
      if Ch = '-' then Inc(I);
      while (I <= N) and (ALine[I] in ['0'..'9', '.', 'x', 'X', 'a'..'f', 'A'..'F']) do
        Inc(I);
      AddTok(vtkNumber, Copy(ALine, StartIdx, I - StartIdx), StartIdx);
      Continue;
    end;

    // 5. Identifiers / Keywords
    if Ch in ['a'..'z', 'A'..'Z', '_'] then
    begin
      StartIdx := I;
      while (I <= N) and (ALine[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
        Inc(I);
      WordStr := Copy(ALine, StartIdx, I - StartIdx);

      case ALang of
        vslPascal:
          if IsPascalKeyword(WordStr) then
            AddTok(vtkKeyword, WordStr, StartIdx)
          else
            AddTok(vtkIdentifier, WordStr, StartIdx);
        vslSql:
          if IsSqlKeyword(WordStr) then
            AddTok(vtkKeyword, WordStr, StartIdx)
          else
            AddTok(vtkIdentifier, WordStr, StartIdx);
        vslPython:
          if IsPythonKeyword(WordStr) then
            AddTok(vtkKeyword, WordStr, StartIdx)
          else
            AddTok(vtkIdentifier, WordStr, StartIdx);
        vslJson:
          if IsJsonKeyword(WordStr) then
            AddTok(vtkKeyword, WordStr, StartIdx)
          else
            AddTok(vtkIdentifier, WordStr, StartIdx);
      else
        AddTok(vtkIdentifier, WordStr, StartIdx);
      end;
      Continue;
    end;

    // 6. Symbols / Punctuation
    AddTok(vtkSymbol, Ch, I);
    Inc(I);
  end;

  Result := Tokens;
end;

{ TVeloxCodeViewer }

constructor TVeloxCodeViewer.CreateViewer(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth, AHeight: Integer;
  const ALang: TVeloxSyntaxLang; const AColors: TVeloxThemeColors);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, AWidth, AHeight);
  FLang := ALang;
  FColors := AColors;
  FLineHeight := 18;
  FShowLineNumbers := True;
  FLines := TStringList.Create;
  FLines.OnChange := LinesChanged;
end;

destructor TVeloxCodeViewer.Destroy;
begin
  FLines.Free;
  inherited Destroy;
end;

procedure TVeloxCodeViewer.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxCodeViewer.SetLang(const AValue: TVeloxSyntaxLang);
begin
  if FLang <> AValue then
  begin
    FLang := AValue;
    Invalidate;
  end;
end;

procedure TVeloxCodeViewer.LinesChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TVeloxCodeViewer.SetCode(const AText: string);
begin
  FLines.Text := AText;
end;

function TVeloxCodeViewer.GetCode: string;
begin
  Result := FLines.Text;
end;

procedure TVeloxCodeViewer.Paint;
var
  I, J, LineY, LeftMargin, GutterW, CurX: Integer;
  Tokens: TVeloxTokenArray;
  NumStr: string;
  R, GutterR: TRect;
begin
  R := Rect(0, 0, Width, Height);

  // Background card
  TVeloxGdiPlus.DrawCard(Canvas, R, FColors.SurfaceCard, FColors.Border, 6);

  Canvas.Font.Name := 'Consolas';
  Canvas.Font.Size := 9;
  FLineHeight := Canvas.TextHeight('Ag') + 4;
  if FLineHeight < 16 then FLineHeight := 16;

  GutterW := 0;
  if FShowLineNumbers then
  begin
    GutterW := Canvas.TextWidth(' 999 ') + 8;
    GutterR := Rect(0, 0, GutterW, Height);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := FColors.Surface;
    Canvas.FillRect(GutterR);

    // Gutter border separator
    Canvas.Pen.Color := FColors.Border;
    Canvas.Pen.Width := 1;
    Canvas.MoveTo(GutterW, 0);
    Canvas.LineTo(GutterW, Height);
  end;

  LeftMargin := GutterW + 10;
  Canvas.Brush.Style := bsClear;

  for I := 0 to FLines.Count - 1 do
  begin
    LineY := 6 + I * FLineHeight;
    if (LineY + FLineHeight < 0) or (LineY > Height) then Continue;

    // Line number
    if FShowLineNumbers then
    begin
      NumStr := IntToStr(I + 1);
      Canvas.Font.Color := FColors.TextSecondary;
      Canvas.Font.Style := [];
      Canvas.TextOut(GutterW - Canvas.TextWidth(NumStr) - 8, LineY, NumStr);
    end;

    // Line tokens
    Tokens := TVeloxLexer.TokenizeLine(FLines[I], FLang);
    CurX := LeftMargin;

    for J := 0 to High(Tokens) do
    begin
      Canvas.Font.Color := TVeloxLexer.TokenColor(Tokens[J].Kind, FColors);
      if Tokens[J].Kind = vtkKeyword then
        Canvas.Font.Style := [fsBold]
      else
        Canvas.Font.Style := [];

      Canvas.TextOut(CurX, LineY, Tokens[J].Text);
      Inc(CurX, Canvas.TextWidth(Tokens[J].Text));
    end;
  end;
end;

end.
