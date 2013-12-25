unit DelphiSpec.Parser;

interface

uses
  SysUtils, Classes, Generics.Collections, XmlIntf, DelphiSpec.DataTable,
  DelphiSpec.Scenario, DelphiSpec.StepDefinitions;

type
  TDelphiSpecLanguages = class
  private
    FLangNode: IXMLNode;
    FXML: IXMLDocument;
  public
    constructor Create(const LangCode: string); reintroduce;

    function StartsWith(const S: string; const StepKind: string): Boolean;
    function StepSubstring(const S: string; const StepKind: string): string;
  end;

  TDelphiSpecFileReader = class
  private
    FLinePos: Integer;
    FLines: TStringList;
    function GetEof: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromFile(const FileName: string);
    function PeekLine: string;
    function ReadLine: string;

    property Eof: Boolean read GetEof;
  end;

  EDelphiSpecSyntaxError = class(Exception);

  TDelphiSpecParser = class
  private
    FReader: TDelphiSpecFileReader;
    FLanguages: TDelphiSpecLanguages;

    procedure CheckEof;
    procedure PassEmptyLines;
    function TryReadDataTable: IDelphiSpecDataTable;

    procedure FeatureNode(Scenarios: TObjectList<TScenario>; StepDefsClass: TStepDefinitionsClass);
    procedure ScenarioNode(Scenario: TScenario);
    procedure GivenNode(Scenario: TScenario);
    procedure WhenNode(Scenario: TScenario);
    procedure ThenNode(Scenario: TScenario);
  public
    constructor Create(const LangCode: string);
    destructor Destroy; override;

    procedure Execute(const FileName: string; Features: TDictionary<string, TObjectList<TScenario>>);
  end;

implementation

{$R DelphiSpecI18n.res}

uses
  StrUtils, Types, XmlDoc, DelphiSpec.Core;

const
  sFeature = 'Feature';
  sScenario = 'Scenario';
  sGiven = 'Given';
  sAnd = 'And';
  sWhen = 'When';
  sThen = 'Then';

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

procedure TDelphiSpecParser.CheckEof;
begin
  if FReader.Eof then
    raise EDelphiSpecSyntaxError.Create('Unexpected end of file');
end;

constructor TDelphiSpecParser.Create(const LangCode: string);
begin
  inherited Create;
  FLanguages := TDelphiSpecLanguages.Create(LangCode);
  FReader := TDelphiSpecFileReader.Create;
end;

destructor TDelphiSpecParser.Destroy;
begin
  FLanguages.Free;
  FReader.Free;
  inherited;
end;

procedure TDelphiSpecParser.Execute(const FileName: string;
  Features: TDictionary<string, TObjectList<TScenario>>);
var
  Command, FeatureName: string;
  Scenarios: TObjectList<TScenario>;
begin
  FReader.LoadFromFile(FileName);

  PassEmptyLines;

  while not FReader.Eof do
  begin
    Command := Trim(FReader.ReadLine);
    if not FLanguages.StartsWith(Command, sFeature) then
      Break;

    FeatureName := FLanguages.StepSubstring(Command, sFeature);
    Scenarios := TObjectList<TScenario>.Create(False);
    Features.Add(FeatureName, Scenarios);

    FeatureNode(Scenarios, GetStepDefinitionsClass(FeatureName));
  end;

  if not FReader.Eof then
    raise EDelphiSpecSyntaxError.Create('Syntax Error');
end;

function TDelphiSpecParser.TryReadDataTable: IDelphiSpecDataTable;
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

  function ReadDataTable: IDelphiSpecDataTable;
  var
    DataTable: TDelphiSpecDataTable;
  begin
    DataTable := TDelphiSpecDataTable.Create(StrToArray(FReader.ReadLine));

    while TableInNextLine do
      DataTable.AddRow(StrToArray(FReader.ReadLine));

    Result := DataTable;
  end;

begin
  if TableInNextLine then
    Result := ReadDataTable
  else
    Result := nil;
end;

procedure TDelphiSpecParser.FeatureNode(Scenarios: TObjectList<TScenario>; StepDefsClass: TStepDefinitionsClass);
var
  Command: string;
  Scenario: TScenario;
