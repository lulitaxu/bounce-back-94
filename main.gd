extends Node2D

const W := 720.0
const H := 405.0
const GROUND_Y := 338.0
const GRAVITY := 1500.0
const MOVE_SPEED := 250.0
const JUMP_VEL := -640.0
const QUOTAS := {1: 8, 2: 12, 3: 10}

var player_pos := Vector2(120.0, GROUND_Y)
var vy := 0.0
var on_ground := true
var just_bounced := false
var run_time := 0.0
var moving := false
var shoot_cd := 0.0
var bullets: Array = []
var enemies: Array = []
var obstacles: Array = []
var score := 0
var lives := 3
var started := false
var game_over := false
var won := false
var level := 1
var kills := 0
var boss_spawned := false
var banner_timer := 0.0
var elapsed := 0.0
var spawn_timer := 1.0
var obstacle_timer := 3.5
var bg_time := 0.0
var glitch_wait := 2.2
var glitch_on := 0.0
var rng := RandomNumberGenerator.new()
var teleport_cd := 0.0
var facing := 1.0
var popups: Array = []
var ghost_pos := Vector2.ZERO
var ghost_t := 0.0
var ui_font: Font = preload("res://pressstart.ttf")
var shake_t := 0.0
var scroll := 0.0
var world_spd := 60.0
var explosions: Array = []
var bg_tex: Texture2D = preload("res://bg_city.png")
var bg_tex2: Texture2D = preload("res://bg_dusk.png")
var bg_tex3: Texture2D = preload("res://bg_core.png")
const SCENES := ["DOWNTOWN", "DUSK DISTRICT", "MELTDOWN CORE"]

@onready var score_label: Label = $HUD/ScoreLabel
@onready var lives_label: Label = $HUD/LivesLabel
@onready var center_label: Label = $HUD/CenterLabel

func _ready() -> void:
	rng.randomize()
	score_label.add_theme_font_override("font", ui_font)
	lives_label.add_theme_font_override("font", ui_font)
	center_label.add_theme_font_override("font", ui_font)
	score_label.add_theme_font_size_override("font_size", 12)
	lives_label.add_theme_font_size_override("font_size", 12)
	center_label.add_theme_font_size_override("font_size", 14)
	center_label.text = ""
	_update_hud()

