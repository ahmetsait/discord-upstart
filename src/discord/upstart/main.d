
//               Copyright Ahmet Sait 2024.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

module discord.upstart.main;

import std.conv;
import std.exception;
import std.file;
import std.json;
import std.net.curl;
import std.path;
import std.stdio;

import discord.upstart.app;
import discord.upstart.start;
import discord.upstart.syscall;
import discord.upstart.version_;

version(unittest)
void main()
{
	writeln(".::Done unittesting::.");
}
else
int main(string[] args)
{
	uid_t ruid, euid, suid;
	errnoEnforce(getresuid(&ruid, &euid, &suid) == 0);
	
	if (euid != 0)
	{
		stderr.writeln("Root privileges needed for installing packages.");
		return 1;
	}
	if (ruid == euid)
	{
		stderr.writeln("Need to be run as a root setuid executable.");
		return 1;
	}
	
	immutable string discordPath = `/usr/share/discord`;
	
	immutable string buildInfoPath = buildPath(discordPath, "resources", "build_info.json");
	immutable string buildInfoText = readText(buildInfoPath);
	immutable JSONValue buildInfo = parseJSON(buildInfoText);
	
	immutable string releaseChannel = buildInfo["releaseChannel"].str;
	immutable string apiVersionUrl = text("https://discord.com/api/updates/", releaseChannel, "?platform=linux");
	immutable string currentVersionString = buildInfo["version"].str;
	immutable Version currentVersion = Version.parse(currentVersionString);
	
	immutable string apiPayload = get(apiVersionUrl).assumeUnique();
	immutable JSONValue apiJson = parseJSON(apiPayload);
	immutable string latestVersionString = apiJson["name"].str;
	immutable Version latestVersion = Version.parse(latestVersionString);
	
	if (currentVersion >= latestVersion)
		execDiscord();
	
	App app = new App("nx.discord.upstart", releaseChannel);
	app.run(args);
	
	return 0;
}
