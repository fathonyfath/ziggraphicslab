const std = @import("std");
const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;
const Shader = common.Shader;
const zm = common.zmath;
const stbi = @import("stbi");

const container_texture_content = common.assets.container_jpg;
const awesomeface_texture_content = common.assets.awesomeface_png;

// zig fmt: off
const vertices = [_]f32{
    // positions          // colors           // texture coords
    // back
     0.5,  0.5, -0.5,    1.0, 1.0, 1.0,     1.0, 1.0,
     0.5, -0.5, -0.5,    1.0, 1.0, 1.0,     1.0, 0.0,
    -0.5, -0.5, -0.5,    1.0, 1.0, 1.0,     0.0, 0.0,
    -0.5,  0.5, -0.5,    1.0, 1.0, 1.0,     0.0, 1.0,
    // front
     0.5,  0.5,  0.5,    1.0, 1.0, 1.0,     1.0, 1.0,
     0.5, -0.5,  0.5,    1.0, 1.0, 1.0,     1.0, 0.0,
    -0.5, -0.5,  0.5,    1.0, 1.0, 1.0,     0.0, 0.0,
    -0.5,  0.5,  0.5,    1.0, 1.0, 1.0,     0.0, 1.0,
    // left
    -0.5,  0.5,  0.5,    1.0, 1.0, 1.0,     1.0, 1.0,
    -0.5,  0.5, -0.5,    1.0, 1.0, 1.0,     1.0, 0.0,
    -0.5, -0.5, -0.5,    1.0, 1.0, 1.0,     0.0, 0.0,
    -0.5, -0.5,  0.5,    1.0, 1.0, 1.0,     0.0, 1.0,
    // right
     0.5,  0.5,  0.5,    1.0, 1.0, 1.0,     1.0, 1.0,
     0.5,  0.5, -0.5,    1.0, 1.0, 1.0,     1.0, 0.0,
     0.5, -0.5, -0.5,    1.0, 1.0, 1.0,     0.0, 0.0,
     0.5, -0.5,  0.5,    1.0, 1.0, 1.0,     0.0, 1.0,
    // bottom
     0.5, -0.5,  0.5,    1.0, 1.0, 1.0,     1.0, 1.0,
     0.5, -0.5, -0.5,    1.0, 1.0, 1.0,     1.0, 0.0,
    -0.5, -0.5, -0.5,    1.0, 1.0, 1.0,     0.0, 0.0,
    -0.5, -0.5,  0.5,    1.0, 1.0, 1.0,     0.0, 1.0,
    // top
     0.5,  0.5,  0.5,    1.0, 1.0, 1.0,     1.0, 1.0,
     0.5,  0.5, -0.5,    1.0, 1.0, 1.0,     1.0, 0.0,
    -0.5,  0.5, -0.5,    1.0, 1.0, 1.0,     0.0, 0.0,
    -0.5,  0.5,  0.5,    1.0, 1.0, 1.0,     0.0, 1.0,
};
// zig fmt: on

const indices = [_]u32{
    0, 1, 3, 1, 2, 3, // back
    4, 5, 7, 5, 6, 7, // front
    8, 9, 11, 9, 10, 11, // left
    12, 13, 15, 13, 14, 15, // right
    16, 17, 19, 17, 18, 19, // bottom
    20, 21, 23, 21, 22, 23, // top
};

const cube_positions = [_][3]f32{
    .{ 0.0, 0.0, 0.0 },
    .{ 2.0, 5.0, -15.0 },
    .{ -1.5, -2.2, -2.5 },
    .{ -3.8, -2.0, -12.3 },
    .{ 2.4, -0.4, -3.5 },
    .{ -1.7, 3.0, -7.5 },
    .{ 1.3, -2.0, -2.5 },
    .{ 1.5, 2.0, -2.5 },
    .{ 1.5, 0.2, -1.5 },
    .{ -1.3, 1.0, -1.5 },
};

const vertex_shader_source =
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

const fragment_shader_source =
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

pub fn main(init: std.process.Init) !void {
    stbi.init(init.io, init.gpa);
    defer stbi.deinit();

    stbi.setFlipVerticallyOnLoad(true);

    const window = try sdl.Window.create(.{
        .title = "007 - Hello Coordinates",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    const container_texture = blk: {
        var image = try stbi.Image.loadFromMemory(container_texture_content, 0);
        defer image.deinit();

        var textures: [1]gl.uint = undefined;
        gl.GenTextures(1, &textures);
        gl.BindTexture(gl.TEXTURE_2D, textures[0]);
        defer gl.BindTexture(gl.TEXTURE_2D, 0);
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image.width), @intCast(image.height), 0, gl.RGB, gl.UNSIGNED_BYTE, @ptrCast(image.data));
        gl.GenerateMipmap(gl.TEXTURE_2D);

        break :blk textures[0];
    };

    const awesomeface_texture = blk: {
        var image = try stbi.Image.loadFromMemory(awesomeface_texture_content, 0);
        defer image.deinit();

        var textures: [1]gl.uint = undefined;
        gl.GenTextures(1, &textures);
        gl.BindTexture(gl.TEXTURE_2D, textures[0]);
        defer gl.BindTexture(gl.TEXTURE_2D, 0);
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(image.width), @intCast(image.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, @ptrCast(image.data));
        gl.GenerateMipmap(gl.TEXTURE_2D);

        break :blk textures[0];
    };

    const shader = try Shader.create(vertex_shader_source, fragment_shader_source, null);
    defer shader.delete();

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
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(1);
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
        gl.EnableVertexAttribArray(2);
        gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 6 * @sizeOf(f32));
    }

    shader.use();
    shader.setInt("texture0", 0);
    shader.setInt("texture1", 1);

    var view_arr = zm.matToArr(zm.translation(0.0, 0.0, -3.0));
    var projection_arr = zm.matToArr(zm.perspectiveFovRhGl(std.math.degreesToRadians(45.0), 800.0 / 600.0, 0.1, 100.0));
    shader.setMat4("view", &view_arr);
    shader.setMat4("projection", &projection_arr);

    gl.Enable(gl.DEPTH_TEST);

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
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        shader.use();
        defer gl.UseProgram(0);

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, container_texture);
        gl.ActiveTexture(gl.TEXTURE1);
        gl.BindTexture(gl.TEXTURE_2D, awesomeface_texture);

        gl.BindVertexArray(vao[0]);
        defer gl.BindVertexArray(0);

        inline for (cube_positions, 0..) |pos, idx| {
            const angle = std.math.degreesToRadians(@as(f32, @floatFromInt(idx)) * 20.0);
            const model = zm.mul(
                zm.matFromAxisAngle(zm.f32x4(1.0, 0.3, 0.5, 0.0), angle),
                zm.translation(pos[0], pos[1], pos[2]),
            );
            var model_arr = zm.matToArr(model);
            shader.setMat4("model", &model_arr);
            gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
        }

        window.swap();
    }
}
