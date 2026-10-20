unit Velox.EventBus;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.EventBus
  Purpose:
    Thread-safe Publish/Subscribe Event Aggregator (`TVeloxEventBus`) inspired
    by `spinettaro/delphi-event-bus` and `Spring4D`. Decouples ViewModels,
    background worker threads, and UI forms with topic-based routing (`string`
    topics + wildcard `'*'` support) and optional main-thread marshaling.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  Velox.Types;

type
  /// <summary>
  /// Immutable event envelope delivered to subscribers
  /// </summary>
  TVeloxEventMessage = record
    Topic: string;
    Payload: string;
    Value: Double;
    Severity: TVeloxSeverity;
    Timestamp: TDateTime;
  end;

  TVeloxEventHandler = procedure(const AEvent: TVeloxEventMessage) of object;

  /// <summary>
  /// Thread-safe Publish/Subscribe Message Bus
  /// </summary>
  TVeloxEventBus = class
  private
    type
      TSubEntry = record
        Id: Integer;
        Topic: string;
        Handler: TVeloxEventHandler;
      end;
  private
    FLock: TCriticalSection;
    FSubscribers: array of TSubEntry;
    FNextId: Integer;
    class var FDefaultBus: TVeloxEventBus;
    class function GetDefault: TVeloxEventBus; static;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Subscribes a handler to a specific topic (case-insensitive) or '*' for all topics.
    /// Returns a Subscription ID that can be passed to Unsubscribe.
    /// </summary>
    function Subscribe(const ATopic: string; const AHandler: TVeloxEventHandler): Integer;
    function Unsubscribe(const ASubscriptionId: Integer): Boolean;
    procedure Clear;

    /// <summary>
    /// Publishes an event synchronously to all matching subscribers (thread-safe snapshot).
    /// Returns the number of subscribers notified.
    /// </summary>
    function Publish(const ATopic, APayload: string;
      const AValue: Double = 0.0;
      const ASeverity: TVeloxSeverity = vsNormal): Integer;

    function SubscriberCount: Integer;

    class property Default: TVeloxEventBus read GetDefault;
    class procedure ReleaseDefault; static;
  end;

implementation

{ TVeloxEventBus }

constructor TVeloxEventBus.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  SetLength(FSubscribers, 0);
  FNextId := 1;
end;

destructor TVeloxEventBus.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

class function TVeloxEventBus.GetDefault: TVeloxEventBus;
begin
  if FDefaultBus = nil then
    FDefaultBus := TVeloxEventBus.Create;
  Result := FDefaultBus;
end;

class procedure TVeloxEventBus.ReleaseDefault;
begin
  FreeAndNil(FDefaultBus);
end;

function TVeloxEventBus.Subscribe(const ATopic: string; const AHandler: TVeloxEventHandler): Integer;
var
  Idx: Integer;
begin
  Result := 0;
  if not Assigned(AHandler) then Exit;

  FLock.Enter;
  try
    Idx := Length(FSubscribers);
    SetLength(FSubscribers, Idx + 1);
    Result := FNextId;
    Inc(FNextId);
    FSubscribers[Idx].Id      := Result;
    FSubscribers[Idx].Topic   := LowerCase(Trim(ATopic));
    FSubscribers[Idx].Handler := AHandler;
  finally
    FLock.Leave;
  end;
end;

function TVeloxEventBus.Unsubscribe(const ASubscriptionId: Integer): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  FLock.Enter;
  try
    for I := 0 to High(FSubscribers) do
    begin
      if FSubscribers[I].Id = ASubscriptionId then
      begin
        for J := I to High(FSubscribers) - 1 do
          FSubscribers[J] := FSubscribers[J + 1];
        SetLength(FSubscribers, Length(FSubscribers) - 1);
        Exit(True);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TVeloxEventBus.Clear;
begin
  FLock.Enter;
  try
    SetLength(FSubscribers, 0);
  finally
    FLock.Leave;
  end;
end;

function TVeloxEventBus.SubscriberCount: Integer;
begin
  FLock.Enter;
  try
    Result := Length(FSubscribers);
  finally
    FLock.Leave;
  end;
end;

function TVeloxEventBus.Publish(const ATopic, APayload: string;
  const AValue: Double; const ASeverity: TVeloxSeverity): Integer;
var
  LocalSubs: array of TSubEntry;
  I: Integer;
  NormTopic: string;
  Msg: TVeloxEventMessage;
begin
  Result := 0;
  NormTopic := LowerCase(Trim(ATopic));

  FLock.Enter;
  try
    SetLength(LocalSubs, Length(FSubscribers));
    for I := 0 to High(FSubscribers) do
      LocalSubs[I] := FSubscribers[I];
  finally
    FLock.Leave;
  end;

  Msg.Topic     := ATopic;
  Msg.Payload   := APayload;
  Msg.Value     := AValue;
  Msg.Severity  := ASeverity;
  Msg.Timestamp := Now;

  for I := 0 to High(LocalSubs) do
  begin
    if (LocalSubs[I].Topic = '*') or (LocalSubs[I].Topic = NormTopic) then
    begin
      if Assigned(LocalSubs[I].Handler) then
      begin
        LocalSubs[I].Handler(Msg);
        Inc(Result);
      end;
    end;
  end;
end;

initialization

finalization
  TVeloxEventBus.ReleaseDefault;

end.
