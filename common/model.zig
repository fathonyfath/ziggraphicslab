const std = @import("std");
const gl = @import("gl");
const Shader = @import("shader.zig");
const TextureLoader = @import("texture.zig");
const assimp_c = @import("assimp_c");

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

    fn deinit(self: MeshBuffers) void {
        gl.DeleteVertexArrays(1, &[_]gl.uint{self.vao});
        gl.DeleteBuffers(1, &[_]gl.uint{self.vbo});
        gl.DeleteBuffers(1, &[_]gl.uint{self.ebo});
    }
};

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

const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,
    textures: []Texture,
    buffers: MeshBuffers,

    pub fn draw(self: Mesh, shader: Shader) void {
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

const SceneNode = struct {
    handle: *const assimp_c.aiScene,
    node: *const assimp_c.aiNode,

    const MeshIterator = struct {
        scene_node: SceneNode,
        current_index: usize,

        fn next(self: *MeshIterator) ?*const assimp_c.aiMesh {
            if (self.current_index < self.scene_node.node.mNumMeshes) {
                defer self.current_index += 1;
                return self.scene_node.handle.mMeshes[self.scene_node.node.mMeshes[self.current_index]];
            }
            return null;
        }
    };

    const ChildIterator = struct {
        scene_node: SceneNode,
        current_index: usize,

        fn next(self: *ChildIterator) ?SceneNode {
            if (self.current_index < self.scene_node.node.mNumChildren) {
                defer self.current_index += 1;
                return .{
                    .handle = self.scene_node.handle,
                    .node = self.scene_node.node.mChildren[self.current_index],
                };
            }
            return null;
        }
    };

    fn meshes(self: SceneNode) MeshIterator {
        return .{ .scene_node = self, .current_index = 0 };
    }

    fn children(self: SceneNode) ChildIterator {
        return .{ .scene_node = self, .current_index = 0 };
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

    fn root(self: ImportedScene) SceneNode {
        return .{
            .handle = self.handle,
            .node = self.handle.mRootNode.?,
        };
    }
};

const LoadContext = struct {
    allocator: std.mem.Allocator,
    texture_cache: *std.ArrayList(Texture.Cached),
    directory: []const u8,
    node: SceneNode,
};

const TextureContext = struct {
    allocator: std.mem.Allocator,
    texture_cache: *std.ArrayList(Texture.Cached),
    directory: []const u8,
    material: *const assimp_c.aiMaterial,
    texture_type: Texture.Type,
};

allocator: std.mem.Allocator,
meshes: []Mesh,

loaded_texture_ids: []u32,

const Self = @This();

pub fn init(allocator: std.mem.Allocator, path: []const u8) !Self {
    const scene = try ImportedScene.init(path);
    defer scene.deinit();

    const directory = std.Io.Dir.path.dirname(path) orelse "";

    var cache_buffer: [64]Texture.Cached = undefined;
    var texture_cache = std.ArrayList(Texture.Cached).initBuffer(&cache_buffer);
    defer for (texture_cache.items) |c| allocator.free(c.path);

    const meshes = try processNode(.{
        .allocator = allocator,
        .texture_cache = &texture_cache,
        .directory = directory,
        .node = scene.root(),
    });
    errdefer {
        for (meshes) |mesh| {
            allocator.free(mesh.vertices);
            allocator.free(mesh.indices);
            allocator.free(mesh.textures);
            mesh.buffers.deinit();
        }
        allocator.free(meshes);
    }

    const texture_ids = allocator.alloc(
        u32,
        texture_cache.items.len,
    ) catch return error.ProcessLoadedTextureIdsFailed;

    for (texture_cache.items, 0..) |c, i| {
        texture_ids[i] = c.texture.id;
    }

    return .{
        .allocator = allocator,
        .meshes = meshes,
        .loaded_texture_ids = texture_ids,
    };
}

pub fn deinit(self: Self) void {
    gl.DeleteTextures(@intCast(self.loaded_texture_ids.len), self.loaded_texture_ids.ptr);
    self.allocator.free(self.loaded_texture_ids);

    for (self.meshes) |mesh| {
        self.allocator.free(mesh.vertices);
        self.allocator.free(mesh.indices);
        self.allocator.free(mesh.textures);
        mesh.buffers.deinit();
    }
    self.allocator.free(self.meshes);
}

pub fn draw(self: Self, shader: Shader) void {
    for (self.meshes) |mesh| mesh.draw(shader);
}

fn processNode(context: LoadContext) ![]Mesh {
    var meshes: std.ArrayList(Mesh) = .empty;
    errdefer meshes.deinit(context.allocator);

    var mesh_iterator = context.node.meshes();
    while (mesh_iterator.next()) |mesh| {
        const processed_mesh = try processMesh(context, mesh);
        meshes.append(context.allocator, processed_mesh) catch return error.ProcessMeshFailed;
    }

    var child_iterator = context.node.children();
    while (child_iterator.next()) |child_node| {
        const child_meshes = try processNode(.{
            .allocator = context.allocator,
            .texture_cache = context.texture_cache,
            .directory = context.directory,
            .node = child_node,
        });
        defer context.allocator.free(child_meshes);

        meshes.appendSlice(context.allocator, child_meshes) catch return error.ProcessChildNodeFailed;
    }

    return meshes.toOwnedSlice(context.allocator) catch error.ProcessNodeFailed;
}

fn processMesh(
    context: LoadContext,
    mesh: *const assimp_c.aiMesh,
) !Mesh {
    var vertices = std.ArrayList(Vertex).initCapacity(
        context.allocator,
        mesh.mNumVertices,
    ) catch return error.ProcessVerticesFailed;
    errdefer vertices.deinit(context.allocator);

    for (0..mesh.mNumVertices) |i| {
        const mesh_vertex = mesh.mVertices[i];

        var vertex: Vertex = undefined;
        vertex.position = .{ mesh_vertex.x, mesh_vertex.y, mesh_vertex.z };

        if (mesh.mNormals) |normals| {
            vertex.normal = .{ normals[i].x, normals[i].y, normals[i].z };
        } else {
            vertex.normal = .{ 0.0, 0.0, 0.0 };
        }

        if (mesh.mTextureCoords[0]) |tex_coords| {
            vertex.tex_coords = .{ tex_coords[i].x, tex_coords[i].y };
        } else {
            vertex.tex_coords = .{ 0.0, 0.0 };
        }

        vertices.appendBounded(vertex) catch return error.ProcessVerticesFailed;
    }

    var indices = std.ArrayList(u32).empty;
    errdefer indices.deinit(context.allocator);

    for (0..mesh.mNumFaces) |i| {
        const face = mesh.mFaces[i];
        for (0..face.mNumIndices) |j| {
            indices.append(
                context.allocator,
                @intCast(face.mIndices[j]),
            ) catch return error.ProcessIndicesFailed;
        }
    }

    const textures = if (mesh.mMaterialIndex < context.node.handle.mNumMaterials) blk: {
        const material = context.node.handle.mMaterials[mesh.mMaterialIndex];

        const diffuse_maps = loadMaterialTextures(.{
            .allocator = context.allocator,
            .texture_cache = context.texture_cache,
            .directory = context.directory,
            .material = material,
            .texture_type = .diffuse,
        });
        defer context.allocator.free(diffuse_maps);

        const specular_maps = loadMaterialTextures(.{
            .allocator = context.allocator,
            .texture_cache = context.texture_cache,
            .directory = context.directory,
            .material = material,
            .texture_type = .specular,
        });
        defer context.allocator.free(specular_maps);

        break :blk std.mem.concat(
            context.allocator,
            Texture,
            &.{ diffuse_maps, specular_maps },
        ) catch return error.ProcessTexturesFailed;
    } else @as([]Texture, &.{});
    errdefer if (textures.len > 0) context.allocator.free(textures);

    const vertices_slice = vertices.toOwnedSlice(context.allocator) catch return error.ProcessVerticesFailed;
    errdefer context.allocator.free(vertices_slice);

    const indices_slice = indices.toOwnedSlice(context.allocator) catch return error.ProcessIndicesFailed;

    const mesh_buffers = MeshBuffers.init(vertices_slice, indices_slice);

    return Mesh{
        .vertices = vertices_slice,
        .indices = indices_slice,
        .textures = textures,
        .buffers = mesh_buffers,
    };
}

fn loadMaterialTextures(context: TextureContext) []Texture {
    const assimp_type: assimp_c.aiTextureType = switch (context.texture_type) {
        .diffuse => assimp_c.aiTextureType_DIFFUSE,
        .specular => assimp_c.aiTextureType_SPECULAR,
    };
    const texture_count_of_type = assimp_c.aiMaterial.aiGetMaterialTextureCount(
        context.material,
        assimp_type,
    );
    var textures = std.ArrayList(Texture).initCapacity(
        context.allocator,
        texture_count_of_type,
    ) catch return &.{};
    for (0..texture_count_of_type) |i| {
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

        const cached: ?Texture.Cached = for (context.texture_cache.items) |t| {
            if (std.mem.eql(u8, t.path, path_str)) break t;
        } else null;

        if (cached) |c| {
            textures.appendBounded(c.texture) catch {};
        } else {
            const cached_texture: Texture.Cached = .{
                .texture = .{
                    .id = textureFromFile(path_str, context.directory),
                    .type = context.texture_type,
                },
                .path = context.allocator.dupe(u8, path_str) catch continue,
            };

            context.texture_cache.appendBounded(cached_texture) catch {};
            textures.appendBounded(cached_texture.texture) catch {};
        }
    }

    return textures.toOwnedSlice(context.allocator) catch &.{};
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
