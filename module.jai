GLTF_Data :: struct {
  asset        : Asset;
  scene        : int;
  scenes       : [..] Scene;
  skins        : [..] Skin;
  accessors    : [..] Accessor;
  nodes        : [..] Node;
  meshes       : [..] Mesh;
  buffer_views : [..] Buffer_View;
  buffers      : [..] Buffer;
  textures     : [..] Texture;
  images       : [..] Image;
  samplers     : [..] Sampler;
  materials    : [..] Material;
}

// @todo: would like to remove everything all at once, thanks 
// to Flat_Pool or something.
gltf_free :: (gltf_data: *GLTF_Data) {
  // fini(*gltf_data._pool);
}

gltf_parse_string :: (gltf_json_string: string) -> GLTF_Data {
  data: GLTF_Data;

  if gltf_json_string == "" then return data;

  success, root := json_parse_string(gltf_json_string);
  defer json_free(root);

  if !success {
    log_error("JSON parsing failed.");
    exit(-1);
  }


  //
  // asset.
  //

  asset := get(root, "asset", .OBJECT);
  data.asset = .{
    version   = get_string(asset, "version"),
    generator = get_string(asset, "generator"),
    copyright = get_string(asset, "copyright"),
  };



  //
  // nodes.
  //

  nodes := get_array(root, "nodes");
  for node_parsed: nodes {
    node: Node;
    defer array_add(*data.nodes, node);

    node.name   = get_string(node_parsed, "name");
    node.skin   = get_int(node_parsed, "skin", -1);
    node.mesh   = get_int(node_parsed, "mesh", -1);
    node.camera = get_int(node_parsed, "camera", -1);

    matrix, has_matrix := get_array(node_parsed, "matrix");
    if has_matrix {
      node.has_matrix = true;
      for val: matrix node.matrix[it_index] = parse_float(val);
    }

    rotation, has_rotation := get_array(node_parsed, "rotation");
    if has_rotation {
      for val: rotation node.rotation[it_index] = parse_float(val);
    }

    scale, has_scale := get_array(node_parsed, "scale");
    if has_scale {
      for val: scale node.scale[it_index] = parse_float(val);
    }

    translation, has_trans := get_array(node_parsed, "translation");
    if has_trans {
      for val: translation node.translation[it_index] = parse_float(val);
    }

    children, has_children := get_array(node_parsed, "children");
    if has_children {
      for val: children array_add(*node.children, parse_int(val)); 
    }
  }



  //
  // accessors.
  //

  accessors := get_array(root, "accessors");
  for accessor_parsed: accessors {
    accessor: Accessor;
    defer array_add(*data.accessors, accessor);

    normalized, has_norm := get(accessor_parsed, "normalized", .BOOLEAN);
    if has_norm then accessor.normalized = normalized.boolean;

    accessor.stride = get_int(accessor_parsed, "byteStride");
    accessor.buffer_view = get_int(accessor_parsed, "bufferView", -1);
    accessor.byte_offset = get_int(accessor_parsed, "byteOffset");
    accessor.count       = get_int(accessor_parsed, "count");

    comp_type := get_int(accessor_parsed, "componentType");
    accessor.component_type = cast(Component_Type) comp_type;

    if get_string(accessor_parsed, "type") == {
      case "SCALAR";
        accessor.type = .SCALAR;
      case "VEC2";
        accessor.type = .VEC2;
      case "VEC3";
        accessor.type = .VEC3;
      case "VEC4";
        accessor.type = .VEC4;
      case "MAT2";
        accessor.type = .MAT2;
      case "MAT3";
        accessor.type = .MAT3;
      case "MAT4";
        accessor.type = .MAT4;
    }
  }



  //
  // scene(s).
  //

  data.scene = get_int(root, "scene", -1);

  scenes := get_array(root, "scenes");
  for scene_parsed: scenes {
    scene: Scene;
    defer array_add(*data.scenes, scene);

    name := get_string(scene_parsed, "name");

    nodes := get_array(scene_parsed, "nodes");
    for nodes array_add(*scene.nodes, parse_int(it));
  }



  //
  // skins.
  //

  skins := get_array(root, "skins");
  for skins {
    skin: Skin;
    defer array_add(*data.skins, skin);

    skin.name = get_string(it, "name");

    skin.skeleton = get_int(it, "skeleton", -1);
    skin.inverse_bind_matrices = get_int(it, "inverseBindMatrices", -1);

    joints := get_array(it, "joints");
    for joints array_add(*skin.joints, parse_int(it));
  }



  //
  // meshes.
  //

  meshes := get_array(root, "meshes");
  for mesh_parsed: meshes {
    mesh: Mesh;
    defer array_add(*data.meshes, mesh);

    name := get_string(mesh_parsed, "name");

    primitives := get_array(mesh_parsed, "primitives");
    for prim_parsed: primitives {
      primitive: Primitive;
      defer array_add(*mesh.primitives, primitive);

      mode := get_int(prim_parsed, "mode");
      primitive.mode = cast(Mode) mode;

      primitive.material         = get_int(prim_parsed, "material", -1);
      primitive.indices_accessor = get_int(prim_parsed, "indices", -1);

      attributes := get(prim_parsed, "attributes", .OBJECT);
      primitive.position_accessor   = get_int(attributes, "POSITION", -1);
      primitive.normal_accessor     = get_int(attributes, "NORMAL", -1);
      primitive.tangent_accessor    = get_int(attributes, "TANGENT", -1);
      primitive.color_accessor      = get_int(attributes, "COLOR", -1);
      primitive.joints_accessor     = get_int(attributes, "JOINTS", -1);
      primitive.weights_accessor    = get_int(attributes, "WEIGHTS", -1);
      primitive.texcoord_0_accessor = get_int(attributes, "TEXCOORD_0", -1);
      primitive.texcoord_1_accessor = get_int(attributes, "TEXCOORD_1", -1);
      primitive.texcoord_2_accessor = get_int(attributes, "TEXCOORD_2", -1);
    }
  }



  //
  // buffers.
  //

  buffers := get_array(root, "buffers");
  for buffer_parsed: buffers {
    buffer: Buffer;
    defer array_add(*data.buffers, buffer);

    buffer.byte_length = get_int(buffer_parsed, "byteLength"); 
    buffer.uri         = get_string(buffer_parsed, "uri");
  }



  //
  // buffer_views.
  //

  buffer_views := get_array(root, "bufferViews");
  for buffer_view_parsed: buffer_views {
    buffer_view: Buffer_View;
    defer array_add(*data.buffer_views, buffer_view);

    target := get_int(buffer_view_parsed, "target");
    buffer_view.target = cast(Target) target;

    buffer_view.buffer      = get_int(buffer_view_parsed, "buffer", -1);
    buffer_view.byte_length = get_int(buffer_view_parsed, "byteLength");
    buffer_view.byte_offset = get_int(buffer_view_parsed, "byteOffset");
    buffer_view.stride      = get_int(buffer_view_parsed, "byteStride");
  }



  //
  // textures.
  //

  textures := get_array(root, "textures");
  for texture_parsed : textures {
    texture: Texture;
    defer array_add(*data.textures, texture);

    texture.sampler = get_int(texture_parsed, "sampler", -1);
    texture.source= get_int(texture_parsed, "source", -1);
  }



  //
  // images.
  //

  images := get_array(root, "images");
  for image_parsed : images {
    image: Image;
    defer array_add(*data.images, image);

    image.uri         = get_string(image_parsed, "uri");
    image.mime_type   = get_string(image_parsed, "mimeType");
    image.data        = get_string(image_parsed, "data");

    image.buffer_view = get_int(image_parsed, "bufferView", -1);
  }



  //
  // samplers.
  //

  samplers := get_array(root, "samplers");
  for sampler_parsed: samplers {
    sampler: Sampler;
    defer array_add(*data.samplers, sampler);

    wrap_s, has_wrap_s := get(sampler_parsed, "wrapS", .NUMBER);
    if has_wrap_s then sampler.wrap_s = cast(Wrap_Mode) parse_int(wrap_s);

    wrap_t, has_wrap_t := get(sampler_parsed, "wrapT", .NUMBER);
    if has_wrap_t then sampler.wrap_t = cast(Wrap_Mode) parse_int(wrap_t);

    mag_filter, has_mag := get(sampler_parsed, "magFilter", .NUMBER);
    if has_mag {
      sampler.mag_filter = cast(Mag_Filter) parse_int(mag_filter);
    }

    min_filter, has_min := get(sampler_parsed, "minFilter", .NUMBER);
    if has_min {
      sampler.min_filter = cast(Min_Filter) parse_int(min_filter);
    }
  }

  materials := get_array(root, "materials");
  for material_parsed: materials {
    material: Material;
    defer array_add(*data.materials, material);

    material.name = get_string(material_parsed, "name");

    //
    // Metallic Roughness.
    //
    {
      using material.metallic_roughness;
      metal_rough := get(material_parsed, "pbrMetallicRoughness", .OBJECT);

      color_factor := get_array(metal_rough, "baseColorFactor");
      for color_factor base_color_factor[it_index] = parse_float(it);

      {
        texture, has_texture := parse_map(metal_rough, "baseColorTexture");
        if has_texture {
          has_base_color = true;
          base_color_texture = texture;
        }
      }

      {
        texture, has_texture := parse_map(metal_rough, "metallicRoughnessTexture");
        if has_texture {
          has_metallic_roughness = true;
          metallic_roughness_texture = texture;
        }
      }

      metallic_factor  = get_float(material_parsed, "metallicFactor");
      roughness_factor = get_float(material_parsed, "roughnessFactor");
    }

    normal_texture, has_normal_texture := parse_map(material_parsed, "normalTexture");
    if has_normal_texture {
      material.has_normal = true;
      material.normal_texture = normal_texture;
    }

    occlu_texture, has_occlu_texture := parse_map(material_parsed, "occlusionTexture");
    if has_occlu_texture {
      material.has_occlusion = true;
      material.occlusion_texture = occlu_texture;
    }

    emiss_texture, has_emiss_texture := parse_map(material_parsed, "emissiveTexture");
    if has_emiss_texture {
      material.has_emissive = true;
      material.emissive_texture = emiss_texture;
    }

    if get_string(material_parsed, "alphaMode") == {
      case "MASK";
        material.alpha_mode = .MASK;
      case "BLEND";
        material.alpha_mode = .BLEND;
      case "OPAQUE"; #through;
      case;
        material.alpha_mode = .OPAQUE;
    }

    material.alpha_cutoff = get_float(material_parsed, "alphaCutoff", 0.5);

    is_double_sided := get(material_parsed, "doubleSided", .BOOLEAN);
    material.is_double_sided = is_double_sided.boolean;

    // @todo: Make khr_materials_emissive_strength extension.
    // @todo: Make khr_materials_ior extension.
    // @todo: Make khr_materials_transmission extension.
  }

  for scene: data.scenes {
    for scene.nodes {
      node := *data.nodes[it];
      fill_parents(*data, node, it);
    }
  }

  return data;
}





