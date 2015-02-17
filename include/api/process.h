#ifndef API_PROCESS_H
#define API_PROCESS_H

#include <lua.h>
#include <sys/time.h>

#include "it.h"
#include "api.h"
#include "luaI.h"


extern void it_exits_process(it_processes* process, int code);

extern double it_gets_time_process();


#endif /* API_PROCESS_H */
