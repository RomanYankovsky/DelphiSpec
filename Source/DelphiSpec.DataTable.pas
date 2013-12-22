unit DelphiSpec.DataTable;

interface

uses
  SysUtils, Classes, Generics.Collections;

type
  IDelphiSpecDataTable = interface
    function GetColumns(const Name: string): TStrings;
    function GetCount: Integer;
    property Columns[const Name: string]: TStrings read GetColumns; default;
    property Count: Integer read GetCount;
  end;

  EDelphiSpecDataTableException = class(Exception);
  TDelphiSpecDataTable = class(TInterfacedObject, IDelphiSpecDataTable)
  private
    FColByIndex: TObjectList<TStringList>;
    FColByName: TDictionary<string, TStringList>;
    function GetColumns(const Name: string): TStrings;
    function GetCount: Integer;
  public
    constructor Create(const ColNames: array of string); reintroduce;
    destructor Destroy; override;

    procedure AddRow(const Values: array of string);

    property Columns[const Name: string]: TStrings read GetColumns; default;
    property Count: Integer read GetCount;
  end;

implementation

{ TDelphiSpecDataTable }

procedure TDelphiSpecDataTable.AddRow(const Values: array of string);
var
  I: Integer;
begin
  if Length(Values) <> FColByIndex.Count then
    raise EDelphiSpecDataTableException.Create('Column count mismatch');

  for I := 0 to High(Values) do
    FColByIndex[I].Add(Values[I]);
end;

constructor TDelphiSpecDataTable.Create(const ColNames: array of string);
var
  I: Integer;
  Row: TStringList;
begin
  inherited Create;
  FColByIndex := TObjectList<TStringList>.Create(True);
  FColByName := TDictionary<string, TStringList>.Create;

  for I := Low(ColNames) to High(ColNames) do
  begin
    Row := TStringList.Create;
    FColByIndex.Add(Row);
    FColByName.Add(AnsiLowerCase(ColNames[I]), Row);
  end;
end;

destructor TDelphiSpecDataTable.Destroy;
begin
  FColByName.Free;
  FColByIndex.Free;
  inherited;
end;

function TDelphiSpecDataTable.GetColumns(const Name: string): TStrings;
begin
  Result := FColByName[AnsiLowerCase(Name)];
end;

function TDelphiSpecDataTable.GetCount: Integer;
begin
  Result := FColByIndex[0].Count;
end;

end.
