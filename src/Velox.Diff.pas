unit Velox.Diff;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  SysUtils, Classes, Math;

type
  TVeloxDiffOp = (vdoEqual, vdoInsert, vdoDelete, vdoModify);

  TVeloxDiffLine = record
    Op: TVeloxDiffOp;
    OldIndex: Integer; // 1-based index in old text, or 0 if inserted
    NewIndex: Integer; // 1-based index in new text, or 0 if deleted
    Text: string;
  end;

  TVeloxDiffResult = record
    Lines: array of TVeloxDiffLine;
    AddedCount: Integer;
    DeletedCount: Integer;
    EqualCount: Integer;
    ModifiedCount: Integer;
  end;

  TVeloxDiff = class
  private
    class function Min3(const A, B, C: Integer): Integer; static; inline;
  public
    /// <summary>Compares two TStrings line by line using an LCS (Longest Common Subsequence) diff algorithm.</summary>
    class function CompareLines(const OldLines, NewLines: TStrings): TVeloxDiffResult; static;
    /// <summary>Compares two multi-line text strings.</summary>
    class function CompareText(const OldText, NewText: string): TVeloxDiffResult; static;
    /// <summary>Formats the diff result as standard unified diff (e.g. --- a\n+++ b\n@@ ... @@).</summary>
    class function FormatUnified(const AResult: TVeloxDiffResult; const OldName: string = 'a'; const NewName: string = 'b'): string; static;
    /// <summary>Computes the Levenshtein edit distance between two strings.</summary>
    class function LevenshteinDistance(const S1, S2: string): Integer; static;
    /// <summary>Returns similarity ratio between 0.0 (completely distinct) and 1.0 (identical).</summary>
    class function Similarity(const S1, S2: string): Double; static;
  end;

implementation

{ TVeloxDiff }

class function TVeloxDiff.Min3(const A, B, C: Integer): Integer;
begin
  Result := A;
  if B < Result then Result := B;
  if C < Result then Result := C;
end;

class function TVeloxDiff.LevenshteinDistance(const S1, S2: string): Integer;
var
  Len1, Len2, I, J, Cost: Integer;
  D: array of array of Integer;
begin
  Len1 := Length(S1);
  Len2 := Length(S2);

  if Len1 = 0 then Exit(Len2);
  if Len2 = 0 then Exit(Len1);

  SetLength(D, Len1 + 1, Len2 + 1);

  for I := 0 to Len1 do
    D[I, 0] := I;
  for J := 0 to Len2 do
    D[0, J] := J;

  for I := 1 to Len1 do
  begin
    for J := 1 to Len2 do
    begin
      if S1[I] = S2[J] then
        Cost := 0
      else
        Cost := 1;

      D[I, J] := Min3(D[I - 1, J] + 1,       // deletion
                      D[I, J - 1] + 1,       // insertion
                      D[I - 1, J - 1] + Cost // substitution
                     );
    end;
  end;

  Result := D[Len1, Len2];
end;

class function TVeloxDiff.Similarity(const S1, S2: string): Double;
var
  MaxLen, Dist: Integer;
begin
  if S1 = S2 then Exit(1.0);
  MaxLen := Max(Length(S1), Length(S2));
  if MaxLen = 0 then Exit(1.0);
  Dist := LevenshteinDistance(S1, S2);
  Result := 1.0 - (Dist / MaxLen);
end;

class function TVeloxDiff.CompareLines(const OldLines, NewLines: TStrings): TVeloxDiffResult;
var
  M, N, I, J: Integer;
  LCS: array of array of Integer;
  DiffList: array of TVeloxDiffLine;
  DiffCount: Integer;

  procedure AddLine(AOp: TVeloxDiffOp; AOldIdx, ANewIdx: Integer; const AText: string);
  begin
    Inc(DiffCount);
    SetLength(DiffList, DiffCount);
    DiffList[DiffCount - 1].Op := AOp;
    DiffList[DiffCount - 1].OldIndex := AOldIdx;
    DiffList[DiffCount - 1].NewIndex := ANewIdx;
    DiffList[DiffCount - 1].Text := AText;

    case AOp of
      vdoInsert: Inc(Result.AddedCount);
      vdoDelete: Inc(Result.DeletedCount);
      vdoEqual:  Inc(Result.EqualCount);
      vdoModify: Inc(Result.ModifiedCount);
    end;
  end;

  procedure Backtrack(I, J: Integer);
  begin
    if (I > 0) and (J > 0) and (OldLines[I - 1] = NewLines[J - 1]) then
    begin
      Backtrack(I - 1, J - 1);
      AddLine(vdoEqual, I, J, OldLines[I - 1]);
    end
    else if (J > 0) and ((I = 0) or (LCS[I, J - 1] >= LCS[I - 1, J])) then
    begin
      Backtrack(I, J - 1);
      AddLine(vdoInsert, 0, J, NewLines[J - 1]);
    end
    else if (I > 0) and ((J = 0) or (LCS[I, J - 1] < LCS[I - 1, J])) then
    begin
      Backtrack(I - 1, J);
      AddLine(vdoDelete, I, 0, OldLines[I - 1]);
    end;
  end;

begin
  FillChar(Result, SizeOf(Result), 0);
  M := OldLines.Count;
  N := NewLines.Count;

  SetLength(LCS, M + 1, N + 1);

  for I := 0 to M do
    LCS[I, 0] := 0;
  for J := 0 to N do
    LCS[0, J] := 0;

  for I := 1 to M do
  begin
    for J := 1 to N do
    begin
      if OldLines[I - 1] = NewLines[J - 1] then
        LCS[I, J] := LCS[I - 1, J - 1] + 1
      else
        LCS[I, J] := Max(LCS[I - 1, J], LCS[I, J - 1]);
    end;
  end;

  DiffCount := 0;
  SetLength(DiffList, 0);
  Backtrack(M, N);

  Result.Lines := DiffList;
end;

class function TVeloxDiff.CompareText(const OldText, NewText: string): TVeloxDiffResult;
var
  L1, L2: TStringList;
begin
  L1 := TStringList.Create;
  L2 := TStringList.Create;
  try
    L1.Text := OldText;
    L2.Text := NewText;
    Result := CompareLines(L1, L2);
  finally
    L1.Free;
    L2.Free;
  end;
end;

class function TVeloxDiff.FormatUnified(const AResult: TVeloxDiffResult; const OldName, NewName: string): string;
var
  SB: TStringBuilder;
  I: Integer;
  Prefix: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('--- ').AppendLine(OldName);
    SB.Append('+++ ').AppendLine(NewName);
    SB.AppendFormat('@@ -1,%d +1,%d @@', [AResult.DeletedCount + AResult.EqualCount,
                                          AResult.AddedCount + AResult.EqualCount]).AppendLine;

    for I := 0 to High(AResult.Lines) do
    begin
      case AResult.Lines[I].Op of
        vdoInsert: Prefix := '+';
        vdoDelete: Prefix := '-';
      else
        Prefix := ' ';
      end;
      SB.Append(Prefix).AppendLine(AResult.Lines[I].Text);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.
