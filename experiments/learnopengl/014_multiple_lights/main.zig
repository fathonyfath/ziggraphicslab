const std = @import("std");
const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;
const Shader = common.Shader;
const Texture = common.Texture;
const Camera = common.Camera;
const zm = common.zmath;

// zig fmt: off
const vertices = [_]f32{
    // pos             normal            texcoord
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 0.0,
     0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0, 1.0,
    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0, 1.0,

    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 0.0,
     0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 0.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0, 1.0,
    -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0, 1.0,

    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0, 0.0,
    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0, 1.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0, 1.0,
    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0, 0.0,

     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0, 1.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0, 1.0,
     0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0, 0.0,

    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0, 1.0,
     0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0, 1.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0, 0.0,
    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0, 0.0,

    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0, 1.0,
     0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0, 1.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0, 0.0,
    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0, 0.0,
};

const indices = [_]u32{
     0,  1,  2,   2,  3,  0,
     4,  5,  6,   6,  7,  4,
     8,  9, 10,  10, 11,  8,
    12, 13, 14,  14, 15, 12,
    16, 17, 18,  18, 19, 16,
    20, 21, 22,  22, 23, 20,
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

const point_light_positions = [_]zm.Vec{
    zm.f32x4(0.7, 0.2, 2.0, 0.0),
    zm.f32x4(2.3, -3.3, -4.0, 0.0),
    zm.f32x4(-4.0, 2.0, -12.0, 0.0),
    zm.f32x4(0.0, 0.0, -3.0, 0.0),
};
// zig fmt: on

const dir_light = DirectionalLight{
    .direction = zm.f32x4(-0.2, -1.0, -0.3, 0.0),
    .ambient = zm.f32x4(0.2, 0.2, 0.2, 0.0),
    .diffuse = zm.f32x4(0.5, 0.5, 0.5, 0.0),
    .specular = zm.f32x4(1.0, 1.0, 1.0, 0.0),
};

const point_lights = blk: {
    var lights: [point_light_positions.len]PointLight = undefined;
    for (&lights, point_light_positions) |*light, pos| {
        light.* = PointLight{
            .position = pos,
            .ambient = zm.f32x4(0.2, 0.2, 0.2, 0.0),
            .diffuse = zm.f32x4(0.5, 0.5, 0.5, 0.0),
            .specular = zm.f32x4(1.0, 1.0, 1.0, 0.0),
            .constant = 1.0,
            .linear = 0.09,
            .quadratic = 0.032,
        };
    }
    break :blk lights;
};

const Material = struct {
    diffuse: i32,
    specular: i32,
    shininess: f32,

    pub fn apply(self: Material, shader: Shader, comptime prefix: []const u8) void {
        shader.setInt(prefix ++ ".diffuse", self.diffuse);
        shader.setInt(prefix ++ ".specular", self.specular);
        shader.setFloat(prefix ++ ".shininess", self.shininess);
    }
};

const DirectionalLight = struct {
    direction: zm.Vec,

    ambient: zm.Vec,
    diffuse: zm.Vec,
    specular: zm.Vec,

    pub fn apply(self: DirectionalLight, shader: Shader, comptime prefix: []const u8) void {
        shader.setVec3(prefix ++ ".direction", zm.vecToArr3(self.direction));
        shader.setVec3(prefix ++ ".ambient", zm.vecToArr3(self.ambient));
        shader.setVec3(prefix ++ ".diffuse", zm.vecToArr3(self.diffuse));
        shader.setVec3(prefix ++ ".specular", zm.vecToArr3(self.specular));
    }
};

const PointLight = struct {
    position: zm.Vec,

    ambient: zm.Vec,
    diffuse: zm.Vec,
    specular: zm.Vec,

    constant: f32,
    linear: f32,
    quadratic: f32,

    pub fn apply(self: PointLight, shader: Shader, comptime prefix: []const u8) void {
        shader.setVec3(prefix ++ ".position", zm.vecToArr3(self.position));
        shader.setVec3(prefix ++ ".ambient", zm.vecToArr3(self.ambient));
        shader.setVec3(prefix ++ ".diffuse", zm.vecToArr3(self.diffuse));
        shader.setVec3(prefix ++ ".specular", zm.vecToArr3(self.specular));
        shader.setFloat(prefix ++ ".constant", self.constant);
        shader.setFloat(prefix ++ ".linear", self.linear);
        shader.setFloat(prefix ++ ".quadratic", self.quadratic);
    }
};

const SpotLight = struct {
    position: zm.Vec,
    direction: zm.Vec,
    cut_off: f32,
    outer_cut_off: f32,

    ambient: zm.Vec,
    diffuse: zm.Vec,
    specular: zm.Vec,

    constant: f32,
    linear: f32,
    quadratic: f32,

    pub fn apply(self: SpotLight, shader: Shader, comptime prefix: []const u8) void {
        shader.setVec3(prefix ++ ".position", zm.vecToArr3(self.position));
        shader.setVec3(prefix ++ ".direction", zm.vecToArr3(self.direction));
        shader.setFloat(prefix ++ ".cutOff", self.cut_off);
        shader.setFloat(prefix ++ ".outerCutOff", self.outer_cut_off);
        shader.setVec3(prefix ++ ".ambient", zm.vecToArr3(self.ambient));
        shader.setVec3(prefix ++ ".diffuse", zm.vecToArr3(self.diffuse));
        shader.setVec3(prefix ++ ".specular", zm.vecToArr3(self.specular));
        shader.setFloat(prefix ++ ".constant", self.constant);
        shader.setFloat(prefix ++ ".linear", self.linear);
        shader.setFloat(prefix ++ ".quadratic", self.quadratic);
    }
};

const vertex_shader_source =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aNormal;
    \\layout (location = 2) in vec2 aTexCoords;
    \\
    \\uniform mat4 model;
    \\uniform mat4 view;
    \\uniform mat4 projection;
    \\
    \\out vec3 Normal;
    \\out vec2 TexCoords;
    \\out vec3 FragPos;
    \\
    \\void main() {
    \\  FragPos = vec3(model * vec4(aPos, 1.0));
    \\  Normal = mat3(transpose(inverse(model))) * aNormal;
    \\  TexCoords = aTexCoords;
    \\  gl_Position = projection * view * vec4(FragPos, 1.0);
    \\}
    \\
;

const fragment_light_shader_source =
    \\#version 330 core
    \\out vec4 FragColor;
    \\
    \\uniform vec3 lightColor;
    \\
    \\void main() {
    \\  FragColor = vec4(lightColor, 1.0);
    \\}
    \\
;

pub fn main(init: std.process.Init) !void {
    const stbi = @import("stbi");
    stbi.init(init.io, init.gpa);
    defer stbi.deinit();

    stbi.setFlipVerticallyOnLoad(true);

    const window = try sdl.Window.create(.{
        .title = "014 - Multiple Lights",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    const container_texture = try Texture.loadFromMemory(common.assets.container2_png);
    defer container_texture.delete();

    const container_specular_texture = try Texture.loadFromMemory(common.assets.container2_specular_png);
    defer container_specular_texture.delete();

    _ = sdl.c.SDL_SetWindowRelativeMouseMode(window.handle, true);

    const object_shader = try Shader.create(
        vertex_shader_source,
        common.assets.multiple_lights_fragment_shader_frag,
        null,
    );
    defer object_shader.delete();

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
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(1);
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
        gl.EnableVertexAttribArray(2);
        gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 6 * @sizeOf(f32));
    }

    gl.Enable(gl.DEPTH_TEST);

    var camera = Camera.init(.{ 0.0, 0.0, 3.0 }, 800.0 / 600.0);

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        \\Controls:
        \\  WASD        - move camera
        \\  Mouse       - look around
        \\  Scroll      - zoom
        \\  Space       - toggle mouse capture
        \\  Escape      - quit
        \\
    , .{});
    try stdout.flush();

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
                    _ = Camera.feedEvent(&input, &event);
                },
                else => if (Camera.feedEvent(&input, &event)) continue,
            }
        }

        Camera.feedKeyboard(&input);
        camera.update(input, delta_time);
        camera.applyCapture(window);

        gl.ClearColor(0.1, 0.1, 0.1, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        {
            object_shader.use();
            defer gl.UseProgram(0);

            dir_light.apply(object_shader, "directionalLight");

            inline for (point_lights, 0..) |point_light, i| {
                point_light.apply(object_shader, std.fmt.comptimePrint("pointLights[{}]", .{i}));
            }

            const spot_light = SpotLight{
                .position = camera.position,
                .direction = camera.front,
                .cut_off = @cos(std.math.degreesToRadians(12.5)),
                .outer_cut_off = @cos(std.math.degreesToRadians(17.5)),
                .ambient = zm.f32x4(0.0, 0.0, 0.0, 0.0),
                .diffuse = zm.f32x4(1.0, 1.0, 1.0, 0.0),
                .specular = zm.f32x4(1.0, 1.0, 1.0, 0.0),
                .constant = 1.0,
                .linear = 0.09,
                .quadratic = 0.032,
            };
            spot_light.apply(object_shader, "spotLight");

            const material = Material{ .diffuse = 0, .specular = 1, .shininess = 32.0 };
            material.apply(object_shader, "material");
            camera.applyToShader(object_shader);

            container_texture.bind(gl.TEXTURE0);
            container_specular_texture.bind(gl.TEXTURE1);

            gl.BindVertexArray(vao[0]);
            defer gl.BindVertexArray(0);

            inline for (cube_positions, 0..) |pos, idx| {
                const angle = std.math.degreesToRadians(@as(f32, @floatFromInt(idx)) * 20.0);
                const model = zm.mul(
                    zm.matFromAxisAngle(zm.f32x4(1.0, 0.3, 0.5, 0.0), angle),
                    zm.translation(pos[0], pos[1], pos[2]),
                );
                var model_arr = zm.matToArr(model);
                object_shader.setMat4("model", &model_arr);
                gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
            }
        }

        {
            light_shader.use();
            defer gl.UseProgram(0);

            light_shader.setVec3("lightColor", .{ 1.0, 1.0, 1.0 });
            camera.applyToShader(light_shader);

            gl.BindVertexArray(vao[0]);
            defer gl.BindVertexArray(0);

            inline for (point_light_positions) |pos| {
                const model = zm.mul(
                    zm.scaling(0.2, 0.2, 0.2),
                    zm.translationV(pos),
                );
                light_shader.setMat4("model", &zm.matToArr(model));
                gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
            }
        }

        window.swap();
    }
}
