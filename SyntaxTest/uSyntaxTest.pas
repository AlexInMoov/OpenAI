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
uses Classes;

//Function TransformString(strInput: String; log:TStringList): String;
function ProcessUserInput(strInput: String):String;
function TestAIML(FileName:String):String;
function TestTextFile(FileName:String):String;


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
  end;

  //����������������� �����. ������������ ������ ������ �������� � ��� ���������
  TPhrase = TList;

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

      function CompareGrammems(strGrammems:String): boolean;//��������� ������� ������� � �������

      constructor Create(const strWordForm,strPartOfSpeach,strGrammems: String);
  end;

  //����, ��������, ������ (������������������) ��������� "����-��������"
  TSyntaxPattern =class
    private
      FPatternElements:TList;
      FRootElement:TSyntaxPatternElement;
      function GetElementCount:integer;
      function GetElement(Index : Integer):TSyntaxPatternElement;
    public
      TrasformationFormula:string;
      property ElementCount:integer read GetElementCount;
      property Elements[Index : Integer]:TSyntaxPatternElement  read GetElement;  default;
      //���������� �������� � ������
      function AddElement(const strWordForm,strPartOfSpeach,strGrammems: String):integer;
      //������� ��������� ��������
      function SetRootElement(const strPartOfSpeach,strGrammems: String):integer;

      //������������  ����� (Phrase), �� ������������ ��������������� ������� (Pattern).
      function TestPhrase(Phrase:TPhrase;
                          var intMatchedWords, intUnmatchedWords:integer):boolean;

      //������������� ����� �� "����������" �������������
      function ProcessTrasformationFormula():string;
      constructor Create();
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

//��������� ������� ������� � �������
function TSyntaxPatternElement.CompareGrammems(strGrammems:String): boolean;
var i:integer;
begin
  result:=true;
  //�������� ��� "�����������" ������� �������� � ������
  //�������� ��� �� ������ ���������, ����� ���� ������� ������ ������������� ���������,
  //������ ���� �������� ������ �� ���������� � �������� �����, �������� ���� ������ ��,
  //� � ����� ��
  //� �������������, ���� � ���� ��� ����� ��������, ����� ���������� � ����� �.
  // ������ ���������, �������� ������ � ����. ��. ��������� � ����� �����.
   for i:=0 to Grammems.Count-1   do
   begin
     //�� ���������� �������� ������� (� ��� ��� ������� ������ � ��������� �������� ������)
     if Pos(Grammems[i] +',',strGrammems )=0 then
     begin
       result:=false;
       break;
     end
   end

end;

//TSyntaxPattern  - �������������� ������
constructor TSyntaxPattern.Create();
begin
  FPatternElements:=TList.create;
  FRootElement:=nil;
end;
function TSyntaxPattern.GetElementCount:integer;
begin
  Result:=FPatternElements.Count;
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
    WF:=Phrase[i];
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



//������������
constructor TWordForm.Create(const aWordForm: String);
var
     ParadigmCollection : IParadigmCollection;
     Paradigm : IParadigm;
     OneAncode, SrcAncodes : string;
     i,j : integer;
begin
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
    Paradigm := ParadigmCollection.Item[j];
    i:=1;

    SrcAncodes := Paradigm.SrcAncode;
    while  i < Length(SrcAncodes) do
    begin
      OneAncode := Copy(SrcAncodes,i,2);
      Lemma.Add ( Paradigm.Norm);
      PartOfSpeach.Add(RusGramTab.GetPartOfSpeechStr( RusGramTab.GetPartOfSpeech(OneAncode)));
      Grammems.Add(RusGramTab.GrammemsToStr( RusGramTab.GetGrammems(OneAncode) ));
      inc (i, 2);
    end;
  end;
end ;

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

