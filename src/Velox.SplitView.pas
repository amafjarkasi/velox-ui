unit Velox.SplitView;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.SplitView
  Purpose:
    Dark/Light Fluent Resizable Splitter & Collapsible Pane (`TVeloxSplitter`)
    inspired by `KControls` and `Virtual-TreeView` master-detail layouts.
    Replaces legacy 1990s XOR-striped `TSplitter` with a custom-painted GDI+
    grip bar, accent hover highlight, min/max clamping, and double-click
    collapse/restore.
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
  /// <summary>
  /// Custom-painted Fluent vertical splitter with min/max clamping & collapse toggle
  /// </summary>
  TVeloxSplitter = class(TCustomControl)
  private
    FTargetControl: TControl;
    FColors: TVeloxThemeColors;
    FMinSize: Integer;
    FMaxSize: Integer;
    FSavedSize: Integer;
    FCollapsed: Boolean;
    FHot: Boolean;
    FDragging: Boolean;
    FDragStartMouseX: Integer;
    FDragStartTargetW: Integer;
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
  public
    constructor CreateVertical(AOwner: TComponent; AParent: TWinControl;
      ATargetControl: TControl; const AColors: TVeloxThemeColors;
      const AMinSize: Integer = 160; const AMaxSize: Integer = 600);
    procedure ApplyColors(const AColors: TVeloxThemeColors);
    procedure SetTargetSize(const ANewWidth: Integer);
    procedure ToggleCollapse;

    property TargetControl: TControl read FTargetControl;
    property MinSize: Integer read FMinSize write FMinSize;
    property MaxSize: Integer read FMaxSize write FMaxSize;
    property Collapsed: Boolean read FCollapsed;
  end;

implementation

{ TVeloxSplitter }

constructor TVeloxSplitter.CreateVertical(AOwner: TComponent; AParent: TWinControl;
  ATargetControl: TControl; const AColors: TVeloxThemeColors;
  const AMinSize, AMaxSize: Integer);
begin
  inherited Create(AOwner);
  Parent := AParent;
  DoubleBuffered := True;
  FTargetControl := ATargetControl;
  FColors := AColors;
  FMinSize := AMinSize;
  FMaxSize := AMaxSize;
  if Assigned(FTargetControl) then
    FSavedSize := FTargetControl.Width
  else
    FSavedSize := 220;
  FCollapsed := False;
  FHot := False;
  FDragging := False;
  Width := 8;
  Align := alLeft;
  if Assigned(FTargetControl) and (FTargetControl.Align = alRight) then
    Align := alRight;
  Cursor := crHSplit;
end;

procedure TVeloxSplitter.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxSplitter.SetTargetSize(const ANewWidth: Integer);
var
  Clamped: Integer;
begin
  if not Assigned(FTargetControl) then Exit;
  Clamped := ANewWidth;
  if Clamped < FMinSize then Clamped := FMinSize;
  if Clamped > FMaxSize then Clamped := FMaxSize;
  FTargetControl.Width := Clamped;
  FTargetControl.Visible := True;
  FCollapsed := False;
  FSavedSize := Clamped;
end;

procedure TVeloxSplitter.ToggleCollapse;
begin
  if not Assigned(FTargetControl) then Exit;
  if FCollapsed then
  begin
    FTargetControl.Width := FSavedSize;
    FTargetControl.Visible := True;
    FCollapsed := False;
  end
  else
  begin
    FSavedSize := FTargetControl.Width;
    FTargetControl.Visible := False;
    FCollapsed := True;
  end;
  Invalidate;
end;

procedure TVeloxSplitter.DblClick;
begin
  inherited DblClick;
  ToggleCollapse;
end;

procedure TVeloxSplitter.MouseEnter;
begin
  inherited MouseEnter;
  FHot := True;
  Invalidate;
end;

procedure TVeloxSplitter.MouseLeave;
begin
  inherited MouseLeave;
  FHot := False;
  Invalidate;
end;

procedure TVeloxSplitter.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Pt: TPoint;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and Assigned(FTargetControl) then
  begin
    if FCollapsed then
      ToggleCollapse;
    FDragging := True;
    GetCursorPos(Pt);
    FDragStartMouseX := Pt.X;
    FDragStartTargetW := FTargetControl.Width;
  end;
end;

procedure TVeloxSplitter.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Pt: TPoint;
  Delta: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if FDragging and Assigned(FTargetControl) then
  begin
    GetCursorPos(Pt);
    Delta := Pt.X - FDragStartMouseX;
    if Align = alRight then
      Delta := -Delta;
    SetTargetSize(FDragStartTargetW + Delta);
  end;
end;

procedure TVeloxSplitter.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragging := False;
  Invalidate;
end;

procedure TVeloxSplitter.Paint;
var
  GripR: TRect;
  GripCol: TColor;
  MidY: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(Rect(0, 0, Width, Height));

  if FDragging or FHot then
    GripCol := FColors.Accent
  else
    GripCol := FColors.Border;

  MidY := Height div 2;
  GripR := Rect(2, MidY - 18, Width - 2, MidY + 18);
  TVeloxGdiPlus.DrawCard(Canvas, GripR, GripCol, GripCol, 2);
end;

end.
