unit DelphiSpec.Test.Scenario;

interface

uses
  TestFramework, DelphiSpec.Scenario, DelphiSpec.StepDefinitions,
  DelphiSpec.DataTable, SysUtils, DelphiSpec.Attributes;

type
  TCustomTestStepsClass = class of TCustomTestSteps;
  TCustomTestSteps = class(TStepDefinitions)
  private
    function GetTestPassed: Boolean;
  protected
    FTestPassed: Boolean;
    FSomeRandomProcCalled: Boolean;
    procedure SetTestPassed;
  public
    procedure SetUp; override;
    procedure SomeRandomProc;
    property TestPassed: Boolean read GetTestPassed;
  end;

  TGivenStepsWithoutAttr = class(TCustomTestSteps)
  public
    procedure Given_I_want_to_test_it;
  end;

  TGivenStepsWithAttr = class(TCustomTestSteps)
  public
    [Given_('I want to test it')]
    procedure TestIt;
  end;

  TWhenStepsWithoutAttr = class(TCustomTestSteps)
  public
    procedure When_I_want_to_test_it;
  end;

  TWhenStepsWithAttr = class(TCustomTestSteps)
  public
    [When_('I want to test it')]
    procedure TestIt;
  end;

  TThenStepsWithoutAttr = class(TCustomTestSteps)
  public
    procedure Then_I_want_to_test_it;
  end;

  TThenStepsWithAttr = class(TCustomTestSteps)
  public
    [Then_('I want to test it')]
    procedure TestIt;
  end;

  TTestParamSteps = class(TCustomTestSteps)
  private type
    TTableRow = record
      Key: Integer;
      Value: string;
    end;
  public
    [Then_('the array is (.*)')]
    procedure TestArray(Value: TArray<Integer>);

    [Then_('PyString is')]
    [Then_('the string is (.*)')]
    procedure TestStr(const Value: string);

    [Then_('Table is')]
    procedure TestTable(Value: TArray<TTableRow>);

    [Then_('Two dim array is')]
    procedure TestTwoDimArray(Value: TArray<TArray<Integer>>);

    procedure Given_I_have_N_apples(const N: Integer);

    [Then_('I have $M apples')]
    procedure TestNamedParameter(const M: Integer);
  end;

type
  Test_TScenario = class(TTestCase)
  strict private
    FScenario: TScenario;
  private
    procedure AddStepAndCheckExecute(StepDefsClass: TCustomTestStepsClass;
      Attr: TDelphiSpecStepAttributeClass; const StepText: string;
      const PyString: string = ''; DataTable: IDataTable = nil);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Test_AddGiven_WithoutAttribute;
    procedure Test_AddGiven_WithAttribute;
    procedure Test_AddWhen_WithoutAttribute;
    procedure Test_AddWhen_WithAttribute;
    procedure Test_AddThen_WithoutAttribute;
    procedure Test_AddThen_WithAttribute;

    procedure Test_ArrayParameter;
    procedure Test_StringParameter;
    procedure Test_PyStringParameter;
    procedure Test_DataTableParameter;

    procedure Test_NamedParameterInMethodName;
    procedure Test_NamedParameterWithDollarSign;
  end;

const
  SimpleStepText = 'I want to test it';
  ArrayParamStepText = 'the array is 4,5,6';
  StringParamStepText = 'the string is test string';
  PyStrParamStepText = 'PyString is:';
  TableParamStepText = 'Table is:';
  NamedParamStepText = 'I have 3 apples';
  TwoDimArrayParamStepText = 'Two dim array is:';

implementation

procedure Test_TScenario.SetUp;
begin
  FScenario := TScenario.Create(nil, '');
end;

procedure Test_TScenario.TearDown;
begin
  FScenario.Free;
  FScenario := nil;
end;

procedure Test_TScenario.Test_AddGiven_WithAttribute;
begin
  AddStepAndCheckExecute(TGivenStepsWithAttr, Given_Attribute, SimpleStepText);
end;

procedure Test_TScenario.Test_AddGiven_WithoutAttribute;
begin
  AddStepAndCheckExecute(TGivenStepsWithoutAttr, Given_Attribute, SimpleStepText);
end;

procedure Test_TScenario.Test_AddWhen_WithAttribute;
begin
  AddStepAndCheckExecute(TWhenStepsWithAttr, When_Attribute, SimpleStepText);
end;

procedure Test_TScenario.Test_AddWhen_WithoutAttribute;
begin
  AddStepAndCheckExecute(TWhenStepsWithoutAttr, When_Attribute, SimpleStepText);
end;

procedure Test_TScenario.Test_ArrayParameter;
begin
  AddStepAndCheckExecute(TTestParamSteps, Then_Attribute, ArrayParamStepText);
end;

procedure Test_TScenario.Test_DataTableParameter;
var
  Table: TDataTable;
begin
  Table := TDataTable.Create(2);
  Table.AddRow(['key', 'value']);
  Table.AddRow(['1', 'a']);
  Table.AddRow(['2', 'b']);

  AddStepAndCheckExecute(TTestParamSteps, Then_Attribute, TableParamStepText, '', Table);

  Table := TDataTable.Create(2);
  Table.AddRow(['0', '1']);
  Table.AddRow(['2', '3']);

  AddStepAndCheckExecute(TTestParamSteps, Then_Attribute, TwoDimArrayParamStepText, '', Table);
