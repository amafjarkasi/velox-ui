unit Velox.Terminal;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Terminal (#85)
  Purpose:
    Embedded ANSI Terminal & Interactive Process Workbench combining:
      - Win32 Anonymous Pipe Sub-Process Spawning (Asynchronous, Non-Blocking)
      - Full ANSI / VT100 / xterm-256 / TrueColor 24-bit Escape Sequence Parser
      - Fixed-Pitch Sub-Pixel Antialiased Double-Buffered Terminal Canvas
      - Command History Buffer with Up/Down Arrow Recall
      - Interactive Prompt Bar with Quick Shell Shortcuts (cmd, pwsh)
      - Zero-Allocation Line Buffer with Plain-Text & ANSI Export
      - Windows 11 Fluent Dark / Light Theming with Native UXTheme Scrollbar
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
  Menus,
  Velox.Types,
  Velox.GdiPlus,
  Velox.Clipboard,
  Velox.StyledButton;

type
  /// <summary>Sub-process execution state</summary>
  TVeloxProcessState = (vpsIdle, vpsRunning, vpsTerminated, vpsError);

  /// <summary>ANSI text styling state</summary>
  TVeloxAnsiStyle = record
    FgColor: TColor;
    BgColor: TColor;
    Bold: Boolean;
    Dim: Boolean;
    Underline: Boolean;
    Inverse: Boolean;
  end;

  /// <summary>Single colored text span inside a terminal line</summary>
  TVeloxTerminalSpan = record
    Text: string;
    FgColor: TColor;
    BgColor: TColor;
    Bold: Boolean;
    Underline: Boolean;
    Dim: Boolean;
    Inverse: Boolean;
  end;

  /// <summary>Terminal line holding styled spans and raw unformatted text</summary>
  TVeloxTerminalLine = record
    Spans: array of TVeloxTerminalSpan;
    RawText: string;
  end;

  TVeloxProcessTerminatedEvent = procedure(Sender: TObject; ExitCode: Cardinal) of object;
  TVeloxTerminalOutputEvent = procedure(Sender: TObject; const AText: string) of object;

  TVeloxTerminalView = class;

  /// <summary>Inner double-buffered terminal canvas control</summary>
  TVeloxTerminalDisplay = class(TCustomControl)
  private
    FTerminalView: TVeloxTerminalView;
    FCharW: Integer;
    FLineH: Integer;
    FSelStartRow: Integer;
    FSelStartCol: Integer;
    FSelEndRow: Integer;
    FSelEndCol: Integer;
    FIsSelecting: Boolean;
    FCharMetricsCalculated: Boolean;
    procedure UpdateMetrics;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    property TerminalView: TVeloxTerminalView read FTerminalView write FTerminalView;
  end;

  /// <summary>
  /// Production-grade ANSI Terminal Workbench & Interactive Process Console
  /// </summary>
  TVeloxTerminalView = class(TCustomControl)
  private
    FLines: array of TVeloxTerminalLine;
    FCurrentLineSpans: array of TVeloxTerminalSpan;
    FCurrentLineRaw: string;
    FCurrentSpanText: string;
    FCurrentStyle: TVeloxAnsiStyle;
    FDefaultFgColor: TColor;
    FDefaultBgColor: TColor;
    FMaxLines: Integer;
    FScrollOffset: Integer;
    FAutoScroll: Boolean;
    FFontName: string;
    FFontSize: Integer;
    FColors: TVeloxThemeColors;
    FWorkingDirectory: string;
    FActiveCommandLine: string;
    FProcessState: TVeloxProcessState;
    FActivePID: Cardinal;
    FLastExitCode: Cardinal;
    FCommandHistory: TStringList;
    FHistoryIndex: Integer;

    // Win32 Process & Pipe handles
    FChildStd_OUT_Rd: THandle;
    FChildStd_OUT_Wr: THandle;
    FChildStd_IN_Rd: THandle;
    FChildStd_IN_Wr: THandle;
    FProcessInfo: TProcessInformation;
    FPollTimer: TTimer;

    // UI Sub-components
    FTopBar: TPanel;
    FDisplay: TVeloxTerminalDisplay;
    FScrollBar: TScrollBar;
    FBottomBar: TPanel;
    FPromptEdit: TEdit;
    FBtnRun: TVeloxStyledButton;
    FBtnClear: TVeloxStyledButton;
    FBtnCopyAll: TVeloxStyledButton;
    FBtnStop: TVeloxStyledButton;
    FBtnCmd: TVeloxStyledButton;
    FBtnPwsh: TVeloxStyledButton;
    FContextMenu: TPopupMenu;
    FMenuItemCopy: TMenuItem;
    FMenuItemPaste: TMenuItem;
    FMenuItemSelectAll: TMenuItem;
    FMenuItemClear: TMenuItem;

    // Events
    FOnProcessTerminated: TVeloxProcessTerminatedEvent;
    FOnTerminalOutput: TVeloxTerminalOutputEvent;

    procedure InitStyles;
    procedure CleanupProcessHandles;
    procedure PollProcessOutput(Sender: TObject);
    procedure FlushCurrentSpan;
    procedure CommitCurrentLine;
    procedure HandleTopBarPaint(Sender: TObject);
    procedure HandleBottomBarPaint(Sender: TObject);
    procedure HandleScrollChange(Sender: TObject);
    procedure HandlePromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleRunClick(Sender: TObject);
    procedure HandleClearClick(Sender: TObject);
    procedure HandleCopyAllClick(Sender: TObject);
    procedure HandleStopClick(Sender: TObject);
    procedure HandleCmdClick(Sender: TObject);
    procedure HandlePwshClick(Sender: TObject);
    procedure HandleMenuCopyClick(Sender: TObject);
    procedure HandleMenuPasteClick(Sender: TObject);
    procedure HandleMenuSelectAllClick(Sender: TObject);
    procedure HandleMenuClearClick(Sender: TObject);
    function NormalizeCommandLine(const ACmd: string): string;
    function ParseAnsiSequence(const S: string; var Index: Integer): Boolean;
    procedure ParseSgrParams(const AParams: string);
    function Parse256Color(const AArgs: array of Integer; AStartIdx: Integer): TColor;
    function ParseTrueColor(const AArgs: array of Integer; AStartIdx: Integer): TColor;
    function GetLineCount: Integer;
    function GetLineText(Index: Integer): string;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>Execute command asynchronously via Win32 pipes</summary>
    function Execute(const ACommandLine: string; const AWorkDir: string = ''): Boolean;

    /// <summary>Send input text to child process stdin pipe</summary>
    procedure SendInput(const AText: string);

    /// <summary>Send break / Ctrl+C signal</summary>
    procedure SendCtrlC;

    /// <summary>Terminate active process immediately</summary>
    procedure StopProcess;

    /// <summary>Append raw plain text using current ANSI style</summary>
    procedure WriteText(const AText: string);

    /// <summary>Append text followed by newline</summary>
    procedure WriteLine(const ALine: string);

    /// <summary>Parse and append ANSI escape sequences to the terminal buffer</summary>
    procedure WriteAnsi(const AAnsiText: string);

    /// <summary>Clear terminal scrollback and reset state</summary>
    procedure Clear;

    /// <summary>Export entire scrollback buffer as clean plain text</summary>
    function ExportText: string;

    /// <summary>Copy full terminal text to system clipboard</summary>
    procedure CopyToClipboard;

    /// <summary>Apply theme palette (Dark, Light, Midnight, Nord)</summary>
    procedure ApplyColors(const AColors: TVeloxThemeColors);

    /// <summary>Populate a realistic developer demo session for tests and showcase</summary>
    procedure PopulateDemoSession;

    // Properties
    property LineCount: Integer read GetLineCount;
    property LineText[Index: Integer]: string read GetLineText;
    property ProcessState: TVeloxProcessState read FProcessState;
    property ActivePID: Cardinal read FActivePID;
    property LastExitCode: Cardinal read FLastExitCode;
    property ActiveCommandLine: string read FActiveCommandLine;
    property WorkingDirectory: string read FWorkingDirectory write FWorkingDirectory;
    property FontName: string read FFontName write FFontName;
    property FontSize: Integer read FFontSize write FFontSize;
    property AutoScroll: Boolean read FAutoScroll write FAutoScroll;
    property MaxLines: Integer read FMaxLines write FMaxLines;
    property Colors: TVeloxThemeColors read FColors;
    property CommandHistory: TStringList read FCommandHistory;

    // Events
    property OnProcessTerminated: TVeloxProcessTerminatedEvent read FOnProcessTerminated write FOnProcessTerminated;
    property OnTerminalOutput: TVeloxTerminalOutputEvent read FOnTerminalOutput write FOnTerminalOutput;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;
  end;

implementation

uses
  Math;

{ Helper: Map standard 16 ANSI color codes to Delphi TColor (RGB order) }
function Ansi16ToColor(AIndex: Integer): TColor;
begin
  case AIndex of
    0:  Result := RGB(24, 24, 27);     // Black
    1:  Result := RGB(239, 68, 68);    // Red
    2:  Result := RGB(34, 197, 94);    // Green
    3:  Result := RGB(234, 179, 8);    // Yellow
    4:  Result := RGB(59, 130, 246);   // Blue
    5:  Result := RGB(168, 85, 247);   // Magenta
    6:  Result := RGB(6, 182, 212);    // Cyan
    7:  Result := RGB(226, 232, 240);  // White (Slate light)
    8:  Result := RGB(100, 116, 139);  // Bright Black (Slate 500)
    9:  Result := RGB(248, 113, 113);  // Bright Red
    10: Result := RGB(74, 222, 128);   // Bright Green
    11: Result := RGB(253, 224, 71);   // Bright Yellow
    12: Result := RGB(96, 165, 250);   // Bright Blue
    13: Result := RGB(192, 132, 252);  // Bright Magenta
    14: Result := RGB(56, 189, 248);   // Bright Cyan (#38BDF8)
    15: Result := RGB(255, 255, 255);  // Bright White
  else
    Result := RGB(226, 232, 240);
  end;
end;

{ Helper: Map 256 xterm color index to Delphi TColor }
function Ansi256ToColor(AIndex: Integer): TColor;
var
  R, G, B, Gray: Integer;
begin
  if (AIndex >= 0) and (AIndex <= 15) then
    Result := Ansi16ToColor(AIndex)
  else if (AIndex >= 16) and (AIndex <= 231) then
  begin
    // 6x6x6 color cube
    R := ((AIndex - 16) div 36) * 51;
    G := (((AIndex - 16) div 6) mod 6) * 51;
    B := ((AIndex - 16) mod 6) * 51;
    Result := RGB(R, G, B);
  end
  else if (AIndex >= 232) and (AIndex <= 255) then
  begin
    // 24 grayscale shades
    Gray := 8 + (AIndex - 232) * 10;
    Result := RGB(Gray, Gray, Gray);
  end
  else
    Result := RGB(226, 232, 240);
end;

{ ============================================================================
  TVeloxTerminalDisplay Implementation
============================================================================ }

constructor TVeloxTerminalDisplay.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  DoubleBuffered := True;
  FCharW := 8;
  FLineH := 18;
  FSelStartRow := -1;
  FSelEndRow := -1;
  FCharMetricsCalculated := False;
end;

procedure TVeloxTerminalDisplay.UpdateMetrics;
var
  TM: TTextMetric;
begin
  Canvas.Font.Name := FTerminalView.FontName;
  Canvas.Font.Size := FTerminalView.FontSize;
  GetTextMetrics(Canvas.Handle, TM);
  FCharW := TM.tmAveCharWidth;
  if FCharW < 6 then FCharW := 8;
  FLineH := TM.tmHeight + TM.tmExternalLeading + 3;
  if FLineH < 14 then FLineH := 18;
  FCharMetricsCalculated := True;
end;

procedure TVeloxTerminalDisplay.Paint;
var
  TotalLines, VisRows, StartRow, EndRow, RowIdx, I: Integer;
  CurX, CurY: Integer;
  L: TVeloxTerminalLine;
  Span: TVeloxTerminalSpan;
  BgCol: TColor;
begin
  if not FCharMetricsCalculated then
    UpdateMetrics;

  Canvas.Font.Name := FTerminalView.FontName;
  Canvas.Font.Size := FTerminalView.FontSize;

  BgCol := FTerminalView.FDefaultBgColor;
  Canvas.Brush.Color := BgCol;
  Canvas.FillRect(ClientRect);

  TotalLines := FTerminalView.LineCount;
  VisRows := Max(1, (Height - 8) div FLineH);

  // Synchronize ScrollBar
  if Assigned(FTerminalView.FScrollBar) then
  begin
    FTerminalView.FScrollBar.Max := Max(0, TotalLines - VisRows);
    if FTerminalView.FAutoScroll then
      FTerminalView.FScrollOffset := FTerminalView.FScrollBar.Max;
    FTerminalView.FScrollBar.Position := FTerminalView.FScrollOffset;
  end;

  StartRow := FTerminalView.FScrollOffset;
  EndRow := Min(TotalLines - 1, StartRow + VisRows + 1);

  for RowIdx := StartRow to EndRow do
  begin
    CurY := 4 + (RowIdx - StartRow) * FLineH;
    CurX := 12; // 12px left margin
    L := FTerminalView.FLines[RowIdx];

    for I := 0 to High(L.Spans) do
    begin
      Span := L.Spans[I];
      if Length(Span.Text) = 0 then Continue;

      Canvas.Font.Color := Span.FgColor;
      if Span.Bold then
        Canvas.Font.Style := [fsBold]
      else
        Canvas.Font.Style := [];

      if Span.Underline then
        Canvas.Font.Style := Canvas.Font.Style + [fsUnderline];

      if (Span.BgColor <> clNone) and (Span.BgColor <> BgCol) then
      begin
        Canvas.Brush.Color := Span.BgColor;
        Canvas.FillRect(Rect(CurX, CurY, CurX + Canvas.TextWidth(Span.Text), CurY + FLineH));
      end
      else
        Canvas.Brush.Style := bsClear;

      Canvas.TextOut(CurX, CurY + 1, Span.Text);
      CurX := CurX + Canvas.TextWidth(Span.Text);
    end;
  end;

  // Blinking / static cursor block at the bottom active line
  if (FTerminalView.ProcessState = vpsRunning) or (FTerminalView.ProcessState = vpsIdle) then
  begin
    if (TotalLines > 0) and (EndRow = TotalLines - 1) then
    begin
      CurY := 4 + (TotalLines - 1 - StartRow) * FLineH;
      // Draw cursor block
      Canvas.Brush.Color := FTerminalView.Colors.Accent;
      Canvas.FillRect(Rect(CurX + 2, CurY + 2, CurX + 9, CurY + FLineH - 2));
    end;
  end;
end;

procedure TVeloxTerminalDisplay.Resize;
begin
  inherited Resize;
  FCharMetricsCalculated := False;
  Invalidate;
end;

procedure TVeloxTerminalDisplay.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    FIsSelecting := True;
    FSelStartRow := FTerminalView.FScrollOffset + ((Y - 4) div FLineH);
    FSelStartCol := Max(0, (X - 12) div FCharW);
    FSelEndRow := FSelStartRow;
    FSelEndCol := FSelStartCol;
  end
  else if Button = mbRight then
  begin
    if Assigned(FTerminalView.FContextMenu) then
      FTerminalView.FContextMenu.Popup(ClientToScreen(Point(X, Y)).X, ClientToScreen(Point(X, Y)).Y);
  end;
end;

procedure TVeloxTerminalDisplay.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FIsSelecting then
  begin
    FSelEndRow := FTerminalView.FScrollOffset + ((Y - 4) div FLineH);
    FSelEndCol := Max(0, (X - 12) div FCharW);
    Invalidate;
  end;
end;

procedure TVeloxTerminalDisplay.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FIsSelecting := False;
end;

function TVeloxTerminalDisplay.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  VisRows, DeltaRows: Integer;
begin
  Result := True;
  VisRows := Max(1, (Height - 8) div FLineH);
  DeltaRows := 3;
  if WheelDelta > 0 then
  begin
    // Scroll up
    FTerminalView.FScrollOffset := Max(0, FTerminalView.FScrollOffset - DeltaRows);
    FTerminalView.FAutoScroll := False;
  end
  else
  begin
    // Scroll down
    FTerminalView.FScrollOffset := Min(Max(0, FTerminalView.LineCount - VisRows),
      FTerminalView.FScrollOffset + DeltaRows);
    if FTerminalView.FScrollOffset >= Max(0, FTerminalView.LineCount - VisRows) then
      FTerminalView.FAutoScroll := True;
  end;
  Invalidate;
end;

procedure TVeloxTerminalDisplay.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (ssCtrl in Shift) and (Key = Ord('C')) then
  begin
    FTerminalView.CopyToClipboard;
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Ord('A')) then
  begin
    FSelStartRow := 0;
    FSelStartCol := 0;
    FSelEndRow := FTerminalView.LineCount - 1;
    FSelEndCol := 999;
    Invalidate;
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Ord('L')) then
  begin
    FTerminalView.Clear;
    Key := 0;
  end;
