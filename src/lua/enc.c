#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <uv.h>

#include <oggz/oggz.h>

#define SCHRO_ENABLE_UNSTABLE_API

#include <schroedinger/schro.h>
#include <schroedinger/schrodebug.h>
#include <schroedinger/schroutils.h>
#include <schroedinger/schrobuffer.h>

#include "lua/enc.h"
#include "lua/ctx.h"

#include "it.h"
#include "luaI.h"


static void it_frees_frame(SchroFrame* frame, void* priv) {
  free(priv);
}

static void it_waits_on_encoder(uv_idle_t* handle, int status) {
    it_encodes* enc = (it_encodes*) handle->data;
    if (enc->eos_pulled) return;
    SchroStateEnum state = schro_encoder_wait(enc->encoder);
    switch (state) {
        case SCHRO_STATE_NEED_FRAME:
            if (enc->closed) {
                schro_encoder_end_of_stream(enc->encoder);
            } else {
                //SCHRO_ERROR("frame %d", n_frames);
                uint8_t* buffer = malloc(enc->size);
                memset(buffer, 128, enc->size);

                SchroFrame* frame = schro_frame_new_from_data_I420(buffer, enc->width, enc->height);
                schro_frame_set_free_callback(frame, it_frees_frame, buffer);
                // chance to change frame …
                luaI_getglobalfield(enc->ctx->lua, "context", "emit");
                lua_getglobal(enc->ctx->lua, "context"); // self
                lua_pushstring(enc->ctx->lua, "rawframe");
                lua_pushlightuserdata(enc->ctx->lua, frame);
                luaI_pcall(enc->ctx->lua, 3, 0);
                // … and right into encoder. hopefully everything is right!
                schro_encoder_push_frame(enc->encoder, frame);
                (enc->frames)++;
            }
            break;
        case SCHRO_STATE_END_OF_STREAM:
        case SCHRO_STATE_HAVE_BUFFER: {
            int nr;
            SchroBuffer* buffer = schro_encoder_pull(enc->encoder, &nr);
            if (buffer->length <= 0)
                it_errors("schro_encoder_pull: buffer[%d]", buffer->length);
            int parse_code = buffer->data[4];
            // accumulate buffers to one packet
            enc->buffer = realloc(enc->buffer, enc->length + buffer->length);
            memcpy(enc->buffer + enc->length, buffer->data, buffer->length);
            enc->length += buffer->length;
            // close in cose of eos
            if (state == SCHRO_STATE_END_OF_STREAM) {
                enc->eos_pulled = TRUE;
                uv_close((uv_handle_t*) enc->idle, NULL);
                uv_stop(enc->loop);
            }
            // skip lua and ogg in case buffer is not a full picture yet
            if (!SCHRO_PARSE_CODE_IS_PICTURE(parse_code)) {
                schro_buffer_unref(buffer);
                break;
            }
            // one time change to do something with this buffer …
            luaI_getglobalfield(enc->ctx->lua, "context", "emit");
            lua_getglobal(enc->ctx->lua, "context"); // self
            lua_pushstring(enc->ctx->lua, "userdata");
            lua_pushlightuserdata(enc->ctx->lua, enc->buffer);
            lua_pushinteger(enc->ctx->lua, enc->length);
            luaI_pcall(enc->ctx->lua, 4, 0);
            { // … now pump it out …
                ogg_packet op = {
                    .packet = enc->buffer,
                    .bytes = enc->length,
                    .b_o_s = -1, // auto bos
                    .e_o_s = (enc->eos_pulled) ? 1 : 0,
                    .granulepos = enc->granulepos,
                    .packetno = enc->packetno,
                };
                // add to write queue
                // this function has to be the first oggz_* that uses
                //   enc->serialno for the first time
                //   to get propper ogg stream content type detected
                oggz_write_feed(enc->container, &op, enc->serialno,
                                OGGZ_FLUSH_AFTER, NULL/*guard*/);
                // increase state
//                 enc->granulepos += 100; // FIXME use either fake or real time here
                enc->granulepos += 22; /* not a typo */ // same as in liboggz/oggz_auto.c#auto_dirac
                enc->packetno++;
            } // … and it's gone.
            enc->buffer = NULL;
            enc->length = 0;
            schro_buffer_unref(buffer);
          };break;
        case SCHRO_STATE_AGAIN:
            break;
        default: // should never happen
            it_errors("unknown encoder state");
            break;
    }
    /* Write bytes from packetized bitstream to the output file */
    oggz_run(enc->container); // flush ogg pages to ogg output // FIXME thread?
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
    luaI_pcall(enc->ctx->lua, 0, 0);
    // … and now run!
    uv_run(enc->loop, UV_RUN_DEFAULT);
}

