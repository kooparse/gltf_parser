# glTF parser for Jai codebase

Note: **Jai beta 0.1.065 is required.**

This project is a glTF 2.0 parser written in Jai, aiming to replace the use of some C/C++ libraries. All glTF types are fully documented, so it comes nicely with IDE autocompletion, reducing
back and forth with the [specification](https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html).

This library intends to mimic the glTF file structure in memory. Thereby it's designed around arrays and indexes instead of pointers as you may see in `cgltf` or other libraries. Also, it's the **user's responsibility** to load glTF files and their related binaries in memory; nevertheless, this library also provides a way to load files and buffers into memory.

Note: It's almost as complete as the glTF specification (see features), but because it's straightforward to add new parsed fields, we'll get new stuff incrementally and on-demand.

If you would like to contribute, don't hesitate! :)

## Examples

You just need to import `module.jai` in your project, also this library has two dependencies: `jason` and `unicode_utils`; so those two modules needs to be found somewhere.

```jai

#import "gltf_parser";

main :: () {
  gltf := gltf_parse_file("./path-to-gltf-or-glb-file");
  defer gltf_free(*gltf);

  gltf_debug_print(gltf);

  gltf_load_buffers(*gltf);

  vertices: [..]float;
  read_buffer_from_accessor(*data, data.accessors[0], *vertices);
}

```

All examples could be found in `example.jai`. Also, if you want to run the tests and examples, run `jai example.jai -import_dir ./modules`.

## General Interfaces

- `gltf_parse_string  :: (buffer: string) -> GLTF_Data`
- `gltf_parse_file    :: (gltf_filepath: string) -> GLTF_Data`
- `gltf_free          :: (gltf_data: *GLTF_Data)`

### Helpers

For ease, I provide a procedure to load buffer in memory. Using it, you'll get
the underlying data in **GLTF_Buffer**:

- `gltf_load_buffers  :: (gltf_data: *GLTF_Data)`

If you want to easily copy the underlying data from an accessor, this procedure
will get the job done. You just need to provide an array of your type from which
the data will be copied. Also, `gltf_load_buffers` must be call first.
If the type of your array doesn't match the type of the accessor's component,
a cast will be made (see `data_read_tests` example):

- `read_buffer_from_accessor :: (gltf: *GLTF_Data, accessor: GLTF_Accessor, list: *[..] $T)`

A tiny utility that gives you the **size, count and stride** of the underlying
accessor's data:

- `get_component_info :: (gltf_accessor: GLTF_Accessor) -> GLTF_Component_Info`

Being able to easily print information could save you lot of debug times,
this procedure gives you general informations about it (animations names,
nodes counts, etc...):

- `gltf_debug_print :: (gltf_data: GLTF_Data)`

## Features

- [x] glTF 2.0 json file
- [x] Scenes
- [x] Nodes
- [x] Buffers
- [x] BufferViews
- [x] Meshes
- [x] Textures
- [x] Images
- [x] Materials
- [x] Animations
- [x] Skins
- [x] Cameras
- [x] Parse `glb` files
- [ ] Morth targets
- [ ] Extras data

Also, we supports some glTF extensions:

- [x] khr_lights_punctual
- [x] khr_materials_emissive_strength
- [x] khr_materials_ior
- [x] khr_materials_transmission

## Thanks

This library is using Raphael Luba's `jason` module to parse JSON strings, so thanks to him! :)

## Contributing to the project

Don’t be shy about shooting any questions you may have. If you are a beginner/junior, don’t hesitate, I will always encourage you. It’s a safe place here. Also, I would be very happy to receive any kind of pull requests, you will have (at least) some feedback/guidance rapidly.

Behind screens, there are human beings, living any sort of story. So be always kind and respectful, because we all sheer to learn new things.
