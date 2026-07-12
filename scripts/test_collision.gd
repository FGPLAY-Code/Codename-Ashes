extends Node3D

func _ready():
	await get_tree().process_frame
	for child in get_children():
		_process_node(child)

func _process_node(node: Node):
	if node is MeshInstance3D:
		var mesh = node.mesh
		if mesh and mesh.get_faces().size() > 0:
			var body = StaticBody3D.new()
			body.name = node.name + "_col"
			body.transform = node.transform
			var col = CollisionShape3D.new()
			var shape = ConcavePolygonShape3D.new()
			shape.set_faces(mesh.get_faces())
			col.shape = shape
			body.add_child(col)
			node.get_parent().add_child(body)
			print("[Collision] 为 ", node.name, " 生成三网格碰撞")
		return
	for child in node.get_children():
		_process_node(child)
