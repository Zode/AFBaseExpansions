SimpleTrail simpletrail;

void SimpleTrail_Call()
{
	simpletrail.RegisterExpansion(simpletrail);
}

class SimpleTrail : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Zode";
		this.ExpansionName = "SimpleTrail " + SimpleTrail::VERSION;
		this.ShortName = "TRAILS";
	}

	void ExpansionInit()
	{
		@SimpleTrail::g_cvarHideChat =				CCVar( "hidechat", false, "Hide player chat when executing trail command",  ConCommandFlag::AdminOnly );
		@SimpleTrail::g_cvarSilence =				CCVar( "silence", false, "Silent plugin - only print to user instead of everybody", ConCommandFlag::AdminOnly );
		@SimpleTrail::g_cvarTrailSize =				CCVar( "trailsize", 8, " trail size", ConCommandFlag::AdminOnly );
		@SimpleTrail::g_cvarTrailDuration =			CCVar( "trailduration", 4.0f, "trail duration (in seconds)", ConCommandFlag::AdminOnly );
		@SimpleTrail::g_cvarTrailAlpha =			CCVar( "trailalpha", 200, "trail alpha", ConCommandFlag::AdminOnly );
		@SimpleTrail::g_cvarTrailDefaultSprite =	CCVar( "trailsprite", "fatline", "default trail sprite", ConCommandFlag::AdminOnly );

		bool bHideChat = SimpleTrail::g_cvarHideChat.GetBool();
		RegisterCommand( "say trail", "s!s", "(trailname/menu/off) - set trail, show menu, or remove trail.", ACCESS_Z, @SimpleTrail::trail_cmd_handle, true, bHideChat );

		g_Hooks.RegisterHook( Hooks::Player::PlayerSpawn, @SimpleTrail::PlayerSpawn );

		SimpleTrail::g_bHasColors = false;
		SimpleTrail::g_isSafe = false;
	}

	void MapInit()
	{
		SimpleTrail::g_TrailSprites.deleteAll();
		SimpleTrail::ReadSprites();
		array<string> spriteNames = SimpleTrail::g_TrailSprites.getKeys();

		for( uint i = 0; i < spriteNames.length(); i++ )
		{
			SimpleTrail::TrailSpriteData@ tsData = cast<SimpleTrail::TrailSpriteData@>(SimpleTrail::g_TrailSprites[spriteNames[i]]);
			tsData.sprIndex = g_Game.PrecacheModel(tsData.sprPath);
		}

		if( @SimpleTrail::trailMenu !is null )
		{
			SimpleTrail::trailMenu.Unregister();
			@SimpleTrail::trailMenu = null;
		}

		if( @SimpleTrail::spriteMenu !is null )
		{
			SimpleTrail::spriteMenu.Unregister();
			@SimpleTrail::spriteMenu = null;
		}

		SimpleTrail::g_PlayerTrails.deleteAll();
		SimpleTrail::g_TrailColors.deleteAll();
		SimpleTrail::ReadColors();
		SimpleTrail::g_bHasColors = true;
		SimpleTrail::g_isSafe = true;

		SimpleTrail::g_iFixedTrailSize = AFBase::cclamp( SimpleTrail::g_cvarTrailSize.GetInt(), 1, 255 );
		SimpleTrail::g_iFixedTrailDuration = AFBase::cclamp( int(SimpleTrail::g_cvarTrailDuration.GetFloat())*10, 1, 255 );
		SimpleTrail::g_iFixedTrailAlpha = AFBase::cclamp( SimpleTrail::g_cvarTrailAlpha.GetInt(), 1, 255 );

		if( SimpleTrail::g_TrailThink !is null )
			g_Scheduler.RemoveTimer(SimpleTrail::g_TrailThink);

		@SimpleTrail::g_TrailThink = g_Scheduler.SetInterval( "trailThink", 0.3f );
	}

	void PlayerDisconnectEvent( CBasePlayer@ pPlayer )
	{
		string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));

		if( SimpleTrail::g_PlayerTrails.exists(sFixId) and sFixId != "" )
			SimpleTrail::g_PlayerTrails.delete(sFixId);

		if( SimpleTrail::g_PlayerCrossover.exists(sFixId) and sFixId != "" )
			SimpleTrail::g_PlayerCrossover.delete(sFixId);

		//SimpleTrail::removeTrail(pPlayer);
	}

	void StopEvent()
	{
		if( SimpleTrail::g_TrailThink !is null)
			g_Scheduler.RemoveTimer(SimpleTrail::g_TrailThink);

		CBasePlayer@ pSearch = null;

		for( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			@pSearch = g_PlayerFuncs.FindPlayerByIndex(i);

			if( pSearch !is null )
			{
				string sFixId = AFBase::FormatSafe( AFBase::GetFixedSteamID(pSearch) );

				if( sFixId == "" ) continue;

				if( SimpleTrail::g_PlayerTrails.exists(sFixId) )
					SimpleTrail::g_PlayerTrails.delete(sFixId);

				if( SimpleTrail::g_PlayerCrossover.exists(sFixId) )
					SimpleTrail::g_PlayerCrossover.delete(sFixId);
			}
		}
	}

	void StartEvent()
	{
		if( SimpleTrail::g_TrailThink is null)
			@SimpleTrail::g_TrailThink = g_Scheduler.SetInterval( "trailThink", 0.3f );
	}
}

