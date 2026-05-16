const std = @import("std");
const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;
const Shader = common.Shader;
const Camera = common.Camera;
const zm = common.zmath;

// zig fmt: off
const vertices = [_]f32{
    // pos                normal
    -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
     0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
     0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
    -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,

    -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,
     0.5, -0.5,  0.5,  0.0,  0.0,  1.0,
     0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
    -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,

    -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,
    -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,
    -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,
    -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,

     0.5,  0.5,  0.5,  1.0,  0.0,  0.0,
     0.5,  0.5, -0.5,  1.0,  0.0,  0.0,
     0.5, -0.5, -0.5,  1.0,  0.0,  0.0,
     0.5, -0.5,  0.5,  1.0,  0.0,  0.0,

    -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
     0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
     0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
    -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,

    -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
     0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
     0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
    -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
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
    \\layout (location = 1) in vec3 aNormal;
    \\
    \\uniform mat4 model;
    \\uniform mat4 view;
    \\uniform mat4 projection;
    \\
    \\out vec3 Normal;
    \\out vec3 FragPos;
    \\
    \\void main() {
    \\  gl_Position = projection * view * model * vec4(aPos, 1.0);
    \\  Normal = aNormal;
    \\  FragPos = vec3(model * vec4(aPos, 1.0));
    \\}
    \\
;

const fragment_shader_source =
    \\#version 330 core
    \\struct Material {
    \\  vec3 ambient;
    \\  vec3 diffuse;
    \\  vec3 specular;
    \\  float shininess;
    \\};
    \\
    \\struct Light {
    \\  vec3 position;
    \\
    \\  vec3 ambient;
    \\  vec3 diffuse;
    \\  vec3 specular;
    \\};
    \\
    \\in vec3 Normal;
    \\in vec3 FragPos;
    \\
    \\out vec4 FragColor;
    \\
    \\uniform vec3 viewPos;
    \\uniform Material material;
    \\uniform Light light;
    \\
    \\void main() {
    \\  // ambient
    \\  vec3 ambient = light.ambient * material.ambient;
    \\
    \\  // diffuse
    \\  vec3 norm = normalize(Normal);
    \\  vec3 lightDir = normalize(light.position - FragPos);
    \\  float diff = max(dot(norm, lightDir), 0.0);
    \\  vec3 diffuse = light.diffuse * (diff * material.diffuse);
    \\
    \\  // specular
    \\  vec3 viewDir = normalize(viewPos - FragPos);
    \\  vec3 reflectDir = reflect(-lightDir, norm);
    \\  float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    \\  vec3 specular = light.specular * (spec * material.specular);
    \\
    \\  vec3 result = ambient + diffuse + specular;
    \\  FragColor = vec4(result, 1.0);
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

const Material = struct {
    ambient: zm.Vec,
    diffuse: zm.Vec,
    specular: zm.Vec,
    shininess: f32,
};

// zig fmt: off
const material_list = [_]struct { []const u8, Material }{
    .{ "default",        .{ .ambient = zm.f32x4(1.0,      0.5,      0.31,     0), .diffuse = zm.f32x4(1.0,      0.5,      0.31,     0), .specular = zm.f32x4(0.5,      0.5,      0.5,      0), .shininess = 32.0        } },
    .{ "emerald",        .{ .ambient = zm.f32x4(0.0215,   0.1745,   0.0215,   0), .diffuse = zm.f32x4(0.07568,  0.61424,  0.07568,  0), .specular = zm.f32x4(0.633,    0.727811, 0.633,    0), .shininess = 76.8        } },
    .{ "jade",           .{ .ambient = zm.f32x4(0.135,    0.2225,   0.1575,   0), .diffuse = zm.f32x4(0.54,     0.89,     0.63,     0), .specular = zm.f32x4(0.316228, 0.316228, 0.316228, 0), .shininess = 12.8        } },
    .{ "obsidian",       .{ .ambient = zm.f32x4(0.05375,  0.05,     0.06625,  0), .diffuse = zm.f32x4(0.18275,  0.17,     0.22525,  0), .specular = zm.f32x4(0.332741, 0.328634, 0.346435, 0), .shininess = 38.4        } },
    .{ "pearl",          .{ .ambient = zm.f32x4(0.25,     0.20725,  0.20725,  0), .diffuse = zm.f32x4(1.0,      0.829,    0.829,    0), .specular = zm.f32x4(0.296648, 0.296648, 0.296648, 0), .shininess = 11.264      } },
    .{ "ruby",           .{ .ambient = zm.f32x4(0.1745,   0.01175,  0.01175,  0), .diffuse = zm.f32x4(0.61424,  0.04136,  0.04136,  0), .specular = zm.f32x4(0.727811, 0.626959, 0.626959, 0), .shininess = 76.8        } },
    .{ "turquoise",      .{ .ambient = zm.f32x4(0.1,      0.18725,  0.1745,   0), .diffuse = zm.f32x4(0.396,    0.74151,  0.69102,  0), .specular = zm.f32x4(0.297254, 0.30829,  0.306678, 0), .shininess = 12.8        } },
    .{ "brass",          .{ .ambient = zm.f32x4(0.329412, 0.223529, 0.027451, 0), .diffuse = zm.f32x4(0.780392, 0.568627, 0.113725, 0), .specular = zm.f32x4(0.992157, 0.941176, 0.807843, 0), .shininess = 27.897      } },
    .{ "bronze",         .{ .ambient = zm.f32x4(0.2125,   0.1275,   0.054,    0), .diffuse = zm.f32x4(0.714,    0.4284,   0.18144,  0), .specular = zm.f32x4(0.393548, 0.271906, 0.166721, 0), .shininess = 25.6        } },
    .{ "chrome",         .{ .ambient = zm.f32x4(0.25,     0.25,     0.25,     0), .diffuse = zm.f32x4(0.4,      0.4,      0.4,      0), .specular = zm.f32x4(0.774597, 0.774597, 0.774597, 0), .shininess = 76.8        } },
    .{ "copper",         .{ .ambient = zm.f32x4(0.19125,  0.0735,   0.0225,   0), .diffuse = zm.f32x4(0.7038,   0.27048,  0.0828,   0), .specular = zm.f32x4(0.256777, 0.137622, 0.086014, 0), .shininess = 12.8        } },
    .{ "gold",           .{ .ambient = zm.f32x4(0.24725,  0.1995,   0.0745,   0), .diffuse = zm.f32x4(0.75164,  0.60648,  0.22648,  0), .specular = zm.f32x4(0.628281, 0.555802, 0.366065, 0), .shininess = 51.2        } },
    .{ "silver",         .{ .ambient = zm.f32x4(0.19225,  0.19225,  0.19225,  0), .diffuse = zm.f32x4(0.50754,  0.50754,  0.50754,  0), .specular = zm.f32x4(0.508273, 0.508273, 0.508273, 0), .shininess = 51.2        } },
    .{ "black plastic",  .{ .ambient = zm.f32x4(0.0,      0.0,      0.0,      0), .diffuse = zm.f32x4(0.01,     0.01,     0.01,     0), .specular = zm.f32x4(0.5,      0.5,      0.5,      0), .shininess = 32.0        } },
    .{ "cyan plastic",   .{ .ambient = zm.f32x4(0.0,      0.1,      0.06,     0), .diffuse = zm.f32x4(0.0,      0.50980,  0.50980,  0), .specular = zm.f32x4(0.50196,  0.50196,  0.50196,  0), .shininess = 32.0        } },
    .{ "green plastic",  .{ .ambient = zm.f32x4(0.0,      0.0,      0.0,      0), .diffuse = zm.f32x4(0.1,      0.35,     0.1,      0), .specular = zm.f32x4(0.45,     0.55,     0.45,     0), .shininess = 32.0        } },
    .{ "red plastic",    .{ .ambient = zm.f32x4(0.0,      0.0,      0.0,      0), .diffuse = zm.f32x4(0.5,      0.0,      0.0,      0), .specular = zm.f32x4(0.7,      0.6,      0.6,      0), .shininess = 32.0        } },
    .{ "white plastic",  .{ .ambient = zm.f32x4(0.0,      0.0,      0.0,      0), .diffuse = zm.f32x4(0.55,     0.55,     0.55,     0), .specular = zm.f32x4(0.7,      0.7,      0.7,      0), .shininess = 32.0        } },
    .{ "yellow plastic", .{ .ambient = zm.f32x4(0.0,      0.0,      0.0,      0), .diffuse = zm.f32x4(0.5,      0.5,      0.0,      0), .specular = zm.f32x4(0.6,      0.6,      0.5,      0), .shininess = 32.0        } },
    .{ "black rubber",   .{ .ambient = zm.f32x4(0.02,     0.02,     0.02,     0), .diffuse = zm.f32x4(0.01,     0.01,     0.01,     0), .specular = zm.f32x4(0.4,      0.4,      0.4,      0), .shininess = 10.0        } },
    .{ "cyan rubber",    .{ .ambient = zm.f32x4(0.0,      0.05,     0.05,     0), .diffuse = zm.f32x4(0.4,      0.5,      0.5,      0), .specular = zm.f32x4(0.04,     0.7,      0.7,      0), .shininess = 10.0        } },
    .{ "green rubber",   .{ .ambient = zm.f32x4(0.0,      0.05,     0.0,      0), .diffuse = zm.f32x4(0.4,      0.5,      0.4,      0), .specular = zm.f32x4(0.04,     0.7,      0.04,     0), .shininess = 10.0        } },
    .{ "red rubber",     .{ .ambient = zm.f32x4(0.05,     0.0,      0.0,      0), .diffuse = zm.f32x4(0.5,      0.4,      0.4,      0), .specular = zm.f32x4(0.7,      0.04,     0.04,     0), .shininess = 10.0        } },
    .{ "white rubber",   .{ .ambient = zm.f32x4(0.05,     0.05,     0.05,     0), .diffuse = zm.f32x4(0.5,      0.5,      0.5,      0), .specular = zm.f32x4(0.7,      0.7,      0.7,      0), .shininess = 10.0        } },
    .{ "yellow rubber",  .{ .ambient = zm.f32x4(0.05,     0.05,     0.0,      0), .diffuse = zm.f32x4(0.5,      0.5,      0.4,      0), .specular = zm.f32x4(0.7,      0.7,      0.04,     0), .shininess = 10.0        } },
};
// zig fmt: on

const material_map = std.StaticStringMap(Material).initComptime(&material_list);

pub fn main(init: std.process.Init) !void {
    const window = try sdl.Window.create(.{
        .title = "011 - Hello Materials",
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
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(1);
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), 3 * @sizeOf(f32));
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
        \\  P           - toggle light movement
        \\  L           - toggle full intensity vs cycling light color
        \\  [ / ]       - cycle materials ({d} available)
        \\  Escape      - quit
        \\
    , .{material_list.len});
    try stdout.flush();

    var last_ticks = sdl.c.SDL_GetTicks();
    var event: sdl.c.SDL_Event = undefined;
    var running = true;
    var light_moving = true;
    var light_time: f32 = 0.0;
    var light_full_intensity = false;
    var current_active_material_index: usize = 0;

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
                    if (event.key.scancode == sdl.c.SDL_SCANCODE_P) light_moving = !light_moving;
                    if (event.key.scancode == sdl.c.SDL_SCANCODE_L) {
                        light_full_intensity = !light_full_intensity;
                        stdout.print("light: {s}\n", .{if (light_full_intensity) "full intensity" else "cycling"}) catch {};
                        stdout.flush() catch {};
                    }
                    if (event.key.scancode == sdl.c.SDL_SCANCODE_RIGHTBRACKET) {
                        current_active_material_index = (current_active_material_index + 1) % material_list.len;
                        stdout.print("material: {s}\n", .{material_list[current_active_material_index][0]}) catch {};
                        stdout.flush() catch {};
                    }
                    if (event.key.scancode == sdl.c.SDL_SCANCODE_LEFTBRACKET) {
                        current_active_material_index = (current_active_material_index + material_list.len - 1) % material_list.len;
                        stdout.print("material: {s}\n", .{material_list[current_active_material_index][0]}) catch {};
                        stdout.flush() catch {};
                    }
                    _ = Camera.feedEvent(&input, &event);
                },
                else => if (Camera.feedEvent(&input, &event)) continue,
            }
        }

        Camera.feedKeyboard(&input);
        camera.update(input, delta_time);
        camera.applyCapture(window);

        if (light_moving) light_time += delta_time;

        gl.ClearColor(0.1, 0.1, 0.1, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const light_pos = zm.f32x4(
            1.0 + @sin(light_time) * 2.0,
            @sin(light_time / 2.0) * 1.0,
            2.0,
            1.0,
        );

        const light_color = if (light_full_intensity)
            zm.f32x4(1.0, 1.0, 1.0, 0.0)
        else
            zm.f32x4(
                @sin(light_time * 2.0),
                @sin(light_time * 0.7),
                @sin(light_time * 1.3),
                0.0,
            );
        const diffuse_color = light_color * zm.splat(zm.Vec, 0.5);
        const ambient_color = diffuse_color * zm.splat(zm.Vec, 0.2);

        {
            shader.use();
            defer gl.UseProgram(0);

            const pos = zm.identity();

            shader.setVec3("light.position", zm.vecToArr3(light_pos));
            shader.setVec3("light.ambient", zm.vecToArr3(ambient_color));
            shader.setVec3("light.diffuse", zm.vecToArr3(diffuse_color));
            shader.setVec3("light.specular", .{ 1.0, 1.0, 1.0 });

            const mat = material_list[current_active_material_index][1];
            shader.setVec3("material.ambient", zm.vecToArr3(mat.ambient));
            shader.setVec3("material.diffuse", zm.vecToArr3(mat.diffuse));
            shader.setVec3("material.specular", zm.vecToArr3(mat.specular));
            shader.setFloat("material.shininess", mat.shininess);

            shader.setMat4("model", &zm.matToArr(pos));
            camera.applyToShader(shader);

            gl.BindVertexArray(vao[0]);
            defer gl.BindVertexArray(0);

            gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
        }

        {
            light_shader.use();
            defer gl.UseProgram(0);

            const model = zm.mul(
                zm.scaling(0.2, 0.2, 0.2),
                zm.translationV(light_pos),
            );

            light_shader.setMat4("model", &zm.matToArr(model));
            light_shader.setVec3("lightColor", zm.vecToArr3(light_color));
            camera.applyToShader(light_shader);

            gl.BindVertexArray(vao[0]);
            defer gl.BindVertexArray(0);

            gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
        }

        window.swap();
    }
}
