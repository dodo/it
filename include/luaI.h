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


#ifndef luaL_newlib
    // these are missing in luajit but defined in lua > 5.2
    #define luaL_setfuncs(L,l,n) \
        luaL_register(L,NULL,l)

    #define luaL_newlibtable(L,l) \
        lua_createtable(L, 0, sizeof(l)/sizeof((l)[0]) - 1)

    #define luaL_newlib(L,l) \
        (luaL_newlibtable(L,l), luaL_setfuncs(L,l,0))
#endif

#define luaI_newlib(L,name,l) \
    (luaL_newlib(L,l), lua_setglobal(L,name))

#define luaI_newmetatable(L,name,l) \
    do {if (luaL_newmetatable(L,name)) { \
        luaL_newlib(L,l); \
        lua_setfield(L, -2, "__index"); \
    }} while (0)

#define luaI_setmetatable(L,name) \
    (luaL_getmetatable(L,name), lua_setmetatable(L,-2))

#define luaI_getglobalfield(L,gn,fn) \
    (lua_getglobal(L,gn), lua_getfield(L,-1,fn), lua_remove(L,-2))

#define luaI_setglobalfield(L,gn,fn) \
    (lua_getglobal(L,gn), lua_pushvalue(L,-2), lua_setfield(L,-2,fn), lua_pop(L,2))


int luaI_loadmetatable(lua_State* L, int i);

int luaI_copyfunction(lua_State* L, lua_State* src);
int luaI_dofile(lua_State* L, const char *filename);

it_processes* luaI_getprocess(lua_State* L);
it_states* luaI_getstate(lua_State* L);
int luaI_setstate(lua_State* L, it_states* ctx);

int luaI_newstate(it_states* ctx);
int luaI_createstate(it_processes* process);

#endif /* LUAI_H */