/*
 *
 * All glTF types are written here!
 * Types are fully documented, mostly copy/pasted from the glTF specs.
 * @Note: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
 *
*/



// A node in the node hierarchy.
//
// When the node contains skin, all mesh.primitives must contain
// JOINTS_0 and WEIGHTS_0 attributes. A node may have either a matrix
// or any combination of translation/rotation/scale (TRS) properties.
// TRS properties are converted to matrices and postmultiplied in
// the T * R * S order to compose the transformation matrix.
// If none are provided, the transform is the identity.
//
// When a node is targeted for animation, referenced by 
// an animation.channel.target, matrix must not be present.
Node :: struct {
  // The user-defined name of this object.
  name : string;
  // The index of the node's parent.
  // A node is called a root node when it doesn’t have a parent.
  parent := -1;
  // The index of the mesh in this node.
  mesh   := -1;
  // The index of the camera referenced by this node.
  camera := -1;
  // The index of the skin referenced by this node.
  skin   := -1;
  // The indices of this node’s children.
  children : [..] int;
  // A floating-point 4x4 transformation matrix stored in column-major order.
  has_matrix := false;
  matrix     := float.[0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
  // The node’s unit quaternion rotation in the order (x, y, z, w),
  // where w is the scalar.
  has_rotation := false;
  rotation     := float.[0, 0, 0, 1];
  // The node’s non-uniform scale, given as the scaling factors
  // along the x, y, and z axes.
  has_scale := false;
  scale     := float.[1, 1, 1];
  // The node’s translation along the x, y, and z axes.
  has_translation := false;
  translation     := float.[0, 0, 0];
  // The weights of the instantiated morph target.
  // The number of array elements must match the number of morph targets
  // of the referenced mesh. When defined, mesh mush also be defined.
  weights := -1;
  //The index of the light referenced by this node.
  light   := -1;
}

// A buffer points to binary geometry, animation, or skins.
Buffer :: struct {
  // Relative paths are relative to the current glTF asset.
  // It could contains a data:-URI instead of a path.
  // Note: data-uri isn't implemented in this library.
  uri : string;
  // The length of the buffer in bytes.
  byte_length : int;
}

// A view into a buffer generally representing a subset of the buffer.
Buffer_View :: struct {
    // The index of the buffer.
    buffer := -1;
    // The length of the bufferView in bytes.
    byte_length : int;
    // The offset into the buffer in bytes.
    byte_offset : int;
    // The stride, in bytes.
    stride : int;
    // The hint representing the intended GPU buffer type
    // to use with this buffer view.
    target: Target;
}

/// A typed view into a buffer view that contains raw binary data.
Accessor :: struct {
  // The index of the bufferView.
  buffer_view := -1;
  // The offset relative to the start of the buffer view in bytes.
  byte_offset := 0;
  // The datatype of the accessor’s components.
  component_type : Component_Type;
  // Specifies if the accessor’s elements are scalars, vectors, or matrices.
  type : Accessor_Type;
  // Computed stride: @sizeOf(component_type) * type.
  stride  := 0;
  // The number of elements referenced by this accessor.
  count   := 0;
  // Specifies whether integer data values are normalized before usage.
  normalized := false;
}

// The root nodes of a scene.
Scene :: struct {
  // The user-defined name of this object.
  name  : string;
  // The indices of each root node.
  nodes : [..] int;
}

/// Joints and matrices defining a skin.
Skin :: struct {
  // The user-defined name of this object.
  name: string;
  // The index of the accessor containing the floating-point
  // 4x4 inverse-bind matrices.
  inverse_bind_matrices := -1;
  // The index of the node used as a skeleton root.
  skeleton := -1;
  // Indices of skeleton nodes, used as joints in this skin.
  joints : [..] int;
}


// Reference to a material texture.
// @Note: It could be a normal/occlusion/color texture!
Texture_Info :: struct {
  // The index of the texture.
  index : int;
  // The set index of texture’s TEXCOORD attribute
  // used for texture coordinate mapping.
  texcoord := 0;
  // The scalar parameter applied to each normal
  // vector of the normal texture.
  // @Note: Only if normal texture.
  scale := 1.0;
  // A scalar multiplier controlling the amount of occlusion applied.
  // @Note: Only if occlusion texture.
  strength := 1.;
}

// A set of parameter values that are used to define
// the metallic-roughness material model
// from Physically-Based Rendering methodology.
Metallic_Roughness :: struct {
    // The factors for the base color of the material.
    base_color_factor := float.[1, 1, 1, 1];
    // The base color texture.
    has_base_color     := false;
    base_color_texture : Texture_Info;
    // The factor for the metalness of the material.
    metallic_factor   := 1.;
    // The factor for the roughness of the material.
    roughness_factor  := 1.;
    // The metallic-roughness texture.
    has_metallic_roughness     := false;
    metallic_roughness_texture : Texture_Info;
}

// The material appearance of a primitive.

Material :: struct {
  // The user-defined name of this object.
  name: string;
  // A set of parameter values that are used to define
  // the metallic-roughness material model
  // from Physically Based Rendering methodology.
  metallic_roughness := Metallic_Roughness.{};
  // The tangent space normal texture.
  has_normal        := false;
  normal_texture    : Texture_Info;
  // The occlusion texture.
  has_occlusion     := false;
  occlusion_texture : Texture_Info;
  // The emissive texture.
  has_emissive      := false;
  emissive_texture  : Texture_Info;
  // The factors for the emissive color of the material.
  emissive_factor := float.[0, 0, 0];
  // The alpha rendering mode of the material.
  alpha_mode := Alpha_Mode.OPAQUE;
  // The alpha cutoff value of the material.
  alpha_cutoff := 0.5;
  // Specifies whether the material is double sided.
  // If it's false, back-face culling is enabled.
  // If it's true, back-face culling is disabled and
  // double sided lighting is enabled.
  is_double_sided := false;
  // Emissive strength multiplier for the emissive factor/texture.
  // @Note: from khr_materials_emissive_strength extension.
  emissive_strength := 1.0;
  // Index of refraction of material.
  // @Note: from khr_materials_ior extension.
  ior := 1.5;
  // The factor for the transmission of the material.
  // @Note: from khr_materials_transmission extension.
  transmission_factor := 0.0;
  // The transmission texture.
  // @Note: from khr_materials_transmission extension.
  has_transmission     := false;
  transmission_texture : Texture_Info;
}

// The material’s alpha rendering mode enumeration specifying
// the interpretation of the alpha value of the base color.
Alpha_Mode :: enum {
  // The alpha value is ignored, and the rendered output is fully opaque.
  OPAQUE;
  // The rendered output is either fully opaque or fully transparent
  // depending on the alpha value and the specified alpha_cutoff value.
  // Note: The exact appearance of the edges may be subject to
  // implementation-specific techniques such as “Alpha-to-Coverage”.
  MASK;
  // The alpha value is used to composite the source and destination areas.
  // The rendered output is combined with the background using
  // the normal painting operation (i.e. the Porter and Duff over operator).
  BLEND;
}

/// A texture and its sampler.
Texture :: struct {
  // The index of the sampler used by this texture.
  // When undefined, a sampler with repeat wrapping and
  // auto filtering should be used.
  sampler := -1;
  // The index of the image used by this texture.
  // When undefined, an extension or other mechanism should supply
  // an alternate texture source, otherwise behavior is undefined.
  source := -1;
}

/// Image data used to create a texture.
/// Image may be referenced by an uri or a buffer view index.
Image :: struct {
  // The URI (or IRI) of the image.
  uri : string;
  // The image’s media type.
  // This field must be defined when bufferView is defined.
  mime_type : string;
  // The index of the bufferView that contains the image.
  // Note: This field must not be defined when uri is defined.
  buffer_view := -1;
  // The image's data calculated from the buffer/buffer_view.
  // Only there if glb file is loaded.
  data : string;
}

Wrap_Mode :: enum u32 {
  CLAMP_TO_EDGE   :: 33071;
  MIRRORED_REPEAT :: 33648;
  REPEAT          :: 10497;
}

Min_Filter :: enum u32 {
  NEAREST                :: 9728;
  LINEAR                 :: 9729;
  NEAREST_MIPMAP_NEAREST :: 9984;
  LINEAR_MIPMAP_NEAREST  :: 9985;
  NEAREST_MIPMAP_LINEAR  :: 9986;
  LINEAR_MIPMAP_LINEAR   :: 9987;
}

Mag_Filter :: enum u32 {
  NEAREST :: 9728;
  LINEAR  :: 9729;
}

// Texture sampler properties for filtering and wrapping modes.
Sampler :: struct {
  // Magnification filter.
  mag_filter := Mag_Filter.NEAREST;
  // Minification filter.
  min_filter := Min_Filter.NEAREST;
  // S (U) wrapping mode.
  wrap_s     := Wrap_Mode.REPEAT;
  // T (U) wrapping mode.
  wrap_t     := Wrap_Mode.REPEAT;
}

Attributes :: struct {
  position_accessor   := -1;
  normal_accessor     := -1;
  tangent_accessor    := -1;
  color_accessor      := -1;
  joints_accessor     := -1;
  weights_accessor    := -1;
  texcoord_0_accessor := -1;
  texcoord_1_accessor := -1;
  texcoord_2_accessor := -1;
}

Accessor_Type :: enum {
  SCALAR;
  VEC2;
  VEC3;
  VEC4;
  MAT2;
  MAT3;
  MAT4;
}

// Enum values from GLTF 2.0 spec.
Target :: enum u32 {
  ARRAY_BUFFER         :: 34962;
  ELEMENT_ARRAY_BUFFER :: 34963;
}

// Enum values from GLTF 2.0 spec.
Component_Type :: enum u32 {
  BYTE             :: 5120;
  UNSIGNED_BYTE    :: 5121;
  SHORT            :: 5122;
  UNSIGNED_SHORT   :: 5123;
  UNSIGNED_INTEGER :: 5125;
  FLOAT            :: 5126;
}

// The topology type of primitives to render.
Mode :: enum u32 {
  POINTS         :: 0;
  LINES          :: 1;
  LINE_LOOP      :: 2;
  LINE_STRIP     :: 3;
  TRIANGLES      :: 4;
  TRIANGLE_STRIP :: 5;
  TRIANGLE_FAN   :: 6;
}

// The name of the node’s TRS property to animate.
Target_Property :: enum {
  // For the "translation" property, the values that are provided by the
  // sampler are the translation along the X, Y, and Z axes.
  TRANSLATION;
  // For the "rotation" property, the values are a quaternion
  // in the order (x, y, z, w), where w is the scalar.
  ROTATION;
  // For the "scale" property, the values are the scaling
  // factors along the X, Y, and Z axes.
  SCALE;
  // The "weights" of the Morph Targets it instantiates.
  WEIGHTS;
}

// An animation channel combines an animation sampler
// with a target property being animated.
Channel :: struct {
  // The index of a sampler in this animation used to
  // compute the value for the target.
  sampler := -1;
  // The descriptor of the animated property.
  target : struct {
    // The index of the node to animate.
    // When undefined, the animated object may be defined by an extension.
    node := -1;
    // The name of the node’s TRS property to animate, or the "weights"
    // of the Morph Targets it instantiates.
    property : Target_Property;
  };
}

// Interpolation algorithm.
Interpolation :: enum {
    // The animated values are linearly interpolated between keyframes.
    // When targeting a rotation, spherical linear interpolation (slerp)
    // should be used to interpolate quaternions.
    LINEAR;
    // The animated values remain constant to the output of the first
    // keyframe, until the next keyframe.
    STEP;
    // The animation’s interpolation is computed using a cubic
    // spline with specified tangents.
    CUBICSPLINE;
}

// An animation sampler combines timestamps
// with a sequence of output values and defines an interpolation algorithm.
Animation_Sampler :: struct {
  // The index of an accessor containing keyframe timestamps.
  input := -1;
  // The index of an accessor, containing keyframe output values.
  output := -1;
  // Interpolation algorithm.
  interpolation := Interpolation.LINEAR;
}

// A keyframe animation.
Animation :: struct {
    // The user-defined name of this object.
    name : string;
    // An array of animation channels.
    // An animation channel combines an animation sampler with a target
    // property being animated.
    // Different channels of the same animation must not have the same targets.
    channels : [..] Channel;
    // An array of animation samplers.
    // An animation sampler combines timestamps with a sequence of output
    // values and defines an interpolation algorithm.
    samplers: [..] Animation_Sampler;
}

// Geometry to be rendered with the given material.
Primitive :: struct {
  using attributes : Attributes;
  // The topology type of primitives to render.
  mode := Mode.TRIANGLES;
  // The index of the accessor that contains the vertex indices.
  indices_accessor := -1;
  // The index of the material to apply to this primitive when rendering.
  material := -1;
}

// A set of primitives to be rendered.
// Its global transform is defined by a node that references it.
Mesh :: struct {
  // The user-defined name of this object.
  name : string;
  // An array of primitives, each defining geometry to be rendered.
  primitives : [..] Primitive;
}

// Metadata about the glTF asset.
Asset :: struct {
  // The glTF version that this asset targets.
  version : string;
  // Tool that generated this glTF model. Useful for debugging.
  generator : string;
  // A copyright message suitable for display to credit the content creator.
  copyright : string;
}

// A camera’s projection.
// A node may reference a camera to apply a transform to place the camera
// in the scene.
Camera :: struct {
  // A perspective camera containing properties to create a
  // perspective projection matrix.
  Perspective :: struct {
    // The aspect ratio of the field of view.
    aspect_ratio := 0.;
    // The vertical field of view in radians.
    // This value should be less than π.
    yfo := 0.;
    // The distance to the far clipping plane.
    zfar := 0.;
    // The distance to the near clipping plane.
    znear := 0.;
  }

  // An orthographic camera containing properties to create an
  // orthographic projection matrix.
  Orthographic :: struct {
    // The horizontal magnification of the view.
    // This value must not be equal to zero.
    // This value should not be negative.
    x_mag := 0.;
    // The vertical magnification of the view.
    // This value must not be equal to zero.
    // This value should not be negative.
    y_mag := 0.;
    // The distance to the far clipping plane.
    // This value must not be equal to zero.
    // This value must be greater than znear.
    z_far := 0.;
    // The distance to the near clipping plane.
    z_near := 0.;
  }

  name : string;

  union {
    perspective  : Perspective;
    orthographic : Orthographic;
  };
}

// Specifies the light type.
Light_Type :: enum {
    // Directional lights act as though they are infinitely far away and emit light in the direction of the local -z axis.
    // This light type inherits the orientation of the node that it belongs to; position and scale are ignored
    // except for their effect on the inherited node orientation. Because it is at an infinite distance,
    // the light is not attenuated. Its intensity is defined in lumens per metre squared, or lux (lm/m^2).
    DIRECTIONAL;
    // Point lights emit light in all directions from their position in space; rotation and scale are ignored except
    // for their effect on the inherited node position.
    // The brightness of the light attenuates in a physically correct manner as distance increases from
    // the light's position (i.e. brightness goes like the inverse square of the distance).
    // Point light intensity is defined in candela, which is lumens per square radian (lm/sr).
    POINT;
    // Spot lights emit light in a cone in the direction of the local -z axis.
    // The angle and falloff of the cone is defined using two numbers, the innerConeAngle and outerConeAngle.
    // As with point lights, the brightness also attenuates in a physically correct manner as distance
    // increases from the light's position (i.e. brightness goes like the inverse square of the distance).
    // Spot light intensity refers to the brightness inside the innerConeAngle (and at the location of the light) and
    // is defined in candela, which is lumens per square radian (lm/sr).
    //
    // Engines that don't support two angles for spotlights should use outerConeAngle as the spotlight angle,
    // leaving innerConeAngle to implicitly be 0.
    SPOT;
}

// A directional, point or spot light.
Light :: struct {
  name : string;
  // Color of the light source.
  color := float.[1, 1, 1];
  // Intensity of the light source. `point` and `spot` lights use luminous intensity in candela (lm/sr)
  // while `directional` lights use illuminance in lux (lm/m^2).
  intensity := 1.;
  // Specifies the light type.
  type : Light_Type;
  // When a light's type is spot, the spot property on the light is required.
  has_spot := false;
  spot     : Light_Spot;
  // A distance cutoff at which the light's intensity may be considered to have reached zero.
  range := 0.;
}

Light_Spot :: struct {
  // Angle in radians from centre of spotlight where falloff begins.
  inner_cone_angle := 0.;
  // Angle in radians from centre of spotlight where falloff ends.
  outer_cone_angle := Math.PI / 4;
}

    
// #run {
//   Compiler :: #import "Compiler";
//   Compiler.set_build_options_dc(.{ do_output = false });

//   data := gltf_parse_string(JSON_TEST);

//   print("%\n", data);

//   gltf_free(*data);

//   report := make_leak_report();
//   // log_leak_report(report);
// }


#scope_file;

fill_parents :: (data: *GLTF_Data, node: *Node, parent_index: int) {
  for node.children {
    child_node := *data.nodes[it];
    child_node.parent = parent_index;
    fill_parents(data, child_node, it);
  }
}

parse_map :: (value: JSON_Value, key: string) -> Texture_Info, bool {
  texture_info: Texture_Info;

  texture, has_texture := get(value, key, .OBJECT);

  if has_texture {
    index    := get(texture, "index", .NUMBER);
    texcoord := get(texture, "texCoord", .NUMBER);
    texture_info = Texture_Info.{
      index      = parse_int(index),
      texcoord   = parse_int(texcoord),
    };
  }

  return texture_info, has_texture; 
}

parse_int :: (json_value: JSON_Value) -> int {
  assert(json_value.type == .NUMBER);
  return cast(int) json_value.number;
}

parse_float :: (json_value: JSON_Value) -> float {
  assert(json_value.type == .NUMBER);
  return cast(float) json_value.number;
}

get_float :: (json_val: JSON_Value, key: string, default := 0.) -> float, bool {
  val, success := get(json_val, key, .NUMBER);
  return ifx success then cast(float) val.number else default, success;
}

get_int :: (json_val: JSON_Value, key: string, default := 0) -> int, bool {
  val, success := get(json_val, key, .NUMBER);
  return ifx success then cast(int) val.number else default, success;
}

get_array :: (json_val: JSON_Value, key: string) -> []JSON_Value, bool {
  val, success := get(json_val, key, .ARRAY);
  return val.array, success;
}

get_string :: (json_val: JSON_Value, key: string) -> string {
  str := get(json_val, key, .STRING).str;
  return copy_string(str);
}

get :: (json_val     : JSON_Value, 
        key          : string, 
        expected_type: JSON_Type) -> JSON_Value, bool {

  assert(json_val.type == .OBJECT);

  table := json_val.object;
  val, success := table_find(table, key);

  // Default value when value was not found.
  if !success {
    val = JSON_Value.{};
    val.type = expected_type;

    if expected_type == {
      case .OBJECT; #through;
      case .NULL;
        val.object = null;
      case .BOOLEAN;
        val.boolean = false;
      case .NUMBER;
        val.number = 0;
      case .STRING ;
        val.str = "";
      case .ARRAY ;
        val.array = JSON_Value.[];
    }
  }

  assert(val.type == expected_type);
  return val, success;
}

// @todo: remove MEMORY_DEBUGGER.
#import "Basic";
#import "Hash_Table";
#import "Flat_Pool";
#import "jason";
#import "unicode_utils";
// #import, dir "./modules/jason";
// #import, dir "./modules/unicode_utils";
Math :: #import "Math";



// @todo: move this to build.jai (and rename build.jai to example.jai).
#scope_module

tests :: () {
  #import "File";

  gltf := read_entire_file("./test-samples/box/Box.gltf");

  data := gltf_parse_string(gltf);
  defer gltf_free(*data);

  log("%\n", data);

  assert(data.asset.generator == "COLLADA2GLTF");
  assert(data.asset.version == "2.0");
  assert(data.scene == 0);
  assert(data.scenes.count == 1);
  assert(data.nodes.count == 2);
  assert(data.meshes.count == 1);
  assert(data.accessors.count == 3);
  assert(data.materials.count == 1);
  assert(data.buffer_views.count == 2);
  assert(data.buffers.count == 1);
}
