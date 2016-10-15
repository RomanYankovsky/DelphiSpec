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

type
  TProgrammingFramework = (Unknown, Delphi, QtCPP);

function ToIdentifier(const AString: String; APrefix: Boolean = False): String;
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

  if APrefix then
  begin
    if Result <> '' then
    begin
      case Result[Low(Result)] of
        '0'..'9': Result := '_' + Result;
      end;
    end else
      Result := '_';
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
    ExamplesDataTable: IDataTable;

    constructor Create;
    destructor Destroy; override;

    class function Find(AList: TObjectList<TStepDef>; ADef: TStepDef): Integer;
  end;

  TScenarioInfo = class
  private
    function GetExamples: IDataTable;
  public
    Scenario: TScenario;
    Steps: TList<TStepDef>;

    constructor Create(AScenario: TScenario);
    destructor Destroy; override;

    property Examples: IDataTable read GetExamples;
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

function GetStepDefinition(const APrefix: String;
  AStep: TScenario.TStep; const AExamplesDataTable: IDataTable;
  AOutput: TObjectList<TStepDef>): TStepDef;
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
    LDef.ExamplesDataTable := AExamplesDataTable;
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

      for I := 0 to LSplitted.Count - 1 do
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
            Name := ToIdentifier(AStep.DataTable.GetValue(I, 0), True);
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

    I := TStepDef.Find(AOutput, LDef);
    if I < 0 then
    begin
      AOutput.Add(LDef);
      Result := LDef;
      LDef := nil;
    end else
      Result := AOutput[I];
  finally
    LDef.Free;
  end;
end;

procedure GetScenarioStepDefinitions(AScenario: TScenario;
  AOutput: TObjectList<TStepDef>;
  AScenarioInfo: TObjectList<TScenarioInfo>);
var
  LStep: TScenario.TStep;
  LInfo: TScenarioInfo;
  LExamples: IDataTable;
begin
  if Assigned(AScenario) then
  begin
    LInfo := TScenarioInfo.Create(AScenario);

    LExamples := LInfo.Examples;

    for LStep in AScenario.GivenSteps do
    begin
      LInfo.Steps.Add(GetStepDefinition('Given_', LStep, LExamples, AOutput));
    end;

    for LStep in AScenario.WhenSteps do
    begin
      LInfo.Steps.Add(GetStepDefinition('When_', LStep, LExamples, AOutput));
    end;

    for LStep in AScenario.ThenSteps do
    begin
      LInfo.Steps.Add(GetStepDefinition('Then_', LStep, LExamples, AOutput));
    end;

    AScenarioInfo.Add(LInfo);
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

function GetTypeNameDelphi(const AParameter: TParameter): String;
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

function GetTypeNameQtCPP(const AParameter: TParameter): String;
begin
  case AParameter.ValueType of
    vtRecord:
    begin
      Result := AParameter.TypeName;
    end;
    vtNumber:
    begin
      if pfFloat in AParameter.Flags then
        Result := 'qreal'
      else if (pfBig in AParameter.Flags) then
        Result := 'qint64'
      else
        Result := 'int';
    end;
    vtString:
    begin
      Result := 'QString';
    end;
    else
    begin
      raise Exception.Create('Unknown  value type');
    end;
  end;

  if pfArray in AParameter.Flags then
    Result := 'QList<' + Result + '>';
end;

function ParametersToStringDelphi(AParameters: TList<TParameter>;
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
          [LName, GetTypeNameDelphi(LParameter)]);

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

