unit SampleCalculator;

interface

uses
  Generics.Collections;

type
  TCalculator = class
  private
    FData: TStack<Integer>;
    FValue: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Add;
    procedure Mul;
    procedure Push(Value: Integer);

    property Value: Integer read FValue;
  end;

implementation

{ TCalculator }

procedure TCalculator.Add;
var
  I: Integer;
begin
  FValue := 0;
  for I := 0 to FData.Count - 1 do
    FValue := FValue + FData.Pop;
end;

constructor TCalculator.Create;
begin
  inherited;
  FData := TStack<Integer>.Create;
end;

destructor TCalculator.Destroy;
begin
  FData.Free;
  inherited;
end;

procedure TCalculator.Mul;
var
  I: Integer;
begin
  FValue := 1;
  for I := 0 to FData.Count - 1 do
    FValue := FValue * FData.Pop;
end;

procedure TCalculator.Push(Value: Integer);
begin
  FData.Push(Value);
end;

end.
