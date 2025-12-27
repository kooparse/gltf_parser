GLTF_Data :: struct {
  filepath     : string;

  asset        : GLTF_Asset;
  scene        : int;
  scenes       : [..] GLTF_Scene;
  skins        : [..] GLTF_Skin;
  accessors    : [..] GLTF_Accessor;
  nodes        : [..] GLTF_Node;
  meshes       : [..] GLTF_Mesh;
  buffer_views : [..] GLTF_Buffer_View;
  buffers      : [..] GLTF_Buffer;
  textures     : [..] GLTF_Texture;
  images       : [..] GLTF_Image;
  samplers     : [..] GLTF_Sampler;
  materials    : [..] GLTF_Material;
  cameras      : [..] GLTF_Camera;
  lights       : [..] GLTF_Light;
  animations   : [..] GLTF_Animation;

  using meta : struct {
    // Used to prevent loading buffers when it's a glb file
    // because it's already loaded in memory.
    is_glb : bool;
    // Used in order
    allocator : Allocator;
  };
}

gltf_parse_string :: (gltf_buffer: string) -> GLTF_Data {
  data: GLTF_Data;

  data.allocator = context.allocator;

  if gltf_buffer == "" then return data;

  if is_glb(gltf_buffer) {
    return parse_glb_string(gltf_buffer);
  }

  success, root := json_parse_string(gltf_buffer);
  defer json_free(root);

  if !success then crash("JSON parsing failed.");


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
    node: GLTF_Node;
    defer array_add(*data.nodes, node);

    node.name   = get_string(node_parsed, "name");
    node.skin   = get_int(node_parsed, "skin", -1);
    node.mesh   = get_int(node_parsed, "mesh", -1);
    node.camera = get_int(node_parsed, "camera", -1);
    node.extras = cast(*void, get_object(node_parsed, "extras"));

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

    node.local_transform = get_local_transform(node);

    children, has_children := get_array(node_parsed, "children");
    if has_children {
      for val: children array_add(*node.children, parse_int(val));
    }

    extensions, has_extension := get(node_parsed, "extensions", .OBJECT);
    if has_extension {
      khr_lights, has_khr_l := get(extensions, "KHR_lights_punctual", .OBJECT);
      if has_khr_l then node.light = get_int(khr_lights, "light", -1);
    }
  }



  //
  // buffers.
  //

  buffers := get_array(root, "buffers");
  for buffer_parsed: buffers {
    buffer: GLTF_Buffer;
    defer array_add(*data.buffers, buffer);

    buffer.byte_length = get_int(buffer_parsed, "byteLength");
    buffer.uri         = get_string(buffer_parsed, "uri");
    buffer.extras = cast(*void, get_object(buffer_parsed, "extras"));
  }



  //
  // buffer_views.
  //

  buffer_views := get_array(root, "bufferViews");
  for buffer_view_parsed: buffer_views {
    buffer_view: GLTF_Buffer_View;
    defer array_add(*data.buffer_views, buffer_view);

    target := get_int(buffer_view_parsed, "target");
    buffer_view.target = cast(GLTF_Target) target;

    buffer_view.buffer      = get_int(buffer_view_parsed, "buffer", -1);
    buffer_view.byte_length = get_int(buffer_view_parsed, "byteLength");
    buffer_view.byte_offset = get_int(buffer_view_parsed, "byteOffset");
    buffer_view.extras = cast(*void, get_object(buffer_view_parsed, "extras"));

    stride, has_stride := get_int(buffer_view_parsed, "byteStride");
    if has_stride {
      buffer_view.has_stride = true;
      buffer_view.stride = stride;
    }
  }



  //
  // accessors.
  //

  accessors := get_array(root, "accessors");
  for accessor_parsed: accessors {
    accessor: GLTF_Accessor;
    defer array_add(*data.accessors, accessor);

    normalized, has_norm := get(accessor_parsed, "normalized", .BOOLEAN);
    if has_norm then accessor.normalized = normalized.boolean;

    accessor.buffer_view = get_int(accessor_parsed, "bufferView", -1);
    accessor.byte_offset = get_int(accessor_parsed, "byteOffset");
    accessor.count       = get_int(accessor_parsed, "count");
    accessor.extras   = cast(*void, get_object(accessor_parsed, "extras"));

    comp_type := get_int(accessor_parsed, "componentType");
    accessor.component_type = cast(GLTF_Component_Type) comp_type;

    if get_string(accessor_parsed, "type") == {
      case "SCALAR"; accessor.type = .SCALAR;
      case "VEC2";   accessor.type = .VEC2;
      case "VEC3";   accessor.type = .VEC3;
      case "VEC4";   accessor.type = .VEC4;
      case "MAT2";   accessor.type = .MAT2;
      case "MAT3";   accessor.type = .MAT3;
      case "MAT4";   accessor.type = .MAT4;
    }

    for value: get_array(accessor_parsed, "min") {
      value_to_store := parse_float(value);
      union_value    := *accessor.min;
      set_min_max_value(accessor.type, value_to_store, union_value, it_index);
    }

    for value: get_array(accessor_parsed, "max") {
      value_to_store := parse_float(value);
      union_value    := *accessor.max;
      set_min_max_value(accessor.type, value_to_store, union_value, it_index);
    }

    if accessor.buffer_view != -1 {
      buffer_view := data.buffer_views[accessor.buffer_view];

      if buffer_view.has_stride {
        accessor.stride = buffer_view.stride;
        continue;
      }
    }

    accessor.stride = get_component_info(accessor).stride;

  }



  //
  // scene(s).
  //

  data.scene = get_int(root, "scene", -1);

  scenes := get_array(root, "scenes");
  for scene_parsed: scenes {
    scene: GLTF_Scene;
    defer array_add(*data.scenes, scene);

    scene.name = get_string(scene_parsed, "name");
    scene.extras   = cast(*void, get_object(scene_parsed, "extras"));

    nodes := get_array(scene_parsed, "nodes");
    for nodes array_add(*scene.nodes, parse_int(it));
  }



  //
  // skins.
  //

  skins := get_array(root, "skins");
  for skins {
    skin: GLTF_Skin;
    defer array_add(*data.skins, skin);

    skin.name = get_string(it, "name");
	skin.extras = cast(*void, get_object(it, "extras"));

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
    mesh: GLTF_Mesh;
    defer array_add(*data.meshes, mesh);

    mesh.name = get_string(mesh_parsed, "name");
	mesh.extras = cast(*void, get_object(mesh_parsed, "extras"));

    primitives := get_array(mesh_parsed, "primitives");
    for prim_parsed: primitives {
      primitive: GLTF_Primitive;
      defer array_add(*mesh.primitives, primitive);

      mode, ok := get_int(prim_parsed, "mode");
      if !ok {
        primitive.mode = .TRIANGLES;
      } else {
        primitive.mode = cast(GLTF_Mode) mode;
      }

      primitive.material         = get_int(prim_parsed, "material", -1);
      primitive.indices_accessor = get_int(prim_parsed, "indices", -1);

      attributes := get(prim_parsed, "attributes", .OBJECT);
      primitive.position_accessor   = get_int(attributes, "POSITION", -1);
      primitive.normal_accessor     = get_int(attributes, "NORMAL", -1);
      primitive.tangent_accessor    = get_int(attributes, "TANGENT", -1);
      primitive.color_accessor      = get_int(attributes, "COLOR", -1);
      primitive.joints_accessor     = get_int(attributes, "JOINTS_0", -1);
      primitive.weights_accessor    = get_int(attributes, "WEIGHTS_0", -1);
      primitive.texcoord_0_accessor = get_int(attributes, "TEXCOORD_0", -1);
      primitive.texcoord_1_accessor = get_int(attributes, "TEXCOORD_1", -1);
      primitive.texcoord_2_accessor = get_int(attributes, "TEXCOORD_2", -1);

      primitive.extras = cast(*void, get_object(prim_parsed, "extras"));

      targets, has_targets := get_array(prim_parsed, "targets");
      if has_targets {
      	for target_parsed: targets {
      		morph_target: GLTF_Morph_Target;

      		morph_target.position_accessor = get_int(target_parsed, "POSITION", -1);
      		morph_target.normal_accessor = get_int(target_parsed, "NORMAL", -1);
      		morph_target.tangent_accessor = get_int(target_parsed, "TANGENT", -1);

      		array_add(*primitive.targets, morph_target);
      	}
      }
    }
  }



  //
  // textures.
  //

  textures := get_array(root, "textures");
  for texture_parsed : textures {
    texture: GLTF_Texture;
    defer array_add(*data.textures, texture);
    texture.sampler = get_int(texture_parsed, "sampler", -1);
    texture.source  = get_int(texture_parsed, "source", -1);
  }



  //
  // images.
  //

  images := get_array(root, "images");
  for image_parsed : images {
    image: GLTF_Image;
    defer array_add(*data.images, image);

    image.uri         = get_string(image_parsed, "uri");
    image.mime_type   = get_string(image_parsed, "mimeType");
    image.data        = get_string(image_parsed, "data");
    image.extras = cast(*void, get_object(image_parsed, "extras"));

    image.buffer_view = get_int(image_parsed, "bufferView", -1);
  }



  //
  // samplers.
  //

  samplers := get_array(root, "samplers");
  for sampler_parsed: samplers {
    sampler: GLTF_Sampler;
    defer array_add(*data.samplers, sampler);

    wrap_s, has_wrap_s := get(sampler_parsed, "wrapS", .NUMBER);
    if has_wrap_s then sampler.wrap_s = cast(GLTF_Wrap_Mode) parse_int(wrap_s);

    wrap_t, has_wrap_t := get(sampler_parsed, "wrapT", .NUMBER);
    if has_wrap_t then sampler.wrap_t = cast(GLTF_Wrap_Mode) parse_int(wrap_t);

    mag_filter, has_mag := get(sampler_parsed, "magFilter", .NUMBER);
    if has_mag {
      sampler.mag_filter = cast(GLTF_Mag_Filter) parse_int(mag_filter);
    }

    min_filter, has_min := get(sampler_parsed, "minFilter", .NUMBER);
    if has_min {
      sampler.min_filter = cast(GLTF_Min_Filter) parse_int(min_filter);
    }

    sampler.extras = cast(*void, get_object(sampler_parsed, "extras"));
  }



  //
  // animations.
  //

  animations := get_array(root, "animations");
  for animation_sampler: animations {
    animation: GLTF_Animation;
    defer array_add(*data.animations, animation);

    animation.name = get_string(animation_sampler, "name");
    animation.extras = cast(*void, get_object(animation_sampler, "extras"));

    samplers := get_array(animation_sampler, "samplers");
    for sampler_parsed: samplers {
      animation_sampler: GLTF_Animation_Sampler;
      defer array_add(*animation.samplers, animation_sampler);

      animation_sampler.input  = get_int(sampler_parsed, "input", -1);
      animation_sampler.output = get_int(sampler_parsed, "output", -1);

      if get_string(sampler_parsed, "interpolation") == {
        case "LINEAR";
          animation_sampler.interpolation = .LINEAR;
        case "STEP";
          animation_sampler.interpolation = .STEP;
        case "CUBICSPLINE";
          animation_sampler.interpolation = .CUBICSPLINE;
      }
    }

    channels := get_array(animation_sampler, "channels");
    for channel_parsed: channels {
      channel: GLTF_Channel;
      defer array_add(*animation.channels, channel);

      channel.sampler = get_int(channel_parsed, "sampler", -1);

      target := get(channel_parsed, "target", .OBJECT);
      channel.target.node = get_int(target, "node", -1);

      if get_string(target, "path") == {
        case "translation";
          channel.target.property = .TRANSLATION;
        case "rotation";
          channel.target.property = .ROTATION;
        case "scale";
          channel.target.property = .SCALE;
        case "weights";
          channel.target.property = .WEIGHTS;
      }
    }
  }



  //
  // materials
  //

  materials := get_array(root, "materials");
  for material_parsed: materials {
    material: GLTF_Material;
    defer array_add(*data.materials, material);

    material.name = get_string(material_parsed, "name");
    material.extras = cast(*void, get_object(material_parsed, "extras"));

    //
    // Metallic Roughness.
    //
    {
      using material.metallic_roughness;
      metal_rough := get(material_parsed, "pbrMetallicRoughness", .OBJECT);

      color_factor := get_array(metal_rough, "baseColorFactor");
      for color_factor base_color_factor[it_index] = parse_float(it);

      {
        texture, has_texture := parse_texture_info(metal_rough, "baseColorTexture");
        if has_texture {
          has_base_color = true;
          base_color_texture = texture;
        }
      }

      {
        texture, has_texture := parse_texture_info(metal_rough, "metallicRoughnessTexture");
        if has_texture {
          has_metallic_roughness = true;
          metallic_roughness_texture = texture;
        }
      }

      metallic_factor  = get_float(material_parsed, "metallicFactor");
      roughness_factor = get_float(material_parsed, "roughnessFactor");
    }

    normal_texture, has_normal_texture := parse_texture_info(material_parsed, "normalTexture");
    if has_normal_texture {
      material.has_normal = true;
      material.normal_texture = normal_texture;
    }

    occlu_texture, has_occlu_texture := parse_texture_info(material_parsed, "occlusionTexture");
    if has_occlu_texture {
      material.has_occlusion = true;
      material.occlusion_texture = occlu_texture;
    }

    emiss_texture, has_emiss_texture := parse_texture_info(material_parsed, "emissiveTexture");
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


    //
    // Extensions
    //

    extensions, has_extension := get(material_parsed, "extensions", .OBJECT);

    if has_extension {
      // Parse khr_materials_emissive_strength extension.
      khr_emissive_strength, has_emissive_str := get(extensions, "KHR_materials_emissive_strength", .OBJECT);

      if has_emissive_str {
        material.emissive_strength = get_float(khr_emissive_strength, "emissiveStrength");
      }

      // Parse khr_materials_ior extension.
      khr_ior, has_ior := get(extensions, "KHR_materials_ior", .OBJECT);
      if has_ior then material.ior = get_float(khr_ior, "ior");

      // Parse khr_materials_transmission extension.
      khr_transmission, has_transmission := get(extensions, "KHR_materials_transmission", .OBJECT);
      if has_transmission {
        material.transmission_factor = get_float(khr_transmission, "transmissionFactor");
        transmission_texture, has_transmission_texture := parse_texture_info(khr_transmission, "transmissionTexture");
        if has_transmission_texture {
          material.has_transmission = true;
          material.transmission_texture = transmission_texture;
        }
      }
    }
  }



  //
  // cameras.
  //

  cameras := get_array(root, "cameras");
  for camera_parsed: cameras {
    camera := GLTF_Camera.{ name = get_string(camera_parsed, "name") };
    defer array_add(*data.cameras, camera);

    type := get_string(camera_parsed, "type");

    if type == {
      case "perspective";
        parsed := get(camera_parsed, "perspective", .OBJECT);
        camera.type = .PERSPECTIVE;
        camera.perspective = .{
          aspect_ratio = get_float(parsed, "aspectRatio"),
          y_fov        = get_float(parsed, "yfov"),
          z_far        = get_float(parsed, "zfar"),
          z_near       = get_float(parsed, "znear"),
        };
      case "orthographic";
        parsed := get(camera_parsed, "orthographic", .OBJECT);
        camera.type = .ORTHOGRAPHIC;
        camera.orthographic = .{
          x_mag  = get_float(parsed, "xmag"),
          y_mag  = get_float(parsed, "ymag"),
          z_far  = get_float(parsed, "zfar"),
          z_near = get_float(parsed, "znear"),
        };
    }
  }



  //
  // khr_lights_punctual.
  //

  extensions, has_extensions := get(root, "extensions", .OBJECT);
  if has_extensions {
    khr_lights, has_khr_l := get(extensions, "KHR_lights_punctual", .OBJECT);

    if has_khr_l {
      lights := get_array(khr_lights, "lights");

      for light_parsed: lights {
        light := GLTF_Light.{ name = get_string(light_parsed, "name") };
        defer array_add(*data.lights, light);

        color := get_array(light_parsed, "color");
        for color light.color[it_index] = parse_float(it);

        light.intensity = get_float(light_parsed, "intensity");
        light.range     = get_float(light_parsed, "range");

        if get_string(light_parsed, "type") == {
          case "directional";
            light.type = .DIRECTIONAL;
          case "point";
            light.type = .POINT;
          case "spot";
            light.type = .SPOT;
            spot := get(light_parsed, "spot", .OBJECT);
            light.spot.inner_cone_angle = get_float(spot, "innerConeAngle");
            light.spot.outer_cone_angle = get_float(spot, "outerConeAngle");
        }
      }
    }
  }




  // Fill parents in nodes, to easily construct a hierarchy.
  for scene: data.scenes {
    for scene.nodes {
      node := *data.nodes[it];
      fill_parents(*data, node, it);
    }
  }


  // Once all nodes are set, we could process the world_transform.
  for * data.nodes {
    it.world_transform = get_world_transform(*data, it);
  }

  return data;
}