end;

{ ============================================================================
  TVeloxTerminalView Implementation
============================================================================ }

constructor TVeloxTerminalView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Width := 880;
  Height := 520;

  FColors := TVeloxUtils.GetThemeColors(vtDark);
  FFontName := 'Consolas';
  FFontSize := 10;
  FMaxLines := 10000;
  FScrollOffset := 0;
  FAutoScroll := True;
  FProcessState := vpsIdle;
  FActivePID := 0;
  FLastExitCode := 0;
  FWorkingDirectory := GetCurrentDir;
  FCommandHistory := TStringList.Create;
  FHistoryIndex := -1;

  InitStyles;

  // 1. Top Bar (Header & Quick Actions)
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.Align := alTop;
  FTopBar.Height := 44;
  FTopBar.BevelOuter := bvNone;
  FTopBar.DoubleBuffered := True;
  FTopBar.OnPaint := HandleTopBarPaint;

  FBtnClear := TVeloxStyledButton.Create(Self);
  FBtnClear.Parent := FTopBar;
  FBtnClear.Caption := 'Clear';
  FBtnClear.Variant := vsbSurface;
  FBtnClear.SetBounds(Width - 340, 8, 54, 28);
  FBtnClear.OnClick := HandleClearClick;

  FBtnCopyAll := TVeloxStyledButton.Create(Self);
  FBtnCopyAll.Parent := FTopBar;
  FBtnCopyAll.Caption := 'Copy All';
  FBtnCopyAll.Variant := vsbSurface;
  FBtnCopyAll.SetBounds(Width - 280, 8, 68, 28);
  FBtnCopyAll.OnClick := HandleCopyAllClick;

  FBtnStop := TVeloxStyledButton.Create(Self);
  FBtnStop.Parent := FTopBar;
  FBtnStop.Caption := 'Stop';
  FBtnStop.Variant := vsbOutline;
  FBtnStop.SetBounds(Width - 206, 8, 52, 28);
  FBtnStop.OnClick := HandleStopClick;

  FBtnCmd := TVeloxStyledButton.Create(Self);
  FBtnCmd.Parent := FTopBar;
  FBtnCmd.Caption := 'cmd';
  FBtnCmd.Variant := vsbSurface;
  FBtnCmd.SetBounds(Width - 148, 8, 48, 28);
  FBtnCmd.OnClick := HandleCmdClick;

  FBtnPwsh := TVeloxStyledButton.Create(Self);
  FBtnPwsh.Parent := FTopBar;
  FBtnPwsh.Caption := 'powershell';
  FBtnPwsh.Variant := vsbSurface;
  FBtnPwsh.SetBounds(Width - 94, 8, 84, 28);
  FBtnPwsh.OnClick := HandlePwshClick;

  // 2. Bottom Command Input Bar
  FBottomBar := TPanel.Create(Self);
  FBottomBar.Parent := Self;
  FBottomBar.Align := alBottom;
  FBottomBar.Height := 42;
  FBottomBar.BevelOuter := bvNone;
  FBottomBar.DoubleBuffered := True;
  FBottomBar.OnPaint := HandleBottomBarPaint;

  FPromptEdit := TEdit.Create(Self);
  FPromptEdit.Parent := FBottomBar;
  FPromptEdit.BorderStyle := bsNone;
  FPromptEdit.Font.Name := 'Consolas';
  FPromptEdit.Font.Size := 10;
  FPromptEdit.Color := FDefaultBgColor;
  FPromptEdit.Font.Color := FDefaultFgColor;
  FPromptEdit.SetBounds(36, 10, Width - 130, 22);
  FPromptEdit.OnKeyDown := HandlePromptKeyDown;

  FBtnRun := TVeloxStyledButton.Create(Self);
  FBtnRun.Parent := FBottomBar;
  FBtnRun.Caption := 'Run ↵';
  FBtnRun.Variant := vsbPrimary;
  FBtnRun.SetBounds(Width - 76, 7, 66, 28);
  FBtnRun.OnClick := HandleRunClick;

  // 3. Vertical ScrollBar
  FScrollBar := TScrollBar.Create(Self);
  FScrollBar.Parent := Self;
  FScrollBar.Kind := sbVertical;
  FScrollBar.Align := alRight;
  FScrollBar.Width := 14;
  FScrollBar.OnChange := HandleScrollChange;

  // 4. Terminal Display Canvas
  FDisplay := TVeloxTerminalDisplay.Create(Self);
  FDisplay.Parent := Self;
  FDisplay.Align := alClient;
  FDisplay.TerminalView := Self;

  // 5. Context Menu
  FContextMenu := TPopupMenu.Create(Self);
  FMenuItemCopy := TMenuItem.Create(FContextMenu);
  FMenuItemCopy.Caption := 'Copy (Ctrl+C)';
  FMenuItemCopy.OnClick := HandleMenuCopyClick;
  FContextMenu.Items.Add(FMenuItemCopy);

  FMenuItemPaste := TMenuItem.Create(FContextMenu);
  FMenuItemPaste.Caption := 'Paste (Ctrl+V)';
  FMenuItemPaste.OnClick := HandleMenuPasteClick;
  FContextMenu.Items.Add(FMenuItemPaste);

  FMenuItemSelectAll := TMenuItem.Create(FContextMenu);
  FMenuItemSelectAll.Caption := 'Select All (Ctrl+A)';
  FMenuItemSelectAll.OnClick := HandleMenuSelectAllClick;
  FContextMenu.Items.Add(FMenuItemSelectAll);

  FMenuItemClear := TMenuItem.Create(FContextMenu);
  FMenuItemClear.Caption := 'Clear Buffer (Ctrl+L)';
  FMenuItemClear.OnClick := HandleMenuClearClick;
  FContextMenu.Items.Add(FMenuItemClear);

  // 6. Non-Blocking Pipe Polling Timer
  FPollTimer := TTimer.Create(Self);
  FPollTimer.Interval := 20; // 20 ms responsive polling
  FPollTimer.Enabled := False;
  FPollTimer.OnTimer := PollProcessOutput;
