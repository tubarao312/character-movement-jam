extends PlayerState
class_name IdleState

func enter(_args: Dictionary = {}) -> void:
	player._animated_sprite.play("idle")
	player.dash_manager.reset_dash_charge()

func step(_delta: float) -> void:
	# If idle, restart the coyote time so that
	# the player can jump again
	player.coyote_manager.restart_coyote_time()

	if player.input.direction != 0:
		transition_to(Enums.PlayerStates.RUNNING)
		return

	# Dash
	if player.input.dash_pressed and player.dash_manager.can_dash():
		transition_to(Enums.PlayerStates.DASHING)
		return

	# Jump
	if player.input.is_jump_queued() and player.coyote_manager.has_coyote_jump():
		transition_to(Enums.PlayerStates.AIRBORNE, {"rising": true})
		return

	# Start Falling
	if not player.is_on_floor():
		transition_to(Enums.PlayerStates.AIRBORNE, {"rising": false})
		return
	
	player.horizontal_velocity = move_toward(player.horizontal_velocity, 0, max(player.RUN_SPEED, abs(player.horizontal_velocity)) * _delta * 15)
	
	if player.is_on_floor:
		player._animated_sprite.play("idle")
