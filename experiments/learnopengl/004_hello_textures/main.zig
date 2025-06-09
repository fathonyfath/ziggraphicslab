const std = @import("std");
const opengl_common = @import("opengl_common");
const stbi = @import("stbi");
const window = opengl_common.window;
const glfw = window.glfw;
const gl = window.gl;
const Shader = opengl_common.Shader;

const container_texture_content = @embedFile("container.jpg");
const awesomeface_texture_content = @embedFile("awesomeface.png");

// zig fmt: off
const vertices = [_]f32{
    // positions        // colors           // texture coords
    0.5, 0.5, 0.0,      1.0, 0.0, 0.0,      1.0, 1.0, // top right
    0.5, -0.5, 0.0,     0.0, 1.0, 0.0,      1.0, 0.0, // bottom right
    -0.5, -0.5, 0.0,    0.0, 0.0, 1.0,      0.0, 0.0, // bottom left
    -0.5, 0.5, 0.0,     1.0, 1.0, 0.0,      0.0, 1.0, // top left
};
// zig fmt: on

const indices = [_]i32{
    0, 1, 3, // first triangle
    1, 2, 3, // second triangle
};

const vertex_shader =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aColor;
    \\layout (location = 2) in vec2 aTexCoord;
    \\
    \\out vec3 ourColor;
    \\out vec2 ourTexCoord;
    \\
    \\void main() {
    \\  gl_Position = vec4(aPos, 1.0);
    \\  ourColor = aColor;
    \\  ourTexCoord = aTexCoord;
    \\}
    \\
;

const fragment_shader =
    \\#version 330 core
    \\in vec3 ourColor;
    \\in vec2 ourTexCoord;
    \\
    \\out vec4 FragColor;
    \\
    \\uniform sampler2D texture0;
    \\uniform sampler2D texture1;
    \\
    \\void main() {
    \\  FragColor = mix(texture(texture0, ourTexCoord), texture(texture1, ourTexCoord), 0.2);
    \\}
    \\
;

pub fn main() !void {
    try window.create(.{ .width = 800, .height = 600, .title = "Learn OpenGL" });
    defer window.destroy();

    stbi.init(std.heap.c_allocator);
    defer stbi.deinit();

    stbi.setFlipVerticallyOnLoad(true);

    const container_texture = blk: {
        var image = try stbi.Image.loadFromMemory(container_texture_content, 0);
        defer image.deinit();

        var textures: [1]gl.uint = undefined;
        gl.GenTextures(textures.len, &textures);

        gl.BindTexture(gl.TEXTURE_2D, textures[0]);
        defer gl.BindTexture(gl.TEXTURE_2D, 0);

        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            @intCast(image.width),
            @intCast(image.height),
            0,
            gl.RGB,
            gl.UNSIGNED_BYTE,
            @ptrCast(image.data),
        );
        gl.GenerateMipmap(gl.TEXTURE_2D);

        break :blk textures[0];
    };

    const awesomeface_texture = blk: {
        var image = try stbi.Image.loadFromMemory(awesomeface_texture_content, 0);
        defer image.deinit();

        var textures: [1]gl.uint = undefined;
        gl.GenTextures(textures.len, &textures);

        gl.BindTexture(gl.TEXTURE_2D, textures[0]);
        defer gl.BindTexture(gl.TEXTURE_2D, 0);

        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            @intCast(image.width),
            @intCast(image.height),
            0,
            gl.RGBA,
            gl.UNSIGNED_BYTE,
            @ptrCast(image.data),
        );
        gl.GenerateMipmap(gl.TEXTURE_2D);

        break :blk textures[0];
    };

    const shader = try Shader.create(vertex_shader, fragment_shader);

    const vbo = blk: {
        var vbos: [1]gl.uint = undefined;
        gl.GenBuffers(vbos.len, &vbos);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbos[0]);
        defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);
        break :blk vbos[0];
    };

    const ebo = blk: {
        var ebos: [1]gl.uint = undefined;
        gl.GenBuffers(ebos.len, &ebos);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebos[0]);
        defer gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);
        break :blk ebos[0];
    };

    const vao = blk: {
        var vaos: [1]gl.uint = undefined;
        gl.GenVertexArrays(vaos.len, &vaos);
        gl.BindVertexArray(vaos[0]);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);

        defer {
            gl.BindVertexArray(0);
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
        }

        gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
        defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(1);
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
        gl.EnableVertexAttribArray(2);
        gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 6 * @sizeOf(f32));

        break :blk vaos[0];
    };

    shader.use();
    shader.setInt("texture0", 0);
    shader.setInt("texture1", 1);

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == .press) {
            window.setShouldClose(true);
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        shader.use();
        defer gl.UseProgram(0);

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, container_texture);

        gl.ActiveTexture(gl.TEXTURE1);
        gl.BindTexture(gl.TEXTURE_2D, awesomeface_texture);

        gl.BindVertexArray(vao);
        defer gl.BindVertexArray(0);

        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);

        glfw.pollEvents();
        window.swapBuffers();
    }
}
