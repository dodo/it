// from schroedinger/schrobitstream.h

#define SCHRO_N_WAVELETS 7

// from schroedinger/schrolimits.h

/**
 * SCHRO_LIMIT_TRANSFORM_DEPTH:
 *
 * The maximum transform depth that the decoder can handle.
 */
#define SCHRO_LIMIT_TRANSFORM_DEPTH 6

/**
 * SCHRO_LIMIT_SUBBANDS:
 *
 * The maximum number of subbands.
 */
#define SCHRO_LIMIT_SUBBANDS (1+3*SCHRO_LIMIT_TRANSFORM_DEPTH)

/**
 * SCHRO_LIMIT_REFERENCE_FRAMES:
 *
 * The maximum number of active reference frames.  In the encoder,
 * the number of active reference frames may be much larger than in
 * the resulting stream.
 */
#define SCHRO_LIMIT_REFERENCE_FRAMES 8

/**
 * SCHRO_LIMIT_BLOCK_SIZE
 *
 * Maximum block size.  Both length and separation must be less than
 * or equal to this limit.
 */
#define SCHRO_LIMIT_BLOCK_SIZE 64

// from schroedinger/schroutil.h

typedef uint32_t SchroPictureNumber;
typedef unsigned int schro_bool;

// from schroedinger/schrobuffer.h

typedef struct _SchroBuffer SchroBuffer;
typedef struct _SchroTag SchroTag;

struct _SchroBuffer
{
  /*< private >*/
  unsigned char *data;
  unsigned int length;

  int ref_count;

  SchroBuffer *parent;

  void (*free) (SchroBuffer *, void *);
  void *priv;

  SchroTag* tag;
};

struct _SchroTag
{
  void (*free) (void *);
  void *value;
};

// from schroedinger/schrolist.h

typedef struct _SchroList SchroList;

typedef void (*SchroListFreeFunc)(void *member, void *priv);

struct _SchroList {
  void **members;
  int n;
  int n_alloc;

  SchroListFreeFunc free;
  void *priv;
};

// from schroedinger/schroqueue.h

typedef struct _SchroQueue SchroQueue;
typedef struct _SchroQueueElement SchroQueueElement;

typedef void (*SchroQueueFreeFunc)(void *data, SchroPictureNumber number);

struct _SchroQueueElement {
  void *data;
  SchroPictureNumber picture_number;
};

struct _SchroQueue {
  int size;
  int n;

  SchroQueueElement *elements;
  SchroQueueFreeFunc free;
};

// from schroedinger/schropack.h

typedef struct _SchroPack SchroPack;

struct _SchroPack {
  SchroBuffer *buffer;

  int n;
  int shift;
  int n_pack;

  uint32_t value;

  int error;
};

// from schroedinger/schroasync.h

typedef int SchroExecDomain;

typedef struct _SchroAsync SchroAsync;
typedef struct _SchroAsyncStage SchroAsyncStage;

typedef int (*SchroAsyncScheduleFunc)(void *, SchroExecDomain exec_domain);
typedef void (*SchroAsyncCompleteFunc)(void *);
typedef void (*SchroAsyncTaskFunc) (void *);

struct _SchroAsyncStage {
  SchroAsyncTaskFunc task_func;
  void *priv;

  schro_bool is_ready;
  schro_bool is_needed; /* FIXME remove eventually */
  schro_bool is_done;
  int priority;
  int n_tasks_started;
  int n_tasks_completed;

  int n_tasks;
  SchroAsyncTaskFunc tasks[10];
};

// from schroedinger/schroparams.h

typedef struct _SchroParams SchroParams;
typedef struct _SchroGlobalMotion SchroGlobalMotion;

struct _SchroGlobalMotion {
  int b0;
  int b1;
  int a_exp;
  int a00;
  int a01;
  int a10;
  int a11;
  int c_exp;
  int c0;
  int c1;
};

