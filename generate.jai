#import "Bindings_Generator";
#import "Basic";
#import "File";
#import "String";
#import "BuildCpp";
#import "File_Utilities";

#run {
    using opts: Generate_Bindings_Options;
    array_add(*system_include_paths, GENERATOR_DEFAULT_SYSTEM_INCLUDE_PATH);

    // strip_flags = .FUNCTIONS_WITH_VALIST;

    files :: string.[
        "libavcodec/avcodec.h",
        "libavutil/samplefmt.h",
        "libavutil/attributes.h",
        "libavutil/avutil.h",
        "libavutil/buffer.h",
        "libavutil/channel_layout.h",
        "libavutil/dict.h",
        "libavutil/frame.h",
        "libavutil/log.h",
        "libavutil/pixfmt.h",
        "libavutil/rational.h",
        "libavutil/opt.h",
        "libavformat/avformat.h",
        "libswscale/swscale.h",
        // "codec.h",
        // "codec_id.h",
        // "defs.h",
        // "packet.h",
        // "version_major.h",
        // "version.h",
        // "codec_desc.h",
        // "codec_par.h",
    ];

    array_add(*libpaths, "win/lib");
    array_add(*libnames, "avcodec", "avutil", "avformat", "swscale");
    array_add(*include_paths, "ffmpeg");
    // files: [..] string;
    // array_add(*files, ..file_list(tprint("%ffmpeg/libavcodec", #filepath), true));
    // array_add(*files, ..file_list(tprint("%ffmpeg/libavutil", #filepath), true));
    for file: files {
        if !ends_with(file, ".h") {
            continue;
        }

        print("%\n", file);
        array_add(*source_files, file);
    }

    footer = #string FOOTER
    FILE :: void;
    FOOTER

    // array_add(*extra_clang_arguments, "-x", "c++");
    generate_compile_time_struct_checks = false;

    // array_add(*system_include_paths, "C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.22621.0\\ucrt");
    // array_add(*system_include_paths, "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Tools\\MSVC\\14.31.31103\\include");

    generate_bindings(opts, "module.jai");
}
