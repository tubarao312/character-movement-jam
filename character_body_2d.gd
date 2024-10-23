extends CharacterBody2D

# Enums
enum State { IDLE, RUNNING, SPRINTING }

# Classes
class StateInformation:
	var direction: float
	var delta: float
	var is_on_floor: bool
	var is_sprinting: bool
	var jump_pressed: bool
	var jump_just_pressed: bool

	func _init(dir: float, d: float, on_floor: bool, sprint: bool, jump_p: bool, jump_jp: bool):
		direction = dir
		delta = d
		is_on_floor = on_floor
		is_sprinting = sprint
		jump_pressed = jump_p
		jump_just_pressed = jump_jp

# Movement Constants
@export var SPEED = 150.0
@export var SPRINT_SPEED = 300.0

# Jump Constants
@export var JUMP_VELOCITY = -400.0
@export var JUMP_BOOST_MAX_TIME = 0.1
@export var JUMP_BOOST_MIN_TIME = 0.1
@export var MIN_JUMP_VELOCITY = -400.0
@export var JUMP_CANCEL_VELOCITY = -200

# Gravity Constants
@export var MIN_GRAVITY_COEFFICIENT = 0.65
@export var GRAVITY_ADJUSTMENT_TRESHOLD = 50

# Animation Constants
@export var AIR_TIME_BEFORE_JUMP_ANIM = 0.2

# Node References
@onready var _animated_sprite = $AnimatedSprite2D

# State Variables
var current_state = State.IDLE
var facing_direction = 1
var state_handlers = {}
var air_time = 0.0
var floor_normal = Vector2.UP
var is_jumping = false
var horizontal_velocity = 0.0 ## The character's velocity perpendicular to the floor normal

# Coyote Jump Constants
@export var COYOTE_TIME = 0.1  # Time in seconds for coyote jump window

# Coyote Jump Variables
var coyote_timer = 0.0
var has_used_coyote_jump = false

# Jump Queue Constants
@export var JUMP_QUEUE_TIME = 0.1  # Time in seconds for jump queue window

# Jump Queue Variables
var jump_queue_timer = 0.0
var has_queued_jump = false

func _ready():
	# Initialize the state handlers dictionary
	state_handlers = {
		State.IDLE: handle_idle_state,
		State.RUNNING: handle_running_state,
		State.SPRINTING: handle_sprinting_state
	}
	transition_to(State.IDLE)

func _physics_process(delta):
	var on_floor = is_on_floor()
	
	handle_gravity(delta, on_floor)
	handle_jump_animations(on_floor)
	
	var state_info = get_state_information()
	handle_state(state_info)
	
	adjust_velocity(on_floor)
	handle_jumping(state_info.jump_pressed, state_info.jump_just_pressed, on_floor, delta)
	handle_coyote_time(delta, on_floor)
	
	move_and_slide()

func handle_gravity(delta: float, on_floor: bool):
	if not on_floor:
		var gravity_coefficient = 1.0
		velocity += get_gravity() * delta * gravity_coefficient
		air_time += delta
	else:
		air_time = 0.0

func handle_jump_animations(on_floor: bool):
	if not on_floor and (air_time >= AIR_TIME_BEFORE_JUMP_ANIM or is_jumping):
		var JUMP_MID_VELOCITY_TRESHOLD = 35
		if velocity.y < -JUMP_MID_VELOCITY_TRESHOLD:
			_animated_sprite.play("jump_rise")
		elif velocity.y > JUMP_MID_VELOCITY_TRESHOLD:
			_animated_sprite.play("jump_fall")
		else:
			_animated_sprite.play("jump_mid")

func get_state_information() -> StateInformation:
	var direction = Input.get_axis("ui_left", "ui_right")
	var is_sprinting = Input.is_action_pressed("ui_sprint")
	var jump_pressed = Input.is_action_pressed("ui_accept")
	var jump_just_pressed = Input.is_action_pressed("ui_accept")
	
	return StateInformation.new(direction, get_physics_process_delta_time(), is_on_floor(), is_sprinting, jump_pressed, jump_just_pressed)

func handle_state(info: StateInformation):
	state_handlers[current_state].call(info)
	_animated_sprite.flip_h = facing_direction

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
	var perpendicular_vector = floor_normal.rotated(PI/2)

	## The horizontal velocity always depends on the floor normal
	velocity.x = horizontal_velocity * perpendicular_vector.x
	
	## If the character is on the floor and going DOWN a slope, we ALWAYS
	## want to add a vertical velocity downwards to make sure they STICK
	## to the slope instead of just running off it awkwardly.
	if on_floor:
		var vertical_velocity_component = horizontal_velocity * floor_normal.rotated(PI/2).y
		if vertical_velocity_component > 0:
			velocity.y += vertical_velocity_component * 2

