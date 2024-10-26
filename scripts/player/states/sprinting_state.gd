# var SPRINT_SPEED = 300.0

# ## Handles the sprinting state
# func step_sprinting_state(info: StateInformation):
# 	if info.direction < 0: facing_direction = FacingDirection.LEFT
# 	elif info.direction > 0: facing_direction = FacingDirection.RIGHT

# 	if info.direction == 0:
# 		return transition_to(State.IDLE)
# 	elif not info.is_sprinting:
# 		return transition_to(State.RUNNING)
	
# 	var target_velocity = info.direction * SPRINT_SPEED * get_jump_horizontal_velocity_coefficient()
# 	if horizontal_velocity != 0 and sign(horizontal_velocity) != sign(target_velocity):
# 		horizontal_velocity = 0
# 	horizontal_velocity = move_toward(horizontal_velocity, target_velocity, SPRINT_SPEED * info.delta * 6)
	
# 	if info.is_on_floor:
# 		_animated_sprite.play("sprint")
