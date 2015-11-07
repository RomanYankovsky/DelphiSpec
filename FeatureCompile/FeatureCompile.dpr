program FeatureCompile;

{$APPTYPE CONSOLE}

uses
  System.SysUtils
, System.Classes
, System.StrUtils
, System.Types
, System.Math
, System.RegularExpressions
, Generics.Collections
, DelphiSpec.Core
, DelphiSpec.Scenario
, DelphiSpec.DataTable
, DelphiSpec.Parser;

function ToIdentifier(const AString: String): String;
var
  I: Integer;
begin
  Result := '';
  for I := Low(AString) to High(AString) do
  begin
    case AString[I] of
      'A'..'Z',
      'a'..'z',
      '_',
      '0'..'9': Result := Result + AString[I];
      ' ': Result := Result + '_';
    end;
  end;
end;

function IsValidIdentifier(const AString: String): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := Low(AString) to High(AString) do
  begin
    case AString[I] of
      'A'..'Z',
      'a'..'z',
      '_',
      '0'..'9': {* OK *};
      else
      begin
        Exit(False);
      end;
    end;
  end;
end;

type
  TValueType = ( vtRecord, vtString, vtNumber);
  TParamFlag = ( pfArray, pfBig, pfStaticString, pfFloat);
  TParamFlags = set of TParamFlag;

  TParameter = record
    TypeName: String;
    Name: String;
    ValueType: TValueType;
    Flags: TParamFlags;
    RecordFields: array of TParameter;

    function SyncWith(const AParameter: TParameter; var AChanged: Boolean): Boolean;
  end;

  TStepDef = class
  public
    Prefix: String;
    AttributeLines: TList<String>;
    ProcedureLine: String;
    Parameters: TList<TParameter>;
    UseAttribute: Boolean;

    constructor Create;
    destructor Destroy; override;

    class function Find(AList: TObjectList<TStepDef>; ADef: TStepDef): Integer;
  end;

function GetValueTypeFromDataTable(const ADataTable: IDataTable;
  out AFlags: TParamFlags; AColumn: Integer = -1): TValueType;
var
  J, LFirstRow: Integer;
  LString: String;
  LValueType: TValueType;
  LIsInteger: Boolean;
  LInteger, LMin, LMax: Int64;
  LIsFloat: Boolean;
  LFloat: Double;
  LTypeSet: Boolean;
begin
  AFlags := [];
  Result := vtString;
  LTypeSet := False;

  if AColumn < 0 then
  begin
    LFirstRow := 0;
    AColumn := 0;
  end else
    LFirstRow := 1;

  LMin := High(Int64);
  LMax := Low(Int64);

  for J := LFirstRow to ADataTable.GetRowCount - 1 do
  begin
    LString := ADataTable.GetValue(AColumn, J);
    LIsInteger := TryStrToInt64(LString, LInteger);
    LIsFloat := not LIsInteger and TryStrToFloat(LString, LFloat,
      TFormatSettings.Create('en-US'));

    if LIsFloat or LIsInteger then
    begin
      LValueType := vtNumber;

      if not (pfFloat in AFlags) then
      begin
        if not LIsFloat then
        begin
          if LInteger < LMin then
            LMin := LInteger;

          if LInteger > LMax then
            LMax := LInteger;
        end else
          Include(AFlags, pfFloat);
      end;
    end else
      LValueType := vtString;

    if not LTypeSet then
    begin
      LTypeSet := True;
      Result := LValueType;
    end else
    if Result <> LValueType then
    begin
      Result := vtString;
      Break;
    end;
  end;

  if Result = vtNumber then
  begin
    if not (pfFloat in AFlags) then
    begin
      if (LMin < Low(Integer)) or (LMax > High(Integer)) then
        Include(AFlags, pfBig);
    end;
  end else
  begin
    AFlags := [];
  end;
end;

function TryParseParameter(const AString: String; const ADataTable: IDataTable;
  out AOutput: TParameter): Boolean;
