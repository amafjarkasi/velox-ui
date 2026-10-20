unit Velox.Controls;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Controls
  Purpose:
    Eliminates the 4 hardest Win32 / LCL / VCL desktop control bugs & boilerplate:
    1. Search Box Vertical Centering & Focus Ring (`TVeloxSearchBox`):
       Standard Win32 bordered TEdits clip placeholder text against the top-left
       border and cannot be vertically padded. `TVeloxSearchBox` wraps a
       borderless `bsNone` TEdit inside a custom-bordered TPanel with exact
       vertical centering `(Height - 16) div 2` and a 10px left margin.
    2. High-DPI TComboBox Closed-Box Height Sync (`SyncComboBoxHeight`):
       Win32 TComboBox ignores `.Height` and computes outer height from
       `CB_SETITEMHEIGHT ($0151) + 2*SM_CYEDGE`. `SyncComboBoxHeight` uses a
       `GetWindowRect` feedback loop to match adjacent TButton heights to the
       exact pixel at 100%, 125%, 150%, and 200% DPI scaling.
    3. Dark Panel TCheckBox Caption Fix (`TVeloxDarkCheckBox`):
       Win32 UXTheme forces native TCheckBox text to black regardless of
       `Font.Color`. `TVeloxDarkCheckBox` pairs a captionless TCheckBox with a
       synchronized, clickable TLabel (`crHandPoint`).
    4. One-Call Themed Modal Dialog Builder (`CreateModalDialog`):
       Scaffolds a complete Fluent modal dialog (Header, Title, Subtitle,
       Body, Footer, Primary & Cancel buttons) in a single call.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Types,
  {$IFDEF FPC}
  LCLType,
  {$ENDIF}
  Graphics,
  Controls,
  Forms,
  StdCtrls,
  ExtCtrls,
  Velox.Types,
  Velox.Theme;

