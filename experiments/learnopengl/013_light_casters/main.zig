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
    \\  FragPos = vec3(model * vec4(aPos, 1.0));
    \\  Normal = mat3(transpose(inverse(model))) * aNormal;
    \\  TexCoords = aTexCoords;
    \\  gl_Position = projection * view * vec4(FragPos, 1.0);
    \\}
    \\
;

const fragment_directional_light_shader_source =
    \\#version 330 core
    \\struct Material {
    \\  sampler2D diffuse;
    \\  sampler2D specular;
    \\  float shininess;
    \\};
    \\
    \\struct DirectionalLight {
    \\  vec3 direction;
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
    \\uniform DirectionalLight light;
    \\
    \\void main() {
    \\  vec3 lightDir = normalize(-light.direction);
    \\
    \\  // ambient
    \\  vec3 ambient = light.ambient * vec3(texture(material.diffuse, TexCoords)).rgb;
    \\
    \\  // diffuse
    \\  vec3 norm = normalize(Normal);
    \\  float diff = max(dot(norm, lightDir), 0.0);
    \\  vec3 diffuse = light.diffuse * diff * vec3(texture(material.diffuse, TexCoords)).rgb;
    \\
    \\  // specular
    \\  vec3 viewDir = normalize(viewPos - FragPos);
    \\  vec3 reflectDir = reflect(-lightDir, norm);
    \\  float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    \\  vec3 specular = light.specular * spec * vec3(texture(material.specular, TexCoords)).rgb;
    \\
    \\  vec3 result = ambient + diffuse + specular;
    \\  FragColor = vec4(result, 1.0);
    \\}
    \\
;

const fragment_point_light_shader_source =
    \\#version 330 core
    \\struct Material {
    \\  sampler2D diffuse;
    \\  sampler2D specular;
    \\  float shininess;
    \\};
    \\
    \\struct PointLight {
    \\  vec3 position;
    \\
    \\  vec3 ambient;
    \\  vec3 diffuse;
    \\  vec3 specular;
    \\
    \\  float constant;
    \\  float linear;
    \\  float quadratic;
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
    \\uniform PointLight light;
    \\
    \\void main() {
    \\  vec3 lightDir = normalize(light.position - FragPos);
    \\
    \\  // ambient
    \\  vec3 ambient = light.ambient * vec3(texture(material.diffuse, TexCoords)).rgb;
    \\
    \\  // diffuse
    \\  vec3 norm = normalize(Normal);
    \\  float diff = max(dot(norm, lightDir), 0.0);
    \\  vec3 diffuse = light.diffuse * diff * vec3(texture(material.diffuse, TexCoords)).rgb;
    \\
    \\  // specular
    \\  vec3 viewDir = normalize(viewPos - FragPos);
    \\  vec3 reflectDir = reflect(-lightDir, norm);
    \\  float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    \\  vec3 specular = light.specular * spec * vec3(texture(material.specular, TexCoords)).rgb;
    \\
    \\  // attenuation
    \\  float distance = length(light.position - FragPos);
    \\  float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));
    \\  ambient *= attenuation;
    \\  diffuse *= attenuation;
    \\  specular *= attenuation;
    \\
    \\  vec3 result = ambient + diffuse + specular;
    \\  FragColor = vec4(result, 1.0);
    \\}
    \\
;

const fragment_spot_light_shader_source =
    \\#version 330 core
    \\struct Material {
    \\  sampler2D diffuse;
    \\  sampler2D specular;
    \\  float shininess;
    \\};
    \\
    \\struct SpotLight {
    \\  vec3 position;
    \\  vec3 direction;
    \\  float cutOff;
    \\  float outerCutOff;
    \\
    \\  vec3 ambient;
    \\  vec3 diffuse;
    \\  vec3 specular;
    \\
    \\  float constant;
    \\  float linear;
    \\  float quadratic;
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
    \\uniform SpotLight light;
    \\
    \\void main() {
    \\  vec3 lightDir = normalize(light.position - FragPos);
    \\
    \\  // ambient
    \\  vec3 ambient = light.ambient * texture(material.diffuse, TexCoords).rgb;
    \\
    \\  // diffuse
    \\  vec3 norm = normalize(Normal);
    \\  float diff = max(dot(norm, lightDir), 0.0);
    \\  vec3 diffuse = light.diffuse * diff * vec3(texture(material.diffuse, TexCoords)).rgb;
    \\
    \\  // specular
    \\  vec3 viewDir = normalize(viewPos - FragPos);
    \\  vec3 reflectDir = reflect(-lightDir, norm);
    \\  float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    \\  vec3 specular = light.specular * spec * texture(material.specular, TexCoords).rgb;
    \\
    \\  // spotlight
    \\  float theta = dot(lightDir, normalize(-light.direction));
    \\  float epsilon = light.cutOff - light.outerCutOff;
    \\  float intensity = clamp((theta - light.outerCutOff) / epsilon, 0.0, 1.0);
    \\  diffuse *= intensity;
    \\  specular *= intensity;
    \\
    \\  // attenuation
    \\  float distance = length(light.position - FragPos);
    \\  float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));
    \\  diffuse *= attenuation;
    \\  specular *= attenuation;
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