gltf_parse_file :: (filepath: string) -> GLTF_Data {
  path, basename, extension := path_decomp(filepath);

  gltf_string, success := read_entire_file(filepath);
  defer free(gltf_string);

  if !success {
    crash("Reading % failed. Are you sure that your file exists?", filepath);
  }

  gltf_data := ifx extension == "glb"
               then parse_glb_string(gltf_string)
               else gltf_parse_string(gltf_string);

  gltf_data.filepath = copy_string(filepath);

  return gltf_data;
}

gltf_load_buffers :: (gltf_data: *GLTF_Data) -> bool {
  if gltf_data.is_glb return true;

  folder_path := gltf_data.filepath;
  folder_path.count = find_index_from_right(gltf_data.filepath, #char "/") + 1;

  success := true;

  for * buffer: gltf_data.buffers {
    bin_path := join(folder_path, buffer.uri);
    defer free(bin_path);

    data, success := read_entire_file(bin_path ,, gltf_data.allocator);
    if !success then success = false;

    buffer.data = data;
  }

  return success;
}

// @todo: Should free the string.
gltf_debug_print :: (gltf_data: GLTF_Data) {
  builder: String_Builder;
  defer free_buffers(*builder);

  PRINT_FORMAT :: #string DONE

    =========

    Debug information for glTF at %.

    % scenes(s) was found.
    % node(s) was found.
    % camera(s) was found.
    % buffer(s) was found.
    % skin(s) was found.
    % meshes(s) was found.
    % images(s) was found.
  DONE

  print_to_builder(*builder, PRINT_FORMAT,
        gltf_data.filepath,
        gltf_data.scenes.count,
        gltf_data.nodes.count,
        gltf_data.cameras.count,
        gltf_data.buffers.count,
        gltf_data.skins.count,
        gltf_data.meshes.count,
        gltf_data.images.count);

  append(*builder, "\n");
  print_to_builder(*builder, "    % animation(s) was found.\n", gltf_data.animations.count);

  for gltf_data.animations {
    print_to_builder(*builder, "      - '%' (at index %)\n", it.name, it_index);
  }

  append(*builder, "\n\n");

  message := builder_to_string(*builder ,, temp);
  log(message);
}


GLTF_Component_Info :: struct {
  size   : int; // Component's size in bytes.
  count  : int; // Number of component.
  stride : int; // Computed count * size.
}

get_component_info :: (accessor: GLTF_Accessor) -> GLTF_Component_Info {
  info : GLTF_Component_Info;

  if #complete accessor.component_type == {
    case .BYTE;             info.size = size_of(s8);
    case .UNSIGNED_BYTE;    info.size = size_of(u8);
    case .SHORT;            info.size = size_of(s16);
    case .UNSIGNED_SHORT;   info.size = size_of(u16);
    case .UNSIGNED_INTEGER; info.size = size_of(u32);
    case .FLOAT;            info.size = size_of(float);
  }

  if #complete accessor.type == {
    case .VEC2;
      info.count = 2;
      info.stride = 2 * info.size;
    case .VEC3;
      info.count = 3;
      info.stride = 3 * info.size;
    case .VEC4; #through;
    case .MAT2;
      info.count = 4;
      info.stride = 4 * info.size;
    case .MAT3;
      info.count = 9;
      info.stride = 9 * info.size;
    case .MAT4;
      info.count = 16;
      info.stride = 16 * info.size;
    case .SCALAR;
      info.count = 1;
      info.stride = info.size;
  }

  return info;
}