var
  LIsInteger: Boolean;
  LIsFloat: Boolean;
  LFloat: Double;
  LInteger: Int64;
  I: Integer;
begin
  AOutput.Flags := [];
  AOutput.ValueType := vtString;

  if (Length(AString) > 0)
  and (AString[Low(AString)] = '"')
  and (AString[High(AString)] = '"') then
  begin
    AOutput.ValueType := vtString;
    Include(AOutput.Flags, pfStaticString);
  end else
  if (Length(AString) > 0)
  and (AString[Low(AString)] = '<')
  and (AString[High(AString)] = '>') then
  begin
    AOutput.Name := ToIdentifier(Trim(AString.Substring(1, Length(AString) - 2)));

    if Assigned(ADataTable) then
    begin
      for I := 0 to ADataTable.GetColCount - 1 do
      begin
        if ADataTable.GetValue(I, 0) = AOutput.Name then
        begin
          AOutput.ValueType := GetValueTypeFromDataTable(ADataTable,
            AOutput.Flags, I);
          Break;
        end;
      end;
    end;
  end else
  begin
    LIsInteger := TryStrToInt64(AString, LInteger);
    LIsFloat := not LIsInteger
      and TryStrToFloat(AString, LFloat, TFormatSettings.Create('en-US'));

    if not LIsInteger and not LIsFloat then
      Exit(False);

    AOutput.ValueType := vtNumber;

    if not LIsFloat then
    begin
      if (LInteger < Low(Integer)) or (LInteger > High(Integer)) then
        Include(AOutput.Flags, pfBig);
    end else
      Include(AOutput.Flags, pfFloat);
  end;

  Result := True;
end;

function GetParameterName(const AParameter: TParameter): String;
begin
  Result := AParameter.Name;
  if Result = '' then
  begin
    case AParameter.ValueType of
      vtRecord:
      begin
        if pfArray in AParameter.Flags then
          Result := 'data'
        else
          Result := 'rec';
      end;
      vtString:
      begin
        if pfArray in AParameter.Flags then
          Result := 'strings'
        else
        if pfBig in AParameter.Flags then
          Result := 'text'
        else
          Result := 'value';
      end;
      else
      begin
        if pfArray in AParameter.Flags then
          Result := 'data'
        else
          Result := 'value';
      end;
    end;
  end;
end;

procedure GetStepDefinition(const APrefix: String;
  AStep: TScenario.TStep; const AExamplesDataTable: IDataTable;
  AOutput: TObjectList<TStepDef>);
var
  LDef: TStepDef;
  LSplitted: TList<String>;
  LString, LIdentifier, LAttributeLine: String;
  LIsValidParameter: Boolean;
  LSubstitute: Boolean;
  LInteger: Int64;
  LIsInteger: Boolean;
  LFloat: Double;
  LIsFloat: Boolean;
  LParameter: TParameter;
  LRegExMatch: TMatch;
  I, LCount, LPos, LPos1, LPos2: Integer;
