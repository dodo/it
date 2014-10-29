#include <schroedinger/schro.h>
#include <schroedinger/schroframe.h>

#include "it.h"
#include "luaI.h"
#include "orcI.h"

#include "api/frame.h"


void it_inits_frame(it_frames* fr, int width, int height)  {
    fr->width = width;
    fr->height = height;
    fr->size = ROUND_UP_4(width) * ROUND_UP_2(height);
    fr->size += (ROUND_UP_8(width)/2) * (ROUND_UP_2(height)/2);
    fr->size += (ROUND_UP_8(width)/2) * (ROUND_UP_2(height)/2);
}

void it_refs_frame(it_frames* fr, SchroFrame* frame) {
    if (fr->frame == frame) return;
    if (fr->frame) schro_frame_unref(fr->frame);
    fr->frame = frame;
}

void it_creates_frame(it_frames* fr, SchroFrameFormat format) {
    if (fr->frame) schro_frame_unref(fr->frame);
    orcI_init();
    schro_init();
    fr->frame = schro_frame_new_and_alloc(NULL, format, fr->width, fr->height);
}

void it_converts_frame(it_frames* src, it_frames* dst) {
    if (!src || !dst || !src->frame) return;
    if (!dst->frame) it_creates_frame(dst, src->frame->format);
    schro_frame_convert(dst->frame, src->frame);
}

void it_reverses_order_frame(it_frames* fr) {
    if (!fr->frame) return;
    int n = SCHRO_FRAME_IS_PACKED(fr->frame->format) ? 1 : 3;
    int depth = SCHRO_FRAME_FORMAT_DEPTH(fr->frame->format) * 4;
    if (fr->frame->format == SCHRO_FRAME_FORMAT_ARGB) depth = 32;
    // Cairo's image surface buffer is in BGR(a)
    // … so we need to reverse channel order in frame data
    // … because libschrödinger is expecting ARGB order
    int i; for (i = 0; i < n; i++) {
        SchroFrameData* comp = fr->frame->components + i;
        orcI_reverse_order(comp->data, comp->width * comp->height, depth);
    }
}

void it_frees_frame(it_frames* fr) {
    if (!fr->frame) return;
    SchroFrame* frame = fr->frame;
    fr->frame = NULL;
    // might take a while …
    schro_frame_unref(frame);
}
