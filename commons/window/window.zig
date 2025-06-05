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

pub const Config = struct {
    width: u32,
    height: u32,
    title: [:0]const u8,
};

pub fn create(config: Config) !void {
    errdefer destroy();

    try glfw.init();
    init_phase = InitPhase.glfw_init;

    glfw.windowHint(.context_version_major, 4);
    glfw.windowHint(.context_version_minor, 1);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);

    global_window = try glfw.Window.create(@intCast(config.width), @intCast(config.height), config.title, null);
    init_phase = InitPhase.window_created;

    glfw.makeContextCurrent(global_window);

    if (!procs.init(fixedGetProcAddress)) return error.InitFailed;
    init_phase = InitPhase.procs_init;

    _ = global_window.setFramebufferSizeCallback(framebufferSizeCallback);
    gl.makeProcTableCurrent(&procs);
}

pub fn destroy() void {
    blk: switch (init_phase) {
        .procs_init => {
            gl.makeProcTableCurrent(null);
            continue :blk processInitPhase();
        },
        .window_created => {
            glfw.makeContextCurrent(null);
            global_window.destroy();
            continue :blk processInitPhase();
        },
        .glfw_init => {
            glfw.terminate();
            continue :blk processInitPhase();
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

fn processInitPhase() InitPhase {
    init_phase = @enumFromInt(@intFromEnum(init_phase) - 1);
    return init_phase;
}

fn framebufferSizeCallback(_: *glfw.Window, width: c_int, height: c_int) callconv(.C) void {
    gl.Viewport(0, 0, width, height);
}
