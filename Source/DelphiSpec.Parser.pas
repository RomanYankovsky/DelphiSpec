unit DelphiSpec.Parser;

interface

uses
  SysUtils, Classes, Generics.Collections, XmlIntf, DelphiSpec.DataTable,
  DelphiSpec.Scenario, DelphiSpec.StepDefinitions;

type
  TStepKind = (skFeature, skBackground, skScenario, skScenarioOutline,
    skGiven, skAnd, skWhen, skThen, skExamples);

  TDelphiSpecLanguages = class
  private
    class var FLangXML: IXMLDocument;
    class function GetStepKindAsString(StepKind: TStepKind): string; static;
  public
    class constructor Create;

    class function CheckStepKind(StepKind: TStepKind; const S: string; const LangCode: string): Boolean;
    class function GetStepText(StepKind: TStepKind; const S: string; const LangCode: string): string;
  end;

  TDelphiSpecFileReader = class
  private
    FLinePos: Integer;
    FLines: TStringList;
    function GetEof: Boolean;
    function GetLineNo: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromFile(const FileName: string);
    function PeekLine: string;
    function ReadLine: string;

    property Eof: Boolean read GetEof;
    property LineNo: Integer read GetLineNo;
  end;

  EDelphiSpecSyntaxError = class(Exception)
  private
    FLineNo: Integer;
  public
    constructor CreateAtLine(LineNo: Integer); overload;
    property LineNo: Integer read FLineNo;
  end;

  EDelphiSpecUnexpectedEof = class(Exception);

  TDelphiSpecParser = class
  private
    FLangCode: string;
    FReader: TDelphiSpecFileReader;

    procedure CheckEof;
    procedure PassEmptyLines;
    procedure RaiseSyntaxError;

    function TryReadDataTable: IDataTable;
    function TryReadPyString: string;

    procedure FeatureNode(Feature: TFeature);
    procedure BackgroundNode(Feature: TFeature);
    procedure ScenarioNode(Scenario: TScenario);
    procedure ScenarioOutlineNode(ScenarioOutline: TScenarioOutline);
    procedure GivenNode(Scenario: TScenario);
    procedure WhenNode(Scenario: TScenario);
    procedure ThenNode(Scenario: TScenario);
    procedure ExampleNode(ScenarioOutline: TScenarioOutline);
  public
    constructor Create(const LangCode: string);
    destructor Destroy; override;

    procedure Execute(const FileName: string; Features: TObjectList<TFeature>);
  end;

implementation

{$R DelphiSpecI18n.res}

uses
  StrUtils, Types, XmlDoc,
{$IFDEF MSWINDOWS}
  Windows, ActiveX,
{$ENDIF}

  DelphiSpec.Core;

{ TDelphiSpecFileReader }

constructor TDelphiSpecFileReader.Create;
begin
  inherited;
  FLinePos := 0;
  FLines := TStringList.Create;
end;

destructor TDelphiSpecFileReader.Destroy;
begin
  FLines.Free;
  inherited;
end;

function TDelphiSpecFileReader.GetEof: Boolean;
begin
  Result := (FLinePos = FLines.Count);
end;

function TDelphiSpecFileReader.GetLineNo: Integer;
begin
  Result := FLinePos;
end;

procedure TDelphiSpecFileReader.LoadFromFile(const FileName: string);
begin
  FLines.LoadFromFile(FileName);
  FLinePos := 0;
end;

function TDelphiSpecFileReader.PeekLine: string;
begin
  Result := FLines[FLinePos];
end;

function TDelphiSpecFileReader.ReadLine: string;
begin
  Result := FLines[FLinePos];
  Inc(FLinePos);
end;

{ TDelphiSpecParser }

procedure TDelphiSpecParser.BackgroundNode(Feature: TFeature);
begin
  if Assigned(Feature.Background) then
    RaiseSyntaxError;

  PassEmptyLines;
  CheckEof;

  Feature.Background := TScenario.Create(nil, '');

  GivenNode(Feature.Background);