// @note: I would love to find a better way for doing that, if someone
//        knows something, let me know!
read_buffer_from_accessor :: (gltf_data: *GLTF_Data, accessor: GLTF_Accessor, list: *[..] $type) {

  if #complete accessor.component_type == {
    case .BYTE;
      temp := get_buffer_data(gltf_data, accessor, s8);
      defer array_free(temp);

      for temp array_add(list, cast(type) it);

    case .UNSIGNED_BYTE;
      temp := get_buffer_data(gltf_data, accessor, u8);
      defer array_free(temp);

      for temp array_add(list, cast(type) it);

    case .SHORT;
      temp := get_buffer_data(gltf_data, accessor, s16);
      defer array_free(temp);

      for temp array_add(list, cast(type) it);
    case .UNSIGNED_SHORT;
      temp := get_buffer_data(gltf_data, accessor, u16);
      defer array_free(temp);

      for temp array_add(list, cast(type) it);

    case .UNSIGNED_INTEGER;
      temp := get_buffer_data(gltf_data, accessor, u32);
      defer array_free(temp);

      for temp array_add(list, cast(type) it);

    case .FLOAT;
      temp := get_buffer_data(gltf_data, accessor, float);
      defer array_free(temp);

      for temp array_add(list, cast(type) it);
  }
}

