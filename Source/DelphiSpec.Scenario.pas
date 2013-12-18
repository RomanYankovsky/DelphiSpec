unit DelphiSpec.Scenario;

interface

uses
  System.SysUtils, System.Classes, DelphiSpec.StepDefinitions, DelphiSpec.Attributes;

type
  EScenarioException = class(Exception);
  TScenario = class
  private
    FName: string;
    FStepDefs: TStepDefinitions;

    FGiven: TStringList;
    FWhen: string;
    FThen: TStringList;

    procedure InvokeStep(const Step: string; AttributeClass: TDelphiSpecAttributeClass);
  public
    constructor Create(const Name: string; StepDefinitionsClass: TStepDefinitionsClass); reintroduce;
    destructor Destroy; override;

    procedure AddGiven(const Value: string);
    procedure SetWhen(const Value: string);
    procedure AddThen(const Value: string);

    procedure Execute;

    property Name: string read FName;
  end;

implementation

uses
  System.Rtti, System.RegularExpressions;

{ TScenario }

procedure TScenario.AddGiven(const Value: string);
begin
  FGiven.Add(Value);
end;

procedure TScenario.AddThen(const Value: string);
begin
  FThen.Add(Value);
end;

constructor TScenario.Create(const Name: string;
  StepDefinitionsClass: TStepDefinitionsClass);
begin
  inherited Create;
  FName := Name;
  FStepDefs := StepDefinitionsClass.Create;

  FGiven := TStringList.Create;
  FWhen := '';
  FThen := TStringList.Create;
end;

destructor TScenario.Destroy;
begin
  FStepDefs.Free;

  FGiven.Free;
  FThen.Free;

  inherited;
end;

procedure TScenario.Execute;
var
  Command: string;
begin
  FStepDefs.SetUp;
  try
    for Command in FGiven do
      InvokeStep(Command, _GivenAttribute);

    InvokeStep(FWhen, _WhenAttribute);

    for Command in FThen do
      InvokeStep(Command, _ThenAttribute);
  finally
    FStepDefs.TearDown;
  end;
end;

procedure TScenario.InvokeStep(const Step: string; AttributeClass: TDelphiSpecAttributeClass);
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  RttiMethod: TRttiMethod;
  RttiAttr: TCustomAttribute;

  RegExMatch: TMatch;
  I: Integer;
  Params: array of TValue;

  MethodInvoked: Boolean;
begin
  MethodInvoked := False;

  RttiContext := TRttiContext.Create;
  try
    RttiType := RttiContext.GetType(FStepDefs.ClassInfo);

    for RttiMethod in RttiType.GetMethods do
    begin
      for RttiAttr in RttiMethod.GetAttributes do
        if RttiAttr is AttributeClass then
        begin
          RegExMatch := TRegEx.Match(Step, TDelphiSpecAttribute(RttiAttr).Text,
            [TRegExOption.roIgnoreCase]);

          if not RegExMatch.Success then
            Continue;

          SetLength(Params, RegExMatch.Groups.Count - 1);
          for I := 1 to RegExMatch.Groups.Count - 1 do
            Params[I - 1] := RegExMatch.Groups[I].Value;

          RttiMethod.Invoke(FStepDefs, Params);

          MethodInvoked := True;
          Break;
        end;
      if MethodInvoked then
        Break;
    end;
  finally
    RttiContext.Free;
  end;

  if not MethodInvoked then
    raise EScenarioException.CreateFmt('Cannot resolve "%s" (%s)', [Step, AttributeClass.ClassName]);
end;

procedure TScenario.SetWhen(const Value: string);
begin
  FWhen := Value;
end;

end.
