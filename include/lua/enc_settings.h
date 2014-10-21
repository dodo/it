#ifndef LUA_ENC_SETTINGS_H
#define LUA_ENC_SETTINGS_H

#include <lua.h>


void  luaI_pushencodersetting_value(lua_State* L, const SchroEncoderSetting* info, double value);
lua_Number luaI_toencodersetting_value(lua_State* L, int index, const SchroEncoderSetting* info);

void   luaI_setencodersetting(lua_State* L, int index, const SchroEncoderSetting* info, double value);
double luaI_getencodersetting(lua_State* L, int index, const SchroEncoderSetting* info);

void luaI_getencodersettings (lua_State* L, int index, SchroEncoder* encoder);
void luaI_pushencodersettings(lua_State* L,            SchroEncoder* encoder);
void luaI_pushschrosettings  (lua_State* L);


#endif /* LUA_ENC_SETTINGS_H */