// Arrays allocate memory
get_extra :: (extras: GLTF_Extras, name: string, $T: Type) -> bool, T
{
	#run {
		SUPPORTED_TYPES :: Type.[
			float,
			float64,
			bool,
			string,
			[] float,
			[] float64,
			[] bool,
			[] string
		];
		is_supported: bool;
		for SUPPORTED_TYPES {
			if T == it {
				is_supported = true;
				break;
			}
		}
		assert(is_supported, "Type % is an unsupported type for get_extra\nSupported types:\n%\n", T, SUPPORTED_TYPES);
	}

	extra: T;
	if !extras return false, extra;

	extra_json: JSON_Value;
	success: bool;

	extras_object := cast(*Table(string, JSON_Value), extras);
	success, extra_json = table_find(extras_object, name);
	if !success return false, extra;

	if extra_json.type == {
		case .NULL;
			return false, extra;
		case .OBJECT;
			return false, extra;
	}

	#if T == {
		case float;
			if extra_json.type != .NUMBER return false, extra;
			extra = get_as(extra_json, float);
		case float64;
			if extra_json.type != .NUMBER return false, extra;
			extra = get_as(extra_json, float64);
		case bool;
			if extra_json.type != .BOOLEAN return false, extra;
			extra = get_as(extra_json, bool);
		case string;
			if extra_json.type != .STRING return false, extra;
			extra = get_as(extra_json, string);
		// Maybe I can do some Type_Info and Type_Info_Array checking here
		// but just doing a resizable call and setting it back to the result
		// looks more concise?
		case [] float;
			if extra_json.type != .ARRAY return false, extra;
			json_arr := get_as(extra_json, [] JSON_Value);
			if json_arr.count < 1 || json_arr[0].type != .NUMBER
				return false, extra;
			arr := resizable(extra);
			array_reserve(*arr, json_arr.count);
			for json_arr {
				array_add(*arr, cast(float, it.number));
			}
			extra = arr;
		case [] float64;
			if extra_json.type != .ARRAY return false, extra;
			json_arr := get_as(extra_json, [] JSON_Value);
			if json_arr.count < 1 || json_arr[0].type != .NUMBER
				return false, extra;
			arr := resizable(extra);
			array_reserve(*arr, json_arr.count);
			for json_arr {
				array_add(*arr, it.number);
			}
			extra = arr;
		case [] bool;
			if extra_json.type != .ARRAY return false, extra;
			json_arr := get_as(extra_json, [] JSON_Value);
			if json_arr.count < 1 || json_arr[0].type != .BOOLEAN
				return false, extra;
			arr := resizable(extra);
			array_reserve(*arr, json_arr.count);
			for json_arr {
				array_add(*arr, it.boolean);
			}
			extra = arr;
		case [] string;
			if extra_json.type != .ARRAY return false, extra;
			json_arr := get_as(extra_json, [] JSON_Value);
			if json_arr.count < 1 || json_arr[0].type != .STRING
				return false, extra;
			arr := resizable(extra);
			array_reserve(*arr, json_arr.count);
			for json_arr {
				array_add(*arr, it.str);
			}
			extra = arr;
	}

	return success, extra;
}

