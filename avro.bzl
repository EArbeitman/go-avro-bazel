load("@bazel_tools//tools/build_defs/repo:jvm.bzl", "jvm_maven_import_external")
load("utils.bzl",
    "get_target_genfiles_root",
    "mkdir_command_string",
    "fix_timestamps_command_string",
    "jar_extract_command_string",
    "cp_command_string",
)

_avsc_filetype = [".avsc"]

def _commonprefix(m):
    if not m: return ''
    s1 = min(m)
    s2 = max(m)
    chars = []
    for i in range(0, len(s1)):
        chars.append(s1[i])
    for i, c in enumerate(chars):
        if c != s2[i]:
            return s1[:i]
    return s1

def _dedup_sources(sources):
    dedup_srcs = []
    for i in sources:
        if i not in dedup_srcs:
            dedup_srcs.append(i)
    return dedup_srcs

def avro_repositories():
  # for code generation
  jvm_maven_import_external(
      name = "org_apache_avro_avro_tools",
      artifact = "org.apache.avro:avro-tools:1.10.2",
      artifact_sha256 = "8ab3c98f6d08ef425dbda3b8702ff2e4ac81e0ce947b652cbe7189bc63bffefd",
      server_urls = ["https://repo1.maven.org/maven2"],
      licenses = ["notice"],  # Apache 2.0
  )
  native.bind(
      name = 'io_bazel_rules_avro/dependency/avro_tools',
      actual = '@org_apache_avro_avro_tools//jar',
  )

  # for code compilation
  jvm_maven_import_external(
      name = "org_apache_avro_avro",
      artifact = "org.apache.avro:avro:1.10.2",
      artifact_sha256 = "fa6f0d601d6b6416c44b0da111d342e36df4ef5319368d06f9b4216a68d1b603",
      server_urls = ["https://repo1.maven.org/maven2"],
      licenses = ["notice"],  # Apache 2.0
  )
  native.bind(
      name = 'io_bazel_rules_avro/dependency/avro',
      actual = '@org_apache_avro_avro//jar',
  )
  
def _avro_gen_impl(ctx):
    # Find a place to put generated Avro files
    target_genfiles_root = get_target_genfiles_root(ctx)

    # Compute full transitive dependencies of the avro srcs
    trans_srcs = depset(ctx.files.srcs, transitive = [dep._transitive_archive_files for dep in ctx.attr.deps], order="postorder")

    commands = [
        'rm -rf {}'.format(target_genfiles_root),
        mkdir_command_string(target_genfiles_root),
    ]

    output_files = []
    for f in ctx.files.srcs:
        file_dirname = f.dirname
        target_path = (target_genfiles_root + "/" + file_dirname)
        commands.append(mkdir_command_string(target_path))
        commands.append(cp_command_string(f.path, target_path))

    java_runtime = ctx.attr._jdk[java_common.JavaRuntimeInfo]
    jar_path = "%s/bin/jar" % java_runtime.java_home

    commands.extend([
        fix_timestamps_command_string(target_genfiles_root),
        # Queue command to archive the Avro files
        jar_path + " cMf \"" + ctx.outputs.libarchive.path + "\"" +
        " -C \"" + target_genfiles_root + "\"" +
        " .",
    ])

    # Register the queued commands
    ctx.actions.run_shell(
        inputs=ctx.files.srcs + ctx.files._jdk,
        outputs=[ctx.outputs.libarchive],
        command=" && ".join(commands),
    )

    return struct(
        srcs=ctx.files.srcs,
        _transitive_archive_files=trans_srcs,
    )

avro_gen = rule(
    attrs={
        "srcs": attr.label_list(
            allow_files = _avsc_filetype
        ),
        "deps": attr.label_list(),
        "_jdk": attr.label(
                    default=Label("@bazel_tools//tools/jdk:current_java_runtime"),
                    providers = [java_common.JavaRuntimeInfo]
                ),
        "_transitive_archive_files": attr.label_list(),
    },
    implementation=_avro_gen_impl,
    outputs={"libarchive": "lib%{name}.avrolib_archive"},
)

