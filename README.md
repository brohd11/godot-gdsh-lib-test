# GDSh test

The `test` command for [GDSh](https://github.com/brohd11/godot-gdsh.git) consoles: runs `*_test.gd` suites
(see util_r's `TestRunner` for the suite contract). It needs no editor, so the gdsh CLI bundles it, and
Editor Console extends it with package-name completions.

```
test ./...                 # every suite below the cwd
test git_service/...       # a package's _export_ignore/test (or export_ignore/test), recursively
test --all                 # every package's tests
test --verbose utils/      # full report, one level
```

GUT and GdUnit4 suites in the target run too, through each framework's own CLI in a headless Godot
(one process per framework, the files passed explicitly), so `./...` and package targets cover them.
They're found by their `extends` chain, custom test bases included, and reported per file from the
framework's JUnit XML. A missing framework fails its suites rather than skipping them.

`gdtest` is the same command under a name that shell builtins don't shadow (the MCP sandbox shell's
own `test` hides this one).

A relative path whose first segment isn't a dir in the cwd names a package: a folder under `res://addons`
with a plugin/package/addon/version cfg. The exit code is 0 when every suite passes, 1 when one fails, and
2 for a bad target (or with `--report-invalid`, a `*_test.gd` without an entry func).

## Loading

```gdscript
host.add_command_dir(preload("res://addons/_lib/gdsh_lib/test/cmd/manifest.gd").resource_path.get_base_dir())
```

`src/test_targets.gd` holds the logic (package discovery, target resolution) for hosts that wrap the command.
