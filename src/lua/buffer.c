#include <stdlib.h>

#include "lua/buffer.h"

#include "it.h"
#include "luaI.h"


int it_mallocs_buffer_lua(lua_State* L) {
    it_buffers* buf = luaL_checkudata(L, 1, "Buffer");
    size_t size = (size_t) luaL_checkint(L, 2);
    buf->buffer = malloc(size);
    buf->free = TRUE;
    return 0;
}

int it_kills_buffer_lua(lua_State* L) {
    it_buffers* buf = luaL_checkudata(L, 1, "Buffer");
    if (buf->free && buf->buffer) {
        free(buf->buffer);
        buf->buffer = NULL;
    }
    return 0;
}
