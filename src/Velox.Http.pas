unit Velox.Http;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Http
  Purpose:
    Tiny zero-dependency HTTP/HTTPS client (`TVeloxHttp`) built directly on the
    OS `winhttp.dll` (system proxy + TLS + redirects handled by Windows), so
    there is no Indy / Synapse / OpenSSL dependency. Provides blocking
    `Request` / `Get` / `PostJson`, `DownloadToFile` with progress + cancel,
    and `RequestAsync` that marshals the response back via `TThread.Queue`.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows;

type
  TVeloxHttpResponse = record
    Ok: Boolean;          // transport success AND HTTP 2xx
    StatusCode: Integer;
    Body: string;         // UTF-8 text
    ErrorText: string;
  end;

  TVeloxUrlParts = record
    Valid: Boolean;
    Secure: Boolean;
    Host: string;
    Port: Integer;
    Path: string;
  end;

  TVeloxHttpCallback = procedure(const AResponse: TVeloxHttpResponse) of object;
  TVeloxProgressProc = procedure(const ABytesRead, ATotalBytes: Int64; var ACancel: Boolean) of object;

  /// <summary>
  /// WinHTTP-based HTTP client
  /// </summary>
  TVeloxHttp = class
  public
    class function ParseUrl(const AUrl: string): TVeloxUrlParts; static;

    class function Request(const AMethod, AUrl: string;
      const ABody: string = ''; const AHeaders: string = '';
      const ATimeoutMs: Integer = 10000): TVeloxHttpResponse; static;

    class function Get(const AUrl: string; const AHeaders: string = '';
      const ATimeoutMs: Integer = 10000): TVeloxHttpResponse; static;

    class function PostJson(const AUrl, AJsonBody: string;
      const ATimeoutMs: Integer = 10000): TVeloxHttpResponse; static;

    /// <summary>Streams the response body straight into a file (progress + cancel).</summary>
    class function DownloadToFile(const AUrl, AFilePath: string;
      const AProgress: TVeloxProgressProc = nil;
      const ATimeoutMs: Integer = 30000): TVeloxHttpResponse; static;

    /// <summary>Runs Request on a worker thread; ACallback fires on the main thread.</summary>
    class procedure RequestAsync(const AMethod, AUrl, ABody, AHeaders: string;
      const ACallback: TVeloxHttpCallback; const ATimeoutMs: Integer = 10000); static;
  end;

implementation

var
  GWinHttpLib: HMODULE = 0;
  GWinHttpTried: Boolean = False;

  WinHttpOpen: function(pwszUserAgent: PWideChar; dwAccessType: DWORD;
    pszProxyName, pszProxyBypass: PWideChar; dwFlags: DWORD): Pointer; stdcall;
  WinHttpConnect: function(hSession: Pointer; pswzServerName: PWideChar;
    nServerPort: Word; dwReserved: DWORD): Pointer; stdcall;
  WinHttpOpenRequest: function(hConnect: Pointer; pwszVerb, pwszObjectName,
    pwszVersion, pwszReferrer: PWideChar; ppwszAcceptTypes: Pointer;
    dwFlags: DWORD): Pointer; stdcall;
  WinHttpSendRequest: function(hRequest: Pointer; pwszHeaders: PWideChar;
    dwHeadersLength: DWORD; lpOptional: Pointer; dwOptionalLength,
    dwTotalLength: DWORD; dwContext: PtrUInt): BOOL; stdcall;
  WinHttpReceiveResponse: function(hRequest: Pointer; lpReserved: Pointer): BOOL; stdcall;
  WinHttpQueryHeaders: function(hRequest: Pointer; dwInfoLevel: DWORD;
    pwszName: PWideChar; lpBuffer: Pointer; var lpdwBufferLength: DWORD;
    lpdwIndex: Pointer): BOOL; stdcall;
  WinHttpReadData: function(hRequest: Pointer; lpBuffer: Pointer;
    dwNumberOfBytesToRead: DWORD; var lpdwNumberOfBytesRead: DWORD): BOOL; stdcall;
  WinHttpCloseHandle: function(hInternet: Pointer): BOOL; stdcall;
  WinHttpSetTimeouts: function(hInternet: Pointer; nResolveTimeout, nConnectTimeout,
    nSendTimeout, nReceiveTimeout: Integer): BOOL; stdcall;

