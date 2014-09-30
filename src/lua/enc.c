#include <schroedinger/schro.h>

#include "lua/enc.h"

#include "it.h"
#include "luaI.h"


static void frame_free(SchroFrame *frame, void *priv) {
  free(priv);
}

int it_creates_enc_lua(lua_State* L) {
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    schro_init();
    enc->frames = 0;
    enc->buffer = NULL;
    enc->encoder = schro_encoder_new();
    return 1;
}

int it_starts_enc_lua(lua_State* L) {
    // TODO
    return 0;
}

int it_gets_format_enc_lua(lua_State* L) {
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    SchroVideoFormat *format = schro_encoder_get_video_format(enc->encoder);
    lua_pushlightuserdata(L, format);
    return 1;
}

int it_sets_format_enc_lua(lua_State* L) {
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    SchroVideoFormat *format = lua_touserdata(L, 2);
    schro_encoder_set_video_format(enc->encoder, format);
    free(format);
    return 0;
}

int it_kills_enc_lua(lua_State* L) {
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (enc->encoder) schro_encoder_free(enc->encoder);
    enc->encoder = NULL;
    return 0;
}
