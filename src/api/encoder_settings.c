#include <string.h>

#include <schroedinger/schro.h>

#include "it.h"
#include "luaI.h"

#include "api/encoder_settings.h"


void luaI_pushencodersetting_value(lua_State* L, const SchroEncoderSetting* info, double value) {
    switch (info->type) {
        case SCHRO_ENCODER_SETTING_TYPE_BOOLEAN:
            lua_pushboolean(L, value);
            return;
        case SCHRO_ENCODER_SETTING_TYPE_INT:
            lua_pushinteger(L, value);
            return;
        case SCHRO_ENCODER_SETTING_TYPE_ENUM:
            lua_pushstring(L, info->enum_list[(int) value]);
            return;
        case SCHRO_ENCODER_SETTING_TYPE_DOUBLE:
            lua_pushnumber(L, value);
            return;
        default:
            lua_pushnil(L);
            return;
    }
}

lua_Number luaI_toencodersetting_value(lua_State* L, int index, const SchroEncoderSetting* info) {
    switch (info->type) {
        case SCHRO_ENCODER_SETTING_TYPE_BOOLEAN:
            return lua_toboolean(L, index);
        case SCHRO_ENCODER_SETTING_TYPE_INT:
            return lua_tointeger(L, index);
        case SCHRO_ENCODER_SETTING_TYPE_DOUBLE:
            return lua_tonumber(L, index);
        case SCHRO_ENCODER_SETTING_TYPE_ENUM: {
            int i; int len = 1 + info->max - info->min;
            const char* value = lua_tostring(L, index);
            for (i = 0; i < len; i++) {
                if (strcmp(value, info->enum_list[i + ((int) info->min)])) {
                    continue;
                }
                return i;
            }}
        default:
            return -1;
    }
}

void luaI_setencodersetting(lua_State* L, int index, const SchroEncoderSetting* info, double value) {
    // create table with setting parameters (min, max, default or stringified enum)
    if (info->type == SCHRO_ENCODER_SETTING_TYPE_ENUM) {
        int len = 1 + info->max - info->min;
        lua_createtable(L, len, 2);
        int i;
        for (i = 0; i < len; i++) {
            lua_pushstring(L, info->enum_list[i + ((int) info->min)]);
            lua_rawseti(L, -2, i + 1);
        }
    } else if (info->type == SCHRO_ENCODER_SETTING_TYPE_BOOLEAN) {
        lua_createtable(L, 0, 2);
    } else {
        lua_createtable(L, 0, 4);
        luaI_pushencodersetting_value(L, info, info->min);
        lua_setfield(L, -2, "min");
        luaI_pushencodersetting_value(L, info, info->max);
        lua_setfield(L, -2, "max");
    }
    luaI_pushencodersetting_value(L, info, value);
    lua_setfield(L, -2, "value");
    luaI_pushencodersetting_value(L, info, info->default_value);
    lua_setfield(L, -2, "default");
    // now store table in settings
    lua_setfield(L, index - (index < 0), info->name);
}

double luaI_getencodersetting(lua_State* L, int index, const SchroEncoderSetting* info) {
    double value = -1; int k = 1;
    lua_getfield(L, index, info->name);
    if (lua_istable(L, -1)) {
        lua_getfield(L, -1, "value");
        k++;
    }
    value = luaI_toencodersetting_value(L, -1, info);
    // restore table if value was overwritten
    if (k == 1) luaI_setencodersetting(L, index, info, value);
    lua_pop(L, k);
    return value;
}

void luaI_getencodersettings(lua_State* L, int index, SchroEncoder* encoder) {
    int i; int n = schro_encoder_get_n_settings();
    for (i = 0; i < n; i++) {
        const SchroEncoderSetting* info = schro_encoder_get_setting_info(i);
        schro_encoder_setting_set_double(encoder, info->name,
            luaI_getencodersetting(L, index, info));
    }
}

void luaI_pushencodersettings(lua_State* L, SchroEncoder* encoder) {
    int i; int n = schro_encoder_get_n_settings();
    lua_createtable(L, 0, n);
    for (i = 0; i < n; i++) {
        const SchroEncoderSetting* info = schro_encoder_get_setting_info(i);
        luaI_setencodersetting(L, -1, info,
            schro_encoder_setting_get_double(encoder, info->name));
    }
}

void luaI_pushschrosettings(lua_State* L) {
    int i; int n = schro_encoder_get_n_settings();
    lua_createtable(L, 0, n);
    for (i = 0; i < n; i++) {
        const SchroEncoderSetting* info = schro_encoder_get_setting_info(i);
        luaI_setencodersetting(L, -1, info, info->default_value);
    }
}
