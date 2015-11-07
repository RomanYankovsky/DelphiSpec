// AUTOMATICALLY GENERATED, DO NOT EDIT! //

type
  [Feature('Calculator')]
  TcalculatorTest = class(TcalculatorTestContext)
  public
    procedure Given_I_have_entered_value_in_calculator(const value: Integer);
    procedure When_I_press_Add;
    procedure Then_the_result_should_be_value_on_the_screen(const value: Integer);
    procedure When_I_press_mul;
  end;

const
  calculatorSource: String = (
'Feature: Calculator'#13#10 +
'  In order to avoid silly mistakes'#13#10 +
'  As a math idiot'#13#10 +
'  I want to be told the sum and the multiplication of two numbers'#13#10 +
''#13#10 +
'Scenario: Add two numbers (fails)'#13#10 +
'  Given I have entered 50 in calculator'#13#10 +
'    And I have entered 50 in calculator'#13#10 +
'  When I press Add'#13#10 +
'  Then the result should be 120 on the screen'#13#10 +
''#13#10 +
'Scenario Outline: Add two numbers'#13#10 +
'  Given I have entered <num1> in calculator'#13#10 +
'    And I have entered <num2> in calculator'#13#10 +
'  When I press Add'#13#10 +
'  Then the result should be <sum> on the screen'#13#10 +
'  '#13#10 +
'  Examples:'#13#10 +
'    | num1 | num2 | sum |'#13#10 +
'    |  1   |  2   |  3  | '#13#10 +
'    |  4   |  5   |  9  |'#13#10 +
'    |  3   |  1   |  4  |'#13#10 +
''#13#10 +
'Scenario: Multiply three numbers'#13#10 +
'  Given I have entered 5 in calculator'#13#10 +
'    And I have entered 5 in calculator'#13#10 +
'    And I have entered 4 in calculator'#13#10 +
'  WHEN I press mul'#13#10 +
'  Then the result should be 100 on the screen'#13#10
);

procedure RegistercalculatorTest;
begin
  RegisterStepDefinitionsClass(TcalculatorTest);
  TDelphiSpecParser.RegisterClass('calculator', 'EN', calculatorSource);
end;
