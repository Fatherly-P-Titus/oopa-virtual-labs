extends Node3D
class_name PendulumApparatus3D
## Presentation-only pendulum assembly. All state is supplied by PendulumSpringsModel.

@onready var pendulum_pivot: Node3D = $PendulumPivot
@onready var rod: MeshInstance3D = $PendulumPivot/Rod
@onready var bob: MeshInstance3D = $PendulumPivot/Bob
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.look_at(Vector3(0.0, 1.25, 0.0))


func set_model_state(length_m: float, theta_rad: float) -> void:
	var displayed_length: float = clampf(length_m, 0.5, 3.0)
	pendulum_pivot.rotation.z = theta_rad
	rod.position.y = -displayed_length * 0.5
	bob.position.y = -displayed_length
	var rod_mesh := rod.mesh as CylinderMesh
	if rod_mesh != null:
		rod_mesh.height = displayed_length