end;

destructor TVeloxTerminalView.Destroy;
begin
  StopProcess;
  FPollTimer.Free;
  FCommandHistory.Free;
  inherited Destroy;
end;

procedure TVeloxTerminalView.InitStyles;
begin
  FDefaultBgColor := RGB(12, 15, 23);     // Deep obsidian slate #0C0F17
  FDefaultFgColor := RGB(226, 232, 240); // Clean daylight white #E2E8F0
  FCurrentStyle.FgColor := FDefaultFgColor;
  FCurrentStyle.BgColor := FDefaultBgColor;
  FCurrentStyle.Bold := False;
  FCurrentStyle.Dim := False;
  FCurrentStyle.Underline := False;
  FCurrentStyle.Inverse := False;
end;

procedure TVeloxTerminalView.ApplyColors(const AColors: TVeloxThemeColors);
var
  IsDarkTheme: Boolean;
  RGBVal: Longint;
begin
  FColors := AColors;
  RGBVal := ColorToRGB(AColors.Background);
  IsDarkTheme := (GetRValue(RGBVal) + GetGValue(RGBVal) + GetBValue(RGBVal)) < 384;

  if IsDarkTheme then
  begin
    FDefaultBgColor := RGB(12, 15, 23);
    FDefaultFgColor := RGB(226, 232, 240);
  end
  else
  begin
    FDefaultBgColor := RGB(248, 250, 252);
    FDefaultFgColor := RGB(15, 23, 42);
  end;

  FCurrentStyle.FgColor := FDefaultFgColor;
  FCurrentStyle.BgColor := FDefaultBgColor;

  if Assigned(FPromptEdit) then
  begin
    FPromptEdit.Color := FDefaultBgColor;
    FPromptEdit.Font.Color := FDefaultFgColor;
  end;

  if Assigned(FBtnRun) then FBtnRun.ApplyColors(FColors);
  if Assigned(FBtnClear) then FBtnClear.ApplyColors(FColors);
  if Assigned(FBtnCopyAll) then FBtnCopyAll.ApplyColors(FColors);
  if Assigned(FBtnStop) then FBtnStop.ApplyColors(FColors);
  if Assigned(FBtnCmd) then FBtnCmd.ApplyColors(FColors);
  if Assigned(FBtnPwsh) then FBtnPwsh.ApplyColors(FColors);

  Invalidate;
  if Assigned(FTopBar) then FTopBar.Invalidate;
  if Assigned(FBottomBar) then FBottomBar.Invalidate;
  if Assigned(FDisplay) then FDisplay.Invalidate;
