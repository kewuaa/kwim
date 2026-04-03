const std = @import("std");
const mem = std.mem;

const wayland = @import("wayland");

const manifest = @import("build.zig.zon");
const version = manifest.version;

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
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    const scanner = wayland.Scanner.create(b, .{});

    scanner.addCustomProtocol(b.path("protocol/river-input-management-v1.xml"));
    scanner.addCustomProtocol(b.path("protocol/river-libinput-config-v1.xml"));
    scanner.addCustomProtocol(b.path("protocol/river-xkb-config-v1.xml"));

    scanner.generate("river_input_manager_v1", 1);
    scanner.generate("river_libinput_config_v1", 1);
    scanner.generate("river_xkb_config_v1", 1);

    const wayland_mod = b.createModule(.{ .root_source_file = scanner.result });
    const xkbcommon_mod = b.dependency("xkbcommon", .{}).module("xkbcommon");
    const mvzr_mod = b.dependency("mvzr", .{}).module("mvzr");
    const clap_mod = b.dependency("clap", .{}).module("clap");

    const config_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/config.zig"),
        .imports = &.{
            .{ .name = "wayland", .module = wayland_mod },
            .{ .name = "mvzr", .module = mvzr_mod },
        }
    });
    const kwim_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/kwim.zig"),
        .imports = &.{
            .{ .name = "wayland", .module = wayland_mod },
            .{ .name = "xkbcommon", .module = xkbcommon_mod },
        }
    });

    config_mod.addImport("kwim", kwim_mod);
    kwim_mod.addImport("config", config_mod);

    const kwm_config = b.option([]const u8, "kwm_config", "kwm config");
    if (kwm_config) |path| {
        const default_config_mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = blk: {
                const load_default_config = b.addExecutable(.{
                    .name = "load_default_config",
                    .root_module = b.createModule(.{
                        .target = target,
                        .optimize = .ReleaseSafe,
                        .root_source_file = b.path("src/load_default_config.zig"),
                        .link_libc = true,
                    }),
                });
                const load_default_config_run = b.addRunArtifact(load_default_config);
                load_default_config_run.addArg("-i");
                load_default_config_run.addArg(path);
                load_default_config_run.addArg("-o");
                break :blk load_default_config_run.addOutputFileArg("default_config.zon");
            }
        });
        kwim_mod.addImport("default_config", default_config_mod);
    }

    const kwim_options = b.addOptions();
    kwim_options.addOption(bool, "has_default_config", kwm_config != null);
    kwim_mod.addOptions("build_options", kwim_options);

    const bash_completion = b.option(
        bool,
        "bash-completion",
        "Set to true to install bash completion for kwim. Defaults to true.",
    ) orelse true;

    if (bash_completion) {
        b.installFile("completions/kwim.bash", "share/bash-completion/completions/kwim");
    }

    const zsh_completion = b.option(
        bool,
        "zsh-completion",
        "Set to true to install zsh completion for kwim. Defaults to true.",
    ) orelse true;

    if (zsh_completion) {
        b.installFile("completions/kwim.zsh", "share/zsh/site-functions/_kwim");
    }

    const full_version = blk: {
        if (b.option([]const u8, "version-string", "Override `kwm -version` output.")) |version_override| {
            break :blk version_override;
        } else if (mem.endsWith(u8, version, "-dev")) {
            var ret: u8 = undefined;

            const git_describe_long = b.runAllowFail(
                &.{ "git", "-C", b.build_root.path orelse ".", "describe", "--long" },
                &ret,
                .Ignore,
            ) catch break :blk version;

            var it = mem.splitSequence(u8, mem.trim(u8, git_describe_long, &std.ascii.whitespace), "-");
            _ = it.next().?; // previous tag
            const commit_count = it.next().?;
            const commit_hash = it.next().?;
            std.debug.assert(it.next() == null);
            std.debug.assert(commit_hash[0] == 'g');

            // Follow semantic versioning, e.g. 0.2.0-dev.42+d1cf95b
            break :blk b.fmt(version ++ ".{s}+{s}", .{ commit_count, commit_hash[1..] });
        } else {
            break :blk version;
        }
    };

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
        .name = "kwim",
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
                // Here "kwim" is the name you will use in your source code to
                // import this module (e.g. `@import("kwim")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{ .name = "clap", .module = clap_mod },
                .{ .name = "wayland", .module = wayland_mod },

                .{ .name = "config", .module = config_mod },
                .{ .name = "kwim", .module = kwim_mod },
            },

            .link_libc = true,
        }),
    });

    exe.root_module.linkSystemLibrary("wayland-client", .{});
    exe.root_module.linkSystemLibrary("xkbcommon", .{});

    const options = b.addOptions();
    options.addOption([]const u8, "version", full_version);
    exe.root_module.addOptions("build_options", options);

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

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const kwim_tests = b.addTest(.{ .root_module = kwim_mod });
    const run_kwim_tests = b.addRunArtifact(kwim_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_kwim_tests.step);

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