begin
  LDef := TStepDef.Create;
  try
    LDef.Prefix := APrefix;
    LSplitted := TList<String>.Create;
    try
      LString := AStep.Value;
      LCount := Length(LString);
      while LCount > 0 do
      begin
        if LString[Low(LString)] = ' ' then
          LPos := 1
        else if LString[Low(LString)] = '"' then
          LPos := LString.IndexOf('"', 1) + 1
        else if LString[Low(LString)] = '<' then
          LPos := LString.IndexOf('>') + 1
        else
        begin
          LPos1 := LString.IndexOf(' ');
          LPos2 := LString.IndexOf('"');

          if (LPos1 < 0) or (LPos2 < 0) then
            LPos1 := Max(LPos1, LPos2)
          else
            LPos1 := Min(LPos1, LPos2);

          LPos2 := LString.IndexOf('<');

          if (LPos1 < 0) or (LPos2 < 0) then
            LPos := Max(LPos1, LPos2)
          else
            LPos := Min(LPos1, LPos2);
        end;

        if LPos < 0 then
          LPos := LCount;

        LSplitted.Add(LString.Substring(0, LPos));
        LString := LString.Remove(0, LPos);

        Dec(LCount, LPos);
      end;

      for I := 0 to LSplitted.Count -1 do
      begin
        LString := LSplitted[I];
        if LString = ' ' then
        begin
          LIdentifier := '';
        end else
        begin
          LIsValidParameter := TryParseParameter(LString,
            AExamplesDataTable, LParameter);

          if LIsValidParameter then
          begin
            LDef.Parameters.Add(LParameter);

            if pfStaticString in LParameter.Flags then
            begin
              LString := '"' + '(.*)' + '"';
              LDef.UseAttribute := True;
            end else
              LString := '(.*)';

            LIdentifier := GetParameterName(LParameter);
          end else
          if not IsValidIdentifier(LString) then
          begin
            LDef.UseAttribute := True;
            LIdentifier := ToIdentifier(LString);
          end else
            LIdentifier := LString;
        end;

        LAttributeLine := LAttributeLine + LString;

        if LIdentifier <> '' then
        begin
          if LDef.ProcedureLine = '' then
            LDef.ProcedureLine := LIdentifier
          else
            LDef.ProcedureLine := LDef.ProcedureLine + '_' + LIdentifier
        end;
      end;
    finally
      LSplitted.Free;
    end;

    if Assigned(AStep.DataTable) then
    begin
      LParameter.Name := '';
      LParameter.Flags := [];
      if AStep.DataTable.GetColCount > 1 then
      begin
        LParameter.ValueType := vtRecord;
        SetLength(LParameter.RecordFields, AStep.DataTable.GetColCount);

        for I := 0 to High(LParameter.RecordFields) do
        begin
          with LParameter.RecordFields[I] do
          begin
            Name := ToIdentifier(AStep.DataTable.GetValue(I, 0));
            ValueType := GetValueTypeFromDataTable(AStep.DataTable, Flags, I);
          end;
        end;
      end else
      begin
        Finalize(LParameter.RecordFields);
        LParameter.ValueType := GetValueTypeFromDataTable(AStep.DataTable,
          LParameter.Flags);
      end;

      Include(LParameter.Flags, pfArray);
      LDef.Parameters.Add(LParameter);
    end;

    if AStep.PyString <> '' then
    begin
      LParameter.Name := '';
      LParameter.ValueType := vtString;
      LParameter.Flags := [ pfBig ];
      Finalize(LParameter.RecordFields);

      LDef.Parameters.Add(LParameter);
    end;

    LDef.AttributeLines.Add(LAttributeLine);

    if TStepDef.Find(AOutput, LDef) < 0 then
    begin
      AOutput.Add(LDef);
      LDef := nil;
    end;
  finally
    LDef.Free;
  end;
end;

procedure GetScenarioStepDefinitions(AScenario: TScenario;
  AExampleDataTable: IDataTable; AOutput: TObjectList<TStepDef>);
var
  LStep: TScenario.TStep;
begin
  if Assigned(AScenario) then
  begin
    for LStep in AScenario.GivenSteps do
    begin
      GetStepDefinition('Given_', LStep, AExampleDataTable, AOutput);
    end;

    for LStep in AScenario.WhenSteps do
    begin
      GetStepDefinition('When_', LStep, AExampleDataTable, AOutput);
    end;

    for LStep in AScenario.ThenSteps do
    begin
      GetStepDefinition('Then_', LStep, AExampleDataTable, AOutput);
    end;
  end;
end;

function GetNameWithoutNumber(const AName: String): String;
var
  PC: PChar;
begin
  PC := Addr(AName[High(AName)]);

  while NativeUInt(PC) >= NativeUInt(Pointer(AName)) do
  begin
    case PC^ of
      '0'..'9':
      begin
        if StrToIntDef(PC, -1) < 0 then
          Break;

        Dec(PC);
      end;
      else
        Break;
    end;
  end;

  Result := AName.Substring(0, PC + 1 - PChar(AName));
