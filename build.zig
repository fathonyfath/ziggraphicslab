const std = @import("std");
const builtin = @import("builtin");
const DependencyMap = std.static_string_map.StaticStringMap(DependencyApplier);

comptime {
    const required_zig = "0.14.0";
    const current_zig = builtin.zig_version;
    const min_zig = std.SemanticVersion.parse(required_zig) catch unreachable;
    if (current_zig.order(min_zig) == .lt) {
        @compileError(std.fmt.comptimePrint("Compiling this project requires Zig with version {} or higher.", .{min_zig}));
    }
}

const Experiment = struct {
    name: []const u8,
    main_file: []const u8,
    dependencies: ?[]const []const u8 = null,
};

const experiments = [_]Experiment{
    Experiment{
        .name = "hello_triangle",
        .main_file = "learnopengl/hello_triangle/hello_triangle.zig",
        .dependencies = &.{ "zglfw", "gl" },
    },
    Experiment{
        .name = "hello_rectangle",
        .main_file = "learnopengl/hello_rectangle/hello_rectangle.zig",
        .dependencies = &.{ "zglfw", "gl" },
    },
};

const DependencyApplier = *const fn (*std.Build, *std.Build.Module, std.Build.ResolvedTarget, std.builtin.OptimizeMode) void;

const dependencies = DependencyMap.initComptime(.{
    .{ "zglfw", &linkZGLFW },
    .{ "gl", &linkGL },
});

fn linkZGLFW(
    b: *std.Build,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    _: std.builtin.OptimizeMode,
) void {
    const zglfw = b.dependency("zglfw", .{});
    module.addImport("glfw", zglfw.module("root"));

    if (target.result.os.tag != .emscripten) {
        module.linkLibrary(zglfw.artifact("glfw"));
    }
}

fn linkGL(
    b: *std.Build,
    module: *std.Build.Module,
    _: std.Build.ResolvedTarget,
    _: std.builtin.OptimizeMode,
) void {
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.1",
        .profile = .core,
        .extensions = &.{},
    });
    module.addImport("gl", gl_bindings);
}

fn addExperiment(
    b: *std.Build,
    comptime e: Experiment,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const module = b.createModule(.{
        .root_source_file = b.path("experiments/" ++ e.main_file),
        .target = target,
        .optimize = optimize,
    });

    if (e.dependencies) |deps| {
        inline for (deps) |d| {
            const dependency = dependencies.get(d) orelse {
                @panic("Undefined dependency '" ++ d ++ "' for experiment '" ++ e.name ++ "'.");
            };
            dependency(b, module, target, optimize);
        }
    }

    const executable = b.addExecutable(.{
        .name = e.name,
        .root_module = module,
    });

    const install_step = b.step(e.name, "Build " ++ e.name);
    install_step.dependOn(&b.addInstallArtifact(executable, .{}).step);
    b.getInstallStep().dependOn(install_step);

    const run_step = b.step(e.name ++ "-run", "Run " ++ e.name);
    run_step.dependOn(&b.addRunArtifact(executable).step);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    inline for (experiments) |e| {
        addExperiment(b, e, target, optimize);
    }
}
