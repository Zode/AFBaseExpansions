HookMod hookmod;

void HookMod_Call()
{
	hookmod.RegisterExpansion(hookmod);
}

class HookMod : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Zode";
		this.ExpansionName = "Hookmod v1.0";
		this.ShortName = "HM";
	}
	
	void ExpansionInit()
	{
		RegisterCommand("hook", "!i", "- Use without argument to see usage/alias - Use hook.", ACCESS_Y, @HookMod::hook, true);
		HookMod::g_hookingPlayers.deleteAll();
		
		if(HookMod::g_hookThink !is null)
			g_Scheduler.RemoveTimer(HookMod::g_hookThink);
	
		@HookMod::g_hookThink = g_Scheduler.SetInterval("HookThink", 0.15f);
	}
	
	void MapInit()
	{
		HookMod::g_hookingPlayers.deleteAll();
		g_SoundSystem.PrecacheSound("weapons/xbow_hit2.wav");
		g_Game.PrecacheModel("sprites/zbeam3.spr");
		
		if(HookMod::g_hookThink !is null)
			g_Scheduler.RemoveTimer(HookMod::g_hookThink);
	
		@HookMod::g_hookThink = g_Scheduler.SetInterval("HookThink", 0.15f);
	}
	
	void PlayerDisconnectEvent(CBasePlayer@ pUser)
	{
		if(HookMod::g_hookingPlayers.exists(pUser.entindex()))
			HookMod::g_hookingPlayers.delete(pUser.entindex());
	}
	
	void StopEvent()
	{
		//incase some player hooking and the extension was stopped
		CBasePlayer@ pSearch = null;
		if(AFBase::IsSafe())
		{
			for(int i = 1; i <= g_Engine.maxClients; i++)
			{
				@pSearch = g_PlayerFuncs.FindPlayerByIndex(i);
				if(pSearch !is null)
				{
					if(HookMod::g_hookingPlayers.exists(pSearch.entindex()))
					{
						HookMod::g_hookingPlayers.delete(pSearch.entindex());
						pSearch.pev.gravity = 1.0f;
					}
				}
			}
		}
		
		if(HookMod::g_hookThink !is null)
			g_Scheduler.RemoveTimer(HookMod::g_hookThink);
	}

	
	void StartEvent()
	{
		if(HookMod::g_hookThink !is null)
			g_Scheduler.RemoveTimer(HookMod::g_hookThink);
	
		@HookMod::g_hookThink = g_Scheduler.SetInterval("HookThink", 0.15f);
	}
}

namespace HookMod
{
	dictionary g_hookingPlayers;
	CScheduledFunction@ g_hookThink = null;

	void HookThink()
	{
		CBasePlayer@ pSearch = null;
		if(AFBase::IsSafe())
		{
			for(int i = 1; i <= g_Engine.maxClients; i++)
			{
				@pSearch = g_PlayerFuncs.FindPlayerByIndex(i);
				if(pSearch !is null)
				{
					if(g_hookingPlayers.exists(pSearch.entindex()))
					{
						Vector hookPos = Vector(g_hookingPlayers[pSearch.entindex()]);
						NetworkMessage message(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null);
							message.WriteByte(TE_BEAMENTPOINT);
							message.WriteShort(pSearch.entindex());
							message.WriteCoord(hookPos.x);
							message.WriteCoord(hookPos.y);
							message.WriteCoord(hookPos.z);
							message.WriteShort(g_EngineFuncs.ModelIndex("sprites/zbeam3.spr"));
							message.WriteByte(1);
							message.WriteByte(1);
							message.WriteByte(2);
							message.WriteByte(8);
							message.WriteByte(0);
							message.WriteByte(0);
							message.WriteByte(0);
							message.WriteByte(255);
							message.WriteByte(255);
							message.WriteByte(0);
						message.End();
						Vector origin = pSearch.pev.origin;
						Vector velocity;
						for(int j = 0; j < 3; j++)
							velocity[j] = (hookPos[j] - origin[j])*3.0f;
						float fPow = velocity.x*velocity.x+velocity.y*velocity.y+velocity.z*velocity.z;
						float fTotal = 600.0f/sqrt(fPow);
						for(int j = 0; j < 3; j++)
							velocity[j] *= fTotal;
						pSearch.pev.velocity = velocity;
						pSearch.pev.flFallVelocity = 0;
					}
				}
			}
		}
	}
	
	void hook(AFBaseArguments@ AFArgs)
	{
		int iMode = AFArgs.GetCount() >= 1 ? AFArgs.GetInt(0) : -1;
		if(iMode == -1)
		{
			hookmod.Tell("Aliases: (execute these, perferrably save to autoexec cfg)", AFArgs.User, HUD_PRINTCONSOLE);
			hookmod.Tell("    alias +hook \".hook 1\"", AFArgs.User, HUD_PRINTCONSOLE);
			hookmod.Tell("    alias -hook \".hook 0\"", AFArgs.User, HUD_PRINTCONSOLE);
			hookmod.Tell("    bind (button) +hook", AFArgs.User, HUD_PRINTCONSOLE);
		}else if(iMode == 0)
		{
			if(g_hookingPlayers.exists(AFArgs.User.entindex()))
			{
				g_hookingPlayers.delete(AFArgs.User.entindex());
				AFArgs.User.pev.gravity = 1.0f;
			}
		}else if(iMode == 1)
		{
			g_EngineFuncs.MakeVectors(AFArgs.User.pev.v_angle);
			Vector vecSrc = AFArgs.User.GetGunPosition();
			Vector vecAiming = g_Engine.v_forward;
			TraceResult tr;
			g_Utility.TraceLine(vecSrc, vecSrc+vecAiming*8192, ignore_monsters, AFArgs.User.edict(), tr);
			AFArgs.User.pev.gravity = 0.0f;
			g_hookingPlayers[AFArgs.User.entindex()] = tr.vecEndPos;
			g_SoundSystem.PlaySound(AFArgs.User.edict(), CHAN_STATIC, "weapons/xbow_hit2.wav", 1.0f, 1.0f);
		}
		
		HookThink();
	}
}