begin
  PassEmptyLines;
  CheckEof;

  while not FReader.Eof do
  begin
    Command := Trim(FReader.ReadLine);
    if not FLanguages.StartsWith(Command, sScenario) then
      Break;

    Scenario := TScenario.Create(FLanguages.StepSubstring(Command, sScenario), StepDefsClass);
    Scenarios.Add(Scenario);

    ScenarioNode(Scenario);
  end;
end;

procedure TDelphiSpecParser.GivenNode(Scenario: TScenario);
var
  Command: string;
begin
  Command := Trim(FReader.ReadLine);

  if FLanguages.StartsWith(Command, sGiven) then
    Scenario.AddGiven(FLanguages.StepSubstring(Command, sGiven), TryReadDataTable)
  else if FLanguages.StartsWith(Command, sAnd) then
    Scenario.AddGiven(FLanguages.StepSubstring(Command, sAnd), TryReadDataTable)
  else
    raise EDelphiSpecSyntaxError.Create('Syntax Error');

  PassEmptyLines;
  CheckEof;

  Command := Trim(FReader.PeekLine);

  if FLanguages.StartsWith(Command, sAnd) then
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

procedure TDelphiSpecParser.ScenarioNode(Scenario: TScenario);
begin
  PassEmptyLines;
  CheckEof;

  GivenNode(Scenario);
  WhenNode(Scenario);
  ThenNode(Scenario);
end;

procedure TDelphiSpecParser.ThenNode(Scenario: TScenario);
var
  Command: string;
begin
  Command := Trim(FReader.ReadLine);

  if FLanguages.StartsWith(Command, sThen) then
    Scenario.AddThen(FLanguages.StepSubstring(Command, sThen), TryReadDataTable)
  else if FLanguages.StartsWith(Command, sAnd) then
    Scenario.AddThen(FLanguages.StepSubstring(Command, sAnd), TryReadDataTable)
  else
    raise EDelphiSpecSyntaxError.Create('Syntax Error');

  PassEmptyLines;
  if FReader.Eof then
    Exit;

  Command := Trim(FReader.PeekLine);

  if FLanguages.StartsWith(Command, sAnd) then
    ThenNode(Scenario);
end;

procedure TDelphiSpecParser.WhenNode(Scenario: TScenario);
var
  Command: string;
begin
  Command := Trim(FReader.ReadLine);

  if FLanguages.StartsWith(Command, sWhen) then
    Scenario.AddWhen(FLanguages.StepSubstring(Command, sWhen), TryReadDataTable)
  else if FLanguages.StartsWith(Command, sAnd) then
    Scenario.AddWhen(FLanguages.StepSubstring(Command, sAnd), TryReadDataTable)
  else
    raise EDelphiSpecSyntaxError.Create('Syntax Error');

  PassEmptyLines;
  CheckEof;
  Command := Trim(FReader.PeekLine);

  if FLanguages.StartsWith(Command, sAnd) then
    WhenNode(Scenario);
end;

{ TDelphiSpecLanguages }

constructor TDelphiSpecLanguages.Create(const LangCode: string);
var
  Stream: TResourceStream;
begin
  Stream := TResourceStream.Create(hInstance, 'DelphiSpecLanguages', RT_RCDATA);
  try
    FXML := NewXmlDocument;
    FXML.LoadFromStream(Stream);

    FLangNode := FXML.DocumentElement.ChildNodes.FindNode(LangCode);
  finally
    Stream.Free;
  end;
end;

function TDelphiSpecLanguages.StartsWith(const S, StepKind: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FLangNode.ChildNodes.Count - 1 do
    if (FLangNode.ChildNodes[I].NodeName = StepKind) and StartsText(FLangNode.ChildNodes[I].NodeValue, S) then
    begin
      Result := True;
      Break;
    end;
end;

function TDelphiSpecLanguages.StepSubstring(const S, StepKind: string): string;
var
  I: Integer;
  StepName: string;
begin
  Result := '';
  for I := 0 to FLangNode.ChildNodes.Count - 1 do
    if (FLangNode.ChildNodes[I].NodeName = StepKind) and StartsText(FLangNode.ChildNodes[I].NodeValue, S) then
    begin
      StepName := FLangNode.ChildNodes[I].NodeValue;

      Result := Trim(Copy(S, Length(StepName) + 1));
      Break;
    end;
end;

end.
