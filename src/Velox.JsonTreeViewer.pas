unit Velox.JsonTreeViewer;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.JsonTreeViewer (#72)
  Purpose:
    Composite Interactive JSON Document & Hierarchy Explorer combining:
      - TVeloxJson (RFC-8259 DOM, JSONPath queries & value extraction)
      - TVeloxTreeBuilder (O(N) DFS hierarchical indentation & branch formatting)
      - TVeloxBreadcrumb (Live JSONPath segment navigation)
      - Owner-drawn tree with typed badges ([Object], [Array], [String], [Number])
==============================================================================}

interface

uses
  Windows,
  Types,
  {$IFDEF FPC}
  LCLType,
  {$ENDIF}
  SysUtils,
  Classes,
  Controls,
  Graphics,
  Forms,
  StdCtrls,
  ExtCtrls,
  Velox.Types,
  Velox.GdiPlus,
  Velox.Json,
  Velox.TreeBuilder,
  Velox.Breadcrumb;

type
  TJsonTreeNode = record
    Path: string;
    KeyName: string;
    ValueStr: string;
    ValueKind: TVeloxJsonKind;
    Depth: Integer;
    HasChildren: Boolean;
  end;

  TVeloxJsonTreeViewer = class(TCustomControl)
  private
    FDoc: TVeloxJson;
    FBreadcrumb: TVeloxBreadcrumb;
    FListBox: TListBox;
    FNodes: array of TJsonTreeNode;
    FNodeCount: Integer;
    FColors: TVeloxThemeColors;
    procedure BuildNodesFromValue(const AVal: TVeloxJson; const APath, AKey: string; const ADepth: Integer);
    procedure HandleListClick(Sender: TObject);
    procedure HandleDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure UpdateBreadcrumb(const APath: string);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    procedure LoadJson(const AJsonText: string);
    procedure Clear;
    function SelectedPath: string;
    function SelectedValue: string;

    property NodeCount: Integer read FNodeCount;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

constructor TVeloxJsonTreeViewer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 480;
  Height := 400;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FNodeCount := 0;
  SetLength(FNodes, 0);

  // 1. Top Breadcrumb
  FBreadcrumb := TVeloxBreadcrumb.Create(Self);
  FBreadcrumb.Parent := Self;
  FBreadcrumb.Align := alTop;
  FBreadcrumb.Height := 34;
  FBreadcrumb.AddSegment('root', 'root');

  // 2. Main ListBox
  FListBox := TListBox.Create(Self);
  FListBox.Parent := Self;
  FListBox.Align := alClient;
  FListBox.Style := lbOwnerDrawFixed;
  FListBox.ItemHeight := 28;
  FListBox.BorderStyle := bsNone;
  FListBox.Color := FColors.Background;
  FListBox.OnDrawItem := HandleDrawItem;
  FListBox.OnClick := HandleListClick;

  ApplyColors(FColors);
end;

destructor TVeloxJsonTreeViewer.Destroy;
begin
  FDoc.Free;
  inherited Destroy;
end;

procedure TVeloxJsonTreeViewer.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;
  if Assigned(FBreadcrumb) then FBreadcrumb.ApplyColors(FColors);
  if Assigned(FListBox) then FListBox.Color := FColors.Background;
  Invalidate;
end;

procedure TVeloxJsonTreeViewer.BuildNodesFromValue(const AVal: TVeloxJson; const APath, AKey: string; const ADepth: Integer);
var
  Idx, I: Integer;
  ChildKey, SubPath: string;
begin
  if not Assigned(AVal) then Exit;

  Idx := FNodeCount;
  Inc(FNodeCount);
  SetLength(FNodes, FNodeCount);

  FNodes[Idx].Path := APath;
  FNodes[Idx].KeyName := AKey;
  FNodes[Idx].ValueKind := AVal.Kind;
  FNodes[Idx].Depth := ADepth;
  FNodes[Idx].HasChildren := (AVal.Kind in [jkObject, jkArray]);

  case AVal.Kind of
    jkObject:
      begin
        FNodes[Idx].ValueStr := Format('{%d props}', [AVal.Count]);
        for I := 0 to AVal.Count - 1 do
        begin
          ChildKey := AVal.KeyAt[I];
          if APath = 'root' then
            SubPath := 'root.' + ChildKey
          else
            SubPath := APath + '.' + ChildKey;
          BuildNodesFromValue(AVal.Items[I], SubPath, ChildKey, ADepth + 1);
        end;
      end;
    jkArray:
      begin
        FNodes[Idx].ValueStr := Format('[%d items]', [AVal.Count]);
        for I := 0 to AVal.Count - 1 do
        begin
          ChildKey := Format('[%d]', [I]);
          SubPath := APath + ChildKey;
          BuildNodesFromValue(AVal.Items[I], SubPath, ChildKey, ADepth + 1);
        end;
      end;
    jkString:  FNodes[Idx].ValueStr := '"' + AVal.AsString + '"';
    jkNumber:  FNodes[Idx].ValueStr := FloatToStr(AVal.AsFloat);
    jkBool:    if AVal.AsBool then FNodes[Idx].ValueStr := 'true' else FNodes[Idx].ValueStr := 'false';
    jkNull:    FNodes[Idx].ValueStr := 'null';
  end;
end;

procedure TVeloxJsonTreeViewer.LoadJson(const AJsonText: string);
var
  I: Integer;
  Err: string;