end;

function RegisterParameterName(ANames: TList<String>;
  const AParameter: TParameter): String;
var
  LFoundIndex: Integer;
  I: Cardinal;
  LNewNameWithoutNumber: String;
  LNewNameWithNumber: String;
  LFound: Boolean;
begin
  Result := GetParameterName(AParameter);

  ANames.Sort;

  I := 0;
  LNewNameWithoutNumber := GetNameWithoutNumber(Result);

  repeat
    if I > 0 then
    begin
      LNewNameWithNumber := LNewNameWithoutNumber + UIntToStr(I);
      LFound := ANames.BinarySearch(LNewNameWithNumber, LFoundIndex);
    end else
    begin
      LFound := ANames.BinarySearch(Result, LFoundIndex);
      if LFound then
      begin
        LFound := ANames.BinarySearch(LNewNameWithoutNumber, LFoundIndex);
        if not LFound then
        begin
          Result := LNewNameWithoutNumber;
          Break;
        end;
      end;
    end;

    if not LFound then
    begin
      if I > 0 then
        Result := LNewNameWithNumber;

      Break;
    end;
    Inc(I);
  until False;

  ANames.Add(Result);
end;

function GetTypeName(const AParameter: TParameter): String;
begin
  case AParameter.ValueType of
    vtRecord:
    begin
      Result := AParameter.TypeName;
    end;
    vtNumber:
    begin
      if pfFloat in AParameter.Flags then
        Result := 'Double'
      else if (pfBig in AParameter.Flags) then
        Result := 'Int64'
      else
        Result := 'Integer';
    end;
    vtString:
    begin
      Result := 'String';
    end;
    else
    begin
      raise Exception.Create('Unknown  value type');
    end;
  end;

  if pfArray in AParameter.Flags then
    Result := 'TArray<' + Result + '>';
end;

function ParametersToString(AParameters: TList<TParameter>;
  out APrefixedParam: Boolean): String;
var
  LNames: TList<String>;
  LParameter: TParameter;
  LParamStr, LName: String;
begin
  APrefixedParam := False;
  Result := '';
  if AParameters.Count > 0 then
  begin
    LNames := TList<String>.Create;
    try
      for LParameter in AParameters do
      begin
        LName := RegisterParameterName(LNames, LParameter);
        if (LName <> '') then
        begin
          case LName[Low(LName)] of
            '0'..'9':
            begin
              LName := '_' + LName;
              APrefixedParam := True;
            end;
          end;
        end;
        LParamStr := Format('const %s: %s',
          [LName, GetTypeName(LParameter)]);

        if Result <> '' then
          Result := Result + '; ' + LParamStr
        else
          Result := LParamStr;
      end;
    finally
      LNames.Free;
    end;

    Result := '(' + Result + ')';
  end;
end;

procedure GenerateFeatureTestClassContents(const AClassName: String;
  AStepDefinitions: TObjectList<TStepDef>;
  AOutput: TStringList;
  ADummyImplementationOutput: TStringList);
var
  LStepDef: TStepDef;
  LSectionStarted: Boolean;
  LParameter, LRecordField: TParameter;
  LTypeNames, LFieldNames: TList<String>;
  I: Integer;
  LParamStr, LAttributeLine: String;
  LPrefixed: Boolean;
