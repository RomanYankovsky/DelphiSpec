Feature: Accounts

Background:
  Given users exist:
    | id | name  | password |
    | 1  | Roman | pass1    |  
    | 2  | Other | pass2    |

Scenario: Correct Login
  Given my name is "Roman"
    And my password is "pass1"
  When I login
  Then I have access to private messages

Scenario: Incorrect Login
  Given my name is "Roman"
    And my password is "pass1"
  When I login
  Then access denied
