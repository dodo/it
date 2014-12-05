#ifndef LUAI_H
#define LUAI_H

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

#include <luajit.h>
#include <lualib.h>
#include <lauxlib.h>

#include "it-types.h"
#include "it-errors.h"


#ifndef luaL_newlib
    // these are missing in luajit but defined in lua > 5.2
    #define luaL_setfuncs(L,l,n) \
        luaL_register(L,NULL,l)

    #define luaL_newlibtable(L,l) \
        lua_createtable(L, 0, sizeof(l)/sizeof((l)[0]) - 1)

    #define luaL_newlib(L,l) \
        (lua_newtable(L), luaL_setfuncs(L,l,0))
//         (luaL_newlibtable(L,l), luaL_setfuncs(L,l,0)) FIXME
#endif

#define luaI_newlib(L,name,l) \
    (luaL_newlib(L,l), lua_setglobal(L,name))

#define luaI_setmetatable(L,name) \
    (luaL_getmetatable(L,name), lua_setmetatable(L,-2))

#define luaI_getglobalfield(L,gn,fn) \
    (lua_getglobal(L,gn), lua_getfield(L,-1,fn), lua_remove(L,-2))

#define luaI_setglobalfield(L,gn,fn) \
    (lua_getglobal(L,gn), lua_insert(L,-2), lua_setfield(L,-2,fn), lua_pop(L,1))

#define luaI_pcall(L,nargs,nresults,safe) \
    do{lua_getglobal(L, "_TRACEBACK"); \
      lua_insert(L,0 - nargs - 2); \
      if (luaI_xpcall(L,nargs,nresults,0 - nargs - 2, safe)) { \
        lua_error(L); \
      } \
      lua_remove(L, 0 - nresults - 1);\
    } while (0)

#define luaI_pcall_in(ctx,nargs,nresults) \
    do{if (!ctx->err) { \
      lua_getglobal(ctx->lua, "_TRACEBACK"); \
      lua_insert(ctx->lua,0 - nargs - 2); \
      if (luaI_xpcall(ctx->lua,nargs,nresults,0 - nargs - 2, ctx->safe)) { \
        ctx->err = lua_tostring(ctx->lua, -1); \
        lua_pop(ctx->lua, 2); \
      } else lua_remove(ctx->lua, 0 - nresults - 1);\
    }} while (0)

#define luaI_emit(L,ev) \
    (lua_getfield(L,-1,"emit"),\
     lua_pushvalue(L,-2),\
     lua_remove(L,-3),\
     lua_pushstring(L,ev))

#define luaI_localemit(L,gn,ev) \
    (lua_getfield(L,-1,gn),\
     lua_remove(L,-2),\
     luaI_emit(L,ev))

#define luaI_globalemit(L,gn,ev) \
    (luaI_getglobalfield(L,gn,"emit"),lua_getglobal(L,gn),lua_pushstring(L,ev))

#define luaI_gc(L) \
    do {if (lua_gc(L, LUA_GCCOLLECT, 0)) \
        luaL_error(L, "internal error: lua_gc failed"); \
    } while (0)


int luaI_loadmetatable(lua_State* L, int i);
void luaI_newmetatable(lua_State* L, const char *name, const luaL_Reg *l);

int luaI_copyfunction(lua_State* L, lua_State* src);
int luaI_dofile(lua_State* L, const char *filename);
void* luaI_checklightuserdata(lua_State* L, int i, const char *metatable);

it_processes* luaI_getprocess(lua_State* L);
it_states* luaI_getstate(lua_State* L);
int luaI_setstate(lua_State* L, it_states* ctx);
const char* luaI_getlibpath(lua_State* L, const char* filename);

void luaI_createdefinetable(lua_State* L);
void luaI_getdefine(lua_State* L, const char* key);
void luaI_setdefine(lua_State* L, const char* key);

luaI_value* luaI_getvalue(lua_State* L, int i);
void luaI_pushvalue(lua_State* L, luaI_value* value);

int luaI_newstate(it_states* ctx);
int luaI_createstate(it_processes* process);
void luaI_close(lua_State* L, const char *global, int code);


#endif /* LUAI_H */
