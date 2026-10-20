unit Velox.Export;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

{==============================================================================
  VeloxUI — High-Velocity Native Desktop MVVM & Fluent UI Micro-Framework
  Unit: Velox.Export
  Purpose:
    Zero-boilerplate tabular & telemetry data exporter (`TVeloxExporter`) for
    RFC-4180 CSV, structured JSON, GitHub Flavored Markdown tables, and
    Clipboard row/table copying. Works with both standard and virtual
    (OwnerData) grids via a clean cell-provider callback.
==============================================================================}

interface

uses
  SysUtils,
  Classes,
  Clipbrd;

type
  /// <summary>
  /// Callback returning the string value for (ARow, ACol) in a virtual dataset
  /// </summary>
  TVeloxCellProvider = function(const ARow, ACol: Integer): string of object;

  /// <summary>
  /// Universal CSV, JSON, Markdown, and Clipboard exporter
  /// </summary>
  TVeloxExporter = class
  public
    /// <summary>
    /// Escapes a string according to RFC-4180 CSV rules (quotes fields
    /// containing commas, double quotes, or line breaks).
    /// </summary>
    class function EscapeCsvField(const AValue: string): string; static;

    /// <summary>
    /// Escapes a string for safe inclusion inside a JSON string literal.
    /// </summary>
    class function EscapeJsonString(const AValue: string): string; static;

    /// <summary>
    /// Formats a single record of fields as an RFC-4180 CSV line.
    /// </summary>
    class function FormatCsvRow(const AFields: array of string): string; static;

    /// <summary>
    /// Exports tabular data via a cell-provider callback to an RFC-4180 CSV string
    /// or file.
    /// </summary>
    class function BuildCsvTable(const AHeaders: array of string;
      const ARowCount: Integer; const ACellProvider: TVeloxCellProvider): string; static;
    class function SaveCsvTable(const AFilePath: string;
      const AHeaders: array of string; const ARowCount: Integer;
      const ACellProvider: TVeloxCellProvider): Boolean; static;

    /// <summary>
    /// Exports tabular data via a cell-provider callback to a structured JSON
    /// array of objects (using AHeaders as property keys).
    /// </summary>
    class function BuildJsonTable(const AGeneratorName: string;
      const AHeaders: array of string; const ARowCount: Integer;
      const ACellProvider: TVeloxCellProvider): string; static;
    class function SaveJsonTable(const AFilePath, AGeneratorName: string;
      const AHeaders: array of string; const ARowCount: Integer;
      const ACellProvider: TVeloxCellProvider): Boolean; static;

    /// <summary>
    /// Exports tabular data to a GitHub Flavored Markdown (GFM) table string.
    /// </summary>
    class function BuildMarkdownTable(const AHeaders: array of string;
      const ARowCount: Integer; const ACellProvider: TVeloxCellProvider): string; static;

    /// <summary>
    /// Copies a single formatted CSV row or entire table directly to the OS Clipboard.
    /// </summary>
    class procedure CopyRowToClipboard(const AFields: array of string); static;
  end;

implementation

{ TVeloxExporter }

class function TVeloxExporter.EscapeCsvField(const AValue: string): string;
var
  NeedsQuotes: Boolean;
