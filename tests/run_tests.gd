extends SceneTree
## 시험 실행기 (창 없음): <godot> --headless --path . -s res://tests/run_tests.gd [-- --cov 파일] — castle_M3D tests/run_tests.gd 를 옮겼다.
## tests/unit/(A 등급 — 순수 로직) · tests/integration/(B 등급 — 흐름 · 저장 · 자동 진행)의 test_*.gd 를 돌며 test_ 로 시작하는 함수를
## 부르고, 하나라도 실패하면 종료 코드 1. 줄 'tests: N passed, M failed' + 폴더별 줄 'suite unit: …'.
## --cov 파일: 함수 단위 커버리지 — scripts/verify.py 가 함수 머리마다 Engine 메타 'cov' 에 표시하는 줄을 넣은 사본에서 돌리고,
## 끝에 불린 함수 목록을 그 파일에 JSON 으로 쓴다(이 저장소의 소스는 그대로).

const DIRS := ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var cov_out := ""
	if a.size() >= 2 and a[0] == "--cov":
		cov_out = a[1]
		Engine.set_meta("cov", {})
	var passed := 0
	var failed := 0
	for dir in DIRS:
		var dp := 0
		var df := 0
		var files := Array(DirAccess.get_files_at(dir))
		files.sort()
		for fname in files:
			if not (fname.begins_with("test_") and fname.ends_with(".gd")):
				continue
			var path: String = dir + "/" + fname
			var scr = load(path)
			if scr == null or not scr.can_instantiate():
				df += 1                              # 문법 오류 등 — 멈추지 않고 실패로 센다(아니면 quit 에 못 닿아 끝나지 않는다)
				print("FAIL %s: 불러오지 못함" % path.trim_prefix("res://tests/"))
				continue
			var suite = scr.new()
			for m in suite.get_method_list():
				var n: String = m["name"]
				if not n.begins_with("test_"):
					continue
				suite.failures = []
				suite.call(n)
				if suite.failures.is_empty():
					dp += 1
				else:
					df += 1
					for f in suite.failures:
						print("FAIL %s %s: %s" % [path.trim_prefix("res://tests/"), n, f])
			suite = null
		print("suite %s: %d passed, %d failed" % [dir.get_file(), dp, df])
		passed += dp
		failed += df
	print("tests: %d passed, %d failed" % [passed, failed])
	if cov_out != "":
		var f := FileAccess.open(cov_out, FileAccess.WRITE)
		f.store_string(JSON.stringify(Engine.get_meta("cov").keys()))
		f.close()
	quit(1 if failed > 0 else 0)