struct _SchroParams {
  /*< private >*/
  SchroVideoFormat *video_format;
  int is_noarith;

  /* transform parameters */
  int wavelet_filter_index;
  int transform_depth;
  int horiz_codeblocks[SCHRO_LIMIT_TRANSFORM_DEPTH + 1];
  int vert_codeblocks[SCHRO_LIMIT_TRANSFORM_DEPTH + 1];
  int codeblock_mode_index;

  /* motion prediction parameters */
  int num_refs;
  int have_global_motion; /* using_global_motion */
  int xblen_luma;
  int yblen_luma;
  int xbsep_luma;
  int ybsep_luma;
  int mv_precision;
  SchroGlobalMotion global_motion[2];
  int picture_pred_mode;
  int picture_weight_bits;
  int picture_weight_1;
  int picture_weight_2;

  /* DiracPro parameters */
  int is_lowdelay;
  int n_horiz_slices; /* slices_x */
  int n_vert_slices; /* slices_y */
  int slice_bytes_num;
  int slice_bytes_denom;
  int quant_matrix[3*SCHRO_LIMIT_TRANSFORM_DEPTH+1];

  /* calculated sizes */
  int iwt_chroma_width;
  int iwt_chroma_height;
  int iwt_luma_width;
  int iwt_luma_height;
  int x_num_blocks;
  int y_num_blocks;
  int x_offset;
  int y_offset;
};

// from schroedinger/schromotion.h

typedef struct _SchroMotionVector SchroMotionVector;
typedef struct _SchroMotionField SchroMotionField;
typedef struct _SchroMotion SchroMotion;

struct _SchroMotionVector {
  unsigned int pred_mode : 2;
  unsigned int using_global : 1;
  unsigned int split : 2;
  unsigned int unused : 3;
  unsigned int scan : 8;
  uint32_t metric;
  uint32_t chroma_metric;
  union {
    struct {
      int16_t dx[2];
      int16_t dy[2];
    } vec;
    struct {
      int16_t dc[3];
    } dc;
  } u;
};

struct _SchroMotionField {
  int x_num_blocks;
  int y_num_blocks;
  SchroMotionVector *motion_vectors;
};

struct _SchroMotion {
  SchroFrame *src1;
  SchroFrame *src2;
  SchroMotionVector *motion_vectors;
  SchroParams *params;

  int ref_weight_precision;
  int ref1_weight;
  int ref2_weight;
  int mv_precision;
  int xoffset;
  int yoffset;
  int xbsep;
  int ybsep;
  int xblen;
  int yblen;

  SchroFrameData block;
  SchroFrameData alloc_block;
  SchroFrameData obmc_weight;

  SchroFrameData alloc_block_ref[2];
  SchroFrameData block_ref[2];

  int weight_x[SCHRO_LIMIT_BLOCK_SIZE];
  int weight_y[SCHRO_LIMIT_BLOCK_SIZE];
  int width;
  int height;
  int max_fast_x;
  int max_fast_y;

  schro_bool simple_weight;
  schro_bool oneref_noscale;
};

// from schroedinger/schrohistogram.h

#define SCHRO_HISTOGRAM_SHIFT 3
#define SCHRO_HISTOGRAM_SIZE ((16-SCHRO_HISTOGRAM_SHIFT)*(1<<SCHRO_HISTOGRAM_SHIFT))

typedef struct _SchroHistogram SchroHistogram;
typedef struct _SchroHistogramTable SchroHistogramTable;

struct _SchroHistogram {
  /*< private >*/
  int n;
  double bins[SCHRO_HISTOGRAM_SIZE];
};

struct _SchroHistogramTable {
  /*< private >*/
  double weights[SCHRO_HISTOGRAM_SIZE];
};

// from schroedinger/schroencoder.h

typedef struct _SchroEncoder SchroEncoder;
typedef struct _SchroEncoderFrame SchroEncoderFrame;
typedef struct _SchroEncoderSetting SchroEncoderSetting;

