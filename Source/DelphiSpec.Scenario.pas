unit DelphiSpec.Scenario;

interface

uses
  SysUtils, Classes, Generics.Collections, DelphiSpec.StepDefinitions, DelphiSpec.Attributes,
  DelphiSpec.DataTable, Rtti;

type
  EScenarioException = class(Exception);
  TScenario = class
  private type
    TStep = class
    strict private
      FValue: string;
      FDataTable: IDelphiSpecDataTable;
    public
      constructor Create(const Value: string; DataTable: IDelphiSpecDataTable); reintroduce;

      property Value: string read FValue;
      property DataTable: IDelphiSpecDataTable read FDataTable;
    end;
  private
    FName: string;
    FStepDefs: TStepDefinitions;

    FGiven: TObjectList<TStep>;
    FWhen: TObjectList<TStep>;
    FThen: TObjectList<TStep>;

    function ConvertDataTable(DataTable: IDelphiSpecDataTable; ParamType: TRttiType): TValue;
    function ConvertParamValue(const Value: string; ParamType: TRttiType): TValue;

    procedure FindStep(Step: TStep; AttributeClass: TDelphiSpecStepAttributeClass);
    function InvokeStep(Step: TStep; AttributeClass: TDelphiSpecStepAttributeClass;
      RttiMethod: TRttiMethod; const Value: string): Boolean;
    function PrepareStep(const Step: string; AttributeClass: TDelphiSpecStepAttributeClass;
      const MethodName: string; const Params: TArray<TRttiParameter>): string;
  public
    constructor Create(const Name: string; StepDefinitionsClass: TStepDefinitionsClass); reintroduce;
    destructor Destroy; override;

    procedure AddGiven(const Value: string; DataTable: IDelphiSpecDataTable);
    procedure AddWhen(const Value: string; DataTable: IDelphiSpecDataTable);
    procedure AddThen(const Value: string; DataTable: IDelphiSpecDataTable);

    procedure Execute;

    property Name: string read FName;
  end;

implementation

uses
  TypInfo, RegularExpressions, TestFramework, StrUtils, Types;

{ TScenario.TScenarioStep }

constructor TScenario.TStep.Create(const Value: string;
  DataTable: IDelphiSpecDataTable);
begin
  inherited Create;
  FValue := Value;
  FDataTable := DataTable;
end;

{ TScenario }

procedure TScenario.AddGiven(const Value: string; DataTable: IDelphiSpecDataTable);
begin
  FGiven.Add(TStep.Create(Value, DataTable));
end;

procedure TScenario.AddThen(const Value: string; DataTable: IDelphiSpecDataTable);
begin
  FThen.Add(TStep.Create(Value, DataTable));
end;

procedure TScenario.AddWhen(const Value: string; DataTable: IDelphiSpecDataTable);
begin
  FWhen.Add(TStep.Create(Value, DataTable));
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

  FGiven := TObjectList<TStep>.Create(True);
  FWhen := TObjectList<TStep>.Create(True);
  FThen := TObjectList<TStep>.Create(True);
end;

function TScenario.ConvertDataTable(DataTable: IDelphiSpecDataTable;
  ParamType: TRttiType): TValue;
var
  I: Integer;
  RttiField: TRttiField;
  Values: TArray<TValue>;
  TmpArr: packed array of Byte;
  ElementType: TRttiType;
begin
  ElementType := (ParamType as TRttiDynamicArrayType).ElementType;
  SetLength(TmpArr, ElementType.TypeSize);

  SetLength(Values, DataTable.Count);
  for I := 0 to DataTable.Count - 1 do
  begin
    TValue.Make(@TmpArr[0], ElementType.Handle, Values[I]);
    for RttiField in ElementType.AsRecord.GetDeclaredFields do
      RttiField.SetValue(Values[I].GetReferenceToRawData, ConvertParamValue(DataTable[RttiField.Name][I], RttiField.FieldType));
  end;

  Result := TValue.FromArray(ParamType.Handle, Values);
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
  Step: TStep;
begin
  FStepDefs.SetUp;
  try
    for Step in FGiven do
      FindStep(Step, Given_Attribute);

    for Step in FWhen do
      FindStep(Step, When_Attribute);

    for Step in FThen do
      FindStep(Step, Then_Attribute);
  finally
    FStepDefs.TearDown;
  end;
end;

procedure TScenario.FindStep(Step: TStep; AttributeClass: TDelphiSpecStepAttributeClass);
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

function TScenario.InvokeStep(Step: TStep; AttributeClass: TDelphiSpecStepAttributeClass;
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
  RegExMatch := TRegEx.Match(Step.Value, S, [TRegExOption.roIgnoreCase]);
  if not RegExMatch.Success then
    Exit(False);

  SetLength(Values, RegExMatch.Groups.Count - 1);
  if Assigned(Step.DataTable) then
  begin
    SetLength(Values, Length(Values) + 1);
    Values[High(Values)] := ConvertDataTable(Step.DataTable, Params[High(Params)].ParamType);
  end;

  if Length(Params) <> Length(Values) then
    raise EScenarioException.CreateFmt('Parameter count does not match: "%s" (%s)', [Step.Value, AttributeClass.ClassName]);

  for I := 0 to RegExMatch.Groups.Count - 2 do
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
