unit Velox.Theme;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Theme
  Purpose:
    1. Windows 10/11 Immersive Dark Title Bar (DWMWA_USE_IMMERSIVE_DARK_MODE)
    2. Windows 11 System Backdrop Materials (Mica, Acrylic, Mica Alt via Attr 38)
    3. Undocumented Win32 uxtheme.dll Ordinals (135 SetPreferredAppMode,
       133 AllowDarkModeForWindow, 136 FlushMenuThemes) + DarkMode_Explorer
       for native dark scrollbars on TListView, TMemo, and TScrollBox
    4. Windows Registry Dark/Light OS preference detection
    5. Recursive 1-line Form & Control hierarchy theming (ApplyFormTheme)
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Messages,
  Graphics,
  Controls,
  Forms,
  StdCtrls,
  ExtCtrls,
  ComCtrls,
  Velox.Types;

type
  /// <summary>
  /// Declarative theme engine for Windows 10/11 DWM, UXTheme dark scrollbars,
  /// and recursive VCL/LCL control tree styling.
  /// </summary>
  TVeloxThemeEngine = class
  public
    /// <summary>
    /// Detects whether the user's Windows OS is currently configured for Dark
    /// or Light app mode (reads HKCU Personalize\AppsUseLightTheme).
    /// </summary>
    class function DetectSystemTheme: TVeloxTheme; static;

    /// <summary>
    /// Enables process-wide Win32 UXTheme dark mode (Ordinal 135) so scrollbars,
    /// tooltips, and menus respect dark mode when opted in.
    /// </summary>
    class procedure InitializeProcessDarkMode(const AAllowDark: Boolean = True); static;

    /// <summary>
    /// Applies Windows 10/11 DWM Immersive Dark Title Bar to any HWND.
    /// Automatically falls back from Attribute 20 (Win11/20H1+) to 19 (1809).
    /// </summary>
    class function ApplyDarkTitleBar(const AHandle: HWND; const ADark: Boolean): Boolean; static;

    /// <summary>
    /// Applies Windows 11 22H2+ System Backdrop Material (Mica, Acrylic, Tabbed)
    /// via DWMWA_SYSTEMBACKDROP_TYPE (Attribute 38).
    /// </summary>
    class function ApplySystemBackdrop(const AHandle: HWND; const ABackdrop: TVeloxBackdropType): Boolean; static;

    /// <summary>
    /// Applies native Win32 DarkMode_Explorer scrollbars and header chrome to
    /// a control handle (e.g. TListView, TMemo, TScrollBox) via uxtheme.dll.
    /// </summary>
    class function ApplyDarkScrollbars(const AHandle: HWND; const ADark: Boolean): Boolean; static;

    /// <summary>
    /// Recursively styles a TForm and all child controls (Panels, Labels, Edits,
    /// Memos, ListViews, ComboBoxes) using semantic TVeloxThemeColors tokens,
    /// plus syncs the DWM dark title bar and dark scrollbars in 1 call.
    /// </summary>
    class procedure ApplyFormTheme(const AForm: TCustomForm; const ATheme: TVeloxTheme); overload; static;
    class procedure ApplyFormTheme(const AForm: TCustomForm; const AColors: TVeloxThemeColors; const AIsDark: Boolean); overload; static;
    class procedure ApplyControlTheme(const AControl: TControl; const AColors: TVeloxThemeColors; const AIsDark: Boolean); static;
  end;

implementation

type
  TPrefAppMode = (
    pamDefault    = 0,
    pamAllowDark  = 1,
    pamForceDark  = 2,
    pamForceLight = 3
  );

  TDwmSetWindowAttribute = function(hwnd: HWND; dwAttribute: DWORD; pvAttribute: Pointer; cbAttribute: DWORD): HRESULT; stdcall;
  TSetPreferredAppMode = function(appMode: TPrefAppMode): TPrefAppMode; stdcall;
  TAllowDarkModeForWindow = function(hwnd: HWND; allow: BOOL): BOOL; stdcall;
  TFlushMenuThemes = procedure; stdcall;
  TSetWindowTheme = function(hwnd: HWND; pszSubAppName: PWideChar; pszSubIdList: PWideChar): HRESULT; stdcall;

const
  DWMWA_USE_IMMERSIVE_DARK_MODE_OLD = 19;
  DWMWA_USE_IMMERSIVE_DARK_MODE     = 20;
  DWMWA_WINDOW_CORNER_PREFERENCE    = 33;
  DWMWA_SYSTEMBACKDROP_TYPE         = 38;

