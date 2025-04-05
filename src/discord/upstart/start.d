
//               Copyright Ahmet Sait 2024.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

module discord.upstart.start;

import std.array;
import std.conv;
import std.algorithm.searching;
import std.exception;
import std.process;

import discord.upstart.syscall;

void execDiscord()
{
	setRealIds();
	
	auto envAA = environment.toAA();
	Appender!(string[]) envBuf = appender!(string[]);
	envBuf.reserve(envAA.length);
	foreach (key, val; envAA)
		if (!namesToScrub.canFind(key))
			envBuf.put(text(key, '=', val));
	
	string[] env = envBuf.data;
	
	errnoEnforce(execvpe("/usr/share/discord/Discord", [], env) == 0);
}

void setRealIds()
{
	gid_t rgid, egid, sgid;
	errnoEnforce(getresgid(&rgid, &egid, &sgid) == 0);
	uid_t ruid, euid, suid;
	errnoEnforce(getresuid(&ruid, &euid, &suid) == 0);
	
	errnoEnforce(setresgid(rgid, rgid, rgid) == 0);
	errnoEnforce(setresuid(ruid, ruid, ruid) == 0);
}

immutable string[] namesToScrub = [
	"CHROME_DESKTOP",
	"GDK_BACKEND",
	"ICEAUTHORITY",
	"INVOCATION_ID",
	"JOURNAL_STREAM",
	"KONSOLE_DBUS_SERVICE",
	"MEMORY_PRESSURE_WATCH",
	"ORIGINAL_XDG_CURRENT_DESKTOP",
	"SESSION_MANAGER",
	"SHELL_SESSION_ID",
	"SYSTEMD_EXEC_PID",
	"WINDOWID",
];
