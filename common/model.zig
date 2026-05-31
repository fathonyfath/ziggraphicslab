const std = @import("std");
const gl = @import("gl");
const Shader = @import("shader.zig");
const TextureLoader = @import("texture.zig");
const assimp_c = @import("assimp_c");

const Vertex = struct {
    position: [3]f32,
    normal: [3]f32,
    tex_coords: [2]f32,
};

const Texture = struct {
    id: u32,
    type: Type,

    const Type = enum { diffuse, specular };

    const Cached = struct {
        texture: Texture,
        path: []const u8,
    };
};

const MeshBuffers = struct {
    vao: u32,
    vbo: u32,
    ebo: u32,

    fn init(vertices: []Vertex, indices: []u32) MeshBuffers {
        var vao: [1]gl.uint = undefined;
        var vbo: [1]gl.uint = undefined;
        var ebo: [1]gl.uint = undefined;

        gl.GenVertexArrays(1, &vao);
        gl.GenBuffers(1, &vbo);
        gl.GenBuffers(1, &ebo);

        gl.BindVertexArray(vao[0]);
        defer {
            gl.BindVertexArray(0);
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
            gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        }

        gl.BindBuffer(gl.ARRAY_BUFFER, vbo[0]);
        gl.BufferData(gl.ARRAY_BUFFER, @intCast(vertices.len * @sizeOf(Vertex)), vertices.ptr, gl.STATIC_DRAW);

        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo[0]);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(indices.len * @sizeOf(u32)), indices.ptr, gl.STATIC_DRAW);

        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @offsetOf(Vertex, "position"));
        gl.EnableVertexAttribArray(1);
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @offsetOf(Vertex, "normal"));
        gl.EnableVertexAttribArray(2);
        gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @offsetOf(Vertex, "tex_coords"));

        return .{
            .vao = vao[0],
            .vbo = vbo[0],
            .ebo = ebo[0],
        };
    }
};

const GlObjects = struct {
    vaos: std.ArrayList(u32) = .empty,
    buffers: std.ArrayList(u32) = .empty,
    textures: std.ArrayList(u32) = .empty,

    fn delete(self: GlObjects) void {
        gl.DeleteVertexArrays(@intCast(self.vaos.items.len), self.vaos.items.ptr);
        gl.DeleteBuffers(@intCast(self.buffers.items.len), self.buffers.items.ptr);
        gl.DeleteTextures(@intCast(self.textures.items.len), self.textures.items.ptr);
    }
};

const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,
    textures: []Texture,
    buffers: MeshBuffers,

    fn draw(self: Mesh, shader: Shader) void {
        var diffuse_number: usize = 1;
        var specular_number: usize = 1;
        var name_buffer: [64]u8 = undefined;
        for (self.textures, 0..) |texture, i| {
            gl.ActiveTexture(@intCast(gl.TEXTURE0 + i));
            const uniform_name = switch (texture.type) {
                .diffuse => blk: {
                    defer diffuse_number += 1;
                    break :blk std.fmt.bufPrintSentinel(
                        &name_buffer,
                        "material.texture_diffuse{d}",
                        .{diffuse_number},
                        0,
                    ) catch continue;
                },
                .specular => blk: {
                    defer specular_number += 1;
                    break :blk std.fmt.bufPrintSentinel(
                        &name_buffer,
                        "material.texture_specular{d}",
                        .{specular_number},
                        0,
                    ) catch continue;
                },
            };

            shader.setInt(uniform_name, @intCast(i));
            gl.BindTexture(gl.TEXTURE_2D, texture.id);
        }
        gl.ActiveTexture(gl.TEXTURE0);

        gl.BindVertexArray(self.buffers.vao);
        defer gl.BindVertexArray(0);
        gl.DrawElements(gl.TRIANGLES, @intCast(self.indices.len), gl.UNSIGNED_INT, 0);
    }
};

