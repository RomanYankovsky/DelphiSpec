unit SampleAccountsStepDefs;

interface

uses
  Generics.Collections
, DelphiSpec.StepDefinitions;

type
  TAccountsTestContext = class(TStepDefinitions)
  protected type
    TUserInfo = class
    public
      Name: string;
      Password: string;
      Id: Integer;
    end;
  protected
    FName, FPassword: string;
    FUsers: TObjectList<TUserInfo>;
    FAccessGranted: Boolean;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  end;

implementation

uses
  System.SysUtils
, DelphiSpec.Core
, DelphiSpec.Assert
, DelphiSpec.Parser
, DelphiSpec.Attributes;

{$I accountsTest.inc}

{ TAccountsTestContext }

procedure TAccountsTestContext.SetUp;
begin
  FUsers := TObjectList<TUserInfo>.Create;
  FAccessGranted := False;
end;

procedure TAccountsTestContext.TearDown;
begin
  FreeAndNil(FUsers);
end;

{ TAccountsTest }

procedure TAccountsTest.Given_my_name_is_value(const value: String);
begin
  FName := value;
end;

procedure TAccountsTest.Given_my_password_is_value(const value: String);
begin
  FPassword := value;
end;

procedure TAccountsTest.Given_users_exist(const data: TArray<t_data>);
var
  I: Integer;
  LUserInfo: TUserInfo;
begin
  for I := Low(data) to High(data) do
  begin
    LUserInfo := TUserInfo.Create;
    with data[I] do
    begin
      LUserInfo.Name := name;
      LUserInfo.Password := password;
      LUserInfo.Id := id;
    end;
    FUsers.Add(LUserInfo);
  end;
end;

procedure TAccountsTest.Given_user_value_has_been_removed(const value: String);
var
  I: Integer;
begin
  for I := 0 to FUsers.Count - 1 do
    if FUsers[I].Name = value then
    begin
      FUsers.Delete(I);
      Break;
    end;
end;

procedure TAccountsTest.Then_access_denied;
begin
  Assert.IsFalse(FAccessGranted, 'Access granted');
end;

procedure TAccountsTest.Then_I_have_access_to_private_messages;
begin
  Assert.IsTrue(FAccessGranted, 'Access denied');
end;

procedure TAccountsTest.When_I_login;
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
  RegisterAccountsTest;
end.
