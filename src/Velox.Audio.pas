unit Velox.Audio;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows, SysUtils, Classes;

type
  TVeloxSoundType = (
    vstDefault,       // Standard beep / MB_OK
    vstError,         // Critical stop / MB_ICONHAND
    vstQuestion,      // Question prompt / MB_ICONQUESTION
    vstWarning,       // Warning alert / MB_ICONEXCLAMATION
    vstInformation    // Info chime / MB_ICONASTERISK
  );

  TVeloxAudio = class
  private
    const
      SND_ASYNC     = $00000001;
      SND_NODEFAULT = $00000002;
      SND_MEMORY    = $00000004;
      SND_LOOP      = $00000008;
      SND_NOSTOP    = $00000010;
      SND_PURGE     = $00000040;
      SND_NOWAIT    = $00002000;
      SND_ALIAS     = $00010000;
      SND_FILENAME  = $00020000;
  public
    // System chimes & earcons
    class procedure PlaySystemSound(SoundType: TVeloxSoundType); static;
    class procedure SuccessChime; static;
    class procedure ErrorChime; static;
    class procedure WarningChime; static;
    class procedure InfoChime; static;

    // WAV file playback (asynchronous or synchronous)
    class function PlayWav(const FilePath: string; Async: Boolean = True; Loop: Boolean = False): Boolean; static;
    class procedure StopAll; static;

    // Hardware frequency tone synthesis (via Win32 kernel32.Beep)
    class function Tone(FrequencyHz: Cardinal = 800; DurationMs: Cardinal = 150): Boolean; static;
  end;

implementation

function PlaySoundW(pszSound: LPCWSTR; hmod: HMODULE; fdwSound: DWORD): BOOL;
  stdcall; external 'winmm.dll' name 'PlaySoundW';

{ TVeloxAudio }

class procedure TVeloxAudio.PlaySystemSound(SoundType: TVeloxSoundType);
var
  UFlag: UINT;
begin
  case SoundType of
    vstError:       UFlag := MB_ICONHAND;
    vstQuestion:    UFlag := MB_ICONQUESTION;
    vstWarning:     UFlag := MB_ICONEXCLAMATION;
    vstInformation: UFlag := MB_ICONASTERISK;
  else
    UFlag := MB_OK;
  end;
  MessageBeep(UFlag);
end;

class procedure TVeloxAudio.SuccessChime;
begin
  PlaySystemSound(vstInformation);
end;

class procedure TVeloxAudio.ErrorChime;
begin
  PlaySystemSound(vstError);
end;

class procedure TVeloxAudio.WarningChime;
begin
  PlaySystemSound(vstWarning);
end;

class procedure TVeloxAudio.InfoChime;
begin
  PlaySystemSound(vstInformation);
end;

class function TVeloxAudio.PlayWav(const FilePath: string; Async: Boolean; Loop: Boolean): Boolean;
var
  Flags: DWORD;
  WidePath: WideString;
begin
  if not FileExists(FilePath) then
  begin
    Result := False;
    Exit;
  end;

  Flags := SND_FILENAME or SND_NODEFAULT;
  if Async then
    Flags := Flags or SND_ASYNC;
  if Loop then
    Flags := Flags or SND_LOOP or SND_ASYNC;

  WidePath := WideString(FilePath);
  Result := PlaySoundW(PWideChar(WidePath), 0, Flags);
end;

class procedure TVeloxAudio.StopAll;
begin
  PlaySoundW(nil, 0, SND_PURGE);
end;

class function TVeloxAudio.Tone(FrequencyHz: Cardinal; DurationMs: Cardinal): Boolean;
begin
  // Windows.Beep allows 37 through 32,767 Hz
  if FrequencyHz < 37 then
    FrequencyHz := 37
  else if FrequencyHz > 32767 then
    FrequencyHz := 32767;

  Result := Windows.Beep(FrequencyHz, DurationMs);
end;

end.