function ParametersToStringQtCPP(AParameters: TList<TParameter>;
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
        if LName <> '' then
        begin
          case LName[Low(LName)] of
            '0'..'9':
            begin
              LName := '_' + LName;
              APrefixedParam := True;
            end;
          end;
        end;
        LParamStr := Format('const %s &%s',
          [GetTypeNameQtCPP(LParameter), LName]);

        if Result <> '' then
          Result := Result + ', ' + LParamStr
        else
          Result := LParamStr;
      end;
    finally
      LNames.Free;
    end;
  end;
end;

function ReplaceWith(LParameter: TParameter;
  var VReplace: String; const AExamples: IDataTable): Boolean; overload;
var
  K: Integer;
  LStr: String;
begin
  Result := False;

  if Assigned(AExamples)
  and (Length(VReplace) > 2)
  and (VReplace[Low(VReplace)] = '<')
  and (VReplace[High(VReplace)] = '>') then
  begin
    LStr := VReplace.SubString(1, Length(VReplace) - 2);

    for K := 0 to AExamples.ColCount - 1 do
    begin
      if String.Compare(LStr, AExamples.Values[K, 0], True) = 0 then
      begin
        VReplace := ToIdentifier(LStr, True);
        if LParameter.ValueType = vtNumber then
        begin
          if pfFloat in LParameter.Flags then
            VReplace := VReplace + '.toDouble()'
          else if (pfBig in LParameter.Flags) then
            VReplace := VReplace + '.toLongLong()'
          else
            VReplace := VReplace + '.toInt()'
        end;

        Result := True;
        Break;
      end;
    end;
  end;
end;

procedure ReplaceWith(const AExamples: IDataTable; var AOutput: String); overload;
var
  I: Integer;
  LColName: String;
begin
  if Assigned(AExamples) then
  begin
    for I := 0 to AExamples.ColCount - 1 do
    begin
      LColName := AExamples.Values[I, 0];
      AOutput := TRegEx.Replace(AOutput, '<' + LColName + '>',
        '") + ' + ToIdentifier(LColName) + '_T("', [TRegExOption.roIgnoreCase]);
    end;
  end;
end;

function ParametersToArgumentStringQtCPP(AScenarioInfo: TScenarioInfo;
  AStep: TScenario.TStep; const AParameters: array of TParameter): String;
var
  LParameter: TParameter;
  LParamStr, LStr, LReplace: String;
  LIndex, I, J: Integer;
  LExamples: IDataTable;
  LReplaced: Boolean;
  LStringList: TStringList;
  LMatchCollection: TMatchCollection;
  LMatch: TMatch;
  LMatchPtr: ^TMatch;
begin
  Result := '';
  if Length(AParameters) > 0 then
  begin
    LExamples := AScenarioInfo.Examples;

    LStr := '(\s|^)((\-?|\+?)[0-9]+|".*"|<.*>)(\s|$)';
    LMatchCollection := TRegEx.Matches(AStep.Value, LStr, [roIgnoreCase]);

    Assert(LMatchCollection.Count <= Length(AParameters));

    for LIndex := 0 to Length(AParameters) - 1 do
    begin
      if LIndex < LMatchCollection.Count then
      begin
        LMatch := LMatchCollection[LIndex];
        LMatchPtr := @LMatch;
      end else
        LMatchPtr := nil;

      LParameter := AParameters[LIndex];
      LParamStr := '';
      case LParameter.ValueType of
        vtRecord:
        begin
          Assert((pfArray in LParameter.Flags) and Assigned(AStep.DataTable));

          with AStep.DataTable do
          begin
            for J := 1 to RowCount - 1 do
            begin
              LStr := '';
              for I := 0 to ColCount - 1 do
              begin
                LReplace := Values[I, J];
                LReplaced := ReplaceWith(LParameter, LReplace, LExamples);

                if not LReplaced then
                begin
                  if LParameter.RecordFields[I].ValueType = vtString then
                    LReplace := '_T("' + LReplace + '")';
                end;

                if I = 0 then
                  LStr := LReplace
                else
                  LStr := LStr + ', ' + LReplace;
              end;
              if J = 1 then
                LParamStr := '{' + LStr + '}'
              else
                LParamStr := LParamStr + ','#10#9#9#9'{' + LStr + '}';
            end;
          end;

          LParamStr := '{' + LParamStr + '}';
        end;
        vtNumber:
        begin
          if Assigned(LMatchPtr) then
          begin
            Assert(not (pfArray in LParameter.Flags));

            LParamStr := Trim(LMatchPtr.Value);
            ReplaceWith(LParameter, LParamStr, LExamples);
          end else
          begin
            Assert((pfArray in LParameter.Flags) and Assigned(AStep.DataTable));

            with AStep.DataTable do
            begin
              for J := 0 to RowCount - 1 do
              begin
                LReplace := Values[0, J];
                ReplaceWith(LParameter, LReplace, LExamples);

                if J = 0 then
                  LStr := LReplace
                else
                  LStr := LStr + ', ' + LReplace;
              end;
            end;

            LParamStr := '{' + LStr + '}';
          end;
        end;
        vtString:
        begin
          if Assigned(LMatchPtr) then
          begin
            Assert(not (pfArray in LParameter.Flags));

            LParamStr := Trim(LMatchPtr.Value);
            LReplaced := ReplaceWith(LParameter, LParamStr, LExamples);
            if not LReplaced then
              LParamStr := '_T(' + LParamStr + ')';
          end else
          if (pfArray in LParameter.Flags) and Assigned(AStep.DataTable) then
          begin
            with AStep.DataTable do
            begin
              for J := 0 to RowCount - 1 do
              begin
                LReplace := Values[0, J];
                LReplaced := ReplaceWith(LParameter, LReplace, LExamples);

                if not LReplaced then
                  LReplace := '_T("' + LReplace + '")';

                if J = 0 then
                  LStr := LReplace
                else
                  LStr := LStr + ', ' + LReplace;
              end;
            end;

            LParamStr := '{' + LStr + '}';
          end else
          if pfBig in LParameter.Flags then
          begin
            LStringList := TStringList.Create;
            try
              LStringList.Text := AStep.PyString;

              for I := 0 to LStringList.Count - 1 do
              begin
                LStr := LStringList[I];
                ReplaceWith(LExamples, LStr);
                LStr := '_T("' + LStr + '")';
                if I = 0 then
                  LParamStr := LStr
                else
                  LParamStr := LParamStr + #10#9#9#9 + LStr;
              end;

              LParamStr := '{' + LParamStr + '}';
            finally
              LStringList.Free;
            end;
          end else
          begin
            raise Exception.Create('Unexpected');
          end;
        end;
        else
        begin
          raise Exception.Create('Unknown  value type');
        end;
      end;

      if Result <> '' then
        Result := Result + ','#10#9#9 + LParamStr
      else
        Result := LParamStr;
    end;
  end;
end;

procedure OutputStepQtCPP(AInfo: TScenarioInfo; I: Integer; AStep: TScenario.TStep; AOutput: TStringList);
var
  LParamStr: String;
  LStepDef: TStepDef;
begin
  LStepDef := AInfo.Steps[I];
  LParamStr := ParametersToArgumentStringQtCPP(AInfo, AStep, LStepDef.Parameters.List);
  AOutput.Add(Format(#9#9'%s%s(%s);', [LStepDef.Prefix, LStepDef.ProcedureLine, LParamStr]));
end;

procedure GenerateFeatureTestClassContents(AFeature: TFeature;
  AStepDefinitions: TObjectList<TStepDef>;
  AScenarioInfo: TObjectList<TScenarioInfo>;
  AOutput: TStringList;
  ADummyImplementationOutput: TStringList;
  AOutputFramework: TProgrammingFramework);
var
  LStep: TScenario.TStep;
  LStepDef: TStepDef;
  LInfo: TScenarioInfo;
  LScenario: TScenario;
  LExamples: IDataTable;
  LParameter, LRecordField: TParameter;
  LTypeNames, LFieldNames: TList<String>;
  LParamStr, LAttributeLine: String;
  I, J: Integer;
  LSectionStarted: Boolean;
  LPrefixed: Boolean;
begin
  ADummyImplementationOutput.Clear;

  LTypeNames := TList<String>.Create;
  LFieldNames := TList<String>.Create;
  try
    case AOutputFramework of
      Delphi:
      begin
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
                   GetTypeNameDelphi(LRecordField)]));
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

          LParamStr := ParametersToStringDelphi(LStepDef.Parameters, LPrefixed);

          if LStepDef.UseAttribute or LPrefixed then
          begin
            for LAttributeLine in LStepDef.AttributeLines do
            begin
              AOutput.Add(Format('    [%s(''%s'')]',
                [LStepDef.Prefix, LAttributeLine.Replace('''', '''''')]));
            end;
          end;

          AOutput.Add(Format('    procedure %s%s%s;',
            [LStepDef.Prefix, LStepDef.ProcedureLine, LParamStr]));

          ADummyImplementationOutput.Add(Format('procedure T%sTest.%s%s%s;',
            [AFeature.FeatureClassName, LStepDef.Prefix, LStepDef.ProcedureLine, LParamStr]));
          ADummyImplementationOutput.Add('begin');
          ADummyImplementationOutput.Add('  Assert.Fail(''Write a test'');');
          ADummyImplementationOutput.Add('end;');
          ADummyImplementationOutput.Add('');
        end;
      end;
      QtCPP:
      begin
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

                AOutput.Add('public:');
              end;

              LParameter.TypeName := 't_' + RegisterParameterName(LTypeNames, LParameter);
              AOutput.Add(Format(#9'struct %s', [LParameter.TypeName]));
              AOutput.Add(#9'{');

              LStepDef.Parameters[I] := LParameter;

              LFieldNames.Clear;

              for LRecordField in LParameter.RecordFields do
              begin
                AOutput.Add(Format(#9#9'%s %s;',
                  [GetTypeNameQtCPP(LRecordField),
                  RegisterParameterName(LFieldNames, LRecordField)]));
              end;

              AOutput.Add(#9'};');
            end;
          end;
        end;

        LSectionStarted := False;
        for LStepDef in AStepDefinitions do
        begin
          if not LSectionStarted then
          begin
            LSectionStarted := True;
            AOutput.Add('private:');
          end;

          LParamStr := ParametersToStringQtCPP(LStepDef.Parameters, LPrefixed);

          AOutput.Add(Format(#9'void %s%s(%s);',
            [LStepDef.Prefix, LStepDef.ProcedureLine, LParamStr]));

          ADummyImplementationOutput.Add(Format('void %sTest::%s%s(%s)',
            [AFeature.FeatureClassName, LStepDef.Prefix, LStepDef.ProcedureLine, LParamStr]));
          ADummyImplementationOutput.Add('{');
          ADummyImplementationOutput.Add(#9'QFAIL("Write a test!");');
          ADummyImplementationOutput.Add('}');
          ADummyImplementationOutput.Add('');
        end;

        LSectionStarted := False;
        for LInfo in AScenarioInfo do
        begin
          if not LSectionStarted then
          begin
            LSectionStarted := True;
            AOutput.Add('private Q_SLOTS:');
          end;

          LScenario := LInfo.Scenario;
          LExamples := LInfo.Examples;
          if LScenario = AFeature.Background then
          begin
            AOutput.Add(#9'// Background');
            AOutput.Add(#9'void initTestCase()');
          end else
          begin
            LParamStr := ToIdentifier(LScenario.Name, True);

            if Assigned(LExamples) then
            begin
              AOutput.Add(#9'// Scenario Examples');
              AOutput.Add(Format(#9'void %s_data()', [LParamStr]));
              AOutput.Add(#9'{');
              for I := 0 to LExamples.ColCount - 1 do
              begin
                AOutput.Add(Format(#9#9'QTest::addColumn<QString>("%s");',
                  [ToIdentifier(LExamples.Values[I, 0], True)]));
              end;

              for J := 1 to LExamples.RowCount - 1 do
              begin
                LAttributeLine := '';
                for I := 0 to LExamples.ColCount - 1 do
                begin
                  LAttributeLine := LAttributeLine +
                    ' << _T("' + LExamples.Values[I, J] + '")';
                end;
                AOutput.Add(Format(#9#9'QTest::newRow("case%d")%s;',
                  [J, LAttributeLine]));
              end;
              AOutput.Add(#9'}');
              AOutput.Add('');
            end;
            AOutput.Add(#9'// Scenario');
            AOutput.Add(Format(#9'void %s()', [LParamStr]));
          end;

          AOutput.Add(#9'{');
          if Assigned(LExamples) then
          begin
            for I := 0 to LExamples.ColCount - 1 do
            begin
              AOutput.Add(Format(#9#9'QFETCH(QString, %s);',
                [ToIdentifier(LExamples.Values[I, 0], True)]));
            end;
          end;

          I := 0;
          for LStep in LScenario.GivenSteps do
          begin
            OutputStepQtCPP(LInfo, I, LStep, AOutput);
            Inc(I);
          end;
          for LStep in LScenario.WhenSteps do
          begin
            OutputStepQtCPP(LInfo, I, LStep, AOutput);
            Inc(I);
          end;
          for LStep in LScenario.ThenSteps do
          begin
            OutputStepQtCPP(LInfo, I, LStep, AOutput);
            Inc(I);
          end;

          AOutput.Add(#9'}');
          AOutput.Add('');
        end;
      end;
    end;
  finally
    LFieldNames.Free;
    LTypeNames.Free;
  end;
end;

const
  TestsMainQtCPP: String =
  '#include "TestsMain.h"'#10 +
  #10 +
  '#include <QCoreApplication>'#10 +
  '#include <QDebug>'#10 +
  #10 +
  'int main(int argc, char *argv[])'#10 +
  '{'#10 +
  #9'qDebug() << "Startup Testing...";'#10 +
  #9'QCoreApplication app(argc, argv);'#10 +
  #9'app.setAttribute(Qt::AA_Use96Dpi, true);'#10 +
  #9'QTEST_SET_MAIN_SOURCE_PATH'#10 +
  #9'return executeTests(argc, argv);'#10 +
  '}';

procedure CompileFeatures(const AOutputPath, ALangCode: String;
  AOutputFramework: TProgrammingFramework; AFeatures: TFeatureList);
var
  LFeature: TFeature;
  LMainHeaders, LMainOutput, LOutput, LDummyImplementation: TStringList;
  LStepDefinitions: TObjectList<TStepDef>;
  LScenarioInfo: TObjectList<TScenarioInfo>;
  LScenario: TScenario;
  LScenarioOutline: TScenarioOutline;
  LString, LOutputFileName: String;
  I, LHigh: Integer;
begin
  ForceDirectories(AOutputPath);
  LOutput := TStringList.Create;
  LMainOutput := TStringList.Create;
  LMainHeaders := TStringList.Create;
  LDummyImplementation := TStringList.Create;
  try
    if AOutputFramework = QtCPP then
    begin
      LMainHeaders.Add('// AUTOMATICALLY GENERATED, DO NOT EDIT! //');
      LMainHeaders.Add('');
      LMainOutput.Add('static int executeTest(QObject *object, int argc, char **argv)');
      LMainOutput.Add('{');
      LMainOutput.Add(#9'int status = QTest::qExec(object, argc, argv);');
      LMainOutput.Add(#9'delete object;');
      LMainOutput.Add(#9'return status;');
      LMainOutput.Add('}');
      LMainOutput.Add('');
      LMainOutput.Add('static int executeTests(int argc, char** argv)');
      LMainOutput.Add('{');
      LMainOutput.Add(#9'int status = 0;');
    end;

    for LFeature in AFeatures do
    begin
      if not IsValidIdentifier(LFeature.FeatureClassName) then
        raise Exception.CreateFmt('Feature class name ''%s'' is invalid',
          [LFeature.FeatureClassName]);

      LOutput.Add('// AUTOMATICALLY GENERATED, DO NOT EDIT! //');

      case AOutputFramework of
        Delphi:
        begin
          LOutput.Add('');
          LOutput.Add('type');
          LOutput.Add(Format('  [Feature(''%s'')]', [LFeature.Name.Replace('''', '''''')]));
          LOutput.Add(Format('  T%sTest = class(T%sTestContext)',
            [LFeature.FeatureClassName, LFeature.FeatureClassName]));
        end;
        QtCPP:
        begin
          LOutput.Add(Format('// Feature "%s" Test Header', [LFeature.Name]));
          LOutput.Add('#pragma once');
          LOutput.Add('');
          LOutput.Add(Format('#include "%sTestContext.h"',
            [LFeature.FeatureClassName]));
          LOutput.Add('');
          LOutput.Add('#include <QList>');
          LOutput.Add('#include <QString>');
          LOutput.Add('#include <QtTest>');
          LOutput.Add('');
          LOutput.Add('#if defined(_UNICODE) && defined(_MSC_VER)');
          LOutput.Add(' #define _T(c) QString::fromWCharArray(L##c)');
          LOutput.Add('#else');
          LOutput.Add(' #define _T(c) QString::fromUtf8(c)');
          LOutput.Add('#endif');
          LOutput.Add('');
          LOutput.Add(Format('class %sTest : public %sTestContext',
            [LFeature.FeatureClassName, LFeature.FeatureClassName]));
          LOutput.Add('{');
          LOutput.Add(#9'Q_OBJECT');
        end;
      end;

      LScenarioInfo := TObjectList<TScenarioInfo>.Create;
      LStepDefinitions := TObjectList<TStepDef>.Create;
      try
        GetScenarioStepDefinitions(LFeature.Background, LStepDefinitions,
          LScenarioInfo);

        for LScenario in LFeature.Scenarios do
          GetScenarioStepDefinitions(LScenario, LStepDefinitions, LScenarioInfo);

        for LScenarioOutline in LFeature.ScenarioOutlines do
        begin
          GetScenarioStepDefinitions(LScenarioOutline, LStepDefinitions, LScenarioInfo);
        end;

        GenerateFeatureTestClassContents(LFeature, LStepDefinitions,
          LScenarioInfo, LOutput, LDummyImplementation, AOutputFramework);

        case AOutputFramework of
          Delphi:
          begin
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

            LOutputFileName := Format('%s\Test%s.pas',
              [AOutputPath, LFeature.FeatureClassName]);

            if not FileExists(LOutputFileName) then
            begin
              LOutput.Clear;
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
          end;
          QtCPP:
          begin
            LOutput.Add('};');

            LOutputFileName := Format('%s\%sTest.h',
              [AOutputPath, LFeature.FeatureClassName]);

            LOutput.SaveToFile(LOutputFileName, TEncoding.UTF8);

            Writeln(LOutputFileName);

            LMainHeaders.Add(Format('#include "%sTest.h"', [LFeature.FeatureClassName]));

            LMainOutput.Add(Format(#9'status |= executeTest(new %sTest, argc, argv);',
            [LFeature.FeatureClassName]));

            LOutputFileName := Format('%s\%sTest.cpp',
              [AOutputPath, LFeature.FeatureClassName]);

            if not FileExists(LOutputFileName) then
            begin
              LOutput.Clear;
              LOutput.Add(Format('// Feature "%s" Test Code', [LFeature.Name]));
              LOutput.Add('');
              LOutput.Add(Format('#include "%sTest.h"', [LFeature.FeatureClassName]));
              LOutput.Add('');

              for I := 0 to LDummyImplementation.Count - 1 do
              begin
                LOutput.Add(LDummyImplementation[I]);
              end;

              LOutput.SaveToFile(LOutputFileName, TEncoding.UTF8);

              Writeln(LOutputFileName);
            end;

            LOutputFileName := Format('%s\%sTestContext.h',
              [AOutputPath, LFeature.FeatureClassName]);

            if not FileExists(LOutputFileName) then
            begin
              LOutput.Clear;
              LOutput.Add(Format('// Feature "%s" Test Context Header', [LFeature.Name]));
              LOutput.Add('');
              LOutput.Add('#include <QObject>');
              LOutput.Add('');
              LOutput.Add(Format('class %sTestContext : public QObject',
                [LFeature.FeatureClassName]));
              LOutput.Add('{');
              LOutput.Add(#9'Q_OBJECT');
              LOutput.Add('public:');
              LOutput.Add(Format(#9'%sTestContext();',
                [LFeature.FeatureClassName]));
              LOutput.Add(Format(#9'virtual ~%sTestContext();',
                [LFeature.FeatureClassName]));
              LOutput.Add('');
              LOutput.Add('protected Q_SLOTS:');
              LOutput.Add(#9'void init();');
              LOutput.Add(#9'void cleanup();');
              LOutput.Add('};');

              LOutput.SaveToFile(LOutputFileName, TEncoding.UTF8);

              Writeln(LOutputFileName);
            end;

            LOutputFileName := Format('%s\%sTestContext.cpp',
              [AOutputPath, LFeature.FeatureClassName]);

            if not FileExists(LOutputFileName) then
            begin
              LOutput.Clear;
              LOutput.Add(Format('// Feature "%s" Test Context Code', [LFeature.Name]));
              LOutput.Add('');
              LOutput.Add(Format('#include "%sTestContext.h"', [LFeature.FeatureClassName]));
              LOutput.Add('');
              LOutput.Add(Format('%sTestContext::%sTestContext()',
                [LFeature.FeatureClassName, LFeature.FeatureClassName]));
              LOutput.Add('{');
              LOutput.Add('}');
              LOutput.Add('');
              LOutput.Add(Format('%sTestContext::~%sTestContext()',
                [LFeature.FeatureClassName, LFeature.FeatureClassName]));
              LOutput.Add('{');
              LOutput.Add('}');
              LOutput.Add('');
              LOutput.Add(Format('void %sTestContext::init()',
                [LFeature.FeatureClassName]));
              LOutput.Add('{');
              LOutput.Add('}');
              LOutput.Add('');
              LOutput.Add(Format('void %sTestContext::cleanup()',
                [LFeature.FeatureClassName]));
              LOutput.Add('{');
              LOutput.Add('}');

              LOutput.SaveToFile(LOutputFileName, TEncoding.UTF8);

              Writeln(LOutputFileName);
            end;
          end;
        end;
      finally
        LStepDefinitions.Free;
        LScenarioInfo.Free;
      end;

      LOutput.Clear;
    end;

    if AOutputFramework = QtCPP then
    begin
      LMainOutput.Add(#9'return status;');
      LMainOutput.Add('}');

      LMainHeaders.Add('');
      LMainHeaders.AddStrings(LMainOutput);

      LOutputFileName := Format('%s\TestsMain.h', [AOutputPath]);

      LMainHeaders.SaveToFile(LOutputFileName, TEncoding.UTF8);

      LOutputFileName := Format('%s\TestsMain.cpp', [AOutputPath]);

      if not FileExists(LOutputFileName) then
      begin
        LMainOutput.Text := TestsMainQtCPP;
        LMainOutput.SaveToFile(LOutputFileName, TEncoding.UTF8);
      end;
    end;

  finally
    LDummyImplementation.Free;
    LMainHeaders.Free;
    LMainOutput.Free;
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

      LExactLineFound := False;
      if not LContinue then
      begin
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
      end;

      if not LContinue then
      begin
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

{ TScenarioInfo }

constructor TScenarioInfo.Create(AScenario: TScenario);
begin
  Scenario := AScenario;
  Steps := TList<TStepDef>.Create;
end;

destructor TScenarioInfo.Destroy;
begin
  Steps.Free;
  inherited;
end;

function TScenarioInfo.GetExamples: IDataTable;
begin
  if Scenario is TScenarioOutline then
    Result := TScenarioOutline(Scenario).Examples
  else
    Result := nil;
end;

var
  LanguageCode: String;
  OutputCode: String;
  OutputFramework: TProgrammingFramework;
  Features: TFeatureList;
begin
  try
    if ParamCount >= 2 then
    begin
      if ParamCount >= 3 then
        LanguageCode := ParamStr(3);

      if LanguageCode = '' then
        LanguageCode := 'EN';

      if ParamCount >= 4 then
        OutputCode := ParamStr(4);

      if OutputCode = '' then
        OutputCode := 'DELPHI' else
        OutputCode := UpperCase(OutputCode);

      if OutputCode = 'DELPHI' then
        OutputFramework := TProgrammingFramework.Delphi else
      if (OutputCode = 'QTC++') or (OutputCode = 'QTCPP') then
        OutputFramework := TProgrammingFramework.QtCPP else
        OutputFramework := TProgrammingFramework.Unknown;

      if OutputFramework = TProgrammingFramework.Unknown then
        raise Exception.CreateFmt('Unknown programming framework: "%s"', [OutputCode]);

      Features := ReadFeatures(ParamStr(1), True, LanguageCode, False);
      try
        CompileFeatures(ParamStr(2), LanguageCode, OutputFramework, Features);
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
      Halt(1);
    end;
  end;
end.
