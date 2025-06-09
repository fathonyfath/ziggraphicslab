const std = @import("std");
const gl = @import("gl");

id: gl.uint,

const Self = @This();

pub const ShaderError = error{ VertexShaderSource, FragmentShaderSource, OtherShaderSource, LinkProgram };

var info_log: [512:0]u8 = std.mem.zeroes([512:0]u8);
var info_log_slice: []const u8 = undefined;

pub fn create(vertex_source: []const u8, fragment_source: []const u8) ShaderError!Self {
    const vertex_shader = try createShader(gl.VERTEX_SHADER, vertex_source);
    defer gl.DeleteShader(vertex_shader);
    errdefer gl.DeleteShader(vertex_shader);

    const fragment_shader = try createShader(gl.FRAGMENT_SHADER, fragment_source);
    defer gl.DeleteShader(fragment_shader);
    errdefer gl.DeleteShader(fragment_shader);

    const program = try createProgram(&.{ vertex_shader, fragment_shader });

    return .{ .id = program };
}

pub fn use(self: Self) void {
    gl.UseProgram(self.id);
}

pub fn delete(self: Self) void {
    gl.DeleteProgram(self.id);
}

pub fn getInfoLog() []const u8 {
    return info_log_slice;
}

fn createShader(shader_type: gl.@"enum", source: []const u8) ShaderError!gl.uint {
    const shader = gl.CreateShader(shader_type);
    errdefer gl.DeleteShader(shader);

    gl.ShaderSource(shader, 1, &[_][*]const u8{source.ptr}, null);
    gl.CompileShader(shader);

    var success: gl.int = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        var length: gl.sizei = undefined;
        gl.GetShaderInfoLog(shader, info_log.len, &length, &info_log);
        info_log_slice = info_log[0..@intCast(length)];

        const error_type = blk: {
            switch (shader_type) {
                gl.VERTEX_SHADER => break :blk ShaderError.VertexShaderSource,
                gl.FRAGMENT_SHADER => break :blk ShaderError.FragmentShaderSource,
                else => break :blk ShaderError.OtherShaderSource,
            }
        };
        return error_type;
    }

    return shader;
}

fn createProgram(shaders: []const gl.uint) ShaderError!gl.uint {
    const program = gl.CreateProgram();
    errdefer gl.DeleteProgram(program);

    for (shaders) |shader| {
        gl.AttachShader(program, shader);
    }
    gl.LinkProgram(program);

    var success: gl.int = undefined;
    gl.GetProgramiv(program, gl.LINK_STATUS, &success);

    if (success == gl.FALSE) {
        var length: gl.sizei = undefined;
        gl.GetProgramInfoLog(program, info_log.len, &length, &info_log);
        info_log_slice = info_log[0..@intCast(length)];

        return ShaderError.LinkProgram;
    }

    return program;
}
