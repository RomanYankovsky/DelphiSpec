program DelphiSpecTest;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  SampleCalculator in 'SampleCalculator.pas',
  SampleCalculatorStepDefs in 'SampleCalculatorStepDefs.pas',
  SampleAccountsStepDefs in 'SampleAccountsStepDefs.pas',
  Generics.Collections,
  DelphiSpec.Core,
  DelphiSpec.Scenario,
  DelphiSpec.DUnit;

var
  Features: TObjectList<TFeature>;
begin
  Features := ReadFeatures('features', True, 'EN');
  try
    CreateDUnitTests(Features);
    DUnitTestRunner.RunRegisteredTests;
  finally
    Features.Free;
  end;
end.

