unit Velox.Registry;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes;

type
  TVeloxRegView = (vrvDefault, vrv32Bit, vrv64Bit);

  TVeloxRegistry = class
  private
    const
      KEY_WOW64_64KEY = $0100;
      KEY_WOW64_32KEY = $0200;
      AUTOSTART_KEY: UnicodeString = 'Software\Microsoft\Windows\CurrentVersion\Run';
    class function AccessFlags(const AAccess: REGSAM; const AView: TVeloxRegView): REGSAM; static;
  public
    class function ReadString(RootKey: HKEY; const KeyPath, ValueName, DefaultVal: string;
      View: TVeloxRegView = vrvDefault): string; static;
    class function ReadInteger(RootKey: HKEY; const KeyPath, ValueName: string; DefaultVal: Integer = 0;
      View: TVeloxRegView = vrvDefault): Integer; static;
    class function ReadBoolean(RootKey: HKEY; const KeyPath, ValueName: string; DefaultVal: Boolean = False;
      View: TVeloxRegView = vrvDefault): Boolean; static;

    class function WriteString(RootKey: HKEY; const KeyPath, ValueName, Value: string;
      View: TVeloxRegView = vrvDefault): Boolean; static;
    class function WriteInteger(RootKey: HKEY; const KeyPath, ValueName: string; Value: Integer;
      View: TVeloxRegView = vrvDefault): Boolean; static;
    class function WriteBoolean(RootKey: HKEY; const KeyPath, ValueName: string; Value: Boolean;
      View: TVeloxRegView = vrvDefault): Boolean; static;

    class function DeleteValue(RootKey: HKEY; const KeyPath, ValueName: string;
      View: TVeloxRegView = vrvDefault): Boolean; static;
    class function KeyExists(RootKey: HKEY; const KeyPath: string;
      View: TVeloxRegView = vrvDefault): Boolean; static;

    /// <summary>Enables or disables automatic application launch on Windows user login (HKCU\...\Run).</summary>
    class function SetAutostart(const AppName, ExePath: string; Enable: Boolean): Boolean; static;
    /// <summary>Checks if an autostart entry is present in HKCU\...\Run.</summary>
    class function IsAutostart(const AppName: string): Boolean; static;
  end;

implementation

{ TVeloxRegistry }

class function TVeloxRegistry.AccessFlags(const AAccess: REGSAM; const AView: TVeloxRegView): REGSAM;
begin
  Result := AAccess;
  case AView of
    vrv64Bit: Result := Result or KEY_WOW64_64KEY;
    vrv32Bit: Result := Result or KEY_WOW64_32KEY;
  end;
end;

class function TVeloxRegistry.KeyExists(RootKey: HKEY; const KeyPath: string;
  View: TVeloxRegView): Boolean;
var
  SubKey: HKEY;
  WidePath: WideString;
begin
  WidePath := WideString(KeyPath);
  if RegOpenKeyExW(RootKey, PWideChar(WidePath), 0, AccessFlags(KEY_READ, View), SubKey) = ERROR_SUCCESS then
  begin
    RegCloseKey(SubKey);
    Result := True;
  end
  else
    Result := False;
end;

class function TVeloxRegistry.ReadString(RootKey: HKEY; const KeyPath, ValueName, DefaultVal: string;
  View: TVeloxRegView): string;
var
  SubKey: HKEY;
  ValType, BufSize: DWORD;
  Buf: array of WideChar;
  WidePath, WideVal: WideString;
  Len: Integer;
