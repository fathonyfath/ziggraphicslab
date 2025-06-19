const std = @import("std");
const math = std.math;

const zm = @import("zm");

const Self = @This();

// Transformation
position: zm.Vec3f,
euler_rotation: zm.Vec3f,
rotation: zm.Quaternionf,

// Camera
front: zm.Vec3f,
up: zm.Vec3f,
right: zm.Vec3f,

// Perspective
fov: f32,
aspect_ratio: f32,
near: f32,
far: f32,

// Matrices
rotation_matrix: zm.Mat4f,

pub fn init(position: zm.Vec3f) Self {
    const euler_rotation = zm.Vec3f{ 0.0, 0.0, 0.0 };

    var self = Self{
        .position = position,
        .euler_rotation = euler_rotation,
        .rotation = zm.Quaternionf.fromEulerAngles(euler_rotation),
        .front = undefined,
        .up = undefined,
        .right = undefined,
        .fov = 45.0,
        .aspect_ratio = 800.0 / 600.0,
        .near = 0.1,
        .far = 100.0,
        .rotation_matrix = undefined,
    };

    self.updateRotationMatrixFromRotation();
    self.updateProperties();
    return self;
}

pub fn getViewMatrix(self: Self) zm.Mat4f {
    return zm.Mat4f.lookAt(self.position, self.position + self.front, self.up);
}

pub fn getProjectionMatrix(self: Self) zm.Mat4f {
    return zm.Mat4f.perspective(math.degreesToRadians(self.fov), self.aspect_ratio, self.near, self.far);
}

pub fn getYawRadians(self: Self) f32 {
    return self.euler_rotation[1];
}

pub fn setYawRadians(self: *Self, angle_rad: f32) void {
    self.euler_rotation[1] = angle_rad;
    self.rotation = zm.Quaternionf.fromEulerAngles(self.euler_rotation);

    self.updateRotationMatrixFromRotation();
    self.updateProperties();
}

pub fn getPitchRadians(self: Self) f32 {
    return self.euler_rotation[0];
}

pub fn setPitchRadians(self: *Self, angle_rad: f32) void {
    self.euler_rotation[0] = angle_rad;
    self.rotation = zm.Quaternionf.fromEulerAngles(self.euler_rotation);

    self.updateRotationMatrixFromRotation();
    self.updateProperties();
}

fn updateRotationMatrixFromRotation(self: *Self) void {
    self.rotation_matrix = zm.Mat4f.fromQuaternion(self.rotation);
}

fn updateProperties(self: *Self) void {
    const x_row = zm.Vec3f{
        self.rotation_matrix.data[0],
        self.rotation_matrix.data[1],
        self.rotation_matrix.data[2],
    };
    const y_row = zm.Vec3f{
        self.rotation_matrix.data[4],
        self.rotation_matrix.data[5],
        self.rotation_matrix.data[6],
    };
    const z_row = zm.Vec3f{
        self.rotation_matrix.data[8],
        self.rotation_matrix.data[9],
        self.rotation_matrix.data[10],
    };

    self.right = zm.vec.normalize(x_row);
    self.up = zm.vec.normalize(y_row);

    const invert: zm.Vec3f = @splat(-1);
    self.front = zm.vec.normalize(invert * z_row);
}
