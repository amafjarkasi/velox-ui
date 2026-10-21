unit Velox.Stepper;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Controls, Graphics, Forms, Types;

type
  TVeloxStepState = (vssPending, vssActive, vssCompleted, vssError);

  TVeloxStepItem = class(TCollectionItem)
  private
    FTitle: string;
    FSubtitle: string;
    FState: TVeloxStepState;
    procedure SetTitle(const Value: string);
    procedure SetSubtitle(const Value: string);
    procedure SetState(const Value: TVeloxStepState);
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Title: string read FTitle write SetTitle;
    property Subtitle: string read FSubtitle write SetSubtitle;
    property State: TVeloxStepState read FState write SetState;
  end;

  TVeloxStepItems = class(TCollection)
  private
    FOwnerControl: TCustomControl;
    function GetItem(Index: Integer): TVeloxStepItem;
    procedure SetItem(Index: Integer; Value: TVeloxStepItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(AOwner: TCustomControl);
    function Add(const ATitle: string = ''; const ASubtitle: string = ''): TVeloxStepItem;
    property Items[Index: Integer]: TVeloxStepItem read GetItem write SetItem; default;
  end;

  TVeloxStepChangeEvent = procedure(Sender: TObject; NewIndex: Integer) of object;

  TVeloxStepper = class(TCustomControl)
  private
    FSteps: TVeloxStepItems;
    FActiveStepIndex: Integer;
    FHoveredStepIndex: Integer;
    FCircleRadius: Integer;
    FBackgroundColor: TColor;
    FTrackColor: TColor;
    FCompletedColor: TColor;
    FActiveColor: TColor;
    FErrorColor: TColor;
    FPendingColor: TColor;
    FTextColor: TColor;
    FSubtextColor: TColor;
    FOnChange: TVeloxStepChangeEvent;
    procedure SetActiveStepIndex(const Value: Integer);
    procedure SetSteps(const Value: TVeloxStepItems);
    procedure SetCircleRadius(const Value: Integer);
    function GetStepState(Index: Integer): TVeloxStepState;
    procedure SetStepState(Index: Integer; const Value: TVeloxStepState);
    function GetStepRect(Index: Integer): TRect;
    function GetCircleCenter(Index: Integer): TPoint;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddStep(const ATitle: string; const ASubtitle: string = ''): TVeloxStepItem;
    function NextStep: Boolean;
    function PrevStep: Boolean;
    function HitTest(X, Y: Integer): Integer;
    property StepState[Index: Integer]: TVeloxStepState read GetStepState write SetStepState;
  published
    property Align;
    property Anchors;
    property ActiveStepIndex: Integer read FActiveStepIndex write SetActiveStepIndex default 0;
    property Steps: TVeloxStepItems read FSteps write SetSteps;
    property CircleRadius: Integer read FCircleRadius write SetCircleRadius default 16;
    property BackgroundColor: TColor read FBackgroundColor write FBackgroundColor default $161922;
    property TrackColor: TColor read FTrackColor write FTrackColor default $334155;
    property CompletedColor: TColor read FCompletedColor write FCompletedColor default $10B981;
    property ActiveColor: TColor read FActiveColor write FActiveColor default $38BDF8;
    property ErrorColor: TColor read FErrorColor write FErrorColor default $EF4444;
    property PendingColor: TColor read FPendingColor write FPendingColor default $475569;
    property TextColor: TColor read FTextColor write FTextColor default $F8FAFC;
    property SubtextColor: TColor read FSubtextColor write FSubtextColor default $94A3B8;
    property OnChange: TVeloxStepChangeEvent read FOnChange write FOnChange;
    property Visible;
    property Enabled;
  end;

implementation

{ TVeloxStepItem }

constructor TVeloxStepItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FState := vssPending;
end;

procedure TVeloxStepItem.Assign(Source: TPersistent);
begin
  if Source is TVeloxStepItem then
  begin
    FTitle := TVeloxStepItem(Source).FTitle;
    FSubtitle := TVeloxStepItem(Source).FSubtitle;
    FState := TVeloxStepItem(Source).FState;
    Changed(False);
  end
  else
    inherited Assign(Source);
end;

procedure TVeloxStepItem.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Changed(False);
  end;
end;

procedure TVeloxStepItem.SetSubtitle(const Value: string);
begin
  if FSubtitle <> Value then
  begin
    FSubtitle := Value;
    Changed(False);
  end;
end;

procedure TVeloxStepItem.SetState(const Value: TVeloxStepState);
begin
  if FState <> Value then
  begin
    FState := Value;
    Changed(False);
  end;
end;

{ TVeloxStepItems }

constructor TVeloxStepItems.Create(AOwner: TCustomControl);
begin
  inherited Create(TVeloxStepItem);
  FOwnerControl := AOwner;
end;

function TVeloxStepItems.GetItem(Index: Integer): TVeloxStepItem;
begin
  Result := TVeloxStepItem(inherited GetItem(Index));
end;

procedure TVeloxStepItems.SetItem(Index: Integer; Value: TVeloxStepItem);
begin
  inherited SetItem(Index, Value);
end;

function TVeloxStepItems.Add(const ATitle, ASubtitle: string): TVeloxStepItem;
begin
  Result := TVeloxStepItem(inherited Add);
  Result.Title := ATitle;
  Result.Subtitle := ASubtitle;
end;

procedure TVeloxStepItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Assigned(FOwnerControl) then
    FOwnerControl.Invalidate;
end;

{ TVeloxStepper }

constructor TVeloxStepper.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 480;
  Height := 80;
  FCircleRadius := 16;
  FActiveStepIndex := 0;
  FHoveredStepIndex := -1;
  FBackgroundColor := $161922;
  FTrackColor := $334155;
  FCompletedColor := $10B981;
  FActiveColor := $38BDF8;
  FErrorColor := $EF4444;
  FPendingColor := $475569;
  FTextColor := $F8FAFC;
  FSubtextColor := $94A3B8;
  FSteps := TVeloxStepItems.Create(Self);
end;

destructor TVeloxStepper.Destroy;
begin
  FSteps.Free;
  inherited Destroy;
end;

function TVeloxStepper.AddStep(const ATitle: string; const ASubtitle: string): TVeloxStepItem;
begin
  Result := FSteps.Add(ATitle, ASubtitle);
  if FSteps.Count = 1 then
    Result.State := vssActive;
  Invalidate;
end;

function TVeloxStepper.GetStepState(Index: Integer): TVeloxStepState;
begin
  if (Index >= 0) and (Index < FSteps.Count) then
    Result := FSteps[Index].State
  else
    Result := vssPending;
end;

procedure TVeloxStepper.SetStepState(Index: Integer; const Value: TVeloxStepState);
begin
  if (Index >= 0) and (Index < FSteps.Count) then
  begin
    FSteps[Index].State := Value;
    Invalidate;
  end;
end;

procedure TVeloxStepper.SetActiveStepIndex(const Value: Integer);
var
  I: Integer;
begin
  if (FActiveStepIndex <> Value) and (Value >= 0) and (Value < FSteps.Count) then
  begin
    FActiveStepIndex := Value;
    for I := 0 to FSteps.Count - 1 do
    begin
      if I < FActiveStepIndex then
      begin
        if FSteps[I].State <> vssError then
          FSteps[I].State := vssCompleted;
      end
      else if I = FActiveStepIndex then
        FSteps[I].State := vssActive
      else
      begin
        if FSteps[I].State <> vssError then
          FSteps[I].State := vssPending;
      end;
    end;
    Invalidate;
    if Assigned(FOnChange) then
      FOnChange(Self, FActiveStepIndex);
  end;
end;

function TVeloxStepper.NextStep: Boolean;
begin
  if FActiveStepIndex < FSteps.Count - 1 then
  begin
    ActiveStepIndex := FActiveStepIndex + 1;
    Result := True;
  end
  else
    Result := False;
end;

function TVeloxStepper.PrevStep: Boolean;
begin
  if FActiveStepIndex > 0 then
  begin
    ActiveStepIndex := FActiveStepIndex - 1;
    Result := True;
  end
  else
    Result := False;
end;

procedure TVeloxStepper.SetSteps(const Value: TVeloxStepItems);
begin
  FSteps.Assign(Value);
  Invalidate;
end;

procedure TVeloxStepper.SetCircleRadius(const Value: Integer);
begin
  if FCircleRadius <> Value then
  begin
    FCircleRadius := Value;
    Invalidate;
  end;
end;

function TVeloxStepper.GetCircleCenter(Index: Integer): TPoint;
var
  StepWidth: Integer;
begin
  if (FSteps.Count <= 1) or (Index < 0) or (Index >= FSteps.Count) then
  begin
    Result.X := Width div 2;
    Result.Y := FCircleRadius + 8;
    Exit;
  end;

  StepWidth := (Width - (FCircleRadius * 2 + 32)) div (FSteps.Count - 1);
  Result.X := (FCircleRadius + 16) + (Index * StepWidth);
  Result.Y := FCircleRadius + 8;
end;

function TVeloxStepper.GetStepRect(Index: Integer): TRect;
var
  Center: TPoint;
  StepWidth: Integer;
begin
  Center := GetCircleCenter(Index);
  if FSteps.Count <= 1 then
    StepWidth := Width
  else
    StepWidth := (Width - 32) div FSteps.Count;

  Result.Left := Center.X - (StepWidth div 2);
  Result.Right := Center.X + (StepWidth div 2);
  Result.Top := 0;
  Result.Bottom := Height;
end;

function TVeloxStepper.HitTest(X, Y: Integer): Integer;
var
  I: Integer;
  R: TRect;
begin
  Result := -1;
  for I := 0 to FSteps.Count - 1 do
  begin
    R := GetStepRect(I);
    if PtInRect(R, Point(X, Y)) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure TVeloxStepper.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Hit: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    Hit := HitTest(X, Y);
    if Hit >= 0 then
      ActiveStepIndex := Hit;
  end;
end;

procedure TVeloxStepper.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Hit: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  Hit := HitTest(X, Y);
  if Hit <> FHoveredStepIndex then
  begin
    FHoveredStepIndex := Hit;
    Invalidate;
  end;
end;

procedure TVeloxStepper.MouseLeave;
begin
  inherited MouseLeave;
  if FHoveredStepIndex <> -1 then
  begin
    FHoveredStepIndex := -1;
    Invalidate;
  end;
end;

procedure TVeloxStepper.Resize;
begin
  inherited Resize;
  Invalidate;
end;

procedure TVeloxStepper.Paint;
var
  I: Integer;
  Pt1, Pt2: TPoint;
  FillCol, BorderCol, TextCol: TColor;
  StepNumStr: string;
  R: TRect;
begin
  // Background
  Canvas.Brush.Color := FBackgroundColor;
  Canvas.FillRect(ClientRect);

  if FSteps.Count = 0 then
    Exit;

  // 1. Draw track lines connecting circles
  Canvas.Pen.Width := 3;
  for I := 0 to FSteps.Count - 2 do
  begin
    Pt1 := GetCircleCenter(I);
    Pt2 := GetCircleCenter(I + 1);

    if (FSteps[I].State = vssCompleted) and (FSteps[I + 1].State in [vssActive, vssCompleted]) then
      Canvas.Pen.Color := FCompletedColor
    else
      Canvas.Pen.Color := FTrackColor;

    Canvas.MoveTo(Pt1.X + FCircleRadius, Pt1.Y);
    Canvas.LineTo(Pt2.X - FCircleRadius, Pt2.Y);
  end;

  // 2. Draw circles & Step labels
  Canvas.Font.Name := 'Segoe UI';
  for I := 0 to FSteps.Count - 1 do
  begin
    Pt1 := GetCircleCenter(I);

    case FSteps[I].State of
      vssCompleted:
        begin
          FillCol := FCompletedColor;
          BorderCol := FCompletedColor;
          TextCol := $FFFFFF;
          StepNumStr := 'OK';
        end;
      vssActive:
        begin
          FillCol := FActiveColor;
          BorderCol := FActiveColor;
          TextCol := $0B0F19;
          StepNumStr := IntToStr(I + 1);
        end;
      vssError:
        begin
          FillCol := FErrorColor;
          BorderCol := FErrorColor;
          TextCol := $FFFFFF;
          StepNumStr := 'X';
        end;
      else // vssPending
        begin
          FillCol := FBackgroundColor;
          BorderCol := FPendingColor;
          TextCol := FPendingColor;
          StepNumStr := IntToStr(I + 1);
        end;
    end;

    // Hover highlight
    if I = FHoveredStepIndex then
      Canvas.Pen.Width := 3
    else
      Canvas.Pen.Width := 2;

    Canvas.Brush.Color := FillCol;
    Canvas.Pen.Color := BorderCol;
    Canvas.Ellipse(Pt1.X - FCircleRadius, Pt1.Y - FCircleRadius,
                   Pt1.X + FCircleRadius, Pt1.Y + FCircleRadius);

    // Number / symbol inside circle
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := TextCol;
    Canvas.Brush.Style := bsClear;

    R := Rect(Pt1.X - FCircleRadius, Pt1.Y - FCircleRadius,
              Pt1.X + FCircleRadius, Pt1.Y + FCircleRadius);
    DrawText(Canvas.Handle, PChar(StepNumStr), Length(StepNumStr), R,
             DT_SINGLELINE or DT_CENTER or DT_VCENTER);

    // Title label below circle
    if FSteps[I].Title <> '' then
    begin
      R := GetStepRect(I);
      R.Top := Pt1.Y + FCircleRadius + 6;
      R.Bottom := R.Top + 16;
      Canvas.Font.Size := 9;
      if I = FActiveStepIndex then
      begin
        Canvas.Font.Style := [fsBold];
        Canvas.Font.Color := FActiveColor;
      end
      else
      begin
        Canvas.Font.Style := [];
        Canvas.Font.Color := FTextColor;
      end;
      DrawText(Canvas.Handle, PChar(FSteps[I].Title), Length(FSteps[I].Title), R,
               DT_SINGLELINE or DT_CENTER or DT_VCENTER);

      // Subtitle label below title
      if FSteps[I].Subtitle <> '' then
      begin
        R.Top := R.Bottom + 2;
        R.Bottom := R.Top + 14;
        Canvas.Font.Size := 8;
        Canvas.Font.Style := [];
        Canvas.Font.Color := FSubtextColor;
        DrawText(Canvas.Handle, PChar(FSteps[I].Subtitle), Length(FSteps[I].Subtitle), R,
                 DT_SINGLELINE or DT_CENTER or DT_VCENTER);
      end;
    end;
  end;
end;

end.
