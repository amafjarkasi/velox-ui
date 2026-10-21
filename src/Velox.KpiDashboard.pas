unit Velox.KpiDashboard;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Controls, Graphics, Forms, Types, Math,
  Velox.Types;

type
  TVeloxKpiCard = record
    Key: string;
    Title: string;
    ValueStr: string;
    UnitStr: string;
    DeltaStr: string;
    DeltaIsPositive: Boolean;
    History: array of Single;
  end;

  TVeloxKpiGrid = class(TCustomControl)
  private
    FCards: array of TVeloxKpiCard;
    FColors: TVeloxThemeColors;
    FMinCardWidth: Integer;
    FCardHeight: Integer;
    FCardGap: Integer;
    FScrollY: Integer;
    function FindCardIndex(const AKey: string): Integer;
    procedure DrawCard(const AIndex: Integer; const ARect: TRect);
    procedure DrawSparkline(const AHistory: array of Single; const ARect: TRect; const AColor: TColor);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    function AddCard(const AKey, ATitle, AValueStr, AUnitStr, ADeltaStr: string;
      const ADeltaPositive: Boolean = True): Integer;
    procedure UpdateCard(const AKey, AValueStr, ADeltaStr: string;
      const ADeltaPositive: Boolean; const ANewSample: Single = 0.0);
    procedure Clear;
    function CardCount: Integer;
  published
    property Align;
    property Anchors;
    property MinCardWidth: Integer read FMinCardWidth write FMinCardWidth default 200;
    property CardHeight: Integer read FCardHeight write FCardHeight default 110;
    property CardGap: Integer read FCardGap write FCardGap default 12;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxKpiGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 640;
  Height := 260;
  FMinCardWidth := 200;
  FCardHeight := 110;
  FCardGap := 12;
  FScrollY := 0;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  SetLength(FCards, 0);
end;

procedure TVeloxKpiGrid.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxKpiGrid.Clear;
begin
  SetLength(FCards, 0);
  Invalidate;
end;

function TVeloxKpiGrid.CardCount: Integer;
begin
  Result := Length(FCards);
end;

function TVeloxKpiGrid.FindCardIndex(const AKey: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FCards) do
    if SameText(FCards[I].Key, AKey) then
      Exit(I);
end;

function TVeloxKpiGrid.AddCard(const AKey, ATitle, AValueStr, AUnitStr, ADeltaStr: string;
  const ADeltaPositive: Boolean): Integer;
var
  Idx, L: Integer;
begin
  Idx := FindCardIndex(AKey);
  if Idx >= 0 then
    Exit(Idx);

  L := Length(FCards);
  SetLength(FCards, L + 1);
  FCards[L].Key := AKey;
  FCards[L].Title := ATitle;
  FCards[L].ValueStr := AValueStr;
  FCards[L].UnitStr := AUnitStr;
  FCards[L].DeltaStr := ADeltaStr;
  FCards[L].DeltaIsPositive := ADeltaPositive;
  SetLength(FCards[L].History, 0);

  Invalidate;
  Result := L;
end;

procedure TVeloxKpiGrid.UpdateCard(const AKey, AValueStr, ADeltaStr: string;
  const ADeltaPositive: Boolean; const ANewSample: Single);
var
  Idx, HL: Integer;
begin
  Idx := FindCardIndex(AKey);
  if Idx < 0 then Exit;

  FCards[Idx].ValueStr := AValueStr;
  FCards[Idx].DeltaStr := ADeltaStr;
  FCards[Idx].DeltaIsPositive := ADeltaPositive;

  if ANewSample <> 0.0 then
  begin
    HL := Length(FCards[Idx].History);
    SetLength(FCards[Idx].History, HL + 1);
    FCards[Idx].History[HL] := ANewSample;
    if Length(FCards[Idx].History) > 30 then
    begin
      // Keep trailing 30 samples
      Move(FCards[Idx].History[1], FCards[Idx].History[0], 29 * SizeOf(Single));
      SetLength(FCards[Idx].History, 29);
    end;
  end;

  Invalidate;
end;

procedure TVeloxKpiGrid.Resize;
begin
  inherited Resize;
  Invalidate;
end;

procedure TVeloxKpiGrid.DrawSparkline(const AHistory: array of Single; const ARect: TRect; const AColor: TColor);
var
  I, N, X, Y: Integer;
  MinV, MaxV, RangeV: Single;