begin
  NeedsQuotes := (Pos(',', AValue) > 0) or
                 (Pos('"', AValue) > 0) or
                 (Pos(#13, AValue) > 0) or
                 (Pos(#10, AValue) > 0);
  if NeedsQuotes then
    Result := '"' + StringReplace(AValue, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := AValue;
end;

class function TVeloxExporter.EscapeJsonString(const AValue: string): string;
var
  I: Integer;
  Ch: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    Ch := AValue[I];
    case Ch of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #8:   Result := Result + '\b';
      #9:   Result := Result + '\t';
      #10:  Result := Result + '\n';
      #12:  Result := Result + '\f';
      #13:  Result := Result + '\r';
    else
      if Ord(Ch) < 32 then
        Result := Result + Format('\u%.4x', [Ord(Ch)])
      else
        Result := Result + Ch;
    end;
  end;
end;

class function TVeloxExporter.FormatCsvRow(const AFields: array of string): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(AFields) to High(AFields) do
  begin
    if I > Low(AFields) then
      Result := Result + ',';
    Result := Result + EscapeCsvField(AFields[I]);
  end;
end;

class function TVeloxExporter.BuildCsvTable(const AHeaders: array of string;
  const ARowCount: Integer; const ACellProvider: TVeloxCellProvider): string;
var
  Lines: TStringList;
  R, C, ColCount: Integer;
  RowStr, Val: string;
begin
  Result := '';
  ColCount := Length(AHeaders);
  if ColCount = 0 then Exit;

  Lines := TStringList.Create;
  try
    Lines.Add(FormatCsvRow(AHeaders));
    if Assigned(ACellProvider) then
    begin
      for R := 0 to ARowCount - 1 do
      begin
        RowStr := '';
        for C := 0 to ColCount - 1 do
        begin
          if C > 0 then RowStr := RowStr + ',';
          Val := ACellProvider(R, C);
          RowStr := RowStr + EscapeCsvField(Val);
        end;
        Lines.Add(RowStr);
      end;
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

class function TVeloxExporter.SaveCsvTable(const AFilePath: string;
  const AHeaders: array of string; const ARowCount: Integer;
  const ACellProvider: TVeloxCellProvider): Boolean;
var
  Lines: TStringList;
begin
  Result := False;
  if AFilePath = '' then Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := BuildCsvTable(AHeaders, ARowCount, ACellProvider);
    Lines.SaveToFile(AFilePath);
    Result := FileExists(AFilePath);
  finally
    Lines.Free;
  end;
end;

class function TVeloxExporter.BuildJsonTable(const AGeneratorName: string;
  const AHeaders: array of string; const ARowCount: Integer;
  const ACellProvider: TVeloxCellProvider): string;
var
  Lines: TStringList;
  R, C, ColCount: Integer;
  CommaRow, CommaCol, KeyName, ValStr: string;
begin
  Result := '';
  ColCount := Length(AHeaders);
  Lines := TStringList.Create;
  try
    Lines.Add('{');
    Lines.Add(Format('  "generator": "%s",', [EscapeJsonString(AGeneratorName)]));
    Lines.Add(Format('  "timestamp": "%s",', [FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now)]));
    Lines.Add(Format('  "count": %d,', [ARowCount]));
    Lines.Add('  "items": [');
    if Assigned(ACellProvider) and (ColCount > 0) then
    begin
      for R := 0 to ARowCount - 1 do
      begin
        if R < ARowCount - 1 then CommaRow := ',' else CommaRow := '';
        Lines.Add('    {');
        for C := 0 to ColCount - 1 do
        begin
          if C < ColCount - 1 then CommaCol := ',' else CommaCol := '';
          KeyName := EscapeJsonString(AHeaders[C]);
          ValStr  := EscapeJsonString(ACellProvider(R, C));
          Lines.Add(Format('      "%s": "%s"%s', [KeyName, ValStr, CommaCol]));
        end;
        Lines.Add('    }' + CommaRow);
      end;
    end;
    Lines.Add('  ]');
    Lines.Add('}');
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

class function TVeloxExporter.SaveJsonTable(const AFilePath, AGeneratorName: string;
  const AHeaders: array of string; const ARowCount: Integer;
  const ACellProvider: TVeloxCellProvider): Boolean;
var
  Lines: TStringList;
begin
  Result := False;
  if AFilePath = '' then Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := BuildJsonTable(AGeneratorName, AHeaders, ARowCount, ACellProvider);
    Lines.SaveToFile(AFilePath);
    Result := FileExists(AFilePath);
  finally
    Lines.Free;
  end;
end;

class function TVeloxExporter.BuildMarkdownTable(const AHeaders: array of string;
  const ARowCount: Integer; const ACellProvider: TVeloxCellProvider): string;
var
  Lines: TStringList;
  R, C, ColCount: Integer;
  HeaderLine, SepLine, RowLine, CellVal: string;
begin
  Result := '';
  ColCount := Length(AHeaders);
  if ColCount = 0 then Exit;

  Lines := TStringList.Create;
  try
    HeaderLine := '|';
    SepLine := '|';
    for C := 0 to ColCount - 1 do
    begin
      HeaderLine := HeaderLine + ' ' + AHeaders[C] + ' |';
      SepLine := SepLine + ' :--- |';
    end;
    Lines.Add(HeaderLine);
    Lines.Add(SepLine);

    if Assigned(ACellProvider) then
    begin
      for R := 0 to ARowCount - 1 do
      begin
        RowLine := '|';
        for C := 0 to ColCount - 1 do
        begin
          CellVal := StringReplace(ACellProvider(R, C), '|', '\|', [rfReplaceAll]);
          RowLine := RowLine + ' ' + CellVal + ' |';
        end;
        Lines.Add(RowLine);
      end;
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

class procedure TVeloxExporter.CopyRowToClipboard(const AFields: array of string);
begin
  Clipboard.AsText := FormatCsvRow(AFields);
end;

end.
