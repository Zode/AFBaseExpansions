Hats hats;

void Hats_Call()
{
	hats.RegisterExpansion(hats);
}

class Hats : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Zode";
		this.ExpansionName = "Hats";
		this.ShortName = "HATS";
	}
	
	void ExpansionInit()
	{
		RegisterCommand("say hat", "s", "(hatname/menu/off) - set hat, show menu or take hat off.", ACCESS_Z, @Hats::hat, true, true); // always supress, uses workaround for now
		RegisterCommand("hat_force", "ss", "(target(s)) (hatname/off) - force hat.. or take it away!", ACCESS_U, @Hats::forcehat, true);
		g_Hooks.RegisterHook(Hooks::Player::PlayerSpawn, @Hats::PlayerSpawn);
		@Hats::g_cvarSuppressChat = CCVar("hats_suppresschat", 0, "0/1 Suppress player chat when using plugin.", ConCommandFlag::AdminOnly);
		@Hats::g_cvarSuppressInfo = CCVar("hats_suppressinfo", 0, "0/1 Suppress info chat from plugin.", ConCommandFlag::AdminOnly);
	}
	
	void MapInit()
	{
		Hats::g_hatModels.deleteAll();
		Hats::ReadHats();
		array<string> hatNames = Hats::g_hatModels.getKeys();
		for(uint i = 0; i < hatNames.length(); i++)
		{
			Hats::HatData@ hData = cast<Hats::HatData@>(Hats::g_hatModels[hatNames[i]]);
			g_Game.PrecacheModel("models/"+hData.sModelPath+".mdl");
		}
		
		Hats::g_hatUsers.deleteAll();
		if(@Hats::hatMenu !is null)
		{
			Hats::hatMenu.Unregister();
			@Hats::hatMenu = null;
		}
		
		array<string> hatUsers = Hats::g_hatCrossover.getKeys();
		for(uint i = 0; i < hatUsers.length(); i++)
		{
			Hats::HatCrossover@ cData = cast<Hats::HatCrossover@>(Hats::g_hatCrossover[hatUsers[i]]);
			cData.iCount = cData.iCount+1;
			cData.bCounted = false;
			Hats::g_hatCrossover[hatUsers[i]] = cData;
			if(cData.iCount >= 3)
				Hats::g_hatCrossover.delete(hatUsers[i]);
		}
	}
	
	void PlayerDisconnectEvent(CBasePlayer@ pPlayer)
	{
		Hats::removehat(pPlayer, true);
	}
	
	void StopEvent()
	{
		CBasePlayer@ pSearch = null;
		for(int i = 1; i <= g_Engine.maxClients; i++)
		{
			@pSearch = g_PlayerFuncs.FindPlayerByIndex(i);
			if(pSearch !is null)
			{
				string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pSearch));
				if(sFixId == "")
					continue;
				
				if(Hats::g_hatUsers.exists(sFixId))
				{
					Hats::removehat(pSearch, true);
				}
			}
		}
	}
}

namespace Hats
{
	dictionary g_hatUsers;
	dictionary g_hatModels;
	string g_hatsFile = "scripts/plugins/AFBaseExpansions/hatmodels.txt";
	CTextMenu@ hatMenu = null;
	dictionary g_hatCrossover;
	CCVar@ g_cvarSuppressChat;
	CCVar@ g_cvarSuppressInfo;
	
	class HatCrossover
	{
		string sHat;
		int iCount;
		bool bCounted;
	}
	
	class HatData
	{
		string sModelPath;
		string sName;
		bool bDynamic;
		int iSequence;
		int iBody;
	}
	
