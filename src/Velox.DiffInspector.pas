unit Velox.DiffInspector;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.DiffInspector (#67)
  Purpose:
    Composite Staging & Code Diff Inspector combining:
      - TVeloxDiff (Myers LCS line-by-line diff, Levenshtein & similarity)
      - TVeloxDiffView (Side-by-side & unified syntax-highlighted visualizer)
      - Header toolbar with ViewMode tabs and additions/deletions badge pills
==============================================================================}

interface

uses
  Windows,
  Types,
  SysUtils,
  Classes,
  Controls,
  Graphics,
  Forms,
  ExtCtrls,
  Velox.Types,
  Velox.GdiPlus,
  Velox.Diff,
  Velox.DiffView,
  Velox.StyledButton;

type
  TVeloxDiffInspector = class(TCustomControl)
  private
    FTopBar: TPanel;
    FDiffView: TVeloxDiffView;
    FBtnUnified: TVeloxStyledButton;
    FBtnSideBySide: TVeloxStyledButton;
    FColors: TVeloxThemeColors;
    FTitle: string;
    FAdditions: Integer;
    FDeletions: Integer;
    FSimilarity: Single;
    procedure HandleUnifiedClick(Sender: TObject);
    procedure HandleSideBySideClick(Sender: TObject);
    procedure TopBarPaint(Sender: TObject);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure CompareTexts(const AOldText, ANewText: string; const ATitle: string = '');
    procedure SetViewMode(const AMode: TVeloxDiffViewMode);

    property DiffView: TVeloxDiffView read FDiffView;
    property Title: string read FTitle write FTitle;
    property Additions: Integer read FAdditions;
    property Deletions: Integer read FDeletions;
    property Similarity: Single read FSimilarity;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxDiffInspector.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 600;
  Height := 400;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FTitle := 'File Comparison';
  FAdditions := 0;
  FDeletions := 0;
  FSimilarity := 1.0;

  // 1. Top Bar
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.Align := alTop;
  FTopBar.Height := 42;
  FTopBar.BevelOuter := bvNone;
  FTopBar.Color := FColors.Surface;
  FTopBar.OnPaint := TopBarPaint;

  // View Mode Buttons on Right
  FBtnUnified := TVeloxStyledButton.Create(Self);
  FBtnUnified.Parent := FTopBar;
  FBtnUnified.Caption := 'Unified';
  FBtnUnified.Variant := vsbPrimary;
  FBtnUnified.SetBounds(Width - 190, 8, 86, 26);
  FBtnUnified.OnClick := HandleUnifiedClick;

  FBtnSideBySide := TVeloxStyledButton.Create(Self);
  FBtnSideBySide.Parent := FTopBar;
  FBtnSideBySide.Caption := 'Side-by-Side';
  FBtnSideBySide.Variant := vsbOutline;
  FBtnSideBySide.SetBounds(Width - 98, 8, 90, 26);
  FBtnSideBySide.OnClick := HandleSideBySideClick;

  // 2. Diff View
  FDiffView := TVeloxDiffView.Create(Self);
  FDiffView.Parent := Self;
  FDiffView.Align := alClient;

  ApplyColors(FColors);
end;

procedure TVeloxDiffInspector.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  if Assigned(FTopBar) then
    FTopBar.Color := FColors.Surface;
  if Assigned(FDiffView) then
    FDiffView.ApplyColors(FColors);
  if Assigned(FBtnUnified) then FBtnUnified.ApplyColors(FColors);
  if Assigned(FBtnSideBySide) then FBtnSideBySide.ApplyColors(FColors);
  Invalidate;
end;

procedure TVeloxDiffInspector.CompareTexts(const AOldText, ANewText: string; const ATitle: string);
begin
  if ATitle <> '' then
    FTitle := ATitle;

  FDiffView.SetDiff(AOldText, ANewText);
  FAdditions := FDiffView.DiffResult.AddedCount;
  FDeletions := FDiffView.DiffResult.DeletedCount;
  FSimilarity := TVeloxDiff.Similarity(AOldText, ANewText);
  FTopBar.Invalidate;
end;

procedure TVeloxDiffInspector.SetViewMode(const AMode: TVeloxDiffViewMode);
begin
  FDiffView.ViewMode := AMode;
  if AMode = vdvmUnified then
  begin
    FBtnUnified.Variant := vsbPrimary;
    FBtnSideBySide.Variant := vsbOutline;
  end
  else
  begin
    FBtnUnified.Variant := vsbOutline;
    FBtnSideBySide.Variant := vsbPrimary;
  end;
  FBtnUnified.Invalidate;
  FBtnSideBySide.Invalidate;
end;

procedure TVeloxDiffInspector.HandleUnifiedClick(Sender: TObject);
begin
  SetViewMode(vdvmUnified);
end;

procedure TVeloxDiffInspector.HandleSideBySideClick(Sender: TObject);
begin
  SetViewMode(vdvmSideBySide);
end;

procedure TVeloxDiffInspector.TopBarPaint(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
  StatsStr: string;
begin
  C := FTopBar.Canvas;
  C.Brush.Color := FColors.Surface;
  C.FillRect(FTopBar.ClientRect);

  // File Title
  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  R := Rect(12, 0, 300, FTopBar.Height);
  DrawText(C.Handle, PChar(FTitle), Length(FTitle), R, DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  // Stats badges (e.g. "+3 / -1")
  StatsStr := Format('+%d / -%d (%.0f%% match)', [FAdditions, FDeletions, FSimilarity * 100.0]);
  R := Rect(310, 0, Width - 200, FTopBar.Height);
  C.Font.Style := [];
  C.Font.Color := FColors.Accent;
  DrawText(C.Handle, PChar(StatsStr), Length(StatsStr), R, DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  // Bottom hairline border
  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, FTopBar.Height - 1);
  C.LineTo(FTopBar.Width, FTopBar.Height - 1);
end;

procedure TVeloxDiffInspector.Paint;
begin
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);
end;

procedure TVeloxDiffInspector.Resize;
begin
  inherited Resize;
  if Assigned(FBtnSideBySide) and Assigned(FBtnUnified) then
  begin
    FBtnSideBySide.Left := Width - FBtnSideBySide.Width - 8;
    FBtnUnified.Left := FBtnSideBySide.Left - FBtnUnified.Width - 6;
  end;
end;

end.
