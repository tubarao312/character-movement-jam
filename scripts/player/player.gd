class_name Player
extends CharacterBody2D

# Node References
@onready var _animated_sprite = $AnimatedSprite2D

var RUN_SPEED = 150.0

# State Variables
var facing_direction = Enums.FacingDirection.RIGHT
var floor_normal = Vector2.UP
var horizontal_velocity = 0.0 ## The character's velocity perpendicular to the floor normal
var on_floor = false	


# Player Input _______________________________________________________________
#
## Player Input gets processed every physics frame.
## When a function needs input, they can be passed the input object.
class PlayerInput:
	var jump_pressed: bool = false
	var jump_just_pressed: bool = false
	var ignore_ledge_grab_pressed: bool = false
	var direction: float = 0.0
	var sprint_pressed: bool = false

	# Jump queue variables
	var jump_queue_timer: float = 0.0
	const JUMP_QUEUE_TIME: float = 0.1
	
	# Ledge grab ignore variables
	var ignore_ledge_grab_timer: float = 0.0
	const IGNORE_LEDGE_GRAB_TIME: float = 0.2
	
	func _init():
		pass
	
	func update(delta: float):
		direction = Input.get_axis("ui_left", "ui_right")
		sprint_pressed = Input.is_action_pressed("ui_sprint")
		
		## Jump
		jump_pressed = Input.is_action_pressed("ui_accept")
		jump_just_pressed = Input.is_action_just_pressed("ui_accept")

		if jump_just_pressed: _queue_jump()

		_decrement_jump_queue_timer(delta)

		## Ignore ledge grab
		
		if Input.is_action_just_pressed("ui_down"):
			_start_ignore_ledge_grab_timer()
		
		_decrement_ignore_ledge_grab_timer(delta)
		
	
	# Jump queue functions

	func _queue_jump():
		jump_queue_timer = JUMP_QUEUE_TIME

	func reset_jump_queue():
		jump_queue_timer = 0

	func is_jump_queued() -> bool:
		return jump_queue_timer > 0
	
	func _decrement_jump_queue_timer(delta: float):
		if jump_queue_timer > 0:
			jump_queue_timer = max(jump_queue_timer - delta, 0)


	# Ignore ledge grab functions
	
	func _start_ignore_ledge_grab_timer():
		ignore_ledge_grab_timer = IGNORE_LEDGE_GRAB_TIME
	
	func reset_ignore_ledge_grab_timer():
		ignore_ledge_grab_timer = 0
	
	func is_ignoring_ledge_grab() -> bool:
		return ignore_ledge_grab_timer > 0

	func _decrement_ignore_ledge_grab_timer(delta: float):
		if ignore_ledge_grab_timer > 0:
			ignore_ledge_grab_timer = max(ignore_ledge_grab_timer - delta, 0)

var input := PlayerInput.new()



# Coyote Jump _______________________________________________________________
#
# Coyote Jump is not really an input related mechanic, therefore it won't
# live inside the PlayerInput class.

class CoyoteJumpManager:
	var coyote_timer = 0.0
	const COYOTE_TIME = 0.15 # Time in seconds for coyote jump window

	## Checks if the player has a coyote jump available
	func has_coyote_jump() -> bool:
		return coyote_timer > 0

	## Re-enables the coyote jump timer - called when the player is on the floor
	func restart_coyote_time():
		coyote_timer = COYOTE_TIME

	## Sets the coyote jump timer to 0 - called when the player jumps
	func reset_coyote_time():
		coyote_timer = 0

	## Decrements the coyote jump timer - called by the Airborne State Handler
	func decrement_coyote_time(delta: float):
		if coyote_timer > 0:
			coyote_timer = max(coyote_timer - delta, 0)

var coyote_manager := CoyoteJumpManager.new()


## Good practice to init each component's variables in a specific function 
## instead of here, so that it's easier to digest and know what belongs where.
func _ready():
	_ready_state_handlers()
	_animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	input.update(delta)
	on_floor = is_on_floor()

	# Flip the sprite based on the facing direction
	# TODO - Move this
	if input.direction < 0: facing_direction = Enums.FacingDirection.LEFT
	elif input.direction > 0: facing_direction = Enums.FacingDirection.RIGHT

	_animated_sprite.flip_h = (facing_direction == Enums.FacingDirection.LEFT)

	process_state(delta)		
	adjust_velocity()
	move_and_slide()

	# TODO - Move this
	decrement_post_ledge_grab_timer(delta)
		


