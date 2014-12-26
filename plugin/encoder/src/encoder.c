#include <uv.h>

#include <oggz/oggz.h>

#include <schroedinger/schro.h>
#include <schroedinger/schroencoder.h>
#include <schroedinger/schrodebug.h>
#include <schroedinger/schroutils.h>
#include <schroedinger/schrobuffer.h>

#include "it.h"
#include "api.h"
#include "uvI.h"
#include "luaI.h"

#include "encoder.h"
#include "encoder_settings.h"

#include "api/thread.h"
#include "api/scope.h"


void schroI_encoder_wait(void* priv) {
    it_encodes* enc = (it_encodes*) priv;
    if (enc->eos_pulled || enc->thread->ctx->err) return;
    SchroStateEnum state = schro_encoder_wait(enc->encoder);
    switch (state) {
        case SCHRO_STATE_NEED_FRAME:
            if (enc->thread->closed) {
                schro_encoder_end_of_stream(enc->encoder);
            } else {
                // chance to create frame …
                int frames = enc->frames;
                luaI_globalemit(enc->thread->ctx->lua, "encoder", "need frame");
                // hopefully calls schro_encoder_push_frame
                luaI_pcall_in(enc->thread->ctx, 2, 0);
                if (enc->thread->ctx->err) return;
                if (enc->frames == frames)
                    it_errors("no schro_encoder_push_frame happened!");
//                     it_prints_error("no schro_encoder_push_frame happened!");
                // free all unused frames and other stuff
                it_collectsgarbage_scope(enc->thread->ctx);
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
                it_closes_thread(enc->thread);
            }
            // skip lua and ogg in case buffer is not a full picture yet
            if (!SCHRO_PARSE_CODE_IS_PICTURE(parse_code)) {
                schro_buffer_unref(buffer);
                break;
            }
            // one time change to do something with this buffer …
            luaI_globalemit(enc->thread->ctx->lua, "encoder", "userdata");
            lua_pushlightuserdata(enc->thread->ctx->lua, enc->buffer);
            lua_pushinteger(enc->thread->ctx->lua, enc->length);
            luaI_pcall_in(enc->thread->ctx, 4, 0);
            if (enc->thread->ctx->err) return;
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

void schroI_run_stage(SchroEncoderFrame* frame) {
    it_encodes* enc = (it_encodes*) frame->encoder->userdata;
    it_states*  ctx = enc->hooks[frame->working];
    if (!ctx) return;
    // need a temporary thread register here cuz stages can switch threads
    uvI_thread_t* thread = uvI_thread_tmp();
    luaI_globalemit(ctx->lua, "encoder", "run stage");
    lua_pushlightuserdata(ctx->lua, frame);
    // FIXME this runs in an unregistered thread (not known to our thread pool in uvI.c)
    luaI_pcall_in(ctx, 3, 0);
    uvI_thread_free(thread);
    // free all unused frames and other stuff
    it_collectsgarbage_scope(ctx);
}

void schroI_encoder_start(void* priv) {
    it_encodes* enc = (it_encodes*) priv;
    if (enc->started) return;
    enc->started = TRUE;
    schro_encoder_start(enc->encoder);
}

void schroI_encoder_free(void* priv) {
    it_encodes* enc = (it_encodes*) priv;
    if (!enc->encoder) return;
    SchroEncoder* encoder = enc->encoder;
    enc->encoder = NULL;
    // might take a while …
    schro_encoder_free(encoder);
    OGGZ* container = enc->container;
    enc->container = NULL;
    // might take a while …
    oggz_close(container);
    // close all opened hook scope
    int i; for (i = 0; i < SCHRO_ENCODER_FRAME_STAGE_LAST; i++) {
        if (enc->hooks[i]) {
            enc->hooks[i]->free = TRUE; // now we can
            it_frees_scope(enc->hooks[i]);
            enc->hooks[i] = NULL;
        }
    }
    if (enc->length) {
        free(enc->buffer);
        enc->buffer = NULL;
        enc->length = 0;
    }
}

void it_inits_encoder(it_encodes* enc, it_threads* thread, SchroVideoFormatEnum format) {
    if (enc->encoder || !thread) return;
    enc->thread = thread;
    thread->priv = enc;
    thread->on_init = schroI_encoder_start;
    thread->on_idle = schroI_encoder_wait;
    thread->on_free = schroI_encoder_free;
    schro_init();
    enc->started = FALSE;
    enc->eos_pulled = FALSE;
    enc->encoder = schro_encoder_new();
    if (!enc->encoder)
        it_errors("schro_encoder_new: failed to create encoder");
    schro_video_format_set_std_video_format(
        &enc->encoder->video_format, format);
}

void it_hooks_stage_encoder(it_encodes* enc,
                           SchroEncoderFrameStateEnum stage, it_states* ctx) {
    if (!enc->encoder || !ctx) return;
    // install encoding stage hook
    enc->encoder->user_stage = schroI_run_stage;
    enc->encoder->userdata = enc;
    // add hook
    enc->hooks[stage] = ctx;
    ctx->free = FALSE; // take over ctx
}

int it_pushes_frame_encoder(it_encodes* enc, it_frames* fr) {
    if (!enc->encoder || !fr->frame) return 0;
    // … and right into encoder. hopefully everything is right!
    schro_encoder_push_frame(enc->encoder, fr->frame);
    fr->frame = NULL; // prevent schro_frame_unref
    return ++(enc->frames);
}

int it_starts_encoder_lua(lua_State* L) { // (enc_userdata, output, settings)
    it_encodes* enc = (it_encodes*) lua_touserdata(L, 1);
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

int it_debugs_encoder_lua(lua_State* L) { // (level)
    schro_init();
    schro_debug_set_level(luaL_checkint(L, 1));
    return 0;
}

int it_gets_settings_encoder_lua(lua_State* L) { // (enc_userdata)
    if (lua_gettop(L) == 1 && !lua_isnil(L, 1)) {
        it_encodes* enc = (it_encodes*) lua_touserdata(L, 1);
        luaI_pushencodersettings(L, enc->encoder);
    } else {
        luaI_pushschrosettings(L);
    }
    return 1;
}

int it_gets_format_encoder_lua(lua_State* L) { // (enc_userdata)
    it_encodes* enc = (it_encodes*) lua_touserdata(L, 1);
    if (!enc->encoder) return 0;
    SchroVideoFormat *format = schro_encoder_get_video_format(enc->encoder);
    if (!format) return 0;
    lua_pushlightuserdata(L, format);
    return 1;
}

int it_sets_format_encoder_lua(lua_State* L) { // (enc_userdata, videoformat_userdata)
    it_encodes* enc = (it_encodes*) lua_touserdata(L, 1);
    if (!enc->encoder) return 0;
    SchroVideoFormat *format = lua_touserdata(L, 2);
    schro_encoder_set_video_format(enc->encoder, format);
    free(format);
    return 0;
}
