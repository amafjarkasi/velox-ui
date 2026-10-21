unit Velox.Pagination;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Controls, Graphics, Forms, Types, Math,
  Velox.Types;

type
  TVeloxPageChangeEvent = procedure(Sender: TObject; const NewPage: Integer) of object;

  TVeloxPageButtonKind = (vpbFirst, vpbPrev, vpbNumber, vpbNext, vpbLast, vpbEllipsis);

  TVeloxPageButton = record
    Kind: TVeloxPageButtonKind;
    PageNum: Integer;
    Caption: string;
    Bounds: TRect;
    IsActive: Boolean;
  end;

  TVeloxPagination = class(TCustomControl)
  private
    FCurrentPage: Integer;
    FTotalPages: Integer;
    FTotalItems: Integer;
    FPageSize: Integer;
    FButtonSize: Integer;
    FShowSummary: Boolean;
    FHotButtonIndex: Integer;
    FColors: TVeloxThemeColors;
    FButtons: array of TVeloxPageButton;
    FOnPageChange: TVeloxPageChangeEvent;
    procedure SetCurrentPage(const Value: Integer);
    procedure SetTotalPages(const Value: Integer);
    procedure SetTotalItems(const Value: Integer);
    procedure SetPageSize(const Value: Integer);
    procedure RecalcButtons;
    function HitTestButton(X, Y: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    function NextPage: Boolean;
    function PrevPage: Boolean;
    function FirstPage: Boolean;
    function LastPage: Boolean;
  published
    property Align;
    property Anchors;
    property CurrentPage: Integer read FCurrentPage write SetCurrentPage default 1;
    property TotalPages: Integer read FTotalPages write SetTotalPages default 1;
    property TotalItems: Integer read FTotalItems write SetTotalItems default 0;
    property PageSize: Integer read FPageSize write SetPageSize default 20;
    property ButtonSize: Integer read FButtonSize write FButtonSize default 28;
    property ShowSummary: Boolean read FShowSummary write FShowSummary default True;
    property OnPageChange: TVeloxPageChangeEvent read FOnPageChange write FOnPageChange;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxPagination.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 460;
  Height := 36;
  FCurrentPage := 1;
  FTotalPages := 1;
  FTotalItems := 0;
  FPageSize := 20;
  FButtonSize := 28;
  FShowSummary := True;
  FHotButtonIndex := -1;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  RecalcButtons;
end;

procedure TVeloxPagination.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxPagination.SetCurrentPage(const Value: Integer);
var
  Clamped: Integer;
begin
  Clamped := Value;
  if Clamped < 1 then Clamped := 1;
  if (FTotalPages > 0) and (Clamped > FTotalPages) then Clamped := FTotalPages;

  if FCurrentPage <> Clamped then
  begin
    FCurrentPage := Clamped;
    RecalcButtons;
    Invalidate;
    if Assigned(FOnPageChange) then
      FOnPageChange(Self, FCurrentPage);
  end;
end;

procedure TVeloxPagination.SetTotalPages(const Value: Integer);
var
  Val: Integer;
begin
  Val := Value;
  if Val < 1 then Val := 1;
  if FTotalPages <> Val then
  begin
    FTotalPages := Val;
    if FCurrentPage > FTotalPages then
      FCurrentPage := FTotalPages;
    RecalcButtons;
    Invalidate;
  end;
end;

procedure TVeloxPagination.SetTotalItems(const Value: Integer);
begin
  if FTotalItems <> Value then
  begin
    FTotalItems := Value;
    if (FTotalItems > 0) and (FPageSize > 0) then
      SetTotalPages((FTotalItems + FPageSize - 1) div FPageSize);
  end;
end;

procedure TVeloxPagination.SetPageSize(const Value: Integer);
begin
  if (FPageSize <> Value) and (Value > 0) then
  begin
    FPageSize := Value;
    if FTotalItems > 0 then
      SetTotalPages((FTotalItems + FPageSize - 1) div FPageSize);
  end;
end;

function TVeloxPagination.NextPage: Boolean;
begin
  if FCurrentPage < FTotalPages then
  begin
    CurrentPage := FCurrentPage + 1;
    Result := True;
  end
  else
    Result := False;
end;

function TVeloxPagination.PrevPage: Boolean;
begin
  if FCurrentPage > 1 then
  begin
    CurrentPage := FCurrentPage - 1;
    Result := True;
  end
  else
    Result := False;
end;

function TVeloxPagination.FirstPage: Boolean;
begin
  if FCurrentPage <> 1 then
  begin
    CurrentPage := 1;
    Result := True;
  end
  else
    Result := False;
end;

function TVeloxPagination.LastPage: Boolean;
begin
  if FCurrentPage <> FTotalPages then
  begin
    CurrentPage := FTotalPages;
    Result := True;
  end
  else
    Result := False;
end;

procedure TVeloxPagination.RecalcButtons;
var
  BtnCount, CurX, BtnY, P: Integer;

  procedure AddBtn(AKind: TVeloxPageButtonKind; APage: Integer; const ACap: string; AActive: Boolean = False);
  var
    W: Integer;
  begin
    Inc(BtnCount);
    SetLength(FButtons, BtnCount);
    FButtons[BtnCount - 1].Kind := AKind;
    FButtons[BtnCount - 1].PageNum := APage;
    FButtons[BtnCount - 1].Caption := ACap;
    FButtons[BtnCount - 1].IsActive := AActive;

    if Length(ACap) > 2 then
      W := FButtonSize + 8
    else
      W := FButtonSize;

    FButtons[BtnCount - 1].Bounds := Rect(CurX, BtnY, CurX + W, BtnY + FButtonSize);
    Inc(CurX, W + 4);
  end;

begin
  BtnCount := 0;
  SetLength(FButtons, 0);

  BtnY := (Height - FButtonSize) div 2;
  if BtnY < 2 then BtnY := 2;
  CurX := Width - 4; // We calculate total buttons then position right-aligned

  // First & Prev
  // Add: First, Prev, Pages, Next, Last
  CurX := Width - 240;
  if CurX < 120 then CurX := 120;

  AddBtn(vpbFirst, 1, '<<');
  AddBtn(vpbPrev, Max(1, FCurrentPage - 1), '<');

  // Pages around current page (e.g. Current-1, Current, Current+1)
  for P := Max(1, FCurrentPage - 2) to Min(FTotalPages, FCurrentPage + 2) do
    AddBtn(vpbNumber, P, IntToStr(P), P = FCurrentPage);

  AddBtn(vpbNext, Min(FTotalPages, FCurrentPage + 1), '>');
  AddBtn(vpbLast, FTotalPages, '>>');
end;

function TVeloxPagination.HitTestButton(X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FButtons) do
  begin
    if PtInRect(FButtons[I].Bounds, Point(X, Y)) then
      Exit(I);
  end;
end;

procedure TVeloxPagination.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Hit: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    Hit := HitTestButton(X, Y);
    if Hit >= 0 then
    begin
      case FButtons[Hit].Kind of
        vpbFirst: FirstPage;
        vpbPrev:  PrevPage;
        vpbNext:  NextPage;
        vpbLast:  LastPage;
        vpbNumber: CurrentPage := FButtons[Hit].PageNum;
      end;
    end;
  end;
end;

procedure TVeloxPagination.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Hit: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  Hit := HitTestButton(X, Y);
  if Hit <> FHotButtonIndex then
  begin
    FHotButtonIndex := Hit;
    Invalidate;
  end;
end;

procedure TVeloxPagination.MouseLeave;
begin
  inherited MouseLeave;
  if FHotButtonIndex <> -1 then
  begin
    FHotButtonIndex := -1;
    Invalidate;
  end;
end;

procedure TVeloxPagination.Resize;
begin
  inherited Resize;
  RecalcButtons;
  Invalidate;
end;

procedure TVeloxPagination.Paint;
var
  I, StartIdx, EndIdx: Integer;
  R, SummaryR, LocalR: TRect;
  SummaryText: string;
begin
  // Background
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);

  // 1. Summary Label on Left (exact vertical center)
  if FShowSummary and (FTotalItems > 0) then
  begin
    StartIdx := (FCurrentPage - 1) * FPageSize + 1;
    EndIdx   := Min(FCurrentPage * FPageSize, FTotalItems);
    SummaryText := Format('Showing %d-%d of %d items', [StartIdx, EndIdx, FTotalItems]);

    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [];
    Canvas.Font.Color := FColors.TextSecondary;

    SummaryR := Rect(8, 0, Width - 250, Height);
    LocalR := SummaryR;
    DrawText(Canvas.Handle, PChar(SummaryText), Length(SummaryText), LocalR,
      DT_SINGLELINE or DT_LEFT or DT_VCENTER);
  end;

  // 2. Buttons
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;

  for I := 0 to High(FButtons) do
  begin
    R := FButtons[I].Bounds;

    if FButtons[I].IsActive then
    begin
      Canvas.Brush.Color := FColors.Accent;
      Canvas.Pen.Color := FColors.Accent;
      Canvas.Font.Style := [fsBold];
      Canvas.Font.Color := $0B0F19; // Dark text on accent
    end
    else
    begin
      if I = FHotButtonIndex then
        Canvas.Brush.Color := FColors.SurfaceCard
      else
        Canvas.Brush.Color := FColors.Background;
      Canvas.Pen.Color := FColors.Border;
      Canvas.Font.Style := [];
      Canvas.Font.Color := FColors.TextPrimary;
    end;

    Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 6, 6);

    LocalR := R;
    DrawText(Canvas.Handle, PChar(FButtons[I].Caption), Length(FButtons[I].Caption), LocalR,
      DT_SINGLELINE or DT_CENTER or DT_VCENTER);
  end;
end;

end.
