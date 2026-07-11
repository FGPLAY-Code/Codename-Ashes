extends Node

## 枪械控制器（GDScript 版）
## 优先读取 weapon_data（WeaponData 资源），为 null 时降级使用 @export 默认值

# ===== 导出属性 =====
@export var weapon_data: WeaponData = null

@export var magazine_capacity: int = 30
@export var reserve_ammo_start: int = 90
@export var fire_rate_auto: float = 0.08
@export var fire_rate_semi: float = 0.15
@export var base_damage: float = 25.0
@export var recoil_kick: float = 0.03
@export var bloom_per_shot: float = 0.15
@export var bloom_recovery: float = 0.6
@export var head_bottom_offset: float = 4.0
@export var head_top_offset: float = 4.5
@export var gun_sound_path: String = "res://resources/mp3/ak_gunshot.mp3"

# ===== 信号 =====
signal ammo_changed(current, max, reserve)
signal fire_mode_changed(mode)
signal reload_state_changed(reloading)
signal shot_fired(headshot_multiplier)

# ===== 运行时状态 =====
var _ammo: int = 0
var _reserve_ammo: int = 0
var _is_reloading: bool = false
var _fire_cooldown: float = 0.0
var _fire_mode: String = "AUTO"
var _bloom: float = 0.0
var _prev_trigger: bool = false

# ===== 节点引用（延迟获取） =====
var _ray: RayCast3D = null
var _camera_pivot: Node3D = null
var _gun_muzzle: Node3D = null
var _weapon_model: Node3D = null
var _spread = null
var _gun_audio: AudioStreamPlayer = null

# ===================================================================
# WeaponData 取值辅助（优先读资源，降级读 @export）
# ===================================================================

func _w_mag() -> int:      return weapon_data.magazine_capacity  if weapon_data else magazine_capacity
func _w_res() -> int:      return weapon_data.reserve_ammo_start if weapon_data else reserve_ammo_start
func _w_fa() -> float:     return weapon_data.fire_rate_auto    if weapon_data else fire_rate_auto
func _w_fs() -> float:     return weapon_data.fire_rate_semi    if weapon_data else fire_rate_semi
func _w_dmg() -> float:    return weapon_data.base_damage       if weapon_data else base_damage
func _w_rk() -> float:     return weapon_data.recoil_kick       if weapon_data else recoil_kick
func _w_bps() -> float:    return weapon_data.bloom_per_shot    if weapon_data else bloom_per_shot
func _w_br() -> float:     return weapon_data.bloom_recovery    if weapon_data else bloom_recovery
func _w_hbo() -> float:    return weapon_data.head_bottom_offset if weapon_data else head_bottom_offset
func _w_hto() -> float:    return weapon_data.head_top_offset   if weapon_data else head_top_offset
func _w_gsp() -> String:   return weapon_data.gun_sound_path    if weapon_data else gun_sound_path

# ===================================================================
# 生命周期
# ===================================================================

func _ready():
	_ammo = _w_mag()
	_reserve_ammo = _w_res()
	_fire_mode = "AUTO"
	_fire_cooldown = 0.0
	
	_resolve_refs()
	_propagate_weapon_data()
	_setup_gun_sound()
	
	emit_signal("ammo_changed", _ammo, _w_mag(), _reserve_ammo)
	emit_signal("fire_mode_changed", _fire_mode)

# ===================================================================
# 武器切换（由 player.gd 调用）
# ===================================================================

func switch_to_weapon(wd: WeaponData, model: Node3D, saved_ammo: int = -1, saved_reserve: int = -1) -> void:
	weapon_data = wd
	_weapon_model = model
	_ammo = saved_ammo if saved_ammo >= 0 else _w_mag()
	_reserve_ammo = saved_reserve if saved_reserve >= 0 else _w_res()
	_bloom = 0.0
	_fire_cooldown = 0.0
	_is_reloading = false
	_fire_mode = "AUTO"
	
	# 重新设置音效
	_setup_gun_sound()
	
	# 同步到 SpreadController
	var sc = get_node_or_null("../SpreadController")
	if sc:
		sc.weapon_data = wd
	
	emit_signal("ammo_changed", _ammo, _w_mag(), _reserve_ammo)
	emit_signal("fire_mode_changed", _fire_mode)
	emit_signal("reload_state_changed", false)

