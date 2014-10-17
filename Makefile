
it: it.c \
	src/luaI.c \
	src/lua/it.c \
	src/lua/ctx.c \
	src/lua/enc.c \
	src/lua/enc_settings.c \
	src/lua/process.c \
	src/lua/buffer.c \
	src/lua/frame.c \
	vendor/schroedinger/schroedinger/.libs/libschroedinger-1.0.a
	gcc -Wall -o $@ $^ -I./include \
		$(shell pkg-config --cflags --libs libuv) \
		$(shell pkg-config --cflags --libs luajit) \
		$(shell PKG_CONFIG_PATH="`pwd`/vendor/schroedinger" pkg-config --cflags --libs --static schroedinger) \
		$(shell pkg-config --cflags --libs oggz)
