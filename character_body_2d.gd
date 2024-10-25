extends CharacterBody2D

# Enums
enum FacingDirection { LEFT = -1, RIGHT = 1 }



# Gravity Constants
@export var MIN_GRAVITY_COEFFICIENT = 0.65
@export var GRAVITY_ADJUSTMENT_TRESHOLD = 50

# Animation Constants
@export var AIR_TIME_BEFORE_JUMP_ANIM = 0.2

# Node References
@onready var _animated_sprite = $AnimatedSprite2D

# State Variables
var facing_direction = FacingDirection.RIGHT
var floor_normal = Vector2.UP
var horizontal_velocity = 0.0 ## The character's velocity perpendicular to the floor normal


## Good practice to init each component's variables in a specific function 
## instead of here, so that it's easier to digest and know what belongs where.
func _ready():
	_ready_state_handlers()
	_animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	var on_floor = is_on_floor()
	var state_info = get_state_information()
	
	adjust_velocity(on_floor)
	handle_state(state_info)
	handle_jumping(state_info.jump_pressed, on_floor, delta)


	## Decrement the ignore ledge grab timer
	if state_info.is_pressing_down:
		restart_ignore_ledge_grab_timer()
	else:
		decrement_ignore_ledge_grab_timer(delta)
		
	move_and_slide()


## Adjusts the velocity of the character based on their angle with the floor.
##
## NOTE - Very hacky and requires careful reading to understand
func adjust_velocity(on_floor: bool):

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


# Jumping _______________________________________________________________

# Jump Queue 

var jump_queue_timer = 0.0
var JUMP_QUEUE_TIME = 0.1 # Time in seconds for jump queue window

## Checks if the player has queued a jump
func jump_is_queued() -> bool:
	return jump_queue_timer > 0

## Queues a jump by setting the jump queue timer to the jump queue time
func queue_jump():
	jump_queue_timer = JUMP_QUEUE_TIME

## Resets the jump queue timer to 0
func reset_jump_queue():
	jump_queue_timer = 0

## Decrements the jump queue timer - called every physics frame
func decrement_jump_queue_timer(delta: float):
	if jump_is_queued():
		jump_queue_timer = max(jump_queue_timer - delta, 0)


# Coyote Jump

var coyote_timer = 0.0
var COYOTE_TIME = 0.15 # Time in seconds for coyote jump window

## Checks if the player has a coyote jump available
func has_coyote_jump() -> bool:
	return coyote_timer > 0

## Re-enables the coyote jump timer - called when the player is on the floor
func restart_coyote_time():
	coyote_timer = COYOTE_TIME

## Sets the coyote jump timer to 0 - called when the player jumps
func reset_coyote_time():
	coyote_timer = 0

## Decrements the coyote jump timer - called every physics frame
func decrement_coyote_time(delta: float):
	if coyote_timer > 0:
		coyote_timer = max(coyote_timer - delta, 0)


# Jump Animations

# Only relevant for the jump animation phases
var JUMP_MID_VELOCITY_TRESHOLD = 35
var air_time = 0.0

## Resets the jump animation air time to 0
func reset_jump_animation_air_time():
	air_time = 0

## Increments the jump animation air time - called every physics frame
func increment_jump_animation_air_time(delta: float):
		air_time += delta

## Handles the jump animations based on the player's velocity and air time.
func handle_jump_animations():
	if is_jumping or air_time >= AIR_TIME_BEFORE_JUMP_ANIM:
		if velocity.y < -JUMP_MID_VELOCITY_TRESHOLD: _animated_sprite.play("jump_rise")
		elif velocity.y > JUMP_MID_VELOCITY_TRESHOLD: _animated_sprite.play("jump_fall")
		else: _animated_sprite.play("jump_mid")


# Jump

var JUMP_HORIZONTAL_VELOCITY_COEFFICIENT = 2
var JUMP_HORIZONTAL_VELOCITY_TRESHOLD = 100
var JUMP_VELOCITY = -400.0
var JUMP_BOOST_MAX_TIME = 0.1
var JUMP_BOOST_MIN_TIME = 0.1
var MIN_JUMP_VELOCITY = -400.0
var JUMP_CANCEL_VELOCITY = -200

