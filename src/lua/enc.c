#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <uv.h>

#define SCHRO_ENABLE_UNSTABLE_API

#include <schroedinger/schro.h>
#include <schroedinger/schrodebug.h>
#include <schroedinger/schroutils.h>
#include <schroedinger/schrobuffer.h>

#include "lua/enc.h"

#include "it.h"
#include "luaI.h"


static void it_frees_frame(SchroFrame* frame, void* priv) {
  free(priv);
}

static void it_waits_on_encoder(uv_idle_t* handle, int status) {
    it_encodes* enc = (it_encodes*) handle->data;
    switch (schro_encoder_wait(enc->encoder)) {
        case SCHRO_STATE_NEED_FRAME:
            if (enc->closed) {
                schro_encoder_end_of_stream(enc->encoder);
            } else {
                //SCHRO_ERROR("frame %d", n_frames);

                enc->buffer = malloc(enc->size);
                memset(enc->buffer, 128, enc->size);

                SchroFrame* frame = schro_frame_new_from_data_I420(enc->buffer, enc->width, enc->height);
                schro_frame_set_free_callback(frame, it_frees_frame, enc->buffer);
                // chance to change frame …
                luaI_getglobalfield(enc->ctx->lua, "context", "emit");
                lua_getglobal(enc->ctx->lua, "context"); // self
                lua_pushstring(enc->ctx->lua, "rawframe");
                lua_pushlightuserdata(enc->ctx->lua, frame);
                lua_call(enc->ctx->lua, 3, 0);
                // … and right into encoder. hopefully everything is right!
                schro_encoder_push_frame(enc->encoder, frame);
                (enc->frames)++;
            }
            break;
        case SCHRO_STATE_HAVE_BUFFER: {
            int nr;
            SchroBuffer* buffer = schro_encoder_pull(enc->encoder, &nr);
            // one time change to do something with this buffer …
            luaI_getglobalfield(enc->ctx->lua, "context", "emit");
            lua_getglobal(enc->ctx->lua, "context"); // self
            lua_pushstring(enc->ctx->lua, "userdata");
            lua_pushlightuserdata(enc->ctx->lua, buffer->data);
            lua_pushinteger(enc->ctx->lua, buffer->length);
            lua_call(enc->ctx->lua, 4, 0);
            // … and it's gone.
            schro_buffer_unref(buffer);
          };break;
        case SCHRO_STATE_AGAIN:
            break;
        case SCHRO_STATE_END_OF_STREAM:
            uv_close((uv_handle_t*) enc->idle, NULL);
            uv_stop(enc->loop);
            break;
        default:
            break;
    }
}

static void thread_encode(void* priv) {
    it_encodes* enc = (it_encodes*) priv;
    schro_encoder_start(enc->encoder);
    enc->loop = uv_loop_new();
    enc->ctx->loop = enc->loop; // switch context loop to thread loop
    uv_idle_t idle;
    enc->idle = &idle;
    uv_idle_init(enc->loop, enc->idle);
    enc->idle->data = enc;
    uv_idle_start(enc->idle, it_waits_on_encoder);
    // call into lua state first …
    luaI_getglobalfield(enc->ctx->lua, "context", "run");
    lua_call(enc->ctx->lua, 0, 0);
    // … and now run!
    uv_run(enc->loop, UV_RUN_DEFAULT);
}

int it_creates_enc_lua(lua_State* L) {
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    it_states*  ctx = luaL_checkudata(L, 2, "Context");
    schro_init();
    enc->ctx = ctx;
    enc->frames = 0;
    enc->thread = NULL;
    enc->buffer = NULL;
    enc->closed = FALSE;
    enc->encoder = schro_encoder_new();
    return 1;
}

int it_starts_enc_lua(lua_State* L) {
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (enc->thread) return 0;
    uv_thread_t thread;
    enc->thread = &thread;
    uv_thread_create(enc->thread, thread_encode, enc);
    return 0;
}

int it_gets_format_enc_lua(lua_State* L) {
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (!enc->encoder) return 0;
    SchroVideoFormat *format = schro_encoder_get_video_format(enc->encoder);
    lua_pushlightuserdata(L, format);
    return 1;
}

int it_sets_format_enc_lua(lua_State* L) {
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (!enc->encoder) return 0;
    SchroVideoFormat *format = lua_touserdata(L, 2);

    int w = format->width; int h = format->height;
    int size = ROUND_UP_4(w) * ROUND_UP_2(h);
    size += (ROUND_UP_8(w)/2) * (ROUND_UP_2(h)/2);
    size += (ROUND_UP_8(w)/2) * (ROUND_UP_2(h)/2);
    enc->height = h;
    enc->width = w;
    enc->size = size;
    schro_encoder_set_video_format(enc->encoder, format);
    free(format);
    return 0;
}

int it_sets_debug_enc_lua(lua_State* L) {
    schro_debug_set_level(luaL_checkint(L, 1));
    return 0;
}

int it_kills_enc_lua(lua_State* L) {
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (!enc->encoder) return 0;
    enc->closed = TRUE;
    uv_thread_join(enc->thread);
    schro_encoder_free(enc->encoder);
    enc->encoder = NULL;
    return 0;
}
