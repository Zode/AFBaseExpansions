BalloonMod balloonmod;

void BalloonMod_Call()
{
	balloonmod.RegisterExpansion(balloonmod);
}

class BalloonMod : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Zode";
		this.ExpansionName = "BalloonMod v1.0";
		this.ShortName = "BM";
	}
	
	void ExpansionInit()
	{
		RegisterCommand("balloon", "!i", "<amount> - Spawn balloons at self!", ACCESS_Z, @BalloonMod::balloon, true);
		RegisterCommand("say !balloon", "!i", "<amount> - Spawn balloons at self!", ACCESS_Z, @BalloonMod::balloon, true, true);
		RegisterCommand("balloontarget", "s!i", "(targets) <amount> - Spawn balloons at target(s)!", ACCESS_G, @BalloonMod::balloontarget, true);
		BalloonMod::g_playerCooldowns.deleteAll();
		BalloonMod::recheckPlayers();
		@BalloonMod::g_cvarCooldown = CCVar("ballooncooldown", 30.0f, "cooldown (float) seconds", ConCommandFlag::AdminOnly);
	}
	
	void PlayerConnectEvent(CBasePlayer@ pUser)
	{
		BalloonMod::g_playerCooldowns[pUser.entindex()] = 0.0f;
	}
	
	void PlayerDisconnectEvent(CBasePlayer@ pUser)
	{
		if(BalloonMod::g_playerCooldowns.exists(pUser.entindex()))
			BalloonMod::g_playerCooldowns.delete(pUser.entindex());
	}
	
	void StartEvent()
	{
		BalloonMod::g_playerCooldowns.deleteAll();
		BalloonMod::recheckPlayers();
	}
	
	void MapInit()
	{
		BalloonMod::g_playerCooldowns.deleteAll();
		BalloonMod::recheckPlayers();
		g_SoundSystem.PrecacheSound("tfc/misc/party2.wav");
		g_Game.PrecacheModel("sprites/zode/bloon_blu.spr");
		g_Game.PrecacheModel("sprites/zode/bloon_gre.spr");
		g_Game.PrecacheModel("sprites/zode/bloon_pur.spr");
		g_Game.PrecacheModel("sprites/zode/bloon_red.spr");
		g_Game.PrecacheModel("sprites/zode/bloon_yel.spr");
	}
}

namespace BalloonMod
{
	dictionary g_playerCooldowns;
	CCVar@ g_cvarCooldown;

	void recheckPlayers()
	{
		CBasePlayer@ pSearch = null;
		for(int i = 1; i <= g_Engine.maxClients; i++) // check already connected players
		{
			@pSearch = g_PlayerFuncs.FindPlayerByIndex(i);
			if(pSearch !is null)
			{
				g_playerCooldowns[pSearch.entindex()] = 0.0f;
			}
		}
	}

	void nmsgBalloon(Vector vOrigin, string sSpr, int iAmt)
	{
		NetworkMessage message(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null);
			message.WriteByte(TE_FIREFIELD);
			message.WriteCoord(vOrigin.x);
			message.WriteCoord(vOrigin.y);
			message.WriteCoord(vOrigin.z);
			message.WriteShort(42);
			message.WriteShort(g_EngineFuncs.ModelIndex(sSpr));
			message.WriteByte(iAmt);
			message.WriteByte(1);
			message.WriteByte(50);
		message.End();
	}
	
	void nmsgBalloons(Vector vOrigin, int iAmt)
	{
		int iTrueAmt = int(floor(iAmt/5));
		nmsgBalloon(vOrigin, "sprites/zode/bloon_blu.spr", iTrueAmt);
		nmsgBalloon(vOrigin, "sprites/zode/bloon_gre.spr", iTrueAmt);
		nmsgBalloon(vOrigin, "sprites/zode/bloon_pur.spr", iTrueAmt);
		nmsgBalloon(vOrigin, "sprites/zode/bloon_red.spr", iTrueAmt);
		nmsgBalloon(vOrigin, "sprites/zode/bloon_yel.spr", iTrueAmt);
	}
	
	void balloon(AFBaseArguments@ AFArgs)
	{
		HUD targetHud = AFArgs.IsChat ? HUD_PRINTTALK : HUD_PRINTCONSOLE;
		int iAmt = AFArgs.GetCount() >= 1 ? AFBase::cclamp(AFArgs.GetInt(0), 5, 40) : 10;
		float fCool = float(g_playerCooldowns[AFArgs.User.entindex()]);
		if(g_EngineFuncs.Time() >= fCool || AFBase::CheckAccess(AFArgs.User, ACCESS_G))
		{
			balloonmod.Tell("Balloons!", AFArgs.User, targetHud);
			nmsgBalloons(AFArgs.User.pev.origin, iAmt);
			g_playerCooldowns[AFArgs.User.entindex()] = g_EngineFuncs.Time()+g_cvarCooldown.GetFloat();
			g_SoundSystem.PlaySound(AFArgs.User.edict(), CHAN_AUTO, "tfc/misc/party2.wav", 1.0f, 1.0f);
		}else
			balloonmod.Tell("(Cooldown) Please wait "+string(int(floor(fCool-g_EngineFuncs.Time()))+1)+" second(s) before spawning more balloons!", AFArgs.User, targetHud);
	}
	
	void balloontarget(AFBaseArguments@ AFArgs)
	{
		array<CBasePlayer@> pTargets;
		int iAmt = AFArgs.GetCount() >= 2 ? AFBase::cclamp(AFArgs.GetInt(1), 5, 40) : 10;
		if(AFBase::GetTargetPlayers(AFArgs.User, HUD_PRINTCONSOLE, AFArgs.GetString(0), TARGETS_NOIMMUNITYCHECK, pTargets))
		{
			CBasePlayer@ pTarget = null;
			for(uint i = 0; i < pTargets.length(); i++)
			{
				@pTarget = pTargets[i];
				nmsgBalloons(pTarget.pev.origin, iAmt);
				g_SoundSystem.PlaySound(pTarget.edict(), CHAN_AUTO, "tfc/misc/party2.wav", 1.0f, 1.0f);
			}
		}
	}
}