var is_jumping = false

## Resets the jump state to false
func reset_jump_state():
	is_jumping = false

## Starts the jump, setting the correct velocity, jumping state, and resetting the jump queue and coyote time
func start_jump():
	velocity.y = JUMP_VELOCITY
	is_jumping = true

	reset_jump_queue()
	reset_coyote_time()

## Cancels the jump by setting the vertical velocity to the jump cancel velocity
## and setting is_jumping to false.
func cancel_jump():
	velocity.y = max(velocity.y, JUMP_CANCEL_VELOCITY)
	is_jumping = false

## Handles jumping logic and time processing for jump-related variables.
## Called in _physics_process() every frame.
func handle_jumping(jump_pressed: bool, on_floor: bool, delta: float) -> void:
		
	# Queue jump whenever jump key is pressed
	if jump_pressed: queue_jump()

	# Reset jumping states when on floor
	if on_floor or is_ledge_grabbing():
		reset_jump_animation_air_time()
		restart_coyote_time()
		reset_jump_state()
	else:
		# Increment air time when the player is in the air
		velocity += get_gravity() * delta # Increment the velocity by gravity

	# Check if we should start a jump
	var can_jump = \
		on_floor or \
		has_coyote_jump() or \
		is_ledge_grabbing()
	
	# Jumping & Jump Cancelling
	if can_jump:
		restart_coyote_time() # If the player can jump but doesn't, we still want to enable the coyote jump
		if jump_is_queued(): start_jump()
	elif is_jumping and not jump_pressed:
		cancel_jump()

	# Decrement the jump queue timer
	decrement_jump_queue_timer(delta)
	decrement_coyote_time(delta)
	increment_jump_animation_air_time(delta)

	# Play the jump animation if the player is jumping
	handle_jump_animations()


## TODO - Completely rework this
## Get jump horizontal velocity coefficient
func get_jump_horizontal_velocity_coefficient() -> float:
	if not is_jumping:
		return 1.0
		
	var velocity_diff = abs(velocity.y - JUMP_VELOCITY)

	if velocity_diff >= JUMP_HORIZONTAL_VELOCITY_TRESHOLD:
		return 1.0
	else:
		return 1 + (JUMP_HORIZONTAL_VELOCITY_COEFFICIENT - JUMP_HORIZONTAL_VELOCITY_COEFFICIENT * velocity_diff / JUMP_HORIZONTAL_VELOCITY_TRESHOLD)


# State ___________________________________________________________________

## Holds information about the current state of the character.
class StateInformation:
	## The direction of movement (-1 for left, 1 for right, 0 for no movement)
	var direction: float
	## The time elapsed since the last frame
	var delta: float
	## Whether the character is on the floor
	var is_on_floor: bool
	## Whether the character is sprinting
	var is_sprinting: bool
	## Whether the jump button is currently pressed
	var jump_pressed: bool
	## Whether the jump button was just pressed this frame
	var jump_just_pressed: bool
	## Whether the player is pressing down
	var is_pressing_down: bool

	## Initializes a new StateInformation instance.
	func _init(dir: float, d: float, on_floor: bool, sprint: bool, jump_p: bool, jump_jp: bool, pressing_down: bool):
		direction = dir
		delta = d
		is_on_floor = on_floor
		is_sprinting = sprint
		jump_pressed = jump_p
		jump_just_pressed = jump_jp
		is_pressing_down = pressing_down
## Generates a StateInformation object based on the current input.
func get_state_information() -> StateInformation:
	var direction = Input.get_axis("ui_left", "ui_right")
	var is_sprinting = Input.is_action_pressed("ui_sprint")
	var jump_pressed = Input.is_action_pressed("ui_accept")
	var jump_just_pressed = Input.is_action_pressed("ui_accept")
	var is_pressing_down = Input.is_action_pressed("ui_down")
	
	return StateInformation.new(direction, get_physics_process_delta_time(), is_on_floor(), is_sprinting, jump_pressed, jump_just_pressed, is_pressing_down)

