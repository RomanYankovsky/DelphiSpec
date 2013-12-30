unit SampleSpamFilterStepDefs;

interface

uses
  DelphiSpec.Attributes, DelphiSpec.StepDefinitions;

type
  [Feature('spam filter')]
  TSpamFilterSteps = class(TStepDefinitions)
  private
    FBlackList: string;
    FMailCount: Integer;
  public
    procedure Given_I_have_a_blacklist(const Text: string);
    procedure Given_I_have_empty_inbox;

    [When_('I receive an email from "(.*)"')]
    procedure ReceiveEmail(const From: string);

    procedure Then_my_inbox_is_empty;
  end;

implementation

uses
  StrUtils, DelphiSpec.Core, DelphiSpec.Assert;

{ TFilterSteps }

procedure TSpamFilterSteps.Given_I_have_a_blacklist(const Text: string);
begin
  FBlackList := Text;
end;

procedure TSpamFilterSteps.Given_I_have_empty_inbox;
begin
  FMailCount := 0;
end;

procedure TSpamFilterSteps.ReceiveEmail(const From: string);
begin
  if not ContainsStr(FBlackList, From) then
    Inc(FMailCount);
end;

procedure TSpamFilterSteps.Then_my_inbox_is_empty;
begin
  Assert.AreEqual(0, FMailCount, 'Inbox should be empty');
end;

initialization
  RegisterStepDefinitionsClass(TSpamFilterSteps);

end.
