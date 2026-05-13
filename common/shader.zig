const std = @import("std");
const gl = @import("gl");

id: gl.uint,

const Self = @This();

pub const Error = error{ VertexShader, FragmentShader, OtherShader, LinkProgram };

var info_log: [512:0]u8 = std.mem.zeroes([512:0]u8);
var info_log_len: gl.sizei = 0;

pub fn create(vertex_source: []const u8, fragment_source: []const u8) Error!Self {
    const vs = try compileShader(gl.VERTEX_SHADER, vertex_source);
    defer gl.DeleteShader(vs);

    const fs = try compileShader(gl.FRAGMENT_SHADER, fragment_source);
    defer gl.DeleteShader(fs);

    return .{ .id = try linkProgram(&.{ vs, fs }) };
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

pub fn getInfoLog() []const u8 {
    return info_log[0..@intCast(info_log_len)];
}

fn compileShader(shader_type: gl.@"enum", source: []const u8) Error!gl.uint {
    const shader = gl.CreateShader(shader_type);
    errdefer gl.DeleteShader(shader);

    gl.ShaderSource(shader, 1, &[_][*]const u8{source.ptr}, null);
    gl.CompileShader(shader);

    var success: gl.int = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, @ptrCast(&success));
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(shader, info_log.len, &info_log_len, &info_log);
        return switch (shader_type) {
            gl.VERTEX_SHADER => Error.VertexShader,
            gl.FRAGMENT_SHADER => Error.FragmentShader,
            else => Error.OtherShader,
        };
    }

    return shader;
}

fn linkProgram(shaders: []const gl.uint) Error!gl.uint {
    const program = gl.CreateProgram();
    errdefer gl.DeleteProgram(program);

    for (shaders) |shader| gl.AttachShader(program, shader);
    gl.LinkProgram(program);

    var success: gl.int = undefined;
    gl.GetProgramiv(program, gl.LINK_STATUS, @ptrCast(&success));
    if (success == gl.FALSE) {
        gl.GetProgramInfoLog(program, info_log.len, &info_log_len, &info_log);
        return Error.LinkProgram;
    }

    return program;
}
