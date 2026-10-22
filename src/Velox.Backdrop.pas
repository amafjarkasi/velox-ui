unit Velox.Backdrop;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Backdrop (Unit #78)
  Purpose:
    Windows 11 DWM Desktop Acrylic & System Backdrop Engine.
    Enables true GPU-rendered Acrylic blur (`DWMSBT_TRANSIENTWINDOW = 3`)
    and Mica backdrops on floating popups, context menus, command palettes,
    toasts, and modal dialogs with graceful Windows 10 BlurBehind fallback.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Forms,
  Controls,
  Velox.Types;

type
  /// <summary>
  /// Windows 11 DWM system backdrop types (Attr 38: DWMWA_SYSTEMBACKDROP_TYPE)
  /// </summary>
  TVeloxBackdropKind = (
    vbkNone,        // 1: DWMSBT_NONE
    vbkMica,        // 2: DWMSBT_MAINWINDOW
    vbkAcrylic,     // 3: DWMSBT_TRANSIENTWINDOW (Frosted acrylic for popups)
    vbkMicaAlt      // 4: DWMSBT_TABBEDWINDOW
  );

  /// <summary>
  /// Windows 11 DWM Acrylic and System Backdrop Controller
  /// </summary>
  TVeloxBackdrop = class
  private
    class function GetBuildNumber: DWORD; static;
  public
    /// <summary>
    /// Applies a hardware DWM backdrop (Mica / Acrylic) to any Win32 HWND.
    /// </summary>
    class function ApplyBackdrop(const AHandle: HWND;
      const AKind: TVeloxBackdropKind = vbkAcrylic;
      const ADarkMode: Boolean = True): Boolean; static;

    /// <summary>
    /// Turnkey setup for floating menus, palettes, and popups:
    /// applies Transient Acrylic blur and rounded corners.
    /// </summary>
    class function ApplyPopupAcrylic(const AHandle: HWND;
      const ADarkMode: Boolean = True): Boolean; static;

    /// <summary>
    /// Returns True if the operating system supports DWMWA_SYSTEMBACKDROP_TYPE (Win11 22H2+ / Build 22621+)
    /// </summary>
    class function SupportsSystemBackdrop: Boolean; static;

    /// <summary>
    /// Returns True if the OS supports DWM dark title bars (Build 17763+)
    /// </summary>
    class function SupportsDarkMode: Boolean; static;

    /// <summary>
    /// Configures a Delphi/Lazarus form with borderless floating styling,
    /// dark mode, and Acrylic blur.
    /// </summary>
    class procedure ConfigureFloatingPopup(const AForm: TCustomForm;
      const ADarkMode: Boolean = True); static;
  end;

implementation

const
  DWMWA_USE_IMMERSIVE_DARK_MODE_OLD = 19;
  DWMWA_USE_IMMERSIVE_DARK_MODE     = 20;
  DWMWA_WINDOW_CORNER_PREFERENCE    = 33;
  DWMWA_SYSTEMBACKDROP_TYPE         = 38;

  DWMWCP_ROUND      = 2;
  DWMWCP_ROUNDSMALL = 3;

  DWMSBT_AUTO            = 0;
  DWMSBT_NONE            = 1;
  DWMSBT_MAINWINDOW      = 2; // Mica
  DWMSBT_TRANSIENTWINDOW = 3; // Acrylic
  DWMSBT_TABBEDWINDOW    = 4; // Mica Alt

type
  TDwmSetWindowAttribute = function(hwnd: HWND; dwAttribute: DWORD;
    pvAttribute: Pointer; cbAttribute: DWORD): HRESULT; stdcall;

  ACCENT_STATE = (
    ACCENT_DISABLED = 0,
    ACCENT_ENABLE_GRADIENT = 1,
    ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
    ACCENT_ENABLE_BLURBEHIND = 3,
    ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
    ACCENT_INVALID_STATE = 5
  );

  WINCOMPATTRDATA = record
    nAttribute: DWORD;
    pData: Pointer;
    ulDataSize: ULONG;
  end;

  ACCENT_POLICY = record
    AccentState: ACCENT_STATE;
    AccentFlags: DWORD;
    GradientColor: DWORD;
    AnimationId: DWORD;
  end;

  TSetWindowCompositionAttribute = function(hwnd: HWND;
    var Data: WINCOMPATTRDATA): BOOL; stdcall;

var
  GDwmDll: HMODULE = 0;
  GDwmSetAttr: TDwmSetWindowAttribute = nil;
  GUser32Dll: HMODULE = 0;
  GSetWinCompAttr: TSetWindowCompositionAttribute = nil;
  GProcsLoaded: Boolean = False;

procedure InitBackdropProcs;
begin
  if GProcsLoaded then Exit;
  GProcsLoaded := True;

  GDwmDll := LoadLibraryA('dwmapi.dll');
  if GDwmDll <> 0 then
    @GDwmSetAttr := GetProcAddress(GDwmDll, 'DwmSetWindowAttribute');

  GUser32Dll := LoadLibraryA('user32.dll');
  if GUser32Dll <> 0 then
    @GSetWinCompAttr := GetProcAddress(GUser32Dll, 'SetWindowCompositionAttribute');
end;

{ TVeloxBackdrop }

class function TVeloxBackdrop.GetBuildNumber: DWORD;
var
  H: HMODULE;
  RtlGetNtVer: function(var Major, Minor, Build: DWORD): DWORD; stdcall;
  Maj, Min, Bld: DWORD;
begin
  Result := 0;
  H := GetModuleHandleA('ntdll.dll');
  if H <> 0 then
  begin
    @RtlGetNtVer := GetProcAddress(H, 'RtlGetNtVersionNumbers');
    if Assigned(RtlGetNtVer) then
    begin
      RtlGetNtVer(Maj, Min, Bld);
      Result := Bld and $FFFF;
      Exit;
    end;
  end;
  Result := GetVersion and $FFFF;
end;

class function TVeloxBackdrop.SupportsSystemBackdrop: Boolean;
begin
  Result := GetBuildNumber >= 22621;
end;

class function TVeloxBackdrop.SupportsDarkMode: Boolean;
begin
  Result := GetBuildNumber >= 17763;
end;

class function TVeloxBackdrop.ApplyBackdrop(const AHandle: HWND;
  const AKind: TVeloxBackdropKind; const ADarkMode: Boolean): Boolean;
var
  DarkVal: Integer;
  BackdropVal: Integer;
  Attr: DWORD;
  Accent: ACCENT_POLICY;
  Data: WINCOMPATTRDATA;
begin
  Result := False;
  if AHandle = 0 then Exit;
  InitBackdropProcs;

  // 1. Dark Mode titlebar attribute
  if Assigned(GDwmSetAttr) then
  begin
    if ADarkMode then DarkVal := 1 else DarkVal := 0;
    if GetBuildNumber >= 18985 then
      Attr := DWMWA_USE_IMMERSIVE_DARK_MODE
    else
      Attr := DWMWA_USE_IMMERSIVE_DARK_MODE_OLD;
    GDwmSetAttr(AHandle, Attr, @DarkVal, SizeOf(DarkVal));
  end;

  // 2. Windows 11 Build 22621+ DWMWA_SYSTEMBACKDROP_TYPE
  if SupportsSystemBackdrop and Assigned(GDwmSetAttr) then
  begin
    case AKind of
      vbkNone:     BackdropVal := DWMSBT_NONE;
      vbkMica:     BackdropVal := DWMSBT_MAINWINDOW;
      vbkAcrylic:  BackdropVal := DWMSBT_TRANSIENTWINDOW;
      vbkMicaAlt:  BackdropVal := DWMSBT_TABBEDWINDOW;
    else
      BackdropVal := DWMSBT_NONE;
    end;

    Result := (GDwmSetAttr(AHandle, DWMWA_SYSTEMBACKDROP_TYPE, @BackdropVal, SizeOf(BackdropVal)) = 0);
    Exit;
  end;

  // 3. Windows 10 Fallback: SetWindowCompositionAttribute BlurBehind
  if Assigned(GSetWinCompAttr) and (AKind in [vbkAcrylic, vbkMica]) then
  begin
    FillChar(Accent, SizeOf(Accent), 0);
    if AKind = vbkAcrylic then
    begin
      Accent.AccentState := ACCENT_ENABLE_ACRYLICBLURBEHIND;
      if ADarkMode then
        Accent.GradientColor := $99202020 // Semi-transparent dark tint
      else
        Accent.GradientColor := $99F5F5F5;
    end
    else
      Accent.AccentState := ACCENT_ENABLE_BLURBEHIND;

    Data.nAttribute := 19; // WCA_ACCENT_POLICY
    Data.pData := @Accent;
    Data.ulDataSize := SizeOf(Accent);
    Result := GSetWinCompAttr(AHandle, Data);
  end;
end;

class function TVeloxBackdrop.ApplyPopupAcrylic(const AHandle: HWND;
  const ADarkMode: Boolean): Boolean;
var
  CornerPref: Integer;
begin
  Result := ApplyBackdrop(AHandle, vbkAcrylic, ADarkMode);

  // Apply rounded corners (DWMWCP_ROUNDSMALL = 3)
  if Assigned(GDwmSetAttr) and (GetBuildNumber >= 22000) then
  begin
    CornerPref := DWMWCP_ROUNDSMALL;
    GDwmSetAttr(AHandle, DWMWA_WINDOW_CORNER_PREFERENCE, @CornerPref, SizeOf(CornerPref));
  end;
end;

class procedure TVeloxBackdrop.ConfigureFloatingPopup(const AForm: TCustomForm;
  const ADarkMode: Boolean);
begin
  if not Assigned(AForm) then Exit;
  AForm.BorderStyle := bsNone;
  if AForm.HandleAllocated then
    ApplyPopupAcrylic(AForm.Handle, ADarkMode);
end;

initialization

finalization
  if GDwmDll <> 0 then
  begin
    FreeLibrary(GDwmDll);
    GDwmDll := 0;
  end;
  if GUser32Dll <> 0 then
  begin
    FreeLibrary(GUser32Dll);
    GUser32Dll := 0;
  end;

end.
