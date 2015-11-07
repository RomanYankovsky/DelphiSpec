unit DelphiSpec.DUnitX;

interface

uses
  Generics.Collections,
  DelphiSpec.Scenario,
  DUnitX.Extensibility;

procedure RegisterFeaturesWithDUnitX(const RootName: string; const Features: TFeatureList);

implementation

uses
  DUnitX.TestFramework,
  DelphiSpec.Assert,
  DelphiSpec.StepDefinitions;

var
  _Features: TFeatureList;
  _RootName: string;

procedure RegisterFeaturesWithDUnitX(const RootName: string; const Features: TFeatureList);
begin
  _RootName := rootName;
  _Features := Features;
end;

type
  TDelphiSpecFixtureProvider = class(TInterfacedObject,IFixtureProvider)
  protected
    procedure Execute(const Context: IFixtureProviderContext);
  end;

  TDelphiSpecPlugin = class(TInterfacedObject,IPlugin)
  protected
    procedure GetPluginFeatures(const Context: IPluginLoadContext);
  end;

  TDUnitXScenario = class
  private
    FScenario: TScenario;
  public
    constructor Create(const Scenario : TScenario);
  public
    procedure Execute;
  end;

{ TDelphiSpecPlugin }

procedure TDelphiSpecPlugin.GetPluginFeatures(const Context: IPluginLoadContext);
begin
  Context.RegisterFixtureProvider(TDelphiSpecFixtureProvider.Create);
end;

{ TDelphiSpecFixtureProvider }

procedure TDelphiSpecFixtureProvider.Execute(const Context: IFixtureProviderContext);
var
  Feature: TFeature;
  ScenarioOutline: TScenarioOutline;

  RootFixture: ITestFixture;

  FeatureFixture: ITestFixture;
  OutlineFixture: ITestFixture;
  ScenarioFixture: ITestFixture;

  procedure BuildTests(const ParentFixture: ITestFixture; const Scenarios: TScenarioList);
  var
    FixtureInstance: TDUnitXScenario;
    TestMethod: TTestMethod;
    Method: TMethod;
    Scenario: TScenario;
  begin
    for Scenario in Scenarios do
    begin
       FixtureInstance := TDUnitXScenario.Create(Scenario);

       Method.Data := FixtureInstance;
       Method.Code := @TDUnitXScenario.Execute;

       TestMethod := TTestMethod(Method);
       ParentFixture.AddTest('', TestMethod, Scenario.Name, '');
    end;
  end;

begin
  if (_Features = nil) or (_Features.Count < 1) then
    Exit;

  RootFixture := Context.CreateFixture(TObject, _RootName, '');

  for Feature in _Features do
  begin
    FeatureFixture := RootFixture.AddChildFixture(TObject, Feature.Name, '');
    BuildTests(FeatureFixture, Feature.Scenarios);

    for ScenarioOutline in Feature.ScenarioOutlines do
    begin
      OutlineFixture := FeatureFixture.AddChildFixture(TObject, ScenarioOutline.Name, '');
      BuildTests(OutlineFixture, ScenarioOutline.Scenarios);
    end;
  end;
end;

{ TDUnitXScenario }

constructor TDUnitXScenario.Create(const Scenario: TScenario);
begin
  FScenario := Scenario;
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
