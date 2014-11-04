
IT_SRC_BIN =  it.c src/uvI.c
IT_SRC_API = src/api.c \
	src/errors.c \
	src/uvI.c \
	src/luaI.c \
	src/api/it.c \
	src/api/scope.c \
	src/api/thread.c \
	src/api/process.c \
	src/api/window.c


IT_DEPENDS = \
	$(shell pkg-config --cflags --libs libuv) \
	$(shell pkg-config --cflags --libs luajit) \
	$(shell pkg-config --cflags --libs sdl2)


IT_INCLUDES = -I./include
IT_WARNS = -Wall

# DEBUG = ""
# DEBUG = -g -O0
DEBUG = -O2

IT_RPATHS = /tmp/it-rpath


cleanall: clean all

all: api plugins it

standalone: api it

api: libapi.so
	echo -n "return nil" > lib/plugins.lua
	echo -n '$$ORIGIN' >  $(IT_RPATHS)

plugins: api lib/plugins.lua
	make -C plugin/encoder \
		&& echo -n ",'encoder'" >> lib/plugins.lua \
		&& echo -n ':$$ORIGIN/plugin/encoder' >> $(IT_RPATHS)


libapi.so:  $(IT_SRC_API)
	gcc $(IT_WARNS) -shared -o $@ -fPIC $(IT_SRC_API) \
		$(IT_INCLUDES) $(DEBUG) $(IT_DEPENDS) \

it: api $(IT_SRC_BIN)
	gcc $(IT_WARNS) -o $@ $(IT_SRC_BIN) $(IT_INCLUDES) $(DEBUG) \
		-L. -lapi \
		$(shell pkg-config --cflags --libs libuv) \
		$(shell pkg-config --cflags --libs luajit) \
		-Wl,-z,origin -Wl,-rpath,'$(shell cat $(IT_RPATHS))'


clean:
	rm -f .rpath libapi.so lib/plugins.lua it
	make -C plugin/encoder clean

.PHONY: all