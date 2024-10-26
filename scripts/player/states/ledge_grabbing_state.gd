class_name LedgeGrabbingState
extends PlayerState

# We use this to record when to exit the ledge grabbing state
var ledge_grab_direction := Enums.FacingDirection.RIGHT

func enter(_args: Dictionary = {}) -> void:
	player.input.reset_jump_queue()
	player._animated_sprite.play("ledge_grabbing")
	ledge_grab_direction = player.facing_direction
	player.velocity.y = 0
	
func step(_delta: float) -> void:	
	# If idle, restart the coyote time so that
	# the player can jump again
	player.coyote_manager.restart_coyote_time()

	# The player just wants to get down
	if player.input.is_ignoring_ledge_grab():
		print("Leaving ledge grab because player is ignoring ledge grab")
		transition_to(Enums.PlayerStates.IDLE)
		return

	# Player wants to jump
	if player.input.is_jump_queued():
		print("Leaving ledge grab because player is jumping")
		transition_to(Enums.PlayerStates.AIRBORNE, {"rising": true})
		return
	
	# Player is inputing the opposite direction of the ledge grab
	if player.input.direction != 0 and sign(player.input.direction) != sign(ledge_grab_direction):
		print("Leaving ledge grab because player is inputing the opposite direction of the ledge grab")

		transition_to(Enums.PlayerStates.IDLE)
		return

	# NOTE - Does this really need to exist? To be tested.
	player.horizontal_velocity = 0

func exit() -> void:
	# TODO - Fix all this this
	print("Leaving ledge grab state..")
	player._animated_sprite.play("jump_fall")
	player.post_ledge_grab_timer = player.POST_LEDGE_GRAB_TIME
