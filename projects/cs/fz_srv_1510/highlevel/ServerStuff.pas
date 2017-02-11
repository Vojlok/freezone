unit ServerStuff;

{$mode delphi}

interface
uses Servers, Packets, PureServer, Clients,NET_common;

type
FZServerState = record
  lock:TRTLCriticalSection;
  mapname:string;
  mapver:string;
  maplink:string;
end;


procedure xrGameSpyServer_constructor_reserve_zerogameid(srv:pxrServer); stdcall;
function game_sv_GameState__OnEvent_CheckHit(src_id:cardinal; dest_id:cardinal; packet:pNET_Packet; senderid:cardinal):boolean; stdcall;
function game__OnEvent_SelfKill_Check(target:pxrClientData; senderid:cardinal):boolean; stdcall;
function CheckKillMessage(p:pNET_Packet; sender_id:cardinal):boolean; stdcall;
function CheckHitMessage(p:pNET_Packet; sender_id:cardinal):boolean; stdcall;

function game_sv_mp__OnPlayerHit_preventlocal(victim:pgame_PlayerState; hitter:pgame_PlayerState):boolean; stdcall;
procedure game_sv_mp__OnPlayerKilled_preventlocal(victim:pgame_PlayerState; hitter:ppgame_PlayerState; weaponid:pword; specialkilltype:pbyte); stdcall;

procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;

function Init():boolean; stdcall;
procedure Clean(); stdcall;

implementation
uses LogMgr, dynamic_caster, basedefs, sysutils, Hits, ConfigCache, Windows;

var
  _serverstate:FZServerState;

procedure xrGameSpyServer_constructor_reserve_zerogameid(srv:pxrServer); stdcall;
begin
  FZLogMgr.Get.Write('Reserving zero game ID');
  CID_Generator__tfGetID.Call([@srv.m_tID_Generator, 0]);
end;

function game__OnEvent_SelfKill_Check(target:pxrClientData; senderid:cardinal):boolean; stdcall;
var
  local_cl:pxrClientData;
begin
  local_cl:=GetServerClient();
  if (local_cl = nil) or (local_cl.base_IClient.ID.id = senderid) then begin
    result:=true;
    exit;
  end;

  fzlogmgr.get.write('Player '+PChar(@target.ps.name[0])+' wants to die');
  result:=(target.base_IClient.ID.id = senderid);
end;

function CheckKillMessage(p:pNET_Packet; sender_id:cardinal):boolean; stdcall;
var
  cld:pxrClientData;
  killer_id:word;
  target_id:word;
begin
  result:=false;

  //GAME_EVENT_PLAYER_KILLED имеет право отправлять только локальный клиент!
  cld:=GetServerClient();
  if (cld = nil) or (cld.base_IClient.ID.id <> sender_id) then begin
    fzlogmgr.get.write('Player id='+inttostr(sender_id)+' tried to send GAME_EVENT_PLAYER_KILLED message!', true);
    exit;
  end;

  //кроме того, локальный клиент не может быть убийцей либо быть убит!
  killer_id:=pword(@p.B.data[p.r_pos+3])^;
  target_id:=pword(@p.B.data[p.r_pos])^;
  FZLogMgr.Get.Write('Killer id = '+inttostr(killer_id)+', victim id = '+inttostr(target_id));


  if (cld.ps.GameID = killer_id) or (cld.ps.GameID = target_id) then begin
    FZLogMgr.Get.Write('Local player cannot be victim or killer!', true);
    exit;
  end;

  result:=true;
end;

function GetNameFromClientdata(cld:pxrClientData):string;
begin
  if cld = nil then begin
    result := '(null)';
  end else begin
    result:= cld.ps.name;
  end;
end;

function CheckHitMessage(p:pNET_Packet; sender_id:cardinal):boolean; stdcall;
var
  cld, victim, hitter:pxrClientData;
  killer_id:word;
  target_id:word;
  weapon_id:word;
  health_dec:single;
  victim_str, hitter_str:string;
begin
  result:=false;

  //GAME_EVENT_PLAYER_HITTED имеет право отправлять только локальный клиент!
  cld:=GetServerClient();
  if (cld = nil) or (cld.base_IClient.ID.id <> sender_id) then begin
    fzlogmgr.get.write('Player id='+inttostr(sender_id)+' tried to send GAME_EVENT_PLAYER_HITTED message!', true);
    exit;
  end;

  //кроме того, локальный клиент не может быть убийцей либо быть убит!
  killer_id:=pword(@p.B.data[p.r_pos+2])^;
  target_id:=pword(@p.B.data[p.r_pos])^;
  health_dec:=psingle(@p.B.data[p.r_pos+4])^;
  if (cld.ps.GameID = killer_id) or (cld.ps.GameID = target_id) then begin
    FZLogMgr.Get.Write('Local player cannot be victim or hitter!', true);
    exit;
  end else begin
    victim:=nil;
    hitter:=nil;
    ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @target_id, @victim);
    ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @killer_id, @hitter);

    victim_str := GetNameFromClientdata(victim);
    hitter_str := GetNameFromClientdata(hitter);

    FZLogMgr.Get.Write('Hitter '+hitter_str+' (id='+inttostr(killer_id)+'), victim = '+victim_str+' (id='+inttostr(target_id)+'), health dec = '+floattostr(health_dec));
  end;

  result:=true;
