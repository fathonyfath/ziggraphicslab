const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;
const Shader = common.Shader;

const vertex_shader_source =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aColor;
    \\
    \\out vec3 ourColor;
    \\
    \\void main() {
    \\  gl_Position = vec4(aPos, 1.0);
    \\  ourColor = aColor;
    \\}
    \\
;

const fragment_shader_source =
    \\#version 330 core
    \\in vec3 ourColor;
    \\
    \\out vec4 FragColor;
    \\
    \\void main() {
    \\  FragColor = vec4(ourColor, 1.0);
    \\}
    \\
;

const vertices = [_]f32{
    0.5, -0.5, 0.0, 1.0, 0.0, 0.0, // bottom right
    -0.5, -0.5, 0.0, 0.0, 1.0, 0.0, // bottom left
    0.0, 0.5, 0.0, 0.0, 0.0, 1.0, // top
};

pub fn main() !void {
    const window = try sdl.Window.create(.{
        .title = "003 - Hello Shaders",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    const shader = try Shader.create(vertex_shader_source, fragment_shader_source, null);
    defer shader.delete();

    var vao: [1]gl.uint = undefined;
    {
        var vbo: [1]gl.uint = undefined;
        gl.GenBuffers(1, &vbo);
        gl.GenVertexArrays(1, &vao);
        gl.BindVertexArray(vao[0]);
        defer {
            gl.BindVertexArray(0);
            gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        }

        gl.BindBuffer(gl.ARRAY_BUFFER, vbo[0]);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(1);
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), 3 * @sizeOf(f32));
    }

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

        {
            shader.use();
            defer gl.UseProgram(0);
            gl.BindVertexArray(vao[0]);
            defer gl.BindVertexArray(0);
            gl.DrawArrays(gl.TRIANGLES, 0, 3);
        }

        window.swap();
    }
}
