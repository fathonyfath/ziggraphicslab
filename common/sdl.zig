const gl = @import("gl");

pub const c = @import("sdl_c");

var gl_procs: gl.ProcTable = undefined;

pub const WindowConfig = struct {
    title: [:0]const u8,
    width: u32 = 800,
    height: u32 = 600,
    vsync: bool = true,
};

pub const Window = struct {
    handle: *c.SDL_Window,
    gl_context: c.SDL_GLContext,

    pub fn create(config: WindowConfig) !Window {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            return error.SDLInitFailed;
        }
        errdefer c.SDL_Quit();

        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 4);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 1);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);

        const handle = c.SDL_CreateWindow(
            config.title,
            @intCast(config.width),
            @intCast(config.height),
            c.SDL_WINDOW_OPENGL,
        ) orelse return error.CreateWindowFailed;
        errdefer c.SDL_DestroyWindow(handle);

        const gl_context = c.SDL_GL_CreateContext(handle) orelse return error.CreateContextFailed;
        errdefer _ = c.SDL_GL_DestroyContext(gl_context);

        if (!gl_procs.init(getProcAddress)) return error.LoadGLProcsFailed;
        gl.makeProcTableCurrent(&gl_procs);

        _ = c.SDL_GL_SetSwapInterval(if (config.vsync) 1 else 0);

        return .{ .handle = handle, .gl_context = gl_context };
    }

    pub fn destroy(self: Window) void {
        gl.makeProcTableCurrent(null);
        _ = c.SDL_GL_DestroyContext(self.gl_context);
        c.SDL_DestroyWindow(self.handle);
        c.SDL_Quit();
    }

    pub fn swap(self: Window) void {
        _ = c.SDL_GL_SwapWindow(self.handle);
    }
};

fn getProcAddress(name: [*:0]const u8) ?gl.PROC {
    return @ptrCast(@alignCast(c.SDL_GL_GetProcAddress(name)));
}
