extends CharacterBody2D

# --- Movement Constants ---
# Tuned for a "Weighted" and "Snappy" feel
const MAX_SPEED = 500.0
const ACCEL = 2000.0
const FRICTION = 1500.0
const JUMP_VELOCITY = -800.0
const GRAVITY = 1800.0

func _ready() -> void:
	setup_input_mappings()

func setup_input_mappings() -> void:
	# 1. Define Key Mappings
	var key_mappings = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP]
	}
	
	# 2. Define Button Mappings (Digital)
	var button_mappings = {
		"jump": [JOY_BUTTON_A, JOY_BUTTON_B]
	}
	
	# Create actions and map keys
	for action in key_mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		
		for key in key_mappings[action]:
			var ev = InputEventKey.new()
			ev.keycode = key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
				
	# Map joypad buttons
	for action in button_mappings:
		for btn in button_mappings[action]:
			var ev = InputEventJoypadButton.new()
			ev.button_index = btn
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)

	# 3. Map Joypad Axes (Analog)
	_setup_axis_mapping("move_left", JOY_AXIS_LEFT_X, -1.0)
	_setup_axis_mapping("move_right", JOY_AXIS_LEFT_X, 1.0)

func _setup_axis_mapping(action: String, axis: int, direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	
	var ev = InputEventJoypadMotion.new()
	ev.axis = axis
	# In Godot 4, for an axis to trigger a digital action, we set the axis 
	# and the threshold. The engine handles the sign of the movement.
	# To map "Left" to move_left, we want it to trigger when axis value is negative.
	# We use a small epsilon to avoid jitter.
	if direction < 0:
		ev.axis_value = -0.5 # Trigger when pushed significantly left
	else:
		ev.axis_value = 0.5 # Trigger when pushed significantly right
		
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 2. Handle Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Handle Horizontal Movement
	# get_axis is the standard for hybrid Keyboard/Controller support
	var input_dir := Input.get_axis("move_left", "move_right")
	
	if input_dir != 0:
		# Snappy acceleration
		velocity.x = move_toward(velocity.x, input_dir * MAX_SPEED, ACCEL * delta)
	else:
		# Weighted stop
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# 4. Final Movement Execution
	move_and_slide()
