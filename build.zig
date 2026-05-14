const std = @import("std");
const builtin = @import("builtin");

comptime {
    const required_zig = "0.16.0";
    const current_zig = builtin.zig_version;
    const min_zig = std.SemanticVersion.parse(required_zig) catch unreachable;
    if (current_zig.order(min_zig) == .lt) {
        @compileError(std.fmt.comptimePrint("Compiling this project requires Zig {} or higher.", .{min_zig}));
    }
}

const Module = struct {
    name: []const u8,
    main_file: []const u8,
    /// Extra external dependencies beyond common (e.g. "zstbi").
    dependencies: ?[]const []const u8 = null,
};

const experiments = [_]Module{
    .{
        .name = "hello_window",
        .main_file = "learnopengl/001_hello_window/main.zig",
    },
    .{
        .name = "hello_triangle",
        .main_file = "learnopengl/002_hello_triangle/main.zig",
    },
    .{
        .name = "hello_rectangle",
        .main_file = "learnopengl/003_hello_rectangle/main.zig",
    },
    .{
        .name = "hello_shaders",
        .main_file = "learnopengl/004_hello_shaders/main.zig",
    },
    .{
        .name = "hello_textures",
        .main_file = "learnopengl/005_hello_textures/main.zig",
        .dependencies = &.{"zstbi"},
    },
    .{
        .name = "hello_transformations",
        .main_file = "learnopengl/006_hello_transformations/main.zig",
        .dependencies = &.{"zstbi"},
    },
    .{
        .name = "hello_coordinates",
        .main_file = "learnopengl/007_hello_coordinates/main.zig",
        .dependencies = &.{"zstbi"},
    },
};

/// Each pub fn here is an external dependency applier.
/// The function name is the key used in Module.dependencies.
const dep_appliers = struct {
    pub fn sdl(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
        const dep = b.dependency("sdl", .{ .target = target, .optimize = optimize });
        const lib = dep.artifact("SDL3");

        const translate = b.addTranslateC(.{
            .root_source_file = b.path("common/sdl_entry.h"),
            .target = target,
            .optimize = optimize,
        });
        translate.addIncludePath(lib.getEmittedIncludeTree());

        module.linkLibrary(lib);
        module.addImport("sdl_c", translate.createModule());
    }

    pub fn gl(b: *std.Build, module: *std.Build.Module, _: std.Build.ResolvedTarget, _: std.builtin.OptimizeMode) void {
        const bindings = @import("zigglgen").generateBindingsModule(b, .{
            .api = .gl,
            .version = .@"4.1",
            .profile = .core,
            .extensions = &.{},
        });
        module.addImport("gl", bindings);
    }

    pub fn zstbi(b: *std.Build, module: *std.Build.Module, _: std.Build.ResolvedTarget, _: std.builtin.OptimizeMode) void {
        const dep = b.dependency("zstbi", .{});
        module.addImport("stbi", dep.module("root"));
    }

    pub fn zmath(b: *std.Build, module: *std.Build.Module, _: std.Build.ResolvedTarget, _: std.builtin.OptimizeMode) void {
        const dep = b.dependency("zmath", .{});
        module.addImport("zmath", dep.module("root"));
    }
};

fn applyDep(
    b: *std.Build,
    module: *std.Build.Module,
    comptime dep_name: []const u8,
    comptime parent_name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    if (!@hasDecl(dep_appliers, dep_name)) {
        @compileError("Undefined dependency '" ++ dep_name ++ "' for module '" ++ parent_name ++ "'.");
    }
    @field(dep_appliers, dep_name)(b, module, target, optimize);
}

fn setupCommon(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const module = b.addModule("common", .{
        .root_source_file = b.path("common/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    applyDep(b, module, "sdl", "common", target, optimize);
    applyDep(b, module, "gl", "common", target, optimize);
    applyDep(b, module, "zmath", "common", target, optimize);
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

    module.addImport("common", b.modules.get("common").?);

    if (m.dependencies) |deps| {
        inline for (deps) |d| {
            applyDep(b, module, d, m.name, target, optimize);
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

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    setupCommon(b, target, optimize);

    inline for (experiments) |e| {
        addExperiment(b, e, target, optimize);
    }
}