begin
  N := Length(AHistory);
  if N < 2 then Exit;

  MinV := AHistory[0];
  MaxV := AHistory[0];
  for I := 1 to N - 1 do
  begin
    if AHistory[I] < MinV then MinV := AHistory[I];
    if AHistory[I] > MaxV then MaxV := AHistory[I];
  end;
  RangeV := MaxV - MinV;
  if RangeV = 0 then RangeV := 1.0;

  Canvas.Pen.Color := AColor;
  Canvas.Pen.Width := 2;

  for I := 0 to N - 1 do
  begin
    X := ARect.Left + (I * (ARect.Right - ARect.Left)) div (N - 1);
    Y := ARect.Bottom - Round(((AHistory[I] - MinV) / RangeV) * (ARect.Bottom - ARect.Top));
    if I = 0 then
      Canvas.MoveTo(X, Y)
    else
      Canvas.LineTo(X, Y);
  end;
end;

procedure TVeloxKpiGrid.DrawCard(const AIndex: Integer; const ARect: TRect);
var
  TitleR, ValR, DeltaR, SparkR, LocalR: TRect;
  ValStr, DeltaText: string;
  DeltaCol, SparkCol: TColor;
begin
  // Card background
  Canvas.Brush.Color := FColors.SurfaceCard;
  Canvas.Pen.Color := FColors.Border;
  Canvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, 12, 12);

  // 1. Title (Top left, exact vertical center in header band)
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := FColors.TextSecondary;
  TitleR := Rect(ARect.Left + 12, ARect.Top + 8, ARect.Right - 12, ARect.Top + 24);
  LocalR := TitleR;
  DrawText(Canvas.Handle, PChar(FCards[AIndex].Title), Length(FCards[AIndex].Title), LocalR,
    DT_SINGLELINE or DT_LEFT or DT_VCENTER);

  // 2. Large Value + Unit (Middle band, vertically centered)
  Canvas.Font.Size := 16;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := FColors.TextPrimary;
  if FCards[AIndex].UnitStr <> '' then
    ValStr := FCards[AIndex].ValueStr + ' ' + FCards[AIndex].UnitStr
  else
    ValStr := FCards[AIndex].ValueStr;

  ValR := Rect(ARect.Left + 12, ARect.Top + 28, ARect.Right - 70, ARect.Top + 62);
  LocalR := ValR;
  DrawText(Canvas.Handle, PChar(ValStr), Length(ValStr), LocalR,
    DT_SINGLELINE or DT_LEFT or DT_VCENTER);

  // 3. Delta Badge (Pill box on right of value)
  if FCards[AIndex].DeltaStr <> '' then
  begin
    if FCards[AIndex].DeltaIsPositive then
    begin
      DeltaCol := $10B981; // Green
      SparkCol := $10B981;
    end
    else
    begin
      DeltaCol := $EF4444; // Red
      SparkCol := $EF4444;
    end;

    DeltaR := Rect(ARect.Right - 64, ARect.Top + 34, ARect.Right - 12, ARect.Top + 54);
    Canvas.Brush.Color := FColors.Background;
    Canvas.Pen.Color := DeltaCol;
    Canvas.RoundRect(DeltaR.Left, DeltaR.Top, DeltaR.Right, DeltaR.Bottom, 6, 6);

    Canvas.Font.Size := 8;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := DeltaCol;
    DeltaText := FCards[AIndex].DeltaStr;
    LocalR := DeltaR;
    DrawText(Canvas.Handle, PChar(DeltaText), Length(DeltaText), LocalR,
      DT_SINGLELINE or DT_CENTER or DT_VCENTER);
  end
  else
    SparkCol := FColors.Accent;

  // 4. Sparkline at bottom
  if Length(FCards[AIndex].History) >= 2 then
  begin
    SparkR := Rect(ARect.Left + 12, ARect.Bottom - 30, ARect.Right - 12, ARect.Bottom - 10);
    DrawSparkline(FCards[AIndex].History, SparkR, SparkCol);
  end;
end;

procedure TVeloxKpiGrid.Paint;
var
  TotalCards, Cols, ColW, TotalRows: Integer;
  I, Row, Col, X, Y: Integer;
  CardR: TRect;
begin
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);

  TotalCards := Length(FCards);
  if TotalCards = 0 then Exit;

  // Auto-flow layout math
  Cols := (Width - FCardGap) div (FMinCardWidth + FCardGap);
  if Cols < 1 then Cols := 1;

  ColW := (Width - (FCardGap * (Cols + 1))) div Cols;
  TotalRows := (TotalCards + Cols - 1) div Cols;

  for I := 0 to TotalCards - 1 do
  begin
    Row := I div Cols;
    Col := I mod Cols;

    X := FCardGap + Col * (ColW + FCardGap);
    Y := FCardGap + Row * (FCardHeight + FCardGap) - FScrollY;

    if (Y + FCardHeight >= 0) and (Y <= Height) then
    begin
      CardR := Rect(X, Y, X + ColW, Y + FCardHeight);
      DrawCard(I, CardR);
    end;
  end;
end;

end.
