const zm = @import("zm");

const Self = @This();

// Transformation
position: zm.Vec3,
rotation: zm.Quaternion,

// Camera
front: zm.Vec3,
up: zm.Vec3,
right: zm.Vec3,
world_up: zm.Vec3,
fov: f64,
aspect_ratio: f64,
near: f64,
far: f64,

pub fn init(position: zm.Vec3f) Self {
    var self = Self{
        .position = position,
        .rotation = zm.Quaternion.fromEulerAngles(zm.Vec3{ 0.0, 0.0, 0.0 }),
        .front = zm.Vec3{ 0.0, 0.0, -1.0 },
        .up = zm.vec.up(f64),
        .right = zm.vec.right(f64),
        .world_up = zm.vec.up(f64),
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
    const rotation_euler = zm.vec.
}
