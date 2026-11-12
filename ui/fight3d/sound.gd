extends Node
## [옮김] castle_M3D `src/view/sound.gd`(2c3e69b) — 효과음만(음악 없음) · 8채널. 바꾼 것: 소리 이름 목록 = 이 판 assets/sfx 에 있는 것 · 음악 뺌.
## 창 없는 점검(headless)에서는 내지 않는다(가짜 오디오가 재생 객체를 붙잡는다). event_fx.gd 가 play(이름, dB, 높이)를 부른다.
## 소리 파일 출처: assets/ASSETS.md `sfx/*.wav`. 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-414

const SFX := ["counter", "fall", "guard", "hit", "hit_heavy", "ko", "miss", "shine", "slash", "swing", "wind"]

var headless := false
var sfx := {}
var players: Array = []


func setup(is_headless: bool) -> void:
	headless = is_headless
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if headless:
		return
	for n in SFX:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			sfx[n] = load(path)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(n: String, db := 0.0, pitch := 1.0) -> void:
	if headless or not sfx.has(n):
		return
	for p in players:
		if not p.playing:
			p.stream = sfx[n]
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return
