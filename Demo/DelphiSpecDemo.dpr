program DelphiSpecDemo;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

{$R DelphiSpecI18n.res DelphiSpecI18n.rc}

uses
  DUnitTestRunner,
  SampleCalculator in 'SampleCalculator.pas',
  SampleCalculatorStepDefs in 'SampleCalculatorStepDefs.pas',
  SampleAccountsStepDefs in 'SampleAccountsStepDefs.pas',
  SampleSpamFilterStepDefs in 'SampleSpamFilterStepDefs.pas',
  Generics.Collections,
  DelphiSpec.Core,
  DelphiSpec.Scenario,
  DelphiSpec.DUnit;

var
  Features: TFeatureList;
begin
  ReportMemoryLeaksOnShutdown := True;

  Features := ReadFeatures('features', True, 'EN');
  try
    CreateDUnitTests(Features);
    DUnitTestRunner.RunRegisteredTests;
  finally
    Features.Free;
  end;
end.

