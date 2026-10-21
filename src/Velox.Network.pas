unit Velox.Network;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes;

type
  TVeloxAdapterInfo = record
    AdapterName: string;
    Description: string;
    IpAddress: string;
    SubnetMask: string;
    Gateway: string;
    MacAddress: string;
    IsUp: Boolean;
    AdapterType: string;
  end;

  TVeloxAdapterArray = array of TVeloxAdapterInfo;

  TVeloxPing = class
  public
    /// <summary>Pings an IPv4 host or IP address using raw Win32 icmp.dll with sub-millisecond precision.</summary>
    class function Ping(const AHostOrIp: string; const ATimeoutMs: Cardinal; out ARttMs: Cardinal): Boolean; static;
  end;

  TVeloxNetwork = class
  public
    /// <summary>Enumerates local network adapters and active IP configurations via iphlpapi.dll.</summary>
    class function GetAdapters: TVeloxAdapterArray; static;
    /// <summary>Returns true if any network interface is online and has a non-loopback IP.</summary>
    class function IsNetworkConnected: Boolean; static;
  end;

implementation

const
  MAX_ADAPTER_NAME_LENGTH        = 256;
  MAX_ADAPTER_DESCRIPTION_LENGTH = 128;
  MAX_ADAPTER_ADDRESS_LENGTH     = 8;

type
  IP_ADDRESS_STRING = record
    S: array[0..15] of AnsiChar;
  end;

  IP_MASK_STRING = IP_ADDRESS_STRING;

  PIP_ADDR_STRING = ^IP_ADDR_STRING;
  IP_ADDR_STRING = record
    Next: PIP_ADDR_STRING;
    IpAddress: IP_ADDRESS_STRING;
    IpMask: IP_MASK_STRING;
    Context: DWORD;
  end;

  PIP_ADAPTER_INFO = ^IP_ADAPTER_INFO;
  IP_ADAPTER_INFO = record
    Next: PIP_ADAPTER_INFO;
    ComboIndex: DWORD;
    AdapterName: array[0..MAX_ADAPTER_NAME_LENGTH + 3] of AnsiChar;
    Description: array[0..MAX_ADAPTER_DESCRIPTION_LENGTH + 3] of AnsiChar;
    AddressLength: UINT;
    Address: array[0..MAX_ADAPTER_ADDRESS_LENGTH - 1] of Byte;
    Index: DWORD;
    AType: UINT;
    DhcpEnabled: UINT;
    CurrentIpAddress: PIP_ADDR_STRING;
    IpAddressList: IP_ADDR_STRING;
    GatewayList: IP_ADDR_STRING;
    DhcpServer: IP_ADDR_STRING;
    HaveWins: BOOL;
    PrimaryWinsServer: IP_ADDR_STRING;
    SecondaryWinsServer: IP_ADDR_STRING;
    LeaseObtained: LongInt;
    LeaseExpires: LongInt;
  end;

  ICMP_OPTIONS = record
    Ttl: Byte;
    Tos: Byte;
    Flags: Byte;
    OptionsSize: Byte;
    OptionsData: Pointer;
  end;

  ICMP_ECHO_REPLY = record
    Address: Cardinal;
    Status: Cardinal;
    RoundTripTime: Cardinal;
    DataSize: Word;
    Reserved: Word;
    Data: Pointer;
    Options: ICMP_OPTIONS;
  end;

function IcmpCreateFile: THandle; stdcall; external 'icmp.dll' name 'IcmpCreateFile';
function IcmpCloseHandle(IcmpHandle: THandle): BOOL; stdcall; external 'icmp.dll' name 'IcmpCloseHandle';
function IcmpSendEcho(IcmpHandle: THandle; DestinationAddress: Cardinal;
  RequestData: Pointer; RequestSize: Word; RequestOptions: Pointer;
  ReplyBuffer: Pointer; ReplySize: DWORD; Timeout: DWORD): DWORD;
  stdcall; external 'icmp.dll' name 'IcmpSendEcho';

function GetAdaptersInfo(pAdapterInfo: PIP_ADAPTER_INFO; var pOutBufLen: ULONG): DWORD;
  stdcall; external 'iphlpapi.dll' name 'GetAdaptersInfo';

function ParseIpv4(const S: string): Cardinal;
var
  Parts: TStringList;
  B0, B1, B2, B3: Cardinal;
