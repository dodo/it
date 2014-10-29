#ifndef API_ENCODER_SETTINGS_H
#define API_ENCODER_SETTINGS_H

#include <lua.h>

#include <schroedinger/schroencoder.h>


extern void  luaI_pushencodersetting_value(lua_State* L, const SchroEncoderSetting* info, double value);
lua_Number luaI_toencodersetting_value(lua_State* L, int index, const SchroEncoderSetting* info);

extern void   luaI_setencodersetting(lua_State* L, int index, const SchroEncoderSetting* info, double value);
double luaI_getencodersetting(lua_State* L, int index, const SchroEncoderSetting* info);

extern void luaI_getencodersettings (lua_State* L, int index, SchroEncoder* encoder);
extern void luaI_pushencodersettings(lua_State* L,            SchroEncoder* encoder);
extern void luaI_pushschrosettings  (lua_State* L);


#endif /* API_ENCODER_SETTINGS_H */