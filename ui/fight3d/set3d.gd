extends Node3D
## [옮김] castle_M3D `src/view/set3d.gd`(2c3e69b) — 바꾼 것: 경로. 설계: docs/C4_설계서_직접조작전투.md 6절 · 요구: FR-403
## 무대 그리는 도구(여러 사람 판 무대 그림의 바탕 — hotel3d.gd 호텔 층 · town3d.gd 1부 거리 · 실내가 물려받는다):
## 빛 · 바닥 · 벽 · 소품 · 재질. 그림마다 build(theme, bounds, detail) 와 const THEMES(그리는 무대 이름)를 둔다(main.gd VIEWS — LSP).
## 폰 성능: 점광 3개 이하 · 그림자는 위에서 오는 빛 하나 · 같은 재질은 나눠 쓴다.

var theme := ""
var _detail := true


func _env(amb: Color, energy: float, bg: Color) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = amb
	env.ambient_light_energy = energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## 위에서 오는 빛(그림자) — 실내 천장 조명을 하나로 묶은 것
func _top(col: Color, energy: float) -> void:
	var l := DirectionalLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.rotation_degrees = Vector3(-70, 20, 0)
	l.shadow_enabled = _detail
	l.shadow_blur = 1.6
	l.directional_shadow_max_distance = 24.0
	add_child(l)
	var rim := DirectionalLight3D.new()                  # 뒤에서 오는 약한 빛 — 어두운 정장 윤곽
	rim.light_color = Color(0.6, 0.7, 1.0)
	rim.light_energy = 0.3
	rim.rotation_degrees = Vector3(-20, 180, 0)
	add_child(rim)


