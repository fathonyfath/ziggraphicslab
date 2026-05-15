const std = @import("std");
const math = std.math;
const zm = @import("zmath");
const sdl = @import("sdl.zig");
const Shader = @import("shader.zig");

pub const CameraInput = struct {
    /// Mouse movement in pixels this frame (x=right, y=down).
    mouse_delta: [2]f32 = .{ 0, 0 },
    /// Scroll wheel notches this frame (positive = scroll up).
    scroll_delta: f32 = 0,
    move: packed struct {
        forward: bool = false,
        back: bool = false,
        left: bool = false,
        right: bool = false,
        up: bool = false,
        down: bool = false,
    } = .{},
    toggle_capture: bool = false,
};

const Self = @This();

position: zm.Vec,
yaw: f32,
pitch: f32,
fov: f32,
aspect_ratio: f32,
near: f32,
far: f32,
captured: bool,

front: zm.Vec,
right: zm.Vec,
up: zm.Vec,

const mouse_sensitivity: f32 = 0.1;
const move_speed: f32 = 5.0;
const world_up = zm.f32x4(0, 1, 0, 0);

pub fn init(position: [3]f32, aspect_ratio: f32) Self {
    var self = Self{
        .position = zm.f32x4(position[0], position[1], position[2], 1),
        .yaw = -math.pi / 2.0,
        .pitch = 0,
        .fov = math.degreesToRadians(45.0),
        .aspect_ratio = aspect_ratio,
        .near = 0.1,
        .far = 100.0,
        .captured = true,
        .front = undefined,
        .right = undefined,
        .up = undefined,
    };
    self.recalculate();
    return self;
}

pub fn update(self: *Self, input: CameraInput, delta_time: f32) void {
    if (input.toggle_capture) self.captured = !self.captured;

    if (self.captured) {
        self.yaw += math.degreesToRadians(input.mouse_delta[0] * mouse_sensitivity);
        self.pitch = math.clamp(
            self.pitch + math.degreesToRadians(-input.mouse_delta[1] * mouse_sensitivity),
            math.degreesToRadians(-89.0),
            math.degreesToRadians(89.0),
        );

        self.fov = math.clamp(
            self.fov - math.degreesToRadians(input.scroll_delta),
            math.degreesToRadians(1.0),
            math.degreesToRadians(45.0),
        );
    }

    const speed: zm.Vec = @splat(move_speed * delta_time);
    if (input.move.forward) self.position += speed * self.front;
    if (input.move.back) self.position -= speed * self.front;
    if (input.move.right) self.position += speed * self.right;
    if (input.move.left) self.position -= speed * self.right;
    if (input.move.up) self.position += speed * world_up;
    if (input.move.down) self.position -= speed * world_up;

    self.recalculate();
}

pub fn getViewMatrix(self: Self) zm.Mat {
    return zm.lookAtRh(self.position, self.position + self.front, self.up);
}

pub fn getProjectionMatrix(self: Self) zm.Mat {
    return zm.perspectiveFovRhGl(self.fov, self.aspect_ratio, self.near, self.far);
}

/// Sets view, projection, and viewPos uniforms on the shader.
pub fn applyToShader(self: Self, shader: Shader) void {
    var view_arr = zm.matToArr(self.getViewMatrix());
    shader.setMat4("view", &view_arr);

    var proj_arr = zm.matToArr(self.getProjectionMatrix());
    shader.setMat4("projection", &proj_arr);

    shader.setVec3("viewPos", zm.vecToArr3(self.position));
}

/// Feed an SDL event into a CameraInput. Returns true if the event was consumed.
pub fn feedEvent(input: *CameraInput, event: *const sdl.c.SDL_Event) bool {
    switch (event.type) {
        sdl.c.SDL_EVENT_MOUSE_MOTION => {
            input.mouse_delta[0] += event.motion.xrel;
            input.mouse_delta[1] += event.motion.yrel;
            return true;
        },
        sdl.c.SDL_EVENT_MOUSE_WHEEL => {
            input.scroll_delta += event.wheel.y;
            return true;
        },
        sdl.c.SDL_EVENT_KEY_DOWN => {
            if (event.key.scancode == sdl.c.SDL_SCANCODE_SPACE) {
                input.toggle_capture = true;
                return true;
            }
            return false;
        },
        else => return false,
    }
}

/// Apply the current captured state to the window's relative mouse mode.
pub fn applyCapture(self: Self, window: sdl.Window) void {
    _ = sdl.c.SDL_SetWindowRelativeMouseMode(window.handle, self.captured);
}

/// Read WASD/QE keyboard state into a CameraInput. Call once per frame after polling.
pub fn feedKeyboard(input: *CameraInput) void {
    const kb = sdl.c.SDL_GetKeyboardState(null);
    input.move.forward = kb[sdl.c.SDL_SCANCODE_W];
    input.move.back = kb[sdl.c.SDL_SCANCODE_S];
    input.move.left = kb[sdl.c.SDL_SCANCODE_A];
    input.move.right = kb[sdl.c.SDL_SCANCODE_D];
    input.move.up = kb[sdl.c.SDL_SCANCODE_E];
    input.move.down = kb[sdl.c.SDL_SCANCODE_Q];
}

fn recalculate(self: *Self) void {
    const cy = @cos(self.yaw);
    const sy = @sin(self.yaw);
    const cp = @cos(self.pitch);
    const sp = @sin(self.pitch);

    self.front = zm.normalize3(zm.f32x4(cy * cp, sp, sy * cp, 0));
    self.right = zm.normalize3(zm.cross3(self.front, world_up));
    self.up = zm.normalize3(zm.cross3(self.right, self.front));
}
