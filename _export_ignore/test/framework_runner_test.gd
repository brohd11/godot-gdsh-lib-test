extends RefCounted
## FrameworkRunner's report side: JUnit from real GUT / GdUnit4 runs (fixtures/junit, each with one
## intentional failure) maps back to suite files, and merge() falls back on the exit code.

const FrameworkRunner = preload("res://addons/_lib/gdsh_lib/test/src/framework_runner.gd")
const JUNIT = "res://addons/_lib/gdsh_lib/test/_export_ignore/test/fixtures/junit/"
const GUT_FILE = "res://addons/gdpackage_ci_test/src/test_labels.gd"
const GDUNIT_FILE = "res://addons/gdpackage_ci_test/src/labels_test.gd"


static func run_tests() -> Dictionary:
	var failures:Array[String] = []
	_check_parse(failures, "gut", FrameworkRunner.GUT, GUT_FILE, "INTENTIONAL_GUT_FAILURE")
	_check_parse(failures, "gdunit4", FrameworkRunner.GDUNIT4, GDUNIT_FILE, "INTENTIONAL_GDUNIT4_FAILURE")
	_check_merge(failures)
	_check_args(failures)
	var output:Array[String] = ["framework_runner: %d failed" % failures.size()]
	output.append_array(failures)
	return {"result": failures.size(), "output": output}


static func _check_parse(failures:Array[String], fixture:String, kind:String, file:String, message:String) -> void:
	var suites = FrameworkRunner.parse_junit([FileAccess.get_file_as_string(JUNIT + fixture + ".xml")])
	_expect(failures, "%s: one suite keyed by res path: %s" % [fixture, suites], suites.size() == 1 and suites[0].key == file.trim_prefix("res://"))
	if suites.size() != 1:
		return
	_expect(failures, fixture + ": failure marks the suite failed", suites[0].passed == false)
	var text = "\n".join(suites[0].output)
	_expect(failures, "%s: output names the case and message: %s" % [fixture, text], text.contains("FAIL test_failure_switch") and text.contains(message))
	# The suite path given as an absolute OS path still matches its report entry.
	var report = {"suites": [], "failed": 0, "invalid": []}
	FrameworkRunner.merge(report, kind, [ProjectSettings.globalize_path(file)], suites, 1, "")
	_expect(failures, fixture + ": merge maps by path, one failed entry", report.suites.size() == 1 and report.failed == 1 and not report.suites[0].output.is_empty())


static func _check_merge(failures:Array[String]) -> void:
	var gut = FrameworkRunner.GUT
	var ok = [{"key": "a/pass.gd", "passed": true, "output": []}]
	var report = _merge(gut, ["res://a/pass.gd", "res://a/missing.gd"], ok, 0)
	_expect(failures, "missing suite with exit 0 passes", report.failed == 0 and report.suites.size() == 2)
	report = _merge(gut, ["res://a/pass.gd", "res://a/missing.gd"], ok, 1)
	_expect(failures, "missing suite with failing exit fails", report.failed == 1 and report.suites[1].passed == false)
	report = _merge(gut, ["res://a/pass.gd"], ok, 1, "boom")
	_expect(failures, "failing exit with every suite passing adds a run entry", report.failed == 1 and report.suites[-1].path == "<GUT run>")
	report = _merge(FrameworkRunner.GDUNIT4, ["res://a/pass.gd"], ok, 101)
	_expect(failures, "GdUnit4 warning exit (101) passes", report.failed == 0)


static func _check_args(failures:Array[String]) -> void:
	var gut = FrameworkRunner.cli_args(FrameworkRunner.GUT, ["res://a.gd", "res://b.gd"], "/tmp/x")
	_expect(failures, "GUT gets one comma list and no config: %s" % [gut], "-gtest=res://a.gd,res://b.gd" in gut and "-gconfig=" in gut and "-gexit" in gut)
	var gdu = FrameworkRunner.cli_args(FrameworkRunner.GDUNIT4, ["res://a.gd", "res://b.gd"], "/tmp/x")
	_expect(failures, "GdUnit4 gets -a per file, continues past failures: %s" % [gdu], gdu.count("-a") == 2 and "-c" in gdu and "--ignoreHeadlessMode" in gdu)


static func _merge(kind:String, files:Array, suites:Array, exit:int, output:String = "") -> Dictionary:
	var report = {"suites": [], "failed": 0, "invalid": []}
	FrameworkRunner.merge(report, kind, files, suites, exit, output)
	return report


static func _expect(failures:Array[String], label:String, ok:bool) -> void:
	if not ok:
		failures.append("FAIL " + label)
