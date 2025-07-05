const std = @import("std");
const zcs = @import("zcs");

const Entities = zcs.Entities;
const Entity = zcs.Entity;
const CmdBuf = zcs.CmdBuf;

const Transform = zcs.ext.Transform2D;
const Node = zcs.ext.Node;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        _ = gpa.deinit();
    }

    var entities = try Entities.init(.{ .gpa = allocator });
    defer entities.deinit(allocator);

    var command_buffer = try CmdBuf.init(.{
        .name = "cb",
        .gpa = allocator,
        .es = &entities,
    });
    defer command_buffer.deinit(allocator, &entities);

    const entity = Entity.reserve(&command_buffer);
    entity.add(&command_buffer, Transform, .{});
    entity.add(&command_buffer, Node, .{});

    Transform.Exec.immediate(&entities, &command_buffer);

    var iterator = entities.iterator(struct {
        transform: *Transform,
        node: *Node,
    });

    while (iterator.next(&entities)) |view| {
        std.log.debug("view: {}", .{view});
    }
}