typedef enum {
  SCHRO_STATE_NEED_FRAME,
  SCHRO_STATE_HAVE_BUFFER,
  SCHRO_STATE_AGAIN,
  SCHRO_STATE_END_OF_STREAM
} SchroStateEnum;

typedef enum {
  SCHRO_ENCODER_FRAME_STAGE_NEW = 0,
  SCHRO_ENCODER_FRAME_STAGE_ANALYSE,
  SCHRO_ENCODER_FRAME_STAGE_SC_DETECT_1,
  SCHRO_ENCODER_FRAME_STAGE_SC_DETECT_2,
  SCHRO_ENCODER_FRAME_STAGE_HAVE_GOP,
  SCHRO_ENCODER_FRAME_STAGE_HAVE_PARAMS,
  SCHRO_ENCODER_FRAME_STAGE_PREDICT_ROUGH,
  SCHRO_ENCODER_FRAME_STAGE_PREDICT_PEL,
  SCHRO_ENCODER_FRAME_STAGE_PREDICT_SUBPEL,
  SCHRO_ENCODER_FRAME_STAGE_MODE_DECISION,
  SCHRO_ENCODER_FRAME_STAGE_HAVE_REFS,
  SCHRO_ENCODER_FRAME_STAGE_HAVE_QUANTS,
  SCHRO_ENCODER_FRAME_STAGE_ENCODING,
  SCHRO_ENCODER_FRAME_STAGE_RECONSTRUCT,
  SCHRO_ENCODER_FRAME_STAGE_POSTANALYSE,
  SCHRO_ENCODER_FRAME_STAGE_DONE,
  SCHRO_ENCODER_FRAME_STAGE_FREE,
  SCHRO_ENCODER_FRAME_STAGE_LAST /* this should be last */
} SchroEncoderFrameStateEnum;

typedef enum {
  SCHRO_ENCODER_PROFILE_AUTO,
  SCHRO_ENCODER_PROFILE_VC2_LOW_DELAY,
  SCHRO_ENCODER_PROFILE_VC2_SIMPLE,
  SCHRO_ENCODER_PROFILE_VC2_MAIN,
  SCHRO_ENCODER_PROFILE_MAIN
} SchroEncoderProfile;

typedef int (*SchroEngineIterateFunc) (SchroEncoder *encoder);

/* forward declaration */
struct _SchroMotionEst;
struct _SchroRoughME;

struct _SchroEncoderFrame {
  /*< private >*/
  int refcount;
  //SchroEncoderFrameStateEnum state;
  //SchroEncoderFrameStateEnum needed_state;
  SchroEncoderFrameStateEnum working;
  int busy;

  void *priv;

  unsigned int expired_reference;

  /* Bits telling the engine stages which stuff needs to happen */
  unsigned int need_extension;
  unsigned int need_downsampling;
  unsigned int need_upsampling;
  unsigned int need_filtering;
  unsigned int need_average_luma;
  unsigned int need_mad;

  /* bits indicating that a particular analysis has happened.  Mainly
   * for verification */
  unsigned int have_estimate_tables;
  unsigned int have_histograms;
  unsigned int have_scene_change_score;
  unsigned int have_downsampling;
  unsigned int have_upsampling;
  unsigned int have_average_luma;
  unsigned int have_mad;

  SchroAsyncStage stages[SCHRO_ENCODER_FRAME_STAGE_LAST];

  /* other stuff */

  int start_sequence_header;
  int gop_length;

  SchroPictureNumber frame_number;
  SchroFrame *original_frame;
  SchroFrame *filtered_frame;
  SchroFrame *downsampled_frames[8];
  SchroFrame *reconstructed_frame;
  SchroFrame *upsampled_original_frame;

  int sc_mad; /* shot change mean absolute difference */
  double sc_threshold; /* shot change threshold */

