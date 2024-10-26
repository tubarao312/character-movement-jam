class_name AirborneState
extends PlayerState

# Only relevant for the jump animation phases
var AIR_TIME_BEFORE_JUMP_ANIM = 0.2
var JUMP_MID_VELOCITY_TRESHOLD = 35
var air_time = 0.0


## Handles the jump animations based on the player's velocity and air time.
func handle_jump_animations(delta: float):
	if is_rising or air_time >= AIR_TIME_BEFORE_JUMP_ANIM:
		if player.velocity.y < -JUMP_MID_VELOCITY_TRESHOLD: player._animated_sprite.play("jump_rise")
		elif player.velocity.y > JUMP_MID_VELOCITY_TRESHOLD: player._animated_sprite.play("jump_fall")
		else: player._animated_sprite.play("jump_mid")

	air_time += delta


# Jumping Constants

var JUMP_HORIZONTAL_VELOCITY_COEFFICIENT = 2
var JUMP_HORIZONTAL_VELOCITY_TRESHOLD = 100
var JUMP_VELOCITY = -400.0
var JUMP_BOOST_MAX_TIME = 0.1
var JUMP_BOOST_MIN_TIME = 0.1
var MIN_JUMP_VELOCITY = -400.0
var JUMP_CANCEL_VELOCITY = -200
var LEDGE_GRAB_JUMP_BOOST = -75.0  # Additional upward velocity when jumping from ledge grab
var LEDGE_GRAB_HORIZONTAL_BOOST = 250.0  # Additional horizontal velocity when jumping from ledge grab


var SPEED = 150.0


# State

var is_rising := true

## Cancels the jump by setting the vertical velocity to the jump cancel velocity
## and setting is_jumping to false.
func cancel_rising() -> void:
	player.velocity.y = max(player.velocity.y, JUMP_CANCEL_VELOCITY)
	is_rising = false

## Possible Arguments:
## - rising: Boolean indicating whether the player should start by rising or falling
func enter(args: Dictionary = {}) -> void:
	
	# Reset important variables
	air_time = 0.0

	# Get the rising argument
	is_rising = args.get("rising")
	if not "rising" in args:
		push_error("AirborneState.enter(): 'rising' argument is required")
		return

	# Initial Jump Velocity (only if the player is rising)
	if is_rising:
		player.coyote_manager.reset_coyote_time()
		player.input.reset_jump_queue()
		player._animated_sprite.play("jump_rise")
		player.velocity.y += JUMP_VELOCITY

		# If the player JUST left a ledge grab state, apply a boost to the jump
		if player.is_post_ledge_grab_jump_active():
			player.velocity.y += LEDGE_GRAB_JUMP_BOOST

			# If the player is moving in a direction, also give them a horizontal boost
			# TODO - In the future, maybe apply a small force instead of a speed boost?
			if player.input.direction != 0:
				player.horizontal_velocity += player.input.direction * LEDGE_GRAB_HORIZONTAL_BOOST


func step(delta: float) -> void:

	# Handle important timers
	player.coyote_manager.decrement_coyote_time(delta)

	# If the player is not pressing the jump button, we want to attempt to cancel the jump
	if is_rising and not player.input.jump_pressed: cancel_rising()
	
	# If the player is falling, we also want to cancel the rising
	if player.velocity.y > JUMP_CANCEL_VELOCITY: cancel_rising()

	# If the player touches the floor, we want to transition to the idle state
	if player.is_on_floor(): transition_to(Enums.PlayerStates.IDLE)
	
	# Jump again (this can happen if the player is in the air and jumps again)
	if player.input.is_jump_queued() and player.coyote_manager.has_coyote_jump():
		transition_to(Enums.PlayerStates.AIRBORNE, {"rising": true})
		return

	# If the player should ledge grab, enter the ledge grabbing state
	if player.should_ledge_grab():
		transition_to(Enums.PlayerStates.LEDGE_GRABBING)
		return

	# Handle horizontal movement
	var direction = player.input.direction
	var target_velocity = direction * player.RUN_SPEED # * player.get_jump_horizontal_velocity_coefficient()
	player.horizontal_velocity = move_toward(player.horizontal_velocity, target_velocity, player.RUN_SPEED * delta * 10)
	
	# Apply gravity
	player.velocity += player.get_gravity() * delta

	# Animations 
	handle_jump_animations(delta)
