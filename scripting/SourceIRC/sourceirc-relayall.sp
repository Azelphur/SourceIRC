/*
       This file is part of SourceIRC.

    SourceIRC is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    SourceIRC is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with SourceIRC.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <regex>
#undef REQUIRE_PLUGIN
#include <sourceirc>

#define PLUGIN_VERSION		"0.2-B"

int g_userid = 0;
bool g_isteam = false;

public Plugin myinfo =
{
	name = "SourceIRC -> Relay All",
	author = "Azelphur (Playa Edit)",
	description = "Relays various game events",
	version = PLUGIN_VERSION,
	url = "FunForBattle"
};

public OnPluginStart()
{
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
	HookEvent("player_changename", Event_PlayerChangeName, EventHookMode_Post);
	HookEvent("player_say", Event_PlayerSay, EventHookMode_Post);
	HookEvent("player_chat", Event_PlayerSay, EventHookMode_Post);

	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say2", Command_Say);
	RegConsoleCmd("say_team", Command_SayTeam);

	LoadTranslations("sourceirc.phrases");
}

public OnAllPluginsLoaded() {
	if (LibraryExists("sourceirc"))
		IRC_Loaded();
}

public OnLibraryAdded(const char[] name) {
	if (StrEqual(name, "sourceirc"))
		IRC_Loaded();
}

IRC_Loaded() {
	IRC_CleanUp(); // Call IRC_CleanUp as this function can be called more than once.
	IRC_HookEvent("PRIVMSG", Event_PRIVMSG);
}

public Action Command_Say(client, args) {
	g_isteam = false; // Ugly hack to get around player_chat event not working.
}

public Action Command_SayTeam(client, args) {
	g_isteam = true; // Ugly hack to get around player_chat event not working.
}

public Action Event_PlayerSay(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	
	char result[IRC_MAXLEN], message[256];
	result[0] = '\0';
	GetEventString(event, "text", message, sizeof(message));
	
	if (client != 0 && !IsPlayerAlive(client))
		StrCat(result, sizeof(result), "*DEAD* ");
	if (g_isteam)
		StrCat(result, sizeof(result), "(TEAM) ");
		
	int team
	if (client != 0)
		team = IRC_GetTeamColor(GetClientTeam(client));
	else
		team = 0;
	if (team == -1)
		Format(result, sizeof(result), "%s%N: %s", result, client, message);
	else
		Format(result, sizeof(result), "%s\x03%02d%N\x03: %s", result, team, client, message);
	IRC_MsgFlaggedChannels("relay", result);
}


public void OnClientAuthorized(client, const char[] auth) { // We are hooking this instead of the player_connect event as we want the steamid
	int userid = GetClientUserId(client);
	if (userid <= g_userid) // Ugly hack to get around mass connects on map change
		return;
	g_userid = userid;
	char playername[MAX_NAME_LENGTH], result[IRC_MAXLEN];
	GetClientName(client, playername, sizeof(playername));
	Format(result, sizeof(result), "%t", "Player Connected", playername, auth, userid);
	if (!StrEqual(result, ""))
		IRC_MsgFlaggedChannels("detail", result);
	return;
}

public Action Event_PlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	if (client != 0) {
		char reason[128], playername[MAX_NAME_LENGTH], auth[64], result[IRC_MAXLEN];
		GetEventString(event, "reason", reason, sizeof(reason));
		GetClientName(client, playername, sizeof(playername));
		GetClientAuthId(client, AuthId_Engine, auth, sizeof(auth)); //GetClientAuthString(client, auth, sizeof(auth));
		for (new i = 0; i <= strlen(reason); i++) { // For some reason, certain disconnect reasons have \n in them, so i'm stripping them. Silly valve.
			if (reason[i] == '\n')
				RemoveChar(reason, sizeof(reason), i);
		}
		Format(result, sizeof(result), "%t", "Player Disconnected", playername, auth, userid, reason);
		if (!StrEqual(result, ""))
			IRC_MsgFlaggedChannels("detail", result);
	}
}

public Action Event_PlayerChangeName(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	if (client != 0) {
		char oldname[128], newname[MAX_NAME_LENGTH], auth[64], result[IRC_MAXLEN];
		GetEventString(event, "oldname", oldname, sizeof(oldname));
		GetEventString(event, "newname", newname, sizeof(newname));
		GetClientAuthId(client, AuthId_Engine, auth, sizeof(auth)); //GetClientAuthString(client, auth, sizeof(auth));
		Format(result, sizeof(result), "%t", "Changed Name", oldname, auth, userid, newname);
		if (!StrEqual(result, ""))
			IRC_MsgFlaggedChannels("relay", result);
	}
}

public OnMapEnd() {
	IRC_MsgFlaggedChannels("detail", "%t", "Map Changing");
}

public OnMapStart() {
	char map[128];
	GetCurrentMap(map, sizeof(map));
	IRC_MsgFlaggedChannels("detail", "%t", "Map Changed", map);
}

public Action Event_PRIVMSG(const char[] hostmask, args) {
	char channel[64];
	IRC_GetEventArg(1, channel, sizeof(channel));
	if (IRC_ChannelHasFlag(channel, "relay")) {
		char nick[IRC_NICK_MAXLEN], text[IRC_MAXLEN];
		IRC_GetNickFromHostMask(hostmask, nick, sizeof(nick));
		IRC_GetEventArg(2, text, sizeof(text));
		if (!strncmp(text, "\x01ACTION ", 8) && text[strlen(text)-1] == '\x01') {
			text[strlen(text)-1] = '\x00';
			IRC_Strip(text, sizeof(text)); // Strip IRC Color Codes
			IRC_StripGame(text, sizeof(text)); // Strip Game color codes
			PrintToChatAll("\x01[\x04IRC\x01] * %s %s", nick, text[7]);
		}
		else {
			IRC_Strip(text, sizeof(text)); // Strip IRC Color Codes
			IRC_StripGame(text, sizeof(text)); // Strip Game color codes
			PrintToChatAll("\x01[\x04IRC\x01] %s :  %s", nick, text);
		}
	}
}

public OnPluginEnd() {
	IRC_CleanUp();
}