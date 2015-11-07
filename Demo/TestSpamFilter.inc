// AUTOMATICALLY GENERATED, DO NOT EDIT! //

type
  [Feature('Spam Filter')]
  TSpamFilterTest = class(TSpamFilterTestContext)
  public
    [Given_('I have a blacklist:')]
    procedure Given_I_have_a_blacklist(const text: String);
    procedure Given_I_have_empty_inbox;
    [When_('I receive an email from "(.*)"')]
    procedure When_I_receive_an_email_from_value(const value: String);
    procedure Then_my_inbox_is_empty;
  end;

const
  SpamFilterSource: String = (
'Feature: Spam Filter'#13#10 +
''#13#10 +
'Scenario: Blacklist'#13#10 +
'  Given I have a blacklist:'#13#10 +
'      """'#13#10 +
'      m@mail.com'#13#10 +
'      123@mail.com'#13#10 +
'      """'#13#10 +
'    And I have empty inbox'#13#10 +
'  When I receive an email from "m@mail.com"'#13#10 +
'  Then my inbox is empty'#13#10
);

procedure RegisterSpamFilterTest;
begin
  RegisterStepDefinitionsClass(TSpamFilterTest);
  TDelphiSpecParser.RegisterClass('SpamFilter', 'EN', SpamFilterSource);
end;