namespace SimpleTrail
{
	const string VERSION = "1.0";
	const string g_ColorFile = "scripts/plugins/AFBaseExpansions/colors.txt";
	const string g_SpriteFile = "scripts/plugins/AFBaseExpansions/trailsprites.txt";

	CCVar@ g_cvarHideChat;
	CCVar@ g_cvarSilence;
	CCVar@ g_cvarTrailSize;
	CCVar@ g_cvarTrailDuration;
	CCVar@ g_cvarTrailAlpha;
	CCVar@ g_cvarTrailDefaultSprite;

	CScheduledFunction@ g_TrailThink = null;

	CTextMenu@ trailMenu = null;
	CTextMenu@ spriteMenu = null;

	int g_iFixedTrailSize;
	int g_iFixedTrailDuration;
	int g_iFixedTrailAlpha;

	dictionary g_PlayerTrails;
	dictionary g_PlayerCrossover;
	dictionary g_TrailColors;
	dictionary g_TrailSprites;

	bool g_bHasColors = false;
	bool g_isSafe = false;

	class PlayerTrailData
	{
		int id;
		Vector color;
		int sprIndex;
		string sprName;
		bool restart;
		bool enabled;
	}

	class PlayerCrossoverData
	{
		Vector color;
		string sprName;
	}

	class TrailSpriteData
	{
		int sprIndex;
		string sprPath;
		bool sprColored;
	}

	void ReadColors()
	{
		File@ file = g_FileSystem.OpenFile( g_ColorFile, OpenFile::READ );

		if( file !is null and file.IsOpen() )
		{
			while( !file.EOFReached() )
			{
				string sLine;
				file.ReadLine(sLine);
				if( sLine.SubString(sLine.Length()-1, 1) == " " or sLine.SubString(sLine.Length()-1, 1) == "\n" or sLine.SubString(sLine.Length()-1, 1) == "\r" or sLine.SubString(sLine.Length()-1, 1) == "\t" )
					sLine = sLine.SubString(0, sLine.Length()-1);
				
				if( sLine.SubString(0, 1) == "#" or sLine.IsEmpty() )
					continue;

				array<string> parsed = sLine.Split(" ");
				if( parsed.length() < 4 )
					continue;

				int iR = AFBase::cclamp( atoi(parsed[1]), 0, 255 );
				int iG = AFBase::cclamp( atoi(parsed[2]), 0, 255 );
				int iB = AFBase::cclamp( atoi(parsed[3]), 0, 255 );
				Vector color = Vector(iR, iG, iB);

				g_TrailColors[parsed[0].ToLowercase()] = color;
			}

			file.Close();
		}
	}