function LoadWinHttp: Boolean;
begin
  if GWinHttpTried then
    Exit(GWinHttpLib <> 0);
  GWinHttpTried := True;
  GWinHttpLib := LoadLibrary('winhttp.dll');
  if GWinHttpLib = 0 then Exit(False);
  @WinHttpOpen            := GetProcAddress(GWinHttpLib, 'WinHttpOpen');
  @WinHttpConnect         := GetProcAddress(GWinHttpLib, 'WinHttpConnect');
  @WinHttpOpenRequest     := GetProcAddress(GWinHttpLib, 'WinHttpOpenRequest');
  @WinHttpSendRequest     := GetProcAddress(GWinHttpLib, 'WinHttpSendRequest');
  @WinHttpReceiveResponse := GetProcAddress(GWinHttpLib, 'WinHttpReceiveResponse');
  @WinHttpQueryHeaders    := GetProcAddress(GWinHttpLib, 'WinHttpQueryHeaders');
  @WinHttpReadData        := GetProcAddress(GWinHttpLib, 'WinHttpReadData');
  @WinHttpCloseHandle     := GetProcAddress(GWinHttpLib, 'WinHttpCloseHandle');
  @WinHttpSetTimeouts     := GetProcAddress(GWinHttpLib, 'WinHttpSetTimeouts');
  Result := Assigned(WinHttpOpen) and Assigned(WinHttpConnect) and
    Assigned(WinHttpOpenRequest) and Assigned(WinHttpSendRequest) and
    Assigned(WinHttpReceiveResponse) and Assigned(WinHttpReadData) and
    Assigned(WinHttpCloseHandle);
  if not Result then
  begin
    FreeLibrary(GWinHttpLib);
    GWinHttpLib := 0;
  end;
end;

function StringToBytes(const AValue: string): TBytes;
begin
  Result := nil;
  {$IFDEF FPC}
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
  {$ELSE}
  Result := TEncoding.UTF8.GetBytes(AValue);
  {$ENDIF}
end;

function MemoryToString(const AStream: TMemoryStream): string;
{$IFNDEF FPC}
var
  Bytes: TBytes;
{$ENDIF}
begin
  Result := '';
  if AStream.Size = 0 then Exit;
  {$IFDEF FPC}
  SetString(Result, PAnsiChar(AStream.Memory), AStream.Size);
  {$ELSE}
  SetLength(Bytes, AStream.Size);
  Move(AStream.Memory^, Bytes[0], AStream.Size);
  Result := TEncoding.UTF8.GetString(Bytes);
  {$ENDIF}
end;

function LastErrorText(const AWhat: string): string;
var
  Code: DWORD;
begin
  Code := GetLastError;
  Result := Format('%s failed (error %d)', [AWhat, Code]);
end;

function DoRequest(const AMethod, AUrl, ABody, AHeaders: string;
  const ATimeoutMs: Integer; const AStream: TStream;
  const AProgress: TVeloxProgressProc): TVeloxHttpResponse;
const
  WINHTTP_FLAG_SECURE = $00800000;
  WINHTTP_QUERY_STATUS_CODE = 19;
  WINHTTP_QUERY_CONTENT_LENGTH = 5;
  WINHTTP_QUERY_FLAG_NUMBER = $20000000;
var
  Url: TVeloxUrlParts;
  hSession, hConnect, hRequest: Pointer;
  WUA, WHost, WVerb, WPath, WHdr: WideString;
  Flags, DataLen, Got, Status, ContentLen, LenSize: DWORD;
  DataPtr: Pointer;
  BodyBytes: TBytes;
  Buf: array[0..8191] of Byte;
  Mem: TMemoryStream;
  Sink: TStream;
  Failed, Cancel: Boolean;
  TotalRead, TotalLen: Int64;
  HdrPtr: PWideChar;