type
  /// <summary>
  /// Self-contained Fluent Search Box (Wrapper Panel + Centered Borderless TEdit)
  /// </summary>
  TVeloxSearchBox = class(TComponent)
  private
    FContainer: TPanel;
    FEdit: TEdit;
    FColors: TVeloxThemeColors;
    procedure ContainerPaint(Sender: TObject);
    procedure ContainerClick(Sender: TObject);
    procedure EditFocusChange(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function GetText: string;
    procedure SetText(const AValue: string);
  public
    constructor CreateBox(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth, AHeight: Integer;
      const APlaceholder: string; const AColors: TVeloxThemeColors;
      const AOnChange: TNotifyEvent = nil);
    procedure ApplyColors(const AColors: TVeloxThemeColors);
    procedure SetFocus;

    property Container: TPanel read FContainer;
    property Edit: TEdit read FEdit;
    property Text: string read GetText write SetText;
  end;

  /// <summary>
  /// Dark-theme-safe CheckBox + clickable Label pair
  /// </summary>
  TVeloxDarkCheckBox = class(TComponent)
  private
    FCheckBox: TCheckBox;
    FLabel: TLabel;
    procedure LabelClick(Sender: TObject);
    function GetChecked: Boolean;
    procedure SetChecked(const AValue: Boolean);
  public
    constructor CreateCheck(AOwner: TComponent; AParent: TWinControl;
      const ALeft, ATop, AWidth: Integer; const ACaption: string;
      const AColors: TVeloxThemeColors; const AChecked: Boolean = False);
    procedure ApplyColors(const AColors: TVeloxThemeColors; const ASidebarMode: Boolean = True);

    property CheckBox: TCheckBox read FCheckBox;
    property CaptionLabel: TLabel read FLabel;
    property Checked: Boolean read GetChecked write SetChecked;
  end;

  /// <summary>
  /// Structured handle to a scaffolded Fluent Modal Dialog
  /// </summary>
  TVeloxModalDialog = record
    Form: TForm;
    HeaderPanel: TPanel;
    TitleLabel: TLabel;
    SubtitleLabel: TLabel;
    BodyPanel: TPanel;
    FooterPanel: TPanel;
    PrimaryButton: TButton;
    CancelButton: TButton;
    Memo: TMemo;
  end;

  /// <summary>
  /// Fluent UI Control Factory & Win32 High-DPI Alignment Helpers
  /// </summary>
  TVeloxControls = class
  public
    /// <summary>
    /// Synchronizes a csOwnerDrawFixed TComboBox's closed-box pixel height to
    /// match a reference TButton (or TargetHeightPx) using CB_SETITEMHEIGHT
    /// ($0151) and a GetWindowRect measurement feedback loop.
    /// </summary>
    class procedure SyncComboBoxHeight(const ACombo: TComboBox;
      const ARefButton: TControl = nil; const ATargetHeightPx: Integer = 28); static;

    /// <summary>
    /// Renders an owner-drawn TComboBox item with vertical centering and
    /// accent selection highlight. Wire directly to TComboBox.OnDrawItem.
    /// </summary>
    class procedure DrawComboBoxItem(const ACombo: TComboBox; Index: Integer;
      const ARect: TRect; State: TOwnerDrawState; const AColors: TVeloxThemeColors); static;

    /// <summary>
    /// Creates a themed modal dialog with header, title, accent subtitle,
    /// body container, footer, and action buttons in one call.
    /// Set AIncludeMemo = True to also create a read-only Consolas report TMemo.
    /// </summary>
    class function CreateModalDialog(const AOwner: TComponent;
      const ACaption, ATitle, ASubtitle: string;
      const AWidth, AHeight: Integer; const AColors: TVeloxThemeColors;
      const APrimaryBtnText: string = 'Apply';
      const ACancelBtnText: string = 'Close';
      const AIncludeMemo: Boolean = False): TVeloxModalDialog; static;
  end;

implementation

{ TVeloxSearchBox }

constructor TVeloxSearchBox.CreateBox(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth, AHeight: Integer;
  const APlaceholder: string; const AColors: TVeloxThemeColors;
  const AOnChange: TNotifyEvent);
var
  EditH, EditY: Integer;
begin
  inherited Create(AOwner);
  FColors := AColors;

  FContainer := TPanel.Create(Self);
  FContainer.Parent := AParent;
  FContainer.BevelOuter := bvNone;
  FContainer.DoubleBuffered := True;
  FContainer.SetBounds(ALeft, ATop, AWidth, AHeight);
  FContainer.Color := AColors.SurfaceCard;
  FContainer.Cursor := crIBeam;
  FContainer.Tag := 2; // Card surface tag for TVeloxThemeEngine
  FContainer.OnPaint := ContainerPaint;
  FContainer.OnClick := ContainerClick;

  EditH := 16;
  EditY := (AHeight - EditH) div 2;
  if EditY < 2 then EditY := 2;

  FEdit := TEdit.Create(Self);
  FEdit.Parent := FContainer;
  FEdit.BorderStyle := bsNone;
  FEdit.AutoSize := False;
  FEdit.Font.Name := 'Segoe UI';
  FEdit.Font.Size := 9;
  FEdit.Color := AColors.SurfaceCard;
  FEdit.Font.Color := AColors.TextPrimary;
  FEdit.SetBounds(10, EditY, AWidth - 18, EditH);
  FEdit.TextHint := APlaceholder;
  FEdit.OnChange := AOnChange;
  FEdit.OnEnter := EditFocusChange;
  FEdit.OnExit := EditFocusChange;
  FEdit.OnKeyDown := EditKeyDown;
end;

procedure TVeloxSearchBox.ApplyColors(const AColors: TVeloxThemeColors);
begin
  FColors := AColors;
  if Assigned(FContainer) then
  begin
    FContainer.Color := AColors.SurfaceCard;
    FContainer.Invalidate;
  end;
  if Assigned(FEdit) then
  begin
    FEdit.Color := AColors.SurfaceCard;
    FEdit.Font.Color := AColors.TextPrimary;
  end;
end;

procedure TVeloxSearchBox.ContainerPaint(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
begin
  if not Assigned(FContainer) then Exit;
  C := FContainer.Canvas;
  R := Rect(0, 0, FContainer.Width, FContainer.Height);
  C.Brush.Style := bsSolid;
  C.Brush.Color := FColors.SurfaceCard;
  C.Pen.Style := psSolid;
  C.Pen.Width := 1;
  if Assigned(FEdit) and FEdit.Focused then
    C.Pen.Color := FColors.Accent
  else
    C.Pen.Color := FColors.Border;
  C.Rectangle(R.Left, R.Top, R.Right, R.Bottom);
end;

procedure TVeloxSearchBox.ContainerClick(Sender: TObject);
begin
  if Assigned(FEdit) and FEdit.CanFocus then
    FEdit.SetFocus;
end;

procedure TVeloxSearchBox.EditFocusChange(Sender: TObject);
begin
  if Assigned(FContainer) then
    FContainer.Invalidate;
end;

procedure TVeloxSearchBox.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and Assigned(FEdit) then
  begin
    if FEdit.Text <> '' then
    begin
      FEdit.Text := '';
      Key := 0;
    end;
  end;
end;

function TVeloxSearchBox.GetText: string;
begin
  if Assigned(FEdit) then
    Result := FEdit.Text
  else
    Result := '';
end;

procedure TVeloxSearchBox.SetText(const AValue: string);
begin
  if Assigned(FEdit) then
    FEdit.Text := AValue;
end;

procedure TVeloxSearchBox.SetFocus;
begin
  if Assigned(FEdit) and FEdit.CanFocus then
  begin
    FEdit.SetFocus;
    FEdit.SelectAll;
  end;
end;

{ TVeloxDarkCheckBox }

constructor TVeloxDarkCheckBox.CreateCheck(AOwner: TComponent; AParent: TWinControl;
  const ALeft, ATop, AWidth: Integer; const ACaption: string;
  const AColors: TVeloxThemeColors; const AChecked: Boolean);
begin
  inherited Create(AOwner);
  FCheckBox := TCheckBox.Create(Self);
  FCheckBox.Parent := AParent;
  FCheckBox.Caption := '';
  FCheckBox.SetBounds(ALeft, ATop, 20, 20);
  FCheckBox.Checked := AChecked;
  FCheckBox.Color := AColors.SidebarBg;

  FLabel := TLabel.Create(Self);
  FLabel.Parent := AParent;
  FLabel.Caption := ACaption;
  FLabel.Font.Name := 'Segoe UI';
  FLabel.Font.Size := 9;
  FLabel.Font.Style := [fsBold];
  FLabel.Font.Color := AColors.SidebarText;
  FLabel.Cursor := crHandPoint;
  FLabel.Tag := 3; // Sidebar text tag
  FLabel.OnClick := LabelClick;
  FLabel.SetBounds(ALeft + 24, ATop + 2, AWidth - 24, 16);
end;

procedure TVeloxDarkCheckBox.LabelClick(Sender: TObject);
begin
  if Assigned(FCheckBox) then
    FCheckBox.Checked := not FCheckBox.Checked;
end;

function TVeloxDarkCheckBox.GetChecked: Boolean;
begin
  Result := Assigned(FCheckBox) and FCheckBox.Checked;
end;

procedure TVeloxDarkCheckBox.SetChecked(const AValue: Boolean);
begin
  if Assigned(FCheckBox) then
    FCheckBox.Checked := AValue;
end;

procedure TVeloxDarkCheckBox.ApplyColors(const AColors: TVeloxThemeColors; const ASidebarMode: Boolean);
begin
  if Assigned(FCheckBox) then
  begin
    if ASidebarMode then
      FCheckBox.Color := AColors.SidebarBg
    else
      FCheckBox.Color := AColors.Surface;
  end;
  if Assigned(FLabel) then
  begin
    if ASidebarMode then
      FLabel.Font.Color := AColors.SidebarText
    else
      FLabel.Font.Color := AColors.TextPrimary;
  end;
end;

{ TVeloxControls }

class procedure TVeloxControls.SyncComboBoxHeight(const ACombo: TComboBox;
  const ARefButton: TControl; const ATargetHeightPx: Integer);
{$IFDEF MSWINDOWS}
const
  CB_SETITEMHEIGHT = $0151;
var
  CmbRect, BtnRect: Windows.TRect;
  TargetH, ActualH, InnerH: Integer;
begin
  if not Assigned(ACombo) or not ACombo.HandleAllocated then Exit;

  TargetH := ATargetHeightPx;
  if Assigned(ARefButton) and (ARefButton is TWinControl) and TWinControl(ARefButton).HandleAllocated then
  begin
    if Windows.GetWindowRect(TWinControl(ARefButton).Handle, BtnRect) then
      if (BtnRect.Bottom - BtnRect.Top) > 18 then
        TargetH := BtnRect.Bottom - BtnRect.Top;
  end;

  InnerH := TargetH - 6;
  ACombo.ItemHeight := InnerH;
  Windows.SendMessage(ACombo.Handle, CB_SETITEMHEIGHT, WPARAM(-1), LPARAM(InnerH));
  Windows.SendMessage(ACombo.Handle, CB_SETITEMHEIGHT, WPARAM(0), LPARAM(InnerH));

  if Windows.GetWindowRect(ACombo.Handle, CmbRect) then
  begin
    ActualH := CmbRect.Bottom - CmbRect.Top;
    if (ActualH > 0) and (ActualH <> TargetH) then
    begin
      InnerH := InnerH + (TargetH - ActualH);
      if InnerH >= 12 then
      begin
        ACombo.ItemHeight := InnerH;
        Windows.SendMessage(ACombo.Handle, CB_SETITEMHEIGHT, WPARAM(-1), LPARAM(InnerH));
        Windows.SendMessage(ACombo.Handle, CB_SETITEMHEIGHT, WPARAM(0), LPARAM(InnerH));
      end;
    end;
  end;

  Windows.SetWindowPos(ACombo.Handle, 0, ACombo.Left, ACombo.Top, ACombo.Width, TargetH,
    SWP_NOZORDER or SWP_NOACTIVATE);
end;
{$ELSE}
begin
end;
{$ENDIF}

class procedure TVeloxControls.DrawComboBoxItem(const ACombo: TComboBox; Index: Integer;
  const ARect: TRect; State: TOwnerDrawState; const AColors: TVeloxThemeColors);
var
  C: TCanvas;
  Txt: string;
  TextY: Integer;
begin
  if not Assigned(ACombo) then Exit;
  C := ACombo.Canvas;
  if (odSelected in State) and not (odComboBoxEdit in State) then
  begin
    C.Brush.Color := TVeloxUtils.BlendColor(AColors.SurfaceCard, AColors.Accent, 0.28);
    C.Font.Color := AColors.TextPrimary;
  end
  else
  begin
    C.Brush.Color := AColors.SurfaceCard;
    C.Font.Color := AColors.TextPrimary;
  end;
  C.FillRect(ARect);

  if (Index >= 0) and (Index < ACombo.Items.Count) then
  begin
    Txt := ACombo.Items[Index];
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 9;
    C.Brush.Style := bsClear;
    TextY := ARect.Top + ((ARect.Bottom - ARect.Top) - C.TextHeight(Txt)) div 2;
    C.TextOut(ARect.Left + 6, TextY, Txt);
  end;
end;

class function TVeloxControls.CreateModalDialog(const AOwner: TComponent;
  const ACaption, ATitle, ASubtitle: string;
  const AWidth, AHeight: Integer; const AColors: TVeloxThemeColors;
  const APrimaryBtnText, ACancelBtnText: string;
  const AIncludeMemo: Boolean): TVeloxModalDialog;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Form := TForm.CreateNew(AOwner);
  Result.Form.Caption := ACaption;
  Result.Form.Position := poMainFormCenter;
  Result.Form.Width := AWidth;
  Result.Form.Height := AHeight;
  Result.Form.Color := AColors.Background;
  Result.Form.Font.Name := 'Segoe UI';
  Result.Form.Font.Size := 9;

  Result.HeaderPanel := TPanel.Create(Result.Form);
  Result.HeaderPanel.Parent := Result.Form;
  Result.HeaderPanel.Align := alTop;
  Result.HeaderPanel.Height := 56;
  Result.HeaderPanel.BevelOuter := bvNone;
  Result.HeaderPanel.Color := AColors.Surface;

  Result.TitleLabel := TLabel.Create(Result.Form);
  Result.TitleLabel.Parent := Result.HeaderPanel;
  Result.TitleLabel.SetBounds(16, 8, AWidth - 40, 22);
  Result.TitleLabel.Caption := ATitle;
  Result.TitleLabel.Font.Size := 11;
  Result.TitleLabel.Font.Style := [fsBold];
  Result.TitleLabel.Font.Color := AColors.TextPrimary;

  Result.SubtitleLabel := TLabel.Create(Result.Form);
  Result.SubtitleLabel.Parent := Result.HeaderPanel;
  Result.SubtitleLabel.SetBounds(16, 32, AWidth - 40, 18);
  Result.SubtitleLabel.Caption := ASubtitle;
  Result.SubtitleLabel.Font.Size := 9;
  Result.SubtitleLabel.Font.Color := AColors.Accent;

  Result.FooterPanel := TPanel.Create(Result.Form);
  Result.FooterPanel.Parent := Result.Form;
  Result.FooterPanel.Align := alBottom;
  Result.FooterPanel.Height := 44;
  Result.FooterPanel.BevelOuter := bvNone;
  Result.FooterPanel.Color := AColors.Surface;

  if APrimaryBtnText <> '' then
  begin
    Result.PrimaryButton := TButton.Create(Result.Form);
    Result.PrimaryButton.Parent := Result.FooterPanel;
    Result.PrimaryButton.SetBounds(16, 8, 140, 28);
    Result.PrimaryButton.Caption := APrimaryBtnText;
    Result.PrimaryButton.ModalResult := mrYes;
  end;

  Result.CancelButton := TButton.Create(Result.Form);
  Result.CancelButton.Parent := Result.FooterPanel;
  Result.CancelButton.SetBounds(AWidth - 110, 8, 90, 28);
  Result.CancelButton.Anchors := [akTop, akRight];
  Result.CancelButton.Caption := ACancelBtnText;
  Result.CancelButton.Cancel := True;
  Result.CancelButton.Default := True;
  Result.CancelButton.ModalResult := mrOk;

  if AIncludeMemo then
  begin
    Result.Memo := TMemo.Create(Result.Form);
    Result.Memo.Parent := Result.Form;
    Result.Memo.Align := alClient;
    Result.Memo.BorderSpacing.Around := 12;
    Result.Memo.ReadOnly := True;
    Result.Memo.ScrollBars := ssBoth;
    Result.Memo.WordWrap := False;
    Result.Memo.Color := AColors.SurfaceCard;
    Result.Memo.Font.Name := 'Consolas';
    Result.Memo.Font.Size := 9;
    Result.Memo.Font.Color := AColors.TextPrimary;
  end
  else
  begin
    Result.BodyPanel := TPanel.Create(Result.Form);
    Result.BodyPanel.Parent := Result.Form;
    Result.BodyPanel.Align := alClient;
    Result.BodyPanel.BevelOuter := bvNone;
    Result.BodyPanel.Color := AColors.Background;
  end;
end;

end.
