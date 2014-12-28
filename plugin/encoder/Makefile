
IT_DIR = ../..

# FIXME
IT_DEPENDS = \
	-L$(IT_DIR) -lapi \
	$(shell pkg-config --cflags --libs luajit) \
	$(shell pkg-config --cflags --libs orc-0.4) \
	$(shell PKG_CONFIG_PATH="`pwd`/$(IT_DIR)/vendor/schroedinger" pkg-config --cflags --libs --static schroedinger) \
	$(shell pkg-config --cflags --libs oggz)

IT_FLAGS = \
	-D SCHRO_ENABLE_UNSTABLE_API \
	-D PKG_ORC_VERSION='"$(shell pkg-config --modversion orc-0.4)"' \
	-D PKG_OGGZ_VERSION='"$(shell pkg-config --modversion oggz)"'

IT_INCLUDES = -I./include -I$(IT_DIR)/include
IT_WARNS = -Wall

# DEBUG = ""
# DEBUG = -g -O0
DEBUG = -O2


all: include/orc0.h src/orc0.c libencoder.so

include/orc0.h: src/it.orc
	orcc -o $@ $^ --inline --header

src/orc0.c: src/it.orc
	orcc -o $@ $^ --inline --implementation

libencoder.so: src/api.c \
	src/orc0.c \
	src/orcI.c \
	src/encoder.c \
	src/encoder_settings.c \
	src/frame.c \
	$(IT_DIR)/vendor/schroedinger/schroedinger/.libs/libschroedinger-1.0.a
	gcc $(IT_WARNS) -shared -o $@ -fPIC $^ \
		$(IT_INCLUDES) $(DEBUG) $(IT_DEPENDS) $(IT_FLAGS)

clean:
	rm -f include/orc0.h src/orc0.c libencoder.so

.PHONY: all
