unit uSyntaxTest;

//' ���� ������ - ��������� ����� (���� ������������) �� ����������� (������)
//' ����� �������� ���������� �� ������� ������ ������� �������� �������������� �������
//' ������ ��������� ��������� ������ ����� ��������� �������
//'
//' ��������� ����� �������� "������" ���������, �.�. �������� � *����������* ������ �����
//' (�� ���������, ��� ����������� "����� � �������")
//'
//' ����� ����, ��� ����� �������� ������ �� ���������� �������������, � ����� ��������������
//' (��������� �������� ������������ ������� (��� � �������� ^ ^) )
//
// ��������� - ��������� ����� �� ������, � ���� ������ �������� � ������ ������������� (�� ������� ��������)
// ����� ����� ���� ���������� � ���������, �� ������ �������� ����.

//  1. �� ������ ����� ����� ������� "�����" �� �����
//  2. �� ������ ����� ����� ��������� ������ (�����������) ��������������
//     ��������.  ��� ����� ����� ������������ ��������� �� AOT, �� ����� ��� ������.
//  3. �� ������� ����� ����� "�������� �������������� ������� �� ������� ������"

interface
uses Classes,IniFiles;

//Function TransformString(strInput: String; log:TStringList): String;
function ProcessUserInput(strInput: String; log:TStringList):String;
function TestAIML(FileName:String):String;

var
  g_WordformCount:integer;
  g_ElementCount:integer;
  g_PatternCount:integer;
implementation
uses  StrUtils, SysUtils,ActiveX,  LibXMLParser,  XMLDoc, XMLIntf,  UUtils,
LEMMATIZERLib_TLB,AGRAMTABLib_TLB;

type
 //  ����������
   TWordForm = class
    private
      function GetNumberOfVariants:integer;
    public
      WordForm:String;//����������, ������� ����� �� �����
      //�������� ����, � ������������� � �������
      //(������� ��������� �������������� ���������) ����� ���� ���������

      PartOfSpeach:TStringList;//����� ����
      Grammems:TStringList; // ��������, � ��������� ����
      Lemma:TStringList; //�������� ����� �����, �����

      property NumberOfVariants:integer read GetNumberOfVariants;
      constructor Create(const aWordForm: String);
      destructor Destroy; Override;
  end;

  //����������������� �����. ������������ ������ ������ �������� � ��� ���������
  TPhrase = TObjectList;

  //������� ��������������� �������.
  //�������� ��������, ��� ��� �� ��� ���� ��� "�������� ���������"
  //�������� ������� �������� ������� �� ���������� � ��� ��� �� ��������
  // ������������ ������� �������.
  TSyntaxPatternElement = class
      PartOfSpeach:String;//����� ����
      Grammems:TStringList; // ��������, � ��������� ����, �����������
      WordForm:String;//����������, ������� ����� ������ � ������� (� ����� � �� ������)

      //����������� ��������
      MatchedPartOfSpeach:String;//����� ����
      MatchedGrammems:String; // ��������, ����� �������
      MatchedWordForm:String;//����������
      MatchedLemma:String; // �����

      function isTerminalElement:boolean; //�������� �� ������ ������� ������������,
      //��� �� "�������� ����������"
      function CompareGrammems(strGrammems:String): boolean;overload;//��������� ������� ������� � �������
      function CompareGrammems(lstGrammems:TStringList): boolean; overload;

      constructor Create(const strWordForm,strPartOfSpeach,strGrammems: String);
      destructor Destroy; Override;
  end;

  //����, ��������, ������ (������������������) ��������� "����-��������"
  // �.�. ���������, ������� ��������� ����� ���� � ��������, � ����� ����� ���� �����
  TSyntaxPattern=class
    private
      FPatternElements:TList;
      FRootElement:TSyntaxPatternElement;
      FVariables:THashedStringList;
      function GetElementCount:integer;
      function GetElement(Index : Integer):TSyntaxPatternElement;
    public
      TrasformationFormula:string;
      property ElementCount:integer read GetElementCount;
      property Elements[Index : Integer]:TSyntaxPatternElement  read GetElement;  default;
      function ExplicitWordformCount:integer;
      //���������� �������� � ������
      function AddElement(const strWordForm,strPartOfSpeach,strGrammems: String):integer;
      //������� ��������� ��������
      function SetRootElement(const strPartOfSpeach,strGrammems: String):integer;

      //������������  ����� (Phrase), �� ������������ ��������������� ������� (Pattern).
      function TestPhrase(Phrase:TPhrase;
                          var intMatchedWords, intUnmatchedWords:integer):boolean;
      function SetVariableValue(VarName,VarValue:String):boolean;
      //������������� ����� �� "����������" �������������
      function ProcessTrasformationFormula():string;
      constructor Create();
      constructor CreateCopy(Source:TSyntaxPattern);
      destructor Destroy; override;
  end;

var
  RusLemmatizer : ILemmatizer;
  RusGramTab :    IGramTab;

//���������� ������ �� ����� �� �����������
function Split (str: String; strSeparator:String ):TStringList;
  var t:TStringList;
