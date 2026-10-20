unit Velox.TreeBuilder;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.TreeBuilder
  Purpose:
    Generic Flat-to-Hierarchical Tree Flattener (`TVeloxTreeBuilder<T>`)
    inspired by `JAM-Software/Virtual-TreeView` and System Informer.
    Reconstructs a parent-child hierarchy from any flat list of items in O(N)
    using hash maps, protects against cyclic parent chains (`MaxDepth = 32`),
    identifies root/orphan nodes automatically, and formats indented tree
    captions (`└─ `) ready for virtual OwnerData rendering.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Generics.Collections,
  Velox.Types;

type
  /// <summary>
  /// Callback that extracts the unique NodeID and ParentNodeID from an item
  /// </summary>
  TVeloxTreeIdExtractor<T> = procedure(const AItem: T; out ANodeId, AParentId: Cardinal) of object;

  /// <summary>
  /// Callback that assigns the computed indentation depth (0..MaxDepth) to an item
  /// </summary>
  TVeloxTreeDepthSetter<T> = procedure(var AItem: T; const ADepth: Integer) of object;

  /// <summary>
  /// Generic O(N) flat-to-hierarchical tree builder with cycle protection
  /// </summary>
  TVeloxTreeBuilder<T> = class
  public
    /// <summary>
    /// Flattens ASource into ATarget in depth-first hierarchical order,
    /// invoking ADepthSetter on each item with its tree nesting level (0..AMaxDepth).
    /// </summary>
    class procedure BuildHierarchy(const ASource, ATarget: TList<T>;
      const AExtractor: TVeloxTreeIdExtractor<T>;
      const ADepthSetter: TVeloxTreeDepthSetter<T> = nil;
      const AMaxDepth: Integer = 32); static;

    /// <summary>
    /// Formats a node display label with hierarchical indentation and
    /// cross-compiler `└─ ` branch connector when ADepth > 0.
    /// </summary>
    class function FormatIndentedCaption(const ACaption: string;
      const ADepth: Integer; const AIndentSpacesPerLevel: Integer = 3): string; static;
  end;

implementation

{ TVeloxTreeBuilder<T> }

class procedure TVeloxTreeBuilder<T>.BuildHierarchy(const ASource, ATarget: TList<T>;
  const AExtractor: TVeloxTreeIdExtractor<T>;
  const ADepthSetter: TVeloxTreeDepthSetter<T>;
  const AMaxDepth: Integer);
var
  IdSet: TDictionary<Cardinal, Boolean>;
  ChildrenMap: TDictionary<Cardinal, TList<Integer>>;
  Roots: TList<Integer>;
  Visited: TDictionary<Integer, Boolean>;
  I: Integer;
  NodeId, ParentId: Cardinal;
  ChildIndices: TList<Integer>;

  procedure TraverseNode(const AIndex, ALevel: Integer);
  var
    K, ChildIdx: Integer;
    ItemCopy: T;
    NId, PId: Cardinal;
    SubChildren: TList<Integer>;
  begin
    if Visited.ContainsKey(AIndex) then Exit;
    Visited.Add(AIndex, True);

    ItemCopy := ASource[AIndex];
    if Assigned(ADepthSetter) then
      ADepthSetter(ItemCopy, ALevel);
    ATarget.Add(ItemCopy);

    if ALevel >= AMaxDepth then Exit;
    AExtractor(ItemCopy, NId, PId);
    if ChildrenMap.TryGetValue(NId, SubChildren) then
    begin
      for K := 0 to SubChildren.Count - 1 do
      begin
        ChildIdx := SubChildren[K];
        TraverseNode(ChildIdx, ALevel + 1);
      end;
    end;
  end;

begin
  if (ASource = nil) or (ATarget = nil) or not Assigned(AExtractor) then Exit;
  ATarget.Clear;
  if ASource.Count = 0 then Exit;

  IdSet := TDictionary<Cardinal, Boolean>.Create;
  ChildrenMap := TDictionary<Cardinal, TList<Integer>>.Create;
  Roots := TList<Integer>.Create;
  Visited := TDictionary<Integer, Boolean>.Create;
  try
    for I := 0 to ASource.Count - 1 do
    begin
      AExtractor(ASource[I], NodeId, ParentId);
      IdSet.AddOrSetValue(NodeId, True);
      if not ChildrenMap.TryGetValue(ParentId, ChildIndices) then
      begin
        ChildIndices := TList<Integer>.Create;
        ChildrenMap.Add(ParentId, ChildIndices);
      end;
      ChildIndices.Add(I);
    end;

    for I := 0 to ASource.Count - 1 do
    begin
      AExtractor(ASource[I], NodeId, ParentId);
      if (ParentId = 0) or (ParentId = NodeId) or (not IdSet.ContainsKey(ParentId)) then
        Roots.Add(I);
    end;

    for I := 0 to Roots.Count - 1 do
      TraverseNode(Roots[I], 0);

    // Append any remaining cyclic orphan nodes safely at level 0
    for I := 0 to ASource.Count - 1 do
      if not Visited.ContainsKey(I) then
        TraverseNode(I, 0);
  finally
    for ChildIndices in ChildrenMap.Values do
      ChildIndices.Free;
    Visited.Free;
    Roots.Free;
    ChildrenMap.Free;
    IdSet.Free;
  end;
end;

class function TVeloxTreeBuilder<T>.FormatIndentedCaption(const ACaption: string;
  const ADepth: Integer; const AIndentSpacesPerLevel: Integer): string;
begin
  if ADepth <= 0 then
    Result := ACaption
  else
    Result := StringOfChar(' ', ADepth * AIndentSpacesPerLevel) + VELOX_TREE_BRANCH + ACaption;
end;

end.
