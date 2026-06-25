extends CharacterBody2D

# --- Enums ---
enum State { NORMAL, CROUCH, BALL, SUPERMAN }

# --- Movement Constants ---
const BASE_MAX_SPEED = 600.0
const GROUND_ACCEL = 3000.0
const AIR_ACCEL = 4000.0
const FRICTION = 4000.0
const JUMP_VELOCITY = -1300.0
const GRAVITY = 2200.0
const SLOPE_SLIDE_FORCE = 1500.0

# --- Polish Constants ---
const COYOTE_TIME = 0.15
const JUMP_BUFFER = 0.15
const JUMP_CUT_FACTOR = 0.5

# --- State Dimensions (Width, Height) ---
const DIMENSIONS = {
	State.NORMAL: Vector2(40, 180),
	State.CROUCH: Vector2(40, 90),
	State.BALL: Vector2(60, 60),
	State.SUPERMAN: Vector2(180, 40)
}

# --- State Physics Multipliers (Slope Slide Force, Friction Multiplier, Max Speed Multiplier) ---
const STATE_PHYSICS = {
	State.NORMAL: {"slide": 1.0, "friction": 1.0, "speed": 1.0},
	State.CROUCH: {"slide": 2.0, "friction": 0.3, "speed": 0.7},
	State.BALL: {"slide": 3.0, "friction": 0.01, "speed": 1.5},
	State.SUPERMAN: {"slide": 0.1, "friction": 3.0, "speed": 1.2}
}

# --- State Variables ---
var current_state := State.NORMAL
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var momentum_timer := 0.0 # Timer to preserve slope speed on flat ground

@onready var collision_shape = $CollisionShape2D
@onready var visual = $Visual

func _ready() -> void:
	floor_stop_on_slope = false
	floor_constant_speed = true
	floor_snap_length = 32.0 # Increased snap to prevent launching at slope ends
	
	add_to_group("player")
	setup_input_mappings()
	apply_state_dimensions()

func setup_input_mappings() -> void:
	var key_mappings = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"crouch": [KEY_S, KEY_DOWN, KEY_CTRL],
		"morph_ball": [KEY_C, KEY_V],
		"morph_superman": [KEY_R, KEY_UP]
	}
	var button_mappings = {
		"jump": [JOY_BUTTON_A, JOY_BUTTON_B],
		"crouch": [13],
		"morph_ball": [JOY_BUTTON_X],
		"morph_superman": [JOY_BUTTON_Y]
	}
	for action in key_mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in key_mappings[action]:
			var ev = InputEventKey.new()
			ev.keycode = key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
	for action in button_mappings:
		for btn in button_mappings[action]:
			var ev = InputEventJoypadButton.new()
			ev.button_index = btn
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
	_setup_axis_mapping("move_left", JOY_AXIS_LEFT_X, -1.0)
	_setup_axis_mapping("move_right", JOY_AXIS_LEFT_X, 1.0)
	_setup_axis_mapping("crouch", JOY_AXIS_LEFT_Y, 1.0) # LS Down
	_setup_axis_mapping("morph_superman", JOY_AXIS_RIGHT_Y, -1.0) # RS Up
	_setup_axis_mapping("morph_ball", JOY_AXIS_RIGHT_Y, 1.0) # RS Down

func _setup_axis_mapping(action: String, axis: int, direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventJoypadMotion.new()
	ev.axis = axis
	# Increased threshold to 0.8 for a "tighter" trigger (especially for crouching)
	ev.axis_value = 0.8 if direction > 0 else -0.8
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	var old_state = current_state
	current_state = new_state
	apply_state_dimensions(old_state)

func apply_state_dimensions(old_state: State = -1) -> void:
	var dim = DIMENSIONS[current_state]
	
	# 1. Ground Pinning: Prevent "shooting up" when shrinking/growing
	if is_on_floor() and old_state != -1:
		var old_dim = DIMENSIONS[old_state]
		var diff = (old_dim.y - dim.y) / 2.0
		global_position.y += diff

	# 2. Update Collision Shape
	if current_state == State.BALL:
		var circle = CircleShape2D.new()
		circle.radius = dim.x / 2.0
		collision_shape.shape = circle
	else:
		var rect = RectangleShape2D.new()
		rect.size = dim
		collision_shape.shape = rect
	
	# 3. Update Visuals
	visual.size = dim
	visual.position = -dim / 2

func _physics_process(delta: float) -> void:
	handle_morphing()
	
	# 1. Timers & Grounding
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER
	else:
		jump_buffer_timer -= delta
		
	# Momentum timer decay
	if momentum_timer > 0:
		momentum_timer -= delta

	# Slope Momentum Tracking: Always track if we are on a slope, regardless of input
	if is_on_floor():
		var floor_normal = get_floor_normal()
		if not Vector2.UP.is_equal_approx(floor_normal):
			momentum_timer = 1.0

	# 2. Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 2. Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 3. Jump Logic
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		coyote_timer = 0

	# 4. Variable Jump Height
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_FACTOR

	# 5. Horizontal Movement
	var input_dir := Input.get_axis("move_left", "move_right")
	var current_accel = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var current_max_speed = BASE_MAX_SPEED * STATE_PHYSICS[current_state]["speed"]
	
	if input_dir != 0:
		# If we are moving faster than max speed (due to slope), let the speed decay slowly
		# instead of snapping it back to MAX_SPEED instantly.
		if abs(velocity.x) > current_max_speed:
			velocity.x = move_toward(velocity.x, input_dir * current_max_speed, FRICTION * 0.5 * delta)
		else:
			velocity.x = move_toward(velocity.x, input_dir * current_max_speed, current_accel * delta)
	else:
		if is_on_floor():
			var floor_normal = get_floor_normal()
			if not Vector2.UP.is_equal_approx(floor_normal):
				var gravity_vec = Vector2(0, 1)
				var slide_dir = gravity_vec - (gravity_vec.dot(floor_normal) * floor_normal)
				
				var slide_mult = STATE_PHYSICS[current_state]["slide"]
				velocity += slide_dir * (SLOPE_SLIDE_FORCE * slide_mult) * delta
				momentum_timer = 1.0 # Extended coasting time
			else:
				# Transitioning to flat ground: Dampen Y velocity to prevent "shooting out"
				velocity.y = move_toward(velocity.y, 0, GRAVITY * delta)
		
		var effective_friction = FRICTION
		# Use slope friction if we are currently on a slope OR if we recently left one
		if (is_on_floor() and not Vector2.UP.is_equal_approx(get_floor_normal())) or momentum_timer > 0:
			effective_friction = FRICTION * STATE_PHYSICS[current_state]["friction"] * 0.2 # Extreme low friction during coast
			
		velocity.x = move_toward(velocity.x, 0, effective_friction * delta)

	move_and_slide()

func handle_morphing() -> void:
	# 1. Priority: Right Stick Morphing (Superman/Ball)
	if Input.is_action_pressed("morph_superman"):
		change_state(State.SUPERMAN)
	elif Input.is_action_pressed("morph_ball"):
		change_state(State.BALL)
	# 2. Crouch Check: Use a tighter vector-based check for the "4pm to 7pm" zone
	elif Input.is_action_pressed("crouch") or Input.get_joy_axis(0, JOY_AXIS_LEFT_Y) > 0.9:
		change_state(State.CROUCH)
	else:
		change_state(State.NORMAL)
