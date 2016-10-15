unit DelphiSpec.Scenario;

interface

uses
  SysUtils, Classes, Generics.Collections, DelphiSpec.StepDefinitions, DelphiSpec.Attributes,
  DelphiSpec.DataTable, Rtti;

type
  TFeature = class; // forward declaration
  TScenario = class; // forward declaration
  TScenarioOutline = class; // forward declaration;

  TFeatureList = class(TObjectList<TFeature>);
  TScenarioList = class(TObjectList<TScenario>);
  TScenarioOutlineList = class(TObjectList<TScenarioOutline>);

  TValueArray = TArray<TValue>;

  TFeature = class
  private
    FName: string;
    FSource: TStringList;
    FClassName: String;
    FBackground: TScenario;
    FScenarios: TScenarioList;
    FScenarioOutlines: TScenarioOutlineList;
    FStepDefsClass: TStepDefinitionsClass;
  public
    constructor Create(const Name, ClassName: string; StepDefsClass: TStepDefinitionsClass); reintroduce;
    destructor Destroy; override;

    property Source: TStringList read FSource;
    property Background: TScenario read FBackground write FBackground;
    property FeatureClassName: String read FClassName;
    property Name: string read FName;
    property Scenarios: TScenarioList read FScenarios;
    property ScenarioOutlines: TScenarioOutlineList read FScenarioOutlines;
    property StepDefinitionsClass: TStepDefinitionsClass read FStepDefsClass;
  end;

  EScenarioStepException = class(Exception);
  TScenario = class
  private
    FUserObject: TObject;
  public type
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

    TStepList = class(TObjectList<TStep>);
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
    procedure SetUserObject(Value: TObject);
  protected
    FGiven: TStepList;
    FWhen: TStepList;
    FThen: TStepList;
  public
    constructor Create(Parent: TFeature; const Name: string); reintroduce; virtual;
    destructor Destroy; override;

    procedure AddGiven(const Value: string; DataTable: IDataTable; const PyString: string);
    procedure AddWhen(const Value: string; DataTable: IDataTable; const PyString: string);
    procedure AddThen(const Value: string; DataTable: IDataTable; const PyString: string);

    procedure Execute(StepDefs: TStepDefinitions);

    property GivenSteps: TStepList read FGiven;
    property WhenSteps: TStepList read FWhen;
    property ThenSteps: TStepList read FThen;
    property Feature: TFeature read FFeature;
    property Name: string read FName;
    property UserObject: TObject read FUserObject write SetUserObject;
  end;

  TScenarioOutline = class(TScenario)
  private
    FExamples: IDataTable;
    FScenarios: TScenarioList;
    FScenariosReady: Boolean;
    function GetScenarios: TScenarioList;
    procedure PrepareScenarios;
  public
    constructor Create(Parent: TFeature; const Name: string); override;
    destructor Destroy; override;

    procedure SetExamples(Examples: IDataTable);

    property Examples: IDataTable read FExamples;
    property Scenarios: TScenarioList read GetScenarios;
  end;

implementation

uses
  TypInfo, RegularExpressions, StrUtils, Types;

{ TFeature }

constructor TFeature.Create(const Name, ClassName: string; StepDefsClass: TStepDefinitionsClass);
begin
  inherited Create;
  FSource := TStringList.Create;
  FName := Name;
  FClassName := ClassName;
  FBackground := nil;
  FScenarios := TScenarioList.Create(True);
  FScenarioOutlines := TScenarioOutlineList.Create(True);
  FStepDefsClass := StepDefsClass;
end;

destructor TFeature.Destroy;
begin
  FSource.Free;
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
  Values: TValueArray;
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

  FGiven := TStepList.Create(True);
  FWhen := TStepList.Create(True);
  FThen := TStepList.Create(True);
end;

