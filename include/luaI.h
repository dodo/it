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

#define luaI_getlocalfield(L,fn) \
    (lua_getfield(L,-1,fn), lua_remove(L,-2))

#define luaI_getglobalfield(L,gn,fn) \
    (lua_getglobal(L,gn), luaI_getlocalfield(L,fn))

#define luaI_setglobalfield(L,gn,fn) \
    (lua_getglobal(L,gn), lua_insert(L,-2), lua_setfield(L,-2,fn), lua_pop(L,1))


extern int luaI_loadmetatable(lua_State* L, int i);
extern void luaI_newmetatable(lua_State* L, const char *name, const luaL_Reg *l);

extern int luaI_copyfunction(lua_State* L, lua_State* src);
extern luaI_function* luaI_tofunction(lua_State* L, int index);
extern int luaI_pushfunction(lua_State* L, luaI_function* func);

extern int luaI_dofile(lua_State* L, const char *filename);
extern void* luaI_checklightuserdata(lua_State* L, int i, const char *metatable);

extern it_processes* luaI_getprocess(lua_State* L);
extern it_states* luaI_getstate(lua_State* L);
extern int luaI_setstate(lua_State* L, it_states* ctx);
extern const char* luaI_getlibpath(lua_State* L, const char* filename);

extern void luaI_createdefinetable(lua_State* L);
extern void luaI_getdefine(lua_State* L, const char* key);
extern void luaI_setdefine(lua_State* L, const char* key);

extern luaI_value* luaI_getvalue(lua_State* L, int i);
extern void luaI_pushvalue(lua_State* L, luaI_value* value);

extern int luaI_newstate(lua_State* L, it_states* ctx);
extern int luaI_createstate(lua_State* L, it_processes* process);
extern int luaI_closestate(it_processes* process);

extern int luaI_pcall(lua_State* L, int nargs, int nresults, int safe);
extern int luaI_pcall_in(it_states* ctx, int nargs, int nresults);

extern int luaI_emit(lua_State* L, const char* event);
extern int luaI_localemit(lua_State* L, const char* field, const char* event);
extern int luaI_globalemit(lua_State* L, const char* global, const char* event);

extern int luaI_gc(lua_State* L);
extern void luaI_close(lua_State* L, int code);


#endif /* LUAI_H */