//��������� ������� �� ����� ���������.
function ComparePatternLength(Item1, Item2: Pointer): Integer;
  begin

    Result :=0;
    if TSyntaxPattern(Item1).ElementCount> TSyntaxPattern(Item2).ElementCount  then
      Result :=-1;
    if TSyntaxPattern(Item1).ElementCount< TSyntaxPattern(Item2).ElementCount  then
      Result :=1;
  end;

//�������� ��� �������  - ����� � �������� ���������
function GetAllRuleList: TList;
var
  xml:IXMLDocument;
  PhraseNode,ElementNode:IXMLNode;
  PatternList: TList;
  Pattern: TSyntaxPattern;
  i,j:integer;
  strWord,strPartOfSpeach,strGrammems,Formula:string;

begin
  PatternList:=  TList.Create;
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
    PatternList.Add(Pattern);
  end;

  Result :=PatternList;
end;

function GetPhraseCategoryList(RightElement:TSyntaxPatternElement; AllRules:TList): TList;
var i:integer;
    PE:TSyntaxPatternElement;
begin
 Result:= TList.Create();
 //�������� ������ �������� �������������� �������� �������� ���������
  for i:=0 to AllRules.Count-1 do
  begin
    PE:=TSyntaxPattern(AllRules[i]).FRootElement;
    if PE<>nil then
      if (PE.PartOfSpeach=RightElement.PartOfSpeach) and (PE.Grammems.Text=RightElement.Grammems.Text)  then
        Result.Add(AllRules[i]);
  end;
end;

//������� ���� ���� ����������������. �� ����� j-�� �������� ����� ��������� �������
//����������������� ��������, � �� ��� ������ - ��������.
// strFormula  - ������� �����
// strElFormula - ������� ����������� ��������
// j - ����� ����������� ��������
function ModifyTransformationFormula(strFormula, strElFormula:String;N,M,j:integer):String;
var lstFormula:TStringList;
    i:integer;
begin
  //lstFormula:=Split(strFormula,' ');
  for i := N downto j+1 do
  begin
    strFormula:=StringReplace(strFormula, '#'+IntToStr(i)+' ', '#'+IntToStr(i+M-1)+' ', [rfReplaceAll]) ;
    strFormula:=StringReplace(strFormula, '#'+IntToStr(i)+'l', '#'+IntToStr(i+M-1)+'l', [rfReplaceAll]) ;
  end;

  //� ���������������� �������� 1 ���������� j, ��������� ����������� � j-� �������
  for i := M downto 1 do
  begin
    strElFormula:=StringReplace(strElFormula, '#'+IntToStr(i)+' ', '#'+IntToStr(j+i-1)+' ', [rfReplaceAll]) ;
    strElFormula:=StringReplace(strElFormula, '#'+IntToStr(i)+'l', '#'+IntToStr(j+i-1)+'l', [rfReplaceAll]) ;
  end;

  strFormula:=StringReplace(strFormula, '#'+IntToStr(j), strElFormula,[rfReplaceAll]) ;
  result:=strFormula;


  //result:=Join(lstFormula,' ');
end;

function GetPatternList(): TList;
var
  i,j,k,l:integer;
  AllRules:TList;
  Expansions:TList;
  NewPattern,CurrentPattern: TSyntaxPattern;
  blnNonTerminalElementsExist:boolean;
