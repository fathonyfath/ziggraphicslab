const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;

pub fn main() !void {
    const window = try sdl.Window.create(.{
        .title = "001 - Hello Window",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    var event: sdl.c.SDL_Event = undefined;
    var running = true;

    while (running) {
        while (sdl.c.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.c.SDL_EVENT_QUIT => running = false,
                sdl.c.SDL_EVENT_KEY_DOWN => {
                    if (event.key.scancode == sdl.c.SDL_SCANCODE_ESCAPE) running = false;
                },
                else => {},
            }
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        window.swap();
    }
}