begin
  Result := 0;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '.';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := S;
    if Parts.Count = 4 then
    begin
      B0 := StrToIntDef(Parts[0], 0);
      B1 := StrToIntDef(Parts[1], 0);
      B2 := StrToIntDef(Parts[2], 0);
      B3 := StrToIntDef(Parts[3], 0);
      Result := (B3 shl 24) or (B2 shl 16) or (B1 shl 8) or B0;
    end;
  finally
    Parts.Free;
  end;
end;

{ TVeloxPing }

class function TVeloxPing.Ping(const AHostOrIp: string; const ATimeoutMs: Cardinal; out ARttMs: Cardinal): Boolean;
var
  hIcmp: THandle;
  IpAddr: Cardinal;
  SendData: AnsiString;
  ReplySize: DWORD;
  ReplyBuf: array of Byte;
  Reply: ^ICMP_ECHO_REPLY;
  RetCount: DWORD;
begin
  ARttMs := 0;
  Result := False;

  IpAddr := ParseIpv4(AHostOrIp);
  if IpAddr = 0 then
  begin
    if SameText(AHostOrIp, 'localhost') or (AHostOrIp = '127.0.0.1') then
      IpAddr := $0100007F // 127.0.0.1 in little endian
    else
      Exit(False);
  end;

  hIcmp := IcmpCreateFile;
  if hIcmp = INVALID_HANDLE_VALUE then Exit(False);
  try
    SendData := 'VeloxPingData';
    ReplySize := SizeOf(ICMP_ECHO_REPLY) + Length(SendData) + 32;
    SetLength(ReplyBuf, ReplySize);

    RetCount := IcmpSendEcho(hIcmp, IpAddr, @SendData[1], Length(SendData),
      nil, @ReplyBuf[0], ReplySize, ATimeoutMs);

    if RetCount > 0 then
    begin
      Reply := @ReplyBuf[0];
      if Reply^.Status = 0 then
      begin
        ARttMs := Reply^.RoundTripTime;
        Result := True;
      end;
    end;
  finally
    IcmpCloseHandle(hIcmp);
  end;
end;

{ TVeloxNetwork }

class function TVeloxNetwork.GetAdapters: TVeloxAdapterArray;
var
  BufLen: ULONG;
  Buffer: array of Byte;
  PInfo: PIP_ADAPTER_INFO;
  Count, I: Integer;
  MacStr: string;
begin
  SetLength(Result, 0);
  BufLen := 0;

  // Query required buffer size
  if GetAdaptersInfo(nil, BufLen) <> 111 { ERROR_BUFFER_OVERFLOW } then
    Exit;

  SetLength(Buffer, BufLen);
  PInfo := PIP_ADAPTER_INFO(@Buffer[0]);

  if GetAdaptersInfo(PInfo, BufLen) <> 0 then
    Exit;

  Count := 0;
  while PInfo <> nil do
  begin
    Inc(Count);
    SetLength(Result, Count);

    Result[Count - 1].AdapterName := string(AnsiString(PInfo^.AdapterName));
    Result[Count - 1].Description := string(AnsiString(PInfo^.Description));
    Result[Count - 1].IpAddress   := string(AnsiString(PInfo^.IpAddressList.IpAddress.S));
    Result[Count - 1].SubnetMask  := string(AnsiString(PInfo^.IpAddressList.IpMask.S));
    Result[Count - 1].Gateway     := string(AnsiString(PInfo^.GatewayList.IpAddress.S));

    MacStr := '';
    for I := 0 to Integer(PInfo^.AddressLength) - 1 do
    begin
      if MacStr <> '' then MacStr := MacStr + '-';
      MacStr := MacStr + IntToHex(PInfo^.Address[I], 2);
    end;
    Result[Count - 1].MacAddress := MacStr;

    case PInfo^.AType of
      6: Result[Count - 1].AdapterType := 'Ethernet';
      71: Result[Count - 1].AdapterType := 'Wi-Fi';
    else
      Result[Count - 1].AdapterType := 'Other';
    end;

    Result[Count - 1].IsUp := (Result[Count - 1].IpAddress <> '') and
                              (Result[Count - 1].IpAddress <> '0.0.0.0');

    PInfo := PInfo^.Next;
  end;
end;

class function TVeloxNetwork.IsNetworkConnected: Boolean;
var
  Adapters: TVeloxAdapterArray;
  I: Integer;
begin
  Adapters := GetAdapters;
  for I := 0 to High(Adapters) do
  begin
    if Adapters[I].IsUp and (Adapters[I].IpAddress <> '127.0.0.1') then
      Exit(True);
  end;
  Result := False;
end;

end.