func _process(delta: float) -> void:
	bg_time += delta
	if glitch_on > 0.0:
		glitch_on -= delta
	else:
		glitch_wait -= delta
		if glitch_wait <= 0.0:
			glitch_on = 0.13
			glitch_wait = rng.randf_range(0.8, 1.6) if level == 3 else rng.randf_range(1.8, 3.6)
	if game_over:
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		queue_redraw()
		return
	if not started:
		center_label.text = "MISSION: fight through 3 levels, destroy the boss.\nA/D run, SPACE jump (landings bounce), J shoot, K teleport.\nJump the spikes and energy walls. Blast drones mid-jump.\nPress SPACE to start\nNO SECOND CHANCES. JUST BOUNCE BACK."
		if Input.is_action_just_pressed("ui_accept"):
			started = true
			center_label.text = ""
		_update_hud()
		queue_redraw()
		return

	if shake_t > 0.0:
		shake_t -= delta
	for i in range(explosions.size() - 1, -1, -1):
		var ex: Dictionary = explosions[i]
		ex.t += delta
		if ex.t > 0.38:
			explosions.remove_at(i)
			continue
		explosions[i] = ex
	if center_label.text == "!! WARNING !!":
		center_label.visible = int(bg_time * 5.0) % 2 == 0

	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			center_label.text = ""

	var dir := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		dir = -1.0
	if Input.is_key_pressed(KEY_D):
		dir = 1.0
	moving = abs(dir) > 0.01
	if moving:
		facing = dir
	player_pos.x = clampf(player_pos.x + dir * MOVE_SPEED * delta, 30.0, W - 70.0)
	run_time += delta * (1.0 if moving else 0.25)
	var spd: float = clampf(60.0 + dir * 95.0, 15.0, 165.0)
	scroll += spd * delta
	world_spd = spd

	if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) and on_ground:
		vy = JUMP_VEL
		on_ground = false
		just_bounced = false
	vy += GRAVITY * delta
	player_pos.y += vy * delta
	if player_pos.y >= GROUND_Y:
		if vy > 320.0 and not just_bounced:
			player_pos.y = GROUND_Y
			vy = -vy * 0.42
			just_bounced = true
		else:
			player_pos.y = GROUND_Y
			vy = 0.0
			on_ground = true
	else:
		on_ground = false

	teleport_cd -= delta
	if ghost_t > 0.0:
		ghost_t -= delta
	if (Input.is_key_pressed(KEY_K) or Input.is_key_pressed(KEY_SHIFT)) and teleport_cd <= 0.0:
		teleport_cd = 1.2
		ghost_pos = player_pos
		ghost_t = 0.25
		player_pos.x = clampf(player_pos.x + facing * 150.0, 30.0, W - 70.0)
		glitch_on = maxf(glitch_on, 0.18)
		_add_popup(player_pos + Vector2(0.0, -72.0), "TP!", Color(0.4, 0.95, 1.0))
	lives_label.modulate = lives_label.modulate.lerp(Color(1, 1, 1), clampf(delta * 5.0, 0.0, 1.0))

	shoot_cd -= delta
	if (Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_X) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and shoot_cd <= 0.0:
		shoot_cd = 0.17
		bullets.append({"pos": Vector2(player_pos.x + 34.0 * facing, player_pos.y - 31.0), "dir": facing})

	elapsed += delta
	if banner_timer <= 0.0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = clampf(1.1 - minf(elapsed * 0.006, 0.25) - float(level) * 0.08, 0.5, 1.1)
			_spawn_enemy()
		obstacle_timer -= delta
		if obstacle_timer <= 0.0:
			obstacle_timer = rng.randf_range(2.6, 4.2) - float(level) * 0.3
			_spawn_obstacle()

	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b.pos.x += 660.0 * b.dir * delta
		if b.pos.x > W + 20.0 or b.pos.x < -20.0:
			bullets.remove_at(i)
			continue
		bullets[i] = b
		var bullet_gone := false
		for ob in obstacles:
			if ob.kind == "barrier" and abs(b.pos.x - ob.x) < 10.0 and b.pos.y > GROUND_Y - 58.0:
				bullets.remove_at(i)
				bullet_gone = true
				break
		if bullet_gone:
			continue
		for j in range(enemies.size() - 1, -1, -1):
			var e: Dictionary = enemies[j]
			var ey: float = e.pos.y - _hop_h(e)
			if abs(b.pos.x - e.pos.x) < 26.0 and abs(b.pos.y - (ey - 24.0)) < 28.0:
				bullets.remove_at(i)
				bullet_gone = true
				if e.get("boss", false):
					e.hp -= 1
					shake_t = maxf(shake_t, 0.12)
					glitch_on = maxf(glitch_on, 0.08)
					if e.hp <= 0:
						enemies.remove_at(j)
						score += 150
						_win()
					else:
						enemies[j] = e
				else:
					enemies.remove_at(j)
					_add_popup(e.pos + Vector2(0.0, -62.0), "+25", Color(1.0, 0.9, 0.4))
					_explode(e.pos + Vector2(0.0, -24.0), false)
					score += 25
					kills += 1
					glitch_on = maxf(glitch_on, 0.06)
					_check_level()
				break
		if bullet_gone:
			continue

	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		e.pos.x -= e.speed * delta
		if e.pos.x < -30.0:
			enemies.remove_at(i)
			continue
		var ey2: float = e.pos.y - _hop_h(e)
		if abs(e.pos.x - player_pos.x) < 27.0 and abs(ey2 - player_pos.y) < 42.0:
			enemies.remove_at(i)
			_damage()
			if game_over:
				return
			continue
		enemies[i] = e

	for i in range(obstacles.size() - 1, -1, -1):
		var ob: Dictionary = obstacles[i]
		if ob.kind == "barrier":
			ob.x -= (world_spd + 25.0) * delta
			if ob.x < -40.0:
				obstacles.remove_at(i)
				continue
			if abs(player_pos.x - ob.x) < 24.0 and player_pos.y > GROUND_Y - 58.0:
				obstacles.remove_at(i)
				_damage()
				if game_over:
					return
				continue
			obstacles[i] = ob
		else:
			ob.x -= world_spd * delta
			if ob.x < -70.0:
				obstacles.remove_at(i)
				continue
			ob.t -= delta
			if ob.t <= 0.0:
				obstacles.remove_at(i)
				continue
			if not ob.hit and on_ground and abs(player_pos.x - (ob.x + 23.0)) < 30.0:
				ob.hit = true
				_damage()
				if game_over:
					return
			obstacles[i] = ob

	for i in range(popups.size() - 1, -1, -1):
		var pp: Dictionary = popups[i]
		pp.t += delta
		pp.pos.y -= 34.0 * delta
		if pp.t > 0.8:
			popups.remove_at(i)
			continue
		popups[i] = pp

	_update_hud()
	queue_redraw()

