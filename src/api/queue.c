 #include "it.h"
#include "luaI.h"

#include "api/queue.h"


it_queues* it_allocs_queue() {
    it_queues* queue = (it_queues*) calloc(1, sizeof(it_queues));
    if (!queue) return NULL;
    return queue;
}

// thread safe (hopefully *g*)
void it_pushes_queue(it_queues* queue, luaI_value* value) {
    if (!queue) return;
    int pos = queue->count;
    if (++(queue->count) >= queue->size) {
        queue->size = queue->size == 0 ? 1 : 2 * queue->size;
        queue->values = realloc(queue->values, sizeof(luaI_value*) * queue->size);
    }
    queue->values[pos] = value;
}

void it_pushes_cdata_queue(it_queues* queue, void* cdata) {
    if (!queue) return;
    luaI_value* value = (luaI_value*) malloc(sizeof(luaI_value));
    if (!value) return;
    value->type = LUAI_TYPE_CDATA;
    value->v.cdata = cdata;
    it_pushes_queue(queue, value);
}

int luaI_pushqueuevalues(lua_State* L, it_queues* queue) {
    if (!queue) return 0;
    int nargs = queue->count;
    int i; for (i = 0; i < queue->count; i++) {
        luaI_value* value = queue->values[i];
        luaI_pushvalue(L, value);
    }
    return nargs;
}

void it_resets_queue(it_queues* queue) {
    if (!queue) return;
    queue->count = 0;
}

void it_clears_queue(it_queues* queue) {
    if (!queue) return;
    queue->size = queue->count = 0;
    if (queue->values) {
        free(queue->values);
        queue->values = NULL;
    }
}

void it_frees_queue(it_queues* queue) {
    if (!queue) return;
    it_queues* next = queue->next;
    queue->next = NULL;
    it_clears_queue(queue);
    free(queue);
    // cascade free if possible
    it_frees_queue(next);
}