begin
  Clear;
  FDoc := TVeloxJson.Parse(AJsonText, Err);
  if Assigned(FDoc) then
  begin
    BuildNodesFromValue(FDoc, 'root', 'root', 0);
  end;

  FListBox.Items.BeginUpdate;
  try
    for I := 0 to FNodeCount - 1 do
      FListBox.Items.Add(FNodes[I].KeyName);
  finally
    FListBox.Items.EndUpdate;
  end;

  if FNodeCount > 0 then
    FListBox.ItemIndex := 0;
  UpdateBreadcrumb('root');
end;

procedure TVeloxJsonTreeViewer.Clear;
begin
  if Assigned(FDoc) then
  begin
    FreeAndNil(FDoc);
  end;
  FNodeCount := 0;
  SetLength(FNodes, 0);
  FListBox.Items.Clear;
  FBreadcrumb.Clear;
  FBreadcrumb.AddSegment('root', 'root');
end;

function TVeloxJsonTreeViewer.SelectedPath: string;
begin
  Result := '';
  if (FListBox.ItemIndex >= 0) and (FListBox.ItemIndex < FNodeCount) then
    Result := FNodes[FListBox.ItemIndex].Path;
end;

function TVeloxJsonTreeViewer.SelectedValue: string;
begin
  Result := '';
  if (FListBox.ItemIndex >= 0) and (FListBox.ItemIndex < FNodeCount) then
    Result := FNodes[FListBox.ItemIndex].ValueStr;
end;

procedure TVeloxJsonTreeViewer.UpdateBreadcrumb(const APath: string);
var
  Parts: TStringList;
  I: Integer;
begin
  FBreadcrumb.Clear;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '.';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := APath;
    for I := 0 to Parts.Count - 1 do
      FBreadcrumb.AddSegment(Parts[I], Parts[I]);
  finally
    Parts.Free;
  end;
end;

procedure TVeloxJsonTreeViewer.HandleListClick(Sender: TObject);
var
  P: string;
begin
  P := SelectedPath;
  if P <> '' then
    UpdateBreadcrumb(P);
end;

procedure TVeloxJsonTreeViewer.HandleDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  Node: TJsonTreeNode;
  IndentX, BadgeW: Integer;
  BadgeStr: string;
  BadgeColor: TColor;
  BadgeR, KeyR, ValR: TRect;
begin
  C := FListBox.Canvas;
  if (Index < 0) or (Index >= FNodeCount) then Exit;
  Node := FNodes[Index];

  // Selection background
  if odSelected in State then
  begin
    C.Brush.Color := FColors.SurfaceHover;
    C.FillRect(ARect);
  end
  else
  begin
    C.Brush.Color := FColors.Background;
    C.FillRect(ARect);
  end;

  IndentX := ARect.Left + 8 + Node.Depth * 16;

  // Tree Branch indicator for depth > 0
  if Node.Depth > 0 then
  begin
    C.Pen.Color := FColors.Border;
    C.Pen.Width := 1;
    C.MoveTo(IndentX - 10, ARect.Top);
    C.LineTo(IndentX - 10, ARect.Top + ARect.Height div 2);
    C.LineTo(IndentX - 4, ARect.Top + ARect.Height div 2);
  end;

  // Type badge
  case Node.ValueKind of
    jkObject:  begin BadgeStr := 'obj';  BadgeColor := $6366F1; end; // Indigo
    jkArray:   begin BadgeStr := 'arr';  BadgeColor := $38BDF8; end; // Cyan
    jkString:  begin BadgeStr := 'str';  BadgeColor := $10B981; end; // Emerald
    jkNumber:  begin BadgeStr := 'num';  BadgeColor := $F59E0B; end; // Amber
    jkBool:    begin BadgeStr := 'bool'; BadgeColor := $EC4899; end; // Pink
    jkNull:    begin BadgeStr := 'null'; BadgeColor := $64748B; end; // Slate
  end;

  BadgeW := 32;
  BadgeR := Rect(IndentX, ARect.Top + 4, IndentX + BadgeW, ARect.Bottom - 4);
  TVeloxGdiPlus.DrawCard(C, BadgeR, TVeloxUtils.BlendColor(FColors.Background, BadgeColor, 0.25), BadgeColor, 3);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 7;
  C.Font.Style := [fsBold];
  C.Font.Color := BadgeColor;
  DrawText(C.Handle, PChar(BadgeStr), -1, BadgeR, DT_SINGLELINE or DT_VCENTER or DT_CENTER);

  // Key Name
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  KeyR := Rect(IndentX + BadgeW + 8, ARect.Top, IndentX + BadgeW + 160, ARect.Bottom);
  DrawText(C.Handle, PChar(Node.KeyName), -1, KeyR, DT_SINGLELINE or DT_VCENTER or DT_LEFT);

  // Value summary
  C.Font.Style := [];
  case Node.ValueKind of
    jkString:  C.Font.Color := $34D399; // Soft emerald
    jkNumber:  C.Font.Color := $FBBF24; // Amber
    jkBool:    C.Font.Color := $F472B6; // Pink
    else       C.Font.Color := FColors.TextSecondary;
  end;

  ValR := Rect(IndentX + BadgeW + 164, ARect.Top, ARect.Right - 8, ARect.Bottom);
  DrawText(C.Handle, PChar(Node.ValueStr), -1, ValR, DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_END_ELLIPSIS);
end;

procedure TVeloxJsonTreeViewer.Paint;
begin
  Canvas.Brush.Color := FColors.Background;
  Canvas.FillRect(ClientRect);
end;

procedure TVeloxJsonTreeViewer.Resize;
begin
  inherited Resize;
end;

end.
