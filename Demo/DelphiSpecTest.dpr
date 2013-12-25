program DelphiSpecTest;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  SampleCalculator in 'SampleCalculator.pas',
  SampleCalculatorStepDefs in 'SampleCalculatorStepDefs.pas',
  SampleAccountsStepDefs in 'SampleAccountsStepDefs.pas',
  DelphiSpec.DUnit;

begin
  PrepareDelphiSpecs('features', True, 'EN');
  DUnitTestRunner.RunRegisteredTests;
end.

