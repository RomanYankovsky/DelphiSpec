unit DelphiSpec.Test.Languages;

interface

uses
  TestFramework, DelphiSpec.Parser;

type
  Test_TDelphiSpecLanguages = class(TTestCase)
  published
    procedure Test_CheckStepKind;
    procedure Test_GetStepText;
  end;

implementation

{ Test_TDelphiSpecLanguages }

procedure Test_TDelphiSpecLanguages.Test_CheckStepKind;
begin
  self.CheckTrue(TDelphiSpecLanguages.CheckStepKind(skFeature, 'Feature: EN feature', 'EN'));
  self.CheckFalse(TDelphiSpecLanguages.CheckStepKind(skGiven, 'Feature: EN feature', 'EN'));
  self.CheckTrue(TDelphiSpecLanguages.CheckStepKind(skFeature, 'Funcionalidade: PT_BR feature', 'PT_BR'));

  self.CheckFalse(TDelphiSpecLanguages.CheckStepKind(skAnd, 'Então in PT_BR is then', 'PT_BR'));
  self.CheckFalse(TDelphiSpecLanguages.CheckStepKind(skAnd, 'Esboço do Cenário: in PT_BR is ScenarioOutline', 'PT_BR'));
  self.CheckFalse(TDelphiSpecLanguages.CheckStepKind(skAnd, 'Exemplos: in PT_BR is Examples', 'PT_BR'));
end;

procedure Test_TDelphiSpecLanguages.Test_GetStepText;
begin
  self.CheckEquals('EN feature', TDelphiSpecLanguages.GetStepText(skFeature, 'Feature: EN feature', 'EN'));
  self.CheckEquals('PT_BR given', TDelphiSpecLanguages.GetStepText(skGiven, 'Dado PT_BR given', 'PT_BR'));
end;

initialization
  RegisterTest(Test_TDelphiSpecLanguages.Suite);

end.
