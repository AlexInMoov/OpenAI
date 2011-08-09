unit uSyntaxTest;

interface
uses Classes;

Function TransformString(strInput: String): String;


implementation
uses  StrUtils, SysUtils,ActiveX,
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
      function GetElementCount:integer;
      function GetElement(Index : Integer):TSyntaxPatternElement;
    public
      TrasformationFormula:string;
      property ElementCount:integer read GetElementCount;
      property Elements[Index : Integer]:TSyntaxPatternElement  read GetElement;  default;
      function AddElement(const strWordForm,strPartOfSpeach,strGrammems: String):integer; //���������� �������� � ������

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
  if  strWordForm<>'' then
    begin
      //������ ���������� �����
      WordForm:=strWordForm;
      PartOfSpeach:='';
      Grammems:=nil; //TStringList.Create;
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
  //������ ���� �������� ������ �� ���������� � �������� �����, �������� ���� ������ ��, � � ����� ��
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
      tmp:=StringReplace (tmp,token, Elements[i].MatchedWordForm,[rfReplaceAll]) ;
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
        if PE.WordForm<>WF.WordForm then
          continue;//������������ �� �������, ����� ������� � ���������� ��������
      end
      else
      begin
        //����� ����
        if PE.PartOfSpeach <> WF.PartOfSpeach[j]  then
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
    writeln('not found');
    exit;
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

function SyntaxAnalysis(Phrase: TPhrase; var intMatchedWords, intUnmatchedWords:integer): TSyntaxPattern;
var
  Pattern,Pattern2,Pattern3: TSyntaxPattern;
  PatternList: TList;
  i:integer;
begin
  //C������ ����� ������ ��������, ������� �� ����� ���������
  PatternList:=  TList.Create;
  //���� ���� ����
  Pattern:= TSyntaxPattern.Create;
  Pattern.AddElement( '','�','��' );
  Pattern.AddElement( '','�','' );
  Pattern.AddElement( '','�','��' );
  Pattern.TrasformationFormula:='#1l [���] #3l [����] #2 [.]';
  PatternList.Add(Pattern);

   // ����  ���� ����
  Pattern2:= TSyntaxPattern.Create;

  Pattern2.AddElement( '','�','��' );
  Pattern2.AddElement( '','�','' );
  Pattern2.AddElement( '','�','��' );

  Pattern2.TrasformationFormula:='#3l [���] #1l [����] #2 [.]';
  PatternList.Add(Pattern2);

  //�������� ���������� �������
  Pattern3:= TSyntaxPattern.Create;

  Pattern3.AddElement( '','�','���' );
  Pattern3.AddElement( '����������','','' );
  Pattern3.AddElement( '','�','��' );

  Pattern3.TrasformationFormula:='#2 [.] #3l [����] #1 [.]';
  PatternList.Add(Pattern3);


  //�������� � �����, ������� �� �������� �����������
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

  PatternList.Free;
end;

//' ������� �������
//' strInput - ������� ������, �������������� ��� ��� "��������������"
// (�� ��� ������� ������� � ����. �������)
Function TransformString(strInput: String): String;
  var SplittedPhrase:TStringList;
      i,j:integer;
      Phrase: TPhrase;

      MatchedPattern: TSyntaxPattern;
      log : TStringList;
      tmp: String;
      intMatchedWords, intUnmatchedWords:integer;
begin


  log:=TStringList.Create;

  // 1. ��������� �� �����
  SplittedPhrase:= Split(trim(strInput),' ');

//2. ���������� ����������� �������������� ���������
// ���� ���� ���� ���������� ���������� ��� ������������� ���������� �������� ������,
// (��������, "����" <- ����|����, ��� ������������ ���, ��������� �������������� ��������
// ��� ������ �� ������.
//�� ���� ����� ��� ����� �������� ����� ��������� (Phrase), � ������� ����� �����������
//����� �������� �����, ������ � ���������������� �� ���������� (��������������� ���������� )
// � ������� (��������� �������)

  Phrase:=Lemmatize(SplittedPhrase);


  //3.
  //�������������� ������. �� ���� ����� �� ������ �������� ��������� ������, �������
  //�������� �������������� ��������� ����������� � �������� ����� � ������������
  //��������������� ���������� (�������������?)

  //�� ������� ������ ����� ���������� �������� ����������� ������.

   MatchedPattern:=SyntaxAnalysis(Phrase, intMatchedWords, intUnmatchedWords);

  //4. �������������
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
  result:=Log.Text;
  SplittedPhrase.Free;
  Phrase.Free;
  log.Free;
  MatchedPattern.Free;
End;


//�������������  �������������.
var   hr :  HRESULT;
initialization
try
    hr := CoInitialize(nil);
    if (hr <> S_OK) then
    begin
       // writeln('cannot load Component Object Model(COM) library');
        halt(1);
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
