unit SampleCalculatorStepDefs;

interface

uses
  SampleCalculator, DelphiSpec.Attributes, DelphiSpec.StepDefinitions;

type
  [Feature('calculator')]
  TSampleCalculatorSteps = class(TStepDefinitions)
  private
    FCalc: TCalculator;
  public
    procedure SetUp; override;
    procedure TearDown; override;

//    [Given_('I have entered (.*) in calculator')]
//    [Given_('I have entered $value in calculator')]
//    [Given_]
    procedure Given_I_have_entered_value_in_calculator(Value: Integer);

//    [When_('I press Add')]
//    [When_]
    procedure When_I_press_add;

//    [When_('I press Mul')]
//    [When_]
    procedure When_I_press_mul;

//    [Then_('the result should be (.*) on the screen')]
//    [Then_('the result should be $value on the screen')]
//    [Then_]
    procedure Then_the_result_should_be_value_on_the_screen(Value: Integer);
  end;

implementation

uses
  SysUtils, TestFramework, DelphiSpec.Core;

{ TSampleCalculatorSteps }

procedure TSampleCalculatorSteps.When_I_press_add;
begin
  FCalc.Add;
end;

procedure TSampleCalculatorSteps.Given_I_have_entered_value_in_calculator(Value: Integer);
begin
  FCalc.Push(Value);
end;

procedure TSampleCalculatorSteps.When_I_press_mul;
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

procedure TSampleCalculatorSteps.Then_the_result_should_be_value_on_the_screen(Value: Integer);
begin
  if FCalc.Value <> Value then
    raise ETestFailure.Create('Incorrect result on calculator screen');
end;

initialization
  RegisterStepDefinitionsClass(TSampleCalculatorSteps);

end.
