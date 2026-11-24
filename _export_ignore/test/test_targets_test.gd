extends RefCounted
## gdsh_lib/test: package discovery, target resolution and the `test` command, over a fixture tree
## generated under fixtures/ and removed afterwards (so its suites never linger for `test --all`).
##     godot --headless --path . --script res://addons/_lib/gdsh_lib/test/_export_ignore/test/run_headless.gd

const Sh = preload("res://addons/_lib/gdsh/_ns/gd_sh.gd")
const TestTargets = preload("res://addons/_lib/gdsh_lib/test/src/test_targets.gd")
const CMD = "res://addons/_lib/gdsh_lib/test/cmd"
const FIXTURES = "res://addons/_lib/gdsh_lib/test/_export_ignore/test/fixtures"

const PASS_SUITE = "static func run_tests() -> Dictionary:\n\treturn {\"result\": 0, \"output\": [\"fixture ok\"]}\n"
const FAIL_SUITE = "static func run_tests() -> Dictionary:\n\treturn {\"result\": 1, \"output\": [\"fixture broke\"]}\n"
const NO_ENTRY_SUITE = "static func helper() -> int:\n\treturn 0\n"

static var _failures:Array[String] = []
static var _passed := 0


static func run_tests() -> Dictionary:
	_failures = []
	_passed = 0
	var root = FIXTURES.path_join("_tmp_%d" % Time.get_ticks_usec())
	_build_fixtures(root)
	_test_discovery(root)
	_test_resolve(root)
	await _test_command(root)
	_remove(root)
	var output:Array[String] = ["gdsh_lib test: %d passed, %d failed" % [_passed, _failures.size()]]
	for failure in _failures:
		output.append("  FAIL  " + failure)
	return {"result": _failures.size(), "output": output}


## alpha: suites (one failing, one in sub/, one without an entry func) plus an export copy with its own cfg.
## beta: an empty test dir. g1/dup + g2/dup: an ambiguous name. plain: no cfg.
static func _build_fixtures(root:String) -> void:
	_write(root.path_join("alpha/plugin.cfg"), "[plugin]\nname=\"alpha\"\n")
	_write(root.path_join("alpha/_export_ignore/test/a_pass_test.gd"), PASS_SUITE)
	_write(root.path_join("alpha/_export_ignore/test/sub/b_fail_test.gd"), FAIL_SUITE)
	_write(root.path_join("alpha/_export_ignore/test/c_no_entry_test.gd"), NO_ENTRY_SUITE)
	_write(root.path_join("alpha/_export_ignore/exports/alpha/plugin.cfg"), "[plugin]\n")
	_write(root.path_join("beta/package.cfg"), "[package]\n")
	DirAccess.make_dir_recursive_absolute(root.path_join("beta/export_ignore/test"))
	_write(root.path_join("g1/dup/version.cfg"), "[plugin]\n")
	_write(root.path_join("g2/dup/version.cfg"), "[plugin]\n")
	DirAccess.make_dir_recursive_absolute(root.path_join("plain/src"))


static func _test_discovery(root:String) -> void:
	var found = TestTargets.find_packages(root)
	var names = found.packages.keys()
	names.sort()
	_check("packages found, export copy skipped", names, ["alpha", "beta", "dup"])
	_check("ambiguous name", found.ambiguous.get("dup", []).size(), 2)
	_check("alpha test dir", TestTargets.package_test_dir(found.packages.alpha), root.path_join("alpha/_export_ignore/test"))
	_check("empty test dir doesn't count", TestTargets.package_test_dir(found.packages.beta), "")
	var all = TestTargets.all_files(found).map(func(p): return p.get_file())
	all.sort()
	_check("all_files", all, ["a_pass_test.gd", "b_fail_test.gd", "c_no_entry_test.gd"])


static func _test_resolve(root:String) -> void:
	var found = TestTargets.find_packages(root)
	var alpha_tests = ProjectSettings.globalize_path(root.path_join("alpha/_export_ignore/test"))
	_check("package name", TestTargets.resolve("res://", "alpha", found), {"dir": alpha_tests, "recursive": false})
	_check("package recursive", TestTargets.resolve("res://", "alpha/...", found), {"dir": alpha_tests, "recursive": true})
	_check("package subdir", TestTargets.resolve("res://", "alpha/sub/", found).get("dir"), alpha_tests.path_join("sub"))
	_check("cwd dir wins", TestTargets.resolve(root, "alpha/...", found).get("dir"), ProjectSettings.globalize_path(root.path_join("alpha")))
	_check("empty arg is cwd", TestTargets.resolve(root, "", found), {"dir": ProjectSettings.globalize_path(root), "recursive": false})
	_check("ambiguous refused", "ambiguous" in TestTargets.resolve("res://", "dup/...", found).get("error", ""), true)
	_check("no tests refused", "has no tests" in TestTargets.resolve("res://", "beta", found).get("error", ""), true)
	_check("unknown refused", TestTargets.resolve("res://", "nosuch/...", found).get("error", ""), "No directory or package named: nosuch")
	_check("missing subdir refused", TestTargets.resolve("res://", "alpha/nope/", found).has("error"), true)
	var non_recursive = TestTargets.collect(alpha_tests, false).map(func(p): return p.get_file())
	non_recursive.sort()
	_check("collect one level", non_recursive, ["a_pass_test.gd", "c_no_entry_test.gd"])


## Dir targets, so the command's own package scan (all of res://addons) doesn't matter here.
static func _test_command(root:String) -> void:
	var tests = root.path_join("alpha/_export_ignore/test")
	var ctx = await _run("test --verbose " + tests)
	_check("one level passes", ctx.exit_code, Sh.CommandBase.ExitCode.OK)
	_check("verbose shows the report", "fixture ok" in ctx.stdout and "[PASS]" in ctx.stdout, true)
	ctx = await _run("test " + tests.path_join("..."))
	_check("recursive failure exits FAIL", ctx.exit_code, Sh.CommandBase.ExitCode.FAIL)
	_check("fail line", "[FAIL]" in ctx.stdout and "b_fail_test.gd" in ctx.stdout, true)
	ctx = await _run("test --report-invalid " + tests)
	_check("report-invalid exits ERR", [ctx.exit_code, "c_no_entry_test.gd" in ctx.stderr], [Sh.CommandBase.ExitCode.ERR, true])
	ctx = await _run("test --all alpha")
	_check("--all with a target refused", ctx.exit_code, Sh.CommandBase.ExitCode.ERR)
	ctx = await _run("test " + root.path_join("plain"))
	_check("no suites", [ctx.exit_code, "No tests found" in ctx.stdout], [Sh.CommandBase.ExitCode.OK, true])


static func _run(text:String) -> Sh.Context:
	var parent = Sh.Context.new()
	parent.load(CMD, true)
	var ctx = Sh.Context.new_ctx("test", parent)
	await Sh.Execute.execute_command_multiline(text, ctx)
	return ctx


static func _write(path:String, text:String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(text)


static func _remove(dir:String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


static func _check(label:String, got, expected) -> void:
	if got == expected:
		_passed += 1
	else:
		_failures.append("%s (expected %s, got %s)" % [label, expected, got])
