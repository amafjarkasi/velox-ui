unit Velox.Glass;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, Controls, Graphics, Forms, Types,
  Velox.Types, Velox.GdiPlus;

type
  TVeloxGlassPanel = class(TCustomControl)
  private
    FCornerRadius: Integer;
    FOpacity: Byte; // 0..255
    FTitle: string;
    FColors: TVeloxThemeColors;
    FShowSpecularHighlight: Boolean;
    procedure SetCornerRadius(const Value: Integer);
    procedure SetOpacity(const Value: Byte);
    procedure SetTitle(const Value: string);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);
  published
    property Align;
    property Anchors;
    property CornerRadius: Integer read FCornerRadius write SetCornerRadius default 12;
    property Opacity: Byte read FOpacity write SetOpacity default 210;
    property Title: string read FTitle write SetTitle;
    property ShowSpecularHighlight: Boolean read FShowSpecularHighlight write FShowSpecularHighlight default True;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxGlassPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 300;
  Height := 180;
  FCornerRadius := 12;
  FOpacity := 210;
  FShowSpecularHighlight := True;
  FTitle := '';
  FColors := TVeloxUtils.GetThemeColors(vtDark);
end;

procedure TVeloxGlassPanel.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Invalidate;
end;

procedure TVeloxGlassPanel.SetCornerRadius(const Value: Integer);
begin
  if FCornerRadius <> Value then
  begin
    FCornerRadius := Value;
    Invalidate;
  end;
end;

procedure TVeloxGlassPanel.SetOpacity(const Value: Byte);
begin
  if FOpacity <> Value then
  begin
    FOpacity := Value;
    Invalidate;
  end;
end;

procedure TVeloxGlassPanel.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Invalidate;
  end;
end;

procedure TVeloxGlassPanel.Resize;
begin
  inherited Resize;
  Invalidate;
end;

procedure TVeloxGlassPanel.Paint;
var
  R, TitleR, LocalR: TRect;
begin
  R := ClientRect;

  // Glass card body
  Canvas.Brush.Color := FColors.SurfaceCard;
  Canvas.Pen.Color := FColors.Border;
  Canvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, FCornerRadius * 2, FCornerRadius * 2);

  // Specular top edge highlight (simulates glass reflection)
  if FShowSpecularHighlight and (Width > FCornerRadius * 2) then
  begin
    Canvas.Pen.Color := $40FFFFFF; // Subtle specular white
    Canvas.Pen.Width := 1;
    Canvas.MoveTo(R.Left + FCornerRadius, R.Top + 1);
    Canvas.LineTo(R.Right - FCornerRadius, R.Top + 1);
  end;

  // Title if set (exact vertical center in title bar region)
  if FTitle <> '' then
  begin
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Size := 9;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := FColors.Accent;

    TitleR := Rect(R.Left + 14, R.Top + 6, R.Right - 14, R.Top + 26);
    LocalR := TitleR;
    DrawText(Canvas.Handle, PChar(FTitle), Length(FTitle), LocalR,
      DT_SINGLELINE or DT_LEFT or DT_VCENTER);

    // Subtle header separator hairline
    Canvas.Pen.Color := FColors.Border;
    Canvas.MoveTo(R.Left + 10, R.Top + 30);
    Canvas.LineTo(R.Right - 10, R.Top + 30);
  end;
end;

end.
