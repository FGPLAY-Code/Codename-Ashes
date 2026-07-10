"""
射击系统
- 鼠标左键射击
- 射线检测命中
- 枪口火焰特效
- 命中特效
"""

extends Node3D

# 射击设置
@export var damage: float = 25.0           # 基础伤害
@export var fire_rate: float = 0.15        # 射击间隔（秒）
@export var max_range: float = 500.0       # 最大射程

# 节点引用
@onready var raycast: RayCast3D = $RayCast3D
@onready var muzzle_flash: OmniLight3D = $MuzzleFlash
@onready var weapon_holder: Node3D = $WeaponHolder

# 状态
var can_shoot: bool = true
var is_reloading: bool = false
var current_ammo: int = 30
var max_ammo: int = 30

# 输入
var shoot_input: bool = false

func _ready() -> void:
	if muzzle_flash:
		muzzle_flash.visible = false
		muzzle_flash.light_indirect_energy = 0.0

func _physics_process(_delta: float) -> void:
	if shoot_input and can_shoot and not is_reloading:
		if current_ammo > 0:
			shoot()
		else:
			reload()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			shoot_input = event.pressed

func shoot() -> void:
	can_shoot = false
	current_ammo -= 1

	show_muzzle_flash()

	raycast.target_position = Vector3(0, 0, -max_range)
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var target = raycast.get_collider()
		var hit_pos = raycast.get_collision_point()
		var hit_norm = raycast.get_collision_normal()

		spawn_impact(hit_pos, hit_norm)

		if target.has_method("take_damage"):
			target.take_damage(damage)

	apply_recoil()

	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

func show_muzzle_flash() -> void:
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.light_indirect_energy = 3.0
		await get_tree().create_timer(0.05).timeout
		muzzle_flash.visible = false

func spawn_impact(hit_pos: Vector3, hit_norm: Vector3) -> void:
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.3
	particles.explosiveness = 0.8

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -9.8, 0)
	material.color = Color(1.0, 0.5, 0.0, 1.0)
	particles.process_material = material

	particles.transform.origin = hit_pos
	particles.look_at(hit_pos + hit_norm, Vector3.UP)

	get_tree().root.add_child(particles)

	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func apply_recoil() -> void:
	pass

func reload() -> void:
	if is_reloading or current_ammo == max_ammo:
		return

	is_reloading = true
	print("正在换弹...")

	await get_tree().create_timer(2.0).timeout

	current_ammo = max_ammo
	is_reloading = false
	print("换弹完成！当前弹药: " + str(current_ammo))

func get_ammo_status() -> String:
	return str(current_ammo) + " / " + str(max_ammo)