int it_creates_enc_lua(lua_State* L) { // (enc_userdata, state_userdata, settings)
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    it_states*  ctx = luaL_checkudata(L, 2, "Context");
    if (enc->encoder) return 0;
    ctx->free = FALSE; // take over ctx
    schro_init();
    enc->ctx = ctx;
    enc->size = 0;
    enc->length = 0;
    enc->frames = 0;
    enc->serialno = 0;
    enc->packetno = 0;
    enc->granulepos = 0;
    enc->thread = NULL;
    enc->buffer = NULL;
    enc->closed = FALSE;
    enc->eos_pulled = FALSE;
    enc->encoder = schro_encoder_new();
    if (!enc->encoder)
        luaI_error(L, "schro_encoder_new: failed to create encoder");
    schro_video_format_set_std_video_format(&enc->encoder->video_format,
        SCHRO_VIDEO_FORMAT_SIF);// SCHRO_VIDEO_FORMAT_HD720P_60);
    // fill settings table from args
    int i; int n = schro_encoder_get_n_settings();
    for (i = 0; i < n; i++) {
        const SchroEncoderSetting* info = schro_encoder_get_setting_info(i);
        lua_createtable(L, 0, 4);
        lua_pushnumber(L, info->min);
        lua_setfield(L, -2, "min");
        lua_pushnumber(L, info->max);
        lua_setfield(L, -2, "max");
        lua_pushnumber(L, info->default_value);
        lua_setfield(L, -2, "value");
        lua_pushnumber(L, info->default_value);
        lua_setfield(L, -2, "default");
        // now store table in settings
        lua_setfield(L, 3, info->name);
    }
    return 1;
}

int it_starts_enc_lua(lua_State* L) { // (enc_userdata, output, settings)
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (enc->thread) return 0;
    // fill encoder settings with state from lua
    int i; int n = schro_encoder_get_n_settings();
    for (i = 0; i < n; i++) {
        const SchroEncoderSetting* info = schro_encoder_get_setting_info(i);
        lua_getfield(L, 3, info->name);
        lua_getfield(L, -1, "value");
        schro_encoder_setting_set_double(enc->encoder, info->name, lua_tonumber(L, -1));
        lua_pop(L, 2);
    }
    // now open ogg container
    const char* name;
    int flags = OGGZ_WRITE;
    if (lua_isnil(L, 2)) {
        name = "oggz_new";
        enc->container = oggz_new(flags);
    } else if (lua_isstring(L, 2)) {
        name = "oggz_open";
        enc->container = oggz_open(lua_tostring(L, 2), flags);
    } else { // probably userdata
        name = "oggz_open_stdio";
        FILE *fd = lua_touserdata(L, 2);
        enc->container = oggz_open_stdio(fd, flags);
    }
    if (!enc->container)
        luaI_error(L, "%s: failed to create oggz container", name);
    enc->serialno = oggz_serialno_new(enc->container);
    // now start the thread to run the encoder
    enc->thread = malloc(sizeof(uv_thread_t));
    if (!enc->thread)
        luaI_error(L, "failed to initialize thread!");
    if (uv_thread_create(enc->thread, thread_encode, enc))
        luaI_error(L, "uv_thread_create: failed to create thread!");
    return 0;
}

int it_gets_format_enc_lua(lua_State* L) { // (enc_userdata)
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (!enc->encoder) return 0;
    SchroVideoFormat *format = schro_encoder_get_video_format(enc->encoder);
    lua_pushlightuserdata(L, format);
    return 1;
}

int it_sets_format_enc_lua(lua_State* L) { // (enc_userdata, videoformat_userdata)
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

int it_sets_debug_enc_lua(lua_State* L) { // (level)
    schro_debug_set_level(luaL_checkint(L, 1));
    return 0;
}

int it_kills_enc_lua(lua_State* L) { // (enc_userdata)
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (!enc->encoder) return 0;
    enc->closed = TRUE;
    uv_thread_join(enc->thread);
    free(enc->thread);
    enc->thread = NULL;
    enc->ctx->free = TRUE; //now we can
    it_frees_ctx(enc->ctx);
    enc->ctx = NULL;
    schro_encoder_free(enc->encoder);
    enc->encoder = NULL;
    oggz_close(enc->container);
    enc->container = NULL;
    if (enc->length) {
        free(enc->buffer);
        enc->buffer = NULL;
        enc->length = 0;
    }
    return 0;
}
