
//               Copyright Ahmet Sait 2024.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

module discord.upstart.start;

import std.exception;
import std.process;

import discord.upstart.syscall;

void execDiscord()
{
	setRealIds();
	errnoEnforce(execvp("discord", []) == 0);
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
