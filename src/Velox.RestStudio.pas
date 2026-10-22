unit Velox.RestStudio;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.RestStudio (#79)
  Purpose:
    Embedded HTTP Workbench, API Debugger & Telemetry Studio combining:
      - TVeloxHttp (Native WinHTTP non-blocking requests with TLS 1.3)
      - TVeloxPropertyGrid (Two-column typed headers & query parameters editor)
      - TVeloxJson (RFC-8259 DOM formatting & syntax inspection)
      - TVeloxDiffView (Side-by-side & unified payload regression diffing)
      - TVeloxRingBuffer & TVeloxGdiPlus (Rolling latency telemetry & sparklines)
      - TVeloxStyledButton & TVeloxClipboard (1-click cURL export & baseline saving)
==============================================================================}

interface

uses
  Windows,
  SysUtils,
  Classes,
  Controls,
  Graphics,
  Forms,
  ExtCtrls,
  StdCtrls,
  Velox.Types,
  Velox.GdiPlus,
  Velox.Http,
  Velox.Json,
  Velox.DiffView,
  Velox.PropertyGrid,
  Velox.StyledButton,
  Velox.Clipboard,
  Velox.Export;

type
  TVeloxRestMethod = (vrmGET, vrmPOST, vrmPUT, vrmDELETE, vrmPATCH, vrmHEAD);

  TVeloxRestViewMode = (vrvmPrettyJson, vrvmRawText, vrvmDiffBaseline, vrvmLatency);

  TVeloxRestStudio = class(TCustomControl)
  private
    FColors: TVeloxThemeColors;
    FMethod: TVeloxRestMethod;
    FViewMode: TVeloxRestViewMode;
    FRequestTab: Integer; // 0 = Headers/Params, 1 = Body (JSON)
    FLastResponse: TVeloxHttpResponse;
    FBaselineResponse: string;
    FLatencyHistory: TVeloxRingBuffer;
    FLastElapsedMs: Cardinal;
    FRequestCount: Integer;
    FIsSending: Boolean;
    FOnResponse: TNotifyEvent;

    // UI Structure
    FTopBar: TPanel;
    FBtnMethod: TVeloxStyledButton;
    FUrlEdit: TEdit;
    FUrlContainer: TPanel;
    FBtnSend: TVeloxStyledButton;
    FBtnCurl: TVeloxStyledButton;
    FBtnBaseline: TVeloxStyledButton;

    FSplitContainer: TPanel;
    FLeftPanel: TPanel;
    FRightPanel: TPanel;

    // Left Panel: Request Config
    FReqHeaderBar: TPanel;
    FBtnTabParams: TVeloxStyledButton;
    FBtnTabBody: TVeloxStyledButton;
    FBtnFormatJson: TVeloxStyledButton;
    FPropGrid: TVeloxPropertyGrid;
    FBodyMemo: TMemo;

    // Right Panel: Response & Telemetry
    FRespHeaderBar: TPanel;
    FBtnViewPretty: TVeloxStyledButton;
    FBtnViewRaw: TVeloxStyledButton;
    FBtnViewDiff: TVeloxStyledButton;
    FBtnViewLatency: TVeloxStyledButton;
    FResponseMemo: TMemo;
    FDiffView: TVeloxDiffView;
    FLatencyPanel: TPanel;
    FFooterBar: TPanel;

    procedure SetMethod(const Value: TVeloxRestMethod);
    procedure SetViewMode(const Value: TVeloxRestViewMode);
    procedure SetRequestTab(const Value: Integer);
    function GetUrl: string;
    procedure SetUrl(const Value: string);
    function GetRequestBody: string;
    procedure SetRequestBody(const Value: string);

    procedure HandleMethodClick(Sender: TObject);
    procedure HandleSendClick(Sender: TObject);
    procedure HandleCurlClick(Sender: TObject);
    procedure HandleBaselineClick(Sender: TObject);
    procedure HandleTabParamsClick(Sender: TObject);
    procedure HandleTabBodyClick(Sender: TObject);
    procedure HandleFormatJsonClick(Sender: TObject);

    procedure HandleViewPrettyClick(Sender: TObject);
    procedure HandleViewRawClick(Sender: TObject);
    procedure HandleViewDiffClick(Sender: TObject);
    procedure HandleViewLatencyClick(Sender: TObject);

    procedure UrlEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TopBarPaint(Sender: TObject);
    procedure UrlContainerPaint(Sender: TObject);
    procedure RespHeaderPaint(Sender: TObject);
    procedure LatencyPanelPaint(Sender: TObject);
    procedure FooterBarPaint(Sender: TObject);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    /// <summary>
    /// Executes the current HTTP request synchronously with sub-millisecond stopwatch
    /// </summary>
    procedure SendRequest;

    /// <summary>
    /// Configures request method, target URL, and optional JSON body
    /// </summary>
    procedure SetEndpoint(const AMethod: TVeloxRestMethod; const AUrl: string;
      const ABody: string = '');

    /// <summary>
    /// Constructs the final URL including query parameters defined in the property grid
    /// </summary>
    function BuildEffectiveUrl: string;

    /// <summary>
    /// Builds raw HTTP headers string from the property grid 'Headers' category
    /// </summary>
    function BuildHeadersString: string;

    /// <summary>
    /// Generates standard executable cURL command for the current request configuration
    /// </summary>
    function GenerateCurlCommand: string;

    /// <summary>
    /// Copies generated cURL command directly to system clipboard
    /// </summary>
    function CopyAsCurl: Boolean;

    /// <summary>
    /// Stores the current response body as baseline comparison snapshot
    /// </summary>
    procedure SaveCurrentAsBaseline;

    /// <summary>
    /// Formats the JSON request body using RFC-8259 indentation
    /// </summary>
    procedure PrettifyBody;

    class function MethodToString(const AMethod: TVeloxRestMethod): string; static;
    class function StringToMethod(const AStr: string): TVeloxRestMethod; static;
    class function MethodColor(const AMethod: TVeloxRestMethod): TColor; static;

    property Method: TVeloxRestMethod read FMethod write SetMethod;
    property Url: string read GetUrl write SetUrl;
    property RequestBody: string read GetRequestBody write SetRequestBody;
    property ViewMode: TVeloxRestViewMode read FViewMode write SetViewMode;
    property RequestTab: Integer read FRequestTab write SetRequestTab;
    property Response: TVeloxHttpResponse read FLastResponse;
    property BaselineResponse: string read FBaselineResponse write FBaselineResponse;
    property LatencyHistory: TVeloxRingBuffer read FLatencyHistory;
    property LastElapsedMs: Cardinal read FLastElapsedMs;
    property RequestCount: Integer read FRequestCount;
    property PropertyGrid: TVeloxPropertyGrid read FPropGrid;
    property DiffView: TVeloxDiffView read FDiffView;
    property OnResponse: TNotifyEvent read FOnResponse write FOnResponse;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

