unit CommonHelper;
{$mode delphi}
interface

uses sysutils, windows;

type

{ FZCommonHelper }

 FZCommonHelper = class
  public
    class function GetGameTickCount():cardinal;
    class function GetEnglishUppercaseChar(low:char):char;
    class function GetEnglishCharFromRussian(rus:char):char;
    class function GetNextParam(var data:string; var buf:string; separator:char=char($00)):boolean;
    class function GetLastParam(var data:string; var buf:string; separator:char=char($00)):boolean;
    class function GetTimeDeltaSafe(starttime:cardinal):cardinal;
    class function StrToPort(port:string):integer;
    class function GetCurTime():string;
    class function GetCurDate():string;
    class function GetVolSN():string;
    class function HexToInt(hex:string; default:cardinal=0):cardinal;
    class function TryHexToInt(hex:string; var out_val:cardinal):boolean;
end;

const
fz_protocol_ver:string='FZ3.0';


implementation

class function FZCommonHelper.GetNextParam(var data:string; var buf:string; separator:char=char($00)):boolean;
var p, i:integer;
begin
  p:=0;
  for i:=1 to length(data) do begin
    if data[i]=separator then begin
      p:=i;
      break;
    end;
  end;

  if p>0 then begin
    buf:=leftstr(data, p-1);
    data:=rightstr(data, length(data)-p);
    result:=true;
  end else result:=false;
end;

class function FZCommonHelper.GetLastParam(var data:string; var buf:string; separator:char=char($00)):boolean;
var p, i:integer;
begin
  p:=0;
  for i:=length(data) downto 1 do begin
    if data[i]=separator then begin
      p:=i;
      break;
    end;
  end;

  if p>0 then begin
    buf:=rightstr(data, length(data)-p);
    data:=leftstr(data, p-1);
    result:=true;
  end else result:=false;
end;

class function FZCommonHelper.StrToPort(port:string):integer;
begin
  result:=strtointdef(port, -1);
  if (result<-1) or (result>65535) then result:=-1;
end;


class function FZCommonHelper.GetVolSN():string;
var
  VolumeName,
  FileSystemName : array [0..MAX_PATH-1] of Char;
  VolumeSerialNo : DWord;
  MaxComponentLength, FileSystemFlags : dword;
begin
  MaxComponentLength:=0;
  FileSystemFlags:=0;
  VolumeName[0]:=CHR(0);
  FileSystemName[0]:=CHR(0);
  GetVolumeInformation(nil,
      VolumeName,
      MAX_PATH,
      @VolumeSerialNo,
      MaxComponentLength,
      FileSystemFlags,
      FileSystemName,
      MAX_PATH);
 result:=IntToHex(VolumeSerialNo,8);
end;

class function FZCommonHelper.GetTimeDeltaSafe(starttime:cardinal):cardinal;
var
  curtime:cardinal;
begin
  curtime:=GetGameTickCount;
  result:=curtime-starttime;
  //���������� ������������
  if result>curtime then result:=$FFFFFFFF-starttime+curtime;
end;

class function FZCommonHelper.GetCurTime():string;
var
  st:_SYSTEMTIME;
begin
  FillMemory(@st, sizeof(st), 0);
  GetLocalTime(st);
  if st.wHour<10 then result:='0' else result:='';
  result:=result+inttostr(st.wHour)+'-';
  if st.wMinute<10 then result:=result+'0';
  result:=result+inttostr(st.wMinute)+'-';
  if st.wSecond<10 then result:=result+'0';
  result:=result+inttostr(st.wSecond);
end;

class function FZCommonHelper.GetCurDate():string;
var
  st:_SYSTEMTIME;
begin
  FillMemory(@st, sizeof(st), 0);
  GetLocalTime(st);
  if st.wDay<10 then result:='0' else result:='';
  result:=result+inttostr(st.wDay)+'.';
  if st.wMonth<10 then result:=result+'0';
  result:=result+inttostr(st.wMonth)+'.';
  result:=result+inttostr(st.wYear);
end;

class function FZCommonHelper.GetEnglishCharFromRussian(rus: char): char;
begin
  case rus of
    '�': result:='a';
    '�': result:='b';
    '�': result:='v';
    '�': result:='g';
    '�': result:='d';
    '�': result:='e';
    '�': result:='e';
    '�': result:='j';
    '�': result:='z';
    '�': result:='i';
    '�': result:='i';    
    '�': result:='k';
    '�': result:='l';
    '�': result:='m';
    '�': result:='n';
    '�': result:='o';
    '�': result:='p';
    '�': result:='r';
    '�': result:='s';
    '�': result:='t';
    '�': result:='u';
    '�': result:='f';
    '�': result:='h';
    '�': result:='c';
    '�': result:='4';
    '�': result:='s';
    '�': result:='s';
    '�': result:='_';
    '�': result:='i';
    '�': result:='6';
    '�': result:='e';
    '�': result:='u';
    '�': result:='a';
       
    '�': result:='A';
    '�': result:='B';
    '�': result:='V';
    '�': result:='G';
    '�': result:='D';
    '�': result:='E';
    '�': result:='E';
    '�': result:='J';
    '�': result:='Z';
    '�': result:='I';
    '�': result:='I';
    '�': result:='K';
    '�': result:='L';
    '�': result:='M';
    '�': result:='N';
    '�': result:='O';
    '�': result:='P';
    '�': result:='R';
    '�': result:='S';
    '�': result:='T';
    '�': result:='U';
    '�': result:='F';
    '�': result:='H';
    '�': result:='C';
    '�': result:='4';
    '�': result:='S';
    '�': result:='S';
    '�': result:='_';
    '�': result:='I';
    '�': result:='6';
    '�': result:='E';
    '�': result:='U';
    '�': result:='J';
  else
    result:='_';
  end;
end;

class function FZCommonHelper.GetGameTickCount: cardinal;
begin
  result:=GetTickCount;
  if result=0 then result:=1;
end;

class function FZCommonHelper.GetEnglishUppercaseChar(low: char): char;
begin
  case low of
    'a':result:='A';
    'b':result:='B';
    'c':result:='C';
    'd':result:='D';
    'e':result:='E';
    'f':result:='F';
    'g':result:='G';
    'h':result:='H';
    'i':result:='I';
    'j':result:='J';
    'k':result:='K';
    'l':result:='L';
    'm':result:='M';
    'n':result:='N';
    'o':result:='O';
    'p':result:='P';
    'q':result:='Q';
    'r':result:='R';
    's':result:='S';
    't':result:='T';
    'u':result:='U';
    'v':result:='V';
    'w':result:='W';
    'x':result:='X';
    'y':result:='Y';
    'z':result:='Z';
  else
    result:=low;
  end;
end;

class function FZCommonHelper.HexToInt(hex: string; default:cardinal=0): cardinal;
var
  i: integer; //err code
  r: Int64;   //result
begin
  val('$'+trim(hex),r, i);
  if i<>0 then
    result := default
  else
    result := cardinal(r);
end;

class function FZCommonHelper.TryHexToInt(hex: string; var out_val: cardinal): boolean;
var
  i: integer; //err code
  r: Int64;   //result
begin
  val('$'+trim(hex),r, i);
  if i<>0 then begin
    result := false;
  end else begin
    result := true;
    out_val:=cardinal(r);
  end;
end;

end.