const ImportedScene = struct {
    handle: *const assimp_c.aiScene,

    fn init(path: []const u8) !ImportedScene {
        const scene: ?*const assimp_c.struct_aiScene = assimp_c.aiImportFile(
            path.ptr,
            assimp_c.aiProcess_Triangulate | assimp_c.aiProcess_GenSmoothNormals | assimp_c.aiProcess_FlipUVs | assimp_c.aiProcess_CalcTangentSpace,
        );

        const s = scene orelse return error.AssimpLoadFailed;

        if (s.mFlags & assimp_c.AI_SCENE_FLAGS_INCOMPLETE != 0 or s.mRootNode == null) {
            return error.AssimpLoadFailed;
        }

        return .{ .handle = s };
    }

    fn deinit(self: ImportedScene) void {
        assimp_c.aiReleaseImport(self.handle);
    }

    /// OBJ carries no transforms, so a genuine import has an all-identity node
    /// hierarchy. Asserting that makes the flat scene.mMeshes read provably safe
    /// and rejects a mislabeled non-OBJ file that assimp content-sniffed into a
    /// real hierarchy. Exact equality on purpose: identity, not approximately so.
    fn assertFlat(self: ImportedScene) error{NonIdentityTransform}!void {
        try checkNode(self.handle.mRootNode.?);
    }

    fn checkNode(node: *const assimp_c.aiNode) error{NonIdentityTransform}!void {
        if (!isIdentity(node.mTransformation)) return error.NonIdentityTransform;
        for (0..node.mNumChildren) |i| try checkNode(node.mChildren[i]);
    }

    fn isIdentity(m: assimp_c.aiMatrix4x4) bool {
        return m.a1 == 1 and m.a2 == 0 and m.a3 == 0 and m.a4 == 0 and
            m.b1 == 0 and m.b2 == 1 and m.b3 == 0 and m.b4 == 0 and
            m.c1 == 0 and m.c2 == 0 and m.c3 == 1 and m.c4 == 0 and
            m.d1 == 0 and m.d2 == 0 and m.d3 == 0 and m.d4 == 1;
    }
};

const LoadContext = struct {
    allocator: std.mem.Allocator, // arena allocator
    cache: *std.ArrayList(Texture.Cached),
    gl_objects: *GlObjects,
    scene: *const assimp_c.aiScene,
    directory: []const u8,
};

const TextureContext = struct {
    allocator: std.mem.Allocator,
    cache: *std.ArrayList(Texture.Cached),
    gl_objects: *GlObjects,
    directory: []const u8,
    material: *const assimp_c.aiMaterial,
    texture_type: Texture.Type,
};

arena: std.heap.ArenaAllocator,
gl_objects: GlObjects,
meshes: []Mesh,

const Self = @This();

pub fn init(gpa: std.mem.Allocator, path: []const u8) !Self {
    // Pre-check file format. Only support .obj for now.
    if (!std.ascii.endsWithIgnoreCase(path, ".obj")) return error.UnsupportedFormat;

    const scene = try ImportedScene.init(path);
    defer scene.deinit();
    try scene.assertFlat(); // reject any non-identity node transform (mislabeled non-OBJ)
    const handle = scene.handle;

    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit(); // declared 1st → unwinds LAST: frees all CPU memory
    const allocator = arena.allocator();

    var gl_objects: GlObjects = .{};
    errdefer gl_objects.delete(); // declared 2nd → unwinds FIRST on error:
    //   deletes GL objects while their (arena-backed) handle lists are still alive

    var cache: std.ArrayList(Texture.Cached) = .empty;

    const context: LoadContext = .{
        .allocator = allocator,
        .cache = &cache,
        .gl_objects = &gl_objects,
        .scene = handle,
        .directory = std.Io.Dir.path.dirname(path) orelse "",
    };

    // Mesh count is known exactly, and OBJ is flat — just walk scene.mMeshes.
    const meshes = try allocator.alloc(Mesh, handle.mNumMeshes);
    for (0..handle.mNumMeshes) |i| meshes[i] = try processMesh(context, handle.mMeshes[i]);

    // Everything is allocated; only now move the arena into the result.
    return .{
        .arena = arena,
        .gl_objects = gl_objects,
        .meshes = meshes,
    };
}

pub fn deinit(self: Self) void {
    self.gl_objects.delete(); // Cleanup GL objects first
    self.arena.deinit(); // Then cleanup CPU memory
}

pub fn draw(self: Self, shader: Shader) void {
    for (self.meshes) |mesh| mesh.draw(shader);
}