{ TVeloxRestStudio }

class function TVeloxRestStudio.MethodToString(const AMethod: TVeloxRestMethod): string;
begin
  case AMethod of
    vrmGET:    Result := 'GET';
    vrmPOST:   Result := 'POST';
    vrmPUT:    Result := 'PUT';
    vrmDELETE: Result := 'DELETE';
    vrmPATCH:  Result := 'PATCH';
    vrmHEAD:   Result := 'HEAD';
  else
    Result := 'GET';
  end;
end;

class function TVeloxRestStudio.StringToMethod(const AStr: string): TVeloxRestMethod;
var
  U: string;
begin
  U := UpperCase(Trim(AStr));
  if U = 'POST' then Result := vrmPOST
  else if U = 'PUT' then Result := vrmPUT
  else if U = 'DELETE' then Result := vrmDELETE
  else if U = 'PATCH' then Result := vrmPATCH
  else if U = 'HEAD' then Result := vrmHEAD
  else Result := vrmGET;
end;

class function TVeloxRestStudio.MethodColor(const AMethod: TVeloxRestMethod): TColor;
begin
  case AMethod of
    vrmGET:    Result := $99D334; // Vibrant Emerald (#34D399)
    vrmPOST:   Result := $F8BD38; // Vibrant Sky Blue (#38BDF8)
    vrmPUT:    Result := $0B9EF5; // Amber (#F59E0B)
    vrmDELETE: Result := $7171F8; // Coral Red (#F87171)
    vrmPATCH:  Result := $F755A8; // Violet (#A855F7)
    vrmHEAD:   Result := $94A3B8; // Slate Slate-400
  else
    Result := $99D334;
  end;
end;