# ===================================================================

func _physics_process(delta: float):
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _bloom > 0.0:
		_bloom = maxf(0.0, _bloom - _w_br() * delta)

# ===================================================================
# 引用解析
# ===================================================================

func _resolve_refs():
	if _spread == null:
		_spread = get_node_or_null("../SpreadController")
	if _ray == null:
		_ray = get_node_or_null("../CameraPivot/Camera3D/RayCast3D")
	if _camera_pivot == null:
		_camera_pivot = get_node_or_null("../CameraPivot")
	if _gun_muzzle == null:
		_gun_muzzle = get_node_or_null("../CameraPivot/Camera3D/GunMuzzle")
	if _ray != null:
		var parent = get_parent()
		if parent != null:
			_ray.add_exception(parent)

func _propagate_weapon_data():
	# 同步 weapon_data 到 SpreadController 兄弟节点
	if weapon_data:
		var sc = get_node_or_null("../SpreadController")
		if sc and not sc.weapon_data:
			sc.weapon_data = weapon_data

# ===================================================================
# 射击驱动
# ===================================================================

func tick_fire(trigger_held: bool, crouching: bool, ads: bool, moving: bool):
	_resolve_refs()
	if _ray == null: return
	if _is_reloading: _prev_trigger = trigger_held; return
	
	var want_shoot := false
	if _fire_mode == "SEMI":
		if trigger_held and not _prev_trigger:
			want_shoot = true
	else:
		if trigger_held:
			want_shoot = true
	_prev_trigger = trigger_held
	
	if want_shoot and _ammo > 0 and _fire_cooldown <= 0.0:
		_do_shoot(crouching, ads, moving)

# ===================================================================
# 换弹
# ===================================================================

func start_reload():
	var cap = _w_mag()
	if _is_reloading or _ammo == cap or _reserve_ammo <= 0:
		return
	_is_reloading = true
	emit_signal("reload_state_changed", true)
	
	# 播放换弹音效
	_play_reload_sound()
	
	await get_tree().create_timer(1.5).timeout
	if _is_reloading:
		var needed = cap - _ammo
		var to_reload = min(needed, _reserve_ammo)
		_ammo += to_reload
		_reserve_ammo -= to_reload
		emit_signal("ammo_changed", _ammo, cap, _reserve_ammo)
	_is_reloading = false
	emit_signal("reload_state_changed", false)

# ===================================================================
# 射击模式切换
# ===================================================================

func toggle_fire_mode():
	if _is_reloading: return
	if _fire_mode == "AUTO":
		_fire_mode = "SEMI"
		_fire_cooldown = _w_fs()
	else:
		_fire_mode = "AUTO"
		_fire_cooldown = _w_fa()
	emit_signal("fire_mode_changed", _fire_mode)

# ===================================================================
# 公开查询方法
# ===================================================================

func get_fire_mode() -> String:
	return _fire_mode

func get_reserve_ammo() -> int:
	return _reserve_ammo

func add_reserve_ammo(amount: int):
	_reserve_ammo += amount
	emit_signal("ammo_changed", _ammo, _w_mag(), _reserve_ammo)

func set_reserve_ammo(amount: int):
	_reserve_ammo = amount
	emit_signal("ammo_changed", _ammo, _w_mag(), _reserve_ammo)

func get_ammo_status() -> String:
	return str(_ammo) + " / " + str(_reserve_ammo)

# ===================================================================
# 射击核心
# ===================================================================