## Enum representing the different states the character can be in.
enum State { IDLE, RUNNING, SPRINTING, LEDGE_GRABBING }
var current_state := State.IDLE

## Handles the logic for entering, stepping through, and exiting a state.
class StateHandler:
	## Function called when entering the state.
	var enter_state_function: Callable = func(): pass
	## Function called each frame while in the state.
	var step_state_function: Callable = func(): pass
	## Function called when exiting the state.
	var exit_state_function: Callable = func(): pass

## Handles the state logic for the current state.
func handle_state(info: StateInformation):
	state_handlers[current_state].step_state_function.call(info)
	_animated_sprite.flip_h = (facing_direction == FacingDirection.LEFT)

## Mapping of states to their state handlers. Assigned in _ready_state_handlers().
var state_handlers: Dictionary = {}

## Assigns the state handlers to the state handlers dictionary.
## Gets called in _ready().
func _ready_state_handlers():
	var ledge_grab_state_handler = StateHandler.new()
	ledge_grab_state_handler.enter_state_function = enter_ledge_grabbing_state
	ledge_grab_state_handler.step_state_function = step_ledge_grabbing_state
	state_handlers[State.LEDGE_GRABBING] = ledge_grab_state_handler

	var idle_state_handler = StateHandler.new()
	idle_state_handler.step_state_function = step_idle_state
	state_handlers[State.IDLE] = idle_state_handler

	var running_state_handler = StateHandler.new()
	running_state_handler.step_state_function = step_running_state
	state_handlers[State.RUNNING] = running_state_handler

	var sprinting_state_handler = StateHandler.new()
	sprinting_state_handler.step_state_function = step_sprinting_state
	state_handlers[State.SPRINTING] = sprinting_state_handler

## Transitions the character to a new state, calling the exit and enter state
## functions of the old and new state's state handlers respectively.
## 
## Arguments:
## - new_state: The new state to transition to.
func transition_to(new_state: State):
	current_state = new_state
	state_handlers[new_state].enter_state_function.call()


# IDLE ------------------------------------

## Handles the idle state
func step_idle_state(info: StateInformation):
	if info.direction != 0:
		return transition_to(State.RUNNING)
	
	handle_ledge_grab_check(info)

	horizontal_velocity = move_toward(horizontal_velocity, 0, max(SPEED, abs(horizontal_velocity)) * info.delta * 12)
	
	if info.is_on_floor: _animated_sprite.play("idle")


# RUNNING ---------------------------------
# NOTE - Maybe running and sprinting should be a single state?

var SPEED = 150.0

## Handles the running state
func step_running_state(info: StateInformation):
	if info.direction < 0: facing_direction = FacingDirection.LEFT
	elif info.direction > 0: facing_direction = FacingDirection.RIGHT
		
	if info.direction == 0:
		return transition_to(State.IDLE)
	elif info.is_sprinting and info.is_on_floor:
		return transition_to(State.SPRINTING)
	
	handle_ledge_grab_check(info)
	
	var target_velocity = info.direction * SPEED * get_jump_horizontal_velocity_coefficient()
	if horizontal_velocity != 0 and sign(horizontal_velocity) != sign(target_velocity):
		horizontal_velocity = 0
	horizontal_velocity = move_toward(horizontal_velocity, target_velocity, SPEED * info.delta * 6)
	
	if info.is_on_floor:
		_animated_sprite.play("run")


# SPRINTING --------------------------------

var SPRINT_SPEED = 300.0

## Handles the sprinting state
func step_sprinting_state(info: StateInformation):
	if info.direction < 0: facing_direction = FacingDirection.LEFT
	elif info.direction > 0: facing_direction = FacingDirection.RIGHT

	if info.direction == 0:
		return transition_to(State.IDLE)
	elif not info.is_sprinting:
		return transition_to(State.RUNNING)
	
	handle_ledge_grab_check(info)

	var target_velocity = info.direction * SPRINT_SPEED * get_jump_horizontal_velocity_coefficient()
	if horizontal_velocity != 0 and sign(horizontal_velocity) != sign(target_velocity):
		horizontal_velocity = 0
	horizontal_velocity = move_toward(horizontal_velocity, target_velocity, SPRINT_SPEED * info.delta * 6)
	
	if info.is_on_floor:
		_animated_sprite.play("sprint")


