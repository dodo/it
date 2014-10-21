#ifndef LUA_IT_H
#define LUA_IT_H

#include <lua.h>

int it_boots_lua(lua_State* L);
int it_loads_lua(lua_State* L);
int it_forks_lua(lua_State* L);
int it_stdios_lua(lua_State* L);
int it_encodes_lua(lua_State* L);
int it_buffers_lua(lua_State* L);
int it_frames_lua(lua_State* L);
int it_windows_lua(lua_State* L);
int it_versions_lua(lua_State* L);

#endif /* LUA_IT_H */