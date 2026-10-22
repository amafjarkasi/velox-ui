unit Velox.DiffView;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Controls, Graphics, Forms, Types,
  Velox.Types, Velox.Diff;

type
  TVeloxDiffViewMode = (vdvmUnified, vdvmSideBySide);

  TVeloxDiffView = class(TCustomControl)
  private
    FDiffResult: TVeloxDiffResult;
    FViewMode: TVeloxDiffViewMode;
    FLineHeight: Integer;
    FScrollY: Integer;
    FColors: TVeloxThemeColors;
    FAddedBgColor: TColor;
    FDeletedBgColor: TColor;
    FAddedTextColor: TColor;
    FDeletedTextColor: TColor;
    FGutterBgColor: TColor;
    FGutterTextColor: TColor;
    procedure SetViewMode(const Value: TVeloxDiffViewMode);
    procedure SetLineHeight(const Value: Integer);
    function TotalLines: Integer;
    procedure ClampScroll;
  protected
    procedure Paint; override;
    procedure Resize; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);
    procedure SetDiff(const OldText, NewText: string);
    procedure SetDiffLines(const OldLines, NewLines: TStrings);
    property DiffResult: TVeloxDiffResult read FDiffResult;
  published
    property Align;
    property Anchors;
    property ViewMode: TVeloxDiffViewMode read FViewMode write SetViewMode default vdvmUnified;
    property LineHeight: Integer read FLineHeight write SetLineHeight default 20;
    property AddedBgColor: TColor read FAddedBgColor write FAddedBgColor default $1B351E;
    property DeletedBgColor: TColor read FDeletedBgColor write FDeletedBgColor default $1F1836;
    property AddedTextColor: TColor read FAddedTextColor write FAddedTextColor default $99D334;
    property DeletedTextColor: TColor read FDeletedTextColor write FDeletedTextColor default $7171F8;
    property GutterBgColor: TColor read FGutterBgColor write FGutterBgColor default $11151F;
    property GutterTextColor: TColor read FGutterTextColor write FGutterTextColor default $8B7464;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxDiffView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 500;
  Height := 300;
  FLineHeight := 20;
  FScrollY := 0;
  FViewMode := vdvmUnified;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FAddedBgColor := $1B351E;
  FDeletedBgColor := $1F1836;
  FAddedTextColor := $99D334;
  FDeletedTextColor := $7171F8;
  FGutterBgColor := $11151F;
  FGutterTextColor := $8B7464;
end;

procedure TVeloxDiffView.ApplyColors(const AColors: TVeloxThemeColors);
var
  R, G, B: Byte;
  IsLight: Boolean;
begin
  FColors := AColors;
  FGutterBgColor := AColors.Surface;
  FGutterTextColor := AColors.TextSecondary;
  R := AColors.Background and $FF;
  G := (AColors.Background shr 8) and $FF;
  B := (AColors.Background shr 16) and $FF;
  IsLight := (R * 299 + G * 587 + B * 114) > 128000;
  if IsLight then
  begin
    FAddedBgColor := $E7FCDC;
    FDeletedBgColor := $E2E2FE;
    FAddedTextColor := $4AA316;
    FDeletedTextColor := $2626DC;
  end
  else
  begin
    FAddedBgColor := $1B351E;
    FDeletedBgColor := $1F1836;
    FAddedTextColor := $99D334;
    FDeletedTextColor := $7171F8;
  end;
  Invalidate;
end;

procedure TVeloxDiffView.SetViewMode(const Value: TVeloxDiffViewMode);
begin
  if FViewMode <> Value then
  begin
    FViewMode := Value;
    Invalidate;
  end;
end;

procedure TVeloxDiffView.SetLineHeight(const Value: Integer);
begin
  if (FLineHeight <> Value) and (Value >= 14) then
  begin
    FLineHeight := Value;
    Invalidate;
  end;
end;

function TVeloxDiffView.TotalLines: Integer;
begin
  Result := Length(FDiffResult.Lines);
end;

procedure TVeloxDiffView.ClampScroll;
var
  MaxScroll: Integer;
begin
  MaxScroll := TotalLines * FLineHeight - Height;
  if MaxScroll < 0 then MaxScroll := 0;
  if FScrollY > MaxScroll then FScrollY := MaxScroll;
  if FScrollY < 0 then FScrollY := 0;
end;

procedure TVeloxDiffView.SetDiff(const OldText, NewText: string);
begin
  FDiffResult := TVeloxDiff.CompareText(OldText, NewText);
  FScrollY := 0;
  Invalidate;
end;