	void ReadSprites()
	{
		File@ file = g_FileSystem.OpenFile(g_SpriteFile, OpenFile::READ);

		if( file !is null and file.IsOpen() )
		{
			while( !file.EOFReached() )
			{
				string sLine;
				file.ReadLine(sLine);
				if( sLine.SubString(sLine.Length()-1, 1) == " " or sLine.SubString(sLine.Length()-1, 1) == "\n" or sLine.SubString(sLine.Length()-1, 1) == "\r" or sLine.SubString(sLine.Length()-1, 1) == "\t" )
					sLine = sLine.SubString(0, sLine.Length()-1);

				if( sLine.SubString(0, 1) == "#" or sLine.IsEmpty() )
					continue;

				array<string> parsed = sLine.Split(" ");
				if( parsed.length() < 3 )
					continue;

				//linux quickfix
				if( parsed[1].SubString(parsed[1].Length()-1, 1) == " " or parsed[1].SubString(parsed[1].Length()-1, 1) == "\n" or parsed[1].SubString(parsed[1].Length()-1, 1) == "\r" or parsed[1].SubString(parsed[1].Length()-1, 1) == "\t" )
					parsed[1] = parsed[1].SubString(0, parsed[1].Length()-1);

				TrailSpriteData tsData;
				tsData.sprPath = parsed[0];
				tsData.sprColored = atoi(parsed[2]) > 0 ? true : false;

				g_TrailSprites[parsed[1].ToLowercase()] = tsData;	
			}

			file.Close();
		}
	}

