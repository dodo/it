

all: include/orc0.h src/orc0.c it

include/orc0.h: src/it.orc
	orcc -o $@ $^ --inline --header

src/orc0.c: src/it.orc
	orcc -o $@ $^ --inline --implementation

it: it.c \
	src/luaI.c \
	src/orc0.c \
	src/orcI.c \
	src/lua/it.c \
	src/lua/ctx.c \
	src/lua/enc.c \
	src/lua/enc_settings.c \
	src/lua/process.c \
	src/lua/buffer.c \
	src/lua/frame.c \
	src/lua/window.c \
	vendor/schroedinger/schroedinger/.libs/libschroedinger-1.0.a
	gcc -Wall -o $@ $^ -I./include \
		$(shell pkg-config --cflags --libs libuv) \
		$(shell pkg-config --cflags --libs luajit) \
		$(shell pkg-config --cflags --libs orc-0.4) \
		$(shell PKG_CONFIG_PATH="`pwd`/vendor/schroedinger" pkg-config --cflags --libs --static schroedinger) \
		$(shell pkg-config --cflags --libs oggz) \
		$(shell pkg-config --cflags --libs sdl2) \
		-D PKG_ORC_VERSION='"$(shell pkg-config --modversion orc-0.4)"' \
		-D PKG_OGGZ_VERSION='"$(shell pkg-config --modversion oggz)"'



.PHONY: all