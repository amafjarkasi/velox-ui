unit Velox.Reactive;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Reactive
  Purpose:
    1. Generic Observable Property wrapper (`TVeloxObservable<T>`) inspired by
       Grijjy Foundation MVVM Starter Kit & RxDelphi. Notifies registered
       subscribers whenever `.Value` changes, and supports 1-line `BindLabel`
       caption formatting.
    2. Non-blocking UI Event Debouncer (`TVeloxDebouncer`) using `TTimer` to
       coalesce rapid-fire events (e.g. search-as-you-type keystrokes or
       window resize events) into a single execution after `DelayMs` of quiet.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  StdCtrls,
  ExtCtrls;

type
  TVeloxValueChangeProc<T> = procedure(const AValue: T) of object;
  TVeloxFormatFunc<T> = function(const AValue: T): string of object;

  /// <summary>
  /// Generic observable property container with automatic UI label binding
  /// </summary>
  TVeloxObservable<T> = class
  private
    FValue: T;
    FListeners: array of TVeloxValueChangeProc<T>;
    FBoundLabel: TLabel;
    FFormatFunc: TVeloxFormatFunc<T>;
    FPrefix: string;
    FSuffix: string;
    procedure SetValue(const ANewValue: T);
    procedure NotifyAll;
  public
    constructor Create(const AInitialValue: T);

    /// <summary>
    /// Subscribes a callback to be invoked immediately and whenever Value changes.
    /// </summary>
    procedure Subscribe(const AListener: TVeloxValueChangeProc<T>; const AFireImmediately: Boolean = True);
    procedure ClearSubscribers;

    /// <summary>
    /// Binds a TLabel so its Caption updates automatically whenever Value changes.
    /// </summary>
    procedure BindLabel(const ALabel: TLabel; const APrefix: string = '';
      const ASuffix: string = ''; const AFormatter: TVeloxFormatFunc<T> = nil);

    property Value: T read FValue write SetValue;
  end;

  /// <summary>
  /// Non-blocking rate-limiting debouncer for rapid UI inputs (e.g. search boxes)
  /// </summary>
  TVeloxDebouncer = class(TComponent)
  private
    FTimer: TTimer;
    FDelayMs: Cardinal;
    FOnDebounced: TNotifyEvent;
    FPendingSender: TObject;
    FPendingCount: Integer;
    procedure OnTimerFired(Sender: TObject);
    function GetIsPending: Boolean;
  public
    constructor CreateDebouncer(AOwner: TComponent; const ADelayMs: Cardinal;
      const AOnDebounced: TNotifyEvent);
    destructor Destroy; override;

    /// <summary>
    /// Resets the debounce countdown timer. The callback will only fire once
    /// ADelayMs elapses with no new Trigger calls.
    /// </summary>
    procedure Trigger(Sender: TObject = nil);

    /// <summary>
    /// Immediately executes any pending debounced invocation and stops the timer.
    /// </summary>
    procedure Flush;
    procedure Cancel;

    property DelayMs: Cardinal read FDelayMs write FDelayMs;
    property IsPending: Boolean read GetIsPending;
    property PendingCount: Integer read FPendingCount;
  end;

implementation

{ TVeloxObservable<T> }

constructor TVeloxObservable<T>.Create(const AInitialValue: T);
begin
  inherited Create;
  FValue := AInitialValue;
  SetLength(FListeners, 0);
  FBoundLabel := nil;
  FFormatFunc := nil;
  FPrefix := '';
  FSuffix := '';
end;

procedure TVeloxObservable<T>.SetValue(const ANewValue: T);
begin
  FValue := ANewValue;
  NotifyAll;
end;

procedure TVeloxObservable<T>.Subscribe(const AListener: TVeloxValueChangeProc<T>;
  const AFireImmediately: Boolean);
var
  Idx: Integer;
begin
  if not Assigned(AListener) then Exit;
  Idx := Length(FListeners);
  SetLength(FListeners, Idx + 1);
  FListeners[Idx] := AListener;
  if AFireImmediately then
    AListener(FValue);
end;

procedure TVeloxObservable<T>.ClearSubscribers;
begin
  SetLength(FListeners, 0);
end;

procedure TVeloxObservable<T>.BindLabel(const ALabel: TLabel;
  const APrefix, ASuffix: string; const AFormatter: TVeloxFormatFunc<T>);
begin
  FBoundLabel := ALabel;
  FPrefix := APrefix;
  FSuffix := ASuffix;
  FFormatFunc := AFormatter;
  NotifyAll;
end;

procedure TVeloxObservable<T>.NotifyAll;
var
  I: Integer;
begin
  if Assigned(FBoundLabel) then
  begin
    if Assigned(FFormatFunc) then
      FBoundLabel.Caption := FPrefix + FFormatFunc(FValue) + FSuffix
    else
      FBoundLabel.Caption := FPrefix + FSuffix;
  end;

  for I := 0 to High(FListeners) do
    if Assigned(FListeners[I]) then
      FListeners[I](FValue);
end;

{ TVeloxDebouncer }

constructor TVeloxDebouncer.CreateDebouncer(AOwner: TComponent;
  const ADelayMs: Cardinal; const AOnDebounced: TNotifyEvent);
begin
  inherited Create(AOwner);
  if ADelayMs < 10 then
    FDelayMs := 150
  else
    FDelayMs := ADelayMs;
  FOnDebounced := AOnDebounced;
  FPendingSender := nil;
  FPendingCount := 0;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := FDelayMs;
  FTimer.OnTimer := OnTimerFired;
end;

destructor TVeloxDebouncer.Destroy;
begin
  FTimer.Enabled := False;
  inherited Destroy;
end;

function TVeloxDebouncer.GetIsPending: Boolean;
begin
  Result := Assigned(FTimer) and FTimer.Enabled;
end;

procedure TVeloxDebouncer.Trigger(Sender: TObject);
begin
  FPendingSender := Sender;
  Inc(FPendingCount);
  FTimer.Enabled := False;
  FTimer.Interval := FDelayMs;
  FTimer.Enabled := True;
end;

procedure TVeloxDebouncer.Flush;
begin
  if FTimer.Enabled or (FPendingCount > 0) then
  begin
    FTimer.Enabled := False;
    FPendingCount := 0;
    if Assigned(FOnDebounced) then
      FOnDebounced(FPendingSender);
  end;
end;

procedure TVeloxDebouncer.Cancel;
begin
  FTimer.Enabled := False;
  FPendingCount := 0;
end;

procedure TVeloxDebouncer.OnTimerFired(Sender: TObject);
begin
  FTimer.Enabled := False;
  FPendingCount := 0;
  if Assigned(FOnDebounced) then
    FOnDebounced(FPendingSender);
end;

end.
