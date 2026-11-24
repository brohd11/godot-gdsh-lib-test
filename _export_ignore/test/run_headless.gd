extends SceneTree
## CI entry for gdsh_lib/test: exit 0 (pass) / 1 (fail). Not a *_test.gd, so `test` skips it.
##     godot --headless --path . --script res://addons/_lib/gdsh_lib/test/_export_ignore/test/run_headless.gd

const Suite = preload("res://addons/_lib/gdsh_lib/test/_export_ignore/test/test_targets_test.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var res = await Suite.run_tests()
	print("\n".join(res.output))
	quit(0 if res.result == 0 else 1)
