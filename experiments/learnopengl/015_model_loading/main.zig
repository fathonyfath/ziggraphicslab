const std = @import("std");
const common = @import("common");
const sdl = common.sdl;
const gl = common.gl;
const Shader = common.Shader;
const Camera = common.Camera;
const zm = common.zmath;
const assimp_c = @import("assimp_c");

const vertex_shader_source =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aNormal;
    \\layout (location = 2) in vec2 aTexCoords;
    \\
    \\out vec2 TexCoords;
    \\
    \\uniform mat4 model;
    \\uniform mat4 view;
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\    TexCoords = aTexCoords;
    \\    gl_Position = projection * view * model * vec4(aPos, 1.0);
    \\}
;

const fragment_shader_source =
    \\#version 330 core
    \\
    \\in vec2 TexCoords;
    \\
    \\out vec4 FragColor;
    \\
    \\uniform sampler2D texture_diffuse1;
    \\
    \\void main() {
    \\    FragColor = texture(texture_diffuse1, TexCoords);
    \\}
;

fn textureFromFile(path: []const u8, directory: []const u8) gl.uint {
    var path_buf: [std.Io.Dir.max_path_bytes:0]u8 = undefined;
    const full_path = std.fmt.bufPrintSentinel(
        &path_buf,
        "{f}",
        .{std.Io.Dir.path.fmtJoin(&.{ directory, path })},
        0,
    ) catch return 0;
    const texture = common.Texture.loadFromFile(full_path) catch return 0;
    return texture.id;
}

const Vertex = struct {
    position: [3]f32,
    normal: [3]f32,
    tex_coords: [2]f32,
};

const TextureType = enum { diffuse, specular };

const Texture = struct {
    id: u32,
    type: TextureType,
};

const CachedTexture = struct {
    id: u32,
    type: TextureType,
    path: []const u8,
};

const Mesh = struct {
    vertices: []Vertex,
    indices: []u32,
    textures: []Texture,

    _vao: u32,
    _vbo: u32,
    _ebo: u32,

    pub fn init(vertices: []Vertex, indices: []u32, textures: []Texture) Mesh {
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
            .vertices = vertices,
            .indices = indices,
            .textures = textures,
            ._vao = vao[0],
            ._vbo = vbo[0],
            ._ebo = ebo[0],
        };
    }

    pub fn deinit(self: Mesh) void {
        gl.DeleteVertexArrays(1, &[_]gl.uint{self._vao});
        gl.DeleteBuffers(1, &[_]gl.uint{self._vbo});
        gl.DeleteBuffers(1, &[_]gl.uint{self._ebo});
    }

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
                        "texture_diffuse{d}",
                        .{diffuse_number},
                        0,
                    ) catch continue;
                },
                .specular => blk: {
                    defer specular_number += 1;
                    break :blk std.fmt.bufPrintSentinel(
                        &name_buffer,
                        "texture_specular{d}",
                        .{specular_number},
                        0,
                    ) catch continue;
                },
            };

            shader.setInt(uniform_name, @intCast(i));
            gl.BindTexture(gl.TEXTURE_2D, texture.id);
        }
        gl.ActiveTexture(gl.TEXTURE0);

        gl.BindVertexArray(self._vao);
        defer gl.BindVertexArray(0);
        gl.DrawElements(gl.TRIANGLES, @intCast(self.indices.len), gl.UNSIGNED_INT, 0);
    }
};

