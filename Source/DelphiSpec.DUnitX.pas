unit DelphiSpec.DUnitX;

interface

uses
  Generics.Collections,
  DelphiSpec.Scenario,
  DUnitX.Extensibility;

procedure RegisterFeaturesWithDUnitX(const rootName : string; const Features: TObjectList<TFeature>);

implementation

uses
  DUnitX.TestFramework,
  DelphiSpec.Assert,
  DelphiSpec.StepDefinitions;

var
  _Features : TObjectList<TFeature>;
  _RootName : string;


procedure RegisterFeaturesWithDUnitX(const rootName : string; const Features: TObjectList<TFeature>);
begin
  _RootName := rootName;
  _Features := Features;
end;

type
  TDelphiSpecFixtureProvider = class(TInterfacedObject,IFixtureProvider)
  protected
    procedure Execute(const context: IFixtureProviderContext);
  end;

  TDelphiSpecPlugin = class(TInterfacedObject,IPlugin)
  protected
    procedure GetPluginFeatures(const context: IPluginLoadContext);
  end;

  TDUnitXScenario = class
  private
    FScenario : TScenario;
  public
    constructor Create(const AScenario : TScenario);
  published
    procedure Execute;
  end;


{ TDelphiSpecPlugin }

procedure TDelphiSpecPlugin.GetPluginFeatures(const context: IPluginLoadContext);
begin
  context.RegisterFixtureProvider(TDelphiSpecFixtureProvider.Create);
end;

{ TDelphiSpecFixtureProvider }

procedure TDelphiSpecFixtureProvider.Execute(const context: IFixtureProviderContext);
var
  feature: TFeature;
  ScenarioOutline: TScenarioOutline;

  rootFixture : ITestFixture;

  featureFixture : ITestFixture;
  outlineFixture : ITestFixture;
  scenarioFixture : ITestFixture;
  StepDefs: TStepDefinitions;

  procedure BuildTests(const parentFixture : ITestFixture; const scenarios : TObjectList<TScenario>);
  var
    fixtureInstance  : TDUnitXScenario;
    testMethod : TTestMethod;
    method : TMethod;
    scenario : TScenario;
  begin
    for scenario in scenarios do
    begin
       fixtureInstance := TDUnitXScenario.Create(scenario);
       scenarioFixture := parentFixture.AddChildFixture(fixtureInstance,scenario.Name);

       method.Data :=  fixtureInstance;
       method.Code := @TDUnitXScenario.Execute;

       testMethod := TTestMethod(method);
       scenarioFixture.AddTest(testMethod,scenario.Name);
    end;
  end;


begin
  if (_Features = nil) or (_Features.Count < 1) then
    exit;

  rootFixture := context.CreateFixture(TObject,_RootName);

  for feature in _Features do
  begin
    featureFixture := rootFixture.AddChildFixture(TObject,feature.Name);
    BuildTests(featureFixture,feature.Scenarios);

    for ScenarioOutline in Feature.ScenarioOutlines do
    begin
      outlineFixture := featureFixture.AddChildFixture(TObject,ScenarioOutline.Name);
      BuildTests(outlineFixture,ScenarioOutline.Scenarios);
    end;
  end;
end;

{ TDUnitXScenario }

constructor TDUnitXScenario.Create(const AScenario: TScenario);
begin
  FScenario := AScenario;
end;

procedure TDUnitXScenario.Execute;
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

initialization
  TDUnitX.RegisterPlugin(TDelphiSpecPlugin.Create);

end.