constructor TVeloxRestStudio.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  Width := 860;
  Height := 540;
  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FMethod := vrmGET;
  FViewMode := vrvmPrettyJson;
  FRequestTab := 0;
  FLatencyHistory.Clear(30);
  FLastElapsedMs := 0;
  FRequestCount := 0;
  FIsSending := False;

  // 1. Top Bar: Method + URL + Send + cURL + Baseline
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.BevelOuter := bvNone;
  FTopBar.Height := 48;
  FTopBar.Align := alTop;
  FTopBar.OnPaint := TopBarPaint;

  FBtnMethod := TVeloxStyledButton.Create(Self);
  FBtnMethod.Parent := FTopBar;
  FBtnMethod.Caption := 'GET';
  FBtnMethod.Variant := vsbPrimary;
  FBtnMethod.SetBounds(8, 10, 72, 28);
  FBtnMethod.OnClick := HandleMethodClick;

  FUrlContainer := TPanel.Create(Self);
  FUrlContainer.Parent := FTopBar;
  FUrlContainer.BevelOuter := bvNone;
  FUrlContainer.SetBounds(86, 10, Width - 320, 28);
  FUrlContainer.OnPaint := UrlContainerPaint;

  FUrlEdit := TEdit.Create(Self);
  FUrlEdit.Parent := FUrlContainer;
  FUrlEdit.BorderStyle := bsNone;
  FUrlEdit.Font.Name := 'Segoe UI';
  FUrlEdit.Font.Size := 9;
  FUrlEdit.Text := 'https://api.github.com/repos/amafjarkasi/velox-ui';
  FUrlEdit.SetBounds(8, 5, FUrlContainer.Width - 16, 18);
  FUrlEdit.OnKeyDown := UrlEditKeyDown;

  FBtnSend := TVeloxStyledButton.Create(Self);
  FBtnSend.Parent := FTopBar;
  FBtnSend.Caption := 'Send';
  FBtnSend.Variant := vsbPrimary;
  FBtnSend.SetBounds(Width - 224, 10, 68, 28);
  FBtnSend.OnClick := HandleSendClick;

  FBtnCurl := TVeloxStyledButton.Create(Self);
  FBtnCurl.Parent := FTopBar;
  FBtnCurl.Caption := 'cURL';
  FBtnCurl.Variant := vsbOutline;
  FBtnCurl.SetBounds(Width - 150, 10, 58, 28);
  FBtnCurl.OnClick := HandleCurlClick;

  FBtnBaseline := TVeloxStyledButton.Create(Self);
  FBtnBaseline.Parent := FTopBar;
  FBtnBaseline.Caption := 'Baseline';
  FBtnBaseline.Variant := vsbSurface;
  FBtnBaseline.SetBounds(Width - 86, 10, 76, 28);
  FBtnBaseline.OnClick := HandleBaselineClick;

  // 2. Footer Status Bar
  FFooterBar := TPanel.Create(Self);
  FFooterBar.Parent := Self;
  FFooterBar.BevelOuter := bvNone;
  FFooterBar.Height := 26;
  FFooterBar.Align := alBottom;
  FFooterBar.OnPaint := FooterBarPaint;

  // 3. Central Split Container
  FSplitContainer := TPanel.Create(Self);
  FSplitContainer.Parent := Self;
  FSplitContainer.BevelOuter := bvNone;
  FSplitContainer.Align := alClient;

  FLeftPanel := TPanel.Create(Self);
  FLeftPanel.Parent := FSplitContainer;
  FLeftPanel.BevelOuter := bvNone;
  FLeftPanel.Width := 340;
  FLeftPanel.Align := alLeft;

  FRightPanel := TPanel.Create(Self);
  FRightPanel.Parent := FSplitContainer;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.Align := alClient;

  // 3.1 Left Panel Components
  FReqHeaderBar := TPanel.Create(Self);
  FReqHeaderBar.Parent := FLeftPanel;
  FReqHeaderBar.BevelOuter := bvNone;
  FReqHeaderBar.Height := 34;
  FReqHeaderBar.Align := alTop;

  FBtnTabParams := TVeloxStyledButton.Create(Self);
  FBtnTabParams.Parent := FReqHeaderBar;
  FBtnTabParams.Caption := 'Headers & Params';
  FBtnTabParams.Variant := vsbPrimary;
  FBtnTabParams.SetBounds(8, 4, 130, 26);
  FBtnTabParams.OnClick := HandleTabParamsClick;

  FBtnTabBody := TVeloxStyledButton.Create(Self);
  FBtnTabBody.Parent := FReqHeaderBar;
  FBtnTabBody.Caption := 'Body (JSON)';
  FBtnTabBody.Variant := vsbOutline;
  FBtnTabBody.SetBounds(144, 4, 100, 26);
  FBtnTabBody.OnClick := HandleTabBodyClick;

  FBtnFormatJson := TVeloxStyledButton.Create(Self);
  FBtnFormatJson.Parent := FReqHeaderBar;
  FBtnFormatJson.Caption := 'Format';
  FBtnFormatJson.Variant := vsbSurface;
  FBtnFormatJson.SetBounds(250, 4, 60, 26);
  FBtnFormatJson.OnClick := HandleFormatJsonClick;

  FPropGrid := TVeloxPropertyGrid.Create(Self);
  FPropGrid.Parent := FLeftPanel;
  FPropGrid.Align := alClient;
  FPropGrid.AddCategory('Headers', True);
  FPropGrid.AddString('Headers', 'Content-Type', 'Content-Type', 'application/json');
  FPropGrid.AddString('Headers', 'Accept', 'Accept', 'application/json');
  FPropGrid.AddString('Headers', 'User-Agent', 'User-Agent', 'VeloxUI-RestStudio/2.5');
  FPropGrid.AddCategory('Query Parameters', True);
  FPropGrid.AddString('Query Parameters', 'page', 'page', '1');
  FPropGrid.AddString('Query Parameters', 'per_page', 'per_page', '30');

  FBodyMemo := TMemo.Create(Self);
  FBodyMemo.Parent := FLeftPanel;
  FBodyMemo.Align := alClient;
  FBodyMemo.BorderStyle := bsNone;
  FBodyMemo.Font.Name := 'Consolas';
  FBodyMemo.Font.Size := 9;
  FBodyMemo.ScrollBars := ssBoth;
  FBodyMemo.Text := '{\r\n  "query": "velox",\r\n  "active": true\r\n}';
  FBodyMemo.Visible := False;

  // 3.2 Right Panel Components
  FRespHeaderBar := TPanel.Create(Self);
  FRespHeaderBar.Parent := FRightPanel;
  FRespHeaderBar.BevelOuter := bvNone;
  FRespHeaderBar.Height := 34;
  FRespHeaderBar.Align := alTop;
  FRespHeaderBar.OnPaint := RespHeaderPaint;

  FBtnViewPretty := TVeloxStyledButton.Create(Self);
  FBtnViewPretty.Parent := FRespHeaderBar;
  FBtnViewPretty.Caption := 'Pretty JSON';
  FBtnViewPretty.Variant := vsbPrimary;
  FBtnViewPretty.SetBounds(200, 4, 82, 26);
  FBtnViewPretty.OnClick := HandleViewPrettyClick;

  FBtnViewRaw := TVeloxStyledButton.Create(Self);
  FBtnViewRaw.Parent := FRespHeaderBar;
  FBtnViewRaw.Caption := 'Raw';
  FBtnViewRaw.Variant := vsbOutline;
  FBtnViewRaw.SetBounds(288, 4, 54, 26);
  FBtnViewRaw.OnClick := HandleViewRawClick;

  FBtnViewDiff := TVeloxStyledButton.Create(Self);
  FBtnViewDiff.Parent := FRespHeaderBar;
  FBtnViewDiff.Caption := 'Diff vs Baseline';
  FBtnViewDiff.Variant := vsbOutline;
  FBtnViewDiff.SetBounds(348, 4, 108, 26);
  FBtnViewDiff.OnClick := HandleViewDiffClick;

  FBtnViewLatency := TVeloxStyledButton.Create(Self);
  FBtnViewLatency.Parent := FRespHeaderBar;
  FBtnViewLatency.Caption := 'Latency';
  FBtnViewLatency.Variant := vsbOutline;
  FBtnViewLatency.SetBounds(462, 4, 68, 26);
  FBtnViewLatency.OnClick := HandleViewLatencyClick;

  FResponseMemo := TMemo.Create(Self);
  FResponseMemo.Parent := FRightPanel;
  FResponseMemo.Align := alClient;
  FResponseMemo.BorderStyle := bsNone;
  FResponseMemo.Font.Name := 'Consolas';
  FResponseMemo.Font.Size := 9;
  FResponseMemo.ReadOnly := True;
  FResponseMemo.ScrollBars := ssBoth;
  FResponseMemo.Text := '// Click Send to execute request against endpoint.';

  FDiffView := TVeloxDiffView.Create(Self);
  FDiffView.Parent := FRightPanel;
  FDiffView.Align := alClient;
  FDiffView.Visible := False;

  FLatencyPanel := TPanel.Create(Self);
  FLatencyPanel.Parent := FRightPanel;
  FLatencyPanel.Align := alClient;
  FLatencyPanel.BevelOuter := bvNone;
  FLatencyPanel.Visible := False;
  FLatencyPanel.OnPaint := LatencyPanelPaint;

  ApplyColors(FColors);
