unit TestCalculator;

interface

uses
  SampleCalculator
, DelphiSpec.StepDefinitions;

type
  TCalculatorTestContext = class(TStepDefinitions)
  private
    FCalc: TCalculator;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  end;

implementation

uses
  System.SysUtils
, DelphiSpec.Core
, DelphiSpec.Assert
, DelphiSpec.Parser
, DelphiSpec.Attributes;

{$I TestCalculator.inc}

{ TCalculatorTest }

procedure TCalculatorTest.Given_I_have_entered_value_in_calculator(
  const value: Integer);
begin
  FCalc.Push(value);
end;

procedure TCalculatorTest.Then_the_result_should_be_value_on_the_screen(
  const value: Integer);
begin
  Assert.AreEqual(Int64(Value), FCalc.Value,
    'Incorrect result on calculator screen');
end;

procedure TCalculatorTest.When_I_press_Add;
begin
  FCalc.Add;
end;

procedure TCalculatorTest.When_I_press_mul;
begin
  FCalc.Mul;
end;

{ TCalculatorTestContext }

procedure TCalculatorTestContext.SetUp;
begin
  FCalc := TCalculator.Create;
end;

procedure TCalculatorTestContext.TearDown;
begin
  FCalc.Free;
end;

initialization
  RegisterCalculatorTest;
end.
