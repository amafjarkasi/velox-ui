unit Velox.Dpi;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Dpi
  Purpose:
    Per-Monitor-V2 High-DPI helper (`TVeloxDpi`): opt the process into
    PerMonitorAwareV2, query system / window DPI (dynamic user32 lookups so
    older Windows still loads), scale/unscale pixel values, and rescale a
    control tree when a window moves between monitors (`WM_DPICHANGED`).
    NOTE: ScaleControlTree rescales `Align = alNone` controls fully and
    alLeft/alRight (width) / alTop/alBottom (height) controls on one axis;
    anchored children of a resized parent are adjusted by the toolkit, so
    prefer Align-based or fixed layouts for automatic rescaling.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows,
  Controls,
  Forms;

const
  VELOX_DEFAULT_DPI = 96;

type
  /// <summary>
  /// Per-Monitor-V2 DPI query & scaling helpers
  /// </summary>
  TVeloxDpi = class
  public
    /// <summary>Opts the process into PerMonitorAwareV2 (call before creating forms). Returns True on success.</summary>
    class function EnablePerMonitorV2: Boolean; static;
    class function GetSystemDpi: Integer; static;
    class function GetWindowDpi(const AWnd: HWND): Integer; static;

    class function GetScaleFactor(const ADpi: Integer): Double; static;
    class function Scale(const AValue, ADpi: Integer): Integer; static;
    class function Unscale(const AValue, ADpi: Integer): Integer; static;

    /// <summary>Rescales child controls (bounds + non-inherited fonts) from AOldDpi to ANewDpi.</summary>
    class procedure ScaleControlTree(const AParent: TWinControl;
      const AOldDpi, ANewDpi: Integer); static;

    /// <summary>Call from WM_DPICHANGED: resizes the form client area and rescales its controls.</summary>
    class procedure RescaleForm(const AForm: TForm; const AOldDpi, ANewDpi: Integer); static;
  end;

implementation

type
  TControlAccess = class(TControl);

var
  GDpiTried: Boolean = False;
  GetDpiForSystemFn: function: UINT; stdcall;
  GetDpiForWindowFn: function(AWnd: HWND): UINT; stdcall;
  SetProcessDpiAwarenessContextFn: function(AValue: THandle): BOOL; stdcall;

procedure LoadDpiApis;
var
  Lib: HMODULE;
begin
  if GDpiTried then Exit;
  GDpiTried := True;
  Lib := GetModuleHandle('user32.dll');
  if Lib = 0 then Exit;
  @GetDpiForSystemFn := GetProcAddress(Lib, 'GetDpiForSystem');
  @GetDpiForWindowFn := GetProcAddress(Lib, 'GetDpiForWindow');
  @SetProcessDpiAwarenessContextFn := GetProcAddress(Lib, 'SetProcessDpiAwarenessContext');
end;

class function TVeloxDpi.EnablePerMonitorV2: Boolean;
begin
  LoadDpiApis;
  Result := False;
  if Assigned(SetProcessDpiAwarenessContextFn) then
    // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
    Result := SetProcessDpiAwarenessContextFn(THandle(NativeInt(-4)));
end;

class function TVeloxDpi.GetSystemDpi: Integer;
var
  DC: HDC;
begin
  LoadDpiApis;
  if Assigned(GetDpiForSystemFn) then
    Result := Integer(GetDpiForSystemFn())
  else
  begin
    DC := GetDC(0);
    try
      Result := GetDeviceCaps(DC, LOGPIXELSX);
    finally
      ReleaseDC(0, DC);
    end;
  end;
  if Result < VELOX_DEFAULT_DPI then
    Result := VELOX_DEFAULT_DPI;
end;

class function TVeloxDpi.GetWindowDpi(const AWnd: HWND): Integer;
begin
  LoadDpiApis;
  Result := 0;
  if (AWnd <> 0) and Assigned(GetDpiForWindowFn) then
    Result := Integer(GetDpiForWindowFn(AWnd));
  if Result <= 0 then
    Result := GetSystemDpi;
end;

class function TVeloxDpi.GetScaleFactor(const ADpi: Integer): Double;
begin
  Result := ADpi / VELOX_DEFAULT_DPI;
end;

class function TVeloxDpi.Scale(const AValue, ADpi: Integer): Integer;
begin
  Result := MulDiv(AValue, ADpi, VELOX_DEFAULT_DPI);
end;

class function TVeloxDpi.Unscale(const AValue, ADpi: Integer): Integer;
begin
  if ADpi <= 0 then
    Result := AValue
  else
    Result := MulDiv(AValue, VELOX_DEFAULT_DPI, ADpi);
end;

class procedure TVeloxDpi.ScaleControlTree(const AParent: TWinControl;
  const AOldDpi, ANewDpi: Integer);
var
  I: Integer;
  C: TControl;
  L, T, W, H: Integer;
begin
  if (AParent = nil) or (AOldDpi <= 0) or (ANewDpi <= 0) or (AOldDpi = ANewDpi) then Exit;
  for I := 0 to AParent.ControlCount - 1 do
  begin
    C := AParent.Controls[I];
    L := C.Left;
    T := C.Top;
    W := C.Width;
    H := C.Height;
    case C.Align of
      alNone:
        C.SetBounds(MulDiv(L, ANewDpi, AOldDpi), MulDiv(T, ANewDpi, AOldDpi),
          MulDiv(W, ANewDpi, AOldDpi), MulDiv(H, ANewDpi, AOldDpi));
      alLeft, alRight:
        C.Width := MulDiv(W, ANewDpi, AOldDpi);
      alTop, alBottom:
        C.Height := MulDiv(H, ANewDpi, AOldDpi);
    end;
    if not TControlAccess(C).ParentFont then
      TControlAccess(C).Font.Height := MulDiv(TControlAccess(C).Font.Height, ANewDpi, AOldDpi);
    if C is TWinControl then
      ScaleControlTree(TWinControl(C), AOldDpi, ANewDpi);
  end;
end;

class procedure TVeloxDpi.RescaleForm(const AForm: TForm; const AOldDpi, ANewDpi: Integer);
begin
  if (AForm = nil) or (AOldDpi <= 0) or (ANewDpi <= 0) or (AOldDpi = ANewDpi) then Exit;
  AForm.ClientWidth := MulDiv(AForm.ClientWidth, ANewDpi, AOldDpi);
  AForm.ClientHeight := MulDiv(AForm.ClientHeight, ANewDpi, AOldDpi);
  ScaleControlTree(AForm, AOldDpi, ANewDpi);
end;

end.
