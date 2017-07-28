#ifndef INCLUDE_CAM_LIVE_H_
#define INCLUDE_CAM_LIVE_H_

#include <stdint.h>

#ifdef _MSC_VER
#ifdef __cplusplus
#ifdef CAM_LIVE_EXPORTS
#define CAM_LIVE_API  extern "C" __declspec(dllexport)
#else
#define CAM_LIVE_API extern "C" __declspec(dllimport)
#endif
#else
#ifdef CAM_LIVE_EXPORTS
#define CAM_LIVE_API __declspec(dllexport)
#else
#define CAM_LIVE_API __declspec(dllimport)
#endif
#endif
#else /* _MSC_VER */
#ifdef __cplusplus
#ifdef CAM_LIVE_EXPORTS
#define CAM_LIVE_API  extern "C" __attribute__((visibility ("default")))
#else
#define CAM_LIVE_API extern "C"
#endif
#else
#ifdef CAM_LIVE_EXPORTS
#define CAM_LIVE_API __attribute__((visibility ("default")))
#else
#define CAM_LIVE_API
#endif
#endif
#endif

#define ST_LIVE_ERR_OK (0)
#define ST_LIVE_ERR_NOMEM (-1)
#define ST_LIVE_ERR_INVALID_ARG (-2)
#define ST_LIVE_ERR_NETWORK (-3)
#define ST_LIVE_ERR_CODEC (-4)

struct st_live_context;
typedef struct st_live_context st_live_context_t;

// TODO(cppbuild): Add your library interface here
// CAM_LIVE_API int st_live_init();
// CAM_LIVE_API void st_live_uninit();

typedef enum {
	ST_LIVE_SINK_FILE,
	ST_LIVE_SINK_RTMP,
} st_live_sink_type;

typedef enum {
	ST_LIVE_FMT_YUV420P,
	ST_LIVE_FMT_NV12,
	ST_LIVE_FMT_NV21,
	ST_LIVE_FMT_RGBA,
} st_live_raw_format;

typedef struct {
	unsigned char * Y_base;
	unsigned int Y_stride;

	unsigned char * CrBr_base;
	unsigned int CrBr_stride;
} st_nv12_descriptor_t;

typedef struct {
	unsigned char *Y_base;
	unsigned int Y_stride;

	unsigned char *U_base;
	unsigned int U_stride;

	unsigned char *V_base;
	unsigned int V_stride;
} st_yuv420p_descriptor_t;

typedef struct {
	unsigned char *data;
	unsigned int stride;
} st_rgba_descriptor_t;

typedef struct {
	void *data;
	int nsamples;
} st_s16pcm_descriptor_t;

typedef int64_t st_timestamp_t;

typedef enum {
	ST_LIVE_CODEC_X264,
	ST_LIVE_CODEC_VIDEOTOOLBOX,
	ST_LIVE_CODEC_MEDIACODEC,
} st_live_codec_t;

typedef struct {
	st_live_codec_t codec;
	const char *mode;
	unsigned int video_bit_rate;
	unsigned int audio_bit_rate;
} st_live_config_t;

CAM_LIVE_API int st_live_create_context(st_live_sink_type type, const char *url,
		const st_live_config_t *conf, st_live_context_t **ctx);

CAM_LIVE_API int st_live_start_streaming(st_live_context_t *ctx, int width, int height, int fps, st_live_raw_format format);
CAM_LIVE_API int st_live_enqueue_frame(st_live_context_t *ctx, void *descriptor, st_timestamp_t timestamp, void *extra_data, unsigned int extra_size);

CAM_LIVE_API int st_live_enqueue_audio_frame(st_live_context_t *ctx, void *descriptor, st_timestamp_t timestamp);

CAM_LIVE_API int st_live_stop_streaming(st_live_context_t *ctx);
CAM_LIVE_API int st_live_destroy_context(st_live_context_t *ctx);

/* Player API */
struct st_player_context;
typedef struct st_player_context st_player_context_t;

typedef struct {
	int width;
	int height;
	st_timestamp_t pts;
	st_timestamp_t time_micro_sec;
	void *desc;
} st_player_video_frame_t;

typedef struct {
	st_live_codec_t codec;
	st_live_raw_format output_format;
} st_player_config_t;

typedef int (*st_player_video_cb)(st_live_raw_format fmt, st_player_video_frame_t *frame,
		unsigned char *extra_data, int extra_size,
		void *priv_data);

CAM_LIVE_API int st_player_create_context(st_player_context_t **ctx, const st_player_config_t *conf, st_player_video_cb vcb);
CAM_LIVE_API int st_player_open_url(st_player_context_t *ctx, const char *url);
CAM_LIVE_API int st_player_decode_frames(st_player_context_t *ctx, void *priv_data);
CAM_LIVE_API int st_player_close_context(st_player_context_t *ctx);

CAM_LIVE_API int st_player_destroy_context(st_player_context_t *ctx);

#endif  // INCLUDE_CAM_LIVE_H_
