const std = @import("std");
const math = std.math;

const window = @import("window.zig");
const glfw = window.glfw;

const zm = @import("zm");

const Self = @This();

pub const Integration = struct {
    CameraPosition: struct {
        Get: *const fn () zm.Vec3f,
        Set: *const fn (zm.Vec3f) void,
    },
    CameraFront: struct {
        Get: *const fn () zm.Vec3f,
    },
    CameraRight: struct {
        Get: *const fn () zm.Vec3f,
    },
    YawRadians: struct {
        Get: *const fn () f32,
        Set: *const fn (f32) void,
    },
    PitchRadians: struct {
        Get: *const fn () f32,
        Set: *const fn (f32) void,
    },
    FOV: struct {
        Get: *const fn () f32,
        Set: *const fn (f32) void,
    },
};

var first_mouse: bool = true;
var last_x: f32 = undefined;
var last_y: f32 = undefined;
var integration: Integration = undefined;
var global_delta_time: f32 = 0.0;

pub fn init(window_width: u32, windoww_height: u32, integration_type: type) void {
    last_x = @as(f32, @floatFromInt(window_width)) / 2.0;
    last_y = @as(f32, @floatFromInt(windoww_height)) / 2.0;
    integration = Integration{
        .CameraPosition = .{
            .Get = &integration_type.CameraPosition.Get,
            .Set = &integration_type.CameraPosition.Set,
        },
        .CameraFront = .{
            .Get = &integration_type.CameraFront.Get,
        },
        .CameraRight = .{
            .Get = &integration_type.CameraRight.Get,
        },
        .YawRadians = .{
            .Get = &integration_type.YawRadians.Get,
            .Set = &integration_type.YawRadians.Set,
        },
        .PitchRadians = .{
            .Get = &integration_type.PitchRadians.Get,
            .Set = &integration_type.PitchRadians.Set,
        },
        .FOV = .{
            .Get = &integration_type.FOV.Get,
            .Set = &integration_type.FOV.Set,
        },
    };

    window.setMousePositionCallback(mousePosCallback);
    window.setScrollCallback(scrollCallback);
}

pub fn handleKeyPress(delta_time: f32) void {
    global_delta_time = delta_time;

    const camera_speed: zm.Vec3f = @splat(5.0 * delta_time);

    if (window.getKey(glfw.Key.w) == .press) {
        integration.CameraPosition.Set(integration.CameraPosition.Get() + camera_speed * integration.CameraFront.Get());
    }
    if (window.getKey(glfw.Key.s) == .press) {
        integration.CameraPosition.Set(integration.CameraPosition.Get() - camera_speed * integration.CameraFront.Get());
    }
    if (window.getKey(glfw.Key.a) == .press) {
        integration.CameraPosition.Set(integration.CameraPosition.Get() - camera_speed * integration.CameraRight.Get());
    }
    if (window.getKey(glfw.Key.d) == .press) {
        integration.CameraPosition.Set(integration.CameraPosition.Get() + camera_speed * integration.CameraRight.Get());
    }
    if (window.getKey(glfw.Key.q) == .press) {
        integration.CameraPosition.Set(integration.CameraPosition.Get() - camera_speed * zm.vec.up(f32));
    }
    if (window.getKey(glfw.Key.e) == .press) {
        integration.CameraPosition.Set(integration.CameraPosition.Get() + camera_speed * zm.vec.up(f32));
    }
}

fn mousePosCallback(pos_x: f64, pos_y: f64) void {
    const pos_x_f32: f32 = @floatCast(pos_x);
    const pos_y_f32: f32 = @floatCast(pos_y);
    if (first_mouse) {
        last_x = pos_x_f32;
        last_y = pos_y_f32;
        first_mouse = false;
    }

    var x_offset = pos_x_f32 - last_x;
    var y_offset = last_y - pos_y_f32;
    last_x = pos_x_f32;
    last_y = pos_y_f32;

    const sensitivity = 0.1;
    x_offset *= sensitivity;
    y_offset *= sensitivity;

    const camera_yaw_deg: f32 = math.radiansToDegrees(integration.YawRadians.Get()) + x_offset;
    integration.YawRadians.Set(math.degreesToRadians(camera_yaw_deg));

    var pitch: f32 = math.radiansToDegrees(integration.PitchRadians.Get()) - y_offset;
    if (pitch > 89.0) pitch = 89.0;
    if (pitch < -89.0) pitch = -89.0;

    integration.PitchRadians.Set(math.degreesToRadians(pitch));
}

fn scrollCallback(_: f64, offset_y: f64) void {
    var fov = integration.FOV.Get() - @as(f32, @floatCast(offset_y * 100.0)) * global_delta_time;
    if (fov < 1.0) fov = 1.0;
    if (fov > 45.0) fov = 45.0;
    integration.FOV.Set(fov);
}
