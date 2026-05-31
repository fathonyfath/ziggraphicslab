const std = @import("std");
const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;
const Camera = common.Camera;
const Shader = common.Shader;
const Texture = common.Texture;
const zm = common.zmath;

// zig fmt: off
const cube_vertices = [_]f32{
    // positions       // tex coords
    -0.5, -0.5, -0.5,  0.0, 0.0,
     0.5, -0.5, -0.5,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
    -0.5,  0.5, -0.5,  0.0, 1.0,
    -0.5, -0.5, -0.5,  0.0, 0.0,

    -0.5, -0.5,  0.5,  0.0, 0.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
     0.5,  0.5,  0.5,  1.0, 1.0,
     0.5,  0.5,  0.5,  1.0, 1.0,
    -0.5,  0.5,  0.5,  0.0, 1.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,

    -0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5,  0.5, -0.5,  1.0, 1.0,
    -0.5, -0.5, -0.5,  0.0, 1.0,
    -0.5, -0.5, -0.5,  0.0, 1.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,
    -0.5,  0.5,  0.5,  1.0, 0.0,

     0.5,  0.5,  0.5,  1.0, 0.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5,  0.5,  0.0, 0.0,
     0.5,  0.5,  0.5,  1.0, 0.0,

    -0.5, -0.5, -0.5,  0.0, 1.0,
     0.5, -0.5, -0.5,  1.0, 1.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
     0.5, -0.5,  0.5,  1.0, 0.0,
    -0.5, -0.5,  0.5,  0.0, 0.0,
    -0.5, -0.5, -0.5,  0.0, 1.0,

    -0.5,  0.5, -0.5,  0.0, 1.0,
     0.5,  0.5, -0.5,  1.0, 1.0,
     0.5,  0.5,  0.5,  1.0, 0.0,
     0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5,  0.5,  0.5,  0.0, 0.0,
    -0.5,  0.5, -0.5,  0.0, 1.0,
};

const plane_vertices = [_]f32{
    // positions       // tex coords (tiled 2x)
     5.0, -0.5,  5.0,  2.0, 0.0,
    -5.0, -0.5,  5.0,  0.0, 0.0,
    -5.0, -0.5, -5.0,  0.0, 2.0,

     5.0, -0.5,  5.0,  2.0, 0.0,
    -5.0, -0.5, -5.0,  0.0, 2.0,
     5.0, -0.5, -5.0,  2.0, 2.0,
};
// zig fmt: on

