unit TestSpamFilter;

interface

uses
  DelphiSpec.StepDefinitions;

type
  TSpamFilterTestContext = class(TStepDefinitions)
  private
    FBlackList: string;
    FMailCount: Integer;
  end;

implementation

uses
  System.StrUtils
, DelphiSpec.Core
, DelphiSpec.Assert
, DelphiSpec.Parser
, DelphiSpec.Attributes;

{$I TestSpamFilter.inc}

{ TSpamFilterTest }

procedure TSpamFilterTest.Given_I_have_a_blacklist(const text: String);
begin
  FBlackList := Text;
end;

procedure TSpamFilterTest.Given_I_have_empty_inbox;
begin
  FMailCount := 0;
end;

procedure TSpamFilterTest.Then_my_inbox_is_empty;
begin
  Assert.AreEqual(0, FMailCount, 'Inbox should be empty');
end;

procedure TSpamFilterTest.When_I_receive_an_email_from_value(
  const value: String);
begin
  if not ContainsStr(FBlackList, value) then
    Inc(FMailCount);
end;

initialization
  RegisterSpamFilterTest;
end.
