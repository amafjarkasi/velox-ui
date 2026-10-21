unit Velox.Crypto;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Crypto
  Purpose:
    Zero-dependency cryptography, hashing, and encoding engine (`TVeloxCrypto`)
    built on the Windows Cryptography API: Next Generation (`bcrypt.dll` / CNG).
    Provides hardware-accelerated SHA-256, SHA-1, and MD5, plus built-in
    IEEE 802.3 CRC32 and RFC-4648 Base64 encode/decode.
    Zero external DLLs, Indy, or OpenSSL dependencies.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Windows;

type
  TVeloxHashAlgo = (vhaSha256, vhaSha1, vhaMd5);

  /// <summary>
  /// Zero-dependency Windows CNG cryptographic hashing and Base64 engine
  /// </summary>
  TVeloxCrypto = class
  public
    /// <summary>Computes the SHA-256 hex string of a UTF-8 text string.</summary>
    class function Sha256(const AText: string): string; static;
    /// <summary>Computes the SHA-1 hex string of a UTF-8 text string.</summary>
    class function Sha1(const AText: string): string; static;
    /// <summary>Computes the MD5 hex string of a UTF-8 text string.</summary>
    class function Md5(const AText: string): string; static;

    /// <summary>Computes the cryptographic hash of a raw byte buffer.</summary>
    class function HashBytes(const ABuffer: Pointer; const ALength: Cardinal;
      const AAlgo: TVeloxHashAlgo): string; static;

    /// <summary>Streams and hashes a file in 64 KB chunks without loading it all into RAM.</summary>
    class function HashFile(const AFilePath: string; const AAlgo: TVeloxHashAlgo): string; static;

    /// <summary>Computes standard IEEE 802.3 CRC-32 checksum as a 32-bit unsigned integer.</summary>
    class function Crc32(const ABuffer: Pointer; const ALength: Cardinal): Cardinal; overload; static;
    class function Crc32(const AText: string): Cardinal; overload; static;
    class function Crc32Hex(const AText: string): string; static;

    /// <summary>Encodes binary or string data to RFC-4648 Base64.</summary>
    class function Base64Encode(const ABuffer: Pointer; const ALength: Cardinal): string; overload; static;
    class function Base64Encode(const AText: string): string; overload; static;

    /// <summary>Decodes RFC-4648 Base64 text to a string or stream.</summary>
    class function Base64Decode(const ABase64: string): string; overload; static;
    class function Base64DecodeToStream(const ABase64: string; const AStream: TStream): Boolean; overload; static;
  end;

implementation

const
  BCRYPT_SHA256_ALGORITHM: UnicodeString = 'SHA256';
  BCRYPT_SHA1_ALGORITHM: UnicodeString   = 'SHA1';
  BCRYPT_MD5_ALGORITHM: UnicodeString    = 'MD5';
  BCRYPT_OBJECT_LENGTH: UnicodeString    = 'ObjectLength';
  BCRYPT_HASH_LENGTH: UnicodeString      = 'HashDigestLength';

type
  BCRYPT_ALG_HANDLE  = Pointer;
  BCRYPT_HASH_HANDLE = Pointer;
  NTSTATUS           = LongInt;