pub fn main(init: std.process.Init) !void {
    const stbi = @import("stbi");
    stbi.init(init.io, init.gpa);
    defer stbi.deinit();

    stbi.setFlipVerticallyOnLoad(true);

    const window = try sdl.Window.create(.{
        .title = "013 - Light Casters",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    const container_texture = try Texture.loadFromMemory(common.assets.container2_png);
    defer container_texture.delete();

    const container_specular_texture = try Texture.loadFromMemory(common.assets.container2_specular_png);
    defer container_specular_texture.delete();

    _ = sdl.c.SDL_SetWindowRelativeMouseMode(window.handle, true);

    const directional_light_shader = try Shader.create(
        vertex_shader_source,
        fragment_directional_light_shader_source,
        null,
    );
    defer directional_light_shader.delete();

    const point_light_shader = try Shader.create(
        vertex_shader_source,
        fragment_point_light_shader_source,
        null,
    );
    defer point_light_shader.delete();

    const spot_light_shader = try Shader.create(
        vertex_shader_source,
        fragment_spot_light_shader_source,
        null,
    );
    defer spot_light_shader.delete();

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
        \\  L           - cycle light mode (directional / point / spot)
        \\  Escape      - quit
        \\
    , .{});
    try stdout.flush();

    const LightMode = enum { directional, point, spot };

    var last_ticks = sdl.c.SDL_GetTicks();
    var event: sdl.c.SDL_Event = undefined;
    var running = true;
    var light_moving = true;
    var light_time: f32 = 0.0;
    var current_mode: LightMode = .directional;

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
                        current_mode = switch (current_mode) {
                            .directional => .point,
                            .point => .spot,
                            .spot => .directional,
                        };
                        try stdout.print("Light mode: {s}\n", .{@tagName(current_mode)});
                        try stdout.flush();
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
        const diffuse_color = zm.f32x4(0.5, 0.5, 0.5, 0.0);
        const ambient_color = zm.f32x4(0.2, 0.2, 0.2, 0.0);

        {
            const active_shader = switch (current_mode) {
                .directional => directional_light_shader,
                .point => point_light_shader,
                .spot => spot_light_shader,
            };

            active_shader.use();
            defer gl.UseProgram(0);

            active_shader.setVec3("light.ambient", zm.vecToArr3(ambient_color));
            active_shader.setVec3("light.diffuse", zm.vecToArr3(diffuse_color));
            active_shader.setVec3("light.specular", .{ 1.0, 1.0, 1.0 });

            switch (current_mode) {
                .directional => {
                    active_shader.setVec3("light.direction", .{ -0.2, -1.0, -0.3 });
                },
                .point => {
                    active_shader.setVec3("light.position", zm.vecToArr3(light_pos));
                    active_shader.setFloat("light.constant", 1.0);
                    active_shader.setFloat("light.linear", 0.09);
                    active_shader.setFloat("light.quadratic", 0.032);
                },
                .spot => {
                    active_shader.setVec3("light.position", zm.vecToArr3(camera.position));
                    active_shader.setVec3("light.direction", zm.vecToArr3(camera.front));
                    active_shader.setFloat("light.cutOff", @cos(std.math.degreesToRadians(12.5)));
                    active_shader.setFloat("light.outerCutOff", @cos(std.math.degreesToRadians(17.5)));
                    active_shader.setFloat("light.constant", 1.0);
                    active_shader.setFloat("light.linear", 0.09);
                    active_shader.setFloat("light.quadratic", 0.032);
                },
            }

            active_shader.setInt("material.diffuse", 0);
            active_shader.setInt("material.specular", 1);
            active_shader.setFloat("material.shininess", 32.0);
            camera.applyToShader(active_shader);

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
                active_shader.setMat4("model", &model_arr);
                gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
            }
        }

        if (current_mode == .point) {
            light_shader.use();
            defer gl.UseProgram(0);

            const model = zm.mul(
                zm.scaling(0.2, 0.2, 0.2),
                zm.translationV(light_pos),
            );

            light_shader.setMat4("model", &zm.matToArr(model));
            light_shader.setVec3("lightColor", .{ 1.0, 1.0, 1.0 });
            camera.applyToShader(light_shader);

            gl.BindVertexArray(vao[0]);
            defer gl.BindVertexArray(0);

            gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, 0);
        }

        window.swap();
    }
}
