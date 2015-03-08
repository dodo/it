
IT_SRC_BIN =  it.c src/uvI.c
IT_SRC_API = src/api.c \
	src/errors.c \
	src/uvI.c \
	src/luaI.c \
	src/api/it.c \
	src/api/async.c \
	src/api/scope.c \
	src/api/thread.c \
	src/api/process.c \
	src/api/window.c

LUAJIT_INC = $(shell pkg-config --cflags luajit)
# LUAJIT_INC = -Ivendor/luajit-2.0/src

IT_DEPENDS = $(LUAJIT_INC) \
	$(shell pkg-config --cflags libuv) \
	$(shell pkg-config --cflags atomic_ops) \
	$(shell pkg-config --cflags sdl2)

IT_LINKS = \
	$(shell pkg-config --libs libuv) \
	$(shell pkg-config --libs luajit) \
	$(shell pkg-config --libs atomic_ops) \
	$(shell pkg-config --libs sdl2)

IT_LAZY_LIBS = \
	$(shell pkg-config --cflags cairo) \
	$(shell pkg-config --cflags pixman-1)

IT_INCLUDES = -I./include
IT_WARNS = -Wall

CC = gcc

# DEBUG = ""
# DEBUG = -g -O0
DEBUG = -O2

IT_RPATHS = /tmp/it-rpath

_rpath = -Wl,-z,origin -Wl,-rpath

cleanall: clean all

all: api plugins it

standalone: api it

plugins: audio encoder

api: libapi.so
	echo -n "return nil" > lib/plugins.lua
	echo -n '$$ORIGIN' >  $(IT_RPATHS)
# 	echo -n '$$ORIGIN:$$ORIGIN/vendor/luajit-2.0/src' >  $(IT_RPATHS)
	echo -n '$(IT_INCLUDES) $(IT_DEPENDS) $(IT_LAZY_LIBS)' > ccflags
	cat lib/cdefs.c > combined-cdefs.c

audio: api lib/plugins.lua
	make -C plugin/audio CC=$(CC) DEBUG=$(DEBUG) \
		&& echo -n ",'audio'" >> lib/plugins.lua \
		&& echo -n ':$$ORIGIN/plugin/audio' >> $(IT_RPATHS) \
		&& cat plugin/audio/lib/cdefs.c >> combined-cdefs.c \
		&& cat plugin/audio/ccflags >> ccflags

encoder: api lib/plugins.lua
	make -C plugin/encoder CC=$(CC) DEBUG=$(DEBUG) \
		&& echo -n ",'encoder'" >> lib/plugins.lua \
		&& echo -n ':$$ORIGIN/plugin/encoder' >> $(IT_RPATHS) \
		&& cat plugin/encoder/lib/cdefs.c >> combined-cdefs.c \
		&& cat plugin/encoder/ccflags >> ccflags

cdefdb.so: $(IT_SRC_API) combined-cdefs.c
	./vendor/cdefdb/gen-cdefdb combined-cdefs.c $(shell cat ccflags)

libapi.so:  $(IT_SRC_API)
	$(CC) $(DEBUG) $(IT_WARNS) -shared -o $@ -fPIC $(IT_SRC_API) \
		$(IT_INCLUDES) $(IT_DEPENDS) $(IT_LINKS) \
		$(_rpath),'$(shell cat $(IT_RPATHS))'

it: api cdefdb.so $(IT_SRC_BIN)
	$(CC) $(DEBUG) $(IT_WARNS) -o $@ $(IT_SRC_BIN) $(IT_INCLUDES) \
		-L. -lapi \
		$(shell pkg-config --cflags --libs libuv) \
		$(shell pkg-config --libs luajit) $(LUAJIT_INC) \
		$(_rpath),'$(shell cat $(IT_RPATHS))'
# 		$(shell pkg-config --cflags --libs luajit)


clean:
	rm -f .rpath combined-cdefs.c cdefdb.c cdefdb.so libapi.so ccflags lib/plugins.lua it
	make -C plugin/encoder clean
	make -C plugin/audio clean

.PHONY: all