begin
  Result := DefaultVal;
  WidePath := WideString(KeyPath);
  WideVal := WideString(ValueName);

  if RegOpenKeyExW(RootKey, PWideChar(WidePath), 0, AccessFlags(KEY_QUERY_VALUE, View), SubKey) = ERROR_SUCCESS then
  begin
    try
      BufSize := 0;
      if RegQueryValueExW(SubKey, PWideChar(WideVal), nil, @ValType, nil, @BufSize) = ERROR_SUCCESS then
      begin
        if (ValType = REG_SZ) or (ValType = REG_EXPAND_SZ) then
        begin
          SetLength(Buf, (BufSize div SizeOf(WideChar)) + 2);
          FillChar(Buf[0], Length(Buf) * SizeOf(WideChar), 0);
          if RegQueryValueExW(SubKey, PWideChar(WideVal), nil, @ValType, @Buf[0], @BufSize) = ERROR_SUCCESS then
          begin
            Len := BufSize div SizeOf(WideChar);
            while (Len > 0) and (Buf[Len - 1] = #0) do
              Dec(Len);
            SetString(Result, PWideChar(@Buf[0]), Len);
          end;
        end;
      end;
    finally
      RegCloseKey(SubKey);
    end;
  end;
end;

class function TVeloxRegistry.ReadInteger(RootKey: HKEY; const KeyPath, ValueName: string;
  DefaultVal: Integer; View: TVeloxRegView): Integer;
var
  SubKey: HKEY;
  ValType, BufSize, Data: DWORD;
  WidePath, WideVal: WideString;
begin
  Result := DefaultVal;
  WidePath := WideString(KeyPath);
  WideVal := WideString(ValueName);

  if RegOpenKeyExW(RootKey, PWideChar(WidePath), 0, AccessFlags(KEY_QUERY_VALUE, View), SubKey) = ERROR_SUCCESS then
  begin
    try
      BufSize := SizeOf(Data);
      if RegQueryValueExW(SubKey, PWideChar(WideVal), nil, @ValType, @Data, @BufSize) = ERROR_SUCCESS then
      begin
        if ValType = REG_DWORD then
          Result := Integer(Data);
      end;
    finally
      RegCloseKey(SubKey);
    end;
  end;
end;

class function TVeloxRegistry.ReadBoolean(RootKey: HKEY; const KeyPath, ValueName: string;
  DefaultVal: Boolean; View: TVeloxRegView): Boolean;
begin
  Result := (ReadInteger(RootKey, KeyPath, ValueName, Ord(DefaultVal), View) <> 0);
end;

class function TVeloxRegistry.WriteString(RootKey: HKEY; const KeyPath, ValueName, Value: string;
  View: TVeloxRegView): Boolean;
var
  SubKey: HKEY;
  WidePath, WideVal, WideData: WideString;
  Disp: DWORD;
begin
  Result := False;
  WidePath := WideString(KeyPath);
  WideVal := WideString(ValueName);
  WideData := WideString(Value);

  if RegCreateKeyExW(RootKey, PWideChar(WidePath), 0, nil, 0,
     AccessFlags(KEY_SET_VALUE, View), nil, SubKey, @Disp) = ERROR_SUCCESS then
  begin
    try
      Result := (RegSetValueExW(SubKey, PWideChar(WideVal), 0, REG_SZ,
        PWideChar(WideData), (Length(WideData) + 1) * SizeOf(WideChar)) = ERROR_SUCCESS);
    finally
      RegCloseKey(SubKey);
    end;
  end;
end;

class function TVeloxRegistry.WriteInteger(RootKey: HKEY; const KeyPath, ValueName: string;
  Value: Integer; View: TVeloxRegView): Boolean;
var
  SubKey: HKEY;
  WidePath, WideVal: WideString;
  Data, Disp: DWORD;
begin
  Result := False;
  WidePath := WideString(KeyPath);
  WideVal := WideString(ValueName);
  Data := DWORD(Value);

  if RegCreateKeyExW(RootKey, PWideChar(WidePath), 0, nil, 0,
     AccessFlags(KEY_SET_VALUE, View), nil, SubKey, @Disp) = ERROR_SUCCESS then
  begin
    try
      Result := (RegSetValueExW(SubKey, PWideChar(WideVal), 0, REG_DWORD,
        @Data, SizeOf(Data)) = ERROR_SUCCESS);
    finally
      RegCloseKey(SubKey);
    end;
  end;
end;

class function TVeloxRegistry.WriteBoolean(RootKey: HKEY; const KeyPath, ValueName: string;
  Value: Boolean; View: TVeloxRegView): Boolean;
begin
  Result := WriteInteger(RootKey, KeyPath, ValueName, Ord(Value), View);
end;

class function TVeloxRegistry.DeleteValue(RootKey: HKEY; const KeyPath, ValueName: string;
  View: TVeloxRegView): Boolean;
var
  SubKey: HKEY;
  WidePath, WideVal: WideString;
begin
  Result := False;
  WidePath := WideString(KeyPath);
  WideVal := WideString(ValueName);

  if RegOpenKeyExW(RootKey, PWideChar(WidePath), 0, AccessFlags(KEY_SET_VALUE, View), SubKey) = ERROR_SUCCESS then
  begin
    try
      Result := (RegDeleteValueW(SubKey, PWideChar(WideVal)) = ERROR_SUCCESS);
    finally
      RegCloseKey(SubKey);
    end;
  end;
end;

class function TVeloxRegistry.SetAutostart(const AppName, ExePath: string; Enable: Boolean): Boolean;
begin
  if Enable then
    Result := WriteString(HKEY_CURRENT_USER, string(AUTOSTART_KEY), AppName, '"' + ExePath + '"')
  else
    Result := DeleteValue(HKEY_CURRENT_USER, string(AUTOSTART_KEY), AppName);
end;

class function TVeloxRegistry.IsAutostart(const AppName: string): Boolean;
begin
  Result := (ReadString(HKEY_CURRENT_USER, string(AUTOSTART_KEY), AppName, '') <> '');
end;

end.
