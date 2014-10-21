#ifndef LUA_WINDOW_H
#define LUA_WINDOW_H

#include <lua.h>

int sdlI_ref(int c);

int it_new_window_lua(lua_State* L);
int it_inits_window_lua(lua_State* L);
int it_creates_window_lua(lua_State* L);
int it_kills_window_lua(lua_State* L);

#endif /* LUA_WINDOW_H */