begin
  Result:= TList.Create();
  AllRules:= GetAllRuleList;

  //�������� ������ �������� (�.�. �������, ��������������� "�����": S->xxx)
  for i:=0 to AllRules.Count-1 do
  begin
    if TSyntaxPattern(AllRules[i]).FRootElement=nil then
      Result.Add(AllRules[i]);
  end;
  //��� �� �������� ������ ���� (S->xxx), ������� �������� � ��������,
  //�������������� �������

  //����� ����� �� ������ ���������� �������������� ������� � ������������
  //  �������� ����� �������.
  //  ����������� ��� ������� � ������. ���� �����������, ��� � ������� ���� ��������������
  //  �������, ��� ������� ���������, � ������ ��� ����������� N ��������� ������ ������� ��������,
  //  ������ � ���������� ������ �������.
  repeat

  blnNonTerminalElementsExist:=False;
  for i:=0 to Result.Count-1 do
  begin
    CurrentPattern:=TSyntaxPattern(Result[i]);
    for j:=0 to CurrentPattern.ElementCount-1  do
    begin
      //���� ���� ������� ���������
      if CurrentPattern.Elements[j].PartOfSpeach='��' then
      begin
        blnNonTerminalElementsExist:=True;
        //���� �������� �������, ��������������� ������ �������� ���������.
        Expansions:=GetPhraseCategoryList(TSyntaxPattern(Result[i]).Elements[j],AllRules);
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
        //���� ������� � ��������� �������
        break;
      end;//if �������������� �������
    end;
  end;
  Result.Pack;
  //��� ����� ����� ������� �� ������ �� �������, �������
  //(��������� ������������ �������� �������) �� ������������� �������� �����.

  //������� ��������� ����, ������ ��� � �������� ����� ��� ����������
  //�������������� ��������
  until Not blnNonTerminalElementsExist ;
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

  PatternList := GetPatternList();

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
      break;
    end
  end;

  //������ �������������� ����, ������ ����� �� �������� �� ���������  � ������ "�"
  // � �������������� ������.
  // (������� ��� ��� ����� �������� ��������� ������� ������), ��������� ������������� ���������,
  // � ������������ ����� ������� �������������� ������ ������������� (���� ���������).
  // ��� �� ������ ����� ����� �������� ���������. :)

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



  //4.
  //�������������� ������. �� ���� ����� �� ������ �������� ��������� ������, �������
  //�������� �������������� ��������� ����������� � �������� ����� � ������������
  //��������������� ���������� (�������������?)

  //�� ������� ������ ����� ���������� �������� ����������� ������.

   MatchedPattern:=SyntaxAnalysis(Phrase, intMatchedWords, intUnmatchedWords);

  //5. �������������
   if MatchedPattern <> nil then
     log.Add(MatchedPattern.ProcessTrasformationFormula);
   log.Add( IntToStr( intMatchedWords) +'/'+  IntToStr( intUnmatchedWords));

  //����� ���� ��� ����������.

  result:='';
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
  result:='xxx';
  SplittedPhrase.Free;
  Phrase.Free;

  MatchedPattern.Free;
End;

//' ������� �������
//' strInput - ���� ����������� � ����� ����
// ��������� ��� :)
function ProcessUserInput(strInput: String):String;
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
  log : TStringList;
  i:integer;
  strPhrase:string;
begin
  log:=TStringList.Create;

   // 1. ��������� �� �����������
  _SentenceSplitter:=TStringTokenizer.Create('.!?;');

  strInput:=  AnsiLowerCase (strInput) ;
  _SentenceSplitter.Tokenize(trim( strInput));
  //SplittedPhrase:= Tokenizer._tokens;
  for i:=0 to _SentenceSplitter._count-1 do
  begin
    strPhrase:=trim(_SentenceSplitter._tokens[i]);

    if strPhrase<>'' then
      TransformString(strPhrase,log);
  end;
  result:=Log.Text;
  log.Free;
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
           CurrentFile.Add(ProcessUserInput(MyXml.CurContent));
           CurrentFile.Add('');
        end;
    END;
  MyXml.Free;


  result:=   CurrentFile.Text;
end;
function TestTextFile(FileName:String):String;
var
  CurrentFile : TStringList;
  TextFile : TStringList;
  i:integer;
begin
  CurrentFile := TStringList.Create;

  TextFile:= TStringList.Create ;
  TextFile.LoadFromFile(FileName);

  for i := 0 to TextFile.Count-1  do
    begin
           CurrentFile.Add(TextFile[i]);
           CurrentFile.Add( ProcessUserInput(TextFile[i]));
           CurrentFile.Add('');

    END;
  TextFile.Free;


  result:=   CurrentFile.Text;
end;


//�������������  �������������.
var   hr :  HRESULT;
initialization
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