end;

procedure TDelphiSpecParser.CheckEof;
begin
  if FReader.Eof then
    raise EDelphiSpecUnexpectedEof.Create('Unexpected end of file');
end;

constructor TDelphiSpecParser.Create(const LangCode: string);
begin
  inherited Create;
  FLangCode := LangCode;
  FReader := TDelphiSpecFileReader.Create;
end;

destructor TDelphiSpecParser.Destroy;
begin
  FReader.Free;
  inherited;
end;

procedure TDelphiSpecParser.ExampleNode(ScenarioOutline: TScenarioOutline);
var
  Command: string;
begin
  PassEmptyLines;
  CheckEof;

  Command := Trim(FReader.ReadLine);
  if not TDelphiSpecLanguages.CheckStepKind(skExamples, Command, FLangCode) then
    RaiseSyntaxError;

  ScenarioOutline.SetExamples(TryReadDataTable);
end;

procedure TDelphiSpecParser.Execute(const FileName: string;
  Features: TObjectList<TFeature>);
var
  Command, FeatureName: string;
  Feature: TFeature;
begin
  FReader.LoadFromFile(FileName);

  while not FReader.Eof do
  begin
    PassEmptyLines;
    CheckEof;

    Command := Trim(FReader.ReadLine);
    if not TDelphiSpecLanguages.CheckStepKind(skFeature, Command, FLangCode) then
      RaiseSyntaxError;

    FeatureName := TDelphiSpecLanguages.GetStepText(skFeature, Command, FLangCode);
    Feature := TFeature.Create(FeatureName, GetStepDefinitionsClass(FeatureName));
    Features.Add(Feature);

    FeatureNode(Feature);
  end;
end;

function TDelphiSpecParser.TryReadDataTable: IDataTable;
const
  TableDelimeter = '|';

  function StrToArray(const S: string): TStringDynArray;
  var
    I: Integer;
    TrimS: string;
  begin
    TrimS := Trim(S);
    Result := SplitString(Copy(TrimS, 2, Length(TrimS) - 2), TableDelimeter);

    for I := Low(Result) to High(Result) do
      Result[I] := Trim(Result[I]);
  end;

  function TableInNextLine: Boolean;
  begin
    Result := (not FReader.Eof) and StartsText(TableDelimeter, Trim(FReader.PeekLine));
  end;

  function ReadDataTable: IDataTable;
  var
    DataTable: TDataTable;
    ColumnNames: TStringDynArray;
  begin
    ColumnNames := StrToArray(FReader.ReadLine);

    DataTable := TDataTable.Create(Length(ColumnNames));
    DataTable.AddRow(ColumnNames);

    while TableInNextLine do
      DataTable.AddRow(StrToArray(FReader.ReadLine));

    Result := DataTable;
  end;

begin
  PassEmptyLines;

  if TableInNextLine then
    Result := ReadDataTable
  else
    Result := nil;
end;

function TDelphiSpecParser.TryReadPyString: string;
const
  PyStrMarker = '"""';
var
  Lines: TStringList;
  Line, IndentationText: string;
  TextStartPos: Integer;
begin
  Result := '';

  PassEmptyLines;
  if FReader.Eof or (Trim(FReader.PeekLine) <> PyStrMarker) then
    Exit;

  Lines := TStringList.Create;
  try
    Line := FReader.ReadLine;

    TextStartPos := Pos(PyStrMarker, Line);
    IndentationText := Copy(Line, 1, TextStartPos - 1);

    repeat
      CheckEof;

      Line := FReader.ReadLine;
      if not StartsText(IndentationText, Line) then
        RaiseSyntaxError;

      Lines.Add(Copy(Line, TextStartPos, Length(Line) - TextStartPos + 1));
    until Trim(FReader.PeekLine) = PyStrMarker;

    if not StartsText(IndentationText, FReader.ReadLine) then
      RaiseSyntaxError;

    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure TDelphiSpecParser.FeatureNode(Feature: TFeature);