begin
  ADummyImplementationOutput.Clear;

  LTypeNames := TList<String>.Create;
  LFieldNames := TList<String>.Create;
  try
    LSectionStarted := False;
    for LStepDef in AStepDefinitions do
    begin
      for I := 0 to LStepDef.Parameters.Count - 1 do
      begin
        LParameter := LStepDef.Parameters[I];

        if LParameter.ValueType = vtRecord then
        begin
          if not LSectionStarted then
          begin
            LSectionStarted := True;
            AOutput.Add('  public type');
          end;

          LParameter.TypeName := 't_' + RegisterParameterName(LTypeNames, LParameter);
          AOutput.Add(Format('    %s = record', [LParameter.TypeName]));

          LStepDef.Parameters[I] := LParameter;

          LFieldNames.Clear;

          for LRecordField in LParameter.RecordFields do
          begin
            AOutput.Add(Format('      %s: %s;',
              [RegisterParameterName(LFieldNames, LRecordField),
               GetTypeName(LRecordField)]));
          end;

          AOutput.Add('    end;');
        end;
      end;
    end;

    LSectionStarted := False;
    for LStepDef in AStepDefinitions do
    begin
      if not LSectionStarted then
      begin
        LSectionStarted := True;
        AOutput.Add('  public');
      end;

      LParamStr := ParametersToString(LStepDef.Parameters, LPrefixed);

      if LStepDef.UseAttribute or LPrefixed then
      begin
        for LAttributeLine in LStepDef.AttributeLines do
        begin
          AOutput.Add(Format('    [%s(''%s'')]',
            [LStepDef.Prefix, LAttributeLine]));
        end;
      end;

      AOutput.Add(Format('    procedure %s%s%s;',
        [LStepDef.Prefix, LStepDef.ProcedureLine, LParamStr]));

      ADummyImplementationOutput.Add(Format('procedure T%sTest.%s%s%s;',
        [AClassName, LStepDef.Prefix, LStepDef.ProcedureLine, LParamStr]));
      ADummyImplementationOutput.Add('begin');
      ADummyImplementationOutput.Add('  Assert.Fail(''Write a test'');');
      ADummyImplementationOutput.Add('end;');
      ADummyImplementationOutput.Add('');
    end;

  finally
    LFieldNames.Free;
    LTypeNames.Free;
  end;
end;

procedure CompileFeatures(const AOutputPath, ALangCode: String; AFeatures: TFeatureList);
var
  LFeature: TFeature;
  LOutput, LDummyImplementation: TStringList;
  LStepDefinitions: TObjectList<TStepDef>;
  LScenario: TScenario;
  LScenarioOutline: TScenarioOutline;
  LString, LOutputFileName: String;
  I, LHigh: Integer;
