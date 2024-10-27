class_name RunningState
extends PlayerState


func enter(_args: Dictionary = {}) -> void:
	player.dash_manager.reset_dash_charge()

## Handles the running state
func step(delta: float) -> void:
	# If idle, restart the coyote time so that
	# the player can jump again
	player.coyote_manager.restart_coyote_time()
		
	# Dash
	if player.input.dash_pressed and player.dash_manager.can_dash():
		transition_to(Enums.PlayerStates.DASHING)
		return
		
	if player.input.direction == 0: transition_to(Enums.PlayerStates.IDLE)
	# elif player.is_sprinting and player.is_on_floor: transition_to(Enums.PlayerStates.SPRINTING)
		
	var target_velocity = player.input.direction * player.RUN_SPEED # * player.get_jump_horizontal_velocity_coefficient()
	if player.horizontal_velocity != 0 and sign(player.horizontal_velocity) != sign(target_velocity):
		player.horizontal_velocity = 0
	player.horizontal_velocity = move_toward(player.horizontal_velocity, target_velocity, player.RUN_SPEED * delta * 15)
	
	# Determine animation based on horizontal velocity
	var speed_ratio = abs(player.horizontal_velocity) / player.RUN_SPEED
	var animation = "walk" if abs(player.horizontal_velocity) < player.RUN_SPEED * 0.5 else "run"
	player._animated_sprite.play(animation)
	
	# Adjust animation speed based on velocity
	if animation == "run":
		player._animated_sprite.speed_scale = max(0.75, speed_ratio)
	else:
		player._animated_sprite.speed_scale = 1.0
	
	# Jump
	if player.input.is_jump_queued() and player.coyote_manager.has_coyote_jump():
		transition_to(Enums.PlayerStates.AIRBORNE, {"rising": true})
	
	# Fall
	if not player.is_on_floor():
		transition_to(Enums.PlayerStates.AIRBORNE, {"rising": false})
