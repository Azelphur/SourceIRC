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

#include <socket>
#undef REQUIRE_PLUGIN
#include <sourceirc>

#pragma semicolon 1

#define SERVERDATA_EXECCOMMAND 2
#define SERVERDATA_AUTH 3

new Handle:gsocket = INVALID_HANDLE;
new REQUESTID = 0;
new bool:busy = false;
new String:greplynick[64];
new String:gcommand[256];

public Plugin:myinfo = {
	name = "SourceIRC -> RCON",
	author = "Azelphur",
	description = "Allows you to run RCON commands",
	version = IRC_VERSION,
	url = "http://Azelphur.com/project/sourceirc"
};

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
	IRC_RegAdminCmd("rcon", Command_RCON, ADMFLAG_RCON, "rcon <command> - Run an rcon command on the server.");
}

public Action:Command_RCON(const String:nick[], args) {
	if (busy)
		IRC_ReplyToCommand(nick, "%t", "RCON Busy");
	else {
		IRC_GetCmdArgString(gcommand, sizeof(gcommand));
		strcopy(greplynick, sizeof(greplynick), nick);
		Connect();
	}
	return Plugin_Handled;
}

Connect() {
	decl String:ServerIp[16];
	new iIp = GetConVarInt(FindConVar("hostip"));
	Format(ServerIp, sizeof(ServerIp), "%i.%i.%i.%i", (iIp >> 24) & 0x000000FF,
                                                          (iIp >> 16) & 0x000000FF,
                                                          (iIp >>  8) & 0x000000FF,
                                                          iIp         & 0x000000FF);
	new ServerPort = GetConVarInt(FindConVar("hostport"));
	gsocket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketConnect(gsocket, OnSocketConnect, OnSocketReceive, OnSocketDisconnected, ServerIp, ServerPort); 
}

public OnSocketConnect(Handle:socket, any:arg) {
	decl String:rcon_password[256];
	GetConVarString(FindConVar("rcon_password"), rcon_password, sizeof(rcon_password));
	if (StrEqual(rcon_password, ""))
		SetFailState("You need to enable RCON to use this plugin");
	ReplaceString(rcon_password, sizeof(rcon_password), "%", "%%"); // Escape out any percent symbols that should happen to be in the password
	Send(SERVERDATA_AUTH, rcon_password);
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:hFile) {
	new i = 0;
	while (i < dataSize) {
		new packetlen = ReadByte(receiveData[i]);
		new requestid = ReadByte(receiveData[i+4]);
		new serverdata = ReadByte(receiveData[i+8]);
		if (serverdata == 2) {
			if (requestid == 1)
				Send(SERVERDATA_EXECCOMMAND, gcommand);
			else
				IRC_ReplyToCommand(greplynick, "Unable to connect to RCON");
		}
		if (serverdata == 0 && requestid > 1) {
			decl String:lines[64][256];
			new linecount = ExplodeString(receiveData[i+12], "\n", lines, sizeof(lines), sizeof(lines[]));
			for (new l = 0; l < linecount; l++) {
				IRC_ReplyToCommand(greplynick, "%s", lines[l]);
			}
			busy = false;
			SocketDisconnect(gsocket);
			REQUESTID = 0;
			CloseHandle(socket);
		}
		i += packetlen+4;
	}
}

public OnSocketDisconnected(Handle:socket, any:hFile) {
	REQUESTID = 0;
	CloseHandle(socket);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:hFile) {
	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}

ReadByte(String:recieveData[]) {
	new numbers[4];
	for (new i = 0; i <= 3; i++) {
		numbers[i] = recieveData[i];
	}
	new number = 0;
	number += numbers[0];
	number += numbers[1]<<8;
	number += numbers[2]<<16;
	number += numbers[3]<<24;
	return number;
}

Send(type, const String:format[], any:...) {
	REQUESTID++;
	decl String:packet[1024], String:command[1014];
	VFormat(command, sizeof(command), format, 2);
	new num = strlen(command)+10;
	Format(packet, sizeof(packet), "%c%c%c%c%c%c%c%c%c%c%c%c%s\x00\x00", num&0xFF, num>>8&0xFF, num>>16&0xFF, num>>24&0xFF, REQUESTID&0xFF, REQUESTID>>8&0xFF, REQUESTID>>16&0xFF, REQUESTID>>24&0xFF, type&0xFF, type>>8&0xFF, type>>16&0xFF, type>>24&0xFF, command);
	SocketSend(gsocket, packet, strlen(command)+14);
	return;
}

public OnPluginEnd() {
	IRC_CleanUp();
}

// http://bit.ly/defcon