begin
  Result.Ok := False;
  Result.StatusCode := 0;
  Result.Body := '';
  Result.ErrorText := '';

  Url := TVeloxHttp.ParseUrl(AUrl);
  if not Url.Valid then
  begin
    Result.ErrorText := 'Invalid URL';
    Exit;
  end;
  if not LoadWinHttp then
  begin
    Result.ErrorText := 'winhttp.dll unavailable';
    Exit;
  end;

  hSession := nil;
  hConnect := nil;
  hRequest := nil;
  Mem := nil;
  Failed := False;
  TotalRead := 0;
  TotalLen := 0;
  try
    WUA := 'VeloxUI/1.0';
    hSession := WinHttpOpen(PWideChar(WUA), 0, nil, nil, 0);
    if hSession = nil then
    begin
      Result.ErrorText := LastErrorText('WinHttpOpen');
      Exit;
    end;
    if Assigned(WinHttpSetTimeouts) then
      WinHttpSetTimeouts(hSession, ATimeoutMs, ATimeoutMs, ATimeoutMs, ATimeoutMs);

    WHost := WideString(Url.Host);
    hConnect := WinHttpConnect(hSession, PWideChar(WHost), Word(Url.Port), 0);
    if hConnect = nil then
    begin
      Result.ErrorText := LastErrorText('WinHttpConnect');
      Exit;
    end;

    Flags := 0;
    if Url.Secure then Flags := WINHTTP_FLAG_SECURE;
    WVerb := WideString(UpperCase(AMethod));
    WPath := WideString(Url.Path);
    hRequest := WinHttpOpenRequest(hConnect, PWideChar(WVerb), PWideChar(WPath),
      nil, nil, nil, Flags);
    if hRequest = nil then
    begin
      Result.ErrorText := LastErrorText('WinHttpOpenRequest');
      Exit;
    end;

    BodyBytes := StringToBytes(ABody);
    if Length(BodyBytes) > 0 then
    begin
      DataPtr := @BodyBytes[0];
      DataLen := Length(BodyBytes);
    end
    else
    begin
      DataPtr := nil;
      DataLen := 0;
    end;

    WHdr := WideString(AHeaders);
    if Length(WHdr) > 0 then
      HdrPtr := PWideChar(WHdr)
    else
      HdrPtr := nil;

    if not WinHttpSendRequest(hRequest, HdrPtr, DWORD(Length(WHdr)),
      DataPtr, DataLen, DataLen, 0) then
    begin
      Result.ErrorText := LastErrorText('WinHttpSendRequest');
      Exit;
    end;
    if not WinHttpReceiveResponse(hRequest, nil) then
    begin
      Result.ErrorText := LastErrorText('WinHttpReceiveResponse');
      Exit;
    end;

    Status := 0;
    LenSize := SizeOf(DWORD);
    if Assigned(WinHttpQueryHeaders) and
       WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
         nil, @Status, LenSize, nil) then
      Result.StatusCode := Integer(Status);

    ContentLen := 0;
    LenSize := SizeOf(DWORD);
    if Assigned(WinHttpQueryHeaders) and
       WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_CONTENT_LENGTH or WINHTTP_QUERY_FLAG_NUMBER,
         nil, @ContentLen, LenSize, nil) then
      TotalLen := ContentLen;

    if AStream <> nil then
      Sink := AStream
    else
    begin
      Mem := TMemoryStream.Create;
      Sink := Mem;
    end;

    repeat
      Got := 0;
      if not WinHttpReadData(hRequest, @Buf[0], SizeOf(Buf), Got) then
      begin
        Result.ErrorText := LastErrorText('WinHttpReadData');
        Failed := True;
        Break;
      end;
      if Got = 0 then Break;
      Sink.WriteBuffer(Buf[0], Got);
      Inc(TotalRead, Got);
      if Assigned(AProgress) then
      begin
        Cancel := False;
        AProgress(TotalRead, TotalLen, Cancel);
        if Cancel then
        begin
          Result.ErrorText := 'Cancelled';
          Failed := True;
          Break;
        end;
      end;
    until False;

    if Mem <> nil then
      Result.Body := MemoryToString(Mem);

    if not Failed then
    begin
      Result.Ok := (Result.StatusCode >= 200) and (Result.StatusCode < 300);
      if (not Result.Ok) and (Result.ErrorText = '') then
        Result.ErrorText := 'HTTP ' + IntToStr(Result.StatusCode);
    end;
  finally
    Mem.Free;
    if hRequest <> nil then WinHttpCloseHandle(hRequest);
    if hConnect <> nil then WinHttpCloseHandle(hConnect);
    if hSession <> nil then WinHttpCloseHandle(hSession);
  end;
end;

{ ---- async worker ---- }

type
  TVeloxHttpThread = class(TThread)
  private
    FMethod, FUrl, FBody, FHeaders: string;
    FTimeout: Integer;
    FCallback: TVeloxHttpCallback;
    FResponse: TVeloxHttpResponse;
    procedure Deliver;
  protected
    procedure Execute; override;
  public
    constructor CreateRequest(const AMethod, AUrl, ABody, AHeaders: string;
      const ATimeoutMs: Integer; const ACallback: TVeloxHttpCallback);
  end;

constructor TVeloxHttpThread.CreateRequest(const AMethod, AUrl, ABody, AHeaders: string;
  const ATimeoutMs: Integer; const ACallback: TVeloxHttpCallback);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FMethod := AMethod;
  FUrl := AUrl;
  FBody := ABody;
  FHeaders := AHeaders;
  FTimeout := ATimeoutMs;
  FCallback := ACallback;
