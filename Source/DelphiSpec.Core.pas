unit DelphiSpec.Core;

interface

uses
  DelphiSpec.StepDefinitions;

procedure PrepareDelphiSpecs(const Path: string; Recursive: Boolean; const LangCode: string);

function GetStepDefinitionsClass(const Name: string): TStepDefinitionsClass;
procedure RegisterStepDefinitionsClass(StepDefinitionsClass: TStepDefinitionsClass);

implementation

uses
  SysUtils, Classes, IOUtils, Rtti, Generics.Collections,
  TestFramework, DelphiSpec.Scenario, DelphiSpec.Parser, DelphiSpec.Attributes;

type
  TDelphiSpecTestCase = class(TAbstractTest)
  protected
    FScenario: TScenario;
    procedure RunTest(testResult: TTestResult); override;
  public
    constructor Create(const Name: string; const Scenario: TScenario); overload; virtual;
    destructor Destroy; override;
  end;

const
  FileMask = '*.feature';

var
  __StepDefsClassList: TDictionary<string, TStepDefinitionsClass>;

procedure PrepareDelphiSpecs(const Path: string; Recursive: Boolean; const LangCode: string);
var
  FileName: string;
  Parser: TDelphiSpecParser;
  SearchMode: TSearchOption;

  Scenario: TScenario;
  Feature: TPair<string, TObjectList<TScenario>>;
  Features: TDictionary<string, TObjectList<TScenario>>;

  TestSuite: TTestSuite;
begin
  if Recursive then
    SearchMode := TSearchOption.soAllDirectories
  else
    SearchMode := TSearchOption.soTopDirectoryOnly;

  Features := nil;
  Parser := nil;
  try
    Features := TDictionary<string, TObjectList<TScenario> >.Create;
    Parser := TDelphiSpecParser.Create(LangCode);

    for FileName in TDirectory.GetFiles(Path, FileMask, SearchMode) do
    begin
      Features.Clear;
      Parser.Execute(FileName, Features);

      for Feature in Features do
      begin
        TestSuite := TTestSuite.Create(Feature.Key);
        for Scenario in Feature.Value do
          TestSuite.AddTest(TDelphiSpecTestCase.Create(Scenario.Name, Scenario));

        RegisterTest(TestSuite);

        Feature.Value.Free;
      end;
    end;
  finally
    Features.Free;
    Parser.Free;
  end;
end;

procedure RegisterStepDefinitionsClass(StepDefinitionsClass: TStepDefinitionsClass);
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  RttiAttr: TCustomAttribute;
begin
  __StepDefsClassList.Add(AnsiLowerCase(StepDefinitionsClass.ClassName), StepDefinitionsClass);

  RttiContext := TRttiContext.Create;
  try
    RttiType := RttiContext.GetType(StepDefinitionsClass);

    for RttiAttr in RttiType.GetAttributes do
      if RttiAttr is FeatureAttribute then
        __StepDefsClassList.Add(AnsiLowerCase(FeatureAttribute(RttiAttr).Text), StepDefinitionsClass);
  finally
    RttiContext.Free;
  end;
end;

function GetStepDefinitionsClass(const Name: string): TStepDefinitionsClass;
begin
  Result := __StepDefsClassList[AnsiLowerCase(Name)];
end;

{ TDelphiSpecTestCase }

constructor TDelphiSpecTestCase.Create(const Name: string;
  const Scenario: TScenario);
begin
  inherited Create(Name);
  FScenario := Scenario;
end;

destructor TDelphiSpecTestCase.Destroy;
begin
  FScenario.Free;
  inherited;
end;

procedure TDelphiSpecTestCase.RunTest(testResult: TTestResult);
begin
  FScenario.Execute;
end;

initialization
  __StepDefsClassList := TDictionary<string, TStepDefinitionsClass>.Create;

finalization
  __StepDefsClassList.Free;

end.