	HookReturnCode PlayerSpawn(CBasePlayer@ pPlayer)
	{	// check if crossover data exists
		string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));
		if(g_hatCrossover.exists(sFixId) && hats.Running)
			g_Scheduler.SetTimeout("plrPostSpawn", 1.0f, g_EngineFuncs.IndexOfEdict(pPlayer.edict()), sFixId);
		
		return HOOK_CONTINUE;
		
	}

	void plrPostSpawn(int &in iIndex, string &in sFixId)
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(iIndex);
		if(pPlayer is null)
			return;
			
		HatCrossover@ cData = cast<HatCrossover@>(g_hatCrossover[sFixId]);
		if(!cData.bCounted)
			sethat(pPlayer, cData.sHat, true);
	}
	
	void ReadHats()
	{
		File@ file = g_FileSystem.OpenFile(g_hatsFile, OpenFile::READ);
		if(file !is null && file.IsOpen())
		{
			while(!file.EOFReached())
			{
				string sLine;
				file.ReadLine(sLine);
				//fix for linux
				string sFix = sLine.SubString(sLine.Length()-1,1);
				if(sFix == " " || sFix == "\n" || sFix == "\r" || sFix == "\t")
					sLine = sLine.SubString(0, sLine.Length()-1);
					
				if(sLine.SubString(0,1) == "#" || sLine.IsEmpty())
					continue;
					
				array<string> parsed = sLine.Split(" ");
				if(parsed.length() < 2)
					continue;
					
				HatData hData;
				string sName = "";
				string sModelPath = "";
				bool bDynamic = false;
				int iSequence = 0;
				int iBody = 0;
				if(parsed[0] == "STATIC")
				{
					array<string> parsed2 = parsed[1].Split("/");
					sName = parsed2[parsed2.length()-1];
					sName = sName.ToLowercase();
					sModelPath = parsed[1];
				}else if(parsed[0] == "DYNAMIC")
				{
					if(parsed.length() < 5)
						continue;
						
					sName = parsed[4];
					sModelPath = parsed[1];
					bDynamic = true;
					iSequence = atoi(parsed[3]);
					iBody = atoi(parsed[2]);
				}
				
				if(sName == "" || sModelPath == "")
					continue;
					
				hData.sName = sName;
				hData.sModelPath = sModelPath;
				hData.bDynamic = bDynamic;
				hData.iSequence = iSequence;
				hData.iBody = iBody;
					
				g_hatModels[sName] = hData; 
			}
			file.Close();
		}
	}
	
	void sethat(CBasePlayer@ pPlayer, string sHat, bool bSilent)
	{
		string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));
		if(g_hatUsers.exists(sFixId))
		{
			CBaseEntity@ pHat2 = cast<CBaseEntity@>(g_hatUsers[sFixId]);
			if(pHat2 !is null)
				g_EntityFuncs.Remove(pHat2);
		}
		
		CBaseEntity@ pHat = g_EntityFuncs.Create("info_target", pPlayer.pev.origin, pPlayer.pev.angles, true);
		g_EntityFuncs.DispatchSpawn(pHat.edict());
		pHat.pev.movetype = MOVETYPE_FOLLOW;
		@pHat.pev.aiment = pPlayer.edict();
		pHat.pev.rendermode = kRenderNormal;
		HatData@ hData = cast<HatData@>(g_hatModels[sHat]);
		HatCrossover cData;
		cData.sHat = sHat;
		cData.iCount = 0;
		cData.bCounted = true;
		g_EntityFuncs.SetModel(pHat, "models/"+hData.sModelPath+".mdl");
		if(hData.bDynamic)
		{
			pHat.pev.sequence = hData.iSequence;
			pHat.pev.body = hData.iBody;
			pHat.pev.framerate = 1;
		}
		pHat.pev.colormap = pPlayer.pev.colormap;
		
		EHandle eHat = pHat;
		g_hatUsers[sFixId] = eHat;
		g_hatCrossover[sFixId] = cData;
		if(!bSilent)
			if(g_cvarSuppressInfo.GetInt() <= 0)
				hats.TellAll(string(pPlayer.pev.netname)+" is now wearing a hat! (name: "+sHat+")", HUD_PRINTTALK);
			else
				hats.Tell("You are now wearing a hat! (name: "+sHat+")", pPlayer, HUD_PRINTTALK);
	}
	
	bool removehat(CBasePlayer@ pPlayer, bool bSilent)
	{
		string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));
		if(g_hatUsers.exists(sFixId))
		{
			CBaseEntity@ pHat = cast<CBaseEntity@>(g_hatUsers[sFixId]);
			if(pHat !is null)
			{
				g_EntityFuncs.Remove(pHat);
				g_hatUsers.delete(sFixId);
				if(g_hatCrossover.exists(sFixId))
					g_hatCrossover.delete(sFixId);
				if(!bSilent)
					if(g_cvarSuppressInfo.GetInt() <= 0)
						hats.TellAll(string(pPlayer.pev.netname)+" is no longer wearing a hat.", HUD_PRINTTALK);
					else
						hats.Tell("You are no longer wearing a hat.", pPlayer, HUD_PRINTTALK);
				return true;
			}else{
				if(!bSilent)
					hats.Tell("Error: hat registered, but has invalid hat entity?", pPlayer, HUD_PRINTTALK);
				return false;
			}
		}else{
			if(!bSilent)
				hats.Tell("You are not wearing a hat!", pPlayer, HUD_PRINTTALK);
			return false;
		}
	}
	
	void hatMenuCallback(CTextMenu@ mMenu, CBasePlayer@ pPlayer, int iPage, const CTextMenuItem@ mItem)
	{
		if(mItem !is null && pPlayer !is null)
		{
			if(mItem.m_szName == "<off>")
				removehat(pPlayer, false);
			else
				sethat(pPlayer, mItem.m_szName, false);
		}
	}
	
	void forcehat(AFBaseArguments@ AFArgs)
	{
		if(AFArgs.GetString(1) != "off" && !g_hatModels.exists(AFArgs.GetString(1)))
		{
			hats.Tell("Invalid hat!", AFArgs.User, HUD_PRINTCONSOLE);
			return;
		}
	
		array<CBasePlayer@> pTargets;
		if(AFBase::GetTargetPlayers(AFArgs.User, HUD_PRINTCONSOLE, AFArgs.GetString(0), 0, pTargets))
		{
			CBasePlayer@ pTarget = null;
			for(uint i = 0; i < pTargets.length(); i++)
			{
				@pTarget = pTargets[i];
				if(AFArgs.GetString(1) == "off")
				{
					removehat(AFArgs.User, true);
					hats.Tell("Removed hat from "+pTarget.pev.netname, AFArgs.User, HUD_PRINTCONSOLE);
				}else{
					sethat(pTarget, AFArgs.GetString(1), true);
					hats.Tell("Set "+pTarget.pev.netname+" hat to \""+AFArgs.GetString(1)+"\"", AFArgs.User, HUD_PRINTCONSOLE);
				}
			}
		}
	}

	void hat(AFBaseArguments@ AFArgs)
	{
		if(g_cvarSuppressChat.GetInt() <= 0)
		{
			//workaround: emulate chat when not supressing, obviously i need to update AFB to add in late supression
			//but eh.. "If it works, dont fix it"
			string sOutput = "";
			for(uint i = 0; i < AFArgs.RawArgs.length(); i++)
			{
				if(i > 0)
					sOutput += " ";
				
				sOutput += AFArgs.RawArgs[i];
			}
			
			g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, " "+AFArgs.User.pev.netname+": "+sOutput);
		}
	
		if(AFArgs.GetString(0) == "off")
			removehat(AFArgs.User, false);
		else if(AFArgs.GetString(0) == "menu")
		{
			if(@hatMenu is null)
			{
				@hatMenu = CTextMenu(hatMenuCallback);
				hatMenu.SetTitle("Hat menu: ");
				hatMenu.AddItem("<off>", null);
				array<string> hatNames = g_hatModels.getKeys();
				hatNames.sortAsc();
				for(uint i = 0; i < hatNames.length(); i++)
				{
					hatMenu.AddItem(hatNames[i].ToLowercase(), null);
				}
				
				hatMenu.Register();
			}
			
			hatMenu.Open(0, 0, AFArgs.User);
		}
		else
		{
			if(g_hatModels.exists(AFArgs.GetString(0)))
				sethat(AFArgs.User, AFArgs.GetString(0), false);
			else
				if(g_cvarSuppressInfo.GetInt() <= 0)
					hats.TellAll("Unknown hat. Try using \"hat menu\"?", HUD_PRINTTALK);
				else
					hats.Tell("Unknown hat. Try using \"hat menu\"?", AFArgs.User, HUD_PRINTTALK);
		}
	}
}