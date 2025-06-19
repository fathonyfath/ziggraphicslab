const zm = @import("zm");

const Self = @This();

// Transformation
position: zm.Vec3,
euler_rotation: zm.Vec3,
rotation: zm.Quaternion,

// Camera
front: zm.Vec3,
up: zm.Vec3,
right: zm.Vec3,

// Perspective
fov: f64,
aspect_ratio: f64,
near: f64,
far: f64,

pub fn init(position: zm.Vec3f) Self {
    const euler_rotation = zm.Vec3{ 0.0, 0.0, 0.0 };

    var self = Self{
        .position = position,
        .euler_rotation = euler_rotation,
        .rotation = zm.Quaternion.fromEulerAngles(euler_rotation),
        .front = undefined,
        .up = undefined,
        .right = undefined,
        .fov = 45.0,
        .aspect_ratio = 16.0 / 9.0,
        .near = 0.1,
        .far = 100.0,
    };

    self.updateProperties();
    return self;
}

pub fn getViewMatrix(self: Self) zm.Mat4 {
    return zm.Mat4.lookAt(self.position, self.position + self.front, self.up);
}

pub fn getProjectionMatrix(self: Self) zm.Mat4 {
    return zm.Mat4.perspective(self.fov, self.ratio, self.near, self.far);
}

pub fn updateProperties(self: *Self) void {
    _ = self;
}
