const std = @import("std");
const window = @import("window");
const glfw = window.glfw;
const gl = window.gl;

pub fn main() !void {
    try window.create(.{ .width = 800, .height = 600, .title = "LearnOpenGL" });
    defer window.destroy();

    glfw.swapInterval(1);

    const shader_program: gl.uint = blk: {
        const vertex_shader_source: []const u8 =
            \\#version 330 core
            \\layout (location=0) in vec3 aPos;
            \\
            \\void main() {
            \\  gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
            \\}
            \\
        ;
        const vertex_shader_sources: []const [*]const u8 = &[_][*]const u8{vertex_shader_source.ptr};

        const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
        gl.ShaderSource(vertex_shader, vertex_shader_sources.len, vertex_shader_sources.ptr, null);
        gl.CompileShader(vertex_shader);

        const fragment_shader_source: []const u8 =
            \\#version 330 core
            \\out vec4 FragColor;
            \\
            \\void main() {
            \\  FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
            \\}
            \\
        ;
        const fragment_shader_sources: []const [*]const u8 = &[_][*]const u8{fragment_shader_source.ptr};

        const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
        gl.ShaderSource(fragment_shader, fragment_shader_sources.len, fragment_shader_sources.ptr, null);
        gl.CompileShader(fragment_shader);

        const shader_program = gl.CreateProgram();

        gl.AttachShader(shader_program, vertex_shader);
        defer gl.DeleteShader(vertex_shader);

        gl.AttachShader(shader_program, fragment_shader);
        defer gl.DeleteShader(fragment_shader);

        gl.LinkProgram(shader_program);
        break :blk shader_program;
    };

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

        gl.BindBuffer(gl.ARRAY_BUFFER, vbos[0]);
        defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    }

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        {
            gl.UseProgram(shader_program);
            defer gl.UseProgram(shader_program);

            gl.BindVertexArray(vaos[0]);
            defer gl.BindVertexArray(0);

            gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);
        }

        glfw.pollEvents();
        window.swapBuffers();
    }
}
