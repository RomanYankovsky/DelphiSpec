unit DelphiSpec.DataTable;

interface

uses
  SysUtils, Classes, Generics.Collections;

type
  IDataTable = interface
    function GetRowCount: Integer;
    function GetColCount: Integer;
    function GetValue(Col, Row: Integer): string;

    property Values[Col, Row: Integer]: string read GetValue; default;
    property RowCount: Integer read GetRowCount;
    property ColCount: Integer read GetColCount;
  end;

  EDataTableException = class(Exception);
  TDataTable = class(TInterfacedObject, IDataTable)
  private
    FColumns: TObjectList<TStringList>;
    function GetRowCount: Integer;
    function GetColCount: Integer;
    function GetValue(Col, Row: Integer): string;
  public
    constructor Create(const ColCount: Integer); reintroduce;
    destructor Destroy; override;

    procedure AddRow(const Values: array of string);

    property Values[Col, Row: Integer]: string read GetValue; default;
    property RowCount: Integer read GetRowCount;
    property ColCount: Integer read GetColCount;
  end;

implementation

{ TDataTable }

procedure TDataTable.AddRow(const Values: array of string);
var
  I: Integer;
begin
  if Length(Values) <> FColumns.Count then
    raise EDataTableException.Create('Column count mismatch');

  for I := 0 to High(Values) do
    FColumns[I].Add(Values[I]);
end;

constructor TDataTable.Create(const ColCount: Integer);
var
  I: Integer;
begin
  inherited Create;
  FColumns := TObjectList<TStringList>.Create(True);

  for I := 0 to ColCount - 1 do
    FColumns.Add(TStringList.Create);
end;

destructor TDataTable.Destroy;
begin
  FColumns.Free;
  inherited;
end;

function TDataTable.GetColCount: Integer;
begin
  Result := FColumns.Count;
end;

function TDataTable.GetRowCount: Integer;
begin
  Result := FColumns[0].Count;
end;

function TDataTable.GetValue(Col, Row: Integer): string;
begin
  Result := FColumns[Col][Row];
end;

end.
