unit DelphiSpec.Attributes;

interface

type
  TDelphiSpecAttribute = class(TCustomAttribute)
  protected
    FText: string;
  public
    constructor Create(const Text: string); reintroduce;

    property Text: string read FText;
  end;

  FeatureAttribute = class(TDelphiSpecAttribute);

  TDelphiSpecStepAttributeClass = class of TDelphiSpecStepAttribute;
  TDelphiSpecStepAttribute = class(TDelphiSpecAttribute)
  public
    constructor Create; overload;
    class function Prefix: string;
  end;

  Given_Attribute = class(TDelphiSpecStepAttribute);

  When_Attribute = class(TDelphiSpecStepAttribute);

  Then_Attribute = class(TDelphiSpecStepAttribute);

implementation

{ TDelphiSpecAttribute }

constructor TDelphiSpecAttribute.Create(const Text: string);
begin
  FText := Text;
end;

{ TDelphiSpecStepAttribute }

constructor TDelphiSpecStepAttribute.Create;
begin
end;

class function TDelphiSpecStepAttribute.Prefix: string;
begin
  Result := ClassName;
  SetLength(Result, Length(Result) - 9);
end;

end.
