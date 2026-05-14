const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;

const vertex_shader_source =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\
    \\void main() {
    \\  gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\}
    \\
;

const fragment_shader_source =
    \\#version 330 core
    \\out vec4 FragColor;
    \\
    \\void main() {
    \\  FragColor = vec4(1.0, 0.5, 0.2, 1.0);
    \\}
    \\
;

const vertices = [_]f32{
    0.5, 0.5, 0.0, // top right
    0.5, -0.5, 0.0, // bottom right
    -0.5, -0.5, 0.0, // bottom left
    -0.5, 0.5, 0.0, // top left
};

const indices = [_]u32{
    0, 1, 3, // first triangle
    1, 2, 3, // second triangle
};

pub fn main() !void {
    const window = try sdl.Window.create(.{
        .title = "003 - Hello Rectangle",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    const shader_program: gl.uint = blk: {
        const vs = gl.CreateShader(gl.VERTEX_SHADER);
        defer gl.DeleteShader(vs);
        gl.ShaderSource(vs, 1, &[_][*]const u8{vertex_shader_source}, null);
        gl.CompileShader(vs);

        const fs = gl.CreateShader(gl.FRAGMENT_SHADER);
        defer gl.DeleteShader(fs);
        gl.ShaderSource(fs, 1, &[_][*]const u8{fragment_shader_source}, null);
        gl.CompileShader(fs);

        const prog = gl.CreateProgram();
        gl.AttachShader(prog, vs);
        gl.AttachShader(prog, fs);
        gl.LinkProgram(prog);
        break :blk prog;
    };
    defer gl.DeleteProgram(shader_program);

    // VBO (Vertex Buffer Object): uploads raw vertex bytes to VRAM. At this point the GPU
    // treats it as an untyped blob — VertexAttribPointer (set up in the VAO) is what tells
    // the GPU how to interpret those bytes and map them to shader attribute slots.
    //
    // EBO (Element Buffer Object): stores indices into the VBO, so shared vertices aren't
    // duplicated. A rectangle needs 4 vertices but 6 index entries (2 triangles).
    //
    // VAO (Vertex Array Object): stores the VertexAttribPointer descriptions — which VBO id,
    // stride, offset, type, and size for each attribute slot — plus the bound EBO. Binding
    // the VAO at draw time restores all of that state, so you don't have to re-call
    // VertexAttribPointer before every draw.
    //
    // Unbind order matters: the EBO binding is stored as part of the VAO state, so unbinding
    // the EBO while the VAO is still bound would clear it from the VAO. The VAO is unbound
    // first in the defer block, making the subsequent EBO unbind safe.
    var vao: [1]gl.uint = undefined;
    {
        var vbo: [1]gl.uint = undefined;
        var ebo: [1]gl.uint = undefined;
        gl.GenBuffers(1, &vbo);
        gl.GenBuffers(1, &ebo);
        gl.GenVertexArrays(1, &vao);
        gl.BindVertexArray(vao[0]);
        defer {
            gl.BindVertexArray(0);
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
            gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        }

        gl.BindBuffer(gl.ARRAY_BUFFER, vbo[0]);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo[0]);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);

        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
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
            gl.UseProgram(shader_program);
            defer gl.UseProgram(0);
            gl.BindVertexArray(vao[0]);
            defer gl.BindVertexArray(0);
            gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);
        }

        window.swap();
    }
}
