
IT_DIR = ../..

IT_SRC_API = src/api.c \
	src/orc0.c \
	src/orcI.c \
	src/encoder.c \
	src/encoder_settings.c \
	src/frame.c

# FIXME
IT_DEPENDS = \
	$(shell pkg-config --cflags luajit) \
	$(shell pkg-config --cflags orc-0.4) \
	$(shell PKG_CONFIG_PATH="`pwd`/$(IT_DIR)/vendor/schroedinger" pkg-config --cflags --static schroedinger) \
	$(shell pkg-config --cflags oggz)

# FIXME
IT_LINKS = \
	-L$(IT_DIR) -lapi \
	$(shell pkg-config --libs luajit) \
	$(shell pkg-config --libs orc-0.4) \
	$(shell PKG_CONFIG_PATH="`pwd`/$(IT_DIR)/vendor/schroedinger" pkg-config --libs --static schroedinger) \
	$(shell pkg-config --libs oggz)

IT_FLAGS = \
	-D SCHRO_ENABLE_UNSTABLE_API \
	-D PKG_ORC_VERSION='"$(shell pkg-config --modversion orc-0.4)"' \
	-D PKG_OGGZ_VERSION='"$(shell pkg-config --modversion oggz)"'

IT_INCLUDES = -I./include -I$(IT_DIR)/include
IT_WARNS = -Wall

CC = gcc

# DEBUG = ""
# DEBUG = -g -O0
DEBUG = -O2


all: include/orc0.h src/orc0.c libencoder.so ccflags

include/orc0.h: src/it.orc
	orcc -o $@ $^ --inline --header

src/orc0.c: src/it.orc
	orcc -o $@ $^ --inline --implementation

ccflags:
	echo -n ' -I./plugin/encoder/include $(IT_DEPENDS) $(IT_FLAGS)' > ccflags

libencoder.so: $(IT_SRC_API) \
	$(IT_DIR)/vendor/schroedinger/schroedinger/.libs/libschroedinger-1.0.a
	$(CC) $(IT_WARNS) -shared -o $@ -fPIC $^ \
		$(IT_INCLUDES) $(DEBUG) $(IT_DEPENDS) $(IT_LINKS) $(IT_FLAGS)

clean:
	rm -f include/orc0.h src/orc0.c ccflags libencoder.so

.PHONY: all
