const std = @import("std");
const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;
const Shader = common.Shader;
const Camera = common.Camera;
const zm = common.zmath;
const Model = common.Model;

pub fn main(init: std.process.Init) !void {
    const stbi = @import("stbi");
    stbi.init(init.io, init.gpa);
    stbi.setFlipVerticallyOnLoad(true);
    defer stbi.deinit();

    const window = try sdl.Window.create(.{
        .title = "015 - Model Loading",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    const model = try Model.init(init.gpa, "common/assets/backpack/backpack.obj");
    defer model.deinit();

    var diag = Shader.Diagnostic{ .allocator = init.gpa };
    defer diag.deinit();

    const shader = Shader.create(
        common.assets.model_vertex_shader_vert,
        common.assets.model_fragment_shader_frag,
        &diag,
    ) catch |err| {
        if (diag.log.len > 0) std.debug.print("Shader error: {s}\n", .{diag.log});
        return err;
    };
    defer shader.delete();

    _ = sdl.c.SDL_SetWindowRelativeMouseMode(window.handle, true);

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
                    switch (event.key.scancode) {
                        sdl.c.SDL_SCANCODE_ESCAPE => running = false,
                        else => if (Camera.feedEvent(&input, &event)) continue,
                    }
                },
                else => if (Camera.feedEvent(&input, &event)) continue,
            }
        }

        Camera.feedKeyboard(&input);
        camera.update(input, delta_time);
        camera.applyCapture(window);

        gl.ClearColor(0.1, 0.1, 0.1, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        shader.use();
        camera.applyToShader(shader);
        {
            shader.setFloat("material.shininess", 128.0);

            shader.setVec3("directionalLight.direction", .{ 0.0, -0.3, -1.0 });
            shader.setVec3("directionalLight.ambient", .{ 0.4, 0.2, 0.1 });
            shader.setVec3("directionalLight.diffuse", .{ 2.0, 0.8, 0.3 });
            shader.setVec3("directionalLight.specular", .{ 1.0, 1.0, 1.0 });
        }

        const model_mat = zm.matToArr(zm.identity());
        shader.setMat4("model", &model_mat);

        model.draw(shader);

        window.swap();
    }
}