var
  GDwmLoaded: Boolean = False;
  GDwmHandle: HMODULE = 0;
  GDwmSetWindowAttr: TDwmSetWindowAttribute = nil;

  GUxThemeLoaded: Boolean = False;
  GUxThemeHandle: HMODULE = 0;
  GSetPreferredAppMode: TSetPreferredAppMode = nil;
  GAllowDarkModeForWindow: TAllowDarkModeForWindow = nil;
  GFlushMenuThemes: TFlushMenuThemes = nil;
  GSetWindowTheme: TSetWindowTheme = nil;

procedure EnsureDwmLoaded;
begin
  if GDwmLoaded then Exit;
  GDwmLoaded := True;
  GDwmHandle := GetModuleHandle('dwmapi.dll');
  if GDwmHandle = 0 then
    GDwmHandle := LoadLibrary('dwmapi.dll');
  if GDwmHandle <> 0 then
    @GDwmSetWindowAttr := GetProcAddress(GDwmHandle, 'DwmSetWindowAttribute');
end;

procedure EnsureUxThemeLoaded;
begin
  if GUxThemeLoaded then Exit;
  GUxThemeLoaded := True;
  GUxThemeHandle := GetModuleHandle('uxtheme.dll');
  if GUxThemeHandle = 0 then
    GUxThemeHandle := LoadLibrary('uxtheme.dll');
  if GUxThemeHandle <> 0 then
  begin
    @GSetPreferredAppMode    := GetProcAddress(GUxThemeHandle, MAKEINTRESOURCEA(135));
    @GAllowDarkModeForWindow := GetProcAddress(GUxThemeHandle, MAKEINTRESOURCEA(133));
    @GFlushMenuThemes        := GetProcAddress(GUxThemeHandle, MAKEINTRESOURCEA(136));
    @GSetWindowTheme         := GetProcAddress(GUxThemeHandle, 'SetWindowTheme');
  end;
end;

{ TVeloxThemeEngine }

class function TVeloxThemeEngine.DetectSystemTheme: TVeloxTheme;
const
  PERSONALIZE_KEY = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';
var
  Key: HKEY;
  Val, ValSize, ValType: DWORD;
begin
  Result := vtDark; // Default to modern dark palette
  if RegOpenKeyExW(HKEY_CURRENT_USER, PERSONALIZE_KEY, 0, KEY_READ, Key) = ERROR_SUCCESS then
  begin
    try
      Val := 1;
      ValSize := SizeOf(Val);
      ValType := REG_DWORD;
      if RegQueryValueExW(Key, 'AppsUseLightTheme', nil, @ValType, @Val, @ValSize) = ERROR_SUCCESS then
      begin
        if Val = 0 then
          Result := vtDark
        else
          Result := vtLight;
      end;
    finally
      RegCloseKey(Key);
    end;
  end;
end;

class procedure TVeloxThemeEngine.InitializeProcessDarkMode(const AAllowDark: Boolean);
begin
  EnsureUxThemeLoaded;
  if Assigned(GSetPreferredAppMode) then
  begin
    if AAllowDark then
      GSetPreferredAppMode(pamAllowDark)
    else
      GSetPreferredAppMode(pamDefault);
  end;
  if Assigned(GFlushMenuThemes) then
    GFlushMenuThemes;
end;

class function TVeloxThemeEngine.ApplyDarkTitleBar(const AHandle: HWND; const ADark: Boolean): Boolean;
var
  DarkVal: BOOL;
begin
  Result := False;
  if AHandle = 0 then Exit;
  EnsureDwmLoaded;
  if Assigned(GDwmSetWindowAttr) then
  begin
    DarkVal := ADark;
    Result := GDwmSetWindowAttr(AHandle, DWMWA_USE_IMMERSIVE_DARK_MODE, @DarkVal, SizeOf(DarkVal)) = 0;
    if not Result then
      Result := GDwmSetWindowAttr(AHandle, DWMWA_USE_IMMERSIVE_DARK_MODE_OLD, @DarkVal, SizeOf(DarkVal)) = 0;
  end;
end;

class function TVeloxThemeEngine.ApplySystemBackdrop(const AHandle: HWND; const ABackdrop: TVeloxBackdropType): Boolean;
var
  BackdropVal: Integer;
