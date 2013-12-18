unit DelphiSpec.Attributes;

interface

type
  TDelphiSpecAttributeClass = class of TDelphiSpecAttribute;
  TDelphiSpecAttribute = class(TCustomAttribute)
  protected
    FText: string;
  public
    constructor Create(const Text: string); reintroduce;

    property Text: string read FText;
  end;

  _FeatureAttribute = class(TDelphiSpecAttribute);

  _GivenAttribute = class(TDelphiSpecAttribute);

  _WhenAttribute = class(TDelphiSpecAttribute);

  _ThenAttribute = class(TDelphiSpecAttribute);

implementation

{ TDelphiSpecAttribute }

constructor TDelphiSpecAttribute.Create(const Text: string);
begin
  inherited Create;
  FText := Text;
end;

end.
