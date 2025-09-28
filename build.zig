const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // beatz modular build options
    const beatz_mode = b.option(enum { performance, balanced, size }, "beatz_mode", "Performance mode: performance, balanced, or size") orelse .balanced;
    const beatz_backends_str = b.option([]const u8, "beatz_backends", "Comma-separated backends: pipewire,alsa") orelse "pipewire,alsa";
    const beatz_features_str = b.option([]const u8, "beatz_features", "Comma-separated features: core,mixer,hotplug,conversion") orelse "core,mixer,hotplug,conversion";
    const beatz_buffer_sizes_str = b.option([]const u8, "beatz_buffer_sizes", "Comma-separated buffer sizes") orelse "64,128,256,512,1024,2048,4096";
    const beatz_sample_rates_str = b.option([]const u8, "beatz_sample_rates", "Comma-separated sample rates") orelse "16000,22050,44100,48000,96000,192000";

    // Parse build options - PipeWire is always enabled on Linux unless explicitly disabled
    const has_pipewire = if (target.result.os.tag == .linux)
        std.mem.indexOf(u8, beatz_backends_str, "no-pipewire") == null
    else
        std.mem.indexOf(u8, beatz_backends_str, "pipewire") != null;
    const has_alsa = std.mem.indexOf(u8, beatz_backends_str, "alsa") != null;
    const has_mixer = std.mem.indexOf(u8, beatz_features_str, "mixer") != null;
    const has_hotplug = std.mem.indexOf(u8, beatz_features_str, "hotplug") != null;
    const has_conversion = std.mem.indexOf(u8, beatz_features_str, "conversion") != null;

    // Create build options for conditional compilation
    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_pipewire", has_pipewire);
    build_options.addOption(bool, "enable_alsa", has_alsa);
    build_options.addOption(bool, "enable_mixer", has_mixer);
    build_options.addOption(bool, "enable_hotplug", has_hotplug);
    build_options.addOption(bool, "enable_conversion", has_conversion);
    build_options.addOption(@TypeOf(beatz_mode), "performance_mode", beatz_mode);
    build_options.addOption([]const u8, "buffer_sizes", beatz_buffer_sizes_str);
    build_options.addOption([]const u8, "sample_rates", beatz_sample_rates_str);
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Zig modules are the preferred way of making Zig code available to consumers.
    // addModule defines a module that we intend to make available for importing
    // to our consumers. We must give it a name because a Zig package can expose
    // multiple modules and consumers will need to be able to specify which
    // module they want to access.
    const mod = b.addModule("beatz", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
        .imports = &.{
            .{ .name = "build_options", .module = build_options.createModule() },
        },
    });

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "beatz",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                // Here "beatz" is the name you will use in your source code to
                // import this module (e.g. `@import("beatz")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{ .name = "beatz", .module = mod },
            },
        }),
    });

    if (target.result.os.tag == .linux) {
        // Conditional library linking based on enabled backends
        if (has_pipewire) {
            exe.linkSystemLibrary("pipewire-0.3");
            exe.addIncludePath(.{ .cwd_relative = "/usr/include/pipewire-0.3" });
            exe.addIncludePath(.{ .cwd_relative = "/usr/include/spa-0.2" });

            mod.addSystemIncludePath(.{ .cwd_relative = "/usr/include/pipewire-0.3" });
            mod.addSystemIncludePath(.{ .cwd_relative = "/usr/include/spa-0.2" });
        }

        if (has_alsa) {
            exe.linkSystemLibrary("alsa");
            exe.addIncludePath(.{ .cwd_relative = "/usr/include/alsa" });

            mod.addSystemIncludePath(.{ .cwd_relative = "/usr/include/alsa" });
        }

        // Always link libc when any backend is enabled
        if (has_pipewire or has_alsa) {
            exe.linkLibC();
            mod.link_libc = true;
        }
    }

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // Link system libraries for tests on Linux
    if (target.result.os.tag == .linux) {
        if (has_pipewire) {
            mod_tests.linkSystemLibrary("pipewire-0.3");
            mod_tests.addIncludePath(.{ .cwd_relative = "/usr/include/pipewire-0.3" });
            mod_tests.addIncludePath(.{ .cwd_relative = "/usr/include/spa-0.2" });
        }
        if (has_alsa) {
            mod_tests.linkSystemLibrary("alsa");
            mod_tests.addIncludePath(.{ .cwd_relative = "/usr/include/alsa" });
        }
        if (has_pipewire or has_alsa) {
            mod_tests.linkLibC();
        }
    }

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // Link system libraries for exe tests on Linux
    if (target.result.os.tag == .linux) {
        exe_tests.linkSystemLibrary("pipewire-0.3");
        exe_tests.linkSystemLibrary("alsa");
        exe_tests.linkLibC();
        exe_tests.addIncludePath(.{ .cwd_relative = "/usr/include/pipewire-0.3" });
        exe_tests.addIncludePath(.{ .cwd_relative = "/usr/include/spa-0.2" });
        exe_tests.addIncludePath(.{ .cwd_relative = "/usr/include/alsa" });
    }

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Add example executables
    const wav_player_exe = b.addExecutable(.{
        .name = "wav_player",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/wav_player.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "beatz", .module = mod },
            },
        }),
    });

    if (target.result.os.tag == .linux) {
        wav_player_exe.linkSystemLibrary("pipewire-0.3");
        wav_player_exe.linkSystemLibrary("alsa");
        wav_player_exe.linkLibC();
        wav_player_exe.addIncludePath(.{ .cwd_relative = "/usr/include/pipewire-0.3" });
        wav_player_exe.addIncludePath(.{ .cwd_relative = "/usr/include/spa-0.2" });
        wav_player_exe.addIncludePath(.{ .cwd_relative = "/usr/include/alsa" });
    }

    b.installArtifact(wav_player_exe);

    const run_wav_player_step = b.step("wav-player", "Build and install WAV player example");
    run_wav_player_step.dependOn(&wav_player_exe.step);

    // Add audio recorder example
    const audio_recorder_exe = b.addExecutable(.{
        .name = "audio_recorder",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/audio_recorder.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "beatz", .module = mod },
            },
        }),
    });

    if (target.result.os.tag == .linux) {
        audio_recorder_exe.linkSystemLibrary("pipewire-0.3");
        audio_recorder_exe.linkSystemLibrary("alsa");
        audio_recorder_exe.linkLibC();
        audio_recorder_exe.addIncludePath(.{ .cwd_relative = "/usr/include/pipewire-0.3" });
        audio_recorder_exe.addIncludePath(.{ .cwd_relative = "/usr/include/spa-0.2" });
        audio_recorder_exe.addIncludePath(.{ .cwd_relative = "/usr/include/alsa" });
    }

    b.installArtifact(audio_recorder_exe);

    const run_audio_recorder_step = b.step("audio-recorder", "Build and install audio recorder example");
    run_audio_recorder_step.dependOn(&audio_recorder_exe.step);

    // Add device monitor example
    const device_monitor_exe = b.addExecutable(.{
        .name = "device_monitor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/device_monitor.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "beatz", .module = mod },
            },
        }),
    });

    if (target.result.os.tag == .linux) {
        device_monitor_exe.linkSystemLibrary("pipewire-0.3");
        device_monitor_exe.linkSystemLibrary("alsa");
        device_monitor_exe.linkLibC();
        device_monitor_exe.addIncludePath(.{ .cwd_relative = "/usr/include/pipewire-0.3" });
        device_monitor_exe.addIncludePath(.{ .cwd_relative = "/usr/include/spa-0.2" });
        device_monitor_exe.addIncludePath(.{ .cwd_relative = "/usr/include/alsa" });
    }

    b.installArtifact(device_monitor_exe);

    const run_device_monitor_step = b.step("device-monitor", "Build and install device monitor example");
    run_device_monitor_step.dependOn(&device_monitor_exe.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.
}
