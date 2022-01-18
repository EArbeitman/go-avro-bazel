load("utils.bzl",
    "get_target_genfiles_root",
    "mkdir_command_string",
    "fix_timestamps_command_string",
    "jar_extract_command_string",
    "cp_command_string",
)
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_context")
load("avro.bzl", "avro_gen")

def _dedup_sources(sources):
    dedup_srcs = []
    for i in sources:
        if i not in dedup_srcs:
            dedup_srcs.append(i)
    return dedup_srcs

def _new_generator_command(ctx, srcs, includes, gen_dir):
    gen_command = '{gogen} -containers=false '.format(gogen=ctx.file._gogen_avro.path)

    if ctx.attr.encoding:
        gen_command += " -encoding {encoding}".format(
          encoding=ctx.attr.encoding
        )

    sources = [f.path for f in srcs]
  

    include_files = [f.path for f in includes]
    include_files += sources
    final_sources = " ".join(_dedup_sources(include_files))

    gen_command += " {gen_dir} {final_sources}".format(
        gen_dir=gen_dir,
        final_sources=final_sources,
    )
    print("go gen command")
    print(gen_command)

    return gen_command


def _gen_avro_srcjar_impl(ctx):
    """
    Generates a jar file containing the sources of all generated Avro files
    """
    go = go_context(ctx)
    target_genfiles_root = get_target_genfiles_root(ctx)
    gen_go_dir = '/'.join([target_genfiles_root, 'gen-go'])

    print("gen file root")
    print(target_genfiles_root)
    print("gen_go_dir")
    print(gen_go_dir)
    # Place to extract all includes for Thrift files
    avro_includes_root = "/".join(
        [target_genfiles_root, "avro_includes"])

    commands = []

    # commands.append("pwd ")
    # Clean up any old stuff
    commands.append('rm -rf {}'.format(target_genfiles_root))
    # Create the root dirs
    commands.append(mkdir_command_string(gen_go_dir))
    commands.append(mkdir_command_string(target_genfiles_root))
    commands.append(mkdir_command_string(avro_includes_root))

    avro_lib_archive_files = ctx.attr.avro_library._transitive_archive_files
    avro_lib_srcs = ctx.attr.avro_library.srcs

    # The list of .thrift files to generate Java code for

    avro_include_dirs = [
        # Search paths for files in srcs attribute
        '"src/avro/urbancompass"',
        # Search paths for extracted avro_lib_archive_files
        '"{}/src/avro/urbancompass"'.format(avro_includes_root),
    ]
    # for d in avro_include_dirs:
    #       # Make sure the include dirs always exist, even if there are no avro files in them
    #       commands.append(mkdir_command_string(d))

    commands.append(_new_generator_command(ctx, avro_lib_srcs, avro_lib_archive_files.to_list(), gen_go_dir))

    # commands.append(fix_timestamps_command_string(gen_go_dir))

    # Queue commands to archive all generated Java files in a srcjar
    # out = ctx.outputs.srcjar
    # commands.append(jar_path + " cMf \"" + out.path + "\"" + " -C \"" + gen_go_dir + "\" .")

    # Declare the directory that generated go files should be output to.
    dir = ctx.actions.declare_directory(ctx.label.name)
    print("dir.path")
    print(dir.path)
    print("dir")
    print(dir)
    avro_go_files = []
    # base_path = '/'.join([ctx.label.name, 'gen'])
    base_path = '/'.join([ctx.label.name])
    print("base path")
    print(base_path)

    gen_path = '/'.join([base_path, 'acl_capability.go'])
    print("gen_path")
    print(gen_path)
    # avro_go_files.extend([
    #     ctx.actions.declare_file('{}/acl_capability.go'.format(dir.path)),
    #     ctx.actions.declare_file('{}/device.go'.format(dir.path)),
    #     ctx.actions.declare_file('{}/resource_ref.go'.format(dir.path)),
    #     ctx.actions.declare_file('{}/resource_scope_type.go'.format(dir.path)),
    #     ctx.actions.declare_file('{}/resource_type.go'.format(dir.path)),
    #     ctx.actions.declare_file('{}/subject_ref.go'.format(dir.path)),
    #     ctx.actions.declare_file('{}/subject_type.go'.format(dir.path)),
    #     ctx.actions.declare_file('{}/task_type.go'.format(dir.path)),
    #     ctx.actions.declare_file('{}/test_transitive.go'.format(dir.path)),
    # ])
    avro_go_files.extend([
        ctx.actions.declare_file('/'.join([base_path, 'test_event_value.go'])),

    ])

    commands.append('cp -pR ' + gen_go_dir +  '/ ' + dir.path)
    commands.append('ls -al {}'.format(dir.path))

    # organize our deps into a list of depsets that map a primary dependency to
    # its own dependencies. this improves bazel's performance by allowing its
    # internal transitive dependency resolver to handle this better than we do
    # when we put all dependencies at the top level.
    transitive_deps = [depset( \
                             t, transitive = \
                             [depset(s) for s in [
                                                   ctx.files._jdk + \
                                                   ctx.files._gogen_avro \
                                                 ] \
                             ] \
                           ) \
                           for t in [avro_lib_archive_files.to_list()] \
                    ]
                    
    inputs = depset(avro_lib_srcs, transitive = transitive_deps,  order="postorder")

    print("avro gen command")
    print(" && \\\n".join(commands))

    ctx.actions.run_shell(
        inputs=inputs,
        outputs=[dir] + avro_go_files,
        command=" && \\\n".join(commands),
    )

    return DefaultInfo(files = depset(avro_go_files))



avro_go_srcjar = rule(
    attrs={
        "avro_library": attr.label(
            mandatory=True, providers=['srcs', '_transitive_archive_files']
        ),
        "strings": attr.bool(),
        "encoding": attr.string(),
        "generate_in_order": attr.bool(),
        "_jdk": attr.label(
            default=Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo]
        ),
        "_go_context_data": attr.label(
            default = "@io_bazel_rules_go//:go_context_data",
        ),
        "_gogen_avro": attr.label(
            default="//gogen-avro:gogen-avro",
            allow_single_file=True),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
    implementation=_gen_avro_srcjar_impl,
)


def avro_go_library(name, srcs=[], deps=[], encoding=None, visibility=None, generate_in_order=False):
    avro_library_deps = []
    for dep in deps:
        # Package-local dependencies can omit the path part and just start with the name, which is
        # prefixed by ":".
        if dep.startswith(':'):
          avro_library_deps.append(dep + '_avrolib')
        # Otherwise, use Label() to normalize the target. It can only handle absolute paths.
        else:
          label = Label(dep)
          avro_library_deps.append(
              '//{}:{}_avrolib'.format(label.package, label.name))
    d = depset(avro_library_deps, order="postorder")

    avro_gen(
        name=name + '_avrolib',
        srcs=_dedup_sources(srcs),
        deps=d,
    )

    avro_go_srcjar(
        name=name + '_go',
        avro_library=name + '_avrolib',
        visibility=visibility,
        encoding=encoding,
    )

    go_library(
        name=name,
        srcs=[name + '_go'],
        importpath = "compass.com/tmp",
        visibility = ["//visibility:public"],
    )
