extends CharacterBody2D
class_name Player

# movement parameters (play with them in the inspector ->)
@export var SPEED: float = 150
@export var ACCEL_TIME: float = 0.2  # time to full speed in seconds
@export var JUMP_VELOCITY: float = -700 # (negative is up, positive is down)
@export var JUMP_GRAVITY_MIN: float = 1200  # Short press
@export var JUMP_GRAVITY_MAX: float = 3600  # Long press
@export var FALL_GRAVITY: float = 1500  # fall faster than you rise
@export var FACING_DIRECTION: float = 1

# summon parameters
@export var BLAST_VELOCITY: float = -1000 # strength of blast jump


const terminal_velocity := 800.0
const max_jump_held_time := 1.0
var jump_held_timer := 0.0
var jump_held := false                  # if jump button is held

var knockback := Vector2.ZERO

# for friction
var tile_map_layer: TileMapLayer = null
@onready var tile_collider := $TileCollider
var friction: float = 1

func _ready() -> void:
	respawn()
	
func respawn() -> void:
	$AnimatedSprite2D.play()
	velocity.x = SPEED


signal spawn_box
func _process(delta: float) -> void:
	### SET SPELL SLOTS
	# blast 
	if Input.is_action_just_pressed("summon_1"):
		velocity.y = BLAST_VELOCITY
		jump_held = false
	
	# box jump
	if Input.is_action_just_pressed("summon_2"):
		spawn_box.emit()
	



# Handles player input and movement
func _physics_process(delta: float) -> void:

	# VERTICAL MOVEMENT
	# --------------------------------------------
	if jump_held:
		jump_held_timer += delta
	
	# Add gravity if in the air
	if not is_on_floor():
		var grav := 0.0
		if (velocity.y <= 0):
			if jump_held:
				grav = JUMP_GRAVITY_MIN
			else:
				# variable jump height, based on holding jump
				grav = clamp(lerp(JUMP_GRAVITY_MIN, JUMP_GRAVITY_MAX,
								  1-jump_held_timer/max_jump_held_time),
							 JUMP_GRAVITY_MIN, JUMP_GRAVITY_MAX)
		else:
			grav = FALL_GRAVITY

		velocity.y += minf(grav * delta, terminal_velocity)

	# Handle jump if on the ground
	if Input.is_action_just_pressed("jump") and is_on_floor():
		$JumpSound.play()
		velocity.y = JUMP_VELOCITY
		jump_held = true
		jump_held_timer = 0.0
		
	if Input.is_action_just_released("jump") and jump_held:
		jump_held = false

	# HORIZONTAL MOVEMENT
	# -------------------------------------------------
	
	var accel: float = SPEED/ACCEL_TIME  # acceleration = velocity / time
	var true_accel: float = accel * friction  # less friction less acceleration
	var max_speed: float = SPEED / friction   # less friction more speed
	
	FACING_DIRECTION = sign(velocity.x)
	
	if (jump_held and velocity.y >= 0):
		jump_held = false
		jump_held_timer = 0.0
		
	if (knockback != Vector2.ZERO):
		velocity += knockback
		knockback = Vector2.ZERO

	# ANIMATION
	# -------------------------------------------------
	if (is_on_floor()):
		if (FACING_DIRECTION != 0):
			$AnimatedSprite2D.animation = "walk"
		else:
			$AnimatedSprite2D.animation = "idle"
	elif (velocity.y <= 0):
		$AnimatedSprite2D.animation = "jump"
	else:
		$AnimatedSprite2D.animation = "fall"
	if (FACING_DIRECTION != 0):
		$AnimatedSprite2D.flip_h = FACING_DIRECTION == -1
		
	
	move_and_slide() # moves and collides player based on velocity
	if is_on_wall_only() or (is_on_wall() and velocity.y >= 0):
		velocity.x = SPEED * -FACING_DIRECTION




signal player_dead
func hurt() -> void:
	$HitSound.play()
	player_dead.emit()

func _on_hurt_box_body_entered(body):
	hurt()
	
func _on_hurt_box_area_entered(area: Area2D) -> void:
	hurt()
	
func flip_collision():
	set_collision_mask_value(2, !get_collision_mask_value(2))	
	set_collision_mask_value(3, !get_collision_mask_value(3))	

# get friction (custom data value) of tile directly below player
# returns friction as a percentage were 1.0 is normal friction
# if there is no tile, return -1
func get_tile_friction() -> float:
	if tile_map_layer == null:
		return -1
	var tile_cell_pos: Vector2i = tile_map_layer.local_to_map(tile_collider.global_position)
	var tile_data: TileData = tile_map_layer.get_cell_tile_data(tile_cell_pos)
	if tile_data:
		var tile_friction: float = tile_data.get_custom_data("friction")
		return(tile_friction)
	return -1
	
func set_knockback(knock : Vector2) -> bool:
	if knockback == Vector2.ZERO:
		knockback = knock
		return true
	return false
