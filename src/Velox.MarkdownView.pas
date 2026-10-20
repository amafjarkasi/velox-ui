unit Velox.MarkdownView;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.MarkdownView
  Purpose:
    Lightweight Native GDI+ Markdown & Changelog Renderer (`TVeloxMarkdownView`)
    inspired by `EtheaDev/StyledComponents` and `lazpaint/bgracontrols`.
    Parses and renders `# H1`, `## H2`, `### H3` headings, `- ` bullet lists,
    `> ` callout alert quotes, `---` horizontal rules, and body paragraphs
    natively in Dark/Light mode without any WebView2 dependency.
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
  TVeloxMdLineKind = (vmlBlank, vmlH1, vmlH2, vmlH3, vmlBullet, vmlQuote, vmlRule, vmlParagraph);

  TVeloxMdBlock = record
    Kind: TVeloxMdLineKind;
    CleanText: string;
  end;

  TVeloxMdBlockArray = array of TVeloxMdBlock;

  /// <summary>
  /// Native GDI+ Markdown viewer control for release notes, changelogs, and help panels
  /// </summary>
  TVeloxMarkdownView = class(TCustomControl)
  private
    FBlocks: TVeloxMdBlockArray;
    FColors: TVeloxThemeColors;
    function GetBlockCount: Integer;
  protected
    procedure Paint; override;
  public
    constructor CreateView(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth, AHeight: Integer;
      const AColors: TVeloxThemeColors);
    procedure LoadMarkdown(const AMarkdownText: string);
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    class function ParseMarkdownLine(const ALine: string): TVeloxMdBlock; static;

    property BlockCount: Integer read GetBlockCount;
  end;

implementation

{ TVeloxMarkdownView }

constructor TVeloxMarkdownView.CreateView(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth, AHeight: Integer;
  const AColors: TVeloxThemeColors);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  SetBounds(ALeft, ATop, AWidth, AHeight);
  FColors := AColors;
  SetLength(FBlocks, 0);
end;

function TVeloxMarkdownView.GetBlockCount: Integer;
begin
  Result := Length(FBlocks);
end;

procedure TVeloxMarkdownView.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

class function TVeloxMarkdownView.ParseMarkdownLine(const ALine: string): TVeloxMdBlock;
var
  S: string;
begin
  S := Trim(ALine);
  if S = '' then
  begin
    Result.Kind := vmlBlank;
    Result.CleanText := '';
  end
  else if (S = '---') or (S = '***') then
  begin
    Result.Kind := vmlRule;
    Result.CleanText := '';
  end
  else if Copy(S, 1, 4) = '### ' then
  begin
    Result.Kind := vmlH3;
    Result.CleanText := Trim(Copy(S, 5, MaxInt));
  end
  else if Copy(S, 1, 3) = '## ' then
  begin
    Result.Kind := vmlH2;
    Result.CleanText := Trim(Copy(S, 4, MaxInt));
  end
  else if Copy(S, 1, 2) = '# ' then
  begin
    Result.Kind := vmlH1;
    Result.CleanText := Trim(Copy(S, 3, MaxInt));
  end
  else if (Copy(S, 1, 2) = '- ') or (Copy(S, 1, 2) = '* ') then
  begin
    Result.Kind := vmlBullet;
    Result.CleanText := Trim(Copy(S, 3, MaxInt));
  end
  else if Copy(S, 1, 2) = '> ' then
  begin
    Result.Kind := vmlQuote;
    Result.CleanText := Trim(Copy(S, 3, MaxInt));
  end
  else
  begin
    Result.Kind := vmlParagraph;
    Result.CleanText := S;
  end;

  // Strip simple **bold** and `code` markers for clean text display
  Result.CleanText := StringReplace(Result.CleanText, '**', '', [rfReplaceAll]);
  Result.CleanText := StringReplace(Result.CleanText, '`', '', [rfReplaceAll]);
end;

procedure TVeloxMarkdownView.LoadMarkdown(const AMarkdownText: string);
var
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AMarkdownText;
    SetLength(FBlocks, Lines.Count);
    for I := 0 to Lines.Count - 1 do
      FBlocks[I] := ParseMarkdownLine(Lines[I]);
  finally
    Lines.Free;
  end;
  Invalidate;
end;

procedure TVeloxMarkdownView.Paint;
var
  I, CurY: Integer;
  B: TVeloxMdBlock;
  QuoteR: TRect;
begin
  TVeloxGdiPlus.DrawCard(Canvas, Rect(0, 0, Width, Height), FColors.SurfaceCard, FColors.Border, 8);

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';
  CurY := 14;

  for I := 0 to High(FBlocks) do
  begin
    if CurY > Height - 18 then Break;
    B := FBlocks[I];
    case B.Kind of
      vmlBlank:
        Inc(CurY, 8);
      vmlRule:
        begin
          Canvas.Pen.Color := FColors.Border;
          Canvas.MoveTo(16, CurY + 4);
          Canvas.LineTo(Width - 16, CurY + 4);
          Inc(CurY, 12);
        end;
      vmlH1:
        begin
          Canvas.Font.Size := 14;
          Canvas.Font.Style := [fsBold];
          Canvas.Font.Color := FColors.TextPrimary;
          Canvas.TextOut(16, CurY, B.CleanText);
          Inc(CurY, 28);
        end;
      vmlH2:
        begin
          Canvas.Font.Size := 11;
          Canvas.Font.Style := [fsBold];
          Canvas.Font.Color := FColors.Accent;
          Canvas.TextOut(16, CurY, B.CleanText);
          Inc(CurY, 22);
        end;
      vmlH3:
        begin
          Canvas.Font.Size := 10;
          Canvas.Font.Style := [fsBold];
          Canvas.Font.Color := FColors.TextPrimary;
          Canvas.TextOut(16, CurY, B.CleanText);
          Inc(CurY, 20);
        end;
      vmlBullet:
        begin
          Canvas.Font.Size := 9;
          Canvas.Font.Style := [];
          Canvas.Font.Color := FColors.Accent;
          Canvas.TextOut(20, CurY, VELOX_BULLET);
          Canvas.Font.Color := FColors.TextPrimary;
          Canvas.TextOut(34, CurY, B.CleanText);
          Inc(CurY, 20);
        end;
      vmlQuote:
        begin
          QuoteR := Rect(16, CurY, Width - 16, CurY + 24);
          TVeloxGdiPlus.DrawCard(Canvas, QuoteR,
            TVeloxUtils.BlendColor(FColors.SurfaceCard, FColors.Accent, 0.14),
            FColors.Accent, 4);
          Canvas.Brush.Style := bsClear;
          Canvas.Font.Size := 9;
          Canvas.Font.Style := [fsBold];
          Canvas.Font.Color := FColors.TextPrimary;
          Canvas.TextOut(26, CurY + 4, B.CleanText);
          Inc(CurY, 30);
        end;
      vmlParagraph:
        begin
          Canvas.Font.Size := 9;
          Canvas.Font.Style := [];
          Canvas.Font.Color := FColors.TextSecondary;
          Canvas.TextOut(16, CurY, B.CleanText);
          Inc(CurY, 19);
        end;
    end;
  end;
end;

end.