end;

destructor TVeloxRestStudio.Destroy;
begin
  inherited Destroy;
end;

procedure TVeloxRestStudio.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  Color := FColors.Background;

  FTopBar.Color := FColors.Surface;
  FUrlContainer.Color := FColors.SurfaceCard;
  FUrlEdit.Color := FColors.SurfaceCard;
  FUrlEdit.Font.Color := FColors.TextPrimary;

  FLeftPanel.Color := FColors.Surface;
  FRightPanel.Color := FColors.Surface;
  FReqHeaderBar.Color := FColors.Surface;
  FRespHeaderBar.Color := FColors.Surface;
  FFooterBar.Color := FColors.Surface;

  FPropGrid.ApplyColors(FColors);
  FDiffView.ApplyColors(FColors);

  FBodyMemo.Color := FColors.SurfaceCard;
  FBodyMemo.Font.Color := FColors.TextPrimary;

  FResponseMemo.Color := FColors.SurfaceCard;
  FResponseMemo.Font.Color := FColors.TextPrimary;

  FLatencyPanel.Color := FColors.SurfaceCard;

  FBtnSend.ApplyColors(FColors);
  FBtnCurl.ApplyColors(FColors);
  FBtnBaseline.ApplyColors(FColors);
  FBtnTabParams.ApplyColors(FColors);
  FBtnTabBody.ApplyColors(FColors);
  FBtnFormatJson.ApplyColors(FColors);
  FBtnViewPretty.ApplyColors(FColors);
  FBtnViewRaw.ApplyColors(FColors);
  FBtnViewDiff.ApplyColors(FColors);
  FBtnViewLatency.ApplyColors(FColors);

  FBtnMethod.ApplyColors(FColors);

  Invalidate;
