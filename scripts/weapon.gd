extends Node3D

# ===== 武器参数 =====
@export var weapon_name: String = "Pistol"
@export var damage: float = 25.0
@export var fire_rate: float = 0.08  # 全自动
@export var mag_capacity: int = 30
@export var reserve_ammo: int = 90

# ===== 节点引用 =====
@onready var weapon_mesh: MeshInstance3D = $WeaponMesh
@onready var muzzle_point: Node3D = $WeaponMesh/MuzzlePoint

# ===== 状态 =====
var current_ammo: int
var is_reloading: bool = false
var is_ads: bool = false

# ===== 位置状态 =====
var hip_position: Vector3 = Vector3(0.4, -0.3, -0.5)  # 腰射位置
var ads_position: Vector3 = Vector3(0.15, -0.25, -0.3)  # 瞄准位置
var hip_rotation: Vector3 = Vector3(0, 0, 0)
var ads_rotation: Vector3 = Vector3(0, 0, 0)

func _ready() -> void:
	current_ammo = mag_capacity
	print("武器系统初始化: " + weapon_name)
	
	# 初始显示武器
	if weapon_mesh:
		weapon_mesh.position = hip_position
		weapon_mesh.rotation = hip_rotation

func _input(event: InputEvent) -> void:
	# 瞄准切换
	if event.is_action_pressed("aim"):
		toggle_ads(true)
	if event.is_action_released("aim"):
		toggle_ads(false)

func toggle_ads(ads_on: bool) -> void:
	is_ads = ads_on
	if not weapon_mesh:
		return
	
	# 平滑移动到目标位置
	var target_pos = ads_position if ads_on else hip_position
	var target_rot = ads_rotation if ads_on else hip_rotation
	
	# 使用 Tween 动画
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(weapon_mesh, "position", target_pos, 0.15)
	tween.tween_property(weapon_mesh, "rotation", target_rot, 0.15)
	
	# 瞄准时调整 FOV（如果相机可访问）
	var player = get_parent()
	if player and player.has_node("Head/Camera3D"):
		var camera = player.get_node("Head/Camera3D")
		var target_fov = 60.0 if ads_on else 75.0
		var fov_tween = create_tween()
		fov_tween.tween_property(camera, "fov", target_fov, 0.15)

func reload() -> bool:
	if is_reloading or current_ammo == mag_capacity or reserve_ammo <= 0:
		return false
	
	is_reloading = true
	print(weapon_name + " 换弹中...")
	
	# 换弹动画 - 武器移出视野
	if weapon_mesh:
		var tween = create_tween()
		tween.tween_property(weapon_mesh, "position:y", -1.0, 0.3)
	
	await get_tree().create_timer(1.5).timeout
	
	var needed = mag_capacity - current_ammo
	var loaded = mini(needed, reserve_ammo)
	current_ammo += loaded
	reserve_ammo -= loaded
	
	# 换弹完成 - 武器回来
	if weapon_mesh:
		var tween = create_tween()
		tween.tween_property(weapon_mesh, "position", hip_position, 0.2)
	
	is_reloading = false
	print(weapon_name + " 换弹完成! 弹药: " + str(current_ammo) + "/" + str(reserve_ammo))
	return true

func get_muzzle_position() -> Vector3:
	if muzzle_point:
		return muzzle_point.get_global_position()
	elif weapon_mesh:
		return weapon_mesh.get_global_position() + Vector3(0, 0, -0.5)
	return Vector3.ZERO

func get_muzzle_direction() -> Vector3:
	var player = get_parent()
	if player and player.has_node("Head/Camera3D"):
		return -player.get_node("Head/Camera3D").global_transform.basis.z
	return Vector3.BACK
