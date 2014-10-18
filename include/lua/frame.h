#ifndef LUA_FRAME_H
#define LUA_FRAME_H

#include <lua.h>

int it_new_frame_lua(lua_State* L);
int it_creates_frame_lua(lua_State* L);
int it_converts_frame_lua(lua_State* L);
int it_gets_data_frame_lua(lua_State* L);
int it_reverses_order_frame_lua(lua_State* L);
int it_kills_frame_lua(lua_State* L);

#endif /* LUA_FRAME_H */
