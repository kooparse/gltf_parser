# glTF parser for Jai codebase

Note: **Jai beta 0.1.059 is required.**

This project is a glTF 2.0 parser written in Jai, aiming to replace the use of some C/C++ libraries. All glTF types are fully documented, so it comes nicely with IDE autocompletion, reducing
back and forth with the [specification](https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html).

This library intends to mimic the glTF file structure in memory. Thereby it's designed around arrays and indexes instead of pointers as you may see in `cgltf` or other libraries. Also, it's the **user's responsibility** to load glTF files and their related binaries in memory; nevertheless, this library also provides a way to load files and buffers into memory.

Note: It's almost as complete as the glTF specification (see features), but because it's straightforward to add new parsed fields, we'll get new stuff incrementally and on-demand.

If you would like to contribute, don't hesitate! :)

## Examples

```jai

#import "gltf_parser";

main :: () {
  data := gltf_parse_file("./path-to-gltf-or-glb-file");
  defer gltf_free(*data);
}

```

## General Interfaces

- `gltf_parse_string  :: (buffer: string) -> GLTF_Data`
- `gltf_parse_file    :: (gltf_filepath: string) -> GLTF_Data`
- `gltf_free          :: (gltf_data: *GLTF_Data)`

### Helpers

For ease, I provide a procedure to load buffer in memory. Using it, you'll get
the underlying data on the field *data* in a **GLTF_Buffer**.

- `gltf_load_buffers  :: (gltf_data: *GLTF_Data)`

Reading accessor could be a bit tedious, this procedure gives you
the **size, count and stride** of a specified accessor.

- `get_component_info :: (gltf_accessor: GLTF_Accessor) -> GLTF_Component_Info`

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

## Contributing to the project

Don’t be shy about shooting any questions you may have. If you are a beginner/junior, don’t hesitate, I will always encourage you. It’s a safe place here. Also, I would be very happy to receive any kind of pull requests, you will have (at least) some feedback/guidance rapidly.

Behind screens, there are human beings, living any sort of story. So be always kind and respectful, because we all sheer to learn new things.
