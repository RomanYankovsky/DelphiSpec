unit DelphiSpec.Scenario;

interface

uses
  System.SysUtils, System.Classes, DelphiSpec.StepDefinitions, DelphiSpec.Attributes,
  System.Rtti;

type
  EScenarioException = class(Exception);
  TScenario = class
  private
    FName: string;
    FStepDefs: TStepDefinitions;

    FGiven: TStringList;
    FWhen: TStringList;
    FThen: TStringList;

    function ConvertParamValue(const Value: string; ParamType: TRttiType): TValue;
    procedure InvokeStep(const Step: string; AttributeClass: TDelphiSpecAttributeClass);
  public
    constructor Create(const Name: string; StepDefinitionsClass: TStepDefinitionsClass); reintroduce;
    destructor Destroy; override;

    procedure AddGiven(const Value: string);
    procedure AddWhen(const Value: string);
    procedure AddThen(const Value: string);

    procedure Execute;

    property Name: string read FName;
  end;

implementation

uses
  System.TypInfo, System.RegularExpressions, TestFramework;

{ TScenario }

procedure TScenario.AddGiven(const Value: string);
begin
  FGiven.Add(Value);
end;

procedure TScenario.AddThen(const Value: string);
begin
  FThen.Add(Value);
end;

procedure TScenario.AddWhen(const Value: string);
begin
  FWhen.Add(Value);
end;

function TScenario.ConvertParamValue(const Value: string;
  ParamType: TRttiType): TValue;
begin
  case ParamType.TypeKind of
    TTypeKind.tkInteger: Result := StrToInt(Value);
    TTypeKind.tkInt64: Result := StrToInt64(Value);
    else
      Result := Value;
  end;
end;

constructor TScenario.Create(const Name: string;
  StepDefinitionsClass: TStepDefinitionsClass);
begin
  inherited Create;
  FName := Name;
  FStepDefs := StepDefinitionsClass.Create;

  FGiven := TStringList.Create;
  FWhen := TStringList.Create;;
  FThen := TStringList.Create;
end;

destructor TScenario.Destroy;
begin
  FStepDefs.Free;

  FGiven.Free;
  FWhen.Free;
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

    for Command in FWhen do
      InvokeStep(Command, _WhenAttribute);

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

  Params: TArray<TRttiParameter>;
  Values: TArray<TValue>;

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

          SetLength(Values, RegExMatch.Groups.Count - 1);
          Params := RttiMethod.GetParameters;

          if Length(Params) <> Length(Values) then
            raise EScenarioException.CreateFmt('Parameter count does not match: "%s" (%s)', [Step, AttributeClass.ClassName]);

          for I := 0 to High(Params) do
            Values[I] := ConvertParamValue(RegExMatch.Groups[I + 1].Value, Params[I].ParamType);

          RttiMethod.Invoke(FStepDefs, Values);

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
    raise ETestFailure.CreateFmt('Step is not implemented yet: "%s" (%s)', [Step, AttributeClass.ClassName]);
end;

end.