end;

procedure TVeloxRestStudio.SetMethod(const Value: TVeloxRestMethod);
begin
  FMethod := Value;
  FBtnMethod.Caption := MethodToString(FMethod);
  FBtnMethod.Invalidate;
end;

procedure TVeloxRestStudio.SetViewMode(const Value: TVeloxRestViewMode);
var
  JsonErr: string;
  J: TVeloxJson;
begin
  FViewMode := Value;
  FBtnViewPretty.Variant := vsbOutline;
  FBtnViewRaw.Variant := vsbOutline;
  FBtnViewDiff.Variant := vsbOutline;
  FBtnViewLatency.Variant := vsbOutline;

  case FViewMode of
    vrvmPrettyJson:   FBtnViewPretty.Variant := vsbPrimary;
    vrvmRawText:      FBtnViewRaw.Variant := vsbPrimary;
    vrvmDiffBaseline: FBtnViewDiff.Variant := vsbPrimary;
    vrvmLatency:      FBtnViewLatency.Variant := vsbPrimary;
  end;

  FBtnViewPretty.Invalidate;
  FBtnViewRaw.Invalidate;
  FBtnViewDiff.Invalidate;
  FBtnViewLatency.Invalidate;

  FResponseMemo.Visible := (FViewMode = vrvmPrettyJson) or (FViewMode = vrvmRawText);
  FDiffView.Visible := (FViewMode = vrvmDiffBaseline);
  FLatencyPanel.Visible := (FViewMode = vrvmLatency);

  if FViewMode = vrvmPrettyJson then
  begin
    if FLastResponse.Body <> '' then
    begin
      J := TVeloxJson.Parse(FLastResponse.Body, JsonErr);
      if Assigned(J) then
      begin
        try
          FResponseMemo.Text := J.Serialize(True);
        finally
          J.Free;
        end;
      end
      else
        FResponseMemo.Text := FLastResponse.Body;
    end;
  end
  else if FViewMode = vrvmRawText then
  begin
    FResponseMemo.Text := FLastResponse.Body;
  end
  else if FViewMode = vrvmDiffBaseline then
  begin
    FDiffView.SetDiff(FBaselineResponse, FLastResponse.Body);
  end
  else if FViewMode = vrvmLatency then
  begin
    FLatencyPanel.Invalidate;
  end;
end;

procedure TVeloxRestStudio.SetRequestTab(const Value: Integer);
begin
  FRequestTab := Value;
  if FRequestTab = 0 then
  begin
    FBtnTabParams.Variant := vsbPrimary;
    FBtnTabBody.Variant := vsbOutline;
    FPropGrid.Visible := True;
    FBodyMemo.Visible := False;
  end
  else
  begin
    FBtnTabParams.Variant := vsbOutline;
    FBtnTabBody.Variant := vsbPrimary;
    FPropGrid.Visible := False;
    FBodyMemo.Visible := True;
  end;
  FBtnTabParams.Invalidate;
  FBtnTabBody.Invalidate;
end;

function TVeloxRestStudio.GetUrl: string;
begin
  Result := Trim(FUrlEdit.Text);
end;

procedure TVeloxRestStudio.SetUrl(const Value: string);
begin
  FUrlEdit.Text := Value;
end;

function TVeloxRestStudio.GetRequestBody: string;
begin
  Result := FBodyMemo.Text;
