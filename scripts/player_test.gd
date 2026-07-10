extends CharacterBody3D

@onready var camera_pivot: Node3D = get_node_or_null("CameraPivot")
@onready var camera: Camera3D = get_node_or_null("CameraPivot/Camera3D")

enum FireMode { AUTO, SEMI }
var current_fire_mode: FireMode = FireMode.AUTO

const HIP_POSITION := Vector3(0.3, -0.2, -0.3)

func find_muzzle_point(node: Node) -> Node3D:
	var muzzle = node.get_node_or_null("Muzzle") as Node3D
	if muzzle:
		return muzzle
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0, -1.0)
	node.add_child(muzzle)
	return muzzle

func setup_weapon() -> void:
	var muzzle = find_muzzle_point(self)

func _ready() -> void:
	setup_weapon()
