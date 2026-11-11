extends "res://ui/fight3d/set3d.gd"
## 구간 방 — 습격 한 구간이 벌어지는 방 하나를 그린다(무대 도구 set3d.gd 를 이어받는다 — castle_M3D hotel3d.gd 와 같은 꼴 · LSP: build 같음).
## build(theme, bounds, detail): bounds = 걸을 수 있는 곳(fight/world.gd bounds · m). 카메라는 +z 쪽 위에서 내려다본다 — 높은 것은 뒤(−z)나 옆 끝에.
## 폰 성능: 점광 3개 이하 · 그림자는 위에서 오는 빛 하나(set3d). C4-0 은 사무실 하나 — 구역 종류별 배경(08 10절 — 부두 · 호텔 로비 …)은 C4-1.
## 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403

const THEMES := ["office"]


func build(th: String, b: Rect2, detail := true) -> void:
	theme = th
	_detail = detail
	_env(Color(0.2, 0.21, 0.27), 0.6, Color(0.012, 0.014, 0.03))
	_top(Color(0.92, 0.9, 0.84), 0.7)
	_floor(b, Color(0.2, 0.17, 0.15), 0.5, true)
	_back_wall(b, Color(0.24, 0.22, 0.24), 3.6)
	_rug(Rect2(b.position.x + 1.0, -1.4, b.size.x - 2.0, 2.8), Color(0.22, 0.1, 0.11))
	for p in [Vector3(b.position.x + 0.6, 0, b.position.y + 0.4), Vector3(b.end.x - 0.6, 0, b.position.y + 0.4)]:
		_pillar(p, Color(0.42, 0.38, 0.36))
	_omni(Vector3(-3.4, 3.2, -0.8), Color(1.0, 0.84, 0.62), 2.2, 9.0)
	_omni(Vector3(3.4, 3.2, -0.8), Color(1.0, 0.84, 0.62), 2.2, 9.0)
	if detail:                                        # 소품은 걸을 곳 밖(뒤쪽 벽 앞 · 옆 끝)에만 — 사람을 가리지 않게
		_desk(Vector3(0.0, 0, b.position.y - 0.75))
		_sofa(Vector3(b.position.x + 2.2, 0, b.position.y - 0.6))
		_plant(Vector3(b.end.x - 1.6, 0, b.position.y - 0.5))