end;

procedure TVeloxRestStudio.SetRequestBody(const Value: string);
begin
  FBodyMemo.Text := Value;
end;

function TVeloxRestStudio.BuildEffectiveUrl: string;
var
  BaseUrl, QueryStr: string;
  I: Integer;
begin
  BaseUrl := GetUrl;
  QueryStr := '';
  for I := 0 to FPropGrid.ItemCount - 1 do
  begin
    if FPropGrid.Items[I].Category = 'Query Parameters' then
    begin
      if FPropGrid.Items[I].StringValue <> '' then
      begin
        if QueryStr <> '' then
          QueryStr := QueryStr + '&'
        else
          QueryStr := '?';
        QueryStr := QueryStr + FPropGrid.Items[I].Key + '=' + FPropGrid.Items[I].StringValue;
      end;
    end;
  end;

  if (Pos('?', BaseUrl) > 0) and (QueryStr <> '') then
    Result := BaseUrl + '&' + Copy(QueryStr, 2, Length(QueryStr))
  else
    Result := BaseUrl + QueryStr;
end;

function TVeloxRestStudio.BuildHeadersString: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FPropGrid.ItemCount - 1 do
  begin
    if FPropGrid.Items[I].Category = 'Headers' then
    begin
      if FPropGrid.Items[I].StringValue <> '' then
        Result := Result + FPropGrid.Items[I].Key + ': ' + FPropGrid.Items[I].StringValue + #13#10;
    end;
  end;
end;

function TVeloxRestStudio.GenerateCurlCommand: string;
var
  MStr, FullUrl, HStr, BStr, Line: string;
  Lines: TStringList;
  I: Integer;
begin
  MStr := MethodToString(FMethod);
  FullUrl := BuildEffectiveUrl;
  Result := 'curl -X ' + MStr + ' "' + FullUrl + '"';

  HStr := BuildHeadersString;
  if HStr <> '' then
  begin
    Lines := TStringList.Create;
    try
      Lines.Text := HStr;
      for I := 0 to Lines.Count - 1 do
      begin
        Line := Trim(Lines[I]);
        if Line <> '' then
          Result := Result + ' \'#13#10'  -H "' + Line + '"';
      end;
    finally
      Lines.Free;
    end;
  end;

  if (FMethod in [vrmPOST, vrmPUT, vrmPATCH]) and (Trim(FBodyMemo.Text) <> '') then
  begin
    BStr := TVeloxExporter.EscapeJsonString(Trim(FBodyMemo.Text));
    Result := Result + ' \'#13#10'  -d "' + Trim(FBodyMemo.Text) + '"';
  end;
end;

function TVeloxRestStudio.CopyAsCurl: Boolean;
begin
  Result := TVeloxClipboard.SetText(GenerateCurlCommand);
end;

procedure TVeloxRestStudio.SaveCurrentAsBaseline;
begin
  FBaselineResponse := FLastResponse.Body;
  if FViewMode = vrvmDiffBaseline then
    FDiffView.SetDiff(FBaselineResponse, FLastResponse.Body);
  FFooterBar.Invalidate;
end;

procedure TVeloxRestStudio.PrettifyBody;
var
  J: TVeloxJson;
  Err: string;
begin
  if Trim(FBodyMemo.Text) = '' then
    Exit;
  J := TVeloxJson.Parse(FBodyMemo.Text, Err);
  if Assigned(J) then
  begin
    try
      FBodyMemo.Text := J.Serialize(True);
    finally
      J.Free;
    end;
  end;
end;

procedure TVeloxRestStudio.SetEndpoint(const AMethod: TVeloxRestMethod; const AUrl, ABody: string);
begin
  SetMethod(AMethod);
  SetUrl(AUrl);
  if ABody <> '' then
  begin
    SetRequestBody(ABody);
    SetRequestTab(1);
  end;
end;

procedure TVeloxRestStudio.SendRequest;
var
  T0, T1: UInt64;
  EffUrl, HStr, BodyStr, MStr: string;
begin
  if FIsSending then
    Exit;
  FIsSending := True;
  FBtnSend.Caption := '...';
  FBtnSend.Enabled := False;
  try
    EffUrl := BuildEffectiveUrl;
    HStr := BuildHeadersString;
    BodyStr := '';
    if FMethod in [vrmPOST, vrmPUT, vrmPATCH] then
      BodyStr := FBodyMemo.Text;

    MStr := MethodToString(FMethod);
    T0 := GetTickCount64;
    FLastResponse := TVeloxHttp.Request(MStr, EffUrl, BodyStr, HStr, 10000);
    T1 := GetTickCount64;
    FLastElapsedMs := T1 - T0;

    FLatencyHistory.Add(FLastElapsedMs);
    Inc(FRequestCount);

    SetViewMode(FViewMode);
    FRespHeaderBar.Invalidate;
    FFooterBar.Invalidate;

    if Assigned(FOnResponse) then
      FOnResponse(Self);
  finally
    FIsSending := False;
    FBtnSend.Caption := 'Send';
    FBtnSend.Enabled := True;
    FBtnSend.Invalidate;
  end;
