const window = @import("opengl_common").window;
const glfw = window.glfw;
const gl = window.gl;

pub fn main() !void {
    try window.create(.{
        .width = 800,
        .height = 600,
        .title = "OpenGL",
        .opengl_profile = .compatibility,
    });
    defer window.destroy();

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == .press) {
            window.setShouldClose(true);
        }

        glfw.pollEvents();
        window.swapBuffers();
    }
}