end;

function game_sv_GameState__OnEvent_CheckHit(src_id:cardinal; dest_id:cardinal; packet:pNET_Packet; senderid:cardinal):boolean; stdcall;
var
  cld, victim, hitter:pxrClientData;
  hit:SHit;
  hit_stat_mode:cardinal;
  fmt:TFormatSettings;
  victim_str, hitter_str:string;
begin
//  FZLogMgr.Get.Write('hit by '+inttostr(senderid));

  result:=false;


  cld:=GetServerClient();
  if cld = nil then begin
    FZLogMgr.Get.Write('No local player in OnHit!', true);
    result:=true;
    exit;
  end;

  if cld.base_IClient.ID.id<>senderid then begin
    //Хит отправлен не локальным клиентом.
    //Проверяем, что хит нам отправил сам отправитель, а не кто-то левый
    LockServerPlayers();
    try
      hitter:=nil;
      ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @src_id, @hitter);
      if hitter=nil then begin
        FZLogMgr.Get.Write('Hit from unexistent client???', true);
        exit;
      end;

      if hitter.ps.GameID<>src_id then begin
        FZLogMgr.Get.Write('Player id='+inttostr(senderid)+' sent not own hit!!!', true);
        exit;
      end;
    finally
      UnLockServerPlayers();
    end;
  end;

  //локальный игрок может отправлять хиты от окружающей среды, но не может быть хиттером или жертвой
  result:= not ((cld.ps.GameID = src_id) or (cld.ps.GameID = dest_id));
  if not result then begin
    if (cld.ps.GameID = src_id) then begin
      FZLogMgr.Get.Write('Local player makes hit? Rejecting!', true);
    end else if (cld.ps.GameID = dest_id) then begin
      FZLogMgr.Get.Write('Local player has been hitted? Rejecting!', true);
    end;
  end else begin
    ReadHitFromPacket(packet, @hit);

    victim:=nil;
    hitter:=nil;
    ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @dest_id, @victim);
    ForEachClientDo(AssignFoundClientDataAction, OneGameIDSearcher, @src_id, @hitter);

    hit_stat_mode:=FZConfigCache.Get.GetDataCopy.hit_statistics_mode;
    if hit_stat_mode = 1 then begin
      //Пишем стату по всем хитам, прилетающим в клиента
      victim_str := GetNameFromClientdata(victim);
      hitter_str := GetNameFromClientdata(hitter);

      FZLogMgr.Get.Write( hitter_str+'->'+victim_str+
                          ' (T='+inttostr(hit.hit_type)+
                          ', P='+floattostrf(hit.power, ffFixed,4,2)+
                          ', I='+floattostrf(hit.impulse, ffFixed,4,2)+
                          ', B='+inttostr(hit.boneID)+
                          ')');

      //todo:анализ хита
    end;
  end;
end;

procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;
begin
  EnterCriticalSection(_serverstate.lock);
  _serverstate.mapname:=PChar(@gdd.map_name[0]);
  _serverstate.mapver:=PChar(@gdd.map_version[0]);
  _serverstate.maplink:=PChar(@gdd.download_url[0]);
  LeaveCriticalSection(_serverstate.lock);
  FZLogMgr.Get.Write('Mapname updated: '+_serverstate.mapname+', '+_serverstate.mapver);
end;

procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
begin
  EnterCriticalSection(_serverstate.lock);
  name:=_serverstate.mapname;
  ver:=_serverstate.mapver;
  link:=_serverstate.maplink;
  LeaveCriticalSection(_serverstate.lock);
end;

procedure game_sv_mp__OnPlayerKilled_checkkiller(victim:pxrClientData; pkiller:ppxrClientData); stdcall;
var
  killer:pxrClientData;
begin
  if (pkiller<>nil) then begin
    killer:=pkiller^;
    if (killer<>nil) then begin
      if killer.base_IClient.flags and ICLIENT_FLAG_LOCAL<>0 then begin
        pkiller^ := victim;
      end;
    end;
  end;
end;

function game_sv_mp__OnPlayerHit_preventlocal(victim:pgame_PlayerState; hitter:pgame_PlayerState):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=false;
  cld:=GetServerClient();

  if (cld<>nil) and (hitter<>nil) and (cld.ps = hitter) then begin
    result:=true;
  end;

end;

procedure game_sv_mp__OnPlayerKilled_preventlocal(victim:pgame_PlayerState; hitter:ppgame_PlayerState; weaponid:pword; specialkilltype:pbyte); stdcall;
var
  cld:pxrClientData;
begin
  cld:=GetServerClient();

  if (cld<>nil) and (hitter<>nil) and (cld.ps = hitter^) then begin
    hitter^:=victim;
    specialkilltype^:=SPECIAL_KILL_TYPE__SKT_NONE;
    weaponid^:=$FFFF;
  end;
end;

function Init():boolean; stdcall;
begin
  result:=true;
  InitializeCriticalSection( _serverstate.lock );
end;

procedure Clean(); stdcall;
begin
  DeleteCriticalSection( _serverstate.lock );
end;

end.

