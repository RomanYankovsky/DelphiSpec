unit SampleAccountsStepDefs;

interface

uses
  Generics.Collections, DelphiSpec.Attributes, DelphiSpec.StepDefinitions;

type
  [Feature('accounts')]
  TSampleAccountSteps = class(TStepDefinitions)
  private type
    TUserInfo = record
      Name: string;
      Password: string;
      Id: Integer;
    end;
  private
    FUsers: TList<TUserInfo>;
    FAccessGranted: Boolean;
  public
    procedure SetUp; override;
    procedure TearDown; override;

    procedure Given_users_exists(Table: TArray<TUserInfo>);

    [When_('I login with "(.*)" and "(.*)"')]
    procedure TryLogin(const Name, Password: string);

    procedure Then_I_have_access_to_private_messages;
    procedure Then_Access_Denied;
  end;

implementation

uses
  DelphiSpec.Core, TestFramework;

{ TSampleAccountSteps }

procedure TSampleAccountSteps.Given_users_exists(Table: TArray<TUserInfo>);
var
  I: Integer;
begin
  for I := Low(Table) to High(Table) do
    FUsers.Add(Table[I]);
end;

procedure TSampleAccountSteps.SetUp;
begin
  FUsers := TList<TUserInfo>.Create;
  FAccessGranted := False;
end;

procedure TSampleAccountSteps.TearDown;
begin
  FUsers.Free;
end;

procedure TSampleAccountSteps.Then_Access_Denied;
begin
  if FAccessGranted then
    raise ETestFailure.Create('Access granted!');
end;

procedure TSampleAccountSteps.Then_I_have_access_to_private_messages;
begin
  if not FAccessGranted then
    raise ETestFailure.Create('Access denied');
end;

procedure TSampleAccountSteps.TryLogin(const Name, Password: string);
var
  I: Integer;
begin
  for I := 0 to FUsers.Count - 1 do
    if (FUsers[I].Name = Name) and (FUsers[I].Password = Password) then
    begin
      FAccessGranted := True;
      Break;
    end;
end;

initialization
  RegisterStepDefinitionsClass(TSampleAccountSteps);

end.
