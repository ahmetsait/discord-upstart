
//               Copyright Ahmet Sait 2024.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

module discord.upstart.util;

import core.memory : pageSize;
import core.sys.posix.stdio : _IOLBF;
import core.sys.posix.sys.wait : waitpid;
import core.sys.posix.unistd : fork;

import std.algorithm;
import std.array;
import std.ascii;
import std.conv;
import std.exception;
import std.format;
import std.path;
import std.process;

import discord.upstart.syscall;

//string stringToIdentifier(string str)
//{
//	if (str.length == 0)
//		return str;
//	
//	static bool isIdentChar(dchar c) => isAlphaNum(c) || c == '_';
//	
//	bool validFirstChar = !isDigit(str[0]);
//	bool validString = str[1 .. $].all!isIdentChar;
//	
//	if (validString && validFirstChar)
//		return str;
//	
//	auto result = appender!(typeof(str));
//	result.reserve(str.length + (validFirstChar ? 0 : 1));
//	
//	if (!validFirstChar)
//	{
//		result.put('_');
//	}
//	
//	if (!validString)
//	{
//		foreach (char c; str)
//		{
//			result.put(isIdentChar(c) ? c : '_');
//		}
//	}
//	
//	return result[];
//}

immutable string[] sizeScales = [
	"B",
	"KiB",
	"MiB",
	"GiB",
	"TiB",
	"PiB",
	"EiB",
	"ZiB",
	"YiB",
	"BiB",
];

string formatSize(size_t sz)
{
	Appender!string buf = appender!string;
	size_t[sizeScales.length] buckets;
	foreach (scope ref size_t bucket; buckets)
	{
		bucket = sz % 1024;
		sz /= 1024;
	}
	bool first = true;
	foreach_reverse (i; 1 .. buckets.length)
	{
		size_t bucket = buckets[i];
		if (bucket > 0)
		{
			if (!first)
				buf.put(' ');
			formattedWrite(buf, "%s", bucket);
			buf.put(sizeScales[i]);
			first = false;
		}
	}
	if (first) // Less than a KiB
	{
		formattedWrite(buf, "%s", buckets[0]);
		buf.put(sizeScales[0]);
	}
	return buf[];
}

unittest
{
	assert(formatSize(1023) == "1023B");
	assert(formatSize(uint.max) == "3GiB 1023MiB 1023KiB");
	assert(formatSize(1024 ^^ 1) == "1KiB");
	assert(formatSize(1024 ^^ 2) == "1MiB");
	assert(formatSize(1024 ^^ 3) == "1GiB");
	assert(formatSize(1024 ^^ 3 + 1024 ^^ 2) == "1GiB 1MiB");
}

///// Fires up the command and an accompanying Konsole instance that shows output of the command.
//void createUnprivilegedKonsole(string command, string[] args)
//{
//	Pipe p2c = pipe();
//	p2c.readEnd.setvbuf(pageSize, _IOLBF);
//	p2c.writeEnd.setvbuf(pageSize, _IOLBF);
//	pid_t pidApt = fork();
//	errnoEnforce(pidApt != -1);
//	string pidAptStr = pidApt.to!string;
//	if (pidApt == 0) // Sub command
//	{
//		p2c.readEnd.readln();
//		p2c.readEnd.close();
//		p2c.writeEnd.close();
//		execvp(command, args);
//	}
//	else // Konsole creator
//	{
//		pid_t pidKonsole = fork();
//		errnoEnforce(pidKonsole != -1);
//		if (pidKonsole == 0) // Konsole
//		{
//			gid_t rgid, egid, sgid;
//			errnoEnforce(getresgid(&rgid, &egid, &sgid) == 0);
//			uid_t ruid, euid, suid;
//			errnoEnforce(getresuid(&ruid, &euid, &suid) == 0);
//			if (euid == 0)
//			{
//				errnoEnforce(setresgid(rgid, rgid, rgid) == 0);
//				errnoEnforce(setresuid(ruid, ruid, ruid) == 0);
//			}
//			//execvp("konsole", ["--nofork", "-e", "tail", "-f", "/dev/null", "--pid", pidAptStr]);
//			execvp("konsole", ["--nofork", "-e", "tail", "-f", buildPath("/proc", pidAptStr, "fd/1"), "--pid", pidAptStr]);
//		}
//		else
//		{
//			p2c.readEnd.close();
//			p2c.writeEnd.writeln();
//			p2c.writeEnd.close();
//			
//			waitpid(pidKonsole, null, 0);
//		}
//	}
//}