	void spriteMenuCallBack( CTextMenu@ mMenu, CBasePlayer@ pPlayer, int iPage, const CTextMenuItem@ mItem )
	{
		if( mItem !is null and pPlayer !is null )
		{
			TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[mItem.m_szName]);

			if( tsData.sprColored )
			{
				addTrail( pPlayer, Vector(255,255,255), mItem.m_szName );

				if( g_cvarSilence.GetBool() )
					simpletrail.Tell( "You now have a colored trail (sprite \"" + mItem.m_szName + "\").", pPlayer, HUD_PRINTTALK );
				else
					simpletrail.TellAll( string(pPlayer.pev.netname) + " now has a colored trail (sprite \"" + mItem.m_szName + "\").", HUD_PRINTTALK );
			}
			else
			{
				setSprite( pPlayer, mItem.m_szName );
				trailMenu.Open( 0, 0, pPlayer );
			}
		}
	}

	void trailMenuCallBack( CTextMenu@ mMenu, CBasePlayer@ pPlayer, int iPage, const CTextMenuItem@ mItem )
	{
		if( mItem !is null and pPlayer !is null )
		{
			string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));

			if( mItem.m_szName == "<off>" )
			{
				if( g_PlayerTrails.exists(sFixId) and sFixId != "" )
				{
					if( g_cvarSilence.GetBool() )
						simpletrail.Tell( "You no longer have a trail.", pPlayer, HUD_PRINTTALK );
					else
						simpletrail.TellAll( string(pPlayer.pev.netname) + " no longer has a trail.", HUD_PRINTTALK );

					removeTrail(pPlayer);
					return;
				}
				
				simpletrail.Tell( "You don't have a trail!", pPlayer, HUD_PRINTTALK );
				return;
			}

			PlayerTrailData@ ptData = cast<PlayerTrailData@>(g_PlayerTrails[sFixId]);

			if( g_cvarSilence.GetBool() )
				simpletrail.Tell( "You now have a " + mItem.m_szName + " trail (sprite \"" + ptData.sprName + "\").", pPlayer, HUD_PRINTTALK );
			else
				simpletrail.TellAll( string(pPlayer.pev.netname) + " now has a " + mItem.m_szName + " trail (sprite \"" + ptData.sprName + "\").", HUD_PRINTTALK );

			addTrail( pPlayer, Vector(g_TrailColors[mItem.m_szName]), "!NOSET!" );
		}
	}

	void trail_cmd_handle( AFBaseArguments@ args )
	{
		CBasePlayer@ pPlayer = args.User;
		bool bSilent = g_cvarSilence.GetBool();

		if( args.GetCount() >= 1 )
		{
			if( !g_isSafe ) // skip
			{
				if( bSilent )
					simpletrail.Tell( "Please wait until map change, this plugins needs to precache sprites.", pPlayer, HUD_PRINTTALK );
				else
					simpletrail.TellAll( "Please wait until map change, this plugins needs to precache sprites.", HUD_PRINTTALK );

				return;
			}

			if( !g_bHasColors )
			{ // most likely as_reloadplugins or map change, still can't hurt to re-read colors 'n stuff
				if( @trailMenu !is null )
				{
					trailMenu.Unregister();
					@trailMenu = null;
				}

				if( @spriteMenu !is null )
				{
					spriteMenu.Unregister();
					@spriteMenu = null;
				}

				g_TrailColors.deleteAll();
				g_PlayerTrails.deleteAll();
				ReadColors();
				g_bHasColors = true;
			}

			if( args.GetString(0).ToLowercase() == "off" )
			{
				if( bSilent )
					simpletrail.Tell( "You no longer have a trail.", pPlayer, HUD_PRINTTALK );
				else
					simpletrail.TellAll( string(pPlayer.pev.netname) + " no longer has a trail.", HUD_PRINTTALK );

				removeTrail(pPlayer);
			}
			else if( args.GetString(0).ToLowercase() == "menu" )
			{
				if( @trailMenu is null )
				{
					@trailMenu = CTextMenu(trailMenuCallBack);
					trailMenu.SetTitle( "Trail menu (COLOR): " );
					trailMenu.AddItem( "<off>", null );
					array<string> colorNames = g_TrailColors.getKeys();
					colorNames.sortAsc();

					for( uint i = 0; i < colorNames.length(); i++ )
						trailMenu.AddItem( colorNames[i].ToLowercase(), null );

					trailMenu.Register();
					//trailMenu.Open(0, 0, pPlayer);
				}

				if( @spriteMenu is null )
				{
					@spriteMenu = CTextMenu(spriteMenuCallBack);
					spriteMenu.SetTitle( "Trail menu (SPRITE): " );
					array<string> spriteNames = g_TrailSprites.getKeys();
					spriteNames.sortAsc();

					for( uint i = 0; i < spriteNames.length(); i++ )
						spriteMenu.AddItem( spriteNames[i].ToLowercase(), null );

					spriteMenu.Register();
					spriteMenu.Open(0, 0, pPlayer);
				}
				else
					spriteMenu.Open(0, 0, pPlayer);
			}
			else
			{
				if( g_TrailColors.exists(args.GetString(0).ToLowercase()) )
				{
					string sSprite = g_TrailSprites.exists(args.GetString(1).ToLowercase()) ? args.GetString(1).ToLowercase() : g_cvarTrailDefaultSprite.GetString();

					if( bSilent )
						simpletrail.Tell( "You now have a " + args.GetString(0).ToLowercase() + " trail (sprite \"" + sSprite + "\").", pPlayer, HUD_PRINTTALK );
					else
						simpletrail.TellAll( string(pPlayer.pev.netname) + " now has a " + args.GetString(0).ToLowercase() + " trail (sprite \"" + sSprite + "\").", HUD_PRINTTALK );

					addTrail( pPlayer, Vector(g_TrailColors[args.GetString(0).ToLowercase()]), sSprite );
				}
				else if( g_TrailSprites.exists(args.GetString(0).ToLowercase()) )
				{
					string sSprite = args.GetString(0).ToLowercase();

					TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);

					if( tsData.sprColored )
					{
						if( bSilent )
							simpletrail.Tell( "You now have a colored trail (sprite \"" + sSprite + "\").", pPlayer, HUD_PRINTTALK );
						else
							simpletrail.TellAll( string(pPlayer.pev.netname) + " now has a colored trail (sprite \"" + sSprite + "\").", HUD_PRINTTALK );

						addTrail( pPlayer, Vector(255, 255, 255), sSprite );
					}
					else
					{
						if( bSilent )
							simpletrail.Tell( "[Trail] \"" + sSprite + "\" isn't a colored sprite! use \"trail <color> <sprite>\" or \"trail menu\".", pPlayer, HUD_PRINTTALK );
						else
							simpletrail.TellAll( "\"" + sSprite + "\" isn't a colored sprite! use \"trail <color> <sprite>\" or \"trail menu\".", HUD_PRINTTALK );
					}
				}
				else
				{
					if( bSilent )
						simpletrail.Tell( "[Trail] No such color or colored sprite, try typing \"trail menu\"?", pPlayer, HUD_PRINTTALK );
					else
						simpletrail.TellAll( "No such color or colored sprite, try typing \"trail menu\"?", HUD_PRINTTALK );
				}
			}
		}
	}

	HookReturnCode PlayerSpawn( CBasePlayer@ pPlayer )
	{	// check if crossover data exists
		string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));

		if( g_PlayerCrossover.exists(sFixId) )
		{
			if( !g_PlayerTrails.exists(sFixId) )
				g_Scheduler.SetTimeout( "trailsPostSpawn", 1.05f, g_EngineFuncs.IndexOfEdict(pPlayer.edict()), sFixId );
		}

		return HOOK_CONTINUE;
	}

	void trailsPostSpawn( int &in iIndex, string &in sFixId )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(iIndex);

		if( pPlayer is null or !pPlayer.IsConnected() )
			return;

		PlayerCrossoverData@ pcData = cast<PlayerCrossoverData@>(g_PlayerCrossover[sFixId]);

		if( pcData.sprName == "!NOSET!" or pcData.sprName.IsEmpty() )
			return;

		addTrail( pPlayer, pcData.color, pcData.sprName );
	}

	void trailThink()
	{
		if( g_PlayerTrails.isEmpty() )
			return;

		array<string> playerTrailIds = g_PlayerTrails.getKeys();

		for( uint i = 0; i < playerTrailIds.length(); i++ )
		{
			PlayerTrailData@ ptData = cast<PlayerTrailData@>(g_PlayerTrails[playerTrailIds[i]]);

			if( !ptData.enabled )
				return;

			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(ptData.id);

			if( pPlayer is null )
				return;

			Vector vVel = pPlayer.pev.velocity;
			bool bTemp = false;

			if( vVel.x == 0 and vVel.y == 0 and vVel.z == 0 ) //vVel == g_vecZero ?
				ptData.restart = true;

			if( ptData.restart )
			{
				if( vVel.x >= 2 or vVel.x <= -2 ) { bTemp = true; }
				if( vVel.y >= 2 or vVel.y <= -2 ) { bTemp = true; }
				if( vVel.z >= 2 or vVel.z <= -2 ) { bTemp = true; }
			}

			if( bTemp )
			{
				ptData.restart = false;

				killMsg(ptData.id);
				trailMsg( pPlayer, ptData.color, ptData.sprIndex );
			}
		}
	}

	void setSprite( CBasePlayer@ pPlayer, string sSprite )
	{
		string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));

		if( g_PlayerTrails.exists(sFixId) and sFixId != "" )
		{
			PlayerTrailData@ ptData = cast<PlayerTrailData@>(g_PlayerTrails[sFixId]);
			TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);
			PlayerCrossoverData@ pcData = cast<PlayerCrossoverData@>(g_PlayerCrossover[sFixId]);

			ptData.enabled = false;
			ptData.sprIndex = tsData.sprIndex;
			ptData.sprName = sSprite;
			pcData.sprName = sSprite;

			//why are these missing??
			//g_PlayerTrails[sFixId] = ptData;
			//g_PlayerCrossover[sFixId] = pcData;
		}
		else
		{
			PlayerTrailData ptData;
			TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);
			PlayerCrossoverData pcData;

			ptData.enabled = false;
			ptData.sprIndex = tsData.sprIndex;
			ptData.sprName = sSprite;
			pcData.sprName = sSprite;

			g_PlayerTrails[sFixId] = ptData;
			g_PlayerCrossover[sFixId] = pcData;
		}
	}

	void addTrail( CBasePlayer@ pPlayer, Vector color, string sSprite )
	{
		string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));

		if( g_PlayerTrails.exists(sFixId) and sFixId != "" )
		{ // replace
			Vector TargetColor = color;
			PlayerTrailData@ ptData = cast<PlayerTrailData@>(g_PlayerTrails[sFixId]);

			ptData.id = g_EntityFuncs.EntIndex(pPlayer.edict());
			ptData.color = TargetColor;
			ptData.restart = false;
			ptData.enabled = true;

			PlayerCrossoverData@ pcData = cast<PlayerCrossoverData@>(g_PlayerCrossover[sFixId]);

			pcData.color = TargetColor;

			TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);

			if( sSprite != "!NOSET!" )
			{
				if( tsData.sprColored )
				{
					ptData.color = Vector(255, 255, 255);
					pcData.color = Vector(255, 255, 255);
					TargetColor = Vector(255, 255, 255);
				}

				ptData.sprIndex = tsData.sprIndex;
				pcData.sprName = sSprite;
			}

			//why are these missing??
			//g_PlayerTrails[sFixId] = ptData;
			//g_PlayerCrossover[sFixId] = pcData;		

			killMsg(ptData.id);
			trailMsg( pPlayer, TargetColor, ptData.sprIndex );
		}
		else
		{ // new
			Vector TargetColor = color;
			PlayerTrailData ptData;

			ptData.id = g_EntityFuncs.EntIndex(pPlayer.edict());
			ptData.color = TargetColor;
			ptData.restart = false;
			ptData.enabled = true;

			PlayerCrossoverData pcData;

			pcData.color = TargetColor;

			TrailSpriteData@ tsData = cast<TrailSpriteData@>(g_TrailSprites[sSprite]);

			if( tsData.sprColored )
			{
				ptData.color = Vector(255, 255, 255);
				pcData.color = Vector(255, 255, 255);
				TargetColor = Vector(255, 255, 255);
			}

			if( sSprite != "!NOSET!" )
			{
				ptData.sprIndex = tsData.sprIndex;
				pcData.sprName = sSprite;	
			}

			g_PlayerTrails[sFixId] = ptData;
			g_PlayerCrossover[sFixId] = pcData;
			trailMsg(pPlayer, TargetColor, ptData.sprIndex);
		}
	}

	void trailMsg( CBasePlayer@ pPlayer, Vector color, int sprIndex )
	{
		int iId = g_EntityFuncs.EntIndex(pPlayer.edict());
		//send trail message
		NetworkMessage message( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null );
			message.WriteByte( TE_BEAMFOLLOW );
			message.WriteShort( iId );
			message.WriteShort( sprIndex );
			message.WriteByte( g_iFixedTrailDuration );
			message.WriteByte( g_iFixedTrailSize );
			message.WriteByte( int(color.x) );
			message.WriteByte( int(color.y) );
			message.WriteByte( int(color.z) );
			message.WriteByte( g_iFixedTrailAlpha );
		message.End();
	}

	void removeTrail( CBasePlayer@ pPlayer )
	{
		string sFixId = AFBase::FormatSafe(AFBase::GetFixedSteamID(pPlayer));

		if( g_PlayerTrails.exists(sFixId) and sFixId != "" )
			g_PlayerTrails.delete(sFixId);

		if( g_PlayerCrossover.exists(sFixId) and sFixId != "" )
			g_PlayerCrossover.delete(sFixId);

		int iId = g_EntityFuncs.EntIndex(pPlayer.edict());
		killMsg(iId);
	}

	void killMsg( int iId )
	{
		//send kill trail message
		NetworkMessage message( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null );
			message.WriteByte( TE_KILLBEAM );
			message.WriteShort( iId );
		message.End();
	}

} //namespace SimpleTrail END

/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		April 25 2018
*	-------------------------
*	- First release
*	-------------------------
*/