/*
 *
 * All glTF types are here!
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
GLTF_Node :: struct {
  // The user-defined name of this object.
  name : string;
  // The index of the node's parent.
  // A node is called a root node when it doesn’t have a parent.
  parent := -1;
  world_transform := Matrix4_Identity;
  local_transform := Matrix4_Identity;
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
  // Application-specific data.
  extras : GLTF_Extras;
}

// A buffer points to binary geometry, animation, or skins.
GLTF_Buffer :: struct {
  // Relative paths are relative to the current glTF asset.
  // It could contains a data:-URI instead of a path.
  // Note: data-uri isn't implemented in this library.
  uri : string;
  // The length of the buffer in bytes.
  byte_length : int;
  // Buffer's data once gltf_load_data was called.
  data : string;
  // Application-specific data.
  extras : GLTF_Extras;
}

// A view into a buffer generally representing a subset of the buffer.
GLTF_Buffer_View :: struct {
  // The index of the buffer.
  buffer := -1;
  // The length of the bufferView in bytes.
  byte_length : int;
  // The offset into the buffer in bytes.
  byte_offset : int;
  // The stride, in bytes.
  has_stride := false;
  stride : int;
  // The hint representing the intended GPU buffer type
  // to use with this buffer view.
  target: GLTF_Target;
  // Application-specific data.
  extras : GLTF_Extras;
}

/// A typed view into a buffer view that contains raw binary data.
GLTF_Accessor :: struct {
  // The index of the bufferView.
  buffer_view := -1;
  // The offset relative to the start of the buffer view in bytes.
  byte_offset := 0;
  // The datatype of the accessor’s components.
  component_type : GLTF_Component_Type;
  // Specifies if the accessor’s elements are scalars, vectors, or matrices.
  type : GLTF_Accessor_Type;
  // Computed stride: size_of(component_type) * type.
  // @Note: If buffer_view is set, it's the buffer_view's stride.
  stride  := 0;
  // The number of elements referenced by this accessor.
  count   := 0;
  // Specifies whether integer data values are normalized before usage.
  normalized := false;
  // Contain per-component minimum and maximum values.
  // @todo: Would be better with tagged union for this.
  min : GLTF_Min_Max_Value;
  max : GLTF_Min_Max_Value;
  // Application-specific data.
  extras : GLTF_Extras;
}

// Refer to a minimum or maximum value.
GLTF_Min_Max_Value :: union {
  scalar: float;
  vec2: Vector2;
  vec3: Vector3;
  vec4: Vector4;
  mat2: Matrix2;
  mat3: Matrix3;
  mat4: Matrix4;
}

// The root nodes of a scene.
GLTF_Scene :: struct {
  // The user-defined name of this object.
  name  : string;
  // The indices of each root node.
  nodes : [..] int;
  // Application-specific data.
  extras : GLTF_Extras;
}

/// Joints and matrices defining a skin.
GLTF_Skin :: struct {
  // The user-defined name of this object.
  name: string;
  // The index of the accessor containing the floating-point
  // 4x4 inverse-bind matrices.
  inverse_bind_matrices := -1;
  // The index of the node used as a skeleton root.
  skeleton := -1;
  // Indices of skeleton nodes, used as joints in this skin.
  joints : [..] int;
  // Application-specific data.
  extras : GLTF_Extras;
}


// Reference to a material texture.
// @Note: It could be a normal/occlusion/color texture!
GLTF_Texture_Info :: struct {
  // The index of the texture.
  index := -1;
  // The set index of texture’s TEXCOORD attribute
  // used for texture coordinate mapping.
  texcoord := 0;
  // The scalar parameter applied to each normal
  // vector of the normal texture.
  // @Note: Only if normal texture.
  normal_scale := 1.0;
  // A scalar multiplier controlling the amount of occlusion applied.
  // @Note: Only if occlusion texture.
  strength := 1.;

  has_khr_texture_transform : bool;
  khr_texture_transform : struct {
    // The offset of the UV coordinate origin as a factor of the texture dimensions.
    offset   := float.[0, 0];
    // Rotate the UVs by this many radians counter-clockwise around the origin.
    // This is equivalent to a similar rotation of the image clockwise.
    rotation :  float;
    // The scale factor applied to the components of the UV coordinates.
    scale    := float.[1., 1.];
    // Overrides the textureInfo texCoord value if supplied,
    // and if this extension is supported.
    texcoord := -1;
  };
}

// A set of parameter values that are used to define
// the metallic-roughness material model
// from Physically-Based Rendering methodology.
GLTF_Metallic_Roughness :: struct {
    // The factors for the base color of the material.
    base_color_factor := float.[1, 1, 1, 1];
    // The base color texture.
    has_base_color     := false;
    base_color_texture : GLTF_Texture_Info;
    // The factor for the metalness of the material.
    metallic_factor   := 1.;
    // The factor for the roughness of the material.
    roughness_factor  := 1.;
    // The metallic-roughness texture.
    has_metallic_roughness     := false;
    metallic_roughness_texture : GLTF_Texture_Info;
    // Application-specific data.
  	extras : GLTF_Extras;
}

// The material appearance of a primitive.

GLTF_Material :: struct {
  // The user-defined name of this object.
  name: string;
  // A set of parameter values that are used to define
  // the metallic-roughness material model
  // from Physically Based Rendering methodology.
  metallic_roughness := GLTF_Metallic_Roughness.{};
  // The tangent space normal texture.
  has_normal        := false;
  normal_texture    : GLTF_Texture_Info;
  // The occlusion texture.
  has_occlusion     := false;
  occlusion_texture : GLTF_Texture_Info;
  // The emissive texture.
  has_emissive      := false;
  emissive_texture  : GLTF_Texture_Info;
  // The factors for the emissive color of the material.
  emissive_factor := float.[0, 0, 0];
  // The alpha rendering mode of the material.
  alpha_mode := GLTF_Alpha_Mode.OPAQUE;
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
  transmission_texture : GLTF_Texture_Info;
  // Application-specific data.
  extras : GLTF_Extras;
}

// The material’s alpha rendering mode enumeration specifying
// the interpretation of the alpha value of the base color.
GLTF_Alpha_Mode :: enum {
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
GLTF_Texture :: struct {
  // The index of the sampler used by this texture.
  // When undefined, a sampler with repeat wrapping and
  // auto filtering should be used.
  sampler := -1;
  // The index of the image used by this texture.
  // When undefined, an extension or other mechanism should supply
  // an alternate texture source, otherwise behavior is undefined.
  source := -1;
  // Application-specific data.
  extras : GLTF_Extras;
}

/// Image data used to create a texture.
/// Image may be referenced by an uri or a buffer view index.
GLTF_Image :: struct {
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
  // Application-specific data.
  extras : GLTF_Extras;
}

GLTF_Wrap_Mode :: enum u32 {
  CLAMP_TO_EDGE   :: 33071;
  MIRRORED_REPEAT :: 33648;
  REPEAT          :: 10497;
}

GLTF_Min_Filter :: enum u32 {
  NEAREST                :: 9728;
  LINEAR                 :: 9729;
  NEAREST_MIPMAP_NEAREST :: 9984;
  LINEAR_MIPMAP_NEAREST  :: 9985;
  NEAREST_MIPMAP_LINEAR  :: 9986;
  LINEAR_MIPMAP_LINEAR   :: 9987;
}

GLTF_Mag_Filter :: enum u32 {
  NEAREST :: 9728;
  LINEAR  :: 9729;
}

// Texture sampler properties for filtering and wrapping modes.
GLTF_Sampler :: struct {
  // Magnification filter.
  mag_filter := GLTF_Mag_Filter.NEAREST;
  // Minification filter.
  min_filter := GLTF_Min_Filter.NEAREST;
  // S (U) wrapping mode.
  wrap_s     := GLTF_Wrap_Mode.REPEAT;
  // T (U) wrapping mode.
  wrap_t     := GLTF_Wrap_Mode.REPEAT;
  // Application-specific data.
  extras : GLTF_Extras;
}

GLTF_Attributes :: struct {
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

GLTF_Accessor_Type :: enum {
  SCALAR;
  VEC2;
  VEC3;
  VEC4;
  MAT2;
  MAT3;
  MAT4;
}

// Enum values from GLTF 2.0 spec.
GLTF_Target :: enum u32 {
  ARRAY_BUFFER         :: 34962;
  ELEMENT_ARRAY_BUFFER :: 34963;
}

// Enum values from GLTF 2.0 spec.
GLTF_Component_Type :: enum u32 {
  BYTE             :: 5120;
  UNSIGNED_BYTE    :: 5121;
  SHORT            :: 5122;
  UNSIGNED_SHORT   :: 5123;
  UNSIGNED_INTEGER :: 5125;
  FLOAT            :: 5126;
}

// The topology type of primitives to render.
GLTF_Mode :: enum u32 {
  POINTS         :: 0;
  LINES          :: 1;
  LINE_LOOP      :: 2;
  LINE_STRIP     :: 3;
  TRIANGLES      :: 4;
  TRIANGLE_STRIP :: 5;
  TRIANGLE_FAN   :: 6;
}

// The name of the node’s TRS property to animate.
GLTF_Target_Property :: enum {
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
GLTF_Channel :: struct {
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
    property : GLTF_Target_Property;
  };
}

// Interpolation algorithm.
GLTF_Interpolation :: enum {
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
GLTF_Animation_Sampler :: struct {
  // The index of an accessor containing keyframe timestamps.
  input := -1;
  // The index of an accessor, containing keyframe output values.
  output := -1;
  // Interpolation algorithm.
  interpolation := GLTF_Interpolation.LINEAR;
}

// A keyframe animation.
GLTF_Animation :: struct {
    // The user-defined name of this object.
    name : string;
    // An array of animation channels.
    // An animation channel combines an animation sampler with a target
    // property being animated.
    // Different channels of the same animation must not have the same targets.
    channels : [..] GLTF_Channel;
    // An array of animation samplers.
    // An animation sampler combines timestamps with a sequence of output
    // values and defines an interpolation algorithm.
    samplers: [..] GLTF_Animation_Sampler;
    // Application-specific data.
  	extras : GLTF_Extras;
}

// Geometry to be rendered with the given material.
GLTF_Primitive :: struct {
  using attributes : GLTF_Attributes;
  // The topology type of primitives to render.
  mode := GLTF_Mode.TRIANGLES;
  // The index of the accessor that contains the vertex indices.
  indices_accessor := -1;
  // The index of the material to apply to this primitive when rendering.
  material := -1;
  // An array of morph targets.
  targets: [..] GLTF_Morph_Target;
  // Application-specific data.
  extras : GLTF_Extras;
}

// A set of primitives to be rendered.
// Its global transform is defined by a node that references it.
GLTF_Mesh :: struct {
  // The user-defined name of this object.
  name : string;
  // An array of primitives, each defining geometry to be rendered.
  primitives : [..] GLTF_Primitive;
  // Application-specific data.
  extras : GLTF_Extras;
}

// Metadata about the glTF asset.
GLTF_Asset :: struct {
  // The glTF version that this asset targets.
  version : string;
  // Tool that generated this glTF model. Useful for debugging.
  generator : string;
  // A copyright message suitable for display to credit the content creator.
  copyright : string;
  // Application-specific data.
  extras : GLTF_Extras;
}

// A camera’s projection.
// A node may reference a camera to apply a transform to place the camera
// in the scene.
GLTF_Camera :: struct {
  name : string;
  type : enum { PERSPECTIVE; ORTHOGRAPHIC; };
  // Application-specific data.
  extras : GLTF_Extras;

  // A perspective camera containing properties to create a
  // perspective projection matrix.
  Perspective :: struct {
    // The aspect ratio of the field of view.
    aspect_ratio := 0.;
    // The vertical field of view in radians.
    // This value should be less than π.
    y_fov := 0.;
    // The distance to the far clipping plane.
    z_far := 0.;
    // The distance to the near clipping plane.
    z_near := 0.;
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

  union {
    perspective  : Perspective;
    orthographic : Orthographic;
  };
}

// Specifies the light type.
GLTF_Light_Type :: enum {
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
GLTF_Light :: struct {
  name : string;
  // Specifies the light type.
  type : GLTF_Light_Type;
  // Color of the light source.
  color := float.[1, 1, 1];
  // Intensity of the light source. `point` and `spot` lights use luminous intensity in candela (lm/sr)
  // while `directional` lights use illuminance in lux (lm/m^2).
  intensity := 1.;
  // When a light's type is spot, the spot property on the light is required.
  using spot : GLTF_Light_Spot;
  // A distance cutoff at which the light's intensity may be considered to have reached zero.
  range := 0.;
}

GLTF_Light_Spot :: struct {
  // Angle in radians from centre of spotlight where falloff begins.
  inner_cone_angle := 0.;
  // Angle in radians from centre of spotlight where falloff ends.
  outer_cone_angle := PI / 4;
}

GLTF_Morph_Target :: struct {
	position_accessor := -1;
	normal_accessor := -1;
	tangent_accessor := -1;
}

GLTF_Extras :: *void;

#scope_file;

get_buffer_data :: (gltf_data: *GLTF_Data, accessor: GLTF_Accessor, $type: Type) -> [..]type {
  list : [..]type;

  buffer_view := gltf_data.buffer_views[accessor.buffer_view];
  buffer      := gltf_data.buffers[buffer_view.buffer];

  component_info  := get_component_info(accessor);

  component_size  := size_of(type);
  component_count := component_info.count;
  stride          := accessor.stride / component_size;

  offset := (buffer_view.byte_offset + accessor.byte_offset) / component_size;

  for data_index: 0..accessor.count - 1 {
    buffer_data := cast(*type) buffer.data.data;
    data := (buffer_data + offset + data_index * stride);

    for component_index: 0..component_count - 1 {
      array_add(*list, data[component_index]);
    }
  }

  return list;
}


fill_parents :: (data: *GLTF_Data, node: *GLTF_Node, parent_index: int) {
  for node.children {
    child_node := *data.nodes[it];
    child_node.parent = parent_index;
    fill_parents(data, child_node, it);
  }
}

get_local_transform :: (using node: GLTF_Node) -> Matrix4 {
  if has_matrix {
    transform : Matrix4 = ---;
    for matrix transform.floats[it_index] = it;

    // Careful here, we transpose the matrix because glTF
    // store column-major matrices.
    return transpose(transform);
  }

  t := make_vector3(translation);
  r := Quaternion.{rotation[0], rotation[1], rotation[2], rotation[3]};
  s := make_vector3(scale);

  return make_translation_matrix4(t) * rotation_matrix(Matrix4, r) * make_scale_matrix4(s);
}

get_world_transform :: (gltf_data: *GLTF_Data, node: GLTF_Node) -> Matrix4 {
  parent_index := node.parent;
  node_transform := node.local_transform;

  while parent_index != -1 {
    parent := gltf_data.nodes[parent_index];
    node_transform = parent.local_transform * node_transform;
    parent_index = parent.parent;
  }

  return node_transform;
}

is_glb :: (buffer: string) -> bool {
  GLB_MAGIC_NUMBER : u32 : 0x46546C67; // 'gltf' in ASCII.

  fields := cast(*u32) buffer.data;
  return fields[0] == GLB_MAGIC_NUMBER;
}

// Documentation for parsing glTF binaries:
// https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#binary-gltf-layout
parse_glb_string :: (glb_buffer: string) -> GLTF_Data {
  GLB_CHUNK_TYPE_JSON : u32 : 0x4E4F534A; // 'JSON' in ASCII.
  GLB_CHUNK_TYPE_BIN  : u32 : 0x004E4942; // 'BIN' in ASCII.

  fields := cast(*u32) glb_buffer.data;

  // The 12-byte header consists of three 4-byte entries:
  magic   := fields[0];
  version := fields[1];
  length  := fields[2];

  if !is_glb(glb_buffer) {
    crash("First 4-byte are not equal to magic number.");
  }

  if version != 2 {
    crash("Only glTF spec v2 is supported.");
  }

  /*

      After having parsed the header, we get two chunk (in this order):
        - JSON data
        - Binary data

      Each chunk has the same following structure:
        - chunk length (u32)
        - chunk type (u32)
        - chunk data (array of data)

  */

  json_string : string;
  bin_string  : string;


  // We first parse the JSON data:

  if fields[4] != GLB_CHUNK_TYPE_JSON {
    crash("First chunk must be JSON data.");
  }

  json_length := fields[3];
  json_offset := 5 * size_of(u32);

  json_string.data  = glb_buffer.data + json_offset;
  json_string.count = json_length;


  // Now, we parse the BIN data:

  bin_chunk  := cast(*u32) (json_string.data + json_string.count);

  if bin_chunk[1] != GLB_CHUNK_TYPE_BIN {
    crash("Second chunk must be BIN data.");
  }

  bin_length       := bin_chunk[0];
  bin_string.data  = json_string.data + json_string.count + (2 * size_of(u32));
  bin_string.count = bin_length;



  // Parse the data:

  gltf_data := gltf_parse_string(json_string);
  gltf_data.is_glb = true;

  assert(gltf_data.buffers.count == 1); // Only 1 buffer.

  buffer_data    := copy_string(bin_string);
  gltf_data.buffers[0].data = buffer_data;

  for * image: gltf_data.images {
    if image.buffer_view == -1 then continue;

    buffer_view := gltf_data.buffer_views[image.buffer_view];

    image_data : string;
    image_data.data  = buffer_data.data + buffer_view.byte_offset;
    image_data.count = buffer_view.byte_length;
    image.data = image_data;
  }

  return gltf_data;
}

