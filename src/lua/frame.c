#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <schroedinger/schroframe.h>

#include "it.h"
#include "luaI.h"

#include "lua/frame.h"


static void it_frees_frame(SchroFrame* frame, void* priv) {
  free(priv);
}

int it_creates_frame_lua(lua_State* L) { // (frame_userdata, frame_data)
    it_frames* fr = luaL_checkudata(L, 1, "Frame");
    if (fr->frame) schro_frame_unref(fr->frame);
    if (lua_isnil(L, 2)) {
        uint8_t* buffer = malloc(fr->size);
        memset(buffer, 128, fr->size);
        fr->frame = schro_frame_new_from_data_I420(buffer, fr->width, fr->height);
        schro_frame_set_free_callback(fr->frame, it_frees_frame, buffer);
    } else luaI_error(L, "unknown data to create SchroFrame from");
    lua_pushlightuserdata(fr->ctx->lua, fr->frame);
    return 1;
}

int it_kills_frame_lua(lua_State* L) { // (frame_userdata)
    it_frames* fr = luaL_checkudata(L, 1, "Frame");
    fr->ctx = NULL;
    if (!fr->frame) return 0;
    schro_frame_unref(fr->frame);
    fr->frame = NULL;
    return 0;
}
