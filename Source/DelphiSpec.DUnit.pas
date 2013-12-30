unit DelphiSpec.DUnit;

interface

uses
  Generics.Collections, DelphiSpec.Scenario;

procedure CreateDUnitTests(Features: TObjectList<TFeature>);

implementation

uses
  TestFramework, DelphiSpec.StepDefinitions, DelphiSpec.Assert;

type
  TDelphiSpecTestSuite = class(TTestSuite)
  public
    constructor Create(const Name: string; Scenarios: TObjectList<TScenario>); overload; virtual;
  end;

  TDelphiSpecTestCase = class(TAbstractTest)
  protected
    FScenario: TScenario;
    procedure RunTest(testResult: TTestResult); override;
  public
    constructor Create(Scenario: TScenario); overload; virtual;
  end;

procedure CreateDUnitTests(Features: TObjectList<TFeature>);
var
  Feature: TFeature;
  Suite: TDelphiSpecTestSuite;
  ScenarioOutline: TScenarioOutline;
begin
  for Feature in Features do
  begin
    Suite := TDelphiSpecTestSuite.Create(Feature.Name, Feature.Scenarios);

    for ScenarioOutline in Feature.ScenarioOutlines do
      Suite.AddSuite(TDelphiSpecTestSuite.Create(ScenarioOutline.Name, ScenarioOutline.Scenarios));

    RegisterTest(Suite);
  end;
end;

{ TDelphiSpecTestCase }

constructor TDelphiSpecTestCase.Create(Scenario: TScenario);
begin
  inherited Create(Scenario.Name);
  FScenario := Scenario;
end;

procedure TDelphiSpecTestCase.RunTest(testResult: TTestResult);
var
  StepDefs: TStepDefinitions;
begin
  StepDefs := FScenario.Feature.StepDefinitionsClass.Create;
  try
    StepDefs.SetUp;
    try
      if Assigned(FScenario.Feature.Background) then
        FScenario.Feature.Background.Execute(StepDefs);

      try
        FScenario.Execute(StepDefs);
      except
        on E: EScenarioStepException do
          raise ETestFailure.Create(E.Message);
        on E: EDelphiSpecTestFailure do
          raise ETestFailure.Create(E.Message);
      end;
    finally
      StepDefs.TearDown;
    end;
  finally
    StepDefs.Free;
  end;
end;

{ TDelphiSpecTestSuite }

constructor TDelphiSpecTestSuite.Create(const Name: string; Scenarios: TObjectList<TScenario>);
var
  Scenario: TScenario;
begin
  inherited Create(Name);

  for Scenario in Scenarios do
    self.AddTest(TDelphiSpecTestCase.Create(Scenario));
end;

end.
