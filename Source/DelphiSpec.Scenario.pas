unit DelphiSpec.Scenario;

interface

uses
  SysUtils, Classes, Generics.Collections, DelphiSpec.StepDefinitions, DelphiSpec.Attributes,
  DelphiSpec.DataTable, Rtti;

type
  TScenario = class; // forward declaration
  TScenarioOutline = class; // forward declaration;

  TFeature = class
  private
    FName: string;
    FBackground: TScenario;
    FScenarios: TObjectList<TScenario>;
    FScenarioOutlines: TObjectList<TScenarioOutline>;
    FStepDefsClass: TStepDefinitionsClass;
  public
    constructor Create(const Name: string; StepDefsClass: TStepDefinitionsClass); reintroduce;
    destructor Destroy; override;

    property Background: TScenario read FBackground write FBackground;
    property Name: string read FName;
    property Scenarios: TObjectList<TScenario> read FScenarios;
    property ScenarioOutlines: TObjectList<TScenarioOutline> read FScenarioOutlines;
    property StepDefinitionsClass: TStepDefinitionsClass read FStepDefsClass;
  end;

  EScenarioStepException = class(Exception);
  TScenario = class
  protected type
    TStep = class
    strict private
      FValue: string;
      FDataTable: IDataTable;
      FPyString: string;
    public
      constructor Create(const Value: string; DataTable: IDataTable; const PyString: string); reintroduce;

      property Value: string read FValue;
      property DataTable: IDataTable read FDataTable;
      property PyString: string read FPyString;
    end;
  strict private
    FName: string;
    FFeature: TFeature;

    function ConvertDataTable(DataTable: IDataTable; ParamType: TRttiType): TValue;
    function ConvertParamValue(const Value: string; ParamType: TRttiType): TValue;

    procedure FindStep(Step: TStep; StepDefs: TStepDefinitions; AttributeClass: TDelphiSpecStepAttributeClass);
    function InvokeStep(Step: TStep; StepDefs: TStepDefinitions; AttributeClass: TDelphiSpecStepAttributeClass;
      RttiMethod: TRttiMethod; const Value: string): Boolean;
    function PrepareStep(const Step: string; AttributeClass: TDelphiSpecStepAttributeClass;
      const MethodName: string; const Params: TArray<TRttiParameter>): string;
  protected
    FGiven: TObjectList<TStep>;
    FWhen: TObjectList<TStep>;
    FThen: TObjectList<TStep>;
  public
    constructor Create(Parent: TFeature; const Name: string); reintroduce; virtual;
    destructor Destroy; override;

    procedure AddGiven(const Value: string; DataTable: IDataTable; const PyString: string);
    procedure AddWhen(const Value: string; DataTable: IDataTable; const PyString: string);
    procedure AddThen(const Value: string; DataTable: IDataTable; const PyString: string);

    procedure Execute(StepDefs: TStepDefinitions);

    property Feature: TFeature read FFeature;
    property Name: string read FName;
  end;

  TScenarioOutline = class(TScenario)
  private
    FExamples: IDataTable;
    FScenarios: TObjectList<TScenario>;
    FScenariosReady: Boolean;
    function GetScenarios: TObjectList<TScenario>;
    procedure PrepareScenarios;
  public
    constructor Create(Parent: TFeature; const Name: string); override;
    destructor Destroy; override;

    procedure SetExamples(Examples: IDataTable);

    property Scenarios: TObjectList<TScenario> read GetScenarios;
  end;

implementation

uses
  TypInfo, RegularExpressions, StrUtils, Types;

{ TFeature }

constructor TFeature.Create(const Name: string; StepDefsClass: TStepDefinitionsClass);
begin
  inherited Create;
  FName := Name;
  FBackground := nil;
  FScenarios := TObjectList<TScenario>.Create(True);
  FScenarioOutlines := TObjectList<TScenarioOutline>.Create(True);
  FStepDefsClass := StepDefsClass;
end;

destructor TFeature.Destroy;
begin
  FreeAndNil(FBackground);
  FScenarioOutlines.Free;
  FScenarios.Free;
  inherited;
end;

{ TScenario.TScenarioStep }

