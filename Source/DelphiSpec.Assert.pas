unit DelphiSpec.Assert;

interface

uses
  SysUtils;

type
  EDelphiSpecTestFailure = class(Exception);

  Assert = class
  private
    class function GetNotEqualsErrorMsg(Left, Right: string; Msg: string): string; static;
  public
    class procedure Fail(const Msg: string; ErrorAddress: Pointer = nil); static;

    class procedure IsFalse(const Value: Boolean; const Msg: string = ''); static;
    class procedure IsTrue(const Value: Boolean; const Msg: string = ''); static;

    class procedure AreEqual(const Expected, Actual: Integer; const Msg: string = ''); overload; static;
    class procedure AreEqual(const Expected, Actual: string; const Msg: string = ''); overload; static;
    class procedure AreEqual<T>(const Expected, Actual: T; const Msg: string); overload; static;
  end;

implementation

uses
  Generics.Defaults;

const
  IsNotEqualToFmt = '%s<%s> is not equal to <%s>';

{ Assert }

class procedure Assert.AreEqual(const Expected, Actual: Integer; const Msg: string);
begin
  if Expected <> Actual then
    Fail(GetNotEqualsErrorMsg(IntToStr(Expected), IntToStr(Actual), Msg), ReturnAddress);
end;

class procedure Assert.AreEqual(const Expected, Actual, Msg: string);
begin
  if Expected <> Actual then
    Fail(GetNotEqualsErrorMsg(Expected, Actual, Msg), ReturnAddress);
end;

class procedure Assert.AreEqual<T>(const Expected, Actual: T; const Msg: string);
var
  Comparer: IComparer<T>;
begin
  Comparer := TComparer<T>.Default;
  if Comparer.Compare(Expected, Actual) <> 0 then
    Fail(Msg, ReturnAddress);
end;

class procedure Assert.Fail(const Msg: string; ErrorAddress: Pointer);
begin
  if ErrorAddress <> nil then
    raise EDelphiSpecTestFailure.Create(Msg) at ErrorAddress
  else
    raise EDelphiSpecTestFailure.Create(Msg) at ReturnAddress;
end;

class function Assert.GetNotEqualsErrorMsg(Left, Right, Msg: string): string;
begin
  if Msg <> '' then
    Msg := Msg + ', ';

  Result := Format(IsNotEqualToFmt, [Msg, Left, Right])
end;

class procedure Assert.IsFalse(const Value: Boolean; const Msg: string);
begin
  if Value then
    Fail(GetNotEqualsErrorMsg('False', 'True', Msg), ReturnAddress);
end;

class procedure Assert.IsTrue(const Value: Boolean; const Msg: string);
begin
  if not Value then
    Fail(GetNotEqualsErrorMsg('True', 'False', Msg), ReturnAddress);
end;

end.
