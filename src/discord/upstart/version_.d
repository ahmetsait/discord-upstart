
//               Copyright Ahmet Sait 2024.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

module discord.upstart.version_;

import std.array;
import std.conv;
import std.format;

struct Version
{
	union
	{
		struct
		{
			uint major, minor, patch, build;
		}
		uint[4] nums;
	}
	
	ref uint opIndex(size_t index) @safe pure return
	{
		return this.nums[index];
	}
	
	int opCmp(const Version other) const @safe pure
	{
		return
			this.major < other.major ? -1 :
			this.major > other.major ? +1 :
			this.minor < other.minor ? -1 :
			this.minor > other.minor ? +1 :
			this.patch < other.patch ? -1 :
			this.patch > other.patch ? +1 :
			this.build < other.build ? -1 :
			this.build > other.build ? +1 :
			0;
	}
	
	static Version parse(const(char)[] str) @safe pure
	{
		const(char)[][] arr = split(str, '.');
		assert(arr.length >= 1 && arr.length <= 4);
		Version result;
		foreach (i, num; arr)
			result[i] = num.to!uint;
		return result;
	}
	
	string toString() const @safe pure
	{
		auto buf = appender!string;
		buf ~= nums[0].to!string;
		foreach (num; nums[1 .. 3])
		{
			buf ~= '.';
			buf ~= num.to!string;
		}
		foreach (num; nums[3 .. $])
		{
			if (num != 0)
			{
				buf ~= '.';
				formattedWrite(buf, "%s", num);
			}
		}
		return buf[];
	}
}
