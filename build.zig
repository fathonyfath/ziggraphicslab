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

const Module = struct {
    name: []const u8,
    main_file: []const u8,
    dependencies: ?[]const []const u8 = null,
};

const commons = [_]Module{
    Module{
        .name = "opengl_common",
        .main_file = "opengl_common/root.zig",
        .dependencies = &.{ "zglfw", "gl" },
    },
};

const experiments = [_]Module{
    Module{
        .name = "hello_triangle",
        .main_file = "learnopengl/001_hello_triangle/main.zig",
        .dependencies = &.{"opengl_common"},
    },
    Module{
        .name = "hello_rectangle",
        .main_file = "learnopengl/002_hello_rectangle/main.zig",
        .dependencies = &.{"opengl_common"},
    },
    Module{
        .name = "hello_shaders",
        .main_file = "learnopengl/003_hello_shaders/main.zig",
        .dependencies = &.{"opengl_common"},
    },
    Module{
        .name = "hello_textures",
        .main_file = "learnopengl/004_hello_textures/main.zig",
        .dependencies = &.{ "opengl_common", "zstbi" },
    },
    Module{
        .name = "hello_transformations",
        .main_file = "learnopengl/005_hello_transformations/main.zig",
        .dependencies = &.{ "opengl_common", "zstbi", "zm" },
    },
    Module{
        .name = "single_vao",
        .main_file = "others/single_vao/main.zig",
        .dependencies = &.{"opengl_common"},
    },
};

const DependencyApplier = *const fn (*std.Build, *std.Build.Module, std.Build.ResolvedTarget, std.builtin.OptimizeMode) void;

const dependencies = DependencyMap.initComptime(.{
    .{ "zglfw", &linkZGLFW },
    .{ "gl", &linkGL },
    .{ "zstbi", &linkZSTBI },
    .{ "zm", &linkZM },
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

fn linkZSTBI(
    b: *std.Build,
    module: *std.Build.Module,
    _: std.Build.ResolvedTarget,
    _: std.builtin.OptimizeMode,
) void {
    const zstbi = b.dependency("zstbi", .{});
    module.addImport("stbi", zstbi.module("root"));
}

fn linkZM(
    b: *std.Build,
    module: *std.Build.Module,
    _: std.Build.ResolvedTarget,
    _: std.builtin.OptimizeMode,
) void {
    const zm = b.dependency("zm", .{});
    module.addImport("zm", zm.module("zm"));
}

fn addExperiment(
    b: *std.Build,
    comptime m: Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const module = b.createModule(.{
        .root_source_file = b.path("experiments/" ++ m.main_file),
        .target = target,
        .optimize = optimize,
    });

    if (m.dependencies) |deps| {
        inline for (deps) |d| {
            const internal_module = b.modules.get(d ++ "_internal");

            if (internal_module) |internal| {
                module.addImport(d, internal);
            } else {
                const dependency = dependencies.get(d) orelse {
                    @panic("Undefined dependency '" ++ d ++ "' for experiment module '" ++ m.name ++ "'.");
                };
                dependency(b, module, target, optimize);
            }
        }
    }

    const executable = b.addExecutable(.{
        .name = m.name,
        .root_module = module,
    });

    const install_step = b.step(m.name, "Build " ++ m.name);
    install_step.dependOn(&b.addInstallArtifact(executable, .{}).step);
    b.getInstallStep().dependOn(install_step);

    const run_step = b.step(m.name ++ "-run", "Run " ++ m.name);
    run_step.dependOn(&b.addRunArtifact(executable).step);
}

fn addCommon(
    b: *std.Build,
    comptime m: Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const module = b.addModule(m.name ++ "_internal", .{
        .root_source_file = b.path("commons/" ++ m.main_file),
        .target = target,
        .optimize = optimize,
    });

    if (m.dependencies) |deps| {
        inline for (deps) |d| {
            const dependency = dependencies.get(d) orelse {
                @panic("Undefined dependency '" ++ d ++ "' for common module '" ++ m.name ++ "'.");
            };
            dependency(b, module, target, optimize);
        }
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    inline for (commons) |c| {
        addCommon(b, c, target, optimize);
    }

    inline for (experiments) |e| {
        addExperiment(b, e, target, optimize);
    }
}
