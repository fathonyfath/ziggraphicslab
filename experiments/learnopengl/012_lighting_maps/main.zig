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
// zig fmt: on

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
    \\  gl_Position = projection * view * model * vec4(aPos, 1.0);
    \\  Normal = aNormal;
    \\  TexCoords = aTexCoords;
    \\  FragPos = vec3(model * vec4(aPos, 1.0));
    \\}
    \\
;

const fragment_shader_source =
    \\#version 330 core
    \\struct Material {
    \\  sampler2D diffuse;
    \\  sampler2D specular;
    \\  sampler2D emission;
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
    \\in vec2 TexCoords;
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
    \\  vec3 ambient = light.ambient * vec3(texture(material.diffuse, TexCoords));
    \\
    \\  // diffuse
    \\  vec3 norm = normalize(Normal);
    \\  vec3 lightDir = normalize(light.position - FragPos);
    \\  float diff = max(dot(norm, lightDir), 0.0);
    \\  vec3 diffuse = light.diffuse * diff * vec3(texture(material.diffuse, TexCoords));
    \\
    \\  // specular
    \\  vec3 viewDir = normalize(viewPos - FragPos);
    \\  vec3 reflectDir = reflect(-lightDir, norm);
    \\  float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    \\  vec3 specular = light.specular * spec * vec3(texture(material.specular, TexCoords));
    \\
    \\  // emission
    \\  vec3 specularSample = vec3(texture(material.specular, TexCoords));
    \\  vec3 emission = texture(material.emission, TexCoords).rgb * (vec3(1.0) - step(vec3(0.1), specularSample));
    \\
    \\  vec3 result = ambient + diffuse + specular + emission;
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

pub fn main(init: std.process.Init) !void {
    const stbi = @import("stbi");
    stbi.init(init.io, init.gpa);
    defer stbi.deinit();

    stbi.setFlipVerticallyOnLoad(true);

    const window = try sdl.Window.create(.{
        .title = "012 - Lighting Maps",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    const container_texture = try Texture.loadFromMemory(common.assets.container2_png);
    defer container_texture.delete();

    const container_specular_texture = try Texture.loadFromMemory(common.assets.container2_specular_png);
    defer container_specular_texture.delete();

    const matrix_texture = try Texture.loadFromMemory(common.assets.matrix_jpg);
    defer matrix_texture.delete();

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
        \\  P           - toggle light movement
        \\  Escape      - quit
        \\
    , .{});
    try stdout.flush();

    var last_ticks = sdl.c.SDL_GetTicks();
    var event: sdl.c.SDL_Event = undefined;
    var running = true;
    var light_moving = true;
    var light_time: f32 = 0.0;

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

        const light_color = zm.f32x4(1.0, 1.0, 1.0, 0.0);
        const diffuse_color = light_color * zm.splat(zm.Vec, 0.5);
        const ambient_color = light_color * zm.splat(zm.Vec, 0.2);

        {
            shader.use();
            defer gl.UseProgram(0);

            const pos = zm.identity();

            shader.setVec3("light.position", zm.vecToArr3(light_pos));
            shader.setVec3("light.ambient", zm.vecToArr3(ambient_color));
            shader.setVec3("light.diffuse", zm.vecToArr3(diffuse_color));
            shader.setVec3("light.specular", .{ 1.0, 1.0, 1.0 });

            shader.setInt("material.diffuse", 0);
            shader.setInt("material.specular", 1);
            shader.setInt("material.emission", 2);
            shader.setFloat("material.shininess", 64.0);

            shader.setMat4("model", &zm.matToArr(pos));
            camera.applyToShader(shader);

            container_texture.bind(gl.TEXTURE0);
            container_specular_texture.bind(gl.TEXTURE1);
            matrix_texture.bind(gl.TEXTURE2);

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