function TScenario.ConvertDataTable(DataTable: IDataTable;
  ParamType: TRttiType): TValue;

  function ConvertDataTableToArrayOfRecords(DataTable: IDataTable;
    ElementType: TRttiType): TValueArray;
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
    ElementType: TRttiType): TValueArray;
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
          ConvertParamValue(DataTable.Values[I, J], (ElementType as TRttiDynamicArrayType).ElementType));
    end;
  end;

  function ConvertDataTableToArray(DataTable: IDataTable;
    ElementType: TRttiType): TValueArray;
  var
    I, J, K: Integer;
    ArrayLength: Integer;
  begin
    ArrayLength := DataTable.RowCount * DataTable.ColCount;
    SetLength(Result, ArrayLength);

    K := 0;
    for J := 0 to DataTable.RowCount - 1 do
    begin
      for I := 0 to DataTable.ColCount - 1 do
      begin
        Result[K] := ConvertParamValue(DataTable.Values[I, J], ElementType);
        Inc(K);
      end;
    end;
  end;

var
  Values: TValueArray;
  ElementType: TRttiType;
begin
  ElementType := (ParamType as TRttiDynamicArrayType).ElementType;
  case ElementType.TypeKind of
    TTypeKind.tkRecord:
      Values := ConvertDataTableToArrayOfRecords(DataTable, ElementType);
    TTypeKind.tkDynArray:
      Values := ConvertDataTableToTwoDimArray(DataTable, ElementType);
    else
      Values := ConvertDataTableToArray(DataTable, ElementType);
  end;

  Result := TValue.FromArray(ParamType.Handle, Values);
end;

destructor TScenario.Destroy;
begin
  FUserObject.Free;
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
  Values: TValueArray;
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
  ParamName: String;
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
      begin
        ParamName := ReplaceStr(Params[I].Name, '_', ' ');
        Result := TRegEx.Replace(Result,
          '\b' + ParamName + '\b', '$' + Params[I].Name,
          [TRegExOption.roIgnoreCase]);
      end;
    end;
  end;
  Result := TRegEx.Replace(Result, '(\$[a-zA-Z0-9_]*)', '(.*)');
end;

procedure TScenario.SetUserObject(Value: TObject);
begin
  FreeAndNil(FUserObject);
  FUserObject := Value;
end;

{ TScenarioOutline }

constructor TScenarioOutline.Create(Parent: TFeature; const Name: string);
begin
  inherited;
  FScenariosReady := False;
  FExamples := nil;
  FScenarios := TScenarioList.Create(True);
end;

destructor TScenarioOutline.Destroy;
begin
  FScenarios.Free;
  inherited;
end;

function TScenarioOutline.GetScenarios: TScenarioList;
begin
  if not FScenariosReady then
  begin
    PrepareScenarios;
    FScenariosReady := True;
  end;

  Result := FScenarios;
end;

procedure TScenarioOutline.PrepareScenarios;

  function PutValues(const Step: string; Index: Integer): string; overload;
  var
    I: Integer;
  begin
    Result := Step;

    for I := 0 to FExamples.ColCount - 1 do
      Result := TRegEx.Replace(Result, '<' + FExamples.Values[I, 0] + '>',
        FExamples.Values[I, Index], [TRegExOption.roIgnoreCase]);
  end;

  function PutValues(const DataTable: IDataTable; Index: Integer): IDataTable; overload;
  var
    Row, Column: Integer;
    Data: TStringDynArray;
    NewTable: TDataTable;
  begin
    Result := nil;
    if Assigned(DataTable) then
    begin
      NewTable := TDataTable.Create(DataTable.ColCount);
      SetLength(Data, DataTable.ColCount);

      for Row := 0 to DataTable.RowCount - 1 do
      begin
        for Column := 0 to DataTable.ColCount - 1 do
          Data[Column] := PutValues(DataTable.Values[Column, Row], Index);

        NewTable.AddRow(Data);
      end;

      Result := NewTable;
    end;
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
      Scenario.AddGiven(PutValues(Step.Value, I),
        PutValues(Step.DataTable, I), PutValues(Step.PyString, I));

    for Step in FWhen do
      Scenario.AddWhen(PutValues(Step.Value, I),
        PutValues(Step.DataTable, I), PutValues(Step.PyString, I));

    for Step in FThen do
      Scenario.AddThen(PutValues(Step.Value, I),
        PutValues(Step.DataTable, I), PutValues(Step.PyString, I));

    FScenarios.Add(Scenario);
  end;
end;

procedure TScenarioOutline.SetExamples(Examples: IDataTable);
begin
  FExamples := Examples;
end;

end.
