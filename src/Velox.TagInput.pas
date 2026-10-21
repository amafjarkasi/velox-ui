unit Velox.TagInput;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Controls, StdCtrls, Graphics, Forms, Types,
  Velox.Types;

type
  TVeloxTagEvent = procedure(Sender: TObject; const ATag: string) of object;

  TVeloxTagPill = record
    Text: string;
    Bounds: TRect;
    CloseBounds: TRect;
  end;

  TVeloxTagInput = class(TCustomControl)
  private
    FTags: TStringList;
    FEdit: TEdit;
    FColors: TVeloxThemeColors;
    FAllowDuplicates: Boolean;
    FPills: array of TVeloxTagPill;
    FHotCloseIndex: Integer;
    FPillBgColor: TColor;
    FPillTextColor: TColor;
    FPillBorderColor: TColor;
    FOnTagAdded: TVeloxTagEvent;
    FOnTagRemoved: TVeloxTagEvent;
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditKeyPress(Sender: TObject; var Key: Char);
    procedure RecalcLayout;
    function HitTestClose(X, Y: Integer): Integer;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    function AddTag(const ATag: string): Boolean;
    function RemoveTag(const AIndex: Integer): Boolean; overload;
    function RemoveTag(const ATag: string): Boolean; overload;
    procedure Clear;
    function TagCount: Integer;

    property Tags: TStringList read FTags;
    property AllowDuplicates: Boolean read FAllowDuplicates write FAllowDuplicates default False;
    property PillBgColor: TColor read FPillBgColor write FPillBgColor default $1E293B;
    property PillTextColor: TColor read FPillTextColor write FPillTextColor default $F8FAFC;
    property PillBorderColor: TColor read FPillBorderColor write FPillBorderColor default $38BDF8;
    property OnTagAdded: TVeloxTagEvent read FOnTagAdded write FOnTagAdded;
    property OnTagRemoved: TVeloxTagEvent read FOnTagRemoved write FOnTagRemoved;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxTagInput.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  FAllowDuplicates := False;
  FHotCloseIndex := -1;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FPillBgColor := $1E293B;
  FPillTextColor := $F8FAFC;
  FPillBorderColor := $38BDF8;
  FTags := TStringList.Create;
  SetLength(FPills, 0);

  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.BorderStyle := bsNone;
  FEdit.AutoSize := False;
  FEdit.Color := FColors.SurfaceCard;
  FEdit.Font.Name := 'Segoe UI';
  FEdit.Font.Size := 9;
  FEdit.Font.Color := FColors.TextPrimary;
  FEdit.OnKeyDown := EditKeyDown;
  FEdit.OnKeyPress := EditKeyPress;

  Width := 380;
  Height := 36;
  RecalcLayout;
end;

destructor TVeloxTagInput.Destroy;
begin
  FTags.Free;
  inherited Destroy;
end;

procedure TVeloxTagInput.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  FEdit.Color := FColors.SurfaceCard;
  FEdit.Font.Color := FColors.TextPrimary;
  Invalidate;
end;

procedure TVeloxTagInput.Clear;
begin
  FTags.Clear;
  RecalcLayout;
  Invalidate;
end;

function TVeloxTagInput.TagCount: Integer;
begin
  Result := FTags.Count;
end;

function TVeloxTagInput.AddTag(const ATag: string): Boolean;
var
  T: string;
begin
  T := Trim(ATag);
  if T = '' then Exit(False);

  if (not FAllowDuplicates) and (FTags.IndexOf(T) >= 0) then
    Exit(False);

  FTags.Add(T);
  RecalcLayout;
  Invalidate;
  if Assigned(FOnTagAdded) then
    FOnTagAdded(Self, T);
  Result := True;
end;

function TVeloxTagInput.RemoveTag(const AIndex: Integer): Boolean;
var
  T: string;
begin
  if (AIndex >= 0) and (AIndex < FTags.Count) then
  begin
    T := FTags[AIndex];
    FTags.Delete(AIndex);
    RecalcLayout;
    Invalidate;
    if Assigned(FOnTagRemoved) then
      FOnTagRemoved(Self, T);
    Result := True;
  end
  else
    Result := False;
end;

function TVeloxTagInput.RemoveTag(const ATag: string): Boolean;
var
  Idx: Integer;
begin
  Idx := FTags.IndexOf(ATag);
  if Idx >= 0 then
    Result := RemoveTag(Idx)
  else
    Result := False;
end;

