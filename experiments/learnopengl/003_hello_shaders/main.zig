const std = @import("std");
const window = @import("opengl_common").window;
const glfw = window.glfw;
const gl = window.gl;
const Shader = @import("opengl_common").Shader;

const vertex_shader_source: []const u8 =
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

const fragment_shader_source: []const u8 =
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

const indices = [_]u32{
    0, 1, 2,
};

pub fn main() !void {
    try window.create(.{
        .width = 800,
        .height = 600,
        .title = "Learn OpenGL",
    });
    defer window.destroy();

    const shader_program = try Shader.create(vertex_shader_source, fragment_shader_source);

    var vbos: [1]gl.uint = undefined;
    {
        gl.GenBuffers(vbos.len, &vbos);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbos[0]);
        defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);
    }

    var ebos: [1]gl.uint = undefined;
    {
        gl.GenBuffers(ebos.len, &ebos);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebos[0]);
        defer gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);
    }

    var vaos: [1]gl.uint = undefined;
    {
        gl.GenVertexArrays(vaos.len, &vaos);

        gl.BindVertexArray(vaos[0]);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebos[0]);
        defer {
            gl.BindVertexArray(0);
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
        }

        // bind array buffer
        {
            gl.BindBuffer(gl.ARRAY_BUFFER, vbos[0]);
            defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

            gl.EnableVertexAttribArray(0);
            gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), 0);

            gl.EnableVertexAttribArray(1);
            gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), 3 * @sizeOf(f32));
        }
    }

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == .press) {
            window.setShouldClose(true);
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        {
            shader_program.use();
            defer gl.UseProgram(0);

            gl.BindVertexArray(vaos[0]);
            defer gl.BindVertexArray(0);

            gl.DrawElements(gl.TRIANGLES, 3, gl.UNSIGNED_INT, 0);
        }

        glfw.pollEvents();
        window.swapBuffers();
    }
}
