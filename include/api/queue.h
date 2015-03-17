#ifndef API_QUEUE_H
#define API_QUEUE_H

#include <lua.h>
#include <uv.h>


#include "it.h"
#include "api.h"
#include "luaI.h"

#include "api/queue.h"


extern it_queues* it_allocs_queue();

extern void it_pushes_queue(it_queues* queue, luaI_value* value);
extern void it_pushes_cdata_queue(it_queues* queue, void* cdata);

extern void it_resets_queue(it_queues* queue);
extern void it_frees_queue(it_queues* queue);

extern int luaI_pushqueuevalues(lua_State* L, it_queues* queue);


#endif /* API_QUEUE_H */