parse_texture_info :: (value: JSON_Value, key: string) -> GLTF_Texture_Info, bool {
  texture_info: GLTF_Texture_Info;

  texture, has_texture := get(value, key, .OBJECT);

  if has_texture {
    index    := get(texture, "index", .NUMBER);
    texcoord := get(texture, "texCoord", .NUMBER);
    normal_scale, has_normal_scale := get(texture, "scale", .NUMBER);

    texture_info = GLTF_Texture_Info.{
      index        = parse_int(index),
      texcoord     = parse_int(texcoord),
      normal_scale = ifx has_normal_scale then parse_float(normal_scale) else 1.,
    };

    extensions, has_extension := get(texture, "extensions", .OBJECT);
    if has_extension {
      khr, has_khr:= get(extensions, "KHR_texture_transform", .OBJECT);
      if has_khr {
        texture_info.has_khr_texture_transform = true;

        khr_offset := get_array(khr, "offset");
        for val: khr_offset texture_info.khr_texture_transform.offset[it_index] = parse_float(val);

        khr_scale := get_array(khr, "scale");
        for val: khr_scale texture_info.khr_texture_transform.scale[it_index] = parse_float(val);

        khr_rotation := get_float(khr, "rotation");
        texture_info.khr_texture_transform.rotation = khr_rotation;

        khr_texcoord, has_khr_texcoord := get_int(khr, "texCoord");
        if has_khr_texcoord then texture_info.khr_texture_transform.texcoord = khr_texcoord;
      }
    }

  }

  return texture_info, has_texture;
}