func _add_popup(pos: Vector2, txt: String, col: Color) -> void:
	popups.append({"pos": pos, "text": txt, "t": 0.0, "col": col})

func _explode(pos: Vector2, big: bool) -> void:
	explosions.append({"pos": pos, "t": 0.0, "big": big, "seed": rng.randf_range(0.0, 100.0)})

func _spawn_enemy() -> void:
	if level >= 2 and rng.randf() < 0.3:
		enemies.append({
			"pos": Vector2(W + 30.0, GROUND_Y - 128.0),
			"speed": rng.randf_range(120.0, 175.0),
			"hop": false, "fly": true, "boss": false, "hp": 1,
			"phase": rng.randf_range(0.0, 6.28),
		})
	else:
		enemies.append({
			"pos": Vector2(W + 30.0, GROUND_Y),
			"speed": rng.randf_range(70.0, 135.0) + minf(elapsed * 0.9, 45.0) + float(level) * 9.0,
			"hop": rng.randf() < 0.45, "fly": false, "boss": false, "hp": 1,
			"phase": rng.randf_range(0.0, 6.28),
		})

func _spawn_obstacle() -> void:
	if level >= 2 and rng.randf() < 0.45:
		obstacles.append({"kind": "barrier", "x": W + 30.0, "t": 0.0, "hit": false})
	else:
		obstacles.append({"kind": "spike", "x": W + 30.0, "t": 16.0, "hit": false})

func _spawn_boss() -> void:
	boss_spawned = true
	enemies.clear()
	enemies.append({
		"pos": Vector2(W + 60.0, GROUND_Y),
		"speed": 34.0,
		"hop": false, "fly": false, "boss": true, "hp": 5,
		"phase": 0.0,
	})
	center_label.visible = true
	center_label.text = "!! WARNING !!"
	banner_timer = 2.0

func _check_level() -> void:
	if level < 3 and kills >= int(QUOTAS[level]):
		level += 1
		kills = 0
		enemies.clear()
		bullets.clear()
		obstacles.clear()
		center_label.visible = true
		center_label.text = "LEVEL %d - %s" % [level, SCENES[level - 1]]
		banner_timer = 2.4
	elif level == 3 and not boss_spawned and kills >= int(QUOTAS[3]):
		kills = 0
		bullets.clear()
		obstacles.clear()
		_spawn_boss()

func _damage() -> void:
	lives -= 1
	shake_t = 0.25
	lives_label.modulate = Color(1.0, 0.35, 0.35)
	_add_popup(player_pos + Vector2(0.0, -72.0), "-1 LIFE", Color(1.0, 0.4, 0.4))
	glitch_on = 0.28
	if lives <= 0:
		_game_over()

func _game_over() -> void:
	game_over = true
	center_label.visible = true
	center_label.text = "GAME OVER\nScore: %d\nPress R to restart" % score
	_update_hud()

func _win() -> void:
	won = true
	game_over = true
	center_label.visible = true
	center_label.text = "MISSION COMPLETE\nScore: %d\nPress R to play again" % score
	_update_hud()

func _hop_h(e: Dictionary) -> float:
	if e.get("hop", false):
		return abs(sin(bg_time * 4.5 + e.phase)) * 36.0
	return 0.0

func _update_hud() -> void:
	if boss_spawned and not won:
		score_label.text = "Score: %d   Level %d   BOSS" % [score, level]
	else:
		score_label.text = "Score: %d   Level %d   %d/%d" % [score, level, kills, int(QUOTAS[level])]
	lives_label.text = "Lives: %d  TP: %s" % [maxi(lives, 0), "OK" if teleport_cd <= 0.0 else "..."]

