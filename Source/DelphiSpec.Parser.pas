unit DelphiSpec.Parser;

interface

uses
  SysUtils, Classes, Generics.Collections, XmlIntf,
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
    FFeatures: TDictionary<string, TObjectList<TScenario>>;
    FReader: TDelphiSpecFileReader;
    FLanguages: TDelphiSpecLanguages;

    procedure CheckEof;
    procedure PassEmptyLines;

    procedure FeatureNode;
    procedure ScenarioNode(StepDefsClass: TStepDefinitionsClass; Scenarios: TObjectList<TScenario>);
    procedure GivenNode(StepDefsClass: TStepDefinitionsClass; Scenario: TScenario; Scenarios: TObjectList<TScenario>);
    procedure WhenNode(StepDefsClass: TStepDefinitionsClass; Scenario: TScenario; Scenarios: TObjectList<TScenario>);
    procedure ThenNode(StepDefsClass: TStepDefinitionsClass; Scenario: TScenario; Scenarios: TObjectList<TScenario>);
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
  Command: string;
begin
  FFeatures := Features;
  FReader.LoadFromFile(FileName);

  PassEmptyLines;
  if FReader.Eof then
    Exit;

  Command := Trim(FReader.PeekLine);
  if FLanguages.StartsWith(Command, sFeature) then
    FeatureNode
  else
    raise EDelphiSpecSyntaxError.Create('Syntax Error!');
end;

procedure TDelphiSpecParser.FeatureNode;
var
  Command: string;
  FeatureName: string;
  Scenarios: TObjectList<TScenario>;
  StepDefsClass: TStepDefinitionsClass;
begin
  Command := Trim(FReader.ReadLine);
  FeatureName := FLanguages.StepSubstring(Command, sFeature);
  StepDefsClass := GetStepDefinitionsClass(FeatureName);

  Scenarios := TObjectList<TScenario>.Create(False);
  FFeatures.Add(FeatureName, Scenarios);

  PassEmptyLines;
  CheckEof;
  Command := Trim(FReader.PeekLine);

  if FLanguages.StartsWith(Command, sScenario) then
    ScenarioNode(StepDefsClass, Scenarios)
  else
    raise EDelphiSpecSyntaxError.Create('Syntax Error!');
end;

procedure TDelphiSpecParser.GivenNode(StepDefsClass: TStepDefinitionsClass; Scenario: TScenario;
   Scenarios: TObjectList<TScenario>);
var
  Command: string;
begin
  Command := Trim(FReader.ReadLine);
  if FLanguages.StartsWith(Command, sGiven) then
    Scenario.AddGiven(FLanguages.StepSubstring(Command, sGiven))
  else if FLanguages.StartsWith(Command, sAnd) then
    Scenario.AddGiven(FLanguages.StepSubstring(Command, sAnd));

  PassEmptyLines;
  CheckEof;
  Command := Trim(FReader.PeekLine);

  if FLanguages.StartsWith(Command, sAnd) then
    GivenNode(StepDefsClass, Scenario, Scenarios)
  else if FLanguages.StartsWith(Command, sWhen) then
    WhenNode(StepDefsClass, Scenario, Scenarios)
  else
    raise EDelphiSpecSyntaxError.Create('Syntax Error!');
end;

procedure TDelphiSpecParser.PassEmptyLines;
begin
  while not FReader.Eof do
    if Trim(FReader.PeekLine) = '' then
      FReader.ReadLine
    else
      Break;
end;

procedure TDelphiSpecParser.ScenarioNode(StepDefsClass: TStepDefinitionsClass;
  Scenarios: TObjectList<TScenario>);
var
  Command: string;
  Scenario: TScenario;
begin
  Command := Trim(FReader.ReadLine);
  Scenario := TScenario.Create(FLanguages.StepSubstring(Command, sScenario), StepDefsClass);
  Scenarios.Add(Scenario);

  PassEmptyLines;
  CheckEof;
  Command := Trim(FReader.PeekLine);

  if FLanguages.StartsWith(Command, sGiven) then
    GivenNode(StepDefsClass, Scenario, Scenarios)
  else
    raise EDelphiSpecSyntaxError.Create('Syntax Error!');
end;

procedure TDelphiSpecParser.ThenNode(StepDefsClass: TStepDefinitionsClass; Scenario: TScenario;
  Scenarios: TObjectList<TScenario>);
var
  Command: string;
begin
  Command := Trim(FReader.ReadLine);
  if FLanguages.StartsWith(Command, sThen) then
    Scenario.AddThen(FLanguages.StepSubstring(Command, sThen))
  else if FLanguages.StartsWith(Command, sAnd) then
    Scenario.AddThen(FLanguages.StepSubstring(Command, sAnd));

  PassEmptyLines;
  if FReader.Eof then
    Exit;

  Command := Trim(FReader.PeekLine);

  if FLanguages.StartsWith(Command, sAnd) then
    ThenNode(StepDefsClass, Scenario, Scenarios)
  else if FLanguages.StartsWith(Command, sScenario) then
    ScenarioNode(StepDefsClass, Scenarios)
  else if FLanguages.StartsWith(Command, sFeature) then
    FeatureNode
  else
    raise EDelphiSpecSyntaxError.Create('Syntax Error!');
end;

procedure TDelphiSpecParser.WhenNode(StepDefsClass: TStepDefinitionsClass; Scenario: TScenario;
  Scenarios: TObjectList<TScenario>);
var
  Command: string;
begin
  Command := Trim(FReader.ReadLine);
  if FLanguages.StartsWith(Command, sWhen) then
    Scenario.AddWhen(FLanguages.StepSubstring(Command, sWhen))
  else if FLanguages.StartsWith(Command, sAnd) then
    Scenario.AddWhen(FLanguages.StepSubstring(Command, sAnd));

  PassEmptyLines;
  CheckEof;
  Command := Trim(FReader.PeekLine);

  if FLanguages.StartsWith(Command, sAnd) then
    WhenNode(StepDefsClass, Scenario, Scenarios)
  else if FLanguages.StartsWith(Command, sThen) then
    ThenNode(StepDefsClass, Scenario, Scenarios)
  else
    raise EDelphiSpecSyntaxError.Create('Syntax Error!');
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