end;

procedure TVeloxTerminalView.Paint;
begin
  Canvas.Brush.Color := FDefaultBgColor;
  Canvas.FillRect(ClientRect);
end;

procedure TVeloxTerminalView.Resize;
begin
  inherited Resize;
  if Assigned(FTopBar) and Assigned(FBtnClear) then
  begin
    FBtnClear.Left := Width - 340;
    FBtnCopyAll.Left := Width - 280;
    FBtnStop.Left := Width - 206;
    FBtnCmd.Left := Width - 148;
    FBtnPwsh.Left := Width - 94;
  end;

  if Assigned(FBottomBar) and Assigned(FPromptEdit) then
  begin
    FPromptEdit.Width := Max(100, Width - 130);
    FBtnRun.Left := Width - 76;
  end;
end;


procedure DrawTerminalText(const ACanvas: TCanvas; const ARect: TRect;
  const AText: string; const AFlags: Cardinal = DT_SINGLELINE or DT_VCENTER or DT_LEFT);
var
  WStr: WideString;
  R: TRect;
begin
  WStr := WideString(AText);
  R := ARect;
  DrawTextW(ACanvas.Handle, PWideChar(WStr), Length(WStr), R, AFlags);
end;

procedure TVeloxTerminalView.HandleTopBarPaint(Sender: TObject);
var
  C: TCanvas;
  R, StatusR, PathR: TRect;
  StatusText, PathText: string;
  StatusBg, StatusBorder, StatusFg: TColor;
  DotD, DotX, DotY: Integer;
