#define __USE_GNU
#define _GNU_SOURCE
#include <dlfcn.h>

#include <string.h>
#include <signal.h>
#include <setjmp.h>
#include <execinfo.h>

#include "it-errors.h"

#include "it.h"
#include "luaI.h"


typedef struct {
    jmp_buf jmp;
    int count;
    void *addrs[BACK_TRACE_SIZE];
} it_debugs;


it_debugs cbacktrace;


int at_panic(lua_State* L) {
    lua_getglobal(L, "process");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        fprintf(stderr, "FATALPANIC@%s\n", lua_tostring(L, -1));
        return 0;
    }
    lua_getfield( L, -1, "emit");
    lua_pushvalue(L, -2);
    lua_remove(   L, -3);
    lua_pushstring(L, "panic");
    lua_pushvalue(L, -4);
    luaI_pcall(L, 3, 0);
    fprintf(stderr, "PANIC@%s\n", lua_tostring(L, -1));
    return 0;
}

void at_fatal_panic(int signum) {
    // first things first
    cbacktrace.count = backtrace(cbacktrace.addrs, BACK_TRACE_SIZE);
    // shorten back trace by removing 'it'-internals
    Dl_info dlinfo;
    int i; for (i = 0; i < cbacktrace.count ; i ++) {
        if (cbacktrace.addrs[i] && dladdr(cbacktrace.addrs[i], &dlinfo)) {
            if (dlinfo.dli_saddr == at_luajit_cfunction_call) {
                cbacktrace.count = i;
                break;
            }
        }
    }
    // jump back …
    longjmp(cbacktrace.jmp, signum);
}

int at_luajit_cfunction_call(lua_State* L, lua_CFunction func) {
    int signum = setjmp(cbacktrace.jmp);
    if (!signum) {
        signal(SIGILL, &at_fatal_panic);
        signal(SIGABRT, &at_fatal_panic);
        signal(SIGFPE, &at_fatal_panic);
        signal(SIGSEGV, &at_fatal_panic);
        signal(SIGSYS, &at_fatal_panic);
        return func(L);
    } else luaI_error(L, "%s", strsignal(signum));
}

int luaI_stacktrace(lua_State* L) {
    lua_CFunction func;
    lua_Debug info;
    Dl_info dlinfo;
    char nr[LUA_IDSIZE];
    char addr[LUA_IDSIZE];
    int skips = 0;
    int level = 0 - cbacktrace.count;
    int strings = 1; // starts with error message on top of stack
    while (level < 0 || lua_getstack(L, level, &info)) {
        func = NULL;
        addr[0] = '\0';
        if (level < 0) {
            func = cbacktrace.addrs[level + cbacktrace.count];
            info.namewhat = "";
            info.what = "";
            info.name = "";
            info.currentline = -1;
            info.linedefined = -1;
            info.short_src[0] = '\0';
        } else {
            lua_getinfo(L, "nSlf", &info);
            if (lua_iscfunction(L, -1)) {
                func = lua_tocfunction(L, -1);
            }
        }
        // silently overlook problems with finding the ptr
        if (func) {
            if (dladdr(func, &dlinfo) || dladdr(&func, &dlinfo)) {
                if (dlinfo.dli_saddr)
                    sprintf(addr, "|%p(%p)%c", dlinfo.dli_saddr, func, '\0');
                sprintf(info.short_src, "%s%c", dlinfo.dli_fname, '\0');
                info.name = dlinfo.dli_sname;
                if (!info.namewhat[0])
                     info.namewhat = "function";
                if (!info.what[0])
                     info.what = "C";
            }
            if (!addr[0]) sprintf(addr, "|%p%c", func, '\0');
        }
        if (level >= 0) {
            lua_pop(L, 1);
            if (!info.name && !info.namewhat[0] && info.currentline == -1) {
                ++skips;
                ++level;
                continue;
            }
        }
        // prepare addr if missing
        if (!addr[0] && info.linedefined > 0)
            sprintf(addr, " +%d%c", info.linedefined, '\0');
        sprintf(nr, "%3d%c", level - skips, '\0');
        // print everything in multiple steps per line
        lua_pushfstring(L, "%s  in %s  ",
            nr, (info.name ? info.name : "<unknown>"));
        ++strings;
        if (info.namewhat[0]) {
            lua_pushfstring(L, "(%s %s at %s%s)",
                info.what, info.namewhat, info.short_src, addr);
            ++strings;
        } else {
            lua_pushfstring(L, "(at %s%s)",
                info.short_src, addr);
            ++strings;
        }
        if (info.currentline > 0) {
            lua_pushfstring(L, "  at line %d",
                info.currentline);
            ++strings;
        }
        lua_pushstring(L, "\n");
        ++strings;
        // get source code
        if (info.what[0] == 'C') {
            ++level;
            continue;
        }
        lua_pushstring(L, "        ");
        luaI_getglobalfield(L, "_it", "getlines");
        lua_pushstring(L, info.short_src);
        lua_pushinteger(L, info.currentline);
        lua_call(L, 2, 1);
        if (lua_isnil(L, -1)) {
            lua_pop(L, 2);
        } else {
            lua_pushstring(L, "\n");
            strings += 3;
        }
        ++level;
    }
    if (level + cbacktrace.count - skips) {
        lua_pushstring(L, "\n");
        lua_insert(L, 2);
        strings++;
    }
    lua_concat(L, strings);
    cbacktrace.count = 0;
    return 1;
}

int luaI_init_errorhandling(lua_State* L) {
    signal(SIGPIPE, SIG_IGN); // ignore borken pipe
    cbacktrace.count = 0;
    lua_atpanic(L, at_panic);
    lua_pushcfunction(L, luaI_stacktrace);
    lua_setglobal(L, "_TRACEBACK");
    // Define cfunction wrapper
    // FIXME wrap only when needed
    lua_pushlightuserdata(L, at_luajit_cfunction_call);
    luaJIT_setmode(L, -1, LUAJIT_MODE_WRAPCFUNC|LUAJIT_MODE_ON);
    lua_pop(L, 1);
    return 0;
}

