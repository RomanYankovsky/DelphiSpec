program DelphiSpecDUnitXDemo;

uses
  FMX.Forms,
  DelphiSpec.Parser,
  DelphiSpec.DUnitX,
  {$IF Defined(MSWINDOWS) or (Defined(MACOS) and not Defined(IOS))}
  DUnitX.Loggers.GUIX,
  {$ELSE}
  DUnitX.Loggers.MobileGUI,
  {$ENDIF }
  TestAccounts in 'TestAccounts.pas',
  SampleCalculator in 'SampleCalculator.pas',
  TestCalculator in 'TestCalculator.pas',
  TestSpamFilter in 'TestSpamFilter.pas';

{$R *.res}

begin
  RegisterFeaturesWithDUnitX('DunitXDemo', TDelphiSpecParser.GetFeatures);

  Application.Initialize;
{$IF Defined(MSWINDOWS) or (Defined(MACOS) and not Defined(IOS))}
  Application.CreateForm(TGUIXTestRunner, GUIXTestRunner);
{$ELSE}
  Application.CreateForm(TMobileGUITestRunner, MobileGUITestRunner);
  {$ENDIF}
  Application.Run;
end.