procedure TVeloxTagInput.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_BACK) and (FEdit.Text = '') and (FTags.Count > 0) then
  begin
    RemoveTag(FTags.Count - 1);
    Key := 0;
  end
  else if (Key = VK_RETURN) and (Trim(FEdit.Text) <> '') then
  begin
    AddTag(FEdit.Text);
    FEdit.Text := '';
    Key := 0;
  end;
end;

procedure TVeloxTagInput.EditKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key = ',') or (Key = ';') then
  begin
    if Trim(FEdit.Text) <> '' then
      AddTag(FEdit.Text);
    FEdit.Text := '';
    Key := #0;
  end;
end;

procedure TVeloxTagInput.RecalcLayout;
var
  I, CurX, PillW, PillH, PillY: Integer;
  TextW: Integer;
begin
  if (not Assigned(FEdit)) or (not Assigned(FTags)) then Exit;

  CurX := 6;
  PillH := 24;
  PillY := (Height - PillH) div 2;
  if PillY < 2 then PillY := 2;

  SetLength(FPills, FTags.Count);

  for I := 0 to FTags.Count - 1 do
  begin
    TextW := Length(FTags[I]) * 7;
    PillW := TextW + 28; // Text + padding + 'x' button
    FPills[I].Text := FTags[I];
    FPills[I].Bounds := Rect(CurX, PillY, CurX + PillW, PillY + PillH);
    FPills[I].CloseBounds := Rect(CurX + PillW - 18, PillY + 4, CurX + PillW - 4, PillY + PillH - 4);
    Inc(CurX, PillW + 6);
  end;

  // Position inner TEdit to the right of the last pill
  if CurX > Width - 60 then
    CurX := Width - 60;
  if CurX < 6 then
    CurX := 6;

  FEdit.SetBounds(CurX, (Height - 18) div 2, Width - CurX - 6, 18);
end;

procedure TVeloxTagInput.Resize;
begin
  inherited Resize;
  RecalcLayout;
  Invalidate;
end;

function TVeloxTagInput.HitTestClose(X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FPills) do
  begin
    if PtInRect(FPills[I].CloseBounds, Point(X, Y)) then
      Exit(I);
  end;
end;

procedure TVeloxTagInput.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Hit: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    Hit := HitTestClose(X, Y);
    if Hit >= 0 then
      RemoveTag(Hit)
    else
      FEdit.SetFocus;
  end;
end;

procedure TVeloxTagInput.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Hit: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  Hit := HitTestClose(X, Y);
  if Hit <> FHotCloseIndex then
  begin
    FHotCloseIndex := Hit;
    Invalidate;
  end;
end;

procedure TVeloxTagInput.MouseLeave;
begin
  inherited MouseLeave;
  if FHotCloseIndex <> -1 then
  begin
    FHotCloseIndex := -1;
    Invalidate;
  end;
end;

procedure TVeloxTagInput.Paint;
var
  I: Integer;
  R, TextR, CloseR, LocalR: TRect;
  CloseChar: string;
begin
  // Background card with border
  Canvas.Brush.Color := FColors.SurfaceCard;
  Canvas.Pen.Color := FColors.Border;
  Canvas.Rectangle(0, 0, Width, Height);

  Canvas.Font.Name := 'Segoe UI';

  // Render Pill Badges
  for I := 0 to High(FPills) do
  begin
    R := FPills[I].Bounds;

    // Pill background & outline
    Canvas.Brush.Color := FPillBgColor;
    Canvas.Pen.Color := FPillBorderColor;
    Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 10, 10);

    // Pill text (exact vertical center, single line)
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [];
    Canvas.Font.Color := FPillTextColor;
    TextR := Rect(R.Left + 8, R.Top, R.Right - 18, R.Bottom);
    LocalR := TextR;
    DrawText(Canvas.Handle, PChar(FPills[I].Text), Length(FPills[I].Text), LocalR,
      DT_SINGLELINE or DT_LEFT or DT_VCENTER);

    // Close 'x' button (vertically centered)
    CloseR := FPills[I].CloseBounds;
    if I = FHotCloseIndex then
      Canvas.Font.Color := $EF4444 // Red hover
    else
      Canvas.Font.Color := FColors.TextSecondary;

    Canvas.Font.Style := [fsBold];
    CloseChar := 'x';
    LocalR := CloseR;
    DrawText(Canvas.Handle, PChar(CloseChar), Length(CloseChar), LocalR,
      DT_SINGLELINE or DT_CENTER or DT_VCENTER);
  end;
end;

end.
