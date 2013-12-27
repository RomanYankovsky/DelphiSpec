unit DelphiSpec.DataTable;

interface

uses
  SysUtils, Classes, Generics.Collections;

type
  IDataTable = interface
    function GetColumns(const Name: string): TStrings;
    function GetRowCount: Integer;
    function GetColCount: Integer;
    function GetName(I: Integer): string;

    property Columns[const Name: string]: TStrings read GetColumns; default;
    property Names[I: Integer]: string read GetName;
    property RowCount: Integer read GetRowCount;
    property ColCount: Integer read GetColCount;
  end;

  EDataTableException = class(Exception);
  TDataTable = class(TInterfacedObject, IDataTable)
  private
    FColNames: TStringList;
    FColByIndex: TObjectList<TStringList>;
    FColByName: TDictionary<string, TStringList>;
    function GetColumns(const Name: string): TStrings;
    function GetName(I: Integer): string;
    function GetRowCount: Integer;
    function GetColCount: Integer;
  public
    constructor Create(const ColNames: array of string); reintroduce;
    destructor Destroy; override;

    procedure AddRow(const Values: array of string);

    property Columns[const Name: string]: TStrings read GetColumns; default;
    property Names[I: Integer]: string read GetName;
    property RowCount: Integer read GetRowCount;
    property ColCount: Integer read GetColCount;
  end;

implementation

{ TDataTable }

procedure TDataTable.AddRow(const Values: array of string);
var
  I: Integer;
begin
  if Length(Values) <> FColByIndex.Count then
    raise EDataTableException.Create('Column count mismatch');

  for I := 0 to High(Values) do
    FColByIndex[I].Add(Values[I]);
end;

constructor TDataTable.Create(const ColNames: array of string);
var
  I: Integer;
  Row: TStringList;
begin
  inherited Create;
  FColNames := TStringList.Create;
  FColByIndex := TObjectList<TStringList>.Create(True);
  FColByName := TDictionary<string, TStringList>.Create;

  for I := Low(ColNames) to High(ColNames) do
  begin
    Row := TStringList.Create;
    FColByIndex.Add(Row);
    FColByName.Add(AnsiLowerCase(ColNames[I]), Row);
    FColNames.Add(ColNames[I]);
  end;
end;

destructor TDataTable.Destroy;
begin
  FColNames.Free;
  FColByName.Free;
  FColByIndex.Free;
  inherited;
end;

function TDataTable.GetColCount: Integer;
begin
  Result := FColNames.Count;
end;

function TDataTable.GetColumns(const Name: string): TStrings;
begin
  Result := FColByName[AnsiLowerCase(Name)];
end;

function TDataTable.GetRowCount: Integer;
begin
  Result := FColByIndex[0].Count;
end;

function TDataTable.GetName(I: Integer): string;
begin
  Result := FColNames[I];
end;

end.
