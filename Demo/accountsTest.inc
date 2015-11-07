// AUTOMATICALLY GENERATED, DO NOT EDIT! //

type
  [Feature('Accounts')]
  TaccountsTest = class(TaccountsTestContext)
  public type
    t_data = record
      id: Integer;
      name: String;
      password: String;
    end;
  public
    [Given_('users exist:')]
    procedure Given_users_exist(const data: TArray<t_data>);
    [Given_('my name is "(.*)"')]
    procedure Given_my_name_is_value(const value: String);
    [Given_('my password is "(.*)"')]
    procedure Given_my_password_is_value(const value: String);
    procedure When_I_login;
    procedure Then_I_have_access_to_private_messages;
    procedure Then_access_denied;
    [Given_('user "(.*)" has been removed')]
    procedure Given_user_value_has_been_removed(const value: String);
  end;

const
  accountsSource: String = (
'Feature: Accounts'#13#10 +
''#13#10 +
'Background:'#13#10 +
'  Given users exist:'#13#10 +
'    | id | name  | password |'#13#10 +
'    | 1  | Roman | pass1    |  '#13#10 +
'    | 2  | Other | pass2    |'#13#10 +
''#13#10 +
'Scenario: Correct Login'#13#10 +
'  Given my name is "Roman"'#13#10 +
'    And my password is "pass1"'#13#10 +
'  When I login'#13#10 +
'  Then I have access to private messages'#13#10 +
''#13#10 +
'Scenario: Incorrect Login'#13#10 +
'  Given my name is "Roman"'#13#10 +
'    And my password is "pass2"'#13#10 +
'  When I login'#13#10 +
'  Then access denied'#13#10 +
''#13#10 +
'Scenario: Remove user'#13#10 +
'  Given my name is "Roman"'#13#10 +
'    And my password is "pass1"'#13#10 +
'    But user "Roman" has been removed'#13#10 +
'  When I login'#13#10 +
'  Then access denied'#13#10
);

procedure RegisteraccountsTest;
begin
  RegisterStepDefinitionsClass(TaccountsTest);
  TDelphiSpecParser.RegisterClass('accounts', 'EN', accountsSource);
end;