var
  Command: string;
  CommentsAllowed: Boolean;
  Scenario: TScenario;
  ScenarioOutline: TScenarioOutline;
begin
  CommentsAllowed := True;
  while not FReader.Eof do
  begin
    PassEmptyLines;
    CheckEof;

    Command := Trim(FReader.ReadLine);
    if TDelphiSpecLanguages.CheckStepKind(skBackground, Command, FLangCode) then
    begin
      BackgroundNode(Feature);
      CommentsAllowed := False;
    end
    else if TDelphiSpecLanguages.CheckStepKind(skScenarioOutline, Command, FLangCode) then
    begin
      ScenarioOutline := TScenarioOutline.Create(Feature, TDelphiSpecLanguages.GetStepText(skScenarioOutline, Command, FLangCode));
      Feature.ScenarioOutlines.Add(ScenarioOutline);
      ScenarioOutlineNode(ScenarioOutline);
      CommentsAllowed := False;
    end
    else if TDelphiSpecLanguages.CheckStepKind(skScenario, Command, FLangCode) then
    begin
      Scenario := TScenario.Create(Feature, TDelphiSpecLanguages.GetStepText(skScenario, Command, FLangCode));
      Feature.Scenarios.Add(Scenario);
      ScenarioNode(Scenario);
      CommentsAllowed := False;
    end
    else if not CommentsAllowed then
      RaiseSyntaxError;
  end;
end;

procedure TDelphiSpecParser.GivenNode(Scenario: TScenario);
var
  Command: string;
begin
  Command := Trim(FReader.ReadLine);

  if TDelphiSpecLanguages.CheckStepKind(skGiven, Command, FLangCode) then
    Scenario.AddGiven(TDelphiSpecLanguages.GetStepText(skGiven, Command, FLangCode), TryReadDataTable, TryReadPyString)
  else if TDelphiSpecLanguages.CheckStepKind(skAnd, Command, FLangCode) then
    Scenario.AddGiven(TDelphiSpecLanguages.GetStepText(skAnd, Command, FLangCode), TryReadDataTable, TryReadPyString)
  else
    RaiseSyntaxError;

  PassEmptyLines;
  CheckEof;

  Command := Trim(FReader.PeekLine);

  if TDelphiSpecLanguages.CheckStepKind(skAnd, Command, FLangCode) then
    GivenNode(Scenario);
end;

procedure TDelphiSpecParser.PassEmptyLines;
begin
  while not FReader.Eof do
    if Trim(FReader.PeekLine) = '' then
      FReader.ReadLine
    else
      Break;
end;

procedure TDelphiSpecParser.RaiseSyntaxError;
begin
  raise EDelphiSpecSyntaxError.CreateAtLine(FReader.LineNo);
end;

procedure TDelphiSpecParser.ScenarioNode(Scenario: TScenario);
begin
  PassEmptyLines;
  CheckEof;

  GivenNode(Scenario);
  WhenNode(Scenario);
  ThenNode(Scenario);
end;

procedure TDelphiSpecParser.ScenarioOutlineNode(
  ScenarioOutline: TScenarioOutline);
begin
  PassEmptyLines;
  CheckEof;

  GivenNode(ScenarioOutline);
  WhenNode(ScenarioOutline);
  ThenNode(ScenarioOutline);
  ExampleNode(ScenarioOutline);
end;

procedure TDelphiSpecParser.ThenNode(Scenario: TScenario);
var
  Command: string;
