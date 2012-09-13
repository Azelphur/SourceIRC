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

#undef REQUIRE_PLUGIN
#include <sourceirc>

#pragma semicolon 1
#pragma dynamic 65535

public Plugin:myinfo = {
	name = "SourceIRC -> Change Map",
	author = "Azelphur",
	description = "Adds a changemap command to SourceIRC",
	version = IRC_VERSION,
	url = "http://Azelphur.com/project/sourceirc"
};

public OnPluginStart() {
	LoadTranslations("sourceirc.phrases");
}

public OnAllPluginsLoaded() {
	if (LibraryExists("sourceirc"))
		IRC_Loaded();
}

public OnLibraryAdded(const String:name[]) {
	if (StrEqual(name, "sourceirc"))
		IRC_Loaded();
}

IRC_Loaded() {
	IRC_CleanUp(); // Call IRC_CleanUp as this function can be called more than once.
	IRC_RegAdminCmd("changemap", Command_ChangeMap, ADMFLAG_CHANGEMAP, "changemap <map> - Changes the current map, you can use a partial map name.");
}

public Action:Command_ChangeMap(const String:nick[], args) {
	decl String:text[IRC_MAXLEN];
	IRC_GetCmdArgString(text, sizeof(text));
	if (IsMapValid(text)) {
		IRC_ReplyToCommand(nick, "%t", "Changing Map", text);
		ForceChangeLevel(text, "Requested from IRC");
	}
	else {
		decl String:storedmap[64], String:map[64];
		new Handle:maps = CreateArray(64);
		ReadMapList(maps);
		new bool:foundmatch = false;
		for (new i = 0; i < GetArraySize(maps); i++) {
			GetArrayString(maps, i, storedmap, sizeof(storedmap));
			if (StrContains(storedmap, text, false) != -1) {
				if (!foundmatch) {
					strcopy(map, sizeof(map), storedmap);
					foundmatch = true;
				}
				else {
					IRC_ReplyToCommand(nick, "%t", "Multiple Maps", text);
					return Plugin_Handled;
				}
			}
		}
		if (foundmatch) {
			IRC_ReplyToCommand(nick, "%t", "Changing Map", map);
			ForceChangeLevel(map, "Requested from IRC");
			return Plugin_Handled;
		}
		else {
			IRC_ReplyToCommand(nick, "%t", "Invalid Map", text);
		}
	}
	return Plugin_Handled;
}

public OnPluginEnd() {
	IRC_CleanUp();
}

// http://bit.ly/defcon
