unit DelphiSpec.Scenario;

interface

uses
  SysUtils, Classes, DelphiSpec.StepDefinitions, DelphiSpec.Attributes,
  Rtti;

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
    procedure FindStep(const Step: string; AttributeClass: TDelphiSpecStepAttributeClass);
    function InvokeStep(const Step: string; AttributeClass: TDelphiSpecStepAttributeClass;
      RttiMethod: TRttiMethod; const Value: string): Boolean;
    function PrepareStep(const Step: string; AttributeClass: TDelphiSpecStepAttributeClass;
      const MethodName: string; const Params: TArray<TRttiParameter>): string;
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
  TypInfo, RegularExpressions, TestFramework, StrUtils, Types;

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
const
  Delimiter = ',';
var
  Strings: TStringDynArray;
  Values: TArray<TValue>;
  I: Integer;
  ElementType: TRttiType;
begin
  case ParamType.TypeKind of
    TTypeKind.tkInteger: Result := StrToInt(Value);
    TTypeKind.tkInt64: Result := StrToInt64(Value);
    TTypeKind.tkEnumeration:
      Result := TValue.FromOrdinal(ParamType.Handle, GetEnumValue(ParamType.Handle, Value));
    TTypeKind.tkDynArray:
    begin
      Strings := SplitString(Value, Delimiter);
      SetLength(Values, Length(Strings));
      ElementType := (ParamType as TRttiDynamicArrayType).ElementType;
      for I := Low(Strings) to High(Strings) do
        Values[i] := ConvertParamValue(Trim(Strings[I]), ElementType);
      Result := TValue.FromArray(ParamType.Handle, Values);
    end;
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
      FindStep(Command, Given_Attribute);

    for Command in FWhen do
      FindStep(Command, When_Attribute);

    for Command in FThen do
      FindStep(Command, Then_Attribute);
  finally
    FStepDefs.TearDown;
  end;
end;

procedure TScenario.FindStep(const Step: string; AttributeClass: TDelphiSpecStepAttributeClass);
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  RttiMethod: TRttiMethod;
  RttiAttr: TCustomAttribute;
begin
  RttiContext := TRttiContext.Create;
  try
    RttiType := RttiContext.GetType(FStepDefs.ClassInfo);

    for RttiMethod in RttiType.GetMethods do
    begin
      for RttiAttr in RttiMethod.GetAttributes do
        if RttiAttr is AttributeClass then
          if InvokeStep(Step, AttributeClass, RttiMethod, TDelphiSpecAttribute(RttiAttr).Text) then
            Exit;

      if StartsText(AttributeClass.Prefix, RttiMethod.Name) then
        if InvokeStep(Step, AttributeClass, RttiMethod, '') then
          Exit;
    end;
  finally
    RttiContext.Free;
  end;

  raise ETestFailure.CreateFmt('Step is not implemented yet: "%s" (%s)', [Step, AttributeClass.ClassName]);
end;

function TScenario.InvokeStep(const Step: string; AttributeClass: TDelphiSpecStepAttributeClass;
  RttiMethod: TRttiMethod; const Value: string): Boolean;
var
  RegExMatch: TMatch;
  I: Integer;
  S: string;
  Params: TArray<TRttiParameter>;
  Values: TArray<TValue>;
begin
  Params := RttiMethod.GetParameters;
  S := PrepareStep(Value, AttributeClass, RttiMethod.Name, Params);
  RegExMatch := TRegEx.Match(Step, S, [TRegExOption.roIgnoreCase]);
  if not RegExMatch.Success then
    Exit(False);

  SetLength(Values, RegExMatch.Groups.Count - 1);
  if Length(Params) <> Length(Values) then
    raise EScenarioException.CreateFmt('Parameter count does not match: "%s" (%s)', [Step, AttributeClass.ClassName]);

  for I := 0 to High(Params) do
    Values[I] := ConvertParamValue(RegExMatch.Groups[I + 1].Value, Params[I].ParamType);

  RttiMethod.Invoke(FStepDefs, Values);
  Result := True;
end;

function TScenario.PrepareStep(const Step: string; AttributeClass: TDelphiSpecStepAttributeClass;
  const MethodName: string; const Params: TArray<TRttiParameter>): string;
var
  I: Integer;
  Prefix: string;
begin
  Result := Step;
  if Result = '' then
  begin
    Prefix := AttributeClass.Prefix;
    if StartsText(Prefix, MethodName) then
    begin
      Result := RightStr(MethodName, Length(MethodName) - Length(Prefix));
      Result := ReplaceStr(Result, '_', ' ');
      for I := 0 to High(Params) do
        Result := TRegEx.Replace(Result, '\b' + Params[I].Name + '\b', '$' + Params[I].Name, [TRegExOption.roIgnoreCase]);
    end;
  end;
  Result := TRegEx.Replace(Result, '(\$[a-zA-Z0-9_]*)', '(.*)');
end;

end.
