#include "orcI.h"

void orcI_init() {
    static int inited = FALSE;
    if (inited) return;
    inited = TRUE;

    orc0_init();
}

void orcI_reverse_order(void* data, int length, int depth) {
    switch (depth) {
        case 16: orc0_reverse_order_u16(data, data, length); break;
        case 32: orc0_reverse_order_u32(data, data, length); break;
        default: break;
    }
}
