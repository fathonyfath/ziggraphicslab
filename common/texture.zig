const gl = @import("gl");
const stbi = @import("stbi");

id: gl.uint,

const Self = @This();

pub fn loadFromMemory(data: []const u8) !Self {
    var image = try stbi.Image.loadFromMemory(data, 0);
    defer image.deinit();

    const format: gl.@"enum" = switch (image.num_components) {
        1 => gl.RED,
        3 => gl.RGB,
        4 => gl.RGBA,
        else => unreachable,
    };

    var textures: [1]gl.uint = undefined;
    gl.GenTextures(1, &textures);

    gl.BindTexture(gl.TEXTURE_2D, textures[0]);
    defer gl.BindTexture(gl.TEXTURE_2D, 0);

    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        @intCast(format),
        @intCast(image.width),
        @intCast(image.height),
        0,
        format,
        gl.UNSIGNED_BYTE,
        @ptrCast(image.data),
    );
    gl.GenerateMipmap(gl.TEXTURE_2D);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    return .{ .id = textures[0] };
}

pub fn bind(self: Self, unit: gl.@"enum") void {
    gl.ActiveTexture(unit);
    gl.BindTexture(gl.TEXTURE_2D, self.id);
}

pub fn delete(self: Self) void {
    gl.DeleteTextures(1, &[_]gl.uint{self.id});
}
