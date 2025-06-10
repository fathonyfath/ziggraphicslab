const std = @import("std");
const opengl_common = @import("opengl_common");

const stbi = @import("stbi");
const window = opengl_common.window;
const glfw = window.glfw;
const gl = window.gl;

const Shader = opengl_common.Shader;

const zm = @import("zm");
const math = std.math;

const container_texture_content = @embedFile("container.jpg");
const awesomeface_texture_content = @embedFile("awesomeface.png");

// zig fmt: off
const vertices = [_]f32{
    // positions        // colors           // texture coords
    // back side
    0.5, 0.5, -0.5,     1.0, 1.0, 1.0,      1.0, 1.0,   // 0
    0.5, -0.5, -0.5,    1.0, 1.0, 1.0,      1.0, 0.0,   // 1
    -0.5, -0.5, -0.5,   1.0, 1.0, 1.0,      0.0, 0.0,   // 2
    -0.5, 0.5, -0.5,    1.0, 1.0, 1.0,      0.0, 1.0,   // 3

    // front side
    0.5, 0.5, 0.5,      1.0, 1.0, 1.0,      1.0, 1.0,   // 4
    0.5, -0.5, 0.5,     1.0, 1.0, 1.0,      1.0, 0.0,   // 5
    -0.5, -0.5, 0.5,    1.0, 1.0, 1.0,      0.0, 0.0,   // 6
    -0.5, 0.5, 0.5,     1.0, 1.0, 1.0,      0.0, 1.0,   // 7

    // left side
    -0.5, 0.5, 0.5,     1.0, 1.0, 1.0,      1.0, 1.0,   // 8
    -0.5, 0.5, -0.5,    1.0, 1.0, 1.0,      1.0, 0.0,   // 9
    -0.5, -0.5, -0.5,   1.0, 1.0, 1.0,      0.0, 0.0,   // 10
    -0.5, -0.5, 0.5,    1.0, 1.0, 1.0,      0.0, 1.0,   // 11

    // right side
    0.5, 0.5, 0.5,      1.0, 1.0, 1.0,      1.0, 1.0,   // 12
    0.5, 0.5, -0.5,     1.0, 1.0, 1.0,      1.0, 0.0,   // 13
    0.5, -0.5, -0.5,    1.0, 1.0, 1.0,      0.0, 0.0,   // 14
    0.5, -0.5, 0.5,     1.0, 1.0, 1.0,      0.0, 1.0,   // 15

    // bottom side
    0.5, -0.5, 0.5,     1.0, 1.0, 1.0,      1.0, 1.0,   // 16
    0.5, -0.5, -0.5,    1.0, 1.0, 1.0,      1.0, 0.0,   // 17
    -0.5, -0.5, -0.5,   1.0, 1.0, 1.0,      0.0, 0.0,   // 18
    -0.5, -0.5, 0.5,    1.0, 1.0, 1.0,      0.0, 1.0,   // 19

    // top side
    0.5, 0.5, 0.5,      1.0, 1.0, 1.0,      1.0, 1.0,   // 20
    0.5, 0.5, -0.5,     1.0, 1.0, 1.0,      1.0, 0.0,   // 21
    -0.5, 0.5, -0.5,    1.0, 1.0, 1.0,      0.0, 0.0,   // 22
    -0.5, 0.5, 0.5,     1.0, 1.0, 1.0,      0.0, 1.0,   // 23
};
// zig fmt: on

const indices = [_]i32{
    0, 1, 3, 1, 2, 3, // back
    4, 5, 7, 5, 6, 7, // front
    8, 9, 11, 9, 10, 11, // left
    12, 13, 15, 13, 14, 15, // right
    16, 17, 19, 17, 18, 19, // bottom
    20, 21, 23, 21, 22, 23, // top
};

const cube_positions = [_]zm.Vec3f{
    zm.Vec3f{ 0.0, 0.0, 0.0 },
    zm.Vec3f{ 2.0, 5.0, -15.0 },
    zm.Vec3f{ -1.5, -2.2, -2.5 },
    zm.Vec3f{ -3.8, -2.0, -12.3 },
    zm.Vec3f{ 2.4, -0.4, -3.5 },
    zm.Vec3f{ -1.7, 3.0, -7.5 },
    zm.Vec3f{ 1.3, -2.0, -2.5 },
    zm.Vec3f{ 1.5, 2.0, -2.5 },
    zm.Vec3f{ 1.5, 0.2, -1.5 },
    zm.Vec3f{ -1.3, 1.0, -1.5 },
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
    \\uniform mat4 model;
    \\uniform mat4 view;
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\  gl_Position = projection * view * model * vec4(aPos, 1.0);
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
    \\  FragColor = mix(texture(texture0, ourTexCoord), texture(texture1, ourTexCoord), 0.2) * vec4(ourColor, 1.0);
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

    const view = zm.Mat4f.translation(0.0, 0.0, -3.0);
    const projection = zm.Mat4f.perspective(math.degreesToRadians(45.0), 800.0 / 600.0, 0.1, 100.0);
    shader.setMat4f("view", view.data);
    shader.setMat4f("projection", projection.data);

    gl.Enable(gl.DEPTH_TEST);

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == .press) {
            window.setShouldClose(true);
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        shader.use();
        defer gl.UseProgram(0);

        {}

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, container_texture);

        gl.ActiveTexture(gl.TEXTURE1);
        gl.BindTexture(gl.TEXTURE_2D, awesomeface_texture);

        gl.BindVertexArray(vao);
        defer gl.BindVertexArray(0);

        inline for (cube_positions, 0..) |cube_position, idx| {
            const angle: f32 = (@as(f32, @floatFromInt(idx)) * 20.0) + @as(f32, @floatCast(glfw.getTime()));
            const model = zm.Mat4f.translationVec3(cube_position)
                .multiply(zm.Mat4f.rotation(zm.Vec3f{ 1.0, 0.0, 0.0 }, angle * 1.0))
                .multiply(zm.Mat4f.rotation(zm.Vec3f{ 0.0, 1.0, 0.0 }, angle * 0.3))
                .multiply(zm.Mat4f.rotation(zm.Vec3f{ 0.0, 0.0, 1.0 }, angle * 0.5));
            shader.setMat4f("model", model.data);
            gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
        }

        glfw.pollEvents();
        window.swapBuffers();
    }
}
