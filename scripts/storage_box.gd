extends RigidBody3D

# ===== 储物箱交互系统 =====
# 储物箱只掉落工艺藏品（绿50%/蓝30%/紫20%）
# 不掉落弹药

# 已拾取标记
var is_interacted: bool = false

# 存储掉落的工艺藏品
var loot_item: Dictionary = {}

func _ready() -> void:
	# collision_layer=4 匹配 RayCast3D 的 collision_mask
	collision_layer = 0b0100
	collision_mask = 0b0100
	freeze = true
	print("[StorageBox] 储物箱初始化完成")

	# 生成掉落物品
	_generate_loot()

func _generate_loot() -> void:
	# 初始化随机种子（确保每次运行结果不同）
	seed(Time.get_ticks_msec() + int(position.x * 1000) + int(position.z * 1000))

	# 实例化 CraftItems 节点来调用非静态方法
	var craft_items_scene = load("res://scripts/craft_items.gd")
	if craft_items_scene:
		var craft_system = craft_items_scene.new()
		loot_item = craft_system.generate_loot_item()
		craft_system.queue_free()  # 用完释放
		if loot_item.size() > 0:
			print("[StorageBox] 生成工艺藏品: ", loot_item.get("name", ""))
		else:
			print("[StorageBox] 未生成工艺藏品")
	else:
		print("[StorageBox] 无法加载CraftItems脚本")

# 标记为储物箱
func is_storage_box() -> bool:
	return true

func interact(player: CharacterBody3D) -> void:
	print("===== StorageBox interact() 被调用 =====")
	if is_interacted:
		return

	is_interacted = true

	# 掉落工艺藏品
	if loot_item.size() > 0:
		_show_loot_notification(loot_item)
		# 将工艺藏品传递给玩家
		if player.has_method("receive_craft_item"):
			player.receive_craft_item(loot_item)
	else:
		print("储物箱为空")

	# 拾取动画
	interact_pickup_animation()

func _show_loot_notification(item_data: Dictionary) -> void:
	# 向HUD发送通知
	var hud = get_tree().get_first_node_in_group("HUD")
	if hud and hud.has_method("show_loot_notification"):
		hud.show_loot_notification(item_data)

func interact_pickup_animation() -> void:
	# 储物箱消失动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1.5, 0.5)
	tween.tween_property(self, "rotation:y", rotation.y + TAU, 0.5)

	var mesh = get_node_or_null("Model")
	if mesh:
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tween.tween_method(func(v): mat.albedo_color.a = v, 1.0, 0.0, 0.5)
		if mesh is MeshInstance3D:
			mesh.material_override = mat

	await tween.finished
	queue_free()
