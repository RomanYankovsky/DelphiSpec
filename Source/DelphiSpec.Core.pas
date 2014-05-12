unit DelphiSpec.Core;

interface

uses
  Generics.Collections, DelphiSpec.StepDefinitions, DelphiSpec.Scenario;

function ReadFeatures(const Path: string; Recursive: Boolean; const LangCode: string): TObjectList<TFeature>;

function GetStepDefinitionsClass(const Name: string): TStepDefinitionsClass;
procedure RegisterStepDefinitionsClass(StepDefinitionsClass: TStepDefinitionsClass);
function CheckStepClassExists(const Name: string): Boolean;

implementation

uses
  SysUtils, IOUtils, Rtti, DelphiSpec.Attributes, DelphiSpec.Parser;

const
  FileMask = '*.feature';

var
  __StepDefsClassList: TDictionary<string, TStepDefinitionsClass>;

procedure RegisterStepDefinitionsClass(StepDefinitionsClass: TStepDefinitionsClass);
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  RttiAttr: TCustomAttribute;
begin
  __StepDefsClassList.Add(AnsiLowerCase(StepDefinitionsClass.ClassName), StepDefinitionsClass);

  RttiContext := TRttiContext.Create;
  try
    RttiType := RttiContext.GetType(StepDefinitionsClass);

    for RttiAttr in RttiType.GetAttributes do
      if RttiAttr is FeatureAttribute then
        __StepDefsClassList.Add(AnsiLowerCase(FeatureAttribute(RttiAttr).Text), StepDefinitionsClass);
  finally
    RttiContext.Free;
  end;
end;

function GetStepDefinitionsClass(const Name: string): TStepDefinitionsClass;
begin
  Result := __StepDefsClassList[AnsiLowerCase(Name)];
end;

function CheckStepClassExists(const Name: string): Boolean;
begin
  Result:=
    __StepDefsClassList.ContainsKey( AnsiLowerCase(Name) );
end;

function ReadFeatures(const Path: string; Recursive: Boolean; const LangCode: string): TObjectList<TFeature>;
var
  FileName: string;
  Parser: TDelphiSpecParser;
  SearchMode: TSearchOption;
begin
  if Recursive then
    SearchMode := TSearchOption.soAllDirectories
  else
    SearchMode := TSearchOption.soTopDirectoryOnly;

  Result := TObjectList<TFeature>.Create(True);
  try
    Parser := TDelphiSpecParser.Create(LangCode);
    try
      for FileName in TDirectory.GetFiles(Path, FileMask, SearchMode) do
      try
        Parser.Execute(FileName, Result);
      except
        on E: EDelphiSpecSyntaxError do
          raise Exception.CreateFmt('Syntax error: line %d at %s', [E.LineNo, FileName]);
        on E: EDelphiSpecUnexpectedEof do
          raise Exception.CreateFmt('Unexpected end of file at %s', [FileName]);
        on E: EDelphiSpecClassNotFound do
          raise Exception.CreateFmt('Class not implemented for feature %s in the file %s', [E.FeatureName, FileName]);
      end;
    finally
      Parser.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

initialization
  __StepDefsClassList := TDictionary<string, TStepDefinitionsClass>.Create;

finalization
  __StepDefsClassList.Free;

end.
