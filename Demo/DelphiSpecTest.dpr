program DelphiSpecTest;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  SampleCalculator in 'SampleCalculator.pas',
  SampleCalculatorStepDefs in 'SampleCalculatorStepDefs.pas',
  DelphiSpec.Core,
  SampleAccountsStepDefs in 'SampleAccountsStepDefs.pas';

begin
  PrepareDelphiSpecs('features', True, 'EN');
  DUnitTestRunner.RunRegisteredTests;
end.

