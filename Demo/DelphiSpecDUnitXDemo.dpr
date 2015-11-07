program DelphiSpecDUnitXDemo;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  DelphiSpec.Core,
  DelphiSpec.Scenario,
  DelphiSpec.Parser,
  Generics.Collections,
  DUnitX.AutoDetect.Console,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestRunner,
  DUnitX.TestFramework,
  SampleAccountsStepDefs in 'SampleAccountsStepDefs.pas',
  SampleCalculator in 'SampleCalculator.pas',
  SampleCalculatorStepDefs in 'SampleCalculatorStepDefs.pas',
  SampleSpamFilterStepDefs in 'SampleSpamFilterStepDefs.pas',
  DelphiSpec.DUnitX in '..\Source\DelphiSpec.DUnitX.pas';

var
  runner : ITestRunner;
  results : IRunResults;
  logger : ITestLogger;
  nunitLogger : ITestLogger;
begin
  ReportMemoryLeaksOnShutdown := True;

  try
    RegisterFeaturesWithDUnitX('DunitXDemo', TDelphiSpecParser.GetFeatures);
    //Create the runner
    runner := TDUnitX.CreateRunner;
    runner.UseRTTI := True;
    //tell the runner how we will log things
    logger := TDUnitXConsoleLogger.Create(false);
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create;
    runner.AddLogger(logger);
    runner.AddLogger(nunitLogger);

    //Run tests
    results := runner.Execute;

    {$IFNDEF CI}
      //We don't want this happening when running under CI.
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    {$ENDIF}
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      {$IFNDEF CI}
        //We don't want this happening when running under CI.
        System.Write('Done.. press <Enter> key to quit.');
        System.Readln;
      {$ENDIF}
    end;
  end;
end.
