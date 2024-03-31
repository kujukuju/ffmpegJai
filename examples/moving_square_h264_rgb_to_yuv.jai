
// this doesn't work, but I think the timing issue with h264 yuv might have been with the incorrect data size getting multiplied down the various ffmpeg conversion math

fps :: 60;
duration :: 8000;
frame_count :: fps * duration / 1000;

width :: 1920;
height :: 1080;

Pixel :: struct {
    r: u8;
    g: u8;
    b: u8;
}

main :: () {
    codec: *AVCodec = avcodec_find_encoder(.AV_CODEC_ID_H264);
    assert(!!codec, "Could not find codec.\n");

    codec_context: *AVCodecContext = avcodec_alloc_context3(codec);
    assert(!!codec_context, "Could not allocate video codec context.\n");
    codec_context.bit_rate = 0;
    codec_context.width = width;
    codec_context.height = height;
    codec_context.time_base = .{1, fps};
    codec_context.framerate = .{fps, 1};
    codec_context.gop_size = 10;
    codec_context.max_b_frames = 1;
    codec_context.pix_fmt = .AV_PIX_FMT_YUV420P;

    av_opt_set(codec_context.priv_data, "preset", "veryfast", 0);
    av_opt_set(codec_context.priv_data, "qp", "0", 0);

    if avcodec_open2(codec_context, codec, null) != 0 {
        assert(false, "Could not open codec.\n");
    }

    filename :: "moving_square_h264.mp4";

    format_context: *AVFormatContext;
    avformat_alloc_output_context2(*format_context, null, null, filename);
    assert(!!format_context, "Could not allocate format context.\n");

    stream: *AVStream = avformat_new_stream(format_context, null);

    if avcodec_parameters_from_context(stream.codecpar, codec_context) != 0 {
        assert(false, "Could not copy codec parameters to stream.\n");
    }

    stream.codecpar.framerate = codec_context.framerate;
    stream.codecpar.bit_rate = 0;

    stream.time_base = codec_context.time_base;
    stream.avg_frame_rate = codec_context.framerate;
    stream.r_frame_rate = codec_context.framerate;

    if avio_open(*format_context.pb, filename, AVIO_FLAG_WRITE) != 0 {
        assert(false, "Could not open output file.\n");
    }

    if avformat_write_header(format_context, null) != 0 {
        assert(false, "Could not write header to output file.\n");
    }

    frame: *AVFrame = av_frame_alloc();
    assert(!!frame, "Could not allocate frame.\n");

    frame.format = cast(s32) codec_context.pix_fmt;
    frame.width = codec_context.width;
    frame.height = codec_context.height;
    // frame.time_base = codec_context.time_base;

    ret: s32 = av_frame_get_buffer(frame, 0);
    if ret != 0 {
        assert(false, "Could not allocate frame buffer.\n");
    }

    packet: *AVPacket = av_packet_alloc();
    assert(!!packet, "Could not allocate packet.\n");

    sws_context: *SwsContext = sws_getContext(
        width, height, .AV_PIX_FMT_RGB24,
        width, height, .AV_PIX_FMT_YUV420P,
        SWS_BILINEAR, null, null, null);

    r: [..] u8;
    g: [..] u8;
    b: [..] u8;

    for i: 0..frame_count - 1 {
        ret = av_frame_make_writable(frame);
        assert(ret == 0, "Could not make frame writable.\n");

        get_frame_data_separate(i, *r, *g, *b);

        frame.data[0] = r.data;
        frame.data[1] = g.data;
        frame.data[2] = b.data;
        frame.linesize[0] = width * size_of(u8);
        frame.linesize[1] = width * size_of(u8);
        frame.linesize[2] = width * size_of(u8);

        sws_scale(sws_context, frame.data.data, frame.linesize.data, 0, height, frame.data.data, frame.linesize.data);

        frame.pts = i;
        // frame.pts = i * fps;

        ret = avcodec_send_frame(codec_context, frame);
        assert(ret == 0, "Could not send frame data.\n");

        while true {
            ret = avcodec_receive_packet(codec_context, packet);
            if ret < 0 {
                break;
            }

            av_interleaved_write_frame(format_context, packet);

            av_packet_unref(packet);
        }
    }

    av_write_trailer(format_context);
    avio_closep(*format_context.pb);

    av_frame_free(*frame);
    av_packet_free(*packet);
    avcodec_close(codec_context);
    avcodec_free_context(*codec_context);
    avformat_close_input(*format_context);
}

get_frame_data_separate :: (frame: int, r: *[..] u8, g: *[..] u8, b: *[..] u8) {
    array_resize(r, width * height);
    array_resize(g, width * height);
    array_resize(b, width * height);

    progress := cast(float) frame / (frame_count - 1);
    cube_width :: 32;
    cube_height :: 32;

    cube_start :: int.[0, 540 - cube_height / 2];
    cube_end :: int.[width - cube_width, 540 - cube_height / 2];

    cube_position := int.[
        cast(int) ((cube_end[0] - cube_start[0]) * progress + cube_start[0]),
        cast(int) ((cube_end[1] - cube_start[1]) * progress + cube_start[1]),
    ];

    memset(r.data, 0, width * height);
    memset(g.data, 0, width * height);
    memset(b.data, 0, width * height);

    for y_offset: 0..cube_height - 1 {
        cube_y := cube_position[1] + y_offset;

        for x_offset: 0..cube_width - 1 {
            cube_x := cube_position[0] + x_offset;

            index := cube_y * width + cube_x;
            r.*[index] = 255;
            g.*[index] = 255;
            b.*[index] = 255;
        }
    }
}

// by the way this method is wrong
// u and v are half dimensions for some reason
rgb_to_yuv :: (r: int, g: int, b: int) -> u8, u8, u8 {
    y := cast(u8) clamp(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16, 0, 255);
    u := cast(u8) clamp(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128, 0, 255);
    v := cast(u8) clamp(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128, 0, 255);

    return y, u, v;
}

#import "ffmpegJai";

#import "Basic";
#import "File";
