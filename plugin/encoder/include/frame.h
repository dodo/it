#ifndef API_FRAME_H
#define API_FRAME_H

#include <lua.h>

#include <schroedinger/schroframe.h>

#include "it.h"
#include "luaI.h"
#include "encoder-types.h"


extern void it_inits_frame(it_frames* fr, int width, int height);
extern void it_refs_frame(it_frames* fr, SchroFrame* frame);
extern void it_creates_frame(it_frames* fr, SchroFrameFormat format);
extern void it_converts_frame(it_frames* src, it_frames* dst);
extern void it_reverses_order_frame(it_frames* fr);
extern void it_frees_frame(it_frames* fr);


#endif /* API_FRAME_H */
