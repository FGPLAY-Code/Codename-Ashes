"""
自动为场景中的所有模型添加碰撞箱
使用方法：
1. 把这个脚本挂到场景根节点
2. 运行游戏（F5）- 只在第一次运行时添加碰撞箱
3. 之后运行时脚本会自动跳过已处理的模型
"""

extends Node3D

var collision_scale: float = 1.0
var has_added_collisions: bool = false

func _ready() -> void:
	# 检查是否已经有碰撞箱了（避免重复添加）
	if has_added_collisions:
		print("碰撞箱已存在，跳过生成")
		return

	print("==================================================")
	print("开始生成碰撞箱...")
	print("==================================================")

	var count = 0
	var mesh_instances = []
	collect_mesh_instances(self, mesh_instances)

	print("找到 " + str(mesh_instances.size()) + " 个模型（不含武器）")

	for mesh in mesh_instances:
		add_collision_to_mesh(mesh)
		count += 1

	print("==================================================")
	print("完成！共处理 " + str(count) + " 个模型")
	print("下次运行时将跳过碰撞箱生成")
	print("==================================================")

	# 标记为已完成
	has_added_collisions = true

func collect_mesh_instances(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			# 跳过已经是 StaticBody 子节点的（已有碰撞箱）
			if child.get_parent() is StaticBody3D:
				continue
			# 跳过武器挂载节点（玩家手上的武器不需要碰撞）
			if child.name.begins_with("WeaponPivot") or child.name.begins_with("SimpleGun") or child.name.begins_with("Weapon"):
				continue
			result.append(child)
		if not (child is StaticBody3D):
			collect_mesh_instances(child, result)

func add_collision_to_mesh(mesh_instance: MeshInstance3D) -> void:
	var mesh = mesh_instance.get_mesh()
	if mesh == null:
		return

	var aabb = mesh.get_aabb()
	if aabb.size.length() < 0.01:
		return

	var static_body = StaticBody3D.new()
	static_body.name = str(mesh_instance.name) + "_Collision"
	# ⚠️ 修复漂移：只继承位置和缩放，不继承旋转
	# 旋转的碎片会导致碰撞体产生倾斜法线，把玩家推向一侧
	var mesh_transform = mesh_instance.transform
	var rotationless_transform = Transform3D(Basis().scaled(mesh_transform.basis.get_scale()), mesh_transform.origin)
	static_body.transform = rotationless_transform
	static_body.collision_layer = 1
	static_body.collision_mask = 0

	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"

	var shape = create_collision_shape_for_mesh(mesh, aabb)
	if shape == null:
		return

	collision_shape.shape = shape
	static_body.add_child(collision_shape)

	var parent = mesh_instance.get_parent()
	if parent:
		parent.add_child(static_body)
		parent.remove_child(mesh_instance)
		static_body.add_child(mesh_instance)
		mesh_instance.transform = Transform3D()

func create_collision_shape_for_mesh(_mesh: Mesh, aabb: AABB) -> Shape3D:
	var size = aabb.size * collision_scale
	var max_dim = max(size.x, max(size.y, size.z))
	var min_dim = min(size.x, min(size.y, size.z))

	if min_dim < max_dim * 0.1:
		var box = BoxShape3D.new()
		box.size = size
		return box

	var aspect_y = size.y / max(size.x, size.z)

	if aspect_y > 2.5:
		var radius = max(size.x, size.z) / 2.0
		var cylinder = CylinderShape3D.new()
		cylinder.height = size.y
		cylinder.radius = radius
		return cylinder
	else:
		var box = BoxShape3D.new()
		box.size = size
		return box
