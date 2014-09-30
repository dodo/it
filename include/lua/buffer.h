#ifndef LUA_BUFFER_H
#define LUA_BUFFER_H

#include <lua.h>


int it_mallocs_buffer_lua(lua_State* L);
int it_memcpies_buffer_lua(lua_State* L);
int it_kills_buffer_lua(lua_State* L);


#endif /* LUA_BUFFER_H */
