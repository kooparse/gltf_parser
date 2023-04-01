#import "File";
#import "Compiler";
#import "Basic";

#run {
  options := get_build_options();

  make_directory_if_it_does_not_exist("example/");

	import_path: [..] string;
  array_add(*import_path, .. options.import_path);
  array_add(*import_path, "./modules");

  options.import_path            = import_path;
  options.optimization_level     = .DEBUG;
  options.output_path            = "example";
  options.output_executable_name = "example";
  options.entry_point_name       = "tests";

  ws := compiler_create_workspace("Tests");
  set_build_options(options, ws);
  add_build_file("module.jai", ws);

  set_build_options_dc(.{ do_output = false });
}
