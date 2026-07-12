extends RigidBody3D

# ===== 弹药箱交互系统 =====
# 弹药箱只掉落7.62x39mm子弹，不掉落工艺藏品
# 工艺藏品由储物箱掉落

# 弹药数量（可调节）
@export var ammo_amount: int = 30

# 已拾取标记（防止重复拾取）
var is_picked_up: bool = false

func _ready() -> void:
	# collision_layer=4 匹配 RayCast3D 的 collision_mask=10（第2层敌人 + 第4层弹药箱）
	collision_layer = 0b0100
	collision_mask = 0b0100
	freeze = true
	print("[AmmoBox] 弹药箱初始化完成 - 只掉落子弹")

# 标记为弹药箱，用于玩家检测
func is_ammo_box() -> bool:
	return true

func interact(player: CharacterBody3D) -> void:
	print("===== AmmoBox interact() 被调用 =====")
	if is_picked_up:
		return

	is_picked_up = true

	# 检查 player 是否有 add_reserve_ammo 方法
	if player.has_method("add_reserve_ammo"):
		player.add_reserve_ammo(ammo_amount)
		print("拾取了弹药箱，获得 ", ammo_amount, " 发备弹")
	else:
		# 备用方式：直接修改 reserve_ammo
		if "reserve_ammo" in player:
			player.reserve_ammo += ammo_amount
			if player.has_method("update_ammo_display"):
				player.update_ammo_display()
		print("拾取了弹药箱，获得 ", ammo_amount, " 发备弹")

	# 拾取动画：向上飘起并消失
	interact_pickup_animation()

func interact_pickup_animation() -> void:
	# 使用更安全的动画方式
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1.5, 0.5)
	# 避免 scale 动画可能导致的矩阵问题，使用 opacity 代替
	var mesh = get_node_or_null("Model")
	if mesh:
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tween.tween_method(func(v): mat.albedo_color.a = v, 1.0, 0.0, 0.5)
		if mesh is MeshInstance3D:
			mesh.material_override = mat
	await tween.finished
	queue_free()