begin
  ForceDirectories(AOutputPath);
  LOutput := TStringList.Create;
  LDummyImplementation := TStringList.Create;
  try
    for LFeature in AFeatures do
    begin
      if not IsValidIdentifier(LFeature.FeatureClassName) then
        raise Exception.CreateFmt('Feature class name ''%s'' is invalid',
          [LFeature.FeatureClassName]);

      LOutput.Add('// AUTOMATICALLY GENERATED, DO NOT EDIT! //');
      LOutput.Add('');
      LOutput.Add('type');
      LOutput.Add(Format('  [Feature(''%s'')]', [LFeature.Name]));
      LOutput.Add(Format('  T%sTest = class(T%sTestContext)',
        [LFeature.FeatureClassName, LFeature.FeatureClassName]));


      LStepDefinitions := TObjectList<TStepDef>.Create;
      try
        GetScenarioStepDefinitions(LFeature.Background, nil, LStepDefinitions);

        for LScenario in LFeature.Scenarios do
          GetScenarioStepDefinitions(LScenario, nil, LStepDefinitions);

        for LScenarioOutline in LFeature.ScenarioOutlines do
        begin
          GetScenarioStepDefinitions(LScenarioOutline,
            LScenarioOutline.Examples, LStepDefinitions);
        end;

        GenerateFeatureTestClassContents(LFeature.FeatureClassName,
          LStepDefinitions, LOutput, LDummyImplementation);

        LOutput.Add('  end;');
        LOutput.Add('');
        LOutput.Add('const');
        LOutput.Add(Format('  %sSource: String = (', [LFeature.FeatureClassName]));

        LHigh := LFeature.Source.Count - 1;
        for I := 0 to LHigh do
        begin
          LString := '''' + LFeature.Source[I].Replace('''', '''''') + '''#13#10';
          if I < LHigh then
           LString := LString + ' +';

          LOutput.Add(LString);
        end;
        LOutput.Add(');');
        LOutput.Add('');
        LOutput.Add(Format('procedure Register%sTest;', [ LFeature.FeatureClassName ]));
        LOutput.Add('begin');
        LOutput.Add(Format('  RegisterStepDefinitionsClass(T%sTest);',
          [LFeature.FeatureClassName]));
        LOutput.Add(
          Format('  TDelphiSpecParser.RegisterClass(''%s'', ''%s'', %sSource);',
          [ LFeature.FeatureClassName, ALangCode, LFeature.FeatureClassName ]));
        LOutput.Add('end;');

        LOutputFileName := Format('%s\Test%s.inc',
          [AOutputPath, LFeature.FeatureClassName]);
        LOutput.SaveToFile(LOutputFileName, TEncoding.UTF8);

        Writeln(LOutputFileName);

        LOutput.Clear;

        LOutputFileName := Format('%s\Test%s.pas',
          [AOutputPath, LFeature.FeatureClassName]);

        if not FileExists(LOutputFileName) then
        begin
          LOutput.Add(Format('unit Test%s;', [LFeature.FeatureClassName]));
          LOutput.Add('');
          LOutput.Add('interface');
          LOutput.Add('');
          LOutput.Add('uses');
          LOutput.Add('  System.SysUtils');
          LOutput.Add(', Generics.Collections');
          LOutput.Add(', DelphiSpec.StepDefinitions;');
          LOutput.Add('');
          LOutput.Add('type');
          LOutput.Add(Format('  T%sTestContext = class(TStepDefinitions)',
            [LFeature.FeatureClassName]));
          LOutput.Add('  public');
          LOutput.Add('    procedure SetUp; override;');
          LOutput.Add('    procedure TearDown; override;');
          LOutput.Add('  end;');
          LOutput.Add('');
          LOutput.Add('implementation');
          LOutput.Add('');
          LOutput.Add('uses');
          LOutput.Add('  DelphiSpec.Core');
          LOutput.Add(', DelphiSpec.Assert');
          LOutput.Add(', DelphiSpec.Attributes');
          LOutput.Add(', DelphiSpec.Parser;');
          LOutput.Add('');
          LOutput.Add(Format('{$I Test%s.inc}', [LFeature.FeatureClassName]));
          LOutput.Add('');
          LOutput.Add(Format('{ T%sTestContext }', [LFeature.FeatureClassName]));
          LOutput.Add('');
          LOutput.Add(Format('procedure T%sTestContext.SetUp;', [LFeature.FeatureClassName]));
          LOutput.Add('begin');
          LOutput.Add('  // TODO: SetUp');
          LOutput.Add('end;');
          LOutput.Add('');
          LOutput.Add(Format('procedure T%sTestContext.TearDown;', [LFeature.FeatureClassName]));
          LOutput.Add('begin');
          LOutput.Add('  // TODO: TearDown');
          LOutput.Add('end;');
          LOutput.Add('');
          LOutput.Add(Format('{ T%sTest }', [LFeature.FeatureClassName]));
          LOutput.Add('');
          for I := 0 to LDummyImplementation.Count - 1 do
          begin
            LOutput.Add(LDummyImplementation[I]);
          end;

          LOutput.Add('initialization');
          LOutput.Add(Format('  Register%sTest;', [LFeature.FeatureClassName]));
          LOutput.Add('end.');

          LOutput.SaveToFile(LOutputFileName, TEncoding.UTF8);

          Writeln(LOutputFileName);
        end;


      finally
        LStepDefinitions.Free;
      end;

      LOutput.Clear;
    end;

  finally
    LDummyImplementation.Free;
    LOutput.Free;
  end;
end;

{ TStepDef }

constructor TStepDef.Create;
begin
  Parameters := TList<TParameter>.Create;
  AttributeLines := TList<String>.Create;
end;

