#ifndef LUA_ENC_H
#define LUA_ENC_H

#include <lua.h>

int it_creates_enc_lua(lua_State* L);
int it_starts_enc_lua(lua_State* L);
int it_gets_format_enc_lua(lua_State* L);
int it_sets_format_enc_lua(lua_State* L);
int it_sets_debug_enc_lua(lua_State* L);
int it_kills_enc_lua(lua_State* L);

#endif /* LUA_ENC_H */