procedure TVeloxDiffView.SetDiffLines(const OldLines, NewLines: TStrings);
begin
  FDiffResult := TVeloxDiff.CompareLines(OldLines, NewLines);
  FScrollY := 0;
  Invalidate;
end;

function TVeloxDiffView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  Inc(FScrollY, -(WheelDelta div 120) * (FLineHeight * 3));
  ClampScroll;
  Invalidate;
end;

procedure TVeloxDiffView.Resize;
begin
  inherited Resize;
  ClampScroll;
  Invalidate;
end;

procedure TVeloxDiffView.Paint;
var
  I, Y, GutterW, SignW, TotalCount: Integer;
  LineRec: TVeloxDiffLine;
  RowR, OldNumR, NewNumR, SignR, TextR, LocalR: TRect;
  BgCol, TxtCol: TColor;
  OldNumStr, NewNumStr, SignChar: string;
begin
  // Background
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);

  TotalCount := Length(FDiffResult.Lines);
  if TotalCount = 0 then
    Exit;

  GutterW := 40;
  SignW := 20;
  Canvas.Font.Name := 'Consolas';
  Canvas.Font.Size := 9;

  for I := 0 to TotalCount - 1 do
  begin
    Y := (I * FLineHeight) - FScrollY;
    if (Y + FLineHeight < 0) or (Y > Height) then
      Continue;

    LineRec := FDiffResult.Lines[I];

    case LineRec.Op of
      vdoInsert:
        begin
          BgCol := FAddedBgColor;
          TxtCol := FAddedTextColor;
          SignChar := '+';
        end;
      vdoDelete:
        begin
          BgCol := FDeletedBgColor;
          TxtCol := FDeletedTextColor;
          SignChar := '-';
        end;
    else // vdoEqual, vdoModify
      BgCol := FColors.SurfaceCard;
      TxtCol := FColors.TextPrimary;
      SignChar := ' ';
    end;

    RowR := Rect(0, Y, Width, Y + FLineHeight);

    // Row Background fill
    Canvas.Brush.Color := BgCol;
    Canvas.FillRect(RowR);

    // Gutter Background
    Canvas.Brush.Color := FGutterBgColor;
    OldNumR := Rect(0, Y, GutterW, Y + FLineHeight);
    NewNumR := Rect(GutterW, Y, GutterW * 2, Y + FLineHeight);
    Canvas.FillRect(Rect(0, Y, GutterW * 2, Y + FLineHeight));

    // Old line number (aligned right, centered vertically)
    Canvas.Font.Color := FGutterTextColor;
    if LineRec.OldIndex > 0 then
      OldNumStr := IntToStr(LineRec.OldIndex)
    else
      OldNumStr := '';
    LocalR := Rect(OldNumR.Left, OldNumR.Top, OldNumR.Right - 4, OldNumR.Bottom);
    DrawText(Canvas.Handle, PChar(OldNumStr), Length(OldNumStr), LocalR,
      DT_SINGLELINE or DT_RIGHT or DT_VCENTER);

    // New line number (aligned right, centered vertically)
    if LineRec.NewIndex > 0 then
      NewNumStr := IntToStr(LineRec.NewIndex)
    else
      NewNumStr := '';
    LocalR := Rect(NewNumR.Left, NewNumR.Top, NewNumR.Right - 4, NewNumR.Bottom);
    DrawText(Canvas.Handle, PChar(NewNumStr), Length(NewNumStr), LocalR,
      DT_SINGLELINE or DT_RIGHT or DT_VCENTER);

    // Separator line between gutter and code
    Canvas.Pen.Color := FColors.Border;
    Canvas.MoveTo(GutterW * 2, Y);
    Canvas.LineTo(GutterW * 2, Y + FLineHeight);

    // Sign symbol (+ / - / space)
    SignR := Rect(GutterW * 2, Y, GutterW * 2 + SignW, Y + FLineHeight);
    Canvas.Font.Color := TxtCol;
    Canvas.Font.Style := [fsBold];
    LocalR := SignR;
    DrawText(Canvas.Handle, PChar(SignChar), Length(SignChar), LocalR,
      DT_SINGLELINE or DT_CENTER or DT_VCENTER);

    // Code text (exact vertical center, single line, left aligned with margin)
    Canvas.Font.Style := [];
    TextR := Rect(GutterW * 2 + SignW + 4, Y, Width, Y + FLineHeight);
    LocalR := TextR;
    DrawText(Canvas.Handle, PChar(LineRec.Text), Length(LineRec.Text), LocalR,
      DT_SINGLELINE or DT_LEFT or DT_VCENTER);
  end;
end;

end.
