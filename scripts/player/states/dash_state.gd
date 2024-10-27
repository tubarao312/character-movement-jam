class_name DashState
extends PlayerState

const DASH_SPEED_INIT = 700.0
const DASH_SPEED_EXIT = 300.0

const DASH_DURATION = 0.15
const DASH_COOLDOWN = 0.5

var dash_direction: Vector2
var dash_timer: float
var can_dash: bool = true

## Dash Raycasts ____________________________
## These are used to check if the player is near the edge of a wall, ceiling, or floor.
## If they are, we push them slightly in the direction of the upper or lower raycast so that
## they don't get stuck.



func enter(_args: Dictionary = {}) -> void:
	
	player.dash_manager.use_dash_charge()
	player.input.reset_jump_queue()

	dash_timer = DASH_DURATION
	can_dash = false
	# Get dash direction from input
	dash_direction = player.input.input_dir.normalized()

	# Rotate dash_raycasts to match dash direction
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2(player.facing_direction, 0)

	# Round the dash direction to the nearest 45 degrees
	dash_direction = dash_direction.round().normalized()

	player.dash_raycasts.rotation = dash_direction.angle()

	# Set initial dash velocity
	player.velocity = dash_direction * DASH_SPEED_INIT

func step(delta: float) -> void:
	dash_timer -= delta
	player._animated_sprite.play("dash_loop")

	var middle_raycast_colliding = player.middle_raycast.is_colliding()
	var lower_raycast_colliding = player.lower_raycast.is_colliding()
	var upper_raycast_colliding = player.upper_raycast.is_colliding()
	var helper_velocity = Vector2.ZERO

	if dash_timer > 0.05 and not middle_raycast_colliding:
		if lower_raycast_colliding and not upper_raycast_colliding:
			helper_velocity -= dash_direction.rotated(PI/2) * 1000
		elif upper_raycast_colliding and not lower_raycast_colliding:
			helper_velocity += dash_direction.rotated(PI/2) * 1000

	if dash_timer <= 0:
		player.velocity = dash_direction * DASH_SPEED_EXIT
		transition_to(Enums.PlayerStates.AIRBORNE, {"rising": false})
		return
	
	
	# Switch to dash_end animation in the final 150ms
	#if dash_timer <= 0.05 and player._animated_sprite.animation != "dash_end":
		#player._animated_sprite.play("dash_end")

	# Maintain dash velocity
	var t = clamp(1 - (dash_timer / DASH_DURATION), 0.0, 1.0)
	player.velocity = lerp(dash_direction * DASH_SPEED_INIT, dash_direction * DASH_SPEED_EXIT, t) + helper_velocity
	

func exit() -> void:
	player.dash_manager.restart_dash_cooldown()
