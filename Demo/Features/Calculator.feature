Feature: Calculator
  In order to avoid silly mistakes
  As a math idiot
  I want to be told the sum and the multiplication of two numbers

Scenario: Add two numbers (fails)
  Given I have entered 50 in calculator
    And I have entered 50 in calculator
  When I press Add
  Then the result should be 120 on the screen

Scenario Outline: Add two numbers
  Given I have entered <num1> in calculator
    And I have entered <num2> in calculator
  When I press Add
  Then the result should be <sum> on the screen
  
  Examples:
    | num1 | num2 | sum |
    |  1   |  2   |  3  | 
    |  4   |  5   |  9  |
    |  3   |  1   |  4  |

Scenario: Multiply three numbers
  Given I have entered 5 in calculator
    And I have entered 5 in calculator
    And I have entered 4 in calculator
  WHEN I press mul
  Then the result should be 100 on the screen
