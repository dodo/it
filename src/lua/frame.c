#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <schroedinger/schroframe.h>

#include "it.h"
#include "luaI.h"

#include "lua/frame.h"


// static void it_frees_frame(SchroFrame* frame, void* priv) {
//   free(priv);
// }

int it_creates_frame_lua(lua_State* L) { // (frame_userdata, frame_data)
    it_frames* fr = luaL_checkudata(L, 1, "Frame");
    if (fr->frame) schro_frame_unref(fr->frame);
    if (lua_isnumber(L, 2)) {
        schro_init();
        SchroFrameFormat format = luaL_checkint(L, 2);
        fr->frame = schro_frame_new_and_alloc(NULL,format,fr->width,fr->height);
    } else if (lua_islightuserdata(L, 2)) {
        fr->frame = lua_touserdata(L, 2);
    } else luaI_error(L, "unknown data to create SchroFrame from");
    lua_pushlightuserdata(L, fr->frame);
    return 1;
}

int it_converts_frame_lua(lua_State* L) {
    it_frames* fr = luaL_checkudata(L, 1, "Frame");
    if (!fr->frame) return 0;
    SchroFrame* frame;
    if (lua_isnumber(L, 2)) {
        schro_init();
        SchroFrameFormat format = luaL_checkint(L, 2);
        frame = schro_frame_new_and_alloc(NULL, format, fr->width, fr->height);
    } else if (lua_islightuserdata(L, 2)) {
        frame = lua_touserdata(L, 2);
    } else luaI_error(L, "unknown data to convert SchroFrame to");
    schro_frame_convert(frame, fr->frame);
    lua_pushlightuserdata(L, frame);
    return 1;
}

int it_kills_frame_lua(lua_State* L) { // (frame_userdata)
    it_frames* fr = luaL_checkudata(L, 1, "Frame");
    if (!fr->frame) return 0;
    schro_frame_unref(fr->frame);
    fr->frame = NULL;
    return 0;
}
