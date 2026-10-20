unit Velox.Config;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Config
  Purpose:
    Zero-dependency key-value & window placement state persistence
    (`TVeloxConfig`). Automatically saves and restores window coordinates,
    Dark/Light theme preference, polling intervals, and active sort columns,
    with multi-monitor screen bounds clamping so an unplugged display never
    leaves a window off-screen.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Controls,
  Forms,
  Velox.Types;

type
  /// <summary>
  /// Lightweight persistent configuration store with multi-monitor safe
  /// window placement restoration.
  /// </summary>
  TVeloxConfig = class
  private
    FValues: TStringList;
    FFilePath: string;
  public
    constructor Create(const AFilePath: string = '');
    destructor Destroy; override;

    function LoadFromFile(const AFilePath: string = ''): Boolean;
    function SaveToFile(const AFilePath: string = ''): Boolean;

    function ReadString(const AKey: string; const ADefault: string = ''): string;
    procedure WriteString(const AKey, AValue: string);

    function ReadInt(const AKey: string; const ADefault: Integer = 0): Integer;
    procedure WriteInt(const AKey: string; const AValue: Integer);

    function ReadBool(const AKey: string; const ADefault: Boolean = False): Boolean;
    procedure WriteBool(const AKey: string; const AValue: Boolean);

    function ReadTheme(const AKey: string = 'ui.theme'; const ADefault: TVeloxTheme = vtDark): TVeloxTheme;
    procedure WriteTheme(const AValue: TVeloxTheme; const AKey: string = 'ui.theme');

    /// <summary>
    /// Captures and restores a Form's Left, Top, Width, Height, and StayOnTop
    /// state, automatically clamping coordinates to valid desktop bounds.
    /// </summary>
    procedure CaptureFormBounds(const AForm: TCustomForm; const APrefix: string = 'window');
    procedure RestoreFormBounds(const AForm: TCustomForm; const APrefix: string = 'window');

    /// <summary>
    /// Clamps a rectangle (ALeft, ATop, AWidth, AHeight) so that it is
    /// guaranteed to be visible within the current desktop area
    /// (ADesktopWidth x ADesktopHeight).
    /// </summary>
    class procedure ClampToDesktop(var ALeft, ATop, AWidth, AHeight: Integer;
      const ADesktopWidth, ADesktopHeight: Integer;
      const AMinWidth: Integer = 400; const AMinHeight: Integer = 300); static;

    property FilePath: string read FFilePath write FFilePath;
  end;

implementation

{ TVeloxConfig }

constructor TVeloxConfig.Create(const AFilePath: string);
begin
  inherited Create;
  FValues := TStringList.Create;
  FValues.NameValueSeparator := '=';
  FFilePath := AFilePath;
  if (FFilePath <> '') and FileExists(FFilePath) then
    LoadFromFile(FFilePath);
end;

destructor TVeloxConfig.Destroy;
begin
  FValues.Free;
  inherited Destroy;
end;

function TVeloxConfig.LoadFromFile(const AFilePath: string): Boolean;
var
  TargetPath: string;
begin
  Result := False;
  if AFilePath <> '' then
    TargetPath := AFilePath
  else
    TargetPath := FFilePath;
  if (TargetPath = '') or not FileExists(TargetPath) then Exit;
  try
    FValues.LoadFromFile(TargetPath);
    FFilePath := TargetPath;
    Result := True;
  except
    Result := False;
  end;
end;

function TVeloxConfig.SaveToFile(const AFilePath: string): Boolean;
var
  TargetPath, DirPath: string;
begin
  Result := False;
  if AFilePath <> '' then
    TargetPath := AFilePath
  else
    TargetPath := FFilePath;
  if TargetPath = '' then Exit;
  try
    DirPath := ExtractFileDir(TargetPath);
    if (DirPath <> '') and not DirectoryExists(DirPath) then
      ForceDirectories(DirPath);
    FValues.SaveToFile(TargetPath);
    FFilePath := TargetPath;
    Result := True;
  except
    Result := False;
  end;
end;

function TVeloxConfig.ReadString(const AKey: string; const ADefault: string): string;
var
  Idx: Integer;
begin
  Idx := FValues.IndexOfName(AKey);
  if Idx >= 0 then
    Result := FValues.ValueFromIndex[Idx]
  else
    Result := ADefault;
