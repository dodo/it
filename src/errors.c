#define __USE_GNU
#define _GNU_SOURCE
#include <dlfcn.h>

#include <assert.h>
#include <string.h>
#include <signal.h>
#include <setjmp.h>
#include <execinfo.h>

#include "it-errors.h"

#include "it.h"
#include "uvI.h"
#include "luaI.h"



static bool panic_attack = FALSE;


int at_panic(lua_State* L) {
    if (panic_attack) {
        printerr("FATAL PANIC %s\n", lua_tostring(L, -1));
        return 0;
    }
    panic_attack = TRUE;
    uvI_thread_t* thread = uvI_thread_self();
    if (!thread) abort();
    // first things first
    if (!thread->backtrace->count)
        uvI_thread_stacktrace(thread);
    lua_getglobal(L, "process");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        luaI_stacktrace(L);
        printerr("internal error during boot: %s\n", lua_tostring(L,-1));
        panic_attack = FALSE;
        return 0;
    }
    lua_getfield( L, -1, "emit");
    lua_pushvalue(L, -2);
    lua_remove(   L, -3);
    lua_pushstring(L, "panic");
    lua_pushvalue(L, -4);
    luaI_pcall(L, 3, 0);
    luaI_stacktrace(L);
    printerr("PANIC@%s\n", lua_tostring(L, -1));
    panic_attack = FALSE;
    return 0;
}

void at_fatal_panic(int signum) {
    // first things first
    uvI_thread_t* thread = uvI_thread_self();
    if (!thread) abort();
    uvI_thread_stacktrace(thread);
    // shorten back trace by removing 'it'-internals
//     Dl_info dlinfo;
//     int i; for (i = 0; i < thread->backtrace->count ; i ++) {
//         if (thread->backtrace->addrs[i]) {
//             if (dladdr(thread->backtrace->addrs[i], &dlinfo)) {
//                 if (dlinfo.dli_saddr == at_luajit_cfunction_call) {
//                     thread->backtrace->count = i;
//                     break;
//                 }
//             }
//         }
//     }
    // jump back …
    uvI_thread_jmp(thread, -signum);
}

// TODO FIXME use siglongjump to block all signals during exception, to prevent recursion
int luaI_xpcall(lua_State* L, int nargs, int nresults, int errfunc) {
    uvI_thread_t* thread = uvI_thread_self();
    if (!thread) it_errors("current thread not found!");
    if (!thread->safe) {// hardcore!
        lua_call(L, nargs, nresults);
        return nresults;
    }
    signal(SIGILL, &at_fatal_panic);
    signal(SIGABRT, &at_fatal_panic);
    signal(SIGFPE, &at_fatal_panic);
    signal(SIGSEGV, &at_fatal_panic);
    signal(SIGSYS, &at_fatal_panic);
    int pos = uvI_thread_notch(thread);
    int num = setjmp(thread->jmp[pos]);
    if (num) uvI_thread_unnotch(thread);
    if (num < 0) return luaL_error(L, "%s%s", (lua_isstring(L, -1)?": ":""), strsignal(-num)); // got signal
    if (num > 0) return num - 1; // ignore error and keep running
    int result = lua_pcall(L, nargs, nresults, errfunc);
    // success
    uvI_thread_unnotch(thread);
    return result;
}

int luaI_stacktrace(lua_State* L) {
    uvI_thread_t* thread = uvI_thread_self();
    if (!thread) abort();
    lua_CFunction func;
    lua_Debug info;
    Dl_info dlinfo;
    char nr[LUA_IDSIZE];
    char addr[LUA_IDSIZE];
    int skips = 0;
    int level = 0 - thread->backtrace->count;
    int strings = lua_isstring(L, -1); // starts with error message on top of stack
    if (thread->backtrace->count && strings) {
        if (lua_isstring(L, -2) && !lua_isnumber(L, -2)) {
            lua_insert(L, -2); // swap lua err msg with luaI_xpcall err msg
            ++strings;
        }
    }
    while (level < 0 || lua_getstack(L, level, &info)) {
        func = NULL;
        addr[0] = '\0';
        if (level < 0) {
            func = thread->backtrace->addrs[level + thread->backtrace->count];
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
            if (dladdr(func, &dlinfo)) {
                if (dlinfo.dli_saddr) {
                    if (dlinfo.dli_saddr == luaI_stacktrace ||
                        dlinfo.dli_saddr == uvI_thread_stacktrace) {
                        // ignore luaI_stacktrace
                        if (level >= 0) lua_pop(L, 1);
                        ++skips; ++level; continue;
                    }
                    sprintf(addr, "|%p%c", dlinfo.dli_saddr, '\0');
                }
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
            sprintf(addr, ":%d%c", info.linedefined, '\0');
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
        luaL_loadstring(L, "return require('fs').line(...)");
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
    if (level + thread->backtrace->count - skips) {
        lua_pushstring(L, "\n");
        lua_insert(L, -strings);
        strings++;
    }
    lua_concat(L, strings);
    thread->backtrace->count = 0;
    return 1;
}

int luaI_init_errorhandling(lua_State* L) {
    signal(SIGPIPE, SIG_IGN); // ignore borken pipe

    lua_atpanic(L, at_panic);
    lua_pushcfunction(L, luaI_stacktrace);
    lua_setglobal(L, "_TRACEBACK");
    return 0;
}

