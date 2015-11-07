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
  SampleAccountsStepDefs in 'SampleAccountsStepDefs.pas',
  SampleCalculator in 'SampleCalculator.pas',
  SampleCalculatorStepDefs in 'SampleCalculatorStepDefs.pas',
  SampleSpamFilterStepDefs in 'SampleSpamFilterStepDefs.pas';

begin
  CreateDUnitTests(TDelphiSpecParser.GetFeatures);
  DUnitTestRunner.RunRegisteredTests;
end.