end;

procedure TVeloxConfig.WriteString(const AKey, AValue: string);
begin
  FValues.Values[AKey] := AValue;
end;

function TVeloxConfig.ReadInt(const AKey: string; const ADefault: Integer): Integer;
begin
  Result := StrToIntDef(ReadString(AKey, ''), ADefault);
end;

procedure TVeloxConfig.WriteInt(const AKey: string; const AValue: Integer);
begin
  WriteString(AKey, IntToStr(AValue));
end;

function TVeloxConfig.ReadBool(const AKey: string; const ADefault: Boolean): Boolean;
var
  S: string;
begin
  S := LowerCase(Trim(ReadString(AKey, '')));
  if (S = '1') or (S = 'true') or (S = 'yes') then
    Result := True
  else if (S = '0') or (S = 'false') or (S = 'no') then
    Result := False
  else
    Result := ADefault;
end;

procedure TVeloxConfig.WriteBool(const AKey: string; const AValue: Boolean);
begin
  if AValue then
    WriteString(AKey, 'true')
  else
    WriteString(AKey, 'false');
end;

function TVeloxConfig.ReadTheme(const AKey: string; const ADefault: TVeloxTheme): TVeloxTheme;
var
  S: string;
begin
  S := LowerCase(Trim(ReadString(AKey, '')));
  if S = 'light' then
    Result := vtLight
  else if S = 'dark' then
    Result := vtDark
  else
    Result := ADefault;
end;

procedure TVeloxConfig.WriteTheme(const AValue: TVeloxTheme; const AKey: string);
begin
  if AValue = vtLight then
    WriteString(AKey, 'light')
  else
    WriteString(AKey, 'dark');
end;

class procedure TVeloxConfig.ClampToDesktop(var ALeft, ATop, AWidth, AHeight: Integer;
  const ADesktopWidth, ADesktopHeight: Integer;
  const AMinWidth, AMinHeight: Integer);
begin
  if AWidth < AMinWidth then AWidth := AMinWidth;
  if AHeight < AMinHeight then AHeight := AMinHeight;

  if (ADesktopWidth > AMinWidth) and (AWidth > ADesktopWidth) then
    AWidth := ADesktopWidth;
  if (ADesktopHeight > AMinHeight) and (AHeight > ADesktopHeight) then
    AHeight := ADesktopHeight;

  if (ADesktopWidth > 0) and (ALeft + AWidth > ADesktopWidth) then
    ALeft := ADesktopWidth - AWidth;
  if (ADesktopHeight > 0) and (ATop + AHeight > ADesktopHeight) then
    ATop := ADesktopHeight - AHeight;

  if ALeft < 0 then ALeft := 0;
  if ATop < 0 then ATop := 0;
end;

procedure TVeloxConfig.CaptureFormBounds(const AForm: TCustomForm; const APrefix: string);
begin
  if AForm = nil then Exit;
  WriteInt(APrefix + '.left', AForm.Left);
  WriteInt(APrefix + '.top', AForm.Top);
  WriteInt(APrefix + '.width', AForm.Width);
  WriteInt(APrefix + '.height', AForm.Height);
  WriteBool(APrefix + '.pinned', AForm.FormStyle = fsStayOnTop);
end;

procedure TVeloxConfig.RestoreFormBounds(const AForm: TCustomForm; const APrefix: string);
var
  L, T, W, H, DeskW, DeskH: Integer;
begin
  if AForm = nil then Exit;
  L := ReadInt(APrefix + '.left', AForm.Left);
  T := ReadInt(APrefix + '.top', AForm.Top);
  W := ReadInt(APrefix + '.width', AForm.Width);
  H := ReadInt(APrefix + '.height', AForm.Height);

  if Assigned(Screen) then
  begin
    DeskW := Screen.DesktopWidth;
    DeskH := Screen.DesktopHeight;
  end
  else
  begin
    DeskW := 1920;
    DeskH := 1080;
  end;

  ClampToDesktop(L, T, W, H, DeskW, DeskH);
  AForm.SetBounds(L, T, W, H);
  if ReadBool(APrefix + '.pinned', False) then
    AForm.FormStyle := fsStayOnTop;
end;

end.
