unit DelphiSpec.Core;

interface

uses
  DelphiSpec.StepDefinitions;

function GetStepDefinitionsClass(const Name: string): TStepDefinitionsClass;
procedure RegisterStepDefinitionsClass(StepDefinitionsClass: TStepDefinitionsClass);

implementation

uses
  SysUtils, Rtti, Generics.Collections, DelphiSpec.Attributes;

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

initialization
  __StepDefsClassList := TDictionary<string, TStepDefinitionsClass>.Create;

finalization
  __StepDefsClassList.Free;

end.