func _draw() -> void:
	if shake_t > 0.0:
		draw_set_transform(Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_t * 22.0, 0.0, Vector2.ONE)
	var bg_scale: float = 0.34
	var dw: float = 2304.0 * bg_scale
	var dh: float = 1296.0 * bg_scale
	var ox: float = -fmod(scroll, dw)
	var oy: float = (H - dh) * 0.5
	draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.05, 0.12))
	var tex: Texture2D = bg_tex
	if level == 2:
		tex = bg_tex2
	elif level == 3:
		tex = bg_tex3
	var wash := Color(0.16, 0.02, 0.2, 0.27)
	if level == 2:
		wash = Color(0.35, 0.12, 0.02, 0.14)
	elif level == 3:
		wash = Color(0.45, 0.02, 0.05, 0.32)
	draw_texture_rect(tex, Rect2(ox, oy, dw, dh), false)
	draw_texture_rect(tex, Rect2(ox + dw, oy, dw, dh), false)
	draw_rect(Rect2(0, 0, W, H), wash)
	if glitch_on > 0.0:
		var sy: float = 40.0 + fmod(bg_time * 977.0, 270.0)
		var reg_y: float = clampf((sy - oy) / bg_scale, 0.0, 1200.0)
		var off: float = 16.0 if int(bg_time * 40.0) % 2 == 0 else -16.0
		draw_texture_rect_region(tex, Rect2(ox + off, sy, dw, 22.0), Rect2(0.0, reg_y, 2304.0, 22.0 / bg_scale))
		for i in range(22):
			var nx: float = rng.randf_range(0.0, W)
			var ny: float = rng.randf_range(0.0, H)
			var ncol: Color = Color(0.3, 0.95, 1.0, 0.5) if i % 3 == 0 else (Color(1.0, 0.3, 0.8, 0.5) if i % 3 == 1 else Color(1, 1, 1, 0.45))
			draw_rect(Rect2(nx, ny, rng.randf_range(4.0, 26.0), 3.0), ncol)
	draw_rect(Rect2(0, GROUND_Y + 14.0, W, H - GROUND_Y - 14.0), Color(0.06, 0.07, 0.15))
	draw_rect(Rect2(0, GROUND_Y + 14.0, W, 4.0), Color(0.35, 1.0, 0.45, 0.95))
	for i in range(17):
		var px: float = fposmod(float(i) * 46.0 - scroll * 1.6, W + 46.0) - 23.0
		draw_rect(Rect2(px, GROUND_Y + 20.0, 2.0, H - GROUND_Y - 26.0), Color(0.4, 0.6, 0.9, 0.18))
	for i in range(13):
		var dx: float = fposmod(float(i) * 70.0 - scroll * 1.6, W + 70.0) - 35.0
		draw_rect(Rect2(dx, GROUND_Y + 34.0, 34.0, 4.0), Color(0.45, 0.8, 1.0, 0.4))
	for ob in obstacles:
		_draw_obstacle(ob)
	for e in enemies:
		_draw_bot(e)
	for b in bullets:
		draw_rect(Rect2(b.pos.x, b.pos.y - 2.0, 13.0, 4.0), Color(0.35, 0.8, 1.0))
		draw_rect(Rect2(b.pos.x + 2.0, b.pos.y - 1.0, 6.0, 2.0), Color(1, 1, 1))
	if ghost_t > 0.0:
		var ga: float = ghost_t / 0.25 * 0.45
		var gc := Color(0.4, 0.95, 1.0, ga)
		draw_rect(Rect2(ghost_pos.x - 10.0, ghost_pos.y - 37.0, 20.0, 21.0), gc)
		draw_rect(Rect2(ghost_pos.x - 8.0, ghost_pos.y - 53.0, 16.0, 15.0), gc)
	for ex in explosions:
		var et: float = float(ex.t) / 0.38
		var ecnt: int = 16 if ex.big else 10
		var edist: float = 48.0 if ex.big else 30.0
		for k in range(ecnt):
			var ang: float = float(k) * 2.4 + float(ex.seed)
			var d: float = et * edist * (0.6 + 0.4 * sin(float(ex.seed) + float(k)))
			var ep: Vector2 = ex.pos + Vector2(cos(ang) * d, sin(ang) * d - et * 16.0)
			var esz: float = (1.0 - et) * (11.0 if ex.big else 7.0)
			var ecol: Color = [Color(1, 1, 1), Color(1.0, 0.85, 0.25), Color(1.0, 0.5, 0.15), Color(0.9, 0.15, 0.1)][k % 4]
			ecol.a = 1.0 - et
			draw_rect(Rect2(ep - Vector2(esz, esz) * 0.5, Vector2(esz, esz)), ecol)
	_draw_player()
	if not started:
		var jx: float = rng.randf_range(-3.0, 3.0) if glitch_on > 0.0 else 0.0
		draw_string(ui_font, Vector2(-2.0 + jx, 106.0), "BOUNCE BACK '94", HORIZONTAL_ALIGNMENT_CENTER, W, 38, Color(1.0, 0.3, 0.8, 0.85))
		draw_string(ui_font, Vector2(2.0 + jx, 106.0), "BOUNCE BACK '94", HORIZONTAL_ALIGNMENT_CENTER, W, 38, Color(0.3, 0.9, 1.0, 0.85))
		draw_string(ui_font, Vector2(jx, 106.0), "BOUNCE BACK '94", HORIZONTAL_ALIGNMENT_CENTER, W, 38, Color(1, 1, 1))
		draw_string(ui_font, Vector2(-1.0 - jx, 138.0), "NEON APOCALYPSE", HORIZONTAL_ALIGNMENT_CENTER, W, 21, Color(1.0, 0.3, 0.8, 0.8))
		draw_string(ui_font, Vector2(1.0 - jx, 138.0), "NEON APOCALYPSE", HORIZONTAL_ALIGNMENT_CENTER, W, 21, Color(0.3, 0.9, 1.0, 0.8))
		draw_string(ui_font, Vector2(-jx, 138.0), "NEON APOCALYPSE", HORIZONTAL_ALIGNMENT_CENTER, W, 21, Color(0.92, 0.08, 0.12))
	for pp in popups:
		var pa: float = 1.0 - float(pp.t) / 0.8
		var pc: Color = pp.col
		pc.a = pa
		draw_string(ui_font, Vector2(pp.pos.x - 60.0, pp.pos.y), pp.text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, pc)
	for yy in range(0, int(H), 4):
		draw_rect(Rect2(0.0, float(yy), W, 1.0), Color(0, 0, 0, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_obstacle(ob: Dictionary) -> void:
	if ob.kind == "barrier":
		var x: float = ob.x
		draw_rect(Rect2(x - 11.0, GROUND_Y - 44.0, 22.0, 58.0), Color(0.3, 0.9, 1.0, 0.32))
		draw_rect(Rect2(x - 11.0, GROUND_Y - 44.0, 22.0, 5.0), Color(0.3, 0.9, 1.0, 0.8))
		draw_rect(Rect2(x - 3.0, GROUND_Y - 50.0, 6.0, 64.0), Color(0.35, 0.4, 0.5))
	else:
		var x0: float = ob.x
		var base: float = GROUND_Y + 14.0
		for k in range(4):
			var bx: float = x0 + float(k) * 11.5
			draw_colored_polygon(PackedVector2Array([Vector2(bx, base), Vector2(bx + 11.0, base), Vector2(bx + 5.5, base - 17.0)]), Color(0.75, 0.78, 0.85))
		draw_rect(Rect2(x0, base - 2.0, 46.0, 3.0), Color(0.9, 0.3, 0.3))

const PALETTE := {"R": Color(0.92, 0.08, 0.12), "S": Color(0.92, 0.72, 0.55), "K": Color(0.05, 0.05, 0.08), "G": Color(0.3, 0.88, 0.35), "D": Color(0.16, 0.42, 0.2), "C": Color(0.35, 0.9, 1.0), "B": Color(0.45, 0.3, 0.15), "N": Color(0.16, 0.2, 0.38), "O": Color(0.08, 0.08, 0.1), "Y": Color(0.55, 0.58, 0.65)}
const FRAME_A := ["....RRRR....", "..R.RRRRRR..", "....SSSK....", "....SSSS....", "...GGGGGD...", "...GGCGGSYYY", "...GGGG..Y..", "...BBBB.....", "...NN..NN...", "...NN...NN..", "...NN....NN.", "..OO......OO"]
const FRAME_B := ["....RRRR....", "..R.RRRRRR..", "....SSSK....", "....SSSS....", "...GGGGGD...", "...GGCGGSYYY", "...GGGG..Y..", "...BBBB.....", "....NNNN....", "..NN....NN..", ".NN......NN.", "OO........OO"]
const FRAME_AIR := ["....RRRR....", "..R.RRRRRR..", "....SSSK....", "....SSSS....", "...GGGGGD...", "...GGCGGSYYY", "...GGGG..Y..", "...BBBB.....", "...NN..N....", "...NN..NN...", "..OO...NN...", "........OO.."]

func _draw_player() -> void:
	var frame: Array = FRAME_A
	if not on_ground:
		frame = FRAME_AIR
	elif moving and int(run_time * 9.0) % 2 == 0:
		frame = FRAME_B
	var cs := 4.5
	var bob: float = sin(run_time * 14.0) * 1.5 if on_ground else 0.0
	var top: float = player_pos.y - 12.0 * cs + bob
	for row in range(frame.size()):
		var line: String = frame[row]
		for col in range(line.length()):
			var ch: String = line.substr(col, 1)
			if ch == ".":
				continue
			var gx: int = (11 - col) if facing < 0.0 else col
			var colr: Color = PALETTE[ch]
			draw_rect(Rect2(player_pos.x + (float(gx) - 5.5) * cs, top + float(row) * cs, cs, cs), colr)

func _draw_bot(e: Dictionary) -> void:
	var x: float = e.pos.x
	var y: float = e.pos.y - _hop_h(e)
	if glitch_on > 0.0:
		x += rng.randf_range(-4.0, 4.0)
	if e.get("fly", false):
		var fl: float = sin(bg_time * 30.0 + e.phase) * 3.0
		draw_rect(Rect2(x - 21.0, y - 24.0 + fl, 42.0, 3.0), Color(0.7, 0.72, 0.8))
		draw_rect(Rect2(x - 16.0, y - 18.0, 32.0, 14.0), Color(0.45, 0.3, 0.7))
		draw_rect(Rect2(x - 4.0, y - 13.0, 9.0, 4.0), Color(1.0, 0.25, 0.3))
		return
	if e.get("boss", false):
		draw_rect(Rect2(x - 20.0, y - 18.0, 13.0, 18.0), Color(0.2, 0.16, 0.3))
		draw_rect(Rect2(x + 7.0, y - 18.0, 13.0, 18.0), Color(0.2, 0.16, 0.3))
		draw_rect(Rect2(x - 24.0, y - 64.0, 48.0, 46.0), Color(0.55, 0.25, 0.7))
		draw_rect(Rect2(x - 16.0, y - 84.0, 32.0, 21.0), Color(0.42, 0.2, 0.62))
		draw_rect(Rect2(x - 11.0, y - 76.0, 22.0, 7.0), Color(1.0, 0.25, 0.3))
		for hp_i in range(int(e.hp)):
			draw_rect(Rect2(x - 20.0 + float(hp_i) * 9.0, y - 96.0, 7.0, 5.0), Color(1.0, 0.4, 0.4))
		return
	var swing: float = sin(bg_time * 10.0 + e.phase) * 4.0
	draw_rect(Rect2(x - 11.0 + swing, y - 10.0, 8.0, 10.0), Color(0.2, 0.16, 0.3))
	draw_rect(Rect2(x + 3.0 - swing, y - 10.0, 8.0, 10.0), Color(0.2, 0.16, 0.3))
	draw_rect(Rect2(x - 17.0, y - 35.0, 4.0, 14.0), Color(0.32, 0.18, 0.5))
	draw_rect(Rect2(x + 13.0, y - 35.0, 4.0, 14.0), Color(0.32, 0.18, 0.5))
	draw_rect(Rect2(x - 13.0, y - 35.0, 26.0, 25.0), Color(0.5, 0.3, 0.75))
	draw_rect(Rect2(x - 3.0, y - 27.0, 6.0, 6.0), Color(1.0, 0.85, 0.25) if int(bg_time * 3.0) % 2 == 0 else Color(0.5, 0.4, 0.1))
	draw_rect(Rect2(x - 9.0, y - 46.0, 18.0, 12.0), Color(0.38, 0.22, 0.6))
	draw_rect(Rect2(x - 6.0, y - 41.0, 12.0, 4.0), Color(1.0, 0.25, 0.3))
	draw_rect(Rect2(x - 1.0, y - 52.0, 2.0, 7.0), Color(0.7, 0.7, 0.8))
	draw_rect(Rect2(x - 2.0, y - 55.0, 4.0, 4.0), Color(1.0, 0.85, 0.25))