# Jumping Logic _______________________________________________________________

## Handles jumping logic
func handle_jumping(jump_pressed: bool, jump_just_pressed: bool, on_floor: bool, delta: float):
	# Reset jumping states when on floor
	if on_floor:
		is_jumping = false
		has_used_coyote_jump = false
	
	# Check if we should start a jump
	var should_jump = (
		(on_floor or (coyote_timer > 0 and not has_used_coyote_jump)) and # Check if player can jump (on floor or within coyote time)
		(jump_just_pressed or has_queued_jump) # Check if jump input is received or queued
	)
	
	if should_jump:
		start_jump()
		has_queued_jump = false
		if not on_floor:
			has_used_coyote_jump = true
			coyote_timer = 0
	elif is_jumping and not jump_pressed:
		cancel_jump()
	
	# Handle jump queue
	if jump_just_pressed and not on_floor:
		jump_queue_timer = JUMP_QUEUE_TIME
		has_queued_jump = true
	elif has_queued_jump:
		jump_queue_timer -= delta
		if jump_queue_timer <= 0:
			has_queued_jump = false

## Starts the jump
func start_jump():
	velocity.y = JUMP_VELOCITY
	is_jumping = true

## Cancels the jump by setting a small upward velocity
func cancel_jump():
	if velocity.y < JUMP_CANCEL_VELOCITY:
		velocity.y = JUMP_CANCEL_VELOCITY
	is_jumping = false


var JUMP_HORIZONTAL_VELOCITY_COEFFICIENT = 2
var JUMP_HORIZONTAL_VELOCITY_TRESHOLD = 100

## Get jump horizontal velocity coefficient
func get_jump_horizontal_velocity_coefficient() -> float:
	if not is_jumping:
		return 1.0
		
	var velocity_diff = abs(velocity.y - JUMP_VELOCITY)

	if velocity_diff >= JUMP_HORIZONTAL_VELOCITY_TRESHOLD:
		return 1.0
	else:
		return 1 + (JUMP_HORIZONTAL_VELOCITY_COEFFICIENT - JUMP_HORIZONTAL_VELOCITY_COEFFICIENT * velocity_diff / JUMP_HORIZONTAL_VELOCITY_TRESHOLD)


# State Handlers _______________________________________________________________

## Transitions the character to a new state
func transition_to(new_state):
	current_state = new_state


## Handles the idle state
func handle_idle_state(info: StateInformation):
	if info.direction != 0:
		return transition_to(State.RUNNING)
	
	horizontal_velocity = move_toward(horizontal_velocity, 0, max(SPEED, abs(horizontal_velocity)) * info.delta * 12)
	
	if info.is_on_floor:
		_animated_sprite.play("idle")

## Handles the running state
func handle_running_state(info: StateInformation):
	if info.direction != 0:
		facing_direction = info.direction < 0
	
	if info.direction == 0:
		return transition_to(State.IDLE)
	elif info.is_sprinting and info.is_on_floor:
		return transition_to(State.SPRINTING)
	
	
	var target_velocity = info.direction * SPEED * get_jump_horizontal_velocity_coefficient()
	if horizontal_velocity != 0 and sign(horizontal_velocity) != sign(target_velocity):
		horizontal_velocity = 0
	horizontal_velocity = move_toward(horizontal_velocity, target_velocity, SPEED * info.delta * 6)
	
	if info.is_on_floor:
		_animated_sprite.play("run")
			
## Handles the sprinting state
func handle_sprinting_state(info: StateInformation):
	if info.direction != 0:
		facing_direction = info.direction < 0

	if info.direction == 0:
		return transition_to(State.IDLE)
	elif not info.is_sprinting:
		return transition_to(State.RUNNING)
	
	var target_velocity = info.direction * SPRINT_SPEED * get_jump_horizontal_velocity_coefficient()
	if horizontal_velocity != 0 and sign(horizontal_velocity) != sign(target_velocity):
		horizontal_velocity = 0
	horizontal_velocity = move_toward(horizontal_velocity, target_velocity, SPRINT_SPEED * info.delta * 6)
	
	if info.is_on_floor:
		_animated_sprite.play("sprint")
	

func handle_coyote_time(delta: float, on_floor: bool):
	if on_floor:
		coyote_timer = COYOTE_TIME
	elif not is_jumping:
		coyote_timer = max(coyote_timer - delta, 0)