## Adjusts the velocity of the character based on their angle with the floor.
##
## NOTE - Very hacky and requires careful reading to understand
func adjust_velocity():

	## If the character is on the floor, we check the 
	## floor normal and update it accordingly.
	if on_floor:
		var latest_slide_collision = get_last_slide_collision()
		if latest_slide_collision:
			floor_normal = latest_slide_collision.get_normal()
		else:
			floor_normal = Vector2.UP
	else:
		floor_normal = Vector2.UP

	## We then calculate the perpendicular vector to the floor normal
	# var perpendicular_vector = floor_normal.rotated(PI/2)

	## The horizontal velocity always depends on the floor normal
	velocity.x = horizontal_velocity # * perpendicular_vector.x
	
	## If the character is on the floor and going DOWN a slope, we ALWAYS
	## want to add a vertical velocity downwards to make sure they STICK
	## to the slope instead of just running off it awkwardly.
	if on_floor:
		var vertical_velocity_component = horizontal_velocity * floor_normal.rotated(PI/2).y
		if vertical_velocity_component > 0:
			velocity.y += vertical_velocity_component * 2


# State Machine _______________________________________________________________
#
## Enum representing the different states the character can be in.
var current_state := Enums.PlayerStates.IDLE

## Handles the state logic for the current state.
func process_state(delta: float) -> void:
	var handler: PlayerState = state_handlers[current_state]
	handler.step(delta)

## Mapping of states to their state handlers. Assigned in _ready_state_handlers().
var state_handlers: Dictionary = {}

## Assigns the state handlers to the state handlers dictionary.
## Gets called in _ready().
func _ready_state_handlers():
	state_handlers[Enums.PlayerStates.IDLE] = IdleState.new(self)
	state_handlers[Enums.PlayerStates.RUNNING] = RunningState.new(self)
	state_handlers[Enums.PlayerStates.LEDGE_GRABBING] = LedgeGrabbingState.new(self)
	state_handlers[Enums.PlayerStates.AIRBORNE] = AirborneState.new(self)
	# state_handlers[Enums.PlayerStates.SPRINTING] = SprintingState.new(self)


# Ledge Grabbing _______________________________________________________________
#
# Post Ledge Grab Jump
# This is a mechanic shared across multiple states, therefore it won't
# live inside the ledge grab state.

var post_ledge_grab_timer = 0.0
const POST_LEDGE_GRAB_TIME = 0.15

## Resets the post ledge grab timer to 0
func reset_post_ledge_grab_timer():
	post_ledge_grab_timer = 0

## Restarts the post ledge grab timer
func restart_post_ledge_grab_timer():
	post_ledge_grab_timer = POST_LEDGE_GRAB_TIME

## Decrements the post ledge grab timer - called every physics frame
func decrement_post_ledge_grab_timer(delta: float):
	if post_ledge_grab_timer > 0:
		post_ledge_grab_timer = max(post_ledge_grab_timer - delta, 0)

## Checks if the post ledge grab timer is active
func is_post_ledge_grab_jump_active() -> bool:
	return current_state == Enums.PlayerStates.LEDGE_GRABBING or post_ledge_grab_timer > 0


# Ledge Grab Checking
# This is also needed across multiple states, so it needs to live here.

@onready var ledge_grab_shapecast = $LedgeGrabShapeCast2D
@onready var anti_ledge_grab_shapecast = $AntiLedgeGrabShapeCast2D

# Ledge Grabbing Constants
var LEDGE_GRAB_DISTANCE_HORIZONTAL = 20.0
var LEDGE_GRAB_DISTANCE_VERTICAL = 20.0

## Checks whether the character is currently grabbing a ledge
## TODO - Improve this
func should_ledge_grab() -> bool:

	# We don't want to enter the ledge grabbing state if we're not
	# pressing any direction
	if input.direction == 0: return false

	# We don't want to ledge grab unless we're falling down
	if velocity.y <= 0: return false

	# If we're currently ignoring ledge grabs, we don't want to grab any
	if input.is_ignoring_ledge_grab(): return false

	# The downwards shapecast must hit a ledge for us to grab onto
	if not ledge_grab_shapecast.is_colliding(): return false

	# Check if the anti-ledge grab shapecast is colliding. It must
	# not collide for us to be able to grab the ledge
	if anti_ledge_grab_shapecast.is_colliding(): return false

	# Calculate the collision point and the distances to it
	var collision_point = ledge_grab_shapecast.get_collision_point(0)
	var ledge_height_distance = collision_point.y - global_position.y
	var ledge_horizontal_distance = abs(collision_point.x - global_position.x)

	# Check if the collision is on the left or the right side of the player. 
	# It needs to be on the same side as the player's facing direction
	var is_ledge_on_same_side = (
		(collision_point.x < global_position.x and facing_direction == Enums.FacingDirection.LEFT) or 
		(collision_point.x > global_position.x and facing_direction == Enums.FacingDirection.RIGHT)
	)
	if not is_ledge_on_same_side:
		return false

	# If the ledge is too far away, we can't grab it
	if ledge_height_distance > LEDGE_GRAB_DISTANCE_VERTICAL or ledge_horizontal_distance > LEDGE_GRAB_DISTANCE_HORIZONTAL:
		return false
	
	# We must set is_jumping to false so the player doesn't exit the ledge grabbing state
	return true

# Simple hack for changing animations
# TODO - Improve this
func _on_animation_finished():
	if _animated_sprite.animation == "ledge_grabbing":
		_animated_sprite.play("ledge_hanging")
