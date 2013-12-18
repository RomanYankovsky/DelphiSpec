unit DelphiSpec.StepDefinitions;

interface

type
  TStepDefinitionsClass = class of TStepDefinitions;
  TStepDefinitions = class
  public
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  end;

implementation

{ TStepDefinitions }

procedure TStepDefinitions.SetUp;
begin
  // nothing
end;

procedure TStepDefinitions.TearDown;
begin
  // nothing
end;

end.