end;

procedure Test_TScenario.Test_NamedParameterInMethodName;
begin
  AddStepAndCheckExecute(TTestParamSteps, Given_Attribute, NamedParamStepText);
end;

procedure Test_TScenario.Test_NamedParameterWithDollarSign;
begin
  AddStepAndCheckExecute(TTestParamSteps, Then_Attribute, NamedParamStepText);
end;

procedure Test_TScenario.Test_PyStringParameter;
begin
  AddStepAndCheckExecute(TTestParamSteps, Then_Attribute, PyStrParamStepText, 'test string');
end;

procedure Test_TScenario.Test_StringParameter;
begin
  AddStepAndCheckExecute(TTestParamSteps, Then_Attribute, StringParamStepText);
end;

procedure Test_TScenario.Test_AddThen_WithAttribute;
begin
  AddStepAndCheckExecute(TThenStepsWithAttr, Then_Attribute, SimpleStepText);
end;

procedure Test_TScenario.Test_AddThen_WithoutAttribute;
begin
  AddStepAndCheckExecute(TThenStepsWithoutAttr, Then_Attribute, SimpleStepText);
end;

procedure Test_TScenario.AddStepAndCheckExecute(StepDefsClass: TCustomTestStepsClass;
  Attr: TDelphiSpecStepAttributeClass; const StepText: string; const PyString: string = '';
  DataTable: IDataTable = nil);
var
  StepDefs: TCustomTestSteps;
begin
  if Attr = Given_Attribute then
    FScenario.AddGiven(StepText, DataTable, PyString);
  if Attr = When_Attribute then
    FScenario.AddWhen(StepText, DataTable, PyString);
  if Attr = Then_Attribute then
    FScenario.AddThen(StepText, DataTable, PyString);

  StepDefs := StepDefsClass.Create;
  try
    StepDefs.SetUp;
    FScenario.Execute(StepDefs);
    StepDefs.TearDown;

    Check(StepDefs.TestPassed, Format('"%s" definition has not been executed.', [Attr.Prefix]));
  finally
    StepDefs.Free;
  end;
end;

{ TCustomStepDefinitions }

function TCustomTestSteps.GetTestPassed: Boolean;
begin
  Result := FTestPassed and not FSomeRandomProcCalled;
end;

procedure TCustomTestSteps.SetTestPassed;
begin
  FTestPassed := True;
end;

procedure TCustomTestSteps.SetUp;
begin
  FTestPassed := False;
  FSomeRandomProcCalled := False;
end;

procedure TCustomTestSteps.SomeRandomProc;
begin
  FSomeRandomProcCalled := True;
end;

{ TGivenStepsWithoutAttr }

procedure TGivenStepsWithoutAttr.Given_I_want_to_test_it;
begin
  SetTestPassed;
end;

{ TGivenStepsWithAttr }

procedure TGivenStepsWithAttr.TestIt;
begin
  SetTestPassed;
end;

{ TWhenStepsWithAttr }

procedure TWhenStepsWithAttr.TestIt;
begin
  SetTestPassed;
end;

{ TWhenStepsWithoutAttr }

procedure TWhenStepsWithoutAttr.When_I_want_to_test_it;
begin
  SetTestPassed;
end;

{ TThenStepsWithAttr }

procedure TThenStepsWithAttr.TestIt;
begin
  SetTestPassed;
end;

{ TThenStepsWithoutAttr }

procedure TThenStepsWithoutAttr.Then_I_want_to_test_it;
begin
  SetTestPassed;
end;

{ TTestParamSteps }

procedure TTestParamSteps.Given_I_have_N_apples(const N: Integer);
begin
  if N = 3 then
    SetTestPassed;
end;

procedure TTestParamSteps.TestArray(Value: TArray<Integer>);
begin
  if (Length(Value) = 3) and (Value[0] = 4) and (Value[1] = 5) and (Value[2] = 6) then
    SetTestPassed;
end;

procedure TTestParamSteps.TestNamedParameter(const M: Integer);
begin
  if M = 3 then
    SetTestPassed;
end;

procedure TTestParamSteps.TestStr(const Value: string);
begin
  if SameText(Value, 'test string') then
    SetTestPassed;
end;

procedure TTestParamSteps.TestTable(Value: TArray<TTableRow>);
begin
  if (Length(Value) = 2)
    and (Value[0].Key = 1) and (Value[1].Key = 2)
    and (Value[0].Value = 'a') and (Value[1].Value = 'b') then

      SetTestPassed;
end;

procedure TTestParamSteps.TestTwoDimArray(Value: TArray<TArray<Integer>>);
begin
  if (Length(Value) = 2) and (Length(Value[0]) = 2)
    and (Value[0][0] = 0) and (Value[0][1] = 1)
    and (Value[1][0] = 2) and (Value[1][1] = 3) then

      SetTestPassed;
end;

initialization
  RegisterTest(Test_TScenario.Suite);

end.

