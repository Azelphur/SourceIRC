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

public Plugin:myinfo = {
	name = "SourceIRC -> Hostmasks",
	author = "Azelphur",
	description = "Provides access based on hostmask",
	version = IRC_VERSION,
	url = "http://Azelphur.com/project/sourceirc"
};

new Handle:kv;

public OnConfigsExecuted() {
	kv = CreateKeyValues("SourceIRC");
	decl String:file[512];
	BuildPath(Path_SM, file, sizeof(file), "configs/sourceirc.cfg");
	FileToKeyValues(kv, file);
}

public IRC_RetrieveUserFlagBits(const String:hostmask[], &flagbits) {	
	if (!KvJumpToKey(kv, "Access")) return;
	if (!KvJumpToKey(kv, "Hostmasks")) return;
	if (!KvGotoFirstSubKey(kv, false)) return;
	decl String:key[64], String:value[64];
	new AdminFlag:tempflag;
	do
	{
		KvGetSectionName(kv, key, sizeof(key));
		if (IsWildCardMatch(hostmask, key)) {
			KvGetString(kv, NULL_STRING, value, sizeof(value));
			for (new i = 0; i <= strlen(value); i++) { 
				if (FindFlagByChar(value[i], tempflag)) {
					flagbits |= 1<<_:tempflag;
				}
			}
		}
	} while (KvGotoNextKey(kv, false));

	KvRewind(kv);
}

// http://bit.ly/defcon