constructor TScenario.TStep.Create(const Value: string;
  DataTable: IDataTable; const PyString: string);
begin
  inherited Create;
  FValue := Value;
  FDataTable := DataTable;
  FPyString := PyString;
end;

{ TScenario }

procedure TScenario.AddGiven(const Value: string; DataTable: IDataTable; const PyString: string);
begin
  if Assigned(DataTable) and (PyString <> '') then
    raise EScenarioStepException.Create('Cannot assign both DataTable and PyString to scenario step');

  FGiven.Add(TStep.Create(Value, DataTable, PyString));
end;

procedure TScenario.AddThen(const Value: string; DataTable: IDataTable; const PyString: string);
begin
  if Assigned(DataTable) and (PyString <> '') then
    raise EScenarioStepException.Create('Cannot assign both DataTable and PyString to scenario step');

  FThen.Add(TStep.Create(Value, DataTable, PyString));
end;

procedure TScenario.AddWhen(const Value: string; DataTable: IDataTable; const PyString: string);
begin
  if Assigned(DataTable) and (PyString <> '') then
    raise EScenarioStepException.Create('Cannot assign both DataTable and PyString to scenario step');

  FWhen.Add(TStep.Create(Value, DataTable, PyString));
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
        Values[I] := ConvertParamValue(Trim(Strings[I]), ElementType);
      Result := TValue.FromArray(ParamType.Handle, Values);
    end;
  else
    Result := Value;
  end;
end;

constructor TScenario.Create(Parent: TFeature; const Name: string);
begin
  inherited Create;
  FFeature := Parent;
  FName := Name;

  FGiven := TObjectList<TStep>.Create(True);
  FWhen := TObjectList<TStep>.Create(True);
  FThen := TObjectList<TStep>.Create(True);
end;

function TScenario.ConvertDataTable(DataTable: IDataTable;
  ParamType: TRttiType): TValue;

  function ConvertDataTableToArrayOfRecords(DataTable: IDataTable;
    ElementType: TRttiType): TArray<TValue>;
  var
    I, J: Integer;
    RttiField: TRttiField;
  begin
    SetLength(Result, DataTable.RowCount - 1);

    for I := 0 to DataTable.RowCount - 2 do
    begin
      TValue.Make(nil, ElementType.Handle, Result[I]);
      for J := 0 to DataTable.ColCount - 1 do
      begin
        RttiField := ElementType.AsRecord.GetField(DataTable.Values[J, 0]);
        RttiField.SetValue(Result[I].GetReferenceToRawData,
          ConvertParamValue(DataTable.Values[J, I + 1], RttiField.FieldType));
      end;
    end;
  end;

  function ConvertDataTableToTwoDimArray(DataTable: IDataTable;
    ElementType: TRttiType): TArray<TValue>;
  var
    I, J: Integer;
    ArrayLength: Integer;
  begin
    SetLength(Result, DataTable.RowCount);

    for I := 0 to DataTable.ColCount - 1 do
    begin
      TValue.Make(nil, ElementType.Handle, Result[I]);

      ArrayLength := DataTable.RowCount;
      DynArraySetLength(PPointer(Result[I].GetReferenceToRawData)^, Result[I].TypeInfo, 1, @ArrayLength);
      for J := 0 to DataTable.RowCount - 1 do
        Result[I].SetArrayElement(J,
          ConvertParamValue(DataTable.Values[J, I], (ElementType as TRttiDynamicArrayType).ElementType));
    end;
  end;

var
  Values: TArray<TValue>;
  ElementType: TRttiType;
begin
  ElementType := (ParamType as TRttiDynamicArrayType).ElementType;
  case ElementType.TypeKind of
    TTypeKind.tkRecord:
      Values := ConvertDataTableToArrayOfRecords(DataTable, ElementType);
    TTypeKind.tkDynArray:
      Values := ConvertDataTableToTwoDimArray(DataTable, ElementType);
  end;

  Result := TValue.FromArray(ParamType.Handle, Values);
end;

destructor TScenario.Destroy;
begin
  FGiven.Free;
  FWhen.Free;
  FThen.Free;

  inherited;
end;

