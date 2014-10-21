#ifndef LUA_THREAD_H
#define LUA_THREAD_H

#include <lua.h>


int it_new_thread_lua(lua_State* L);
int it_inits_thread_lua(lua_State* L);
int it_creates_thread_lua(lua_State* L);
int it_kills_thread_lua(lua_State* L);


#endif /* LUA_THREAD_H */