fn processMesh(
    context: LoadContext,
    mesh: *const assimp_c.aiMesh,
) !Mesh {
    // Vertex count is known exactly — allocate once, fill by index.
    const vertices = try context.allocator.alloc(Vertex, mesh.mNumVertices);
    for (0..mesh.mNumVertices) |i| {
        const v = mesh.mVertices[i];
        vertices[i] = .{
            .position = .{ v.x, v.y, v.z },
            .normal = if (mesh.mNormals) |n| .{ n[i].x, n[i].y, n[i].z } else .{ 0.0, 0.0, 0.0 },
            .tex_coords = if (mesh.mTextureCoords[0]) |t| .{ t[i].x, t[i].y } else .{ 0.0, 0.0 },
        };
    }

    // aiProcess_Triangulate converts polygons to triangles but leaves point and
    // line primitives intact, so a mesh isn't guaranteed all-triangles — which
    // is why this used to be a bound, not an exact count. We render with
    // DrawElements(TRIANGLES), so require triangle-only; then the index count is
    // exactly mNumFaces*3 and indices get the same flat alloc as vertices.
    if (mesh.mPrimitiveTypes != assimp_c.aiPrimitiveType_TRIANGLE) return error.NonTriangleMesh;
    const indices = try context.allocator.alloc(u32, @as(usize, mesh.mNumFaces) * 3);
    for (0..mesh.mNumFaces) |i| {
        const face = mesh.mFaces[i];
        indices[i * 3 + 0] = @intCast(face.mIndices[0]);
        indices[i * 3 + 1] = @intCast(face.mIndices[1]);
        indices[i * 3 + 2] = @intCast(face.mIndices[2]);
    }

    var textures: std.ArrayList(Texture) = .empty;
    if (mesh.mMaterialIndex < context.scene.mNumMaterials) {
        const material = context.scene.mMaterials[mesh.mMaterialIndex];
        try loadMaterialTextures(.{
            .allocator = context.allocator,
            .cache = context.cache,
            .gl_objects = context.gl_objects,
            .directory = context.directory,
            .material = material,
            .texture_type = .diffuse,
        }, &textures);

        try loadMaterialTextures(.{
            .allocator = context.allocator,
            .cache = context.cache,
            .gl_objects = context.gl_objects,
            .directory = context.directory,
            .material = material,
            .texture_type = .specular,
        }, &textures);
    }

    // Reserve the handle slots *before* creating the GL objects, so the only
    // fallible step here runs while nothing exists on the GL side yet. After
    // GenBuffers the appends are infallible, so every handle is tracked.
    try context.gl_objects.vaos.ensureUnusedCapacity(context.allocator, 1);
    try context.gl_objects.buffers.ensureUnusedCapacity(context.allocator, 2);
    const buffers = MeshBuffers.init(vertices, indices);
    context.gl_objects.vaos.appendAssumeCapacity(buffers.vao);
    context.gl_objects.buffers.appendAssumeCapacity(buffers.vbo);
    context.gl_objects.buffers.appendAssumeCapacity(buffers.ebo);

    return .{
        .vertices = vertices,
        .indices = indices,
        .textures = textures.items,
        .buffers = buffers,
    };
}

fn loadMaterialTextures(context: TextureContext, out: *std.ArrayList(Texture)) !void {
    const assimp_type: assimp_c.aiTextureType = switch (context.texture_type) {
        .diffuse => assimp_c.aiTextureType_DIFFUSE,
        .specular => assimp_c.aiTextureType_SPECULAR,
    };
    const count = assimp_c.aiMaterial.aiGetMaterialTextureCount(context.material, assimp_type);

    // Reserve headroom for this batch on every list it might touch.
    try out.ensureTotalCapacity(context.allocator, count);
    try context.cache.ensureTotalCapacity(context.allocator, count);
    try context.gl_objects.textures.ensureTotalCapacity(context.allocator, count);

    for (0..count) |i| {
        var path: assimp_c.aiString = undefined;

        _ = assimp_c.aiMaterial.aiGetMaterialTexture(
            context.material,
            assimp_type,
            @intCast(i),
            &path,
            null,
            null,
            null,
            null,
            null,
            null,
        );

        const path_str = path.data[0..path.length];

        const cached: ?Texture = for (context.cache.items) |c| {
            if (std.mem.eql(u8, c.path, path_str)) break c.texture;
        } else null;

        if (cached) |tex| {
            out.appendAssumeCapacity(tex);
            continue;
        }

        const id = textureFromFile(path_str, context.directory);
        if (id == 0) continue; // missing / corrupt file — skip, non-fatal
        const tex: Texture = .{ .id = id, .type = context.texture_type };

        context.gl_objects.textures.appendAssumeCapacity(id); // track before anything can fail
        out.appendAssumeCapacity(tex);
        context.cache.appendAssumeCapacity(.{
            .texture = tex,
            .path = try context.allocator.dupe(u8, path_str),
        });
    }
}

fn textureFromFile(path: []const u8, directory: []const u8) gl.uint {
    var path_buf: [std.Io.Dir.max_path_bytes:0]u8 = undefined;
    const full_path = std.fmt.bufPrintSentinel(
        &path_buf,
        "{f}",
        .{std.Io.Dir.path.fmtJoin(&.{ directory, path })},
        0,
    ) catch return 0;
    const texture = TextureLoader.loadFromFile(full_path) catch return 0;
    return texture.id;
}