  SchroBuffer *sequence_header_buffer;
  SchroList *inserted_buffers;
  int output_buffer_size;
  SchroBuffer *output_buffer;
  int presentation_frame;
  int slot;
  int last_frame;

  int is_ref;
  int num_refs;
  SchroPictureNumber picture_number_ref[2];
  SchroPictureNumber retired_picture_number;

  int16_t slice_y_dc_values[100];
  int16_t slice_u_dc_values[100];
  int16_t slice_v_dc_values[100];
  int slice_y_n;
  int slice_uv_n;
  int slice_y_bits;
  int slice_uv_bits;
  int slice_y_trailing_zeros;
  int slice_uv_trailing_zeros;
  SchroFrameData luma_subbands[SCHRO_LIMIT_SUBBANDS];
  SchroFrameData chroma1_subbands[SCHRO_LIMIT_SUBBANDS];
  SchroFrameData chroma2_subbands[SCHRO_LIMIT_SUBBANDS];

  /* from the old SchroEncoderTask */

  int stats_dc;
  int stats_global;
  int stats_motion;

  int subband_size;
  SchroBuffer *subband_buffer;

  int16_t *quant_data;

  int *quant_indices[3][SCHRO_LIMIT_SUBBANDS];

  double est_entropy[3][SCHRO_LIMIT_SUBBANDS][60];
  double actual_subband_bits[3][SCHRO_LIMIT_SUBBANDS];
  double est_error[3][SCHRO_LIMIT_SUBBANDS][60];
  SchroPack *pack;
  SchroParams params;
  SchroEncoder *encoder;
  SchroFrame *iwt_frame;
  SchroFrame *quant_frame;
  SchroFrame *prediction_frame;

  SchroEncoderFrame *previous_frame;
  SchroEncoderFrame *ref_frame[2];

  struct _SchroMotionEst *me;
  struct _SchroRoughME *rme[2];
  struct _SchroPhaseCorr *phasecorr[2];
  struct _SchroHierBm *hier_bm[2];
  struct _SchroMe *deep_me;

  SchroMotion *motion;

  SchroHistogram subband_hists[3][SCHRO_LIMIT_SUBBANDS];
  SchroHistogram hist_test;

  /* statistics */

  double picture_weight;
  double scene_change_score;
  double average_luma;

  int hard_limit_bits;
  int allocated_residual_bits;
  int allocated_mc_bits;
  double frame_lambda;
  double frame_me_lambda;
  int estimated_residual_bits;
  int estimated_mc_bits;

  int actual_residual_bits;
  int actual_mc_bits;
  double mc_error;
  double mean_squared_error_luma;
  double mean_squared_error_chroma;
  double mssim;

  double estimated_arith_context_ratio;

  double badblock_ratio;
  double dcblock_ratio;
  double hist_slope;
};

struct _SchroEncoder {
  /*< private >*/
  SchroAsync *async;
  void *userdata;

  SchroPictureNumber next_frame_number;

  SchroQueue *frame_queue;

  SchroEncoderFrame *reference_pictures[SCHRO_LIMIT_REFERENCE_FRAMES];
  SchroEncoderFrame *last_frame;

  int assemble_packets;
  int need_rap;

  SchroVideoFormat video_format;
  int version_major;
  int version_minor;

  int bit_depth;
  int input_frame_depth;
  int intermediate_frame_depth;

  /* configuration */
  int rate_control;
  int bitrate;
  int max_bitrate;
  int min_bitrate;

  // Buffer model parameters for CBR and (TODO) constrained VBR coding
  int buffer_size;
  int buffer_level;
  double quality;
  double noise_threshold;
  int gop_structure;
  int queue_depth;
  int perceptual_weighting;
  double perceptual_distance;
  int filtering;
  double filter_value;
  SchroEncoderProfile force_profile;
  int profile;
  int level;
  int open_gop;
  int au_distance;
  int max_refs;
  schro_bool enable_psnr;
  schro_bool enable_ssim;
  schro_bool enable_md5;

