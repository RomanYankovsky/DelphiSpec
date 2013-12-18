program DelphiSpecTest;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}



uses
  DUnitTestRunner,
  VCL.Forms,
  System.IOUtils,
  System.SysUtils,
  SampleCalculator in 'SampleCalculator.pas',
  SampleCalculatorStepDefs in 'SampleCalculatorStepDefs.pas',
  DelphiSpec.Attributes in '..\Source\DelphiSpec.Attributes.pas',
  DelphiSpec.Core in '..\Source\DelphiSpec.Core.pas',
  DelphiSpec.Parser in '..\Source\DelphiSpec.Parser.pas',
  DelphiSpec.Scenario in '..\Source\DelphiSpec.Scenario.pas',
  DelphiSpec.StepDefinitions in '..\Source\DelphiSpec.StepDefinitions.pas';

{R *.RES}

begin
  PrepareDelphiSpecs(TPath.Combine(ExtractFilePath(Application.ExeName), 'features'), True, 'RU');
  DUnitTestRunner.RunRegisteredTests;
end.

