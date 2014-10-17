#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define SCHRO_ENABLE_UNSTABLE_API

#include <schroedinger/schro.h>
#include <schroedinger/schroframe.h>

#include "it.h"
#include "luaI.h"

#include "lua/frame.h"


int it_new_frame_lua(lua_State* L)  { // (width, height)
    int w = luaL_checkint(L, 1);
    int h = luaL_checkint(L, 2);
    int size = ROUND_UP_4(w) * ROUND_UP_2(h);
    size += (ROUND_UP_8(w)/2) * (ROUND_UP_2(h)/2);
    size += (ROUND_UP_8(w)/2) * (ROUND_UP_2(h)/2);
    it_frames* fr = lua_newuserdata(L, sizeof(it_frames));
    fr->frame = NULL;
    fr->size = size;
    fr->width = w;
    fr->height = h;
    luaI_setmetatable(L, "Frame");
    return 1;
}

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

int it_gets_data_frame_lua(lua_State* L) { // (frame_userdata) //, cairo_surface_userdata)
    it_frames* fr = luaL_checkudata(L, 1, "Frame");
    if (!fr->frame) return 0;
    lua_pushlightuserdata(L, fr->frame->components[0].data);
    if (SCHRO_FRAME_IS_PACKED(fr->frame->format)) return 1;
    lua_pushlightuserdata(L, fr->frame->components[1].data);
    lua_pushlightuserdata(L, fr->frame->components[2].data);
    return 3;
}

int it_kills_frame_lua(lua_State* L) { // (frame_userdata)
    it_frames* fr = luaL_checkudata(L, 1, "Frame");
    if (!fr->frame) return 0;
    schro_frame_unref(fr->frame);
    fr->frame = NULL;
    return 0;
}