  int transform_depth;
  int intra_wavelet;
  int inter_wavelet;
  int mv_precision;
  int motion_block_size;
  int motion_block_overlap;
  schro_bool interlaced_coding;
  schro_bool enable_internal_testing;
  schro_bool enable_noarith;
  schro_bool enable_fullscan_estimation;
  schro_bool enable_hierarchical_estimation;
  schro_bool enable_zero_estimation;
  schro_bool enable_phasecorr_estimation;
  schro_bool enable_bigblock_estimation;
  schro_bool enable_multiquant;
  schro_bool enable_dc_multiquant;
  schro_bool enable_global_motion;
  schro_bool enable_scene_change_detection;
  schro_bool enable_deep_estimation;
  schro_bool enable_rdo_cbr;
  schro_bool enable_chroma_me;
  int horiz_slices;
  int vert_slices;
  int codeblock_size;

  double magic_dc_metric_offset;
  double magic_subband0_lambda_scale;
  double magic_chroma_lambda_scale;
  double magic_nonref_lambda_scale;
  double magic_I_lambda_scale;
  double magic_P_lambda_scale;
  double magic_B_lambda_scale;
  double magic_me_lambda_scale;
  double magic_allocation_scale;
  double magic_inter_cpd_scale;
  double magic_keyframe_weight;
  double magic_scene_change_threshold;
  double magic_inter_p_weight;
  double magic_inter_b_weight;
  double magic_me_bailout_limit;
  double magic_bailout_weight;
  double magic_error_power;
  double magic_subgroup_length;
  double magic_badblock_multiplier_nonref;
  double magic_badblock_multiplier_ref;
  double magic_block_search_threshold;
  double magic_scan_distance;
  double magic_diagonal_lambda_scale;

  /* hooks */

  void (*init_frame) (SchroEncoderFrame *frame);
  void (*user_stage) (SchroEncoderFrame *frame);
  void (*handle_gop) (SchroEncoder *encoder, int i);
  int (*setup_frame) (SchroEncoderFrame *frame);
  int (*handle_quants) (SchroEncoder *encoder, int i);

  /* other */

  int end_of_stream;
  int end_of_stream_handled;
  int end_of_stream_pulled;
  int completed_eos;
  int prev_offset;
  int force_sequence_header;

  SchroPictureNumber au_frame;
  int next_slot;

  int output_slot;

  SchroList *inserted_buffers;
  int queue_changed;

  int engine_init;
  SchroEngineIterateFunc engine_iterate;
  int quantiser_engine;

  double start_time;
  int downsample_levels;

  /* internal stuff */

  double cycles_per_degree_horiz;
  double cycles_per_degree_vert;

  double intra_subband_weights[SCHRO_N_WAVELETS][SCHRO_LIMIT_TRANSFORM_DEPTH][SCHRO_LIMIT_SUBBANDS];
  double inter_subband_weights[SCHRO_N_WAVELETS][SCHRO_LIMIT_TRANSFORM_DEPTH][SCHRO_LIMIT_SUBBANDS];
  SchroHistogramTable intra_hist_tables[60];


  /* statistics */

  double average_arith_context_ratios_intra[3][SCHRO_LIMIT_SUBBANDS];
  double average_arith_context_ratios_inter[3][SCHRO_LIMIT_SUBBANDS];

  double frame_stats[21];

  /* engine specific stuff */

  int bits_per_picture;
  int subgroup_position;
  int I_complexity;
  int P_complexity;
  int B_complexity;
  int B_complexity_sum;
  long int I_frame_alloc;
  long int P_frame_alloc;
  long int B_frame_alloc;
  long int gop_target;

  // Current qf, from which is derived ...
  double qf;
  // lambda to use for intra pictures in CBR mode
  double intra_cbr_lambda;

  int gop_picture;
  int quant_slot;

  int last_ref;
};