# LEDGE GRABBING --------------------------

@onready var ledge_grab_shapecast = $LedgeGrabShapeCast2D
@onready var anti_ledge_grab_shapecast = $AntiLedgeGrabShapeCast2D

# Ledge Grabbing Constants
var LEDGE_GRAB_DISTANCE_HORIZONTAL = 20.0
var LEDGE_GRAB_DISTANCE_VERTICAL = 20.0

# Ignore Ledge Grab Variables
var ignore_ledge_grab_timer = 0.0
var IGNORE_LEDGE_GRAB_TIME = 0.2

## Resets the ignore ledge grab timer to 0
func reset_ignore_ledge_grab_timer():
	ignore_ledge_grab_timer = 0

## Restarts the ignore ledge grab timer
func restart_ignore_ledge_grab_timer():
	ignore_ledge_grab_timer = IGNORE_LEDGE_GRAB_TIME

## Decrements the ignore ledge grab timer - called every physics frame
func decrement_ignore_ledge_grab_timer(delta: float):
	if ignore_ledge_grab_timer > 0:
		ignore_ledge_grab_timer = max(ignore_ledge_grab_timer - delta, 0)

## Checks if the ignore ledge grab timer is active
func is_ignoring_ledge_grab() -> bool:
	return ignore_ledge_grab_timer > 0

## Checks if the character is currently in the ledge grabbing state
func is_ledge_grabbing() -> bool:
	return current_state == State.LEDGE_GRABBING

## Checks whether the character is currently grabbing a ledge
func handle_ledge_grab_check(info: StateInformation):

	# We don't want to enter the ledge grabbing state if we're not
	# pressing any direction
	if info.direction == 0:
		return

	if is_ignoring_ledge_grab():
		return

	# We can't grab a ledge if we're on the floor
	if info.is_on_floor:
		return

	# We don't want to ledge grab unless we're falling down
	if velocity.y <= 0:
		return
	
	# The downwards shapecast must hit a ledge for us to grab onto
	if not ledge_grab_shapecast.is_colliding():
		return

	# Check if the anti-ledge grab shapecast is colliding
	if anti_ledge_grab_shapecast.is_colliding():
		return

	# Calculate the collision point and the distances to it
	var collision_point = ledge_grab_shapecast.get_collision_point(0)
	var ledge_height_distance = collision_point.y - global_position.y
	var ledge_horizontal_distance = abs(collision_point.x - global_position.x)

	# Check if the collision is on the left or the right side of the player. 
	# It needs to be on the same side as the player's facing direction
	var is_ledge_on_same_side = (
		(collision_point.x < global_position.x and facing_direction == FacingDirection.LEFT) or 
		(collision_point.x > global_position.x and facing_direction == FacingDirection.RIGHT)
	)
	if not is_ledge_on_same_side:
		return

	# If the ledge is too far away, we can't grab it
	if ledge_height_distance > LEDGE_GRAB_DISTANCE_VERTICAL or ledge_horizontal_distance > LEDGE_GRAB_DISTANCE_HORIZONTAL:
		return
	
	# We must set is_jumping to false so the player doesn't exit the ledge grabbing state
	is_jumping = false
	velocity.y = 0
	transition_to(State.LEDGE_GRABBING)


# State Handlers

func enter_ledge_grabbing_state():
	_animated_sprite.play("ledge_grabbing")

func step_ledge_grabbing_state(info: StateInformation):	
	if ignore_ledge_grab_timer > 0:
		transition_to(State.IDLE)
		return


	# The player just wants to get down
	if is_ignoring_ledge_grab():
		return transition_to(State.IDLE)

	if is_jumping:
		return transition_to(State.IDLE)
	elif info.direction != 0 and sign(info.direction) != sign(facing_direction):
		return transition_to(State.IDLE)
	
	horizontal_velocity = 0


# Simple hack for changing animations
func _on_animation_finished():
	print("Animation finished: ", _animated_sprite.animation)
	if _animated_sprite.animation == "ledge_grabbing":
		_animated_sprite.play("ledge_hanging")
