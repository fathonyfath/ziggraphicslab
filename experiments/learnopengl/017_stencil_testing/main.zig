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
        .title = "017 - Stencil Testing",
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

    const outline_shader = Shader.create(
        common.assets.simple_vertex_shader_vert,
        common.assets.outline_fragment_shader_frag,
        &diag,
    ) catch |err| {
        if (diag.log.len > 0) std.debug.print("Base Shader error: {s}\n", .{diag.log});
        return err;
    };
    defer outline_shader.delete();

    const cube_texture = try Texture.loadFromMemory(common.assets.marble_jpg);
    defer cube_texture.delete();

    const floor_texture = try Texture.loadFromMemory(common.assets.metal_png);
    defer floor_texture.delete();

    base_shader.use();
    base_shader.setInt("texture1", 0);

    gl.Enable(gl.DEPTH_TEST);
    gl.Enable(gl.STENCIL_TEST);

    // Mental model: the stencil buffer is a 2D array (width x height), each pixel holds one byte (0-255).
    // We use it as a mask: 0 = "not cube", 1 = "cube was here".
    //
    // Three passes each frame:
    //   1. Floor  - StencilMask(0x00): stencil is read-only, floor pixels never mark the buffer.
    //   2. Cubes  - StencilMask(0xFF) + StencilFunc(ALWAYS, 1) + StencilOp(REPLACE):
    //              every cube pixel stamps 1 into the stencil buffer, visible or not.
    //   3. Outline - StencilFunc(NOTEQUAL, 1): scaled cube only renders where stencil != 1,
    //              which is the outer ring between the scaled and original silhouettes.
    //
    // StencilOp(sfail, dpfail, dppass) is a side effect — it does NOT affect whether a fragment
    // is drawn. It only controls what gets written back into the stencil buffer after the tests.
    // Per pixel the pipeline is:
    //   StencilFunc runs → fail: fragment discarded, sfail action runs on stencil buffer
    //                    → pass: depth test runs → fail: fragment discarded, dpfail action runs
    //                                            → pass: fragment drawn,   dppass action runs
    //
    //   sfail=KEEP     - triggered in outline pass (StencilFunc NOTEQUAL): pixels inside the
    //                    original cube silhouette fail the stencil test, leave stencil unchanged.
    //   dpfail=REPLACE - triggered in cube base pass: cube bottom is behind the floor so depth
    //                    fails, but we still stamp stencil=1 so the outline pass (depth-disabled)
    //                    won't bleed through the floor for those pixels.
    //   dppass=REPLACE - triggered in cube base pass: visible cube pixels pass both tests,
    //                    stamp stencil=1 to mark the cube silhouette for the outline pass.
    gl.StencilOp(gl.KEEP, gl.REPLACE, gl.REPLACE);

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
        // stencil buffer: all pixels = 0
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT);

        base_shader.use();
        camera.applyToShader(base_shader);

        {
            const shader = base_shader;
            shader.use();
            camera.applyToShader(shader);

            // Draw floor
            // stencil buffer: write mask=0, floor draw changes nothing → still all 0
            gl.StencilMask(0x00); // write mask=0: floor never writes to stencil buffer
            floor_texture.bind(gl.TEXTURE0);
            gl.BindVertexArray(plane_vao[0]);
            {
                const model = zm.matToArr(zm.identity());
                shader.setMat4("model", &model);
                gl.DrawArrays(gl.TRIANGLES, 0, 6);
            }

            // Draw boxes
            // stencil buffer after: pixels covered by either cube (visible or behind floor) = 1, everything else = 0
            gl.StencilMask(0xFF); // write mask=0xFF: all bits writable, cubes can write to stencil
            gl.StencilFunc(gl.ALWAYS, 1, 0xFF); // always pass stencil test, ref=1 (value to write via StencilOp REPLACE)
            cube_texture.bind(gl.TEXTURE0);
            gl.BindVertexArray(cube_vao[0]);
            {
                const model = zm.matToArr(zm.translation(-1.0, 0.0, -1.0));
                shader.setMat4("model", &model);
                gl.DrawArrays(gl.TRIANGLES, 0, 36);
            }
            {
                const model = zm.matToArr(zm.translation(2.0, 0.0, 0.0));
                shader.setMat4("model", &model);
                gl.DrawArrays(gl.TRIANGLES, 0, 36);
            }
        }

        {
            const shader = outline_shader;
            shader.use();
            camera.applyToShader(shader);

            // stencil buffer: write mask=0, outline draw changes nothing → stays as cubes left it
            // StencilFunc NOTEQUAL: only pixels with stencil=0 (outside cube silhouette) pass → draws the outer ring
            gl.StencilMask(0x00); // write mask=0: outline pass never modifies stencil
            gl.StencilFunc(gl.NOTEQUAL, 1, 0xFF); // only draw pixels where stencil != 1 (the outer ring)
            defer {
                gl.StencilMask(0xFF);
                gl.StencilFunc(gl.ALWAYS, 1, 0xFF);
            }

            gl.Disable(gl.DEPTH_TEST);
            defer gl.Enable(gl.DEPTH_TEST);

            const scale = 1.1;

            gl.BindVertexArray(cube_vao[0]);
            {
                const model = zm.matToArr(
                    zm.mul(
                        zm.scaling(scale, scale, scale),
                        zm.translation(-1.0, 0.0, -1.0),
                    ),
                );
                shader.setMat4("model", &model);
                gl.DrawArrays(gl.TRIANGLES, 0, 36);
            }
            {
                const model = zm.matToArr(
                    zm.mul(
                        zm.scaling(scale, scale, scale),
                        zm.translation(2.0, 0.0, 0.0),
                    ),
                );
                shader.setMat4("model", &model);
                gl.DrawArrays(gl.TRIANGLES, 0, 36);
            }
        }

        gl.BindVertexArray(0);

        window.swap();
    }
}