const Model = struct {
    allocator: std.mem.Allocator,
    meshes: []Mesh,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !Model {
        const scene: ?*const assimp_c.struct_aiScene = assimp_c.aiImportFile(
            path.ptr,
            assimp_c.aiProcess_Triangulate | assimp_c.aiProcess_GenSmoothNormals | assimp_c.aiProcess_FlipUVs | assimp_c.aiProcess_CalcTangentSpace,
        );

        const s = scene orelse return error.AssimpLoadFailed;
        defer assimp_c.aiReleaseImport(s);

        if (s.mFlags & assimp_c.AI_SCENE_FLAGS_INCOMPLETE != 0 or s.mRootNode == null) {
            return error.AssimpLoadFailed;
        }
        const directory = std.Io.Dir.path.dirname(path) orelse "";

        var cache_buf: [64]CachedTexture = undefined;
        var texture_cache: std.ArrayList(CachedTexture) = .initBuffer(&cache_buf);
        defer for (texture_cache.items) |c| allocator.free(c.path);

        var model: Model = .{
            .allocator = allocator,
            .meshes = &.{},
        };

        model.meshes = model.processNode(&texture_cache, directory, s.mRootNode.?, s);

        return model;
    }

    pub fn deinit(self: Model) void {
        for (self.meshes) |mesh| {
            self.allocator.free(mesh.vertices);
            self.allocator.free(mesh.indices);
            self.allocator.free(mesh.textures);
            mesh.deinit();
        }
        self.allocator.free(self.meshes);
    }

    pub fn draw(self: Model, shader: Shader) void {
        for (self.meshes) |mesh| mesh.draw(shader);
    }

    fn processNode(
        self: *Model,
        texture_cache: *std.ArrayList(CachedTexture),
        directory: []const u8,
        node: *const assimp_c.aiNode,
        scene: *const assimp_c.aiScene,
    ) []Mesh {
        var meshes: std.ArrayList(Mesh) = .empty;
        for (0..node.mNumMeshes) |i| {
            const mesh: *const assimp_c.aiMesh = scene.mMeshes[node.mMeshes[i]];
            meshes.append(self.allocator, self.processMesh(texture_cache, directory, mesh, scene)) catch {};
        }
        for (0..node.mNumChildren) |i| {
            const child_meshes = self.processNode(texture_cache, directory, node.mChildren[i], scene);
            defer self.allocator.free(child_meshes);

            meshes.appendSlice(self.allocator, child_meshes) catch {};
        }
        return meshes.toOwnedSlice(self.allocator) catch &.{};
    }
    fn processMesh(
        self: *Model,
        texture_cache: *std.ArrayList(CachedTexture),
        directory: []const u8,
        mesh: *const assimp_c.aiMesh,
        scene: *const assimp_c.aiScene,
    ) Mesh {
        var vertices = std.ArrayList(Vertex).initCapacity(self.allocator, mesh.mNumVertices) catch return undefined;
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

            vertices.appendBounded(vertex) catch {};
        }

        var indices = std.ArrayList(u32).empty;
        for (0..mesh.mNumFaces) |i| {
            const face = mesh.mFaces[i];
            for (0..face.mNumIndices) |j| {
                indices.append(self.allocator, @intCast(face.mIndices[j])) catch {};
            }
        }

        if (mesh.mMaterialIndex >= 0) {
            const material = scene.mMaterials[mesh.mMaterialIndex];
            const diffuse_maps = self.loadMaterialTextures(
                texture_cache,
                directory,
                material,
                assimp_c.aiTextureType_DIFFUSE,
                .diffuse,
            );
            defer self.allocator.free(diffuse_maps);

            const specular_maps = self.loadMaterialTextures(
                texture_cache,
                directory,
                material,
                assimp_c.aiTextureType_SPECULAR,
                .specular,
            );
            defer self.allocator.free(specular_maps);

            const all_textures_const = std.mem.concat(self.allocator, Texture, &.{ diffuse_maps, specular_maps }) catch &.{};
            const all_textures: []Texture = @constCast(all_textures_const);

            return Mesh.init(
                vertices.toOwnedSlice(self.allocator) catch &.{},
                indices.toOwnedSlice(self.allocator) catch &.{},
                all_textures,
            );
        }

        return Mesh.init(
            vertices.toOwnedSlice(self.allocator) catch &.{},
            indices.toOwnedSlice(self.allocator) catch &.{},
            &.{},
        );
    }

    fn loadMaterialTextures(
        self: *Model,
        texture_cache: *std.ArrayList(CachedTexture),
        directory: []const u8,
        material: *const assimp_c.aiMaterial,
        material_type: assimp_c.aiTextureType,
        type_name: TextureType,
    ) []Texture {
        const texture_count_of_type = assimp_c.aiMaterial.aiGetMaterialTextureCount(material, material_type);
        var textures = std.ArrayList(Texture).initCapacity(self.allocator, texture_count_of_type) catch return &.{};
        for (0..texture_count_of_type) |i| {
            var path: assimp_c.aiString = undefined;
            _ = assimp_c.aiMaterial.aiGetMaterialTexture(
                material,
                material_type,
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
            const cached: ?CachedTexture = for (texture_cache.items) |t| {
                if (std.mem.eql(u8, t.path, path_str)) break t;
            } else null;

            if (cached) |c| {
                const texture: Texture = .{
                    .id = c.id,
                    .type = c.type,
                };
                textures.appendBounded(texture) catch {};
            } else {
                const texture: Texture = .{
                    .id = textureFromFile(path_str, directory),
                    .type = type_name,
                };
                const cached_texture: CachedTexture = .{
                    .id = texture.id,
                    .type = texture.type,
                    .path = self.allocator.dupe(u8, path_str) catch continue,
                };
                texture_cache.appendBounded(cached_texture) catch {};
                textures.appendBounded(texture) catch {};
            }
        }

        return textures.toOwnedSlice(self.allocator) catch &.{};
    }
};

pub fn main(init: std.process.Init) !void {
    const stbi = @import("stbi");
    stbi.init(init.io, init.gpa);
    stbi.setFlipVerticallyOnLoad(true);
    defer stbi.deinit();

    const window = try sdl.Window.create(.{
        .title = "015 - Model Loading",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    const model = try Model.init(init.gpa, "common/assets/backpack/backpack.obj");
    defer model.deinit();

    const shader = try Shader.create(vertex_shader_source, fragment_shader_source, null);
    defer shader.delete();

    _ = sdl.c.SDL_SetWindowRelativeMouseMode(window.handle, true);

    gl.Enable(gl.DEPTH_TEST);

    var camera = Camera.init(.{ 0.0, 0.0, 3.0 }, 800.0 / 600.0);

    var last_ticks = sdl.c.SDL_GetTicks();
    var event: sdl.c.SDL_Event = undefined;
    var running = true;

    while (running) {
        const current_ticks = sdl.c.SDL_GetTicks();
        const delta_time: f32 = @as(f32, @floatFromInt(current_ticks - last_ticks)) / 1000.0;
        last_ticks = current_ticks;

        var input = Camera.CameraInput{};

        while (sdl.c.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.c.SDL_EVENT_QUIT => running = false,
                sdl.c.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.scancode) {
                        sdl.c.SDL_SCANCODE_ESCAPE => running = false,
                        else => if (Camera.feedEvent(&input, &event)) continue,
                    }
                },
                else => if (Camera.feedEvent(&input, &event)) continue,
            }
        }

        Camera.feedKeyboard(&input);
        camera.update(input, delta_time);
        camera.applyCapture(window);

        gl.ClearColor(0.1, 0.1, 0.1, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        shader.use();
        camera.applyToShader(shader);

        const model_mat = zm.matToArr(zm.identity());
        shader.setMat4("model", &model_mat);

        model.draw(shader);

        window.swap();
    }
}
