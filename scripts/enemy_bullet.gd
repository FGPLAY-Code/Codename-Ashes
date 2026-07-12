extends Area3D

# 内部状态变量
var _velocity: Vector3
var _elapsed: float = 0.0
var _hit_something: bool = false
var _mesh: MeshInstance3D

# 子弹参数
var speed: float = 20.0       # 飞行速度（降低，给玩家反应时间）
var damage: float = 8.0       # 伤害（降低一点）
var lifetime: float = 2.5     # 最长存活时间
var direction: Vector3        # 固定飞行方向（不追踪）
var spawn_pos: Vector3        # 出生位置
var owner_enemy: Node         # 发射这颗子弹的敌人，用于排除自伤

func _ready() -> void:
	spawn_pos = global_position
	_velocity = direction.normalized() * speed

	# 创建橙色小球外观
	_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	_mesh.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	mat.emission_energy_multiplier = 3.0
	_mesh.material_override = mat
	add_child(_mesh)

	# 设置碰撞体（Area3D 用 CollisionShape3D 子节点）
	var col_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.1
	col_shape.shape = shape
	add_child(col_shape)

	# collision_layer=0 表示自身在第0层（不影响）
	# collision_mask=2 表示检测第2层的物体（玩家在第2层）
	collision_layer = 0
	collision_mask = 2

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _hit_something:
		return

	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return

	# 直线飞行（不追踪）
	global_position += _velocity * delta

	# 超出最大距离也消失
	if global_position.distance_to(spawn_pos) > 80:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if _hit_something:
		return

	# 忽略发射子弹的敌人自己
	if owner_enemy != null and body == owner_enemy:
		return

	_hit_something = true

	# 重要：在 queue_free 之前先保存位置并生成特效
	var hit_pos = global_position

	if body.has_method("take_damage"):
		body.take_damage(damage)

	# 命中特效（在删除前生成）
	_spawn_hit_flash_at(hit_pos)
	queue_free()

func _spawn_hit_flash_at(pos: Vector3) -> void:
	var flash = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	flash.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.9, 0.5)
	mat.emission_energy_multiplier = 5.0
	flash.material_override = mat
	flash.name = "HitFlash"
	# 先加入树，再用 position 设置（避免 global_position 在未入树时失效）
	get_tree().root.add_child(flash)
	flash.position = pos
	await get_tree().create_timer(0.08).timeout
	if flash and flash.is_inside_tree():
		flash.queue_free()
