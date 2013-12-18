unit SampleCalculatorStepDefs;

interface

uses
  SampleCalculator, DelphiSpec.Attributes, DelphiSpec.StepDefinitions;

type
  [_Feature('calculator')]
  TSampleCalculatorSteps = class(TStepDefinitions)
  private
    FCalc: TCalculator;
  public
    procedure SetUp; override;
    procedure TearDown; override;

    [_Given('I have entered (.*) in calculator')]
    procedure EnterInt(Value: string);

    [_When('I press Add')]
    procedure AddInt;

    [_When('I press Mul')]
    procedure MulInt;

    [_Then('the result should be (.*) on the screen')]
    procedure TestResult(Value: string);
  end;

implementation

uses
  System.SysUtils, TestFramework, DelphiSpec.Core;

{ TSampleCalculatorSteps }

procedure TSampleCalculatorSteps.AddInt;
begin
  FCalc.Add;
end;

procedure TSampleCalculatorSteps.EnterInt(Value: string);
begin
  FCalc.Push(Value.ToInteger);
end;

procedure TSampleCalculatorSteps.MulInt;
begin
  FCalc.Mul;
end;

procedure TSampleCalculatorSteps.SetUp;
begin
  FCalc := TCalculator.Create;
end;

procedure TSampleCalculatorSteps.TearDown;
begin
  FCalc.Free;
end;

procedure TSampleCalculatorSteps.TestResult(Value: string);
begin
  if FCalc.Value <> Value.ToInteger then
    raise ETestFailure.Create('Incorrect result on calculator screen');
end;

initialization
  RegisterStepDefinitionsClass(TSampleCalculatorSteps);

end.
