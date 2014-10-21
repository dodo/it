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

#include "it.h"
#include "luaI.h"

#include "lua/enc.h"
#include "lua/enc_settings.h"
#include "lua/ctx.h"


static void schroI_encoder_wait(void* priv) {
    it_encodes* enc = (it_encodes*) priv;
    if (enc->eos_pulled) return;
    SchroStateEnum state = schro_encoder_wait(enc->encoder);
    switch (state) {
        case SCHRO_STATE_NEED_FRAME:
            if (enc->thread->closed) {
                schro_encoder_end_of_stream(enc->encoder);
            } else {
                int frames = enc->frames;
                // chance to create frame …
                luaI_getglobalfield(enc->thread->ctx->lua, "context", "emit");
                lua_getglobal(enc->thread->ctx->lua, "context"); // self
                lua_pushstring(enc->thread->ctx->lua, "need frame");
                // hopefully calls schro_encoder_push_frame
                luaI_pcall(enc->thread->ctx->lua, 2, 0);
                if (enc->frames == frames)
                    it_prints_error("no schro_encoder_push_frame happened!");
                // free all unused frames and other stuff
                if (lua_gc(enc->thread->ctx->lua, LUA_GCCOLLECT, 0))
                    luaL_error(enc->thread->ctx->lua, "internal error: lua_gc failed");
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
                uv_close((uv_handle_t*) enc->thread->idle, NULL);
                uv_stop(enc->thread->ctx->loop);
            }
            // skip lua and ogg in case buffer is not a full picture yet
            if (!SCHRO_PARSE_CODE_IS_PICTURE(parse_code)) {
                schro_buffer_unref(buffer);
                break;
            }
            // one time change to do something with this buffer …
            luaI_getglobalfield(enc->thread->ctx->lua, "context", "emit");
            lua_getglobal(enc->thread->ctx->lua, "context"); // self
            lua_pushstring(enc->thread->ctx->lua, "userdata");
            lua_pushlightuserdata(enc->thread->ctx->lua, enc->buffer);
            lua_pushinteger(enc->thread->ctx->lua, enc->length);
            luaI_pcall(enc->thread->ctx->lua, 4, 0);
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
                if (enc->packetno == 0) {
                    oggz_comment_set_vendor(enc->container, enc->serialno, IT_NAMES" "IT_VERSIONS);
                }
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

static void schroI_encoder_start(void* priv) {
    it_encodes* enc = (it_encodes*) priv;
    if (enc->started) return;
    enc->started = TRUE;
    schro_encoder_start(enc->encoder);
    // inject encoder handle into lua context …
    lua_pushlightuserdata(enc->thread->ctx->lua, enc);
    lua_setglobal(enc->thread->ctx->lua, "encoder");
}

static void schroI_encoder_free(void* priv) {
    it_encodes* enc = (it_encodes*) priv;
    if (!enc->encoder) return;
    schro_encoder_free(enc->encoder);
    enc->encoder = NULL;
    oggz_close(enc->container);
    enc->container = NULL;
    if (enc->length) {
        free(enc->buffer);
        enc->buffer = NULL;
        enc->length = 0;
    }
}

int it_new_enc_lua(lua_State* L) { // ((optional) enc_pointer)
    if (lua_gettop(L) == 1 && lua_islightuserdata(L, 1)) {
        lua_newtable(L);
    } else {
        it_encodes* enc = lua_newuserdata(L, sizeof(it_encodes));
        memset(enc, 0, sizeof(it_encodes));
    }
    luaI_setmetatable(L, "Encoder");
    return 1;
}

int it_creates_enc_lua(lua_State* L) { // (enc_userdata, state_userdata)
    it_encodes* enc    = luaL_checkudata(L, 1, "Encoder");
    it_threads* thread = luaL_checkudata(L, 2, "Thread");
    if (enc->encoder) return 0;
    enc->thread = thread;
    thread->priv = enc;
    thread->init = schroI_encoder_start;
    thread->callback = schroI_encoder_wait;
    thread->free = schroI_encoder_free;
    schro_init();
    enc->started = FALSE;
    enc->eos_pulled = FALSE;
    enc->encoder = schro_encoder_new();
    if (!enc->encoder)
        luaI_error(L, "schro_encoder_new: failed to create encoder");
    schro_video_format_set_std_video_format(&enc->encoder->video_format,
        SCHRO_VIDEO_FORMAT_SIF);// SCHRO_VIDEO_FORMAT_HD720P_60);
    return 0;
}

int it_starts_enc_lua(lua_State* L) { // (enc_userdata, output, settings)
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (enc->started) return 0;
    // fill encoder settings with state from lua
    luaI_getencodersettings(L, 3, enc->encoder);
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
    return 0;
}

int it_pushes_frame_enc_lua(lua_State* L) { // (enc_userdata, frame_userdata)
    it_encodes* enc = luaI_checklightuserdata(L, 1, "Encoder");
    it_frames* fr = luaI_checklightuserdata(L, 2, "Frame");
    if (enc->encoder && fr->frame) {
        // … and right into encoder. hopefully everything is right!
        schro_encoder_push_frame(enc->encoder, fr->frame);
        fr->frame = NULL; // prevent schro_frame_unref
        (enc->frames)++;
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }
    return 1;
}

int it_gets_settings_enc_lua(lua_State* L) { // (enc_userdata)
    if (lua_gettop(L) == 1 && !lua_isnil(L, 1)) {
        it_encodes* enc = luaI_checklightuserdata(L, 1, "Encoder");
        luaI_pushencodersettings(L, enc->encoder);
    } else {
        luaI_pushschrosettings(L);
    }
    return 1;
}

int it_gets_format_enc_lua(lua_State* L) { // (enc_userdata)
    it_encodes* enc = luaI_checklightuserdata(L, 1, "Encoder");
    if (!enc->encoder) return 0;
    SchroVideoFormat *format = schro_encoder_get_video_format(enc->encoder);
    lua_pushlightuserdata(L, format);
    return 1;
}

int it_sets_format_enc_lua(lua_State* L) { // (enc_userdata, videoformat_userdata)
    it_encodes* enc = luaL_checkudata(L, 1, "Encoder");
    if (!enc->encoder) return 0;
    SchroVideoFormat *format = lua_touserdata(L, 2);
    schro_encoder_set_video_format(enc->encoder, format);
    free(format);
    return 0;
}

int it_sets_debug_enc_lua(lua_State* L) { // (level)
    schro_debug_set_level(luaL_checkint(L, 1));
    return 0;
}
