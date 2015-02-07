#ifndef API_ENCODER_H
#define API_ENCODER_H

#include <lua.h>

#include <uv.h>

#include <oggz/oggz.h>

#include <schroedinger/schro.h>
#include <schroedinger/schroencoder.h>
#include <schroedinger/schrodebug.h>
#include <schroedinger/schroutils.h>
#include <schroedinger/schrobuffer.h>

#include "it.h"
#include "luaI.h"
#include "encoder-types.h"

#include "encoder.h"
#include "encoder_settings.h"
#include "api/thread.h"
#include "api/scope.h"
#include "frame.h"


extern void schroI_encoder_wait(void* priv);
extern void schroI_encoder_start(void* priv);
extern void schroI_encoder_free(void* priv);

extern void it_inits_encoder(it_encodes* enc, it_threads* thread, SchroVideoFormatEnum format);

extern int it_pushes_frame_encoder(it_encodes* enc, it_frames* fr);
extern void it_hooks_stage_encoder(it_encodes* enc,
                                   SchroEncoderFrameStateEnum stage,
                                   it_states* ctx);

extern int it_starts_encoder_lua(lua_State* L);
extern int it_debugs_encoder_lua(lua_State* L);
extern int it_gets_settings_encoder_lua(lua_State* L);
extern int it_gets_format_encoder_lua(lua_State* L);
extern int it_sets_format_encoder_lua(lua_State* L);


#endif /* API_ENCODER_H */
