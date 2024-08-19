extends Node2D

# Variables
var shoot_cooldown = 1.5  # Time between shots
var laser_length = 1000  # Length of the railgun beam
var laser_color = Color(1, 0, 1)  # Purple color for the beam
var laser_thickness = 4  # Thickness of the laser

var can_shoot = true  # Control shooting cooldown

# Line2D for the laser effect
var laser_line: Line2D

func _ready():
	laser_line = Line2D.new()
	laser_line.width = laser_thickness
	laser_line.default_color = laser_color
	laser_line.visible = false  # Hide by default
	add_child(laser_line)

func _process(delta):
	if Input.is_action_just_pressed("shoot") and can_shoot:
		shoot()

func shoot() -> void:
	can_shoot = false
	laser_line.visible = true

	# Calculate the direction of the shot (assume the player is facing right)
	var start_position = global_position
	var end_position = start_position + Vector2(laser_length, 0).rotated(rotation)

	laser_line.points = [start_position, end_position]

	# Check for hit objects (e.g., enemies)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = start_position
	query.to = end_position
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)

	if result.size() > 0:
		laser_line.points[1] = result["position"]  # Stop the laser at the collision point
		apply_damage(result["collider"])

	# Hide the laser after a short time
	await get_tree().create_timer(0.1).timeout
	laser_line.visible = false

	# Handle shooting cooldown
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

func apply_damage(target):
	if target.has_method("take_damage"):
		target.take_damage(100)  # Adjust the damage amount as needed