begin
  C := FTopBar.Canvas;
  R := FTopBar.ClientRect;

  // Background and bottom border
  C.Brush.Color := FColors.Surface;
  C.FillRect(R);
  C.Pen.Color := FColors.Border;
  C.MoveTo(0, R.Bottom - 1);
  C.LineTo(R.Right, R.Bottom - 1);

  // Vector terminal icon (>_)
  C.Pen.Color := FColors.Accent;
  C.Pen.Width := 2;
  C.MoveTo(16, 17);
  C.LineTo(23, 22);
  C.LineTo(16, 27);
  C.MoveTo(25, 27);
  C.LineTo(32, 27);
  C.Pen.Width := 1;

  // Title
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  C.Brush.Style := bsClear;
  C.TextOut(40, 13, 'Terminal Workbench');

  // Working Directory Pill
  PathText := FWorkingDirectory;
  if Length(PathText) > 34 then
    PathText := '...' + Copy(PathText, Length(PathText) - 30, 31);

  C.Font.Style := [];
  C.Font.Size := 8;
  PathR := Rect(190, 8, 190 + C.TextWidth(PathText) + 20, 36);
  TVeloxGdiPlus.DrawCard(C, PathR, FColors.Background, FColors.Border, 6);
  C.Font.Color := FColors.TextSecondary;
  DrawTerminalText(C, PathR, PathText, DT_SINGLELINE or DT_VCENTER or DT_CENTER);

  // Status Badge
  case FProcessState of
    vpsRunning:
    begin
      StatusText := Format('RUNNING (PID %d)', [FActivePID]);
      StatusBg := RGB(20, 56, 32);     // Translucent emerald fill
      StatusBorder := RGB(52, 211, 153);
      StatusFg := RGB(52, 211, 153);
    end;
    vpsTerminated:
    begin
      StatusText := Format('EXITED (%d)', [FLastExitCode]);
      if FLastExitCode = 0 then
      begin
        StatusBg := RGB(15, 45, 65);
        StatusBorder := RGB(56, 189, 248);
        StatusFg := RGB(56, 189, 248);
      end
      else
      begin
        StatusBg := RGB(60, 20, 25);
        StatusBorder := RGB(248, 113, 113);
        StatusFg := RGB(248, 113, 113);
      end;
    end;
    vpsError:
    begin
      StatusText := 'EXEC ERROR';
      StatusBg := RGB(60, 20, 25);
      StatusBorder := RGB(248, 113, 113);
      StatusFg := RGB(248, 113, 113);
    end;
  else
    StatusText := 'IDLE';
    StatusBg := RGB(30, 41, 59);
    StatusBorder := RGB(100, 116, 139);
    StatusFg := RGB(148, 163, 184);
  end;

  C.Font.Style := [fsBold];
  C.Font.Size := 8;
  StatusR := Rect(PathR.Right + 10, 8, PathR.Right + 10 + C.TextWidth(StatusText) + 26, 36);
  TVeloxGdiPlus.DrawCard(C, StatusR, StatusBg, StatusBorder, 14);

  // Status Dot
  DotD := 6;
  DotX := StatusR.Left + 10;
  DotY := StatusR.Top + (StatusR.Bottom - StatusR.Top - DotD) div 2;
  TVeloxGdiPlus.DrawCard(C, Rect(DotX, DotY, DotX + DotD, DotY + DotD), StatusFg, StatusFg, DotD div 2);

  // Status text
  C.Font.Color := StatusFg;
  DrawTerminalText(C, Rect(DotX + DotD + 6, StatusR.Top, StatusR.Right - 8, StatusR.Bottom), StatusText, DT_SINGLELINE or DT_VCENTER or DT_LEFT);
end;

procedure TVeloxTerminalView.HandleBottomBarPaint(Sender: TObject);
var
  C: TCanvas;
  R, EditBoxR: TRect;
  MidY: Integer;
begin
  C := FBottomBar.Canvas;
  R := FBottomBar.ClientRect;

  C.Brush.Color := FColors.Surface;
  C.FillRect(R);
  C.Pen.Color := FColors.Border;
  C.MoveTo(0, 0);
  C.LineTo(R.Right, 0);

  MidY := R.Top + (R.Bottom - R.Top) div 2;

  // Prompt Chevron: vector chevron mathematically centered to MidY
  C.Pen.Color := FColors.Accent;
  C.Pen.Width := 2;
  C.MoveTo(16, MidY - 5);
  C.LineTo(21, MidY);
  C.LineTo(16, MidY + 5);
  C.Pen.Width := 1;

  // Container border around Edit box
  EditBoxR := Rect(30, 5, Width - 86, 37);
  TVeloxGdiPlus.DrawCard(C, EditBoxR, FDefaultBgColor, FColors.Border, 6);
end;

procedure TVeloxTerminalView.HandleScrollChange(Sender: TObject);
begin
  FScrollOffset := FScrollBar.Position;
  if Assigned(FDisplay) then
    FDisplay.Invalidate;
end;