end;

procedure TVeloxRestStudio.HandleMethodClick(Sender: TObject);
begin
  if FMethod = High(TVeloxRestMethod) then
    SetMethod(Low(TVeloxRestMethod))
  else
    SetMethod(Succ(FMethod));
end;

procedure TVeloxRestStudio.HandleSendClick(Sender: TObject);
begin
  SendRequest;
end;

procedure TVeloxRestStudio.HandleCurlClick(Sender: TObject);
begin
  CopyAsCurl;
end;

procedure TVeloxRestStudio.HandleBaselineClick(Sender: TObject);
begin
  SaveCurrentAsBaseline;
end;

procedure TVeloxRestStudio.HandleTabParamsClick(Sender: TObject);
begin
  SetRequestTab(0);
end;

procedure TVeloxRestStudio.HandleTabBodyClick(Sender: TObject);
begin
  SetRequestTab(1);
end;

procedure TVeloxRestStudio.HandleFormatJsonClick(Sender: TObject);
begin
  PrettifyBody;
end;

procedure TVeloxRestStudio.HandleViewPrettyClick(Sender: TObject);
begin
  SetViewMode(vrvmPrettyJson);
end;

procedure TVeloxRestStudio.HandleViewRawClick(Sender: TObject);
begin
  SetViewMode(vrvmRawText);
end;

procedure TVeloxRestStudio.HandleViewDiffClick(Sender: TObject);
begin
  SetViewMode(vrvmDiffBaseline);
end;

procedure TVeloxRestStudio.HandleViewLatencyClick(Sender: TObject);
begin
  SetViewMode(vrvmLatency);
end;

procedure TVeloxRestStudio.UrlEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    SendRequest;
    Key := 0;
  end;
end;

procedure TVeloxRestStudio.TopBarPaint(Sender: TObject);
var
  C: TCanvas;
begin
  C := FTopBar.Canvas;
  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, FTopBar.Height - 1);
  C.LineTo(FTopBar.Width, FTopBar.Height - 1);
end;

procedure TVeloxRestStudio.UrlContainerPaint(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
begin
  C := FUrlContainer.Canvas;
  R := Rect(0, 0, FUrlContainer.Width, FUrlContainer.Height);
  TVeloxGdiPlus.DrawCard(C, R, FColors.SurfaceCard, FColors.Border, 4);
end;

procedure TVeloxRestStudio.RespHeaderPaint(Sender: TObject);
var
  C: TCanvas;
  BadgeCol: TColor;
  StatusTxt, TimeTxt, SizeTxt: string;
begin
  C := FRespHeaderBar.Canvas;
  C.Brush.Style := bsSolid;
  C.Brush.Color := FColors.Surface;
  C.FillRect(Rect(0, 0, FRespHeaderBar.Width, FRespHeaderBar.Height));

  // Determine Status color & text
  if FLastResponse.StatusCode > 0 then
  begin
    StatusTxt := IntToStr(FLastResponse.StatusCode);
    if FLastResponse.Ok then
    begin
      BadgeCol := $99D334; // Green
      StatusTxt := StatusTxt + ' OK';
    end
    else if FLastResponse.StatusCode >= 500 then
    begin
      BadgeCol := $7171F8; // Red
      StatusTxt := StatusTxt + ' Server Error';
    end
    else
    begin
      BadgeCol := $0B9EF5; // Amber
      StatusTxt := StatusTxt + ' Error';
    end;
  end
  else if FLastResponse.ErrorText <> '' then
  begin
    BadgeCol := $7171F8;
    StatusTxt := 'Error';
  end
  else
  begin
    BadgeCol := FColors.TextSecondary;
    StatusTxt := 'Ready';
  end;

  // Status Badge
  TVeloxGdiPlus.DrawBadge(C, Rect(8, 7, 100, 27), StatusTxt, BadgeCol, $000000);

  // Time Badge
  if FLastElapsedMs > 0 then
    TimeTxt := IntToStr(FLastElapsedMs) + ' ms'
  else
    TimeTxt := '-- ms';
  TVeloxGdiPlus.DrawBadge(C, Rect(106, 7, 186, 27), TimeTxt, FColors.SurfaceCard, FColors.TextPrimary);

  // Bottom Border
  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, FRespHeaderBar.Height - 1);
  C.LineTo(FRespHeaderBar.Width, FRespHeaderBar.Height - 1);
