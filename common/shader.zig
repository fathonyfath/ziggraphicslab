const std = @import("std");
const gl = @import("gl");

id: gl.uint,

const Self = @This();

pub const Diagnostic = struct {
    allocator: std.mem.Allocator,
    log: []u8 = &.{},

    pub fn deinit(self: *Diagnostic) void {
        self.allocator.free(self.log);
        self.log = &.{};
    }
};

pub const Error = error{ VertexShader, FragmentShader, OtherShader, LinkProgram };

pub fn create(vertex_source: []const u8, fragment_source: []const u8, diag: ?*Diagnostic) Error!Self {
    const vs = try compileShader(gl.VERTEX_SHADER, vertex_source, diag);
    defer gl.DeleteShader(vs);

    const fs = try compileShader(gl.FRAGMENT_SHADER, fragment_source, diag);
    defer gl.DeleteShader(fs);

    return .{ .id = try linkProgram(&.{ vs, fs }, diag) };
}

pub fn use(self: Self) void {
    gl.UseProgram(self.id);
}

pub fn delete(self: Self) void {
    gl.DeleteProgram(self.id);
}

pub fn setInt(self: Self, name: [:0]const u8, value: i32) void {
    gl.Uniform1i(gl.GetUniformLocation(self.id, name), value);
}

pub fn setFloat(self: Self, name: [:0]const u8, value: f32) void {
    gl.Uniform1f(gl.GetUniformLocation(self.id, name), value);
}

pub fn setMat4(self: Self, name: [:0]const u8, value: *const [16]f32) void {
    gl.UniformMatrix4fv(gl.GetUniformLocation(self.id, name), 1, gl.TRUE, value);
}

fn compileShader(shader_type: gl.@"enum", source: []const u8, diag: ?*Diagnostic) Error!gl.uint {
    const shader = gl.CreateShader(shader_type);
    errdefer gl.DeleteShader(shader);

    gl.ShaderSource(shader, 1, &[_][*]const u8{source.ptr}, null);
    gl.CompileShader(shader);

    var success: gl.int = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, @ptrCast(&success));
    if (success == gl.FALSE) {
        if (diag) |d| {
            var len: [1]gl.int = .{0};
            gl.GetShaderiv(shader, gl.INFO_LOG_LENGTH, &len);
            if (d.allocator.alloc(u8, @intCast(len[0]))) |buf| {
                gl.GetShaderInfoLog(shader, len[0], null, buf.ptr);
                d.allocator.free(d.log);
                d.log = buf;
            } else |_| {}
        }
        return switch (shader_type) {
            gl.VERTEX_SHADER => Error.VertexShader,
            gl.FRAGMENT_SHADER => Error.FragmentShader,
            else => Error.OtherShader,
        };
    }

    return shader;
}

fn linkProgram(shaders: []const gl.uint, diag: ?*Diagnostic) Error!gl.uint {
    const program = gl.CreateProgram();
    errdefer gl.DeleteProgram(program);

    for (shaders) |shader| gl.AttachShader(program, shader);
    gl.LinkProgram(program);

    var success: gl.int = undefined;
    gl.GetProgramiv(program, gl.LINK_STATUS, @ptrCast(&success));
    if (success == gl.FALSE) {
        if (diag) |d| {
            var len: [1]gl.int = .{0};
            gl.GetProgramiv(program, gl.INFO_LOG_LENGTH, &len);
            if (d.allocator.alloc(u8, @intCast(len[0]))) |buf| {
                gl.GetProgramInfoLog(program, len[0], null, buf.ptr);
                d.allocator.free(d.log);
                d.log = buf;
            } else |_| {}
        }
        return Error.LinkProgram;
    }

    return program;
}
