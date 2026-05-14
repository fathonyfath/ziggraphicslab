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
    // positions        // colors           // texture coords
     0.5,  0.5, 0.0,   1.0, 0.0, 0.0,     1.0, 1.0, // top right
     0.5, -0.5, 0.0,   0.0, 1.0, 0.0,     1.0, 0.0, // bottom right
    -0.5, -0.5, 0.0,   0.0, 0.0, 1.0,     0.0, 0.0, // bottom left
    -0.5,  0.5, 0.0,   1.0, 1.0, 0.0,     0.0, 1.0, // top left
};
// zig fmt: on

const indices = [_]u32{
    0, 1, 3,
    1, 2, 3,
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
    \\uniform mat4 transform;
    \\
    \\void main() {
    \\  gl_Position = transform * vec4(aPos, 1.0);
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
    \\  FragColor = mix(texture(texture0, ourTexCoord), texture(texture1, ourTexCoord), 0.2);
    \\}
    \\
;

pub fn main(init: std.process.Init) !void {
    stbi.init(init.io, init.gpa);
    defer stbi.deinit();

    stbi.setFlipVerticallyOnLoad(true);

    const window = try sdl.Window.create(.{
        .title = "006 - Hello Transformations",
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

    var vbo: [1]gl.uint = undefined;
    {
        gl.GenBuffers(1, &vbo);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo[0]);
        defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);
    }

    var ebo: [1]gl.uint = undefined;
    {
        gl.GenBuffers(1, &ebo);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo[0]);
        defer gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);
    }

    var vao: [1]gl.uint = undefined;
    {
        gl.GenVertexArrays(1, &vao);
        gl.BindVertexArray(vao[0]);
        defer gl.BindVertexArray(0);
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo[0]);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo[0]);
        defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);
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

        shader.use();
        defer gl.UseProgram(0);

        const time: f32 = @as(f32, @floatFromInt(sdl.c.SDL_GetTicks())) / 1000.0;
        const transform = zm.mul(
            zm.rotationZ(time),
            zm.translation(0.5, -0.5, 0.0),
        );
        var transform_arr = zm.matToArr(transform);
        shader.setMat4("transform", &transform_arr);

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, container_texture);
        gl.ActiveTexture(gl.TEXTURE1);
        gl.BindTexture(gl.TEXTURE_2D, awesomeface_texture);

        gl.BindVertexArray(vao[0]);
        defer gl.BindVertexArray(0);

        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);

        window.swap();
    }
}
