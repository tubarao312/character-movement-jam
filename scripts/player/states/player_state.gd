extends Node
class_name PlayerState

var player: Player

# Base functions that must be implemented by each state

## Initializes the state with a reference to the player.
## The player reference is used to access the player's properties and functions.
func _init(_player: Player) -> void:
	player = _player

## Function called when entering the state.
func enter(_args: Dictionary = {}) -> void: pass
## Function called each frame while in the state.
func step(_delta: float) -> void: pass
## Function called when exiting the state.
func exit() -> void: pass

## Transitions the character to a new state, calling the exit and enter state
## functions of the old and new state's state handlers respectively.
## 
## Arguments:
## - new_state: The new state to transition to.
func transition_to(new_state: Enums.PlayerStates, args: Dictionary = {}) -> void:
	player.state_handlers[player.current_state].exit.call()
	player.current_state = new_state
	player.state_handlers[new_state].enter.call(args)
