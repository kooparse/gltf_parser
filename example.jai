#import "Basic"()(MEMORY_DEBUGGER=true);
#import "File";
#import "Compiler";

#import, file "module.jai";

#run {
  main();
  set_build_options_dc(.{ do_output = false });
}

main :: () {
  check_print();

  check_leaks();

  simple_tests();
  rigged_tests();
  animation_tests();
  camera_tests();
  khr_lights_punctual_tests();
  glb_file_tests();
  data_read_tests();

  print("\n");
  log("All tests and examples were executed without errors!");
  print("\n");
}

check_print :: () {
  data := gltf_parse_file("./test-samples/rigged_simple/RiggedSimple.gltf");
  defer gltf_free(*data);

  gltf_debug_print(data);
}

check_leaks :: () {
  data := gltf_parse_file("./test-samples/box/Box.gltf");
  gltf_load_buffers(*data);

  gltf_free(*data);

  report := make_leak_report();
  log_leak_report(report);
}

animation_tests :: () {
  data := gltf_parse_file("./test-samples/rigged_simple/RiggedSimple.gltf");
  defer gltf_free(*data);

  assert(data.animations.count == 1);
  assert(data.animations[0].channels.count == 3);
  assert(data.animations[0].samplers.count == 3);

  assert(data.animations[0].samplers[0].input == 5);
  assert(data.animations[0].samplers[0].output == 6);
  assert(data.animations[0].samplers[0].interpolation == GLTF_Interpolation.LINEAR);

  assert(data.animations[0].channels[0].sampler == 0);
  assert(data.animations[0].channels[0].target.node == 4);
  assert(data.animations[0].channels[0].target.property == GLTF_Target_Property.TRANSLATION);
}

simple_tests :: () {
  data := gltf_parse_file("./test-samples/box/Box.gltf");
  defer gltf_free(*data);

  gltf_load_buffers(*data);

  assert(data.asset.generator == "COLLADA2GLTF");
  assert(data.asset.version == "2.0");
  assert(data.scene == 0);
  assert(data.scenes.count == 1);
  assert(data.nodes.count == 2);
  assert(data.meshes.count == 1);
  assert(data.cameras.count == 0);
  assert(data.accessors.count == 3);
  assert(data.materials.count == 1);
  assert(data.buffer_views.count == 2);
  assert(data.buffers.count == 1);
}

rigged_tests :: () {
  data := gltf_parse_file("./test-samples/rigged_simple/RiggedSimple.gltf");
  defer gltf_free(*data);

  gltf_load_buffers(*data);

  assert(data.asset.generator == "COLLADA2GLTF");
  assert(data.asset.version == "2.0");

  assert(data.nodes[0].name == "Z_UP");
  assert(data.nodes[2].name == "Cylinder");
  assert(data.nodes[2].skin != -1);
  assert(data.skins.count == 1);
  assert(data.skins[0].name == "Armature");
}

camera_tests :: () {
  data := gltf_parse_file("./test-samples/cameras/Cameras.gltf");
  defer gltf_free(*data);

  assert(data.cameras.count == 2);

  cam_1 := data.cameras[0];
  cam_2 := data.cameras[1];

  assert(cam_1.type == .PERSPECTIVE);
  assert(cam_2.type == .ORTHOGRAPHIC);

  perspective := cam_1.perspective;
  assert(perspective.aspect_ratio == 1.0);
  assert(perspective.y_fov == .7);
  assert(perspective.z_far == 100);
  assert(perspective.z_near == 0.01);

  ortho := cam_2.orthographic;
  assert(ortho.x_mag == 1.0);
  assert(ortho.y_mag == 1.0);
  assert(ortho.z_far == 100);
  assert(ortho.z_near == 0.01);
}

khr_lights_punctual_tests :: () {
  data := gltf_parse_file("./test-samples/khr_lights_punctual/Lights.gltf");
  defer gltf_free(*data);

  assert(data.lights.count == 3);

  assert(data.lights[0].type == .POINT);
  assert(data.lights[1].type == .SPOT);
  assert(data.lights[2].type == .DIRECTIONAL);

  assert(data.lights[0].intensity == 1000);
  for data.lights[0].color assert(it == 1);

  assert(data.lights[1].spot.inner_cone_angle  == 0);
  assert(data.lights[1].spot.outer_cone_angle  == 1);

  assert(data.nodes[0].light == 0);
  assert(data.nodes[2].light == 1);
}

glb_file_tests :: () {
  gltf_data := gltf_parse_file("./test-samples/box_binary_textured/BoxTextured.glb");
  defer gltf_free(*gltf_data);

  texture_data := read_entire_file("./test-samples/box_binary_textured/test.png");
  defer free(texture_data);

  image_data := gltf_data.images[0].data;
  assert(image_data != "");
  assert(image_data == texture_data);
}

data_read_tests :: () {
  gltf_data := gltf_parse_file("./test-samples/box_binary/Box.glb");
  defer gltf_free(*gltf_data);

  // Useless, but we want to try if no crash happens.
  gltf_load_buffers(*gltf_data);

  vertices : [..] float;
  mesh     := gltf_data.meshes[0];

  for primitive: mesh.primitives {
    using primitive;

    if position_accessor != -1 {
      accessor := gltf_data.accessors[position_accessor];
      read_buffer_from_accessor(*gltf_data, accessor, *vertices);
    }
  }

  expected_vertices := float.[
    -0.50, -0.50, 0.50, 0.50, -0.50, 0.50, -0.50, 0.50, 0.50,
    0.50, 0.50, 0.50, 0.50, -0.50, 0.50, -0.50, -0.50, 0.50,
    0.50, -0.50, -0.50, -0.50, -0.50, -0.50, 0.50, 0.50, 0.50,
    0.50, -0.50, 0.50, 0.50, 0.50, -0.50, 0.50, -0.50, -0.50,
    -0.50, 0.50, 0.50, 0.50, 0.50, 0.50, -0.50, 0.50, -0.50,
    0.50, 0.50, -0.50, -0.50, -0.50, 0.50, -0.50, 0.50, 0.50,
    -0.50, -0.50, -0.50, -0.50, 0.50, -0.50, -0.50, -0.50, -0.50,
    -0.50, 0.50, -0.50, 0.50, -0.50, -0.50, 0.50, 0.50, -0.50,
  ];

  assert(vertices.count == 72);
  for vertices assert(it == expected_vertices[it_index]);
}