end;

procedure TVeloxRestStudio.LatencyPanelPaint(Sender: TObject);
var
  C: TCanvas;
  R, SparkR: TRect;
  Arr: TSingleDynArray;
  MetricsStr: string;
begin
  C := FLatencyPanel.Canvas;
  R := Rect(0, 0, FLatencyPanel.Width, FLatencyPanel.Height);
  C.Brush.Style := bsSolid;
  C.Brush.Color := FColors.SurfaceCard;
  C.FillRect(R);

  // Title
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 10;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  C.TextOut(16, 16, 'HTTP Request Latency History');

  // Metrics summary
  MetricsStr := Format('Latest: %.0f ms   Average: %.0f ms   Peak: %.0f ms   Total Calls: %d',
    [FLatencyHistory.Latest, FLatencyHistory.Average, FLatencyHistory.Peak, FRequestCount]);
  C.Font.Size := 9;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  C.TextOut(16, 40, MetricsStr);

  // Sparkline Chart Area
  SparkR := Rect(16, 70, FLatencyPanel.Width - 16, FLatencyPanel.Height - 24);
  if (SparkR.Right > SparkR.Left + 20) and (SparkR.Bottom > SparkR.Top + 20) then
  begin
    TVeloxGdiPlus.DrawCard(C, SparkR, FColors.Surface, FColors.Border, 6);
    Arr := FLatencyHistory.ToArray;
    if Length(Arr) >= 2 then
    begin
      TVeloxGdiPlus.DrawSparkline(C, Rect(SparkR.Left + 8, SparkR.Top + 8, SparkR.Right - 8, SparkR.Bottom - 8),
        Arr, FColors.Accent, TVeloxUtils.BlendColor(FColors.Surface, FColors.Accent, 0.25));
    end
    else
    begin
      C.Font.Color := FColors.TextSecondary;
      C.TextOut(SparkR.Left + 20, SparkR.Top + (SparkR.Bottom - SparkR.Top) div 2 - 8,
        'Execute multiple requests to populate latency history trend.');
    end;
  end;
end;

procedure TVeloxRestStudio.FooterBarPaint(Sender: TObject);
var
  C: TCanvas;
  Txt: string;
begin
  C := FFooterBar.Canvas;
  C.Brush.Style := bsSolid;
  C.Brush.Color := FColors.Surface;
  C.FillRect(Rect(0, 0, FFooterBar.Width, FFooterBar.Height));

  C.Pen.Color := FColors.Border;
  C.Pen.Width := 1;
  C.MoveTo(0, 0);
  C.LineTo(FFooterBar.Width, 0);

  C.Font.Name := 'Segoe UI';
  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;

  Txt := 'WinHTTP 5.1 TLS 1.3 | ';
  if FLastResponse.Body <> '' then
    Txt := Txt + 'Body: ' + TVeloxUtils.FormatBytes(Length(FLastResponse.Body)) + ' | '
  else
    Txt := Txt + 'Body: 0 B | ';

  if FBaselineResponse <> '' then
    Txt := Txt + 'Baseline: ' + TVeloxUtils.FormatBytes(Length(FBaselineResponse)) + ' stored'
  else
    Txt := Txt + 'No baseline snapshot stored';

  C.TextOut(10, 5, Txt);
end;

procedure TVeloxRestStudio.Paint;
begin
  inherited Paint;
end;

procedure TVeloxRestStudio.Resize;
var
  LeftW: Integer;
begin
  inherited Resize;
  if Assigned(FUrlContainer) and Assigned(FTopBar) then
  begin
    FUrlContainer.SetBounds(86, 10, FTopBar.Width - 320, 28);
    if Assigned(FUrlEdit) then
      FUrlEdit.SetBounds(8, 5, FUrlContainer.Width - 16, 18);
    if Assigned(FBtnSend) then
      FBtnSend.SetBounds(FTopBar.Width - 224, 10, 68, 28);
    if Assigned(FBtnCurl) then
      FBtnCurl.SetBounds(FTopBar.Width - 150, 10, 58, 28);
    if Assigned(FBtnBaseline) then
      FBtnBaseline.SetBounds(FTopBar.Width - 86, 10, 76, 28);
  end;

  if Assigned(FLeftPanel) then
  begin
    LeftW := Width div 3;
    if LeftW < 280 then LeftW := 280;
    if LeftW > 450 then LeftW := 450;
    FLeftPanel.Width := LeftW;
  end;
end;

end.
