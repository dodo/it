

IT_DEPENDS = \
	$(shell pkg-config --cflags --libs libuv) \
	$(shell pkg-config --cflags --libs luajit) \
	$(shell pkg-config --cflags --libs orc-0.4) \
	$(shell PKG_CONFIG_PATH="`pwd`/vendor/schroedinger" pkg-config --cflags --libs --static schroedinger) \
	$(shell pkg-config --cflags --libs oggz) \
	$(shell pkg-config --cflags --libs sdl2)

IT_FLAGS = \
	-D SCHRO_ENABLE_UNSTABLE_API \
	-D PKG_ORC_VERSION='"$(shell pkg-config --modversion orc-0.4)"' \
	-D PKG_OGGZ_VERSION='"$(shell pkg-config --modversion oggz)"'

IT_INCLUDES = -I./include
IT_WARNS = -Wall

# DEBUG = ""
# DEBUG = -g -O0
DEBUG = -O2


all: include/orc0.h src/orc0.c lib/api.so it

include/orc0.h: src/it.orc
	orcc -o $@ $^ --inline --header

src/orc0.c: src/it.orc
	orcc -o $@ $^ --inline --implementation

lib/api.so: src/api.c \
	src/errors.c \
	src/luaI.c \
	src/orc0.c \
	src/orcI.c \
	src/api/it.c \
	src/api/scope.c \
	src/api/thread.c \
	src/api/encoder.c \
	src/api/encoder_settings.c \
	src/api/process.c \
	src/api/frame.c \
	src/api/window.c \
	vendor/schroedinger/schroedinger/.libs/libschroedinger-1.0.a
	gcc $(IT_WARNS) -shared -o $@ -fPIC $^ \
		$(IT_INCLUDES) $(DEBUG) $(IT_DEPENDS) $(IT_FLAGS)

it: it.c src/uvI.c
	gcc $(IT_WARNS) -o $@ $^ $(IT_INCLUDES) $(DEBUG) \
		$(shell pkg-config --cflags --libs libuv) \
		$(shell pkg-config --cflags --libs luajit)

clean:
	rm -f include/orc0.h src/orc0.c lib/api.so it

.PHONY: all