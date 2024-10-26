class_name RunningState
extends PlayerState

## Handles the running state
func step(delta: float) -> void:
	# If idle, restart the coyote time so that
	# the player can jump again
	player.coyote_manager.restart_coyote_time()

	if player.input.direction < 0: player.facing_direction = Enums.FacingDirection.LEFT
	elif player.input.direction > 0: player.facing_direction = Enums.FacingDirection.RIGHT
		
	if player.input.direction == 0: transition_to(Enums.PlayerStates.IDLE)
	# elif player.is_sprinting and player.is_on_floor: transition_to(Enums.PlayerStates.SPRINTING)
		
	var target_velocity = player.input.direction * player.RUN_SPEED # * player.get_jump_horizontal_velocity_coefficient()
	if player.horizontal_velocity != 0 and sign(player.horizontal_velocity) != sign(target_velocity):
		player.horizontal_velocity = 0
	player.horizontal_velocity = move_toward(player.horizontal_velocity, target_velocity, player.RUN_SPEED * delta * 6)
	
	# TODO - Change animation speed and add walking animation depending on walk speed
	player._animated_sprite.play("run")
	
	# Jump
	if player.input.is_jump_queued() and player.coyote_manager.has_coyote_jump():
		transition_to(Enums.PlayerStates.AIRBORNE, {"rising": true})
	
	# Fall
	if not player.is_on_floor():
		transition_to(Enums.PlayerStates.AIRBORNE, {"rising": false})