func _do_shoot(crouching: bool, ads: bool, moving: bool):
	_ammo -= 1
	_fire_cooldown = _w_fs() if _fire_mode == "SEMI" else _w_fa()
	
	_apply_recoil(crouching, ads)
	_show_muzzle_flash()
	_play_gun_sound()
	_bloom = minf(_bloom + _w_bps(), 10.0)
	
	var forward = -_ray.global_transform.basis.z
	var dir: Vector3
	if _spread != null and _spread.has_method("get_spread_direction"):
		dir = _spread.get_spread_direction(forward, crouching, ads, moving, _bloom)
	else:
		dir = forward
	
	_ray.rotation = Vector3.ZERO
	_ray.look_at(_ray.global_position + dir)
	_ray.force_raycast_update()
	
	if _ray.is_colliding():
		var collider = _ray.get_collider()
		if collider != null and is_instance_valid(collider):
			var hit_point = _ray.get_collision_point()
			_spawn_impact_effect(hit_point, _ray.get_collision_normal())
			
			var target = collider
			while target != null and not target.has_method("take_damage"):
				target = target.get_parent()
			
			if target != null and is_instance_valid(target):
				var final_damage = _w_dmg()
				if target is CharacterBody3D:
					var cap_bottom = target.global_position.y
					var head_bottom = cap_bottom + _w_hbo()
					var head_top = cap_bottom + _w_hto()
					if hit_point.y > head_bottom and hit_point.y < head_top:
						var mult = 2.0 if crouching else 1.75
						final_damage = _w_dmg() * mult
						emit_signal("shot_fired", mult)
				target.call("take_damage", final_damage)
	
	_ray.rotation = Vector3.ZERO
	emit_signal("ammo_changed", _ammo, _w_mag(), _reserve_ammo)
	
	if _ammo <= 0 and _reserve_ammo > 0:
		start_reload()

func _apply_recoil(crouching: bool, ads: bool):
	var mult = 0.5 if crouching else 1.0
	if ads: mult *= 0.7
	var kick = _w_rk() * mult
	if _camera_pivot != null:
		_camera_pivot.rotate_x(kick)
	if _weapon_model == null:
		var pivot = get_node_or_null("../CameraPivot/WeaponPivot")
		if pivot and pivot.get_child_count() > 0:
			_weapon_model = pivot.get_child(0) as Node3D
	if _weapon_model != null:
		var recoil_offset = Vector3(randf() * 0.01 - 0.005, kick * 0.3, kick * 0.5)
		var tween = create_tween()
		tween.tween_property(_weapon_model, "position", _weapon_model.position + recoil_offset, 0.02)
		tween.tween_property(_weapon_model, "position", _weapon_model.position, 0.06)

func _show_muzzle_flash():
	if _gun_muzzle == null: return
	var flash = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.15)
	flash.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 4.0
	flash.material_override = mat
	flash.position = _gun_muzzle.position
	if _camera_pivot != null: _camera_pivot.add_child(flash)
	else: add_child(flash)
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(flash): flash.queue_free()

func _spawn_impact_effect(pos: Vector3, normal: Vector3):
	var spark = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.02; sphere.height = 0.04
	spark.mesh = sphere
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.6, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.2)
	m.emission_energy_multiplier = 1.5
	spark.material_override = m
	spark.position = pos + normal * 0.02
	get_tree().get_root().add_child(spark)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(spark): spark.queue_free()

func _setup_gun_sound():
	_gun_audio = AudioStreamPlayer.new()
	_gun_audio.name = "GunAudio"
	var sound = load(_w_gsp())
	if sound != null:
		_gun_audio.stream = sound
		_gun_audio.volume_db = 0.0
		_gun_audio.bus = "Master"
		if _camera_pivot != null: _camera_pivot.add_child(_gun_audio)
		else: add_child(_gun_audio)
	else:
		push_error("无法加载枪声音频: ", _w_gsp())

func _play_gun_sound():
	if _gun_audio != null and _gun_audio.stream != null:
		_gun_audio.play()

func _play_reload_sound():
	var wname = weapon_data.weapon_name.to_lower() if weapon_data else "akm"
	var path = "res://resources/mp3/" + wname + "_reload.mp3"
	if not ResourceLoader.exists(path):
		return
	var sound = load(path)
	if sound != null:
		var sp = AudioStreamPlayer.new()
		sp.stream = sound
		sp.bus = "Master"
		add_child(sp)
		sp.play()
		sp.finished.connect(sp.queue_free)
