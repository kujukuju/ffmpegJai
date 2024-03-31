
// this doesnt work at all. if you use ffprobe the fps values are all extremely incorrect
// I think it has to do with not correct yuv conversion values so it has the wrong data size
// otherwise I have no clue... it works except for the fps values as you can see using ffprobe

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
    codec: *AVCodec = avcodec_find_encoder(.AV_CODEC_ID_FFV1);
    assert(!!codec, "Could not find codec.\n");

    codec_context: *AVCodecContext = avcodec_alloc_context3(codec);
    assert(!!codec_context, "Could not allocate video codec context.\n");
    // codec_context.bit_rate = 40000000;
    codec_context.width = width;
    codec_context.height = height;
    codec_context.time_base = .{1, fps};
    codec_context.framerate = .{fps, 1};
    codec_context.gop_size = 10;
    codec_context.max_b_frames = 1;
    codec_context.pix_fmt = .AV_PIX_FMT_BGRA;

    if avcodec_open2(codec_context, codec, null) != 0 {
        assert(false, "Could not open codec.\n");
    }

    filename :: "moving_square_raw_video_other.avi";

    format_context: *AVFormatContext;
    avformat_alloc_output_context2(*format_context, null, null, filename);
    assert(!!format_context, "Could not allocate format context.\n");

    if format_context.oformat.flags & AVFMT_GLOBALHEADER {
        codec_context.flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    stream: *AVStream = avformat_new_stream(format_context, null);
    assert(!!stream, "Could not create new stream.\n");
    avcodec_parameters_from_context(stream.codecpar, codec_context);
    stream.time_base = codec_context.time_base;
    
    print("w h % %\n", stream.codecpar.width, stream.codecpar.height);

    if avio_open(*format_context.pb, filename, AVIO_FLAG_WRITE) != 0 {
        assert(false, "Could not open output file.\n");
    }

    ret: s32 = avformat_write_header(format_context, null);
    assert(ret == 0, "Could not write header.\n");

    frame: *AVFrame = av_frame_alloc();
    assert(!!frame, "Could not allocate frame.\n");

    frame.format = cast(s32) codec_context.pix_fmt;
    frame.width = codec_context.width;
    frame.height = codec_context.height;
    // frame.color_range = .AVCOL_RANGE_MPEG;
    // frame.color_primaries = .AVCOL_PRI_BT709;
    // frame.color_trc = .AVCOL_TRC_IEC61966_2_1;
    // frame.colorspace = .AVCOL_SPC_BT709;

    ret = av_frame_get_buffer(frame, 0);
    assert(ret == 0, "Could not allocate frame buffer.\n");

    packet: *AVPacket = av_packet_alloc();
    assert(!!packet, "Could not allocate packet.\n");

    // r: [..] u8;
    // g: [..] u8;
    // b: [..] u8;

    // rgb: [..] u8;
    bgra: [..] u8;

    print("frames: %\n", frame_count);

    for i: 0..frame_count - 1 {
        ret = av_frame_make_writable(frame);
        assert(ret == 0, "Could not make frame writable.\n");

        // get_frame_data_separate(i, *r, *g, *b);
        // frame.data[0] = r.data;
        // frame.data[1] = g.data;
        // frame.data[2] = b.data;
        // frame.linesize[0] = width;
        // frame.linesize[1] = width;
        // frame.linesize[2] = width;

        // get_frame_data_rgb(i, *rgb);
        // frame.data[0] = rgb.data;
        // frame.linesize[0] = width * 3;

        get_frame_data_bgra(i, *bgra);
        frame.data[0] = bgra.data;
        frame.linesize[0] = width * 4;

        frame.pts = i;

        ret = avcodec_send_frame(codec_context, frame);
        assert(ret == 0, "Could not send frame data.\n");

        while ret >= 0 {
            ret = avcodec_receive_packet(codec_context, packet);
            if ret != 0 {
                break;
            }

            av_interleaved_write_frame(format_context, packet);
            av_packet_unref(packet);
        }
    }

    // flush?
    avcodec_send_frame(codec_context, null);
    while avcodec_receive_packet(codec_context, packet) == 0 {
        av_interleaved_write_frame(format_context, packet);
        av_packet_unref(packet);
    }

    av_write_trailer(format_context);
    avio_closep(*format_context.pb);

    av_frame_free(*frame);
    av_packet_free(*packet);
    avcodec_close(codec_context);
    avcodec_free_context(*codec_context);
    avformat_close_input(*format_context);
}

get_frame_data_rgb :: (frame: int, rgb: *[..] u8) {
    array_resize(rgb, width * height * 3);

    progress := cast(float) frame / (frame_count - 1);
    cube_width :: 32;
    cube_height :: 32;

    cube_start :: int.[0, 540 - cube_height / 2];
    cube_end :: int.[width - cube_width, 540 - cube_height / 2];

    cube_position := int.[
        cast(int) ((cube_end[0] - cube_start[0]) * progress + cube_start[0]),
        cast(int) ((cube_end[1] - cube_start[1]) * progress + cube_start[1]),
    ];

    memset(rgb.data, 0, rgb.count);

    for y_offset: 0..cube_height - 1 {
        cube_y := cube_position[1] + y_offset;

        for x_offset: 0..cube_width - 1 {
            cube_x := cube_position[0] + x_offset;

            index := cube_y * width + cube_x;
            rgb.*[index * 3 + 0] = 255;
            rgb.*[index * 3 + 1] = 255;
            rgb.*[index * 3 + 2] = 255;
        }
    }
}
get_frame_data_bgra :: (frame: int, bgra: *[..] u8) {
    array_resize(bgra, width * height * 4);

    progress := cast(float) frame / (frame_count - 1);
    cube_width :: 32;
    cube_height :: 32;

    cube_start :: int.[0, 540 - cube_height / 2];
    cube_end :: int.[width - cube_width, 540 - cube_height / 2];

    cube_position := int.[
        cast(int) ((cube_end[0] - cube_start[0]) * progress + cube_start[0]),
        cast(int) ((cube_end[1] - cube_start[1]) * progress + cube_start[1]),
    ];

    memset(bgra.data, 0, bgra.count);

    for y_offset: 0..cube_height - 1 {
        cube_y := cube_position[1] + y_offset;

        for x_offset: 0..cube_width - 1 {
            cube_x := cube_position[0] + x_offset;

            index := cube_y * width + cube_x;
            bgra.*[index * 4 + 0] = 255;
            bgra.*[index * 4 + 1] = 255;
            bgra.*[index * 4 + 2] = 255;
            bgra.*[index * 4 + 3] = 255;
        }
    }
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

#import "ffmpegJai";

#import "Basic";
#import "File";
