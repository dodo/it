#ifndef IT_H
#define IT_H

#include <assert.h>

#include <uv.h>
#include <lua.h>

#include "it-types.h"
#include "it-errors.h"


#define IT_NAMES "muSchro0m it"
#define IT_VERSIONS "beta"


extern int it_refs(it_refcounts* ref);
extern int it_unrefs(it_refcounts* ref);


#endif /* IT_H */
