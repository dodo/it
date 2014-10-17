#ifndef LUA_ENC_SETTINGS_H
#define LUA_ENC_SETTINGS_H

#include <lua.h>


void  luaI_pushencodersetting_value(lua_State* L, const SchroEncoderSetting* info, double value);
lua_Number luaI_toencodersetting_value(lua_State* L, int index, const SchroEncoderSetting* info);

void   luaI_setencodersetting(lua_State* L, int index, const SchroEncoderSetting* info);
double luaI_getencodersetting(lua_State* L, int index, const SchroEncoderSetting* info);

void luaI_setencodersettings(lua_State* L, int index);
void luaI_getencodersettings(lua_State* L, int index, SchroEncoder* encoder);


#endif /* LUA_ENC_SETTINGS_H */