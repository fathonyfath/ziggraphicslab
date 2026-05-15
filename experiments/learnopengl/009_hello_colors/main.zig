const std = @import("std");
const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;
const Shader = common.Shader;
const Camera = common.Camera;
const zm = common.zmath;

// zig fmt: off
const vertices = [_]f32{
    -0.5, -0.5, -0.5,
     0.5, -0.5, -0.5,
     0.5,  0.5, -0.5,
    -0.5,  0.5, -0.5,

    -0.5, -0.5,  0.5,
     0.5, -0.5,  0.5,
     0.5,  0.5,  0.5,
    -0.5,  0.5,  0.5,

    -0.5,  0.5,  0.5,
    -0.5,  0.5, -0.5,
    -0.5, -0.5, -0.5,
    -0.5, -0.5,  0.5,

     0.5,  0.5,  0.5,
     0.5,  0.5, -0.5,
     0.5, -0.5, -0.5,
     0.5, -0.5,  0.5,

    -0.5, -0.5, -0.5,
     0.5, -0.5, -0.5,
     0.5, -0.5,  0.5,
    -0.5, -0.5,  0.5,

    -0.5,  0.5, -0.5,
     0.5,  0.5, -0.5,
     0.5,  0.5,  0.5,
    -0.5,  0.5,  0.5,
};

const indices = [_]u32{
     0,  1,  2,   2,  3,  0,
     4,  5,  6,   6,  7,  4,
     8,  9, 10,  10, 11,  8,
    12, 13, 14,  14, 15, 12,
    16, 17, 18,  18, 19, 16,
    20, 21, 22,  22, 23, 20,
};
// zig fmt: on

const vertex_shader_source =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\
    \\uniform mat4 model;
    \\uniform mat4 view;
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\  gl_Position = projection * view * model * vec4(aPos, 1.0);
    \\}
    \\
;

const fragment_shader_source =
    \\#version 330 core
    \\out vec4 FragColor;
    \\
    \\uniform vec3 objectColor;
    \\uniform vec3 lightColor;
    \\
    \\void main() {
    \\  FragColor = vec4(objectColor * lightColor, 1.0);
    \\}
    \\
;

const fragment_light_shader_source =
    \\#version 330 core
    \\out vec4 FragColor;
    \\
    \\void main() {
    \\  FragColor = vec4(1.0);
    \\}
    \\
;

pub fn main(init: std.process.Init) !void {
    _ = init;

    const window = try sdl.Window.create(.{
        .title = "009 - Hello Colors",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    _ = sdl.c.SDL_SetWindowRelativeMouseMode(window.handle, true);

    const shader = try Shader.create(
        vertex_shader_source,
        fragment_shader_source,
        null,
    );
    defer shader.delete();

    const light_shader = try Shader.create(
        vertex_shader_source,
        fragment_light_shader_source,
        null,
    );
    defer light_shader.delete();

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

    var light_vao: [1]gl.uint = undefined;
    {
        var vbo: [1]gl.uint = undefined;
        var ebo: [1]gl.uint = undefined;

        gl.GenBuffers(1, &vbo);
        gl.GenBuffers(1, &ebo);
        gl.GenVertexArrays(1, &light_vao);

        gl.BindVertexArray(light_vao[0]);
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

    gl.Enable(gl.DEPTH_TEST);

    var camera = Camera.init(.{ 0.0, 0.0, 3.0 }, 800.0 / 600.0);

    var last_ticks = sdl.c.SDL_GetTicks();
    var event: sdl.c.SDL_Event = undefined;
    var running = true;

    while (running) {
        const current_ticks = sdl.c.SDL_GetTicks();
        const delta_time: f32 = @as(f32, @floatFromInt(current_ticks - last_ticks)) / 1000.0;
        last_ticks = current_ticks;

        var input = Camera.CameraInput{};

        while (sdl.c.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.c.SDL_EVENT_QUIT => running = false,
                sdl.c.SDL_EVENT_KEY_DOWN => {
                    if (event.key.scancode == sdl.c.SDL_SCANCODE_ESCAPE) running = false;
                },
                else => if (Camera.feedEvent(&input, &event)) continue,
            }
        }

        Camera.feedKeyboard(&input);
        camera.update(input, delta_time);

        gl.ClearColor(0.1, 0.1, 0.1, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        {
            shader.use();
            defer gl.UseProgram(0);

            const pos = zm.identity();
            // This should match what the object color is.
            const object_color = zm.f32x4(1.0, 0.5, 0.31, 0.0);
            // This should match what the light shader emit.
            const light_color = zm.f32x4(1.0, 1.0, 1.0, 0.0);

            shader.setVec3("objectColor", zm.vecToArr3(object_color));
            shader.setVec3("lightColor", zm.vecToArr3(light_color));

            shader.setMat4("model", &zm.matToArr(pos));
            camera.applyToShader(shader);

            gl.BindVertexArray(vao[0]);
            defer gl.BindVertexArray(0);

            gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
        }

        {
            light_shader.use();
            defer gl.UseProgram(0);

            const light_pos = zm.f32x4(1.2, 1.0, 2.0, 0.0);
            const model = zm.mul(
                zm.scaling(0.2, 0.2, 0.2),
                zm.translationV(light_pos),
            );

            light_shader.setMat4("model", &zm.matToArr(model));
            camera.applyToShader(light_shader);

            gl.BindVertexArray(light_vao[0]);
            defer gl.BindVertexArray(0);

            gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
        }

        window.swap();
    }
}
