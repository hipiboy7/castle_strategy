extends Camera3D
## [옮김] castle_M3D `src/view/camera_rig.gd`(2c3e69b) — 바꾼 것: 없음. 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403
## 3/4 탑뷰 카메라 — 두 사람 사이(김신 쪽으로 조금)를 따라가고, 멀어지면 물러나고, 흔들림 · 결착 줌을 더한다.
## 높이 · 거리 OFFSET 으로 내려다보는 각이 약 55도(castle_M 의 3/4 탑뷰와 같은 느낌, 아이소메트릭 아님). 인물이 화면 높이의 약 1/3 이 되게 가깝다(2026-10-26 자체 점검 1).

const OFFSET := Vector3(0, 10.0, 7.0)

var focus := Vector3.ZERO
var dist_k := 1.0
var zoom := 1.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	fov = 38.0
	near = 0.3
	far = 120.0
	rng.seed = 5


func follow(a: Vector3, b: Vector3, dt: float, shake: int) -> void:
	_aim(a.lerp(b, 0.42), a.distance_to(b), dt, shake)


## 여럿(11장): 조작하는 사람(lead) 둘레 7.5m 안 사람들을 한 화면에 — 그 묶음 가운데와 lead 사이를 보고, 퍼진 만큼 물러난다
func follow_group(lead: Vector3, pts: Array, dt: float, shake: int) -> void:
	var lo := Vector2(lead.x, lead.z)
	var hi := lo
	for p in pts:
		if p.distance_to(lead) < 7.5:
			lo = lo.min(Vector2(p.x, p.z))
			hi = hi.max(Vector2(p.x, p.z))
	var c := (lo + hi) * 0.5
	_aim(Vector3(lerpf(lead.x, c.x, 0.6), 0, lerpf(lead.z, c.y, 0.6)), (hi - lo).length() * 0.85, dt, shake)


func _aim(mid: Vector3, sep: float, dt: float, shake: int) -> void:
	var want := clampf(0.5 + sep * 0.045, 0.56, 0.95) * zoom
	focus = focus.lerp(mid, 1.0 - exp(-5.0 * dt))
	dist_k = lerpf(dist_k, want, 1.0 - exp(-3.0 * dt))
	zoom = lerpf(zoom, 1.0, 1.0 - exp(-1.5 * dt))
	var sh := Vector3.ZERO
	if shake > 0:
		sh = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.03 * shake
	position = focus + OFFSET * dist_k + sh
	look_at(focus + Vector3(0, 0.9, 0) + sh * 0.4, Vector3.UP)


func snap(a: Vector3, b: Vector3) -> void:
	focus = a.lerp(b, 0.42)
	position = focus + OFFSET
	look_at(focus + Vector3(0, 0.9, 0), Vector3.UP)


func punch_zoom(k: float) -> void:
	zoom = minf(zoom, k)
