Feature: Accounts

Scenario: Correct Login
  Given users exists:
    | id | name  | password |
    | 1  | Roman | pass1    |  
    | 2  | Other | pass2    |
  When I login with "Roman" and "pass1"
  Then I have access to private messages

Scenario: Incorrect Login
  Given users exists:
    | id | name  | password |
    | 1  | Roman | pass1    |  
    | 2  | Other | pass2    |
  When I login with "Roman" and "pass2"
  Then access denied