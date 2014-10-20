#include <stdlib.h>
#include <string.h>

#include "it.h"
#include "luaI.h"

#include "lua/buffer.h"


static void it_frees_buffer(it_buffers* buf) {
    if (buf->free && buf->buffer) {
        free(buf->buffer);
        buf->buffer = NULL;
    }
}

int it_new_buffer_lua(lua_State* L) { // ()
    it_buffers* buf = lua_newuserdata(L, sizeof(it_buffers));
    memset(buf, 0, sizeof(it_buffers));
    buf->free = FALSE;
    luaI_setmetatable(L, "Buffer");
    return 1;
}

int it_uses_userdata_buffer_lua(lua_State* L) { // (buf_userdata, void*_userdata)
    it_buffers* buf = luaL_checkudata(L, 1, "Buffer");
    void* userdata = lua_touserdata(L, 2);
    it_frees_buffer(buf);
    buf->buffer = userdata;
    buf->free = FALSE;
    return 0;
}

int it_mallocs_buffer_lua(lua_State* L) { // (buf_userdata, size)
    it_buffers* buf = luaL_checkudata(L, 1, "Buffer");
    size_t size = (size_t) luaL_checkint(L, 2);
    buf->buffer = malloc(size);
    buf->free = TRUE;
    return 0;
}

int it_memcpies_buffer_lua(lua_State* L) { // (dest_buf_userdata, src_buf_userdata, size)
    it_buffers* dst = luaL_checkudata(L, 1, "Buffer");
    it_buffers* src = luaL_checkudata(L, 2, "Buffer");
    size_t size = (size_t) luaL_checkint(L, 3);
    dst->buffer = memcpy(dst->buffer, src->buffer, size);
    return 0;
}

int it_kills_buffer_lua(lua_State* L) { // (buf_userdata)
    it_frees_buffer(luaL_checkudata(L, 1, "Buffer"));
    return 0;
}
