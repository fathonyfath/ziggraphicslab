const std = @import("std");
pub const glfw = @import("glfw");
pub const gl = @import("gl");

var procs: gl.ProcTable = undefined;
var global_window: *glfw.Window = undefined;
var init_phase: InitPhase = InitPhase.none;

const InitPhase = enum(u32) {
    none = 0,
    glfw_init,
    window_created,
    procs_init,
};

pub const OpenGLProfile = enum(u32) {
    core = @intFromEnum(glfw.OpenGLProfile.opengl_core_profile),
    compatibility = @intFromEnum(glfw.OpenGLProfile.opengl_compat_profile),
};

pub const Config = struct {
    width: u32,
    height: u32,
    title: [:0]const u8,
    opengl_profile: OpenGLProfile = .core,
};

pub fn create(config: Config) !void {
    errdefer destroy();

    try glfw.init();
    _ = increaseInitPhase();

    glfw.windowHint(.context_version_major, 4);
    glfw.windowHint(.context_version_minor, 1);
    glfw.windowHint(.opengl_profile, @enumFromInt(@intFromEnum(config.opengl_profile)));
    glfw.windowHint(.opengl_forward_compat, true);

    global_window = try glfw.Window.create(@intCast(config.width), @intCast(config.height), config.title, null);
    _ = increaseInitPhase();

    glfw.makeContextCurrent(global_window);

    if (!procs.init(fixedGetProcAddress)) return error.InitFailed;
    _ = increaseInitPhase();

    _ = global_window.setFramebufferSizeCallback(framebufferSizeCallback);
    gl.makeProcTableCurrent(&procs);
}

pub fn destroy() void {
    blk: switch (init_phase) {
        .procs_init => {
            gl.makeProcTableCurrent(null);
            continue :blk decreaseInitPhase();
        },
        .window_created => {
            glfw.makeContextCurrent(null);
            global_window.destroy();
            continue :blk decreaseInitPhase();
        },
        .glfw_init => {
            glfw.terminate();
            continue :blk decreaseInitPhase();
        },
        else => {},
    }
}

pub fn shouldClose() bool {
    return global_window.shouldClose();
}

pub fn getKey(key: glfw.Key) glfw.Action {
    return global_window.getKey(key);
}

pub fn setShouldClose(should_close: bool) void {
    global_window.setShouldClose(should_close);
}

pub fn swapBuffers() void {
    global_window.swapBuffers();
}

fn fixedGetProcAddress(prefixed_name: [*:0]const u8) ?gl.PROC {
    return @alignCast(glfw.getProcAddress(std.mem.span(prefixed_name)));
}

fn increaseInitPhase() InitPhase {
    init_phase = @enumFromInt(@intFromEnum(init_phase) + 1);
    return init_phase;
}

fn decreaseInitPhase() InitPhase {
    init_phase = @enumFromInt(@intFromEnum(init_phase) - 1);
    return init_phase;
}

fn framebufferSizeCallback(_: *glfw.Window, width: c_int, height: c_int) callconv(.C) void {
    gl.Viewport(0, 0, width, height);
}
