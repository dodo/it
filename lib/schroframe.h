// from schroedinger/schroasync.h

typedef struct _SchroMutex SchroMutex;

// from schroedinger/schrodomain.h

// #define SCHRO_MEMORY_DOMAIN_SLOTS 1000

typedef struct _SchroMemoryDomain {
  SchroMutex * mutex;

  unsigned int flags;

  void *(*alloc) (int size);
  void *(*alloc_2d) (int depth, int width, int height);
  void (*free) (void *ptr, int size);

  struct {
    unsigned int flags;
    void *ptr;
    int size;
    void *priv;
  } slots[1000/*SCHRO_MEMORY_DOMAIN_SLOTS*/];
} SchroMemoryDomain;

// from schroedinger/schroframe.h

// #define SCHRO_FRAME_CACHE_SIZE 32

typedef struct _SchroFrame SchroFrame;
typedef struct _SchroFrameData SchroFrameData;

typedef void (*SchroFrameFreeFunc)(SchroFrame *frame, void *priv);
typedef void (*SchroFrameRenderFunc)(SchroFrame *frame, void *dest, int component, int i);

/* bit pattern:
 *  0x100 - 0: normal, 1: indirect (packed)
 *  0x001 - horizontal chroma subsampling: 0: 1, 1: 2
 *  0x002 - vertical chroma subsampling: 0: 1, 1: 2
 *  0x00c - depth: 0: u8, 1: s16, 2: s32
 *  */
typedef enum _SchroFrameFormat {
  SCHRO_FRAME_FORMAT_U8_444 = 0x00,
  SCHRO_FRAME_FORMAT_U8_422 = 0x01,
  SCHRO_FRAME_FORMAT_U8_420 = 0x03,

  SCHRO_FRAME_FORMAT_S16_444 = 0x04,
  SCHRO_FRAME_FORMAT_S16_422 = 0x05,
  SCHRO_FRAME_FORMAT_S16_420 = 0x07,

  SCHRO_FRAME_FORMAT_S32_444 = 0x08,
  SCHRO_FRAME_FORMAT_S32_422 = 0x09,
  SCHRO_FRAME_FORMAT_S32_420 = 0x0b,

  /* indirectly supported */
  SCHRO_FRAME_FORMAT_YUYV = 0x100, /* YUYV order */
  SCHRO_FRAME_FORMAT_UYVY = 0x101, /* UYVY order */
  SCHRO_FRAME_FORMAT_AYUV = 0x102,
  SCHRO_FRAME_FORMAT_ARGB = 0x103,
  SCHRO_FRAME_FORMAT_RGB = 0x104,
  SCHRO_FRAME_FORMAT_v216 = 0x105,
  SCHRO_FRAME_FORMAT_v210 = 0x106,
  SCHRO_FRAME_FORMAT_AY64 = 0x107
} SchroFrameFormat;

struct _SchroFrameData {
  SchroFrameFormat format;
  void *data;
  int stride;
  int width;
  int height;
  int length;
  int h_shift;
  int v_shift;
};

struct _SchroFrame {
  int refcount;
  SchroFrameFreeFunc free;
  SchroMemoryDomain *domain;
  void *regions[3];
  void *priv;

  SchroFrameFormat format;
  int width;
  int height;

  SchroFrameData components[3];

  int is_virtual;
  int cached_lines[3][32/*SCHRO_FRAME_CACHE_SIZE*/];
  SchroFrame *virt_frame1;
  SchroFrame *virt_frame2;
  void (*render_line) (SchroFrame *frame, void *dest, int component, int i);
  void *virt_priv;
  void *virt_priv2;

  int extension;
  int cache_offset[3];
  int is_upsampled;
};
