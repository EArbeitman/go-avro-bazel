def get_target_genfiles_root(ctx):
  """Returns a place where we can dump generated files.
  For the thrift_library rule, we dump the copied thrift files here.
  For the thrift_java_srcjar rule, we dump the generated Java files here.

  Use a location unique to the build target so that we don't accidentally jar up files we don't
  mean to. Previous versions of Bazel sandboxed the directory on OS X so we didn't run into these
  issues, but sandboxing was disabled for a few reasons on 0.3.2, to be re-enabled for 0.4.
  https://github.com/bazelbuild/bazel/issues/1849. Note that sandboxing is still working on Linux.

  Once it is re-enabled, we can change the below back to just

      return ctx.configuration.genfiles_dir.path (or possibly ctx.genfiles_dir.path)
  """
  return ctx.configuration.genfiles_dir.path + "/" + ctx.label.package + ":" + ctx.label.name


def mkdir_command_string(path):
  return "mkdir -p \"" + path + "\""


def cp_command_string(from_path, to_path):
  return ("cp \"" + from_path + "\" " +
          "\"" + to_path + "\"/")


def fix_timestamps_command_string(root):
  """Sets timestamps to 10 Apr 1976.
  Used to set timestamps of files to be archived to a fixed value, to allow for reproducible builds.
  """
  return ("find \"" + root + "\" -mindepth 1" +
          " -exec touch -t 198001010000 \"{}\" +")


def jar_extract_command_string(jar, filename, to_path):
  for i in range(len(to_path.split("/"))):
    filename = "../" + filename
  # Using _LOCAL_JAR to work around traversing upwards to the wrong parent from a symlink on linux
  return ("_LOCAL_JAR=$PWD/{} && ".format(jar) +
          "pushd \"" + to_path + "\" >/dev/null && " +
          "${_LOCAL_JAR}" + " xf \"" + filename + "\" && popd >/dev/null ")
