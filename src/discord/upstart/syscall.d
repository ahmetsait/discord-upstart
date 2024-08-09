
//               Copyright Ahmet Sait 2024.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

module discord.upstart.syscall;

public import core.sys.posix.sys.types;

extern(C) int getresuid(uid_t *ruid, uid_t *euid, uid_t *suid);
extern(C) int getresgid(gid_t *rgid, gid_t *egid, gid_t *sgid);

extern(C) int setresuid(uid_t ruid, uid_t euid, uid_t suid);
extern(C) int setresgid(gid_t rgid, gid_t egid, gid_t sgid);
