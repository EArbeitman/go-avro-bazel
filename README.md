# Command to Run

```
bazel build evans_test           
```

# Expected Output

```
compilepkg: missing strict dependencies:
        /private/var/tmp/_bazel_evan.arbeitman/e5dd1fe2cc7c596dbd1efd3cf40929d1/sandbox/darwin-sandbox/8/execroot/__main__/bazel-out/darwin-fastbuild/bin/evans_test_go/test_event_value.go: import of "github.com/actgardner/gogen-avro/v8/compiler"
        /private/var/tmp/_bazel_evan.arbeitman/e5dd1fe2cc7c596dbd1efd3cf40929d1/sandbox/darwin-sandbox/8/execroot/__main__/bazel-out/darwin-fastbuild/bin/evans_test_go/test_event_value.go: import of "github.com/actgardner/gogen-avro/v8/vm"
        /private/var/tmp/_bazel_evan.arbeitman/e5dd1fe2cc7c596dbd1efd3cf40929d1/sandbox/darwin-sandbox/8/execroot/__main__/bazel-out/darwin-fastbuild/bin/evans_test_go/test_event_value.go: import of "github.com/actgardner/gogen-avro/v8/vm/types"
No dependencies were provided.
Check that imports in Go sources match importpath attributes in deps.
Target //:evans_test failed to build
Use --verbose_failures to see the command lines of failed build steps.
INFO: Elapsed time: 0.174s, Critical Path: 0.07s
INFO: 2 processes: 2 internal.
FAILED: Build did NOT complete successfully
```