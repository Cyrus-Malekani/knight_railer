extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0

# Rail contents
var can_shoot = true
var shoot_cooldown = 1 # Time between shots
var laser_length = 1000  # Length of the railgun beam
var laser_thickness = 3  # Thickness of the laser
var laser_color = Color(1, 0, 1)  # Purple color for the beam

# Grapple hook constants
const GRAPPLE_SPEED = 400.0  # Speed at which the grapple moves
const GRAPPLE_MAX_DISTANCE = 500.0  # Maximum grapple distance
const GRAPPLE_PULL_SPEED = 200.0  # Speed at which the player is pulled to the grapple point

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var grapple_active = false  # Is the grapple currently active?
var grapple_position: Vector2  # Position where the grapple has attached
var grapple_velocity: Vector2  # Velocity of the grapple moving towards target
var is_grapple_attached = false  # Is the grapple currently attached to a surface?

@onready var animated_sprite = $AnimatedSprite2D
@onready var weapon_position = $WeaponPosition
@onready var laser_line = $LaserLine
@onready var grapple_line = $GrappleLine  # Assume you have a Line2D for the grapple

func _ready():
	laser_line.width = 4
	laser_line.default_color = Color(1, 0, 1)
	laser_line.visible = false

	grapple_line.width = 2
	grapple_line.default_color = Color(0, 1, 0)
	grapple_line.visible = false

func _physics_process(delta):
	if grapple_active:
		if is_grapple_attached:
			grapple_pull(delta)
		else:
			handle_grapple_movement(delta)
	else:
		handle_player_movement(delta)

	# Handle shooting
	if Input.is_action_just_pressed("shoot") and can_shoot:
		shoot()

	# Handle grappling
	if Input.is_action_just_pressed("grapple"):
		launch_grapple()

	if Input.is_action_just_released("grapple") and is_grapple_attached:
		cancel_grapple()

func handle_player_movement(delta):
	# Add gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction: -1, 0, 1
	var direction = Input.get_axis("move_left", "move_right")
	
	# Flip the sprite based on direction
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
	
	# Play animations
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")
	
	# Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func launch_grapple():
	# Get the start position from the weapon position (global coordinates)
	var start_position = weapon_position.global_position

	# Calculate the direction from the weapon position to the mouse cursor
	var mouse_position = get_global_mouse_position()
	var direction_vector = (mouse_position - start_position).normalized()

	# Set the grapple velocity
	grapple_velocity = direction_vector * GRAPPLE_SPEED

	# Initialize the grapple position at the start
	grapple_position = start_position

	# Show the grapple line and set its initial points
	grapple_line.visible = true
	grapple_line.points = [
		grapple_line.to_local(start_position),  # Convert global to local for Line2D
		grapple_line.to_local(grapple_position)
	]

	grapple_active = true
	is_grapple_attached = false

func handle_grapple_movement(delta):
	# Update grapple position
	grapple_position += grapple_velocity * delta

	# Update grapple line with the new positions
	grapple_line.points[1] = grapple_line.to_local(grapple_position)

	# Check if grapple reached maximum distance
	if grapple_position.distance_to(weapon_position.global_position) > GRAPPLE_MAX_DISTANCE:
		cancel_grapple()
		return

	# Check for collision
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = weapon_position.global_position
	query.to = grapple_position
	query.exclude = [self]

	var result = space_state.intersect_ray(query)
	if result.size() > 0:
		# Attach to the surface and stop the grapple movement
		grapple_position = result["position"]
		grapple_line.points[1] = grapple_line.to_local(grapple_position)
		grapple_velocity = Vector2.ZERO  # Stop the grapple from moving
		is_grapple_attached = true
	else:
		grapple_pull(delta)

func grapple_pull(_delta):
	# Pull the player towards the grapple position
	var pull_direction = (grapple_position - global_position).normalized()
	velocity = pull_direction * GRAPPLE_PULL_SPEED

	# Move the player towards the grapple point
	move_and_slide()

	# Stop grappling if player reaches the grapple point
	if global_position.distance_to(grapple_position) < 10.0:
		if not Input.is_action_pressed("grapple"):
			cancel_grapple()

	# Update the grapple line to reflect the player's new position
	grapple_line.points[0] = grapple_line.to_local(weapon_position.global_position)
	grapple_line.points[1] = grapple_line.to_local(grapple_position)

func cancel_grapple():
	grapple_active = false
	is_grapple_attached = false
	grapple_line.visible = false
	velocity = Vector2.ZERO
	
func shoot():
	can_shoot = false
	laser_line.visible = true

	# Get the start position from the weapon position (global coordinates)
	var start_position = weapon_position.global_position

	# Calculate the direction from the weapon position to the mouse cursor
	var mouse_position = get_global_mouse_position()
	var direction_vector = (mouse_position - start_position).normalized()

	# Set the end position of the laser (global coordinates)
	var end_position = start_position + direction_vector * laser_length

	# Update the laser line points using global coordinates
	laser_line.clear_points()
	laser_line.add_point(laser_line.to_local(start_position))
	laser_line.add_point(laser_line.to_local(end_position))

	# Check for hit objects (e.g., enemies) using raycast
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = start_position
	query.to = end_position
	query.exclude = [self]

	var result = space_state.intersect_ray(query)

	if result.size() > 0:
		# Stop the laser at the collision point
		var hit_position = result["position"]
		laser_line.set_point_position(1, laser_line.to_local(hit_position))
		apply_damage(result["collider"])

	# Hide the laser after a short time
	await get_tree().create_timer(0.05).timeout
	laser_line.visible = false

	# Handle shooting cooldown
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

func apply_damage(target):
	if target.has_method("take_damage"):
		target.take_damage(100)  # Adjust the damage amount as needed