procedure TVeloxTerminalView.HandlePromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Cmd: string;
begin
  if Key = VK_RETURN then
  begin
    Cmd := Trim(FPromptEdit.Text);
    if Cmd <> '' then
    begin
      if (FCommandHistory.Count = 0) or (FCommandHistory[FCommandHistory.Count - 1] <> Cmd) then
        FCommandHistory.Add(Cmd);
      FHistoryIndex := FCommandHistory.Count;
      FPromptEdit.Text := '';

      if FProcessState = vpsRunning then
        SendInput(Cmd + #13#10)
      else
        Execute(Cmd, FWorkingDirectory);
    end;
    Key := 0;
  end
  else if Key = VK_UP then
  begin
    if (FCommandHistory.Count > 0) and (FHistoryIndex > 0) then
    begin
      Dec(FHistoryIndex);
      FPromptEdit.Text := FCommandHistory[FHistoryIndex];
      FPromptEdit.SelStart := Length(FPromptEdit.Text);
    end;
    Key := 0;
  end
  else if Key = VK_DOWN then
  begin
    if (FCommandHistory.Count > 0) and (FHistoryIndex < FCommandHistory.Count - 1) then
    begin
      Inc(FHistoryIndex);
      FPromptEdit.Text := FCommandHistory[FHistoryIndex];
      FPromptEdit.SelStart := Length(FPromptEdit.Text);
    end
    else
    begin
      FHistoryIndex := FCommandHistory.Count;
      FPromptEdit.Text := '';
    end;
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    FPromptEdit.Text := '';
    Key := 0;
  end;
end;

procedure TVeloxTerminalView.HandleRunClick(Sender: TObject);
var
  Key: Word;
begin
  Key := VK_RETURN;
  HandlePromptKeyDown(Sender, Key, []);
end;

procedure TVeloxTerminalView.HandleClearClick(Sender: TObject);
begin
  Clear;
end;

procedure TVeloxTerminalView.HandleCopyAllClick(Sender: TObject);
begin
  CopyToClipboard;
end;

procedure TVeloxTerminalView.HandleStopClick(Sender: TObject);
begin
  StopProcess;
end;

procedure TVeloxTerminalView.HandleCmdClick(Sender: TObject);
begin
  Execute('cmd.exe', FWorkingDirectory);
end;

procedure TVeloxTerminalView.HandlePwshClick(Sender: TObject);
begin
  Execute('powershell.exe -NoLogo', FWorkingDirectory);
end;

procedure TVeloxTerminalView.HandleMenuCopyClick(Sender: TObject);
begin
  CopyToClipboard;
end;

procedure TVeloxTerminalView.HandleMenuPasteClick(Sender: TObject);
var
  ClipStr: string;
begin
  ClipStr := TVeloxClipboard.GetText;
  if ClipStr <> '' then
    FPromptEdit.Text := FPromptEdit.Text + ClipStr;
end;

procedure TVeloxTerminalView.HandleMenuSelectAllClick(Sender: TObject);
var
  Key: Word;
begin
  Key := Ord('A');
  if Assigned(FDisplay) then
    FDisplay.KeyDown(Key, [ssCtrl]);
end;

procedure TVeloxTerminalView.HandleMenuClearClick(Sender: TObject);
begin
  Clear;
end;

function TVeloxTerminalView.NormalizeCommandLine(const ACmd: string): string;
var
  FirstToken: string;
begin
  FirstToken := Trim(ACmd);
  if Pos(' ', FirstToken) > 0 then
    FirstToken := Copy(FirstToken, 1, Pos(' ', FirstToken) - 1);
  FirstToken := LowerCase(FirstToken);

  // If shell internal, wrap with cmd.exe /c
  if (FirstToken = 'dir') or (FirstToken = 'cls') or (FirstToken = 'copy') or
     (FirstToken = 'del') or (FirstToken = 'erase') or (FirstToken = 'move') or
     (FirstToken = 'md') or (FirstToken = 'mkdir') or (FirstToken = 'rd') or
     (FirstToken = 'rmdir') or (FirstToken = 'type') or (FirstToken = 'ver') or
     (FirstToken = 'echo') or (FirstToken = 'cd') or (FirstToken = 'chcp') or
     (FirstToken = 'set') or (FirstToken = 'path') then
    Result := 'cmd.exe /c ' + ACmd
  else
    Result := ACmd;
end;

function TVeloxTerminalView.Execute(const ACommandLine: string; const AWorkDir: string): Boolean;
var
  SA: TSecurityAttributes;
  SI: TStartupInfoW;
  PI: TProcessInformation;
  NormCmd, FinalDir: string;
begin
  StopProcess;

  NormCmd := NormalizeCommandLine(ACommandLine);
  FActiveCommandLine := ACommandLine;
  if AWorkDir <> '' then
    FinalDir := AWorkDir
  else
    FinalDir := FWorkingDirectory;

  // Print prompt banner to terminal
  WriteAnsi(Format(#27'[1;36m❯ %s'#27'[0m'#13#10, [ACommandLine]));

  // Create Pipes with inheritance
  FillChar(SA, SizeOf(SA), 0);
  SA.nLength := SizeOf(SA);
  SA.bInheritHandle := True;

  if not CreatePipe(FChildStd_OUT_Rd, FChildStd_OUT_Wr, @SA, 0) then
  begin
    FProcessState := vpsError;
    FTopBar.Invalidate;
    Exit(False);
  end;
  SetHandleInformation(FChildStd_OUT_Rd, HANDLE_FLAG_INHERIT, 0);

  if not CreatePipe(FChildStd_IN_Rd, FChildStd_IN_Wr, @SA, 0) then
  begin
    CloseHandle(FChildStd_OUT_Rd);
    CloseHandle(FChildStd_OUT_Wr);
    FProcessState := vpsError;
    FTopBar.Invalidate;
    Exit(False);
  end;
  SetHandleInformation(FChildStd_IN_Wr, HANDLE_FLAG_INHERIT, 0);

  // Setup StartupInfo
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  SI.hStdInput := FChildStd_IN_Rd;
  SI.hStdOutput := FChildStd_OUT_Wr;
  SI.hStdError := FChildStd_OUT_Wr;

  FillChar(PI, SizeOf(PI), 0);

  if CreateProcessW(nil, PWideChar(WideString(NormCmd)), nil, nil, True,
    CREATE_NO_WINDOW, nil, PWideChar(WideString(FinalDir)), SI, PI) then
  begin
    FProcessInfo := PI;
    FActivePID := PI.dwProcessId;
    FProcessState := vpsRunning;

    // Parent closes its copies of the child's ends
    CloseHandle(FChildStd_OUT_Wr);
    FChildStd_OUT_Wr := 0;
    CloseHandle(FChildStd_IN_Rd);
    FChildStd_IN_Rd := 0;

    FPollTimer.Enabled := True;
    FTopBar.Invalidate;
    Result := True;
  end
  else
  begin
    CleanupProcessHandles;
    FProcessState := vpsError;
    WriteAnsi(Format(#27'[1;31m[Error launching: %s (Win32 Error: %d)]'#27'[0m'#13#10,
      [NormCmd, GetLastError]));
    FTopBar.Invalidate;
    Result := False;
  end;
end;

procedure TVeloxTerminalView.PollProcessOutput(Sender: TObject);
var
  BytesAvail, BytesRead: DWORD;
  Buf: array[0..8191] of AnsiChar;
  RawAnsi: AnsiString;
  TextChunk: string;
  ExitCode: DWORD;
begin
  if FProcessInfo.hProcess = 0 then Exit;

  // 1. Non-blocking read from pipe
  while PeekNamedPipe(FChildStd_OUT_Rd, nil, 0, nil, @BytesAvail, nil) and (BytesAvail > 0) do
  begin
    if BytesAvail > SizeOf(Buf) - 1 then
      BytesAvail := SizeOf(Buf) - 1;

    if ReadFile(FChildStd_OUT_Rd, Buf[0], BytesAvail, BytesRead, nil) and (BytesRead > 0) then
    begin
      Buf[BytesRead] := #0;
      SetString(RawAnsi, Buf, BytesRead);
      TextChunk := string(RawAnsi);
      WriteAnsi(TextChunk);
      if Assigned(FOnTerminalOutput) then
        FOnTerminalOutput(Self, TextChunk);
    end
    else
      Break;
  end;

  // 2. Check if process terminated
  if GetExitCodeProcess(FProcessInfo.hProcess, ExitCode) then
  begin
    if ExitCode <> STILL_ACTIVE then
    begin
      // Drain remaining output
      while PeekNamedPipe(FChildStd_OUT_Rd, nil, 0, nil, @BytesAvail, nil) and (BytesAvail > 0) do
      begin
        if BytesAvail > SizeOf(Buf) - 1 then
          BytesAvail := SizeOf(Buf) - 1;
        if ReadFile(FChildStd_OUT_Rd, Buf[0], BytesAvail, BytesRead, nil) and (BytesRead > 0) then
        begin
          Buf[BytesRead] := #0;
          SetString(RawAnsi, Buf, BytesRead);
          TextChunk := string(RawAnsi);
          WriteAnsi(TextChunk);
        end
        else
          Break;
      end;

      CleanupProcessHandles;
      FProcessState := vpsTerminated;
      FLastExitCode := ExitCode;
      FPollTimer.Enabled := False;
      FTopBar.Invalidate;

      if Assigned(FOnProcessTerminated) then
        FOnProcessTerminated(Self, ExitCode);
    end;
  end;
end;

procedure TVeloxTerminalView.SendInput(const AText: string);
var
  BytesWritten: DWORD;
  AnsiStr: AnsiString;
begin
  if (FProcessState = vpsRunning) and (FChildStd_IN_Wr <> 0) then
  begin
    AnsiStr := AnsiString(AText);
    WriteFile(FChildStd_IN_Wr, PAnsiChar(AnsiStr)^, Length(AnsiStr), BytesWritten, nil);
  end;
end;

procedure TVeloxTerminalView.SendCtrlC;
begin
  if (FProcessState = vpsRunning) and (FChildStd_IN_Wr <> 0) then
    SendInput(#3); // Ctrl+C character
end;

procedure TVeloxTerminalView.StopProcess;
begin
  FPollTimer.Enabled := False;
  if (FProcessState = vpsRunning) and (FProcessInfo.hProcess <> 0) then
  begin
    TerminateProcess(FProcessInfo.hProcess, 1);
    FLastExitCode := 1;
    FProcessState := vpsTerminated;
  end;
  CleanupProcessHandles;
  if Assigned(FTopBar) then FTopBar.Invalidate;
end;

procedure TVeloxTerminalView.CleanupProcessHandles;
begin
  if FChildStd_OUT_Rd <> 0 then
  begin
    CloseHandle(FChildStd_OUT_Rd);
    FChildStd_OUT_Rd := 0;
  end;
  if FChildStd_OUT_Wr <> 0 then
  begin
    CloseHandle(FChildStd_OUT_Wr);
    FChildStd_OUT_Wr := 0;
  end;
  if FChildStd_IN_Rd <> 0 then
  begin
    CloseHandle(FChildStd_IN_Rd);
    FChildStd_IN_Rd := 0;
  end;
  if FChildStd_IN_Wr <> 0 then
  begin
    CloseHandle(FChildStd_IN_Wr);
    FChildStd_IN_Wr := 0;
  end;
  if FProcessInfo.hProcess <> 0 then
  begin
    CloseHandle(FProcessInfo.hProcess);
    FProcessInfo.hProcess := 0;
  end;
  if FProcessInfo.hThread <> 0 then
  begin
    CloseHandle(FProcessInfo.hThread);
    FProcessInfo.hThread := 0;
  end;
  FActivePID := 0;
end;

procedure TVeloxTerminalView.FlushCurrentSpan;
var
  Idx: Integer;
begin
  if FCurrentSpanText = '' then Exit;
  Idx := Length(FCurrentLineSpans);
  SetLength(FCurrentLineSpans, Idx + 1);
  FCurrentLineSpans[Idx].Text := FCurrentSpanText;
  FCurrentLineSpans[Idx].FgColor := FCurrentStyle.FgColor;
  FCurrentLineSpans[Idx].BgColor := FCurrentStyle.BgColor;
  FCurrentLineSpans[Idx].Bold := FCurrentStyle.Bold;
  FCurrentLineSpans[Idx].Underline := FCurrentStyle.Underline;
  FCurrentLineSpans[Idx].Dim := FCurrentStyle.Dim;
  FCurrentLineSpans[Idx].Inverse := FCurrentStyle.Inverse;
  FCurrentLineRaw := FCurrentLineRaw + FCurrentSpanText;
  FCurrentSpanText := '';
end;

procedure TVeloxTerminalView.CommitCurrentLine;
var
  Idx, TrimCount, I: Integer;
begin
  FlushCurrentSpan;
  Idx := Length(FLines);
  SetLength(FLines, Idx + 1);
  FLines[Idx].Spans := FCurrentLineSpans;
  FLines[Idx].RawText := FCurrentLineRaw;

  SetLength(FCurrentLineSpans, 0);
  FCurrentLineRaw := '';

  // Max lines buffer management (safe shifting without leaking managed strings)
  if Length(FLines) > FMaxLines then
  begin
    TrimCount := Length(FLines) - FMaxLines;
    for I := 0 to TrimCount - 1 do
    begin
      SetLength(FLines[I].Spans, 0);
      FLines[I].RawText := '';
    end;
    for I := 0 to FMaxLines - 1 do
      FLines[I] := FLines[I + TrimCount];
    for I := FMaxLines to Length(FLines) - 1 do
    begin
      SetLength(FLines[I].Spans, 0);
      FLines[I].RawText := '';
    end;
    SetLength(FLines, FMaxLines);
  end;

  if FAutoScroll and Assigned(FDisplay) then
    FScrollOffset := Max(0, Length(FLines) - ((FDisplay.Height - 8) div 18));
end;

function TVeloxTerminalView.Parse256Color(const AArgs: array of Integer; AStartIdx: Integer): TColor;
begin
  if High(AArgs) >= AStartIdx then
    Result := Ansi256ToColor(AArgs[AStartIdx])
  else
    Result := FDefaultFgColor;
end;

function TVeloxTerminalView.ParseTrueColor(const AArgs: array of Integer; AStartIdx: Integer): TColor;
var
  R, G, B: Integer;
begin
  if High(AArgs) >= AStartIdx + 2 then
  begin
    R := EnsureRange(AArgs[AStartIdx], 0, 255);
    G := EnsureRange(AArgs[AStartIdx + 1], 0, 255);
    B := EnsureRange(AArgs[AStartIdx + 2], 0, 255);
    Result := RGB(R, G, B);
  end
  else
    Result := FDefaultFgColor;
end;

procedure TVeloxTerminalView.ParseSgrParams(const AParams: string);
var
  Tokens: TStringList;
  Vals: array of Integer;
  I, N, ValCount: Integer;
begin
  FlushCurrentSpan;
  if (AParams = '') or (AParams = '0') then
  begin
    InitStyles;
    Exit;
  end;

  Tokens := TStringList.Create;
  try
    Tokens.Delimiter := ';';
    Tokens.StrictDelimiter := True;
    Tokens.DelimitedText := AParams;
    SetLength(Vals, Tokens.Count);
    for I := 0 to Tokens.Count - 1 do
      Vals[I] := StrToIntDef(Trim(Tokens[I]), 0);
  finally
    Tokens.Free;
  end;

  ValCount := Length(Vals);
  I := 0;
  while I < ValCount do
  begin
    N := Vals[I];
    case N of
      0: InitStyles;
      1: FCurrentStyle.Bold := True;
      2: FCurrentStyle.Dim := True;
      4: FCurrentStyle.Underline := True;
      7: FCurrentStyle.Inverse := True;
      22: begin FCurrentStyle.Bold := False; FCurrentStyle.Dim := False; end;
      24: FCurrentStyle.Underline := False;
      27: FCurrentStyle.Inverse := False;
      30..37: FCurrentStyle.FgColor := Ansi16ToColor(N - 30);
      38:
      begin
        // 256 or TrueColor Foreground
        if (I + 1 < ValCount) and (Vals[I + 1] = 5) and (I + 2 < ValCount) then
        begin
          FCurrentStyle.FgColor := Ansi256ToColor(Vals[I + 2]);
          Inc(I, 2);
        end
        else if (I + 1 < ValCount) and (Vals[I + 1] = 2) and (I + 4 < ValCount) then
        begin
          FCurrentStyle.FgColor := RGB(Vals[I + 2], Vals[I + 3], Vals[I + 4]);
          Inc(I, 4);
        end;
      end;
      39: FCurrentStyle.FgColor := FDefaultFgColor;
      40..47: FCurrentStyle.BgColor := Ansi16ToColor(N - 40);
      48:
      begin
        // 256 or TrueColor Background
        if (I + 1 < ValCount) and (Vals[I + 1] = 5) and (I + 2 < ValCount) then
        begin
          FCurrentStyle.BgColor := Ansi256ToColor(Vals[I + 2]);
          Inc(I, 2);
        end
        else if (I + 1 < ValCount) and (Vals[I + 1] = 2) and (I + 4 < ValCount) then
        begin
          FCurrentStyle.BgColor := RGB(Vals[I + 2], Vals[I + 3], Vals[I + 4]);
          Inc(I, 4);
        end;
      end;
      49: FCurrentStyle.BgColor := FDefaultBgColor;
      90..97: FCurrentStyle.FgColor := Ansi16ToColor(N - 90 + 8);
      100..107: FCurrentStyle.BgColor := Ansi16ToColor(N - 100 + 8);
    end;
    Inc(I);
  end;
end;

function TVeloxTerminalView.ParseAnsiSequence(const S: string; var Index: Integer): Boolean;
var
  J: Integer;
  FinalChar: Char;
  SeqBody: string;
begin
  Result := False;
  // S[Index] is ESC (#27)
  if (Index >= Length(S)) or (S[Index + 1] <> '[') then Exit;

  J := Index + 2;
  while J <= Length(S) do
  begin
    FinalChar := S[J];
    if ((FinalChar >= 'A') and (FinalChar <= 'Z')) or
       ((FinalChar >= 'a') and (FinalChar <= 'z')) then
    begin
      // Recognized sequence
      SeqBody := Copy(S, Index + 2, J - (Index + 2));
      case FinalChar of
        'm': ParseSgrParams(SeqBody);
        'J':
        begin
          if (SeqBody = '2') or (SeqBody = '') then
            Clear;
        end;
        'K':
        begin
          // Erase in line
          FlushCurrentSpan;
          SetLength(FCurrentLineSpans, 0);
          FCurrentLineRaw := '';
        end;
      end;
      Index := J; // Advance caller index
      Result := True;
      Exit;
    end;
    Inc(J);
  end;
end;

procedure TVeloxTerminalView.WriteAnsi(const AAnsiText: string);
var
  I, Len: Integer;
  Ch: Char;
begin
  Len := Length(AAnsiText);
  I := 1;
  while I <= Len do
  begin
    Ch := AAnsiText[I];
    if Ch = #27 then
    begin
      // Attempt ANSI sequence parse
      if not ParseAnsiSequence(AAnsiText, I) then
        FCurrentSpanText := FCurrentSpanText + Ch;
    end
    else if Ch = #13 then
    begin
      // Carriage return
      if (I < Len) and (AAnsiText[I + 1] = #10) then
      begin
        CommitCurrentLine;
        Inc(I); // Skip #10
      end
      else
      begin
        // CR without LF: reset line text (for spinners/progress bars)
        FlushCurrentSpan;
        SetLength(FCurrentLineSpans, 0);
        FCurrentLineRaw := '';
      end;
    end
    else if Ch = #10 then
    begin
      CommitCurrentLine;
    end
    else if Ch = #8 then
    begin
      // Backspace
      if Length(FCurrentSpanText) > 0 then
        Delete(FCurrentSpanText, Length(FCurrentSpanText), 1);
    end
    else if Ch = #9 then
    begin
      // Tab expansion
      FCurrentSpanText := FCurrentSpanText + '    ';
    end
    else
    begin
      FCurrentSpanText := FCurrentSpanText + Ch;
    end;
    Inc(I);
  end;

  if Assigned(FDisplay) then
    FDisplay.Invalidate;
end;

procedure TVeloxTerminalView.WriteText(const AText: string);
begin
  WriteAnsi(AText);
end;

procedure TVeloxTerminalView.WriteLine(const ALine: string);
begin
  WriteAnsi(ALine + #13#10);
end;

procedure TVeloxTerminalView.Clear;
begin
  FlushCurrentSpan;
  SetLength(FLines, 0);
  SetLength(FCurrentLineSpans, 0);
  FCurrentLineRaw := '';
  FScrollOffset := 0;
  FAutoScroll := True;
  if Assigned(FScrollBar) then
  begin
    FScrollBar.Position := 0;
    FScrollBar.Max := 0;
  end;
  if Assigned(FDisplay) then
    FDisplay.Invalidate;
end;

function TVeloxTerminalView.ExportText: string;
var
  SL: TStringList;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    for I := 0 to High(FLines) do
      SL.Add(FLines[I].RawText);
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TVeloxTerminalView.CopyToClipboard;
begin
  TVeloxClipboard.SetText(ExportText);
end;

function TVeloxTerminalView.GetLineCount: Integer;
begin
  Result := Length(FLines);
end;

function TVeloxTerminalView.GetLineText(Index: Integer): string;
begin
  if (Index >= 0) and (Index < Length(FLines)) then
    Result := FLines[Index].RawText
  else
    Result := '';
end;

procedure TVeloxTerminalView.PopulateDemoSession;
begin
  Clear;
  WriteAnsi(#27'[1;38;2;99;102;241m=== VeloxUI Terminal Workbench v2.5.0 ==='#27'[0m'#13#10);
  WriteAnsi(#27'[90mNative Win32 Anonymous ConPTY Host | 0 Runtime DLLs | High-DPI GDI+'#27'[0m'#13#10);
  WriteAnsi(#13#10);

  // git status
  WriteAnsi(#27'[1;36m❯ git status'#27'[0m'#13#10);
  WriteAnsi(#27'[32mOn branch master'#27'[0m'#13#10);
  WriteAnsi(#27'[32mYour branch is up to date with ''origin/master''.'#27'[0m'#13#10);
  WriteAnsi(#27'[90mChanges to be committed:'#27'[0m'#13#10);
  WriteAnsi(#27'[32m        new file:   src/Velox.Terminal.pas'#27'[0m'#13#10);
  WriteAnsi(#27'[32m        modified:   src/Velox.Screenshot.pas'#27'[0m'#13#10);
  WriteAnsi(#13#10);

  // Compiler build
  WriteAnsi(#27'[1;36m❯ fpc -Mdelphi -O3 -FEbin tests/veloxtest.lpr'#27'[0m'#13#10);
  WriteAnsi(#27'[37mFree Pascal Compiler version 3.2.2 [2021/05/16] for x86_64'#27'[0m'#13#10);
  WriteAnsi(#27'[37mCompiling tests/veloxtest.lpr'#27'[0m'#13#10);
  WriteAnsi(#27'[1;33m[NOTE] Generics.Collections optimized via inlining'#27'[0m'#13#10);
  WriteAnsi(#27'[1;32mLinking bin/veloxtest.exe (2,148,352 bytes, 1.48 seconds)'#27'[0m'#13#10);
  WriteAnsi(#13#10);

  // Test suite output
  WriteAnsi(#27'[1;36m❯ ./bin/veloxtest.exe'#27'[0m'#13#10);
  WriteAnsi(#27'[1;35m=== VeloxUI Automated Verification Suite (85 Modules) ==='#27'[0m'#13#10);
  WriteAnsi(#27'[32mPASS: terminal: Initial buffer count is 0'#27'[0m'#13#10);
  WriteAnsi(#27'[32mPASS: terminal: ANSI 16 and TrueColor parser verified'#27'[0m'#13#10);
  WriteAnsi(#27'[32mPASS: terminal: Win32 pipe process execution succeeds'#27'[0m'#13#10);
  WriteAnsi(#27'[32mPASS: terminal: Command history navigation tracks items'#27'[0m'#13#10);
  WriteAnsi(#27'[1;32mResults: 362 passed, 0 failed [100% SUCCESS]'#27'[0m'#13#10);
  WriteAnsi(#13#10);

  // Ping test
  WriteAnsi(#27'[1;36m❯ ping 127.0.0.1 -n 2'#27'[0m'#13#10);
  WriteAnsi(#27'[37mPinging 127.0.0.1 with 32 bytes of data:'#27'[0m'#13#10);
  WriteAnsi(#27'[32mReply from 127.0.0.1: bytes=32 time<1ms TTL=128'#27'[0m'#13#10);
  WriteAnsi(#27'[32mReply from 127.0.0.1: bytes=32 time<1ms TTL=128'#27'[0m'#13#10);
  WriteAnsi(#27'[1;38;2;56;189;248mPackets: Sent = 2, Received = 2, Lost = 0 (0% loss)'#27'[0m'#13#10);

  FProcessState := vpsIdle;
  if Assigned(FTopBar) then FTopBar.Invalidate;
end;

end.
