program DelphiSpecTest;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  SampleCalculator in 'SampleCalculator.pas',
  SampleCalculatorStepDefs in 'SampleCalculatorStepDefs.pas',
  DelphiSpec.Core;

begin
  PrepareDelphiSpecs('features', True, 'EN');
  DUnitTestRunner.RunRegisteredTests;
end.