procedure TScenario.Execute(StepDefs: TStepDefinitions);
var
  Step: TStep;
begin
  for Step in FGiven do
    FindStep(Step, StepDefs, Given_Attribute);

  for Step in FWhen do
    FindStep(Step, StepDefs, When_Attribute);

  for Step in FThen do
    FindStep(Step, StepDefs, Then_Attribute);
end;

procedure TScenario.FindStep(Step: TStep; StepDefs: TStepDefinitions;
  AttributeClass: TDelphiSpecStepAttributeClass);
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  RttiMethod: TRttiMethod;
  RttiAttr: TCustomAttribute;
begin
  RttiContext := TRttiContext.Create;
  try
    RttiType := RttiContext.GetType(StepDefs.ClassInfo);

    for RttiMethod in RttiType.GetMethods do
    begin
      for RttiAttr in RttiMethod.GetAttributes do
        if RttiAttr is AttributeClass then
          if InvokeStep(Step, StepDefs, AttributeClass, RttiMethod, TDelphiSpecAttribute(RttiAttr).Text) then
            Exit;

      if StartsText(AttributeClass.Prefix, RttiMethod.Name) then
        if InvokeStep(Step, StepDefs, AttributeClass, RttiMethod, '') then
          Exit;
    end;
  finally
    RttiContext.Free;
  end;

  raise EScenarioStepException.CreateFmt('Step is not implemented: "%s" (%s)', [Step.Value, AttributeClass.ClassName]);
end;

function TScenario.InvokeStep(Step: TStep; StepDefs: TStepDefinitions;
  AttributeClass: TDelphiSpecStepAttributeClass; RttiMethod: TRttiMethod;
  const Value: string): Boolean;
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
  if Step.PyString <> '' then
  begin
    SetLength(Values, Length(Values) + 1);
    Values[High(Values)] := Step.PyString;
  end;

  if Length(Params) <> Length(Values) then
    raise EScenarioStepException.CreateFmt('Parameter count does not match: "%s" (%s)', [Step.Value, AttributeClass.ClassName]);

  for I := 0 to RegExMatch.Groups.Count - 2 do
    Values[I] := ConvertParamValue(RegExMatch.Groups[I + 1].Value, Params[I].ParamType);

  RttiMethod.Invoke(StepDefs, Values);
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

{ TScenarioOutline }

constructor TScenarioOutline.Create(Parent: TFeature; const Name: string);
begin
  inherited;
  FScenariosReady := False;
  FExamples := nil;
  FScenarios := TObjectList<TScenario>.Create(True);
end;

destructor TScenarioOutline.Destroy;
begin
  FScenarios.Free;
  inherited;
end;

function TScenarioOutline.GetScenarios: TObjectList<TScenario>;
begin
  if not FScenariosReady then
  begin
    PrepareScenarios;
    FScenariosReady := True;
  end;

  Result := FScenarios;
end;

procedure TScenarioOutline.PrepareScenarios;

  function PutValues(const Step: string; Index: Integer): string;
  var
    I: Integer;
  begin
    Result := Step;

    for I := 0 to FExamples.ColCount - 1 do
      Result := TRegEx.Replace(Result, '<' + FExamples.Values[I, 0] + '>',
        FExamples.Values[I, Index], [TRegExOption.roIgnoreCase]);
  end;

var
  I: Integer;
  Scenario: TScenario;
  Step: TStep;
begin
  for I := 1 to FExamples.RowCount - 1 do
  begin
    Scenario := TScenario.Create(Feature, Name + Format(' [case %d]', [I]));

    for Step in FGiven do
      Scenario.AddGiven(PutValues(Step.Value, I), Step.DataTable, PutValues(Step.PyString, I));

    for Step in FWhen do
      Scenario.AddWhen(PutValues(Step.Value, I), Step.DataTable, PutValues(Step.PyString, I));

    for Step in FThen do
      Scenario.AddThen(PutValues(Step.Value, I), Step.DataTable, PutValues(Step.PyString, I));

    FScenarios.Add(Scenario);
  end;
end;

procedure TScenarioOutline.SetExamples(Examples: IDataTable);
begin
  FExamples := Examples;
end;

end.