begin
  Command := Trim(FReader.ReadLine);

  if TDelphiSpecLanguages.CheckStepKind(skThen, Command, FLangCode) then
    Scenario.AddThen(TDelphiSpecLanguages.GetStepText(skThen, Command, FLangCode), TryReadDataTable, TryReadPyString)
  else if TDelphiSpecLanguages.CheckStepKind(skAnd, Command, FLangCode) then
    Scenario.AddThen(TDelphiSpecLanguages.GetStepText(skAnd, Command, FLangCode), TryReadDataTable, TryReadPyString)
  else
    RaiseSyntaxError;

  PassEmptyLines;
  if FReader.Eof then
    Exit;

  Command := Trim(FReader.PeekLine);

  if TDelphiSpecLanguages.CheckStepKind(skAnd, Command, FLangCode) then
    ThenNode(Scenario);
end;

procedure TDelphiSpecParser.WhenNode(Scenario: TScenario);
var
  Command: string;
begin
  Command := Trim(FReader.ReadLine);

  if TDelphiSpecLanguages.CheckStepKind(skWhen, Command, FLangCode) then
    Scenario.AddWhen(TDelphiSpecLanguages.GetStepText(skWhen, Command, FLangCode), TryReadDataTable, TryReadPyString)
  else if TDelphiSpecLanguages.CheckStepKind(skAnd, Command, FLangCode) then
    Scenario.AddWhen(TDelphiSpecLanguages.GetStepText(skAnd, Command, FLangCode), TryReadDataTable, TryReadPyString)
  else
    RaiseSyntaxError;

  PassEmptyLines;
  CheckEof;
  Command := Trim(FReader.PeekLine);

  if TDelphiSpecLanguages.CheckStepKind(skAnd, Command, FLangCode) then
    WhenNode(Scenario);
end;

{ TDelphiSpecLanguages }

class constructor TDelphiSpecLanguages.Create;
var
  Stream: TResourceStream;
begin
{$IFDEF MSWINDOWS}
  ActiveX.CoInitialize(nil);
{$ENDIF}


  Stream := TResourceStream.Create(hInstance, 'DelphiSpecLanguages', RT_RCDATA);
  try
    FLangXML := NewXmlDocument;
    FLangXML.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

class function TDelphiSpecLanguages.GetStepKindAsString(StepKind: TStepKind): string;
const
  StepNames: array [TStepKind] of string = (
    'Feature', 'Background', 'Scenario', 'ScenarioOutline',
    'Given', 'And', 'When', 'Then', 'Examples');
begin
  Result := StepNames[StepKind];
end;

class function TDelphiSpecLanguages.CheckStepKind(StepKind: TStepKind; const S: string; const LangCode: string): Boolean;
var
  I: Integer;
  LangNode: IXMLNode;
  StepKindName: string;
begin
  Result := False;
  LangNode := FLangXML.DocumentElement.ChildNodes.FindNode(LangCode);
  StepKindName := GetStepKindAsString(StepKind);

  for I := 0 to LangNode.ChildNodes.Count - 1 do
    if (LangNode.ChildNodes[I].NodeName = StepKindName) and StartsText(LangNode.ChildNodes[I].NodeValue, S) then
    begin
      Result := True;
      Break;
    end;
end;

class function TDelphiSpecLanguages.GetStepText(StepKind: TStepKind; const S: string; const LangCode: string): string;
var
  I: Integer;
  StepKindName: string;
  LangNode: IXMLNode;
begin
  Result := '';
  LangNode := FLangXML.DocumentElement.ChildNodes.FindNode(LangCode);
  StepKindName := GetStepKindAsString(StepKind);

  for I := 0 to LangNode.ChildNodes.Count - 1 do
    if (LangNode.ChildNodes[I].NodeName = StepKindName) and StartsText(LangNode.ChildNodes[I].NodeValue, S) then
    begin
      Result := Trim(Copy(S, Length(LangNode.ChildNodes[I].NodeValue) + 1));
      Break;
    end;
end;

{ EDelphiSpecSyntaxError }

constructor EDelphiSpecSyntaxError.CreateAtLine(LineNo: Integer);
begin
  inherited Create('Syntax error');
  FLineNo := LineNo;
end;


end.