var
  GBCryptLib: HMODULE = 0;
  GBCryptTried: Boolean = False;

  BCryptOpenAlgorithmProvider: function(out phAlgorithm: BCRYPT_ALG_HANDLE;
    pszAlgId: PWideChar; pszImplementation: PWideChar; dwFlags: ULONG): NTSTATUS; stdcall;
  BCryptCloseAlgorithmProvider: function(hAlgorithm: BCRYPT_ALG_HANDLE; dwFlags: ULONG): NTSTATUS; stdcall;
  BCryptGetProperty: function(hObject: Pointer; pszProperty: PWideChar;
    pbOutput: Pointer; cbOutput: ULONG; out pcbResult: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  BCryptCreateHash: function(hAlgorithm: BCRYPT_ALG_HANDLE; out phHash: BCRYPT_HASH_HANDLE;
    pbHashObject: Pointer; cbHashObject: ULONG; pbSecret: Pointer; cbSecret: ULONG;
    dwFlags: ULONG): NTSTATUS; stdcall;
  BCryptHashData: function(hHash: BCRYPT_HASH_HANDLE; pbInput: Pointer;
    cbInput: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  BCryptFinishHash: function(hHash: BCRYPT_HASH_HANDLE; pbOutput: Pointer;
    cbOutput: ULONG; dwFlags: ULONG): NTSTATUS; stdcall;
  BCryptDestroyHash: function(hHash: BCRYPT_HASH_HANDLE): NTSTATUS; stdcall;

function LoadBCrypt: Boolean;
begin
  if GBCryptTried then
    Exit(GBCryptLib <> 0);
  GBCryptTried := True;
  GBCryptLib := LoadLibrary('bcrypt.dll');
  if GBCryptLib = 0 then Exit(False);

  @BCryptOpenAlgorithmProvider  := GetProcAddress(GBCryptLib, 'BCryptOpenAlgorithmProvider');
  @BCryptCloseAlgorithmProvider := GetProcAddress(GBCryptLib, 'BCryptCloseAlgorithmProvider');
  @BCryptGetProperty            := GetProcAddress(GBCryptLib, 'BCryptGetProperty');
  @BCryptCreateHash             := GetProcAddress(GBCryptLib, 'BCryptCreateHash');
  @BCryptHashData               := GetProcAddress(GBCryptLib, 'BCryptHashData');
  @BCryptFinishHash             := GetProcAddress(GBCryptLib, 'BCryptFinishHash');
  @BCryptDestroyHash            := GetProcAddress(GBCryptLib, 'BCryptDestroyHash');

  Result := Assigned(BCryptOpenAlgorithmProvider) and Assigned(BCryptCreateHash) and
            Assigned(BCryptHashData) and Assigned(BCryptFinishHash);
end;

function AlgoIdToPWideChar(const AAlgo: TVeloxHashAlgo): PWideChar;
begin
  case AAlgo of
    vhaSha256: Result := PWideChar(BCRYPT_SHA256_ALGORITHM);
    vhaSha1:   Result := PWideChar(BCRYPT_SHA1_ALGORITHM);
    vhaMd5:    Result := PWideChar(BCRYPT_MD5_ALGORITHM);
  else
    Result := PWideChar(BCRYPT_SHA256_ALGORITHM);
  end;
end;

function BytesToHex(const ABytes: Pointer; const ACount: Integer): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  P: PByte;
  I: Integer;
begin
  SetLength(Result, ACount * 2);
  P := PByte(ABytes);
  for I := 0 to ACount - 1 do
  begin
    Result[I * 2 + 1] := HexChars[P^ shr 4];
    Result[I * 2 + 2] := HexChars[P^ and $0F];
    Inc(P);
  end;
end;

{ TVeloxCrypto }

class function TVeloxCrypto.HashBytes(const ABuffer: Pointer; const ALength: Cardinal;
  const AAlgo: TVeloxHashAlgo): string;
var
  hAlg: BCRYPT_ALG_HANDLE;
  hHash: BCRYPT_HASH_HANDLE;
  ObjLen, HashLen, ResLen: ULONG;
  HashObj: array of Byte;
  Digest: array of Byte;
begin
  Result := '';
  if not LoadBCrypt then Exit;

  if BCryptOpenAlgorithmProvider(hAlg, AlgoIdToPWideChar(AAlgo), nil, 0) <> 0 then
    Exit;
  try
    ObjLen := 0;
    if BCryptGetProperty(hAlg, PWideChar(BCRYPT_OBJECT_LENGTH),
      @ObjLen, SizeOf(ObjLen), ResLen, 0) <> 0 then Exit;

    HashLen := 0;
    if BCryptGetProperty(hAlg, PWideChar(BCRYPT_HASH_LENGTH),
      @HashLen, SizeOf(HashLen), ResLen, 0) <> 0 then Exit;

    SetLength(HashObj, ObjLen);
    SetLength(Digest, HashLen);

    if BCryptCreateHash(hAlg, hHash, @HashObj[0], ObjLen, nil, 0, 0) <> 0 then
      Exit;
    try
      if (ALength > 0) and (ABuffer <> nil) then
        BCryptHashData(hHash, ABuffer, ALength, 0);
      if BCryptFinishHash(hHash, @Digest[0], HashLen, 0) = 0 then
        Result := BytesToHex(@Digest[0], HashLen);
    finally
      BCryptDestroyHash(hHash);
    end;
  finally
    BCryptCloseAlgorithmProvider(hAlg, 0);
  end;
end;

class function TVeloxCrypto.Sha256(const AText: string): string;
var
  U8: UTF8String;
begin
  U8 := UTF8Encode(AText);
  if Length(U8) = 0 then
    Result := HashBytes(nil, 0, vhaSha256)
  else
    Result := HashBytes(@U8[1], Length(U8), vhaSha256);
end;

class function TVeloxCrypto.Sha1(const AText: string): string;
var
  U8: UTF8String;
begin
  U8 := UTF8Encode(AText);
  if Length(U8) = 0 then
    Result := HashBytes(nil, 0, vhaSha1)
  else
    Result := HashBytes(@U8[1], Length(U8), vhaSha1);
end;

class function TVeloxCrypto.Md5(const AText: string): string;
var
  U8: UTF8String;
begin
  U8 := UTF8Encode(AText);
  if Length(U8) = 0 then
    Result := HashBytes(nil, 0, vhaMd5)
  else
    Result := HashBytes(@U8[1], Length(U8), vhaMd5);
end;

class function TVeloxCrypto.HashFile(const AFilePath: string; const AAlgo: TVeloxHashAlgo): string;
var
  Stream: TFileStream;
  Buf: array[0..65535] of Byte;
  ReadBytes: Integer;
  hAlg: BCRYPT_ALG_HANDLE;
  hHash: BCRYPT_HASH_HANDLE;
  ObjLen, HashLen, ResLen: ULONG;
  HashObj, Digest: array of Byte;
begin
  Result := '';
  if (not FileExists(AFilePath)) or (not LoadBCrypt) then Exit;

  if BCryptOpenAlgorithmProvider(hAlg, AlgoIdToPWideChar(AAlgo), nil, 0) <> 0 then
    Exit;
  try
    ObjLen := 0;
    BCryptGetProperty(hAlg, PWideChar(BCRYPT_OBJECT_LENGTH),
      @ObjLen, SizeOf(ObjLen), ResLen, 0);
    HashLen := 0;
    BCryptGetProperty(hAlg, PWideChar(BCRYPT_HASH_LENGTH),
      @HashLen, SizeOf(HashLen), ResLen, 0);

    SetLength(HashObj, ObjLen);
    SetLength(Digest, HashLen);

    if BCryptCreateHash(hAlg, hHash, @HashObj[0], ObjLen, nil, 0, 0) <> 0 then
      Exit;
    try
      Stream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyNone);
      try
        repeat
          ReadBytes := Stream.Read(Buf, SizeOf(Buf));
          if ReadBytes > 0 then
            BCryptHashData(hHash, @Buf[0], ReadBytes, 0);
        until ReadBytes = 0;
      finally
        Stream.Free;
      end;
      if BCryptFinishHash(hHash, @Digest[0], HashLen, 0) = 0 then
        Result := BytesToHex(@Digest[0], HashLen);
    finally
      BCryptDestroyHash(hHash);
    end;
  finally
    BCryptCloseAlgorithmProvider(hAlg, 0);
  end;
end;

{ CRC-32 (IEEE 802.3 Polynomial $EDB88320) }

var
  GCrcTable: array[0..255] of Cardinal;
  GCrcTableInit: Boolean = False;

procedure InitCrcTable;
var
  C: Cardinal;
  I, J: Integer;
begin
  if GCrcTableInit then Exit;
  for I := 0 to 255 do
  begin
    C := I;
    for J := 0 to 7 do
    begin
      if (C and 1) <> 0 then
        C := (C shr 1) xor Cardinal($EDB88320)
      else
        C := C shr 1;
    end;
    GCrcTable[I] := C;
  end;
  GCrcTableInit := True;
end;

class function TVeloxCrypto.Crc32(const ABuffer: Pointer; const ALength: Cardinal): Cardinal;
var
  P: PByte;
  I: Cardinal;
begin
  InitCrcTable;
  Result := $FFFFFFFF;
  if (ABuffer = nil) or (ALength = 0) then Exit(0);
  P := PByte(ABuffer);
  for I := 0 to ALength - 1 do
  begin
    Result := (Result shr 8) xor GCrcTable[(Result and $FF) xor P^];
    Inc(P);
  end;
  Result := Result xor $FFFFFFFF;
end;

class function TVeloxCrypto.Crc32(const AText: string): Cardinal;
var
  U8: UTF8String;
begin
  U8 := UTF8Encode(AText);
  if Length(U8) = 0 then Exit(0);
  Result := Crc32(@U8[1], Length(U8));
end;

class function TVeloxCrypto.Crc32Hex(const AText: string): string;
begin
  Result := LowerCase(IntToHex(Crc32(AText), 8));
end;

{ Base64 (RFC-4648) }

const
  B64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

class function TVeloxCrypto.Base64Encode(const ABuffer: Pointer; const ALength: Cardinal): string;
var
  Src: PByte;
  I, Remain: Cardinal;
  B0, B1, B2: Byte;
  OutLen: Cardinal;
  Dst: PChar;
begin
  if (ABuffer = nil) or (ALength = 0) then Exit('');
  OutLen := ((ALength + 2) div 3) * 4;
  SetLength(Result, OutLen);
  Src := PByte(ABuffer);
  Dst := PChar(Result);
  I := 0;
  while I + 3 <= ALength do
  begin
    B0 := Src^; Inc(Src);
    B1 := Src^; Inc(Src);
    B2 := Src^; Inc(Src);
    Dst^ := B64Chars[(B0 shr 2) + 1]; Inc(Dst);
    Dst^ := B64Chars[(((B0 and 3) shl 4) or (B1 shr 4)) + 1]; Inc(Dst);
    Dst^ := B64Chars[(((B1 and $0F) shl 2) or (B2 shr 6)) + 1]; Inc(Dst);
    Dst^ := B64Chars[(B2 and $3F) + 1]; Inc(Dst);
    Inc(I, 3);
  end;
  Remain := ALength - I;
  if Remain = 1 then
  begin
    B0 := Src^;
    Dst^ := B64Chars[(B0 shr 2) + 1]; Inc(Dst);
    Dst^ := B64Chars[((B0 and 3) shl 4) + 1]; Inc(Dst);
    Dst^ := '='; Inc(Dst);
    Dst^ := '=';
  end
  else if Remain = 2 then
  begin
    B0 := Src^; Inc(Src);
    B1 := Src^;
    Dst^ := B64Chars[(B0 shr 2) + 1]; Inc(Dst);
    Dst^ := B64Chars[(((B0 and 3) shl 4) or (B1 shr 4)) + 1]; Inc(Dst);
    Dst^ := B64Chars[((B1 and $0F) shl 2) + 1]; Inc(Dst);
    Dst^ := '=';
  end;
end;

class function TVeloxCrypto.Base64Encode(const AText: string): string;
var
  U8: UTF8String;
begin
  U8 := UTF8Encode(AText);
  if Length(U8) = 0 then Exit('');
  Result := Base64Encode(@U8[1], Length(U8));
end;

function DecodeChar(const C: Char): Integer;
begin
  case C of
    'A'..'Z': Result := Ord(C) - Ord('A');
    'a'..'z': Result := Ord(C) - Ord('a') + 26;
    '0'..'9': Result := Ord(C) - Ord('0') + 52;
    '+':      Result := 62;
    '/':      Result := 63;
    '=':      Result := -1;
  else
    Result := -2;
  end;
end;

class function TVeloxCrypto.Base64DecodeToStream(const ABase64: string; const AStream: TStream): Boolean;
var
  I, N, Val: Integer;
  C: Char;
  Group: array[0..3] of Integer;
  GroupCount: Integer;
  B: Byte;
begin
  Result := False;
  if AStream = nil then Exit;
  GroupCount := 0;
  N := Length(ABase64);
  for I := 1 to N do
  begin
    C := ABase64[I];
    if C in [#9, #10, #13, ' '] then Continue;
    Val := DecodeChar(C);
    if Val = -2 then Exit(False); // Invalid char
    Group[GroupCount] := Val;
    Inc(GroupCount);
    if GroupCount = 4 then
    begin
      // 4 group values -> 1 to 3 bytes
      B := (Group[0] shl 2) or (Group[1] shr 4);
      AStream.Write(B, 1);
      if Group[2] <> -1 then
      begin
        B := ((Group[1] and $0F) shl 4) or (Group[2] shr 2);
        AStream.Write(B, 1);
        if Group[3] <> -1 then
        begin
          B := ((Group[2] and 3) shl 6) or Group[3];
          AStream.Write(B, 1);
        end;
      end;
      GroupCount := 0;
    end;
  end;
  Result := GroupCount = 0;
end;

class function TVeloxCrypto.Base64Decode(const ABase64: string): string;
var
  MS: TMemoryStream;
  U8: UTF8String;
begin
  Result := '';
  MS := TMemoryStream.Create;
  try
    if Base64DecodeToStream(ABase64, MS) and (MS.Size > 0) then
    begin
      SetLength(U8, MS.Size);
      Move(MS.Memory^, U8[1], MS.Size);
      Result := UTF8Decode(U8);
    end;
  finally
    MS.Free;
  end;
end;

end.