begin
  Result := False;
  if AHandle = 0 then Exit;
  EnsureDwmLoaded;
  if Assigned(GDwmSetWindowAttr) then
  begin
    BackdropVal := Ord(ABackdrop);
    Result := GDwmSetWindowAttr(AHandle, DWMWA_SYSTEMBACKDROP_TYPE, @BackdropVal, SizeOf(BackdropVal)) = 0;
  end;
end;

class function TVeloxThemeEngine.ApplyDarkScrollbars(const AHandle: HWND; const ADark: Boolean): Boolean;
begin
  Result := False;
  if AHandle = 0 then Exit;
  EnsureUxThemeLoaded;
  if Assigned(GAllowDarkModeForWindow) then
    GAllowDarkModeForWindow(AHandle, ADark);

  if Assigned(GSetWindowTheme) then
  begin
    if ADark then
      Result := GSetWindowTheme(AHandle, 'DarkMode_Explorer', nil) = 0
    else
      Result := GSetWindowTheme(AHandle, 'Explorer', nil) = 0;
    SendMessage(AHandle, WM_THEMECHANGED, 0, 0);
  end;
end;

class procedure TVeloxThemeEngine.ApplyFormTheme(const AForm: TCustomForm; const ATheme: TVeloxTheme);
var
  Colors: TVeloxThemeColors;
begin
  Colors := TVeloxUtils.GetThemeColors(ATheme);
  ApplyFormTheme(AForm, Colors, ATheme = vtDark);
end;

class procedure TVeloxThemeEngine.ApplyFormTheme(const AForm: TCustomForm;
  const AColors: TVeloxThemeColors; const AIsDark: Boolean);
var
  I: Integer;
begin
  if AForm = nil then Exit;
  InitializeProcessDarkMode(AIsDark);

  AForm.Color := AColors.Background;
  AForm.Font.Color := AColors.TextPrimary;

  if AForm.HandleAllocated then
    ApplyDarkTitleBar(AForm.Handle, AIsDark);

  for I := 0 to AForm.ControlCount - 1 do
    ApplyControlTheme(AForm.Controls[I], AColors, AIsDark);

  AForm.Invalidate;
end;

class procedure TVeloxThemeEngine.ApplyControlTheme(const AControl: TControl;
  const AColors: TVeloxThemeColors; const AIsDark: Boolean);
var
  I: Integer;
  WinCtrl: TWinControl;
begin
  if AControl = nil then Exit;

  if AControl is TPanel then
  begin
    // Tag = 1 convention: Sidebar panel; Tag = 2: Card surface; default: Surface
    case AControl.Tag of
      1: TPanel(AControl).Color := AColors.SidebarBg;
      2: TPanel(AControl).Color := AColors.SurfaceCard;
      3: TPanel(AControl).Color := AColors.Background;
    else
      TPanel(AControl).Color := AColors.Surface;
    end;
  end
  else if AControl is TLabel then
  begin
    case AControl.Tag of
      1: TLabel(AControl).Font.Color := AColors.TextSecondary;
      2: TLabel(AControl).Font.Color := AColors.Accent;
      3: TLabel(AControl).Font.Color := AColors.SidebarText;
    else
      TLabel(AControl).Font.Color := AColors.TextPrimary;
    end;
  end
  else if AControl is TEdit then
  begin
    TEdit(AControl).Color := AColors.SurfaceCard;
    TEdit(AControl).Font.Color := AColors.TextPrimary;
  end
  else if AControl is TMemo then
  begin
    TMemo(AControl).Color := AColors.SurfaceCard;
    TMemo(AControl).Font.Color := AColors.TextPrimary;
    if TMemo(AControl).HandleAllocated then
      ApplyDarkScrollbars(TMemo(AControl).Handle, AIsDark);
  end
  else if AControl is TListView then
  begin
    TListView(AControl).Color := AColors.Surface;
    TListView(AControl).Font.Color := AColors.TextPrimary;
    if TListView(AControl).HandleAllocated then
      ApplyDarkScrollbars(TListView(AControl).Handle, AIsDark);
  end
  else if AControl is TComboBox then
  begin
    TComboBox(AControl).Color := AColors.SurfaceCard;
    TComboBox(AControl).Font.Color := AColors.TextPrimary;
  end;

  if AControl is TWinControl then
  begin
    WinCtrl := TWinControl(AControl);
    for I := 0 to WinCtrl.ControlCount - 1 do
      ApplyControlTheme(WinCtrl.Controls[I], AColors, AIsDark);
  end;

  AControl.Invalidate;
end;

end.
