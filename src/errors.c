#define __USE_GNU
#define _GNU_SOURCE
#include <dlfcn.h>

#ifdef NDEBUG
    #undef NDEBUG
#endif

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
    if (!thread) it_errors("at_panic: current thread not found!");
    // first things first
    if (!thread->backtrace->count)
        uvI_thread_stacktrace(thread);
    // lets print the problem
    luaI_stacktrace(L);
    printerr("PANIC@Thread %d: %s\n",
            uvI_thread_pool_index(thread->pthread),
            lua_tostring(L, -1));
    // now try to announce the problem back to lua, when possible
    lua_getglobal(L, "process");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        printerr("internal error during boot.\n");
        panic_attack = FALSE;
        return 0;
    }
    lua_getfield( L, -1, "emit");
    lua_pushvalue(L, -2);
    lua_remove(   L, -3);
    lua_pushliteral(L, "panic");
    lua_pushvalue(L, -4);
    luaI_pcall(L, 3, 0, 2/*super safe*/);
    panic_attack = FALSE;
    return 0;
}

static bool missed_thread = FALSE;
void at_fatal_panic(int signum) {
    // first things first
    uvI_thread_t* thread = uvI_thread_self();
    if (!thread) {
        if (!missed_thread) {
            it_prints_error("at_fatal_panic: current thread not found!");
            missed_thread = TRUE;
        }
        return;
    }
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
int luaI_xpcall(lua_State* L, int nargs, int nresults, int safe) {
    if (!safe) { // hardcore!
        lua_call(L, nargs, nresults);
        return 0;
    }
    uvI_thread_t* thread = uvI_thread_self();
    if (!thread) it_errors("at luaI_xpcall: current thread not found!");
    if (!thread->safe && safe != 2) { // hardcore!
        lua_call(L, nargs, nresults);
        return 0;
    }
    signal(SIGILL, &at_fatal_panic);
    if (!missed_thread) signal(SIGABRT, &at_fatal_panic);
    signal(SIGFPE, &at_fatal_panic);
    signal(SIGSEGV, &at_fatal_panic);
    signal(SIGSYS, &at_fatal_panic);
    thread->checksum = IT_CHECKSUMS;
    int pos = uvI_thread_notch(thread);
    int num = setjmp(thread->jmp[pos]);
    if (num) uvI_thread_unnotch(thread);
    if (num < 0) {
        lua_State* lua = luaL_newstate();
        if (lua) {
            lua_pushfstring(lua, "caught signal %d: %s\n", -num, strsignal(-num));
            luaI_stacktrace(lua);
            lua_error(lua);
        } else {
            it_prints_error("caught signal %d: %s\n", -num, strsignal(-num));
        }
        return 0;
    }
    // got signal
    if (num > 0) return num - 1; // ignore error and keep running
//     int result = luaI_pcall_with(L, nargs, nresults, luaI_simpleerror);
    int result = luaI_pcall_with(L, nargs, nresults, luaI_stacktrace);
    // success
    uvI_thread_unnotch(thread);
    return result;
}

int luaI_pcall_with(lua_State* L, int nargs, int nresults, lua_CFunction f) {
    int msgh = 0 - nargs - 2;
    lua_pushcfunction(L, f);
    lua_insert(L, msgh);
    int result = lua_pcall(L, nargs, nresults, msgh);
    if (result) nresults = 1; // just one error message
    lua_remove(L, 0 - nresults - 1);
    return result;
}

int luaI_simpleerror(lua_State* L) {
    if (!lua_isstring(L, -1)) {
        lua_pop(L, 1); // whateva it is
        lua_pushliteral(L, "missing error message");
    } else if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_pushliteral(L, "nil error message");
    } else {
        lua_State* lua = luaL_newstate();
        if (!lua) {
            it_prints_error("error while getting simple error message");
            it_prints_error("%s", lua_tostring(L, -1));
            lua_pop(L, 1);
        }
        luaL_loadstring(lua, "return string.match(..., '([^\\n]+)')");
        lua_pushstring(lua, lua_tostring(L, -1));
        lua_pop(L, 1);
        if (lua_pcall(lua, 1, 1, 0)) {
            lua_pushliteral(L, "error during message extraction: ");
            lua_pushstring( L, lua_tostring(lua, -1));
            lua_concat(L, 2);
        }
        lua_close(lua);
    }
    return 1;
}

int luaI_stacktrace(lua_State* L) {
    uvI_thread_t* thread = uvI_thread_self();
    if (!thread) it_errors("luaI_stacktrace: current thread not found!");
    lua_CFunction func;
    lua_Debug info;
    Dl_info dlinfo;
    char nr[LUA_IDSIZE];
    char addr[LUA_IDSIZE];
    int skips = 0;
    int level = 0 - thread->backtrace->count;
    it_states *tmp = calloc(1, sizeof(it_states));
    if (tmp && luaI_newstate(NULL, tmp)) {
        free(tmp);
        tmp = NULL;
    }
    int strings = lua_isstring(L, -1); // starts with error message on top of stack
    if (strings && !lua_objlen(L, -1)) {
        lua_pop(L, 1);
        --strings;
    }
    if (thread->backtrace->count && strings) {
        if (lua_isstring(L, -2) && !lua_isnumber(L, -2)) {
//             lua_remove(L, -2); // somehow err msg is doubled
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
                sprintf(info.short_src, "%s", dlinfo.dli_fname);
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
        lua_pushliteral(L, "\n");
        ++strings;
        // get source code
        if (info.what[0] == 'C') {
            ++level;
            continue;
        }
        if (tmp) { // try to extract lua code
            lua_pushliteral(L, "        ");
            luaL_loadstring(tmp->lua, "return require('it.fs').line(...)");
            lua_pushstring(tmp->lua, info.short_src);
            lua_pushinteger(tmp->lua, info.currentline);
            if (luaI_pcall_with(tmp->lua, 2, 1, luaI_simpleerror)) {
                lua_pushliteral(L, "--[[! internal error: missing lua lines: ");
                lua_pushstring( L, lua_tostring(tmp->lua, -1));
                lua_pushliteral(L, " !]]\n");
                lua_pop(tmp->lua,  1);
                strings += 4;
            } else if (lua_isnil(tmp->lua, -1)) {
                // no lua code found, so skip it
                lua_pop(tmp->lua, 1);
                lua_pop(L, 1);
            } else {
                lua_pushstring( L, lua_tostring(tmp->lua, -1));
                lua_pushliteral(L, "\n");
                lua_pop(tmp->lua,  1);
                strings += 3;
            }
        }
        ++level;
    }
    if (level + thread->backtrace->count - skips) {
        lua_pushliteral(L, "\n");
        lua_insert(L, 0 - strings);
        ++strings;
    }
    if (tmp) {
        lua_close(tmp->lua);
        free(tmp);
    }
    lua_concat(L, strings);
    thread->backtrace->count = 0;
    return 1;
}

int luaI_init_errorhandling(lua_State* L) {
    signal(SIGPIPE, SIG_IGN); // ignore borken pipe
    // lets generate heisenbugs!
    lua_atpanic(L, at_panic);
    lua_pushcfunction(L, luaI_stacktrace);
    lua_setglobal(L, "_TRACEBACK");
    return 0;
}