pub fn main(init: std.process.Init) !void {
    const stbi = @import("stbi");
    stbi.init(init.io, init.gpa);
    stbi.setFlipVerticallyOnLoad(true);
    defer stbi.deinit();

    const window = try sdl.Window.create(.{
        .title = "016 - Depth Testing",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    _ = sdl.c.SDL_SetWindowRelativeMouseMode(window.handle, true);

    var diag = Shader.Diagnostic{ .allocator = init.gpa };
    defer diag.deinit();

    const base_shader = Shader.create(
        common.assets.simple_vertex_shader_vert,
        common.assets.simple_fragment_shader_frag,
        &diag,
    ) catch |err| {
        if (diag.log.len > 0) std.debug.print("Base Shader error: {s}\n", .{diag.log});
        return err;
    };
    defer base_shader.delete();

    const depth_viz_shader = Shader.create(
        common.assets.simple_vertex_shader_vert,
        common.assets.depth_viz_fragment_shader_frag,
        &diag,
    ) catch |err| {
        if (diag.log.len > 0) std.debug.print("Depth Viz Shader error: {s}\n", .{diag.log});
        return err;
    };
    defer depth_viz_shader.delete();

    const depth_viz_improve_shader = Shader.create(
        common.assets.simple_vertex_shader_vert,
        common.assets.depth_viz_improve_fragment_shader_frag,
        &diag,
    ) catch |err| {
        if (diag.log.len > 0) std.debug.print("Depth Viz Improve Shader error: {s}\n", .{diag.log});
        return err;
    };
    defer depth_viz_improve_shader.delete();

    const cube_texture = try Texture.loadFromMemory(common.assets.marble_jpg);
    defer cube_texture.delete();

    const floor_texture = try Texture.loadFromMemory(common.assets.metal_png);
    defer floor_texture.delete();

    base_shader.use();
    base_shader.setInt("texture1", 0);

    gl.Enable(gl.DEPTH_TEST);

    var cube_vao: [1]gl.uint = undefined;
    var cube_vbo: [1]gl.uint = undefined;
    {
        gl.GenVertexArrays(1, &cube_vao);
        gl.GenBuffers(1, &cube_vbo);
        gl.BindVertexArray(cube_vao[0]);
        defer {
            gl.BindVertexArray(0);
            gl.BindBuffer(gl.ARRAY_BUFFER, 0);
            gl.DeleteBuffers(1, &cube_vbo);
        }
        gl.BindBuffer(gl.ARRAY_BUFFER, cube_vbo[0]);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(cube_vertices)), &cube_vertices, gl.STATIC_DRAW);
        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(1);
        gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
    }

    var plane_vao: [1]gl.uint = undefined;
    var plane_vbo: [1]gl.uint = undefined;
    {
        gl.GenVertexArrays(1, &plane_vao);
        gl.GenBuffers(1, &plane_vbo);
        gl.BindVertexArray(plane_vao[0]);
        defer {
            gl.BindVertexArray(0);
            gl.BindBuffer(gl.ARRAY_BUFFER, 0);
            gl.DeleteBuffers(1, &plane_vbo);
        }
        gl.BindBuffer(gl.ARRAY_BUFFER, plane_vbo[0]);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(plane_vertices)), &plane_vertices, gl.STATIC_DRAW);
        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(1);
        gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
    }
    defer {
        gl.DeleteVertexArrays(1, &cube_vao);
        gl.DeleteVertexArrays(1, &plane_vao);
        gl.DeleteBuffers(1, &cube_vbo);
        gl.DeleteBuffers(1, &plane_vbo);
    }

    var camera = Camera.init(.{ 0.0, 0.0, 3.0 }, 800.0 / 600.0);

    var active_shader = base_shader;

    const DepthFunc = struct {
        func: gl.@"enum",
        name: []const u8,
        desc: []const u8,
    };
    const depth_funcs = [_]DepthFunc{
        .{ .func = gl.LESS,     .name = "GL_LESS",     .desc = "pass if fragment depth < stored depth (default)" },
        .{ .func = gl.ALWAYS,   .name = "GL_ALWAYS",   .desc = "always pass" },
        .{ .func = gl.NEVER,    .name = "GL_NEVER",    .desc = "never pass" },
        .{ .func = gl.EQUAL,    .name = "GL_EQUAL",    .desc = "pass if fragment depth == stored depth" },
        .{ .func = gl.LEQUAL,   .name = "GL_LEQUAL",   .desc = "pass if fragment depth <= stored depth" },
        .{ .func = gl.GREATER,  .name = "GL_GREATER",  .desc = "pass if fragment depth > stored depth" },
        .{ .func = gl.NOTEQUAL, .name = "GL_NOTEQUAL", .desc = "pass if fragment depth != stored depth" },
        .{ .func = gl.GEQUAL,   .name = "GL_GEQUAL",   .desc = "pass if fragment depth >= stored depth" },
    };
    var depth_func_idx: usize = 0;
    gl.DepthFunc(depth_funcs[depth_func_idx].func);

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        \\Controls:
        \\  WASD        - move camera
        \\  Mouse       - look around
        \\  Scroll      - zoom
        \\  Space       - toggle mouse capture
        \\  1           - base shader
        \\  2           - depth visualization
        \\  3           - linearized depth visualization
        \\  Tab         - cycle depth function
        \\  Escape      - quit
        \\
    , .{});
    try stdout.print("Depth func: {s} - {s}\n", .{ depth_funcs[depth_func_idx].name, depth_funcs[depth_func_idx].desc });
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
                    switch (event.key.scancode) {
                        sdl.c.SDL_SCANCODE_ESCAPE => running = false,
                        sdl.c.SDL_SCANCODE_1 => active_shader = base_shader,
                        sdl.c.SDL_SCANCODE_2 => active_shader = depth_viz_shader,
                        sdl.c.SDL_SCANCODE_3 => active_shader = depth_viz_improve_shader,
                        sdl.c.SDL_SCANCODE_TAB => {
                            depth_func_idx = (depth_func_idx + 1) % depth_funcs.len;
                            gl.DepthFunc(depth_funcs[depth_func_idx].func);
                            try stdout.print("Depth func: {s} - {s}\n", .{ depth_funcs[depth_func_idx].name, depth_funcs[depth_func_idx].desc });
                            try stdout.flush();
                        },
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

        active_shader.use();
        camera.applyToShader(active_shader);

        cube_texture.bind(gl.TEXTURE0);
        gl.BindVertexArray(cube_vao[0]);
        {
            const model = zm.matToArr(zm.translation(-1.0, 0.0, -1.0));
            active_shader.setMat4("model", &model);
            gl.DrawArrays(gl.TRIANGLES, 0, 36);
        }
        {
            const model = zm.matToArr(zm.translation(2.0, 0.0, 0.0));
            active_shader.setMat4("model", &model);
            gl.DrawArrays(gl.TRIANGLES, 0, 36);
        }

        floor_texture.bind(gl.TEXTURE0);
        gl.BindVertexArray(plane_vao[0]);
        {
            const model = zm.matToArr(zm.identity());
            active_shader.setMat4("model", &model);
            gl.DrawArrays(gl.TRIANGLES, 0, 6);
        }

        gl.BindVertexArray(0);

        window.swap();
    }
}