set_min_max_value :: (type: GLTF_Accessor_Type, value_to_store: float, union_value: *GLTF_Min_Max_Value, array_index: int) {
  if #complete type == {
    case .SCALAR;
      union_value.scalar = value_to_store;
    case .VEC2;
      array := union_value.vec2.component.data;
      array[array_index] = value_to_store;
    case .VEC3;
      array := union_value.vec3.component.data;
      array[array_index] = value_to_store;
    case .VEC4;
      array := union_value.vec4.component.data;
      array[array_index] = value_to_store;
    case .MAT2;
      array := union_value.mat2.floats.data;
      array[array_index] = value_to_store;
    case .MAT3;
      array := union_value.mat3.floats.data;
      array[array_index] = value_to_store;
    case .MAT4;
      array := union_value.mat4.floats.data;
      array[array_index] = value_to_store;
  }
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

get_object :: (json_val: JSON_Value, key: string) -> *JSON_Object {
	val := get(json_val, key, .OBJECT);
	return val.object;
}

get :: (json_val     : JSON_Value,
        key          : string,
        expected_type: JSON_Type) -> JSON_Value, bool {

  assert(json_val.type == .OBJECT);

  table := json_val.object;
  success, val := table_find(table, key);

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

crash :: (msg: string, args: ..Any) {
  log_error(msg, args);
  exit(-1);
}

#import "Basic";
#import "File";
#import "String";
#import "Hash_Table";
#import "Math";

#import, dir "modules/jaison";