destructor TStepDef.Destroy;
begin
  AttributeLines.Free;
  Parameters.Free;
  inherited;
end;

class function TStepDef.Find(AList: TObjectList<TStepDef>;
  ADef: TStepDef): Integer;
var
  LDef: TStepDef;
  I: Integer;
  LParameter: TParameter;
  LParameterPtr: ^TParameter;
  LTemp: array of TParameter;
  LContinue, LChanged, LExactLineFound: Boolean;
  LAttributeLine, LOriginalAttributeLine, LString: String;
begin
  Result := 0;

  for LDef in AList do
  begin
    if (LDef.Prefix = ADef.Prefix)
    and (LDef.Parameters.Count = ADef.Parameters.Count) then
    begin
      SetLength(LTemp, ADef.Parameters.Count);
      LChanged := False;
      LParameterPtr := Pointer(LTemp);
      LContinue := False;
      for I := 0 to Length(LTemp) - 1 do
      begin
        LParameterPtr^ := LDef.Parameters[I];
        if not LParameterPtr^.SyncWith(ADef.Parameters[I], LChanged) then
        begin
          LContinue := True;
          Break;
        end;
        Inc(LParameterPtr);
      end;

      if LContinue then
        Continue;

      LExactLineFound := False;
      LOriginalAttributeLine := ADef.AttributeLines.First;
      LAttributeLine := LOriginalAttributeLine.Replace('"(.*)"', '(.*)');
      for LString in LDef.AttributeLines do
      begin
        if LString.Replace('"(.*)"', '(.*)') <> LAttributeLine then
        begin
          LContinue := True;
          Break;
        end;

        if not LExactLineFound and (LString = LOriginalAttributeLine) then
          LExactLineFound := True;
      end;

      if LContinue then
        Continue;

      if not LExactLineFound then
        LDef.AttributeLines.Add(ADef.AttributeLines.First);

      if LChanged then
      begin
        LDef.Parameters.Clear;
        for I := 0 to Length(LTemp) - 1 do
          LDef.Parameters.Add(LTemp[I]);
      end;
      Exit;
    end;

    Inc(Result);
  end;

  Result := -1;
end;

{ TParameter }

function TParameter.SyncWith(const AParameter: TParameter; var AChanged: Boolean): Boolean;
var
  I: Integer;
  Flags1, Flags2: TParamFlags;
begin
  AChanged := False;
  Flags1 := Flags - [ pfStaticString ];
  Flags2 := AParameter.Flags - [ pfStaticString ];

  if Flags1 <> Flags2 then
    Exit(False);

  if Length(RecordFields) <> Length(AParameter.RecordFields) then
    Exit(False);

  if (ValueType <> AParameter.ValueType) and (ValueType = vtRecord) then
    Exit(False);

  for I := 0 to Length(RecordFields) - 1 do
  begin
    if not RecordFields[I].SyncWith(AParameter.RecordFields[I], AChanged) then
      Exit(False);
  end;

  if ValueType = vtNumber then
  begin
    if (pfBig in AParameter.Flags)
    and not (pfBig in Flags) then
    begin
      Include(Flags, pfBig);
      AChanged := True;
    end;

    if (pfFloat in AParameter.Flags)
    and not (pfFloat in Flags) then
    begin
      Include(Flags, pfFloat);
      AChanged := True;
    end;
  end else
  if ValueType <> AParameter.ValueType then
  begin
    ValueType := vtString;
    AChanged := True;
  end;

  Result := True;
end;

var
  LanguageCode: String;
  Features: TFeatureList;
begin
  try
    if ParamCount >= 2 then
    begin
      if ParamCount >= 3 then
        LanguageCode := ParamStr(3)
      else
        LanguageCode := 'EN';

      Features := ReadFeatures(ParamStr(1), True, LanguageCode, False);
      try
        CompileFeatures(ParamStr(2), LanguageCode, Features);
      finally
        Features.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
    {$IFDEF DEBUG}
      Readln;
    {$ENDIF}
    end;
  end;
end.