begin
  t:=TStringList.create; //������ �����
  t.text:=stringReplace(str,strSeparator,#13#10,[rfReplaceAll]);//�� �������� ��� ����������� �� ������� ����� ������
  result:= t;
end;
function min(a,b:integer):integer;
begin
  if a< b then
    Result:=a
  else
    Result:=b;
end;


//������� ��������������� �������
constructor TSyntaxPatternElement.Create(const strWordForm,strPartOfSpeach,strGrammems: String);
begin
  inherited Create;
  inc(g_ElementCount);
  if  (strWordForm<>'')and (strWordForm<>'*') then
    begin
      //������ ���������� �����
      WordForm:=strWordForm;
      PartOfSpeach:='';
      Grammems:=TStringList.Create;   // nil;
    end
  else
    begin
      WordForm:='*';
      PartOfSpeach:=strPartOfSpeach;
      Grammems:=Split(strGrammems,',') ;
    end;
end;

destructor TSyntaxPatternElement.Destroy;
begin
  Grammems.Free;
  dec(g_ElementCount);
  inherited Destroy;
end;

//��������� ������� ������� � �������
//�������� ��� "�����������" ������� �������� � ������
//��� �������� ������� ������� ������ �������������� � �������, ����� ���� �������� ����������
  //�������� ��� �� ������ ���������, ����� ���� ������� ������ ������������� ���������,
  //������ ���� �������� ������ �� ���������� � �������� �����, �������� ���� ������ ��,
  //� � ����� ��
  //� �������������, ���� � ���� ��� ����� ��������, ����� ���������� � ����� �.
  // ������ ���������, �������� ������ � ����. ��. ��������� � ����� �����.
function TSyntaxPatternElement.CompareGrammems(strGrammems:String): boolean;
var i:integer;
begin
  result:=true;
  for i:=0 to Grammems.Count-1   do
  begin
    //�� ���������� �������� ������� (� ��� ��� ������� ������ � ��������� �������� ������)
    if  Pos(Grammems[i] +',',strGrammems )=0 then
    begin
      result:=false;
      break;
    end
  end
end;

//�� �� �����, ������ �������� � ���� ������
function TSyntaxPatternElement.CompareGrammems(lstGrammems:TStringList): boolean;
var i:integer;
begin
  result:=true;
  for i:=0 to Grammems.Count-1   do
  begin
    //�� ���������� �������� ������� (� ��� ��� ������� ������ � ��������� �������� ������)
    if lstGrammems.IndexOf(Grammems[i])=-1 then
    begin
      result:=false;
      break;
    end;
  end;
end;

function TSyntaxPatternElement.isTerminalElement:boolean;
begin
  Result:=not ((PartOfSpeach='��')or (PartOfSpeach='��') );
end;

//TSyntaxPattern  - �������������� ������
constructor TSyntaxPattern.Create();
begin
  FPatternElements:=TList.Create;
  FRootElement:=nil;
  FVariables:=THashedStringList.Create;
  inc(g_PatternCount);
end;
constructor TSyntaxPattern.CreateCopy(Source:TSyntaxPattern);
var i:integer;
begin
  FPatternElements:=TList.Create;
  FVariables:=THashedStringList.Create;
  FRootElement:=nil;
  inc(g_PatternCount);
  //�������� ����������
  TrasformationFormula:= Source.TrasformationFormula;
  if Source.FRootElement<>nil then
    SetRootElement(Source.FRootElement.PartOfSpeach, Source.FRootElement.Grammems.Text);

  for i:= 0 to Source.ElementCount-1 do
    AddElement(Source[i].WordForm, Source[i].PartOfSpeach, Source[i].Grammems.text);

  FVariables.Text:=Source.FVariables.Text;
end;

destructor TSyntaxPattern.Destroy();
var i:integer;
begin
  //��������� �������� ������� ������� �������
  FRootElement.Free;
  //��������� �������� � ������ ������ ��������
  for i := 0 to FPatternElements.Count-1  do
    TSyntaxPatternElement(FPatternElements[i]).Free;
  FPatternElements.free;
  FVariables.Free;
  dec(g_PatternCount);
end;

function TSyntaxPattern.GetElementCount:integer;
begin
  Result:=FPatternElements.Count;
end;

function TSyntaxPattern.ExplicitWordformCount:integer;
var i:integer;
begin
  Result:=0;
  for i := 0 to ElementCount-1 do
  begin
    if Elements[i].WordForm<>'*' then
      inc(Result);
  end;
end;

function TSyntaxPattern.GetElement(index:integer):TSyntaxPatternElement;
begin
  Result:=FPatternElements[index];
end ;

function TSyntaxPattern.AddElement(const strWordForm,strPartOfSpeach,strGrammems: String):integer;
var
  aSyntaxPatternElement:TSyntaxPatternElement;
begin
  aSyntaxPatternElement := TSyntaxPatternElement.Create(strWordForm,strPartOfSpeach,strGrammems);
  Result:=FPatternElements.Add(aSyntaxPatternElement);
end;

function TSyntaxPattern.SetRootElement(const strPartOfSpeach,strGrammems: String):integer;
begin
  FRootElement:=TSyntaxPatternElement.Create('',strPartOfSpeach,strGrammems);
  Result:=0;
end;

//����� ������� �������� � ������ ������ - ����������� ������ ����������������
function TSyntaxPattern.ProcessTrasformationFormula():string;
var i: integer;
    tmp: String;
    token:String;
begin
  tmp:=TrasformationFormula;
  for i:=0 to ElementCount-1 do
  begin
    token:='#'+IntToStr(i+1)+'l';
    if Pos(token,tmp)<>0 then
      tmp:=StringReplace (tmp,token, Elements[i].MatchedLemma,[rfReplaceAll]) ;

    token:='#'+IntToStr(i+1);
    if Pos(token,tmp)<>0 then
      tmp:=StringReplace (tmp,token, AnsiUpperCase( Elements[i].MatchedWordForm),[rfReplaceAll]) ;
  end;
  Result:= tmp;
end;


//������������  ����� (Phrase), �� ������������ ��������������� ������� (Pattern).
//������������ �������������� � ������ �����.
//������������
// intMatchedWords   - ����� �������������� ���� � ������ �����
// intUnmatchedWords - ����� �� �������������� ���� � ������ �����
// ������� ���������� True, ���� ����� ������������� �������
function TSyntaxPattern.TestPhrase(Phrase:TPhrase;
                                   var intMatchedWords, intUnmatchedWords:integer):boolean;
var i,j:integer;
    PE:TSyntaxPatternElement ;
    WF: TWordForm;
    blnMatched:boolean;
begin
  intMatchedWords := 0;

  //���� � ����� �� ������ ����� � ������� ��������. ���� ������������ - �����.
  for i:=0 to min( self.ElementCount-1, Phrase.Count-1)    do
  begin
    PE:=self[i];
    //������ ���������� �������� ��� ����������� � ��� �� �������
    WF:=TWordForm(Phrase[i]);
    blnMatched:=False;
    for j:=0 to WF.NumberOfVariants-1  do
    begin
      if PE.WordForm<>'*' then
      begin
      //���������� �����
        if AnsiUpperCase(PE.WordForm)<>AnsiUpperCase(WF.WordForm) then
          continue;//������������ �� �������, ����� ������� � ���������� ��������
      end
      else
      begin
        //����� ����
        if (PE.PartOfSpeach<>'*') and (PE.PartOfSpeach <> WF.PartOfSpeach[j])  then
          continue;//������������ �� �������, ����� ������� � ���������� �������� ����������.

        //��������
        if not PE.CompareGrammems(WF.Grammems[j]) then
          continue;//������������ �� �������, ����� ������� � ���������� �������� ����������.
      end;

      blnMatched:=True;
      //������������ �������, ����� ������� � ���������� �����
      //(��������� ������������. ���� ����� ������������� �������, ����� ������ �������)

      PE.MatchedWordForm:= WF.WordForm;
      PE.MatchedPartOfSpeach:= WF.PartOfSpeach[j]  ;
      PE.MatchedGrammems:= WF.Grammems[j]  ;
      PE.MatchedLemma:= WF.Lemma[j] ;
      break;

    end;
    if blnMatched then
      intMatchedWords:=intMatchedWords + 1
    else
    begin
      //������ ���������� �� ������������� �������. ����� ��������
      break;

    end;
  end;
  Result := (self.ElementCount = intMatchedWords);
  intUnmatchedWords := Phrase.Count-intMatchedWords;
end;

function TSyntaxPattern.SetVariableValue(VarName,VarValue:String):boolean;
var
  i,j: Integer;
  procedure RemoveGrammem(Grammems:TStringList;value:String);
    var intIndex:integer;
  begin
    intIndex:= Grammems.IndexOf(value);
    if intIndex <>-1 then
    begin
      Grammems.delete(intIndex );
    end;

  end;
begin
  //������ ����� ������ ���������� �� ������
  FVariables.Delete(FVariables.IndexOfName(VarName));
  //�������� ����������  �� �������� �� ���� ���������
  for i := 0 to ElementCount-1 do
  begin

    for j := 0 to Elements[i].Grammems.Count-1 do
      Elements[i].Grammems[j]:=ReplaceStr(Elements[i].Grammems[j],VarName,VarValue);

    //������� ���������, ���������� �� �������� ���������� � ������ ������ ����
    //� ������� ����������
    if Elements[i].PartOfSpeach = '�' then
      begin
        RemoveGrammem(Elements[i].Grammems,'1�');
        RemoveGrammem(Elements[i].Grammems,'2�');
        RemoveGrammem(Elements[i].Grammems,'3�');
      end;
    if Elements[i].PartOfSpeach = '�' then
    begin
      if Elements[i].Grammems.IndexOf('���')<> -1 then
        begin
          RemoveGrammem(Elements[i].Grammems,'1�');
          RemoveGrammem(Elements[i].Grammems,'2�');
          RemoveGrammem(Elements[i].Grammems,'3�');
        end;
      if (Elements[i].Grammems.IndexOf('���')<> -1) or
         (Elements[i].Grammems.IndexOf('���')<> -1) or
         (Elements[i].Grammems.IndexOf('��')<> -1) then
        begin
          RemoveGrammem(Elements[i].Grammems,'��');
          RemoveGrammem(Elements[i].Grammems,'��');
          RemoveGrammem(Elements[i].Grammems,'��');
        end;
    end;
    //�������������� �� ������������� ����� ������ ����
    if (Elements[i].PartOfSpeach = '�') or
       (Elements[i].PartOfSpeach = '��-�') or
       (Elements[i].PartOfSpeach = '��_����')  then
    begin
      if (Elements[i].Grammems.IndexOf('��')<> -1) then
        begin
          RemoveGrammem(Elements[i].Grammems,'��');
          RemoveGrammem(Elements[i].Grammems,'��');
          RemoveGrammem(Elements[i].Grammems,'��');
        end;
    end;
  end;
  //� � ��� ����� � �������� ��������, ���� ����.
  if FRootElement<>nil then
    for j := 0 to  FRootElement.Grammems.Count-1 do
      FRootElement.Grammems[j]:=ReplaceStr(FRootElement.Grammems[j],VarName,VarValue);

end;

//������������
constructor TWordForm.Create(const aWordForm: String);
var
     ParadigmCollection : IParadigmCollection;
     Paradigm : IParadigm;
     OneAncode, SrcAncodes : string;
     i,j : integer;
     strLemma,strPartOfSpeach:string;
begin
  inc(g_WordformCount);
  WordForm:=aWordForm;
  Lemma:=TStringList.Create;
  Grammems:=TStringList.Create;
  PartOfSpeach:= TStringList.Create;
  ParadigmCollection := RusLemmatizer.CreateParadigmCollectionFromForm(aWordForm, 1, 1);
  if (ParadigmCollection.Count = 0) then
  begin
    Raise Exception.Create('�� ������� ��������� ��� ����� '+aWordForm);
  end;

  for j:=0 to ParadigmCollection.Count-1 do
  begin
    Paradigm:=nil;
    Paradigm := ParadigmCollection.Item[j];
    i:=1;

    SrcAncodes := Paradigm.SrcAncode;
    while  i < Length(SrcAncodes) do
    begin
      OneAncode := Copy(SrcAncodes,i,2);
      strLemma:=Paradigm.Norm;
      strPartOfSpeach:=RusGramTab.GetPartOfSpeechStr( RusGramTab.GetPartOfSpeech(OneAncode));
      if not((strLemma='��')and (strPartOfSpeach='�'))
      and not((strLemma='����')and (strPartOfSpeach='�')) then
      begin
        Lemma.Add(strLemma);
        PartOfSpeach.Add(strPartOfSpeach);
        Grammems.Add(RusGramTab.GrammemsToStr( RusGramTab.GetGrammems(OneAncode) ));
      end;
      inc (i, 2);
    end;
  end;
  ParadigmCollection:=nil;
  Paradigm:=nil;
end ;

destructor TWordForm.Destroy();
begin
  dec(g_WordformCount);
  PartOfSpeach.Free;
  Grammems.Free;
  Lemma.Free;
  inherited;
end;

function TWordForm.GetNumberOfVariants():integer;
begin
  result:=PartOfSpeach.Count;
end;


//2. ������������, ������������ �������  (�������������� ���������)
// ���� ���� ���� ���������� ���������� ��� ������������� ���������� �������� ������,
// (��������, "����" <- ����|����, ��� ������������ ���, ��������� �������������� ��������
// ��� ������ �� ������.
function Lemmatize(WordList:TStringList):TPhrase;
var i:integer;
    Phrase: TPhrase;

begin
  Phrase:= TPhrase.create;
  Phrase.OwnsObjects:= true;
  for i:=0 to WordList.Count-1 do
  begin

    Phrase.Add(TWordForm.Create(WordList[i]) );
  end;
  result:=Phrase;
end;

//C���������, ������ ��������, � �������� �� ����� ���������� ���� �����.
//������ �������� ���� ������, �� �����, ��� �� "����������� ����������",
//�� ����� �����.
// ��� ��������� ��� �����, ��������� ��������.
// ���� ������ ������ ���� ���������� �� "�������������", ����� ������� � ������.

//��������� �������  �� �������������.
// ������ �����������
//  1 - ����� ���������.
//  2 - ����� ���� �������� ���������
//  3 - ������ ����� ([.]) ������� ����������� �������� ([...])
function ComparePatternLength(Item1, Item2: Pointer): Integer;
var Pattern1,Pattern2:TSyntaxPattern;
begin
  Pattern1:=TSyntaxPattern(Item1);
  Pattern2:=TSyntaxPattern(Item2);

  //������ �������� ������
  Result :=0;
  if Pattern1.ElementCount> Pattern2.ElementCount  then
    Result :=-1;
  if Pattern1.ElementCount< Pattern2.ElementCount  then
    Result :=1;

  //�������� ����� ���� �������� ���������
  if Result=0 then
  begin
    if Pattern1.ExplicitWordformCount> Pattern2.ExplicitWordformCount  then
      Result :=-1;
    if Pattern1.ExplicitWordformCount< Pattern2.ExplicitWordformCount  then
      Result :=1;
  end;

  if Result=0 then
  begin
    //�������� �������
    if (Pos('[.]',Pattern1.TrasformationFormula)<>0) and (Pos('[.]',Pattern2.TrasformationFormula)=0)   then
      Result :=-1;
    if (Pos('[.]',Pattern1.TrasformationFormula)=0) and (Pos('[.]',Pattern2.TrasformationFormula)<>0)  then
      Result :=1;
  end;
  Pattern1:=nil;
  Pattern2:=nil;
end;

//�������� ��� ������� - ����� � �������� ���������
function GetAllRuleList: TObjectList;
var
  xml:IXMLDocument;
  PhraseNode,ElementNode,VarNode:IXMLNode;
  PatternList: TObjectList;
  Pattern: TSyntaxPattern;
  i,j:integer;
  strWord,strPartOfSpeach,strGrammems,Formula:string;
  varName,varValue:string;
begin
  PatternList:=TObjectList.Create;
  PatternList.OwnsObjects:=True;

  xml:=LoadXMLDocument('d:\OpenAI\_SRC\grammar.xml');//
 // xml.LoadFromFile();
  xml.Active:=True;

  for i := 0 to xml.DocumentElement.ChildNodes.Count-1 do
  if (xml.DocumentElement.ChildNodes[i].NodeName='Phrase') or
     (xml.DocumentElement.ChildNodes[i].NodeName='PhraseCategory') then
  begin
    Pattern:= TSyntaxPattern.Create;
    PhraseNode:=xml.DocumentElement.ChildNodes[i];
    strWord:= PhraseNode.NodeName;
    for j := 0 to PhraseNode.ChildNodes['Pattern'].ChildNodes.Count-1 do
    begin
      ElementNode:=PhraseNode.ChildNodes['Pattern'].ChildNodes[j];
      strWord:= ElementNode.ChildNodes['WordForm'].Text ;
      strPartOfSpeach:= ElementNode.ChildNodes['Category'].Text ;
      strGrammems:=ElementNode.ChildNodes['Grammems'].Text ;
      Pattern.AddElement( strWord,strPartOfSpeach,strGrammems );
    end;

    Pattern.TrasformationFormula:=PhraseNode.ChildNodes['TrasformationFormula'].Text;
    if (PhraseNode.NodeName='PhraseCategory') then
    begin
      ElementNode:=PhraseNode.ChildNodes['Def'];
      strPartOfSpeach:= ElementNode.ChildNodes['Category'].Text ;
      strGrammems:=ElementNode.ChildNodes['Grammems'].Text ;
      Pattern.SetRootElement (strPartOfSpeach,strGrammems );
    end;
    //������ ����������
    for j := 0 to PhraseNode.ChildNodes['Vars'].ChildNodes.Count-1 do
    begin
      VarNode:=PhraseNode.ChildNodes['Vars'].ChildNodes[j];
      varName:=VarNode.Attributes['Name'];
      varValue:=VarNode.Attributes['Values'];
      Pattern.FVariables.Add(varName +'='+varValue  );
    end;


    PatternList.Add(Pattern);
  end;

  Result :=PatternList;
  xml:=nil;
  PhraseNode:=nil;
  ElementNode:=nil;
  VarNode:=nil;
 end;

//������� ���������, �������������� "������ �����" ������� (RightElement).
//��� ����� ("S") RightElement - nil

function GetRuleListSubset(RightElement:TSyntaxPatternElement; AllRules:TList): TObjectList;
var i:integer;
    PE:TSyntaxPatternElement;
begin
  Result:= TObjectList.Create();
  Result.OwnsObjects:=True;
  //�������� ������ �������� ��������������� �������� �������� ���������
  for i:=0 to AllRules.Count-1 do
  begin
    PE:=TSyntaxPattern(AllRules[i]).FRootElement;
    if RightElement<>nil then
      begin
        if PE<>nil then
          if (PE.PartOfSpeach=RightElement.PartOfSpeach) and (RightElement.CompareGrammems( PE.Grammems))  then
            //� ������ ����������� �����(!) ��������� ��������
            Result.Add(TSyntaxPattern.CreateCopy(AllRules[i]));
      end
    else
      begin
        if PE=nil then
          //� ������ ����������� �����(!) ��������� ��������
          Result.Add(TSyntaxPattern.CreateCopy(AllRules[i]));
      end;
  end;
end;

//������� ���� ���� ����������������. �� ����� j-�� �������� ����� ��������� �������
//����������������� ��������, � �� ��� ������ - ��������.
// strFormula  - ������� �����
// strElFormula - ������� ����������� ��������
// j - ����� ����������� ��������
function ModifyTransformationFormula(strFormula, strElFormula:String;N,M,j:integer):String;
var //lstFormula:TStringList;
    i:integer;
begin
  if strElFormula='#2-��' then
    i:=0;

  //lstFormula:=Split(strFormula,' ');
  for i := N downto j+1 do
  begin
    strFormula:=StringReplace(strFormula, '#'+IntToStr(i)+' ', '#'+IntToStr(i+M-1)+' ', [rfReplaceAll]) ;
    strFormula:=StringReplace(strFormula, '#'+IntToStr(i)+'-', '#'+IntToStr(i+M-1)+'-', [rfReplaceAll]) ;
    strFormula:=StringReplace(strFormula, '#'+IntToStr(i)+'l', '#'+IntToStr(i+M-1)+'l', [rfReplaceAll]) ;
  end;

  strElFormula:=strElFormula+' ';
  //� ���������������� �������� 1 ���������� j, ��������� ����������� � j-� �������
  for i := M downto 1 do
  begin
    strElFormula:=StringReplace(strElFormula, '#'+IntToStr(i)+' ', '#'+IntToStr(j+i-1)+' ', [rfReplaceAll]) ;
    strElFormula:=StringReplace(strElFormula, '#'+IntToStr(i)+'-', '#'+IntToStr(j+i-1)+'-', [rfReplaceAll]) ;
    strElFormula:=StringReplace(strElFormula, '#'+IntToStr(i)+'l', '#'+IntToStr(j+i-1)+'l', [rfReplaceAll]) ;
  end;
  strElFormula:=trim(strElFormula);

  strFormula:=StringReplace(strFormula, '#'+IntToStr(j), strElFormula,[rfReplaceAll]) ;
  result:=strFormula;


  //result:=Join(lstFormula,' ');
end;

Procedure ExpandVariables(PatternList: TObjectList);
var
  VarName:String;
  VarValue:TStringList;
  blnNonTerminalElementsExist:boolean;
  NewPattern,CurrentPattern: TSyntaxPattern;
  i,j:integer;
begin
  //����� ���������������� ����������
  repeat
  blnNonTerminalElementsExist:=False;
  for i:=0 to PatternList.Count-1 do
  begin
    CurrentPattern:=TSyntaxPattern(PatternList[i]);
    if CurrentPattern.FVariables.Count<>0   then
    begin
      blnNonTerminalElementsExist:=True;
      //����� ������ ����������
      //��� ������� �������� ����������
       //������� ����� ������
       VarName:=CurrentPattern.FVariables.Names[0];
       VarValue:=Split(CurrentPattern.FVariables.Values[VarName],',');
       for j := 0 to VarValue.Count-1 do
       begin
         NewPattern:=TSyntaxPattern.CreateCopy(CurrentPattern);
         NewPattern.SetVariableValue(VarName,VarValue[j]);
         PatternList.Add(NewPattern);
       end;
       //���� �� ������� �� ������
       PatternList.Delete(i);
       VarValue.Free;
    end;
  end;
  until Not blnNonTerminalElementsExist ;
end;

function GetPatternList(intMaxElements:integer): TObjectList;
var
  i,j,k,l:integer;
  AllRules:TObjectList;
  Expansions:TObjectList;
  NewPattern,CurrentPattern: TSyntaxPattern;
  blnNonTerminalElementsExist:boolean;
begin

  AllRules:= GetAllRuleList;
  ExpandVariables(AllRules);

  //�������� ������ �������� (�.�. �������, ��������������� "�����": S->xxx)
  Result:=GetRuleListSubset(nil,AllRules);
  //��� �� �������� ������ ���� (S->xxx), ������� �������� � ��������,
  //�������������� �������



  //����� ����� �� ������ ���������� �������������� ������� � ������������
  // �������� ����� �������.
  //  ����������� ��� ������� � ������. ���� �����������, ��� � ������� ����
  //  �������������� �������, ��� ������� ���������, � ������ ��� �����������
  //  N ��������� ������ ������� ��������, ������ � ���������� ������ �������.
  //  ������� �����������, ���� ��� �������������� �������� �� ����� ��������
  //  �� ������������
  repeat

  blnNonTerminalElementsExist:=False;
  for i:=0 to Result.Count-1 do
  begin
    CurrentPattern:=TSyntaxPattern(Result[i]);
    for j:=0 to CurrentPattern.ElementCount-1  do
    begin
      //���� ���� ������� ���������
      if not CurrentPattern.Elements[j].isTerminalElement  then
      begin

        //���� �������� �������, ��������������� ������ �������� ���������.
        Expansions:=GetRuleListSubset(TSyntaxPattern(Result[i]).Elements[j],AllRules);
        if Expansions.Count>0 then
        begin
        blnNonTerminalElementsExist:=True; //��� ��������� �������, � ������� �������� ������.
        for k := 0 to Expansions.Count-1  do
        begin
          NewPattern:=TSyntaxPattern.Create;
          for l := 0 to j-1 do
            NewPattern.AddElement(CurrentPattern[l].WordForm, CurrentPattern[l].PartOfSpeach, CurrentPattern[l].Grammems.text);

          for l := 0 to TSyntaxPattern(Expansions[k]).ElementCount-1  do
            NewPattern.AddElement(TSyntaxPattern(Expansions[k])[l].WordForm, TSyntaxPattern(Expansions[k])[l].PartOfSpeach, TSyntaxPattern(Expansions[k])[l].Grammems.text);


          for l := j+1 to CurrentPattern.ElementCount-1 do
            NewPattern.AddElement(CurrentPattern[l].WordForm,
                                  CurrentPattern[l].PartOfSpeach,
                                  CurrentPattern[l].Grammems.text);
          //������� ���� ���� ����������������. �� ����� j-�� �������� ����� ��������� �������
          //����������������� ��������, � �� ��� ������ - ��������.
          NewPattern.TrasformationFormula:=
          ModifyTransformationFormula(CurrentPattern.TrasformationFormula,
                                      TSyntaxPattern(Expansions[k]).TrasformationFormula,
                                      CurrentPattern.ElementCount,
                                      TSyntaxPattern(Expansions[k]).ElementCount,
                                      j+1 ) ;
          Result.Add(NewPattern);
        end; //�� �� ��������� ������������� ������� ��������.

        //����� ������������� �������� ������� ���������.
        Result.Delete(i);
        end;
        //�������� ���� ������ �� �����
        Expansions.Free;
        //���� ������� � ��������� �������
        break;
      end;//if �������������� �������
    end;
  end;
  Result.Pack;
  //��� ����� ����� ������� �� ������ �� �������, �������
  //(��������� ������������ �������� �������) �� ������������� �������� �����.
    //������ ������� ������� �������
    // ��� ����� ������� ������ ��� � ��� ���������� �� �����������
  for i:=Result.Count-1 downto 0  do
    if TSyntaxPattern(Result[i]).ElementCount>intMaxElements  then
     Result.Delete(i);


  Result.Pack;
  //������� ��������� ����, ������ ��� � �������� ����� ��� ����������
  //�������������� ��������
  until Not blnNonTerminalElementsExist ;

  //������
  AllRules.Free;
end;

//�������������� ������.
// - ������� ��������� �����,
//   � ���������� ����������� ������ � ����� ��������� ���� � ������ �����.
function SyntaxAnalysis(Phrase: TPhrase; var intMatchedWords, intUnmatchedWords:integer): TSyntaxPattern;
var
//  Pattern,Pattern2,Pattern3: TSyntaxPattern;
  PatternList: TList;
  i:integer;
begin

  //C������ ����� ������ ��������, ������� �� ����� ���������
  //(������ ����)

  PatternList := GetPatternList(Phrase.Count);

  //�������� � �����, ������� �� �������� �����������
  PatternList.sort(ComparePatternLength);
  Result:=nil;
  //� ���� ������������� ����� �� ������������ ������ ��������������� �������.
  for i:=0 to PatternList.Count-1 do
  begin
    if TSyntaxPattern(PatternList[i]).TestPhrase(Phrase, intMatchedWords, intUnmatchedWords) then
    begin
      //C����������� �������
      Result:= PatternList[i];

      //��������� ������ ��������� �� ������
      PatternList.Extract(Result);
      break;
    end
  end;

  //������ ������
  PatternList.Free;
end;

//��������� �������������� ����
//����� ������� �������������� ��������� ����� �����, ��������� ���������������
// ����� � �������� �������.
// ���������
// ���������� ����� � �����.
// - ���� ����� �������� ���� ������� � �������������� ������, ������ ����� ������.
// - ���� �������������� ������ ��� ������, ��������� (�����������) ����� �����,
//   ������ �� �������������� ��� ��� ������
// - ���� ������ ��� ������ (�.�. ��������� �����), ���������, ������ �� ����������� ��� �����
//   � ������.
// - ���� ������ �� ����� ������� ������, ���������� ����� � ������� � ����������.
// �.� �� ������ ������������ ��������� ����� � ��������.
 //������ �������������� ����, ������ ����� �� �������� �� ���������  � ������ "�"
  // � �������������� ������.
  // (������� ��� ��� ����� �������� ��������� ������� ������), ��������� ������������� ���������,
  // � ������������ ����� ������� �������������� ������ ������������� (���� ���������).
  // ��� �� ������ ����� ����� �������� ���������. :)

function SyntaxAnalysis2(Phrase: TPhrase; var intMatchedWords, intUnmatchedWords:integer): TSyntaxPattern;
var i:integer;
begin
  //����� �� ������������, ��� �������������� �������� ��������, � �� ����� ���� � �����
  //��������� ������������.  ���� ����� ���� ��������, � ����� ����� ����� � �������.
  for i:=0 to Phrase.Count-1 do
  begin

  end;

end;


Function TransformString(strInput:String; log:TStringList):String;
  var SplittedPhrase:TStringList;
      i,j:integer;
      Phrase: TPhrase;

      MatchedPattern: TSyntaxPattern;

      tmp: String;
      intMatchedWords, intUnmatchedWords:integer;
begin
  result:='';
  // 2. ��������� �� �����
  SplittedPhrase:= Split(strInput,' ');

  //3. ���������� ����������� �������������� ���������
// ���� ���� ���� ���������� ���������� ��� ������������� ���������� �������� ������,
// (��������, "����" <- ����|����, ��� ������������ ���, ��������� �������������� ��������
// ��� ������ �� ������.
//�� ���� ����� ��� ����� �������� ����� ��������� (Phrase), � ������� ����� �����������
//����� �������� �����, ������ � ���������������� �� ���������� (��������������� ���������� )
// � ������� (��������� �������)

  Phrase:=Lemmatize(SplittedPhrase);

  if TWordForm(Phrase[0]).WordForm='�' then
    Phrase.Delete(0);

  if TWordForm(Phrase[0]).WordForm='��' then
    Phrase.Delete(0);

  if TWordForm(Phrase[0]).WordForm='�' then
    Phrase.Delete(0);

  //4.
  //�������������� ������. �� ���� ����� �� ������ �������� ��������� ������, �������
  //�������� �������������� ��������� ����������� � �������� ����� � ������������
  //��������������� ���������� (�������������?)

  //�� ������� ������ ����� ���������� �������� ����������� ������.

   MatchedPattern:=SyntaxAnalysis(Phrase, intMatchedWords, intUnmatchedWords);

  //5. �������������
   if MatchedPattern <> nil then
     result:= MatchedPattern.ProcessTrasformationFormula;

  //����� ���� ��� ����������.
   log.Add(result);
   log.Add( IntToStr( intMatchedWords) +'/'+  IntToStr( intUnmatchedWords));


  for i:=0 to Phrase.Count-1 do
  begin
    log.add(TWordForm(Phrase[i]).WordForm+':');
    tmp:='';
    tmp:=tmp+(' {');
    for j:=0 to TWordForm(Phrase[i]).Lemma.Count-1 do
    begin
      tmp:=tmp+(' '+TWordForm(Phrase[i]).Lemma[j]);
      tmp:=tmp+(' '+TWordForm(Phrase[i]).PartOfSpeach [j]);
      tmp:=tmp+(' '+TWordForm(Phrase[i]).Grammems[j]);
      tmp:=tmp+(';')
    end;
    tmp:=tmp+' }';
    log.add(tmp);
  end;
  SplittedPhrase.Free;
  Phrase.Free;

  MatchedPattern.Free;
End;

//' ������� �������
//' strInput - ���� ����������� � ����� ����
// ��������� ��� :)
function ProcessUserInput(strInput: String; log:TStringList):String;
//��������� ��������.
// 1. ������� ���� ������������.
// 2. ������� �� ������������ �� ������ ����������. '.!?;'
// 3. ������ �� ����������� ��������������:
//      - �������� ��� �������������� ������, �������� ����������� �������������.
//      - �� ������ �������������� ��������� �������� �������������  ������� �����������
//          � ���� ����������� ������������� (���).
//4. ������������ ����� ����������� �� ��� �������������� ������ (� ����� :) )
var
  _SentenceSplitter:TStringTokenizer;
  i:integer;
  strPhrase:string;
begin
   // 1. ��������� �� �����������
  _SentenceSplitter:=TStringTokenizer.Create('.!?;');

  strInput:=AnsiLowerCase(strInput);
  _SentenceSplitter.Tokenize(trim(strInput));
  //SplittedPhrase:= Tokenizer._tokens;
  result:='';
  for i:=0 to _SentenceSplitter._count-1 do
  begin
    strPhrase:=trim(_SentenceSplitter._tokens[i]);

    if strPhrase<>'' then
      result:=result+TransformString(strPhrase,log)+' ';
  end;
  result:=trim(result);
  _SentenceSplitter.Free;
end;

//�������� ������������ Aiml ��������
//� ��������, ��� ���������� ������ <pattern>...</pattern>
function TestAIML(FileName:String):String;
var
  CurrentFile : TStringList;
  MyXml : TXmlParser;
begin
  CurrentFile := TStringList.Create;

  MyXml := TXmlParser.Create;
  MyXml.LoadFromFile (FileName);

  MyXml.StartScan;
  WHILE MyXml.Scan DO
    CASE MyXml.CurPartType OF

      ptContent, ptCData:
        if AnsiLowerCase (MyXml.CurName) ='pattern' then
        begin
           CurrentFile.Add(MyXml.CurContent);
           ProcessUserInput(MyXml.CurContent, CurrentFile);
           CurrentFile.Add('');
        end;
    END;
  MyXml.Free;


  result:=   CurrentFile.Text;
end;

//�������������  �������������.
var   hr :  HRESULT;
initialization
  g_WordformCount:=0;
  g_ElementCount:=0;
  g_PatternCount:=0;
try
   // hr := CoInitialize(nil);
    if (hr <> S_OK) then
    begin
       // writeln('cannot load Component Object Model(COM) library');
      //  halt(1);
    end;
     // loading morphological dicitonary
    RusLemmatizer := CoLemmatizerRussian.Create;
    if  (RusLemmatizer = nil) then
    begin
        //writeln('cannot load lemmatizer');
        halt(1);
    end;
    RusLemmatizer.LoadDictionariesRegistry();
    // loading table of gram-codes
    RusGramTab := CoRusGramTab.Create;
    if  (RusGramTab = nil) then
    begin
        writeln('cannot load table for grammatical codes');
        halt(1);
    end;
    RusGramTab.Load;

except
   // writeln('an exception occurred!');
end;

finalization
  CoUninitialize();
end.
