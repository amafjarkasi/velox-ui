unit Velox.Layout;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Layout (#75)
  Purpose:
    Modern Responsive Layout Primitives:
      - TVeloxStackPanel: Horizontal or Vertical flex-stack container with
        automatic gap spacing, padding, auto-wrapping, and cross-axis alignment.
      - Eliminates 90% of manual SetBounds/Resize coordinate math in desktop forms.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  Graphics,
  Controls,
  ExtCtrls,
  Velox.Types;

type
  TVeloxOrientation = (voHorizontal, voVertical);
  TVeloxStackAlignment = (vsaStart, vsaCenter, vsaEnd, vsaStretch);

  /// <summary>
  /// High-productivity responsive stack layout container
  /// </summary>
  TVeloxStackPanel = class(TCustomControl)
  private
    FOrientation: TVeloxOrientation;
    FGap: Integer;
    FPadding: Integer;
    FWrap: Boolean;
    FAlignment: TVeloxStackAlignment;
    FCrossAlignment: TVeloxStackAlignment;
    FColors: TVeloxThemeColors;
    FInRelayout: Boolean;
    procedure SetOrientation(const AValue: TVeloxOrientation);
    procedure SetGap(const AValue: Integer);
    procedure SetPadding(const AValue: Integer);
    procedure SetWrap(const AValue: Boolean);
    procedure SetAlignment(const AValue: TVeloxStackAlignment);
    procedure SetCrossAlignment(const AValue: TVeloxStackAlignment);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateHorizontal(AOwner: TComponent; AParent: TWinControl;
      const AGap: Integer = 8; const APadding: Integer = 8);
    constructor CreateVertical(AOwner: TComponent; AParent: TWinControl;
      const AGap: Integer = 8; const APadding: Integer = 8);

    procedure ApplyColors(const AColors: TVeloxThemeColors);

    /// <summary>
    /// Adds a child control to the stack and positions it
    /// </summary>
    function Add(AControl: TControl): TControl;

    /// <summary>
    /// Removes a child control from the stack without destroying it
    /// </summary>
    procedure Remove(AControl: TControl);

    /// <summary>
    /// Recalculates child bounds based on orientation, gap, and wrapping
    /// </summary>
    procedure Relayout;

    /// <summary>
    /// Calculates total content height when stacked vertically
    /// </summary>
    function ContentHeight: Integer;

    /// <summary>
    /// Calculates total content width when stacked horizontally
    /// </summary>
    function ContentWidth: Integer;

    property Orientation: TVeloxOrientation read FOrientation write SetOrientation default voHorizontal;
    property Gap: Integer read FGap write SetGap default 8;
    property Padding: Integer read FPadding write SetPadding default 8;
    property Wrap: Boolean read FWrap write SetWrap default False;
    property Alignment: TVeloxStackAlignment read FAlignment write SetAlignment default vsaStart;
    property CrossAlignment: TVeloxStackAlignment read FCrossAlignment write SetCrossAlignment default vsaCenter;
  published
    property Align;
    property Anchors;
    property Color;
    property Visible;
    property Enabled;
  end;

implementation

{ TVeloxStackPanel }

constructor TVeloxStackPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  FOrientation := voHorizontal;
  FGap := 8;
  FPadding := 8;
  FWrap := False;
  FAlignment := vsaStart;
  FCrossAlignment := vsaCenter;
  FInRelayout := False;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  Color := FColors.Background;
  Width := 300;
  Height := 48;
end;

constructor TVeloxStackPanel.CreateHorizontal(AOwner: TComponent; AParent: TWinControl;
  const AGap, APadding: Integer);
begin
  Create(AOwner);
  Parent := AParent;
  FOrientation := voHorizontal;
  FGap := AGap;
  FPadding := APadding;
end;

constructor TVeloxStackPanel.CreateVertical(AOwner: TComponent; AParent: TWinControl;
  const AGap, APadding: Integer);
begin
  Create(AOwner);
  Parent := AParent;
  FOrientation := voVertical;
  FGap := AGap;
  FPadding := APadding;
end;

procedure TVeloxStackPanel.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  Invalidate;
end;

function TVeloxStackPanel.Add(AControl: TControl): TControl;
begin
  if Assigned(AControl) then
  begin
    AControl.Parent := Self;
    Relayout;
  end;
  Result := AControl;
end;

procedure TVeloxStackPanel.Remove(AControl: TControl);
begin
  if Assigned(AControl) and (AControl.Parent = Self) then
  begin
    AControl.Parent := nil;
    Relayout;
  end;
end;

procedure TVeloxStackPanel.SetOrientation(const AValue: TVeloxOrientation);
begin
  if FOrientation <> AValue then
  begin
    FOrientation := AValue;
    Relayout;
  end;
end;

procedure TVeloxStackPanel.SetGap(const AValue: Integer);
begin
  if FGap <> AValue then
  begin
    FGap := AValue;
    Relayout;
  end;
end;

procedure TVeloxStackPanel.SetPadding(const AValue: Integer);
begin
  if FPadding <> AValue then
  begin
    FPadding := AValue;
    Relayout;
  end;
end;

procedure TVeloxStackPanel.SetWrap(const AValue: Boolean);
begin
  if FWrap <> AValue then
  begin
    FWrap := AValue;
    Relayout;
  end;
end;

procedure TVeloxStackPanel.SetAlignment(const AValue: TVeloxStackAlignment);
begin
  if FAlignment <> AValue then
  begin
    FAlignment := AValue;
    Relayout;
  end;
end;

procedure TVeloxStackPanel.SetCrossAlignment(const AValue: TVeloxStackAlignment);
begin
  if FCrossAlignment <> AValue then
  begin
    FCrossAlignment := AValue;
    Relayout;
  end;
end;

procedure TVeloxStackPanel.Resize;
begin
  inherited Resize;
  Relayout;
end;

procedure TVeloxStackPanel.Relayout;
var
  I, CurX, CurY, MaxLineCross, LineStartX, RowIdx: Integer;
  Ctrl: TControl;
  NewX, NewY, NewW, NewH: Integer;
  AvailCross: Integer;
begin
  if FInRelayout or (ControlCount = 0) then Exit;
  FInRelayout := True;
  try
    CurX := FPadding;
    CurY := FPadding;
    MaxLineCross := 0;

    if FOrientation = voHorizontal then
    begin
      AvailCross := Height - (FPadding * 2);
      if AvailCross <= 0 then AvailCross := 1;

      for I := 0 to ControlCount - 1 do
      begin
        Ctrl := Controls[I];
        if not Ctrl.Visible then Continue;

        // Wrap to next line if necessary
        if FWrap and (CurX + Ctrl.Width > Width - FPadding) and (CurX > FPadding) then
        begin
          CurX := FPadding;
          Inc(CurY, MaxLineCross + FGap);
          MaxLineCross := 0;
        end;

        NewX := CurX;
        NewW := Ctrl.Width;
        NewH := Ctrl.Height;

        case FCrossAlignment of
          vsaStart:   NewY := CurY;
          vsaCenter:  NewY := CurY + ((AvailCross - NewH) div 2);
          vsaEnd:     NewY := CurY + (AvailCross - NewH);
          vsaStretch:
            begin
              NewY := CurY;
              NewH := AvailCross;
            end;
        else
          NewY := CurY;
        end;

        Ctrl.SetBounds(NewX, NewY, NewW, NewH);
        Inc(CurX, NewW + FGap);

        if NewH > MaxLineCross then
          MaxLineCross := NewH;
      end;
    end
    else
    begin
      // Vertical orientation
      AvailCross := Width - (FPadding * 2);
      if AvailCross <= 0 then AvailCross := 1;

      for I := 0 to ControlCount - 1 do
      begin
        Ctrl := Controls[I];
        if not Ctrl.Visible then Continue;

        // Wrap to next column if necessary
        if FWrap and (CurY + Ctrl.Height > Height - FPadding) and (CurY > FPadding) then
        begin
          CurY := FPadding;
          Inc(CurX, MaxLineCross + FGap);
          MaxLineCross := 0;
        end;

        NewY := CurY;
        NewW := Ctrl.Width;
        NewH := Ctrl.Height;

        case FCrossAlignment of
          vsaStart:   NewX := CurX;
          vsaCenter:  NewX := CurX + ((AvailCross - NewW) div 2);
          vsaEnd:     NewX := CurX + (AvailCross - NewW);
          vsaStretch:
            begin
              NewX := CurX;
              NewW := AvailCross;
            end;
        else
          NewX := CurX;
        end;

        Ctrl.SetBounds(NewX, NewY, NewW, NewH);
        Inc(CurY, NewH + FGap);

        if NewW > MaxLineCross then
          MaxLineCross := NewW;
      end;
    end;
  finally
    FInRelayout := False;
  end;
end;

function TVeloxStackPanel.ContentHeight: Integer;
var
  I, H: Integer;
begin
  H := FPadding * 2;
  if FOrientation = voVertical then
  begin
    for I := 0 to ControlCount - 1 do
      if Controls[I].Visible then
        Inc(H, Controls[I].Height + FGap);
    if ControlCount > 0 then
      Dec(H, FGap);
  end
  else
  begin
    for I := 0 to ControlCount - 1 do
      if Controls[I].Visible and (Controls[I].Height > H) then
        H := Controls[I].Height + FPadding * 2;
  end;
  Result := H;
end;

function TVeloxStackPanel.ContentWidth: Integer;
var
  I, W: Integer;
begin
  W := FPadding * 2;
  if FOrientation = voHorizontal then
  begin
    for I := 0 to ControlCount - 1 do
      if Controls[I].Visible then
        Inc(W, Controls[I].Width + FGap);
    if ControlCount > 0 then
      Dec(W, FGap);
  end
  else
  begin
    for I := 0 to ControlCount - 1 do
      if Controls[I].Visible and (Controls[I].Width > W) then
        W := Controls[I].Width + FPadding * 2;
  end;
  Result := W;
end;

procedure TVeloxStackPanel.Paint;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
end;

end.
