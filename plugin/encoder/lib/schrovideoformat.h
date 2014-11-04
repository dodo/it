// from schroedinger/schroutils.h

typedef unsigned int schro_bool;

// from schroedinger/schrobitstream.h

typedef enum _SchroVideoFormatEnum {
  SCHRO_VIDEO_FORMAT_CUSTOM = 0,
  SCHRO_VIDEO_FORMAT_QSIF,
  SCHRO_VIDEO_FORMAT_QCIF,
  SCHRO_VIDEO_FORMAT_SIF,
  SCHRO_VIDEO_FORMAT_CIF,
  SCHRO_VIDEO_FORMAT_4SIF,
  SCHRO_VIDEO_FORMAT_4CIF,
  SCHRO_VIDEO_FORMAT_SD480I_60,
  SCHRO_VIDEO_FORMAT_SD576I_50,
  SCHRO_VIDEO_FORMAT_HD720P_60,
  SCHRO_VIDEO_FORMAT_HD720P_50,
  SCHRO_VIDEO_FORMAT_HD1080I_60,
  SCHRO_VIDEO_FORMAT_HD1080I_50,
  SCHRO_VIDEO_FORMAT_HD1080P_60,
  SCHRO_VIDEO_FORMAT_HD1080P_50,
  SCHRO_VIDEO_FORMAT_DC2K_24,
  SCHRO_VIDEO_FORMAT_DC4K_24,
  SCHRO_VIDEO_FORMAT_UHDTV_4K_60,
  SCHRO_VIDEO_FORMAT_UHDTV_4K_50,
  SCHRO_VIDEO_FORMAT_UHDTV_8K_60,
  SCHRO_VIDEO_FORMAT_UHDTV_8K_50
} SchroVideoFormatEnum;

typedef enum _SchroChromaFormat {
  SCHRO_CHROMA_444 = 0,
  SCHRO_CHROMA_422,
  SCHRO_CHROMA_420
} SchroChromaFormat;

typedef enum _SchroColourPrimaries {
  SCHRO_COLOUR_PRIMARY_HDTV = 0,
  SCHRO_COLOUR_PRIMARY_SDTV_525 = 1,
  SCHRO_COLOUR_PRIMARY_SDTV_625 = 2,
  SCHRO_COLOUR_PRIMARY_CINEMA = 3
} SchroColourPrimaries;

typedef enum _SchroColourMatrix {
  SCHRO_COLOUR_MATRIX_HDTV = 0,
  SCHRO_COLOUR_MATRIX_SDTV = 1,
  SCHRO_COLOUR_MATRIX_REVERSIBLE = 2
}SchroColourMatrix;

typedef enum _SchroTransferFunction {
  SCHRO_TRANSFER_CHAR_TV_GAMMA = 0,
  SCHRO_TRANSFER_CHAR_EXTENDED_GAMUT = 1,
  SCHRO_TRANSFER_CHAR_LINEAR = 2,
  SCHRO_TRANSFER_CHAR_DCI_GAMMA = 3
} SchroTransferFunction;

// from schroedinger/schrovideoformat.h

typedef struct _SchroVideoFormat {
  SchroVideoFormatEnum index;
  int width;
  int height;
  SchroChromaFormat chroma_format;

  schro_bool interlaced;
  schro_bool top_field_first;

  int frame_rate_numerator;
  int frame_rate_denominator;
  int aspect_ratio_numerator;
  int aspect_ratio_denominator;

  int clean_width;
  int clean_height;
  int left_offset;
  int top_offset;

  int luma_offset;
  int luma_excursion;
  int chroma_offset;
  int chroma_excursion;

  SchroColourPrimaries colour_primaries;
  SchroColourMatrix colour_matrix;
  SchroTransferFunction transfer_function;

  int interlaced_coding;

  int unused0;
  int unused1;
  int unused2;
} SchroVideoFormat;
