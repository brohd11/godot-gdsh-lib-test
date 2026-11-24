extends SceneTree
## CI entry for gdsh_lib/test: exit 0 (pass) / 1 (fail). Not a *_test.gd, so `test` skips it.
##     godot --headless --path . --script res://addons/_lib/gdsh_lib/test/_export_ignore/test/run_headless.gd

const TestRunner = preload("res://addons/_lib/util_r/src/test/test_runner.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir = get_script().resource_path.get_base_dir()
	var report = await TestRunner.run_files(TestRunner.find_suites(dir))
	for s in report.suites:
		print("[%s] %s" % ["PASS" if s.passed else "FAIL", s.path])
		for line in s.output:
			print("\t" + str(line))
	quit(0 if report.failed == 0 and report.invalid.is_empty() else 1)
