program DelphiSpecDemo;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  Generics.Collections,
  DelphiSpec.Core,
  DelphiSpec.Scenario,
  DelphiSpec.DUnit,
  DelphiSpec.Parser,
  TestAccounts in 'TestAccounts.pas',
  SampleCalculator in 'SampleCalculator.pas',
  TestCalculator in 'TestCalculator.pas',
  TestSpamFilter in 'TestSpamFilter.pas';

begin
  CreateDUnitTests(TDelphiSpecParser.GetFeatures);
  DUnitTestRunner.RunRegisteredTests;
end.

