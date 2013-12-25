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
    FName, FPassword: string;
    FUsers: TList<TUserInfo>;
    FAccessGranted: Boolean;
  public
    procedure SetUp; override;
    procedure TearDown; override;

    procedure Given_users_exist(Table: TArray<TUserInfo>);

    [Given_('my name is "(.*)"')]
    procedure EnterName(const Value: string);

    [Given_('my password is "(.*)"')]
    procedure EnterPassword(const Value: string);

    [Given_('user "(.*)" has been removed')]
    procedure RemoveUser(const Name: string);

    procedure When_I_login;

    procedure Then_I_have_access_to_private_messages;
    procedure Then_Access_Denied;
  end;

implementation

uses
  DelphiSpec.Core, TestFramework;

{ TSampleAccountSteps }

procedure TSampleAccountSteps.EnterName(const Value: string);
begin
  FName := Value;
end;

procedure TSampleAccountSteps.EnterPassword(const Value: string);
begin
  FPassword := Value;
end;

procedure TSampleAccountSteps.Given_users_exist(Table: TArray<TUserInfo>);
var
  I: Integer;
begin
  for I := Low(Table) to High(Table) do
    FUsers.Add(Table[I]);
end;

procedure TSampleAccountSteps.RemoveUser(const Name: string);
var
  I: Integer;
begin
  for I := 0 to FUsers.Count - 1 do
    if (FUsers[I].Name = FName) then
    begin
      FUsers.Delete(I);
      Break;
    end;
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

procedure TSampleAccountSteps.When_I_login;
var
  I: Integer;
begin
  for I := 0 to FUsers.Count - 1 do
    if (FUsers[I].Name = FName) and (FUsers[I].Password = FPassword) then
    begin
      FAccessGranted := True;
      Break;
    end;
end;

initialization
  RegisterStepDefinitionsClass(TSampleAccountSteps);

end.
