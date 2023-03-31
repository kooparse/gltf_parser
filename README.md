# glTF parser for Jai codebase

Note: **Jai beta 0.1.059 is required.**

This project is a glTF 2.0 parser written in Jai, aiming to replace the use of some C/C++ libraries. All glTF types are fully documented, so it comes nicely with IDE autocompletion, reducing
back and forth with the [specification](https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html).

This library intends to mimic the glTF file structure in memory. Thereby it's designed around arrays and indexes instead of pointers as you may see in `cgltf` or other libraries. Also, it's the **user's responsibility** to load glTF files and their related binaries in memory.

Note: It's not as complete as the glTF specification yet, but because it's straightforward to add new parsed fields, we'll get new stuff incrementally and on-demand.

If you would like to contribute, don't hesitate! :)

## Examples

```jai

#import "gltf_parser";

main :: () {
  data := gltf_parse_string("gltf_json_data");
  defer gltf_free(*data);
}

```

## Interface

- `gltf_parse_file    :: (gltf_filepath: string) -> GLTF_Data`
- `gltf_parse_string  :: (gltf_json: string) -> GLTF_Data`
- `gltf_load_buffers  :: (gltf_data: *GLTF_Data)`
- `get_component_info :: (gltf_accessor: GLTF_Acessor) -> GLTF_Component_Info`
- `gltf_free          :: (gltf_data: *GLTF_Data)`

## Features

- [x] glTF 2.0 json file
- [x] Scenes
- [x] Nodes
- [x] Buffers
- [x] BufferViews
- [x] Meshes
- [x] Images
- [x] Materials
- [x] Animations
- [x] Skins
- [x] Cameras
- [x] Parse `glb` files
- [ ] Morth targets
- [ ] Extras data
- [ ] glTF writer

Also, we supports some glTF extensions:

- [x] khr_lights_punctual
- [x] khr_materials_emissive_strength
- [x] khr_materials_ior
- [x] khr_materials_transmission

## Contributing to the project

Don’t be shy about shooting any questions you may have. If you are a beginner/junior, don’t hesitate, I will always encourage you. It’s a safe place here. Also, I would be very happy to receive any kind of pull requests, you will have (at least) some feedback/guidance rapidly.

Behind screens, there are human beings, living any sort of story. So be always kind and respectful, because we all sheer to learn new things.
