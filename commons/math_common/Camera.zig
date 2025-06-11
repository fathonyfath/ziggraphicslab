const zm = @import("zm");

const Self = @This();

position: zm.Vec3f,

pub fn init(position: zm.Vec3f) Self {
    return Self{ .position = position };
}