func _omni(at: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	add_child(l)


func _floor(b: Rect2, col: Color, rough: float, tiles: bool) -> void:
	var m := _mat(col, rough, 0.0, 0.0)
	m.metallic_specular = 0.7
	var pm := PlaneMesh.new()
	pm.size = Vector2(b.size.x + 4.0, b.size.y + 4.0)
	_mesh(self, pm, m, Vector3(b.get_center().x, 0, b.get_center().y + 0.6))
	if tiles:                                            # 대리석 줄눈
		var j := _mat(col.darkened(0.25), 0.6)
		for x in range(int(b.position.x) - 1, int(b.end.x) + 2, 2):
			_mesh(self, _box(Vector3(0.02, 0.004, b.size.y + 3.0)), j, Vector3(x, 0.002, b.get_center().y + 0.6))
		for z in range(int(b.position.y) - 1, int(b.end.y) + 2, 2):
			_mesh(self, _box(Vector3(b.size.x + 3.0, 0.004, 0.02)), j, Vector3(b.get_center().x, 0.002, z))


func _rug(r: Rect2, col: Color) -> void:
	var m := _mat(col, 0.95)
	_mesh(self, _box(Vector3(r.size.x, 0.01, r.size.y)), m, Vector3(r.get_center().x, 0.005, r.get_center().y))
	var edge := _mat(Color(0.75, 0.6, 0.25), 0.6, 0.0, 0.5)
	for z in [r.position.y, r.end.y]:
		_mesh(self, _box(Vector3(r.size.x, 0.012, 0.05)), edge, Vector3(r.get_center().x, 0.006, z))


func _back_wall(b: Rect2, col: Color, h: float) -> void:
	var m := _mat(col, 0.8)
	var z := b.position.y - 0.8
	_mesh(self, _box(Vector3(b.size.x + 4.0, h, 0.3)), m, Vector3(b.get_center().x, h * 0.5, z))
	var trim := _mat(col.lightened(0.2), 0.5)
	_mesh(self, _box(Vector3(b.size.x + 4.0, 0.12, 0.34)), trim, Vector3(b.get_center().x, 0.06, z + 0.02))
	for sx in [-1.0, 1.0]:                               # 옆벽(낮게 — 위에서 보는 카메라가 안을 본다)
		var x: float = b.get_center().x + sx * (b.size.x * 0.5 + 1.2)
		_mesh(self, _box(Vector3(0.3, 1.2, b.size.y + 2.0)), m, Vector3(x, 0.6, b.get_center().y))


## 유리창 벽: 낮은 턱 · 창틀(세로 기둥)만 — 그 너머로 도시가 보인다
func _window_wall(b: Rect2, h: float) -> void:
	var z := b.position.y - 0.8
	var frame := _mat(Color(0.16, 0.17, 0.2), 0.4, 0.0, 0.6)
	_mesh(self, _box(Vector3(b.size.x + 4.0, 0.5, 0.3)), frame, Vector3(b.get_center().x, 0.25, z))
	_mesh(self, _box(Vector3(b.size.x + 4.0, 0.12, 0.2)), frame, Vector3(b.get_center().x, h, z))
	var glass := _mat(Color(0.5, 0.65, 0.9, 0.12), 0.05, 0.4, 0.0)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(self, _box(Vector3(b.size.x + 4.0, h - 0.5, 0.02)), glass, Vector3(b.get_center().x, 0.5 + (h - 0.5) * 0.5, z))
	for x in range(int(b.position.x) - 1, int(b.end.x) + 2, 2):
		_mesh(self, _box(Vector3(0.08, h, 0.14)), frame, Vector3(x, h * 0.5, z))
	for sx in [-1.0, 1.0]:
		var x: float = b.get_center().x + sx * (b.size.x * 0.5 + 1.2)
		_mesh(self, _box(Vector3(0.3, 1.2, b.size.y + 2.0)), _mat(Color(0.2, 0.2, 0.24), 0.8), Vector3(x, 0.6, b.get_center().y))


## 도시 야경: 유리창 너머 아래쪽(71층) — 건물 상자 + 불 켜진 창(빛나는 작은 판). 결정적(seed 고정)
func _city(z0: float, width: float, seed_v: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 71 + seed_v
	var body := _mat(Color(0.05, 0.06, 0.09), 0.9)
	var lit := _mat(Color(1.0, 0.85, 0.55), 0.5)
	lit.emission = Color(1.0, 0.78, 0.45)
	lit.emission_energy_multiplier = 2.2
	var lit2 := _mat(Color(0.7, 0.85, 1.0), 0.5)
	lit2.emission = Color(0.55, 0.75, 1.0)
	lit2.emission_energy_multiplier = 1.8
	var n := 34 if _detail else 18
	for i in n:
		var x := r.randf_range(-width * 0.5, width * 0.5)
		var z := z0 - r.randf_range(6.0, 40.0)
		var w := r.randf_range(2.0, 5.0)
		var top := r.randf_range(-18.0, -3.0)              # 이 층보다 한참 아래
		var hgt := 40.0
		_mesh(self, _box(Vector3(w, hgt, w)), body, Vector3(x, top - hgt * 0.5, z))
		for k in 3:
			_mesh(self, _box(Vector3(w * 0.7, 0.25, 0.05)), lit if r.randf() < 0.7 else lit2,
				Vector3(x, top - 1.0 - k * 1.6, z + w * 0.5 + 0.03))
	# 먼 도시 불빛 띠
	_mesh(self, _box(Vector3(width * 2.0, 0.3, 0.2)), lit, Vector3(0, -14.0, z0 - 60.0))


func _elevator(at: Vector3, floor_no: String) -> void:
	var metal := _mat(Color(0.7, 0.68, 0.62), 0.25, 0.0, 0.9)
	var frame := _mat(Color(0.45, 0.38, 0.28), 0.4, 0.0, 0.7)
	_mesh(self, _box(Vector3(1.7, 2.7, 0.12)), frame, at + Vector3(0, 1.35, 0))
	for sx in [-1.0, 1.0]:
		_mesh(self, _box(Vector3(0.72, 2.4, 0.06)), metal, at + Vector3(0.37 * sx, 1.2, 0.08))
	var ind := _mat(Color(1.0, 0.6, 0.2), 0.5)
	ind.emission = Color(1.0, 0.55, 0.15)
	ind.emission_energy_multiplier = 3.0
	_mesh(self, _box(Vector3(0.36, 0.14, 0.04)), ind, at + Vector3(0, 2.85, 0.07))
	var l := Label3D.new()
	l.text = floor_no
	l.font_size = 40
	l.pixel_size = 0.005
	l.modulate = Color(1.0, 0.7, 0.3)
	l.position = at + Vector3(0, 2.85, 0.1)
	add_child(l)


func _pillar(at: Vector3, col: Color) -> void:
	_mesh(self, _cyl(0.32, 0.32, 3.6), _mat(col, 0.35, 0.0, 0.1), at + Vector3(0, 1.8, 0))
	_mesh(self, _box(Vector3(0.8, 0.16, 0.8)), _mat(col.darkened(0.15), 0.4), at + Vector3(0, 0.08, 0))


func _sofa(at: Vector3) -> void:
	var m := _mat(Color(0.35, 0.22, 0.14), 0.8)
	_mesh(self, _box(Vector3(1.6, 0.42, 0.7)), m, at + Vector3(0, 0.21, 0))
	_mesh(self, _box(Vector3(1.6, 0.5, 0.18)), m, at + Vector3(0, 0.6, 0.28))


func _plant(at: Vector3) -> void:
	_mesh(self, _cyl(0.22, 0.18, 0.5), _mat(Color(0.3, 0.28, 0.26), 0.6), at + Vector3(0, 0.25, 0))
	_mesh(self, _sphere(0.45), _mat(Color(0.12, 0.28, 0.12), 0.9), at + Vector3(0, 0.9, 0))


func _round_table(at: Vector3) -> void:
	var wood := _mat(Color(0.3, 0.18, 0.1), 0.4)
	_mesh(self, _cyl(0.85, 0.85, 0.06), wood, at + Vector3(0, 0.76, 0))
	_mesh(self, _cyl(0.1, 0.25, 0.74), wood, at + Vector3(0, 0.37, 0))
	_mesh(self, _cyl(0.2, 0.12, 0.14), _mat(Color(0.85, 0.7, 0.3), 0.3, 0.0, 0.8), at + Vector3(0, 0.86, 0))     # 장식 그릇


func _sconce(at: Vector3) -> void:
	var m := _mat(Color(1.0, 0.85, 0.6), 0.5)
	m.emission = Color(1.0, 0.75, 0.45)
	m.emission_energy_multiplier = 2.5
	_mesh(self, _box(Vector3(0.2, 0.3, 0.08)), m, at)


func _strip(at: Vector3) -> void:
	var m := _mat(Color(0.5, 0.65, 1.0), 0.5)
	m.emission = Color(0.4, 0.6, 1.0)
	m.emission_energy_multiplier = 3.0
	_mesh(self, _box(Vector3(1.2, 0.05, 0.1)), m, at)


func _double_door(at: Vector3) -> void:
	var wood := _mat(Color(0.25, 0.15, 0.09), 0.45)
	var gold := _mat(Color(0.85, 0.7, 0.3), 0.3, 0.0, 0.85)
	for sz in [-1.0, 1.0]:
		_mesh(self, _box(Vector3(0.12, 2.8, 0.95)), wood, at + Vector3(0, 1.4, 0.5 * sz))
		_mesh(self, _box(Vector3(0.16, 0.5, 0.04)), gold, at + Vector3(-0.04, 1.2, 0.12 * sz))
	_mesh(self, _box(Vector3(0.2, 0.2, 2.2)), gold, at + Vector3(0, 2.9, 0))


func _desk(at: Vector3) -> void:
	var wood := _mat(Color(0.22, 0.13, 0.08), 0.35)
	_mesh(self, _box(Vector3(2.4, 0.08, 1.0)), wood, at + Vector3(0, 0.78, 0))
	_mesh(self, _box(Vector3(2.3, 0.74, 0.9)), wood, at + Vector3(0, 0.37, 0))
	var leather := _mat(Color(0.08, 0.06, 0.06), 0.5)
	_mesh(self, _box(Vector3(0.7, 0.12, 0.7)), leather, at + Vector3(0, 0.5, -0.9))          # 빈 의자
	_mesh(self, _box(Vector3(0.7, 0.9, 0.14)), leather, at + Vector3(0, 0.95, -1.22))


# ---- 바깥 · 거리 도구(town3d.gd 가 처음 쓴다 — 위 도구들은 그대로) ----

var _mats := {}


## 나눠 쓰는 재질 — 같은 값이면 같은 재질 하나(폰: 재질 · 그리기 묶음을 줄인다)
func _shared(c: Color, rough := 0.7, rim := 0.0, metal := 0.0) -> StandardMaterial3D:
	var k := "%s/%.2f/%.2f/%.2f" % [c.to_html(), rough, rim, metal]
	if not _mats.has(k):
		_mats[k] = _mat(c, rough, rim, metal)
	return _mats[k]


## 스스로 빛나는 재질(창 불빛 · 등 · 간판)
func _glow(c: Color, energy := 2.5) -> StandardMaterial3D:
	var k := "glow/%s/%.2f" % [c.to_html(), energy]
	if not _mats.has(k):
		var m := _mat(c, 0.5)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		_mats[k] = m
	return _mats[k]


## 해 · 달(그림자 하나) — _top 과 같되 각도를 고른다(노을 = 낮게 · 길게). 뒤에서 오는 약한 윤곽 빛도 같이
func _sun(col: Color, energy: float, rot: Vector3, rim_col := Color(0.6, 0.7, 1.0), rim_e := 0.3) -> void:
	var l := DirectionalLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.rotation_degrees = rot
	l.shadow_enabled = _detail
	l.shadow_blur = 1.6
	l.directional_shadow_max_distance = 24.0
	add_child(l)
	var rim := DirectionalLight3D.new()
	rim.light_color = rim_col
	rim.light_energy = rim_e
	rim.rotation_degrees = Vector3(-20, 180, 0)
	add_child(rim)


## 안개(먼 곳을 빛깔로 덮는다 — 노을 · 눈 오는 밤). _env 뒤에 부른다
func _fog(col: Color, density: float) -> void:
	for c in get_children():
		if c is WorldEnvironment:
			var e: Environment = c.environment
			e.fog_enabled = true
			e.fog_light_color = col
			e.fog_density = density
			e.fog_sky_affect = 0.0


## 넓은 땅(바깥 — 카메라가 걸을 곳 둘레 6m 까지 본다). 상세 그림이면 lo ~ hi 잔무늬 결(_noise_tex)을 period(m)마다 되풀이,
## 아니면 가운데 빛깔 하나
func _ground(b: Rect2, lo: Color, hi: Color, rough: float, seed_v: int, margin := 8.0, period := 2.0) -> void:
	var m := _mat(lo.lerp(hi, 0.5), rough)
	m.metallic_specular = 0.4
	var size := Vector2(b.size.x + margin * 2.0, b.size.y + margin * 2.0)
	if _detail:
		m.albedo_color = Color.WHITE
		m.albedo_texture = _noise_tex(lo, hi, seed_v)
		m.uv1_scale = Vector3(size.x / period, size.y / period, 1)
	var pm := PlaneMesh.new()
	pm.size = size
	_mesh(self, pm, m, Vector3(b.get_center().x, 0, b.get_center().y))


## 바닥에 붙은 판(선 · 얼룩 · 눈 · 칠) — 걸어도 되는 얇은 상자
func _decal(r: Rect2, mat: Material, y := 0.004) -> MeshInstance3D:
	return _mesh(self, _box(Vector3(r.size.x, 0.006, r.size.y)), mat, Vector3(r.get_center().x, y, r.get_center().y))


## 잔무늬 결(바닥 · 흙 · 아스팔트) — lo ~ hi 사이 작은 점 + 큰 얼룩. 이어 붙는다(가장자리가 맞음) · 결정적(seed)
func _noise_tex(lo: Color, hi: Color, seed_v: int, n := 64, fine := 0.55) -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = 900 + seed_v
	var g := 8
	var coarse: Array = []
	for i in g * g:
		coarse.append(r.randf())
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var fx := float(x) / n * g
			var fy := float(y) / n * g
			var x0 := int(fx) % g
			var y0 := int(fy) % g
			var tx := fx - floorf(fx)
			var ty := fy - floorf(fy)
			var a: float = lerpf(coarse[y0 * g + x0], coarse[y0 * g + (x0 + 1) % g], tx)
			var c: float = lerpf(coarse[((y0 + 1) % g) * g + x0], coarse[((y0 + 1) % g) * g + (x0 + 1) % g], tx)
			var v := lerpf(lerpf(a, c, ty), r.randf(), fine)
			img.set_pixel(x, y, lo.lerp(hi, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## 줄무늬 결(골함석 · 벽지 · 펜스) — cols 를 차례로 한 줄(가로로 되풀이)
func _stripe_tex(cols: Array) -> ImageTexture:
	var img := Image.create(cols.size(), 1, false, Image.FORMAT_RGB8)
	for i in cols.size():
		img.set_pixel(i, 0, cols[i])
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## 결이 있는 판(벽면 · 간판) — 앞(+z 를 보는 면)에 붙는 사각 판, 결을 rep 만큼 되풀이
func _panel(at: Vector3, size: Vector2, tex: Texture2D, rep: Vector2, tint := Color.WHITE, rough := 0.7, yaw := 0.0) -> MeshInstance3D:
	var m := _mat(tint, rough)
	m.albedo_texture = tex
	m.uv1_scale = Vector3(rep.x, rep.y, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var q := QuadMesh.new()
	q.size = size
	var mi := _mesh(self, q, m, at)
	mi.rotation_degrees.y = yaw
	return mi


## 돌려 놓는 묶음(차 · 굴착기 …) — 이 아래에 _mesh 로 붙인다
func _group(at: Vector3, yaw := 0.0) -> Node3D:
	var g := Node3D.new()
	g.position = at
	g.rotation_degrees.y = yaw
	add_child(g)
	return g


## 내리는 눈(작은 점 — 같은 재질 하나). 상세 그림(_detail)일 때만
func _snow(center: Vector3, ext: Vector3, amount: int) -> void:
	if not _detail:
		return
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3(0.25, -1, 0.1)
	p.spread = 20.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, -0.12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var s := SphereMesh.new()
	s.radius = 0.028
	s.height = 0.056
	s.radial_segments = 4
	s.rings = 2
	p.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.95, 1.0)
	p.material_override = m
	p.position = center
	add_child(p)


## 승용차(앞 = +x). body 차체 색 — 돌려 놓은 묶음을 돌려준다(경광등 · 무늬를 더 붙일 수 있게)
func _car(at: Vector3, yaw: float, body: Color, lights := true) -> Node3D:
	var g := _group(at, yaw)
	var paint := _shared(body, 0.35, 0.0, 0.25)
	var glass := _shared(Color(0.16, 0.2, 0.26), 0.1, 0.0, 0.5)
	var tire := _shared(Color(0.05, 0.05, 0.05), 0.9)
	_mesh(g, _box(Vector3(4.3, 0.62, 1.76)), paint, Vector3(0, 0.55, 0))
	_mesh(g, _box(Vector3(2.3, 0.52, 1.56)), glass, Vector3(-0.25, 1.12, 0))
	_mesh(g, _box(Vector3(2.0, 0.07, 1.48)), paint, Vector3(-0.3, 1.41, 0))
	for wx in [-1.38, 1.38]:
		for wz in [-0.8, 0.8]:
			var w := _mesh(g, _cyl(0.33, 0.33, 0.24), tire, Vector3(wx, 0.33, wz))
			w.rotation_degrees.x = 90
	if lights:
		for z in [-0.6, 0.6]:
			_mesh(g, _box(Vector3(0.05, 0.12, 0.34)), _glow(Color(1.0, 0.95, 0.8), 1.6), Vector3(2.15, 0.66, z))
			_mesh(g, _box(Vector3(0.05, 0.12, 0.3)), _glow(Color(0.9, 0.08, 0.05), 1.2), Vector3(-2.15, 0.68, z))
	return g


## 폐차(바퀴 · 불 없이 차체 둘 — 쌓아 올리는 더미용). roll 은 옆으로 기운 각
func _wreck(parent: Node3D, at: Vector3, yaw: float, body: Color, roll := 0.0) -> void:
	var g := Node3D.new()
	g.position = at
	g.rotation_degrees = Vector3(0, yaw, roll)
	parent.add_child(g)
	_mesh(g, _box(Vector3(4.1, 0.6, 1.7)), _shared(body, 0.85), Vector3(0, 0.3, 0))
	_mesh(g, _box(Vector3(2.0, 0.42, 1.5)), _shared(body.darkened(0.35), 0.8), Vector3(-0.2, 0.8, 0))


## 가로등(기둥 + 등 — 팔은 +z 로). 빛은 따로(_omni — 점광 3개 이하). lit = false 면 낮(등이 꺼져 있다)
func _lamp_post(at: Vector3, lamp: Color, h := 4.2, arm := 0.9, lit := true) -> void:
	var pole := _shared(Color(0.22, 0.23, 0.25), 0.5, 0.0, 0.6)
	_mesh(self, _cyl(0.07, 0.09, h), pole, at + Vector3(0, h * 0.5, 0))
	_mesh(self, _box(Vector3(0.08, 0.08, arm)), pole, at + Vector3(0, h - 0.05, arm * 0.5))
	_mesh(self, _box(Vector3(0.36, 0.1, 0.5)), _glow(lamp, 3.0) if lit else _shared(lamp, 0.4), at + Vector3(0, h - 0.14, arm))


## 드럼통
func _barrel(at: Vector3, col: Color) -> void:
	_mesh(self, _cyl(0.3, 0.3, 0.88), _shared(col, 0.8, 0.0, 0.3), at + Vector3(0, 0.44, 0))
	var band := _shared(col.darkened(0.3), 0.7, 0.0, 0.3)
	for y in [0.3, 0.6]:
		_mesh(self, _cyl(0.31, 0.31, 0.04), band, at + Vector3(0, y, 0))


## 쌓인 타이어 n 개
func _tires(at: Vector3, n: int) -> void:
	var t := TorusMesh.new()
	t.inner_radius = 0.18
	t.outer_radius = 0.36
	t.rings = 12
	t.ring_segments = 6
	var m := _shared(Color(0.06, 0.06, 0.06), 0.9)
	for i in n:
		_mesh(self, t, m, at + Vector3(0.03 * (i % 2), 0.1 + i * 0.19, 0))


func _mat(c: Color, rough := 0.7, rim := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 16
	c.rings = 1
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