end;

procedure TVeloxHttpThread.Deliver;
begin
  if Assigned(FCallback) then
    FCallback(FResponse);
end;

procedure TVeloxHttpThread.Execute;
begin
  FResponse := DoRequest(FMethod, FUrl, FBody, FHeaders, FTimeout, nil, nil);
  if Assigned(FCallback) then
    Queue(Deliver);
end;

{ ---- TVeloxHttp ---- }

class function TVeloxHttp.ParseUrl(const AUrl: string): TVeloxUrlParts;
var
  S, Rest, HostPort: string;
  P, Q: Integer;
begin
  Result.Valid := False;
  Result.Secure := False;
  Result.Host := '';
  Result.Port := 0;
  Result.Path := '/';

  S := Trim(AUrl);
  if LowerCase(Copy(S, 1, 8)) = 'https://' then
  begin
    Result.Secure := True;
    Result.Port := 443;
    Rest := Copy(S, 9, MaxInt);
  end
  else if LowerCase(Copy(S, 1, 7)) = 'http://' then
  begin
    Result.Port := 80;
    Rest := Copy(S, 8, MaxInt);
  end
  else
    Exit;

  P := Pos('/', Rest);
  Q := Pos('?', Rest);
  if (Q > 0) and ((P = 0) or (Q < P)) then
  begin
    HostPort := Copy(Rest, 1, Q - 1);
    Result.Path := '/' + Copy(Rest, Q, MaxInt);
  end
  else if P > 0 then
  begin
    HostPort := Copy(Rest, 1, P - 1);
    Result.Path := Copy(Rest, P, MaxInt);
  end
  else
    HostPort := Rest;

  P := Pos(':', HostPort);
  if P > 0 then
  begin
    Result.Port := StrToIntDef(Copy(HostPort, P + 1, MaxInt), 0);
    HostPort := Copy(HostPort, 1, P - 1);
  end;
  Result.Host := HostPort;
  Result.Valid := (Result.Host <> '') and (Result.Port > 0) and (Result.Port < 65536);
end;

class function TVeloxHttp.Request(const AMethod, AUrl, ABody, AHeaders: string;
  const ATimeoutMs: Integer): TVeloxHttpResponse;
begin
  Result := DoRequest(AMethod, AUrl, ABody, AHeaders, ATimeoutMs, nil, nil);
end;

class function TVeloxHttp.Get(const AUrl, AHeaders: string;
  const ATimeoutMs: Integer): TVeloxHttpResponse;
begin
  Result := DoRequest('GET', AUrl, '', AHeaders, ATimeoutMs, nil, nil);
end;

class function TVeloxHttp.PostJson(const AUrl, AJsonBody: string;
  const ATimeoutMs: Integer): TVeloxHttpResponse;
begin
  Result := DoRequest('POST', AUrl, AJsonBody,
    'Content-Type: application/json' + #13#10 + 'Accept: application/json',
    ATimeoutMs, nil, nil);
end;

class function TVeloxHttp.DownloadToFile(const AUrl, AFilePath: string;
  const AProgress: TVeloxProgressProc; const ATimeoutMs: Integer): TVeloxHttpResponse;
var
  FS: TFileStream;
  Dir: string;
begin
  Result.Ok := False;
  Result.StatusCode := 0;
  Result.Body := '';
  Result.ErrorText := '';
  Dir := ExtractFileDir(AFilePath);
  if (Dir <> '') and (not DirectoryExists(Dir)) then
    ForceDirectories(Dir);
  try
    FS := TFileStream.Create(AFilePath, fmCreate);
  except
    on E: Exception do
    begin
      Result.ErrorText := E.Message;
      Exit;
    end;
  end;
  try
    Result := DoRequest('GET', AUrl, '', '', ATimeoutMs, FS, AProgress);
  finally
    FS.Free;
  end;
  if not Result.Ok then
    SysUtils.DeleteFile(AFilePath);
end;

class procedure TVeloxHttp.RequestAsync(const AMethod, AUrl, ABody, AHeaders: string;
  const ACallback: TVeloxHttpCallback; const ATimeoutMs: Integer);
var
  T: TVeloxHttpThread;
begin
  T := TVeloxHttpThread.CreateRequest(AMethod, AUrl, ABody, AHeaders, ATimeoutMs, ACallback);
  T.Start;
end;

end.
