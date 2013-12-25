unit DelphiSpec.DUnit;

interface

procedure PrepareDelphiSpecs(const Path: string; Recursive: Boolean; const LangCode: string);

implementation

uses
  IOUtils, Generics.Collections, TestFramework, DelphiSpec.Scenario,
  DelphiSpec.Parser, DelphiSpec.StepDefinitions;

const
  FileMask = '*.feature';

type
  TDelphiSpecTestSuite = class(TTestSuite)
  private
    FFeature: TFeature;
  public
    constructor Create(Feature: TFeature); overload; virtual;
    destructor Destroy; override;
  end;

  TDelphiSpecTestCase = class(TAbstractTest)
  protected
    FScenario: TScenario;
    procedure RunTest(testResult: TTestResult); override;
  public
    constructor Create(Scenario: TScenario); overload; virtual;
    destructor Destroy; override;
  end;

procedure PrepareDelphiSpecs(const Path: string; Recursive: Boolean; const LangCode: string);
var
  FileName: string;
  Parser: TDelphiSpecParser;
  SearchMode: TSearchOption;

  Feature: TFeature;
  Features: TObjectList<TFeature>;
begin
  if Recursive then
    SearchMode := TSearchOption.soAllDirectories
  else
    SearchMode := TSearchOption.soTopDirectoryOnly;

  Features := nil;
  Parser := nil;
  try
    Features := TObjectList<TFeature>.Create(False);
    Parser := TDelphiSpecParser.Create(LangCode);

    for FileName in TDirectory.GetFiles(Path, FileMask, SearchMode) do
    begin
      Features.Clear;
      Parser.Execute(FileName, Features);

      for Feature in Features do
         RegisterTest(TDelphiSpecTestSuite.Create(Feature));
    end;
  finally
    Features.Free;
    Parser.Free;
  end;
end;

{ TDelphiSpecTestCase }

constructor TDelphiSpecTestCase.Create(Scenario: TScenario);
begin
  inherited Create(Scenario.Name);
  FScenario := Scenario;
end;

destructor TDelphiSpecTestCase.Destroy;
begin
  FScenario.Free;
  inherited;
end;

procedure TDelphiSpecTestCase.RunTest(testResult: TTestResult);
var
  StepDefs: TStepDefinitions;
begin
  StepDefs := FScenario.Feature.StepDefinitionsClass.Create;
  try
    StepDefs.SetUp;

    if Assigned(FScenario.Feature.Background) then
      FScenario.Feature.Background.Execute(StepDefs);

    FScenario.Execute(StepDefs);

    StepDefs.TearDown;
  finally
    StepDefs.Free;
  end;
end;

{ TDelphiSpecTestSuite }

constructor TDelphiSpecTestSuite.Create(Feature: TFeature);
var
  Scenario: TScenario;
begin
  inherited Create(Feature.Name);
  FFeature := Feature;

  for Scenario in Feature.Scenarios do
    self.AddTest(TDelphiSpecTestCase.Create(Scenario));
end;

destructor TDelphiSpecTestSuite.Destroy;
begin
  FFeature.Free;
  inherited;
end;

end.
