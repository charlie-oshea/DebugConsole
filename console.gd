extends Control

@onready var output_text_edit: TextEdit = $Panel/MarginContainer/VBoxContainer/OutputTextEdit
@onready var input_text_edit: LineEdit = $Panel/MarginContainer/VBoxContainer/HBoxContainer/InputTextEdit
@onready var top_bar: Panel = $Panel/MarginContainer/VBoxContainer/TopBar
@onready var resize_handle: Panel = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ResizeHandle
@onready var console_panel: Panel = $Panel

# store registered commands in a dictionary
var commands: Dictionary = {}
var command_history: Array = [] # store all entered commands
var history_index: int = -1 # tracks current position in history

var is_console_open: bool = false
var is_dragging: bool = false
var is_resizing: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var initial_size: Vector2 = Vector2.ZERO

# command vars
var show_fps: bool = false
var debug_mode: bool = false

func _ready() -> void:
	# hidden by default
	visible = false
	
	register_command("help", Callable(self, "_command_help"), "Display available commands")
	register_command("list_commands", Callable(self, "_command_list_commands"), "List all registered commands")
	register_command("clear", Callable(self, "_command_clear"), "Clear the console output")
	register_command("quit", Callable(self, "_command_quit"), "Quit the game")
	register_command("exit", Callable(self, "_command_quit"), "Quit the game")  # Alias for quit
	register_command("pause", Callable(self, "_command_pause"), "Toggle pause")
	register_command("restart", Callable(self, "_command_restart"), "Restart the current scene")
	register_command("fps", Callable(self, "_command_show_fps"), "Toggle FPS display")
	register_command("max_fps", Callable(self, "_command_set_max_fps"), "Set the max FPS (usage: max_fps <value>)")
	register_command("time_scale", Callable(self, "_command_time_scale"), "Set the time scale (usage: time_scale <value>)")
	register_command("log", Callable(self, "_command_log"), "Log a message to the console (usage: log <message>)")
	register_command("font_size", Callable(self, "_command_set_font_size"), "Set the font size (usage: font_size <size>)")
	register_command("list_nodes", Callable(self, "_command_list_nodes"), "List all nodes in the current scene")
	register_command("debug", Callable(self, "_command_debug"), "Toggle debug mode")
	
	input_text_edit.connect("text_submitted", Callable(self, "_on_command_submitted"))
	input_text_edit.connect("gui_input", Callable(self, "_on_input_text_gui_input"))
	
	 # connect top bar and resize handle input events
	top_bar.connect("gui_input", Callable(self, "_on_top_bar_gui_input"))
	resize_handle.connect("gui_input", Callable(self, "_on_resize_handle_gui_input"))

func _process(delta: float) -> void:
	if show_fps:
		print_to_console("FPS: " + str(Engine.get_frames_per_second()))

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and (event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ESCAPE):
			toggle_console()

func toggle_console():
	is_console_open = !is_console_open
	visible = is_console_open

	# show/hide the mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_console_open else Input.MOUSE_MODE_CAPTURED)

	# pause the game when the console is open not wanted always
	#get_tree().paused = is_console_open

	# focus the input field when the console is opened
	if is_console_open:
		call_deferred("_focus_input_line")

func _focus_input_line():
	input_text_edit.grab_focus()

# resizing and moving
func _on_top_bar_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# start dragging
				is_dragging = true
				drag_offset = get_global_mouse_position() - global_position
			else:
				# stop dragging
				is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		# move the console
		global_position = get_global_mouse_position() - drag_offset

# handle resize handle dragging
func _on_resize_handle_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_resizing = true
				initial_size = size
			else:
				is_resizing = false
	elif event is InputEventMouseMotion and is_resizing:
		# eesize the console
		var mouse_position = get_local_mouse_position()
		console_panel.size = Vector2(
			max(mouse_position.x, 200),  # min width
			max(mouse_position.y, 150)   # max height
		)

### cycling history
func _on_input_text_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_UP:
				_cycle_history(-1)
			elif event.keycode == KEY_DOWN:
				_cycle_history(1)

func _cycle_history(direction: int):
	if command_history.size() == 0:
		return
	
	history_index = clamp(history_index + direction, -1, command_history.size() - 1)
	
	if history_index == -1:
		input_text_edit.text = "" # clear input when at bottom of history
	else:
		input_text_edit.text = command_history[history_index]
	
	input_text_edit.caret_column = input_text_edit.text.length()


## to register a command from elsewhere in the project - set console as autoload and use same format as here
func register_command(command: String, callable: Callable, description: String = ""):
	commands[command] = {"callable": callable, "description": description}

func _on_command_submitted(command_text: String):
	# clear input field
	input_text_edit.clear()
	print_to_console("> " + command_text)
	
	# add command to history
	command_history.append(command_text)
	history_index = -1 # reset index
	if command_history.size() > 50:  # Keep only the last 50 commands
		command_history.pop_front()
	
	# parse and execute command
	var args = command_text.split(" ")
	var command = args[0]
	args.remove_at(0) # remove command leaving only arguments
	
	if commands.has(command):
		var result = commands[command]["callable"].call(args)
		if result != null:
			print_to_console(str(result))
	else:
		print_to_console("Unknown command: " + command)

func print_to_console(message: String):
	output_text_edit.text += message + "\n"
	output_text_edit.scroll_vertical = output_text_edit.get_line_count() - 1


### default commands ###

func _command_help(args: Array):
	print_to_console("Available commands:")
	for cmd in commands:
		print_to_console("  - " + cmd + ": " + commands[cmd]["description"])
	
	return

func _command_clear(args: Array):
	output_text_edit.clear()

func _command_quit(args: Array):
	get_tree().quit()

func _command_restart(args: Array):
	get_tree().reload_current_scene()

func _command_pause(args: Array):
	if get_tree().paused:
		get_tree().paused = false
		print_to_console("Unpaused")
	else:
		get_tree().paused = true
		print_to_console("Paused")

func _command_show_fps(args: Array):
	show_fps = not show_fps
	print_to_console("FPS display: " + ("enabled" if show_fps else "disabled"))

func _command_set_max_fps(args: Array):
	if args.size() != 1 or not args[0].is_valid_int():
		print_to_console("Usage: set_fps <value>")
		return
	var fps = args[0].to_int()
	Engine.max_fps = fps
	print_to_console("Max FPS set to: " + str(fps))

func _command_time_scale(args: Array):
	if args.size() != 1 or not args[0].is_valid_float():
		print_to_console("Usage: time_scale <value>")
		return
	
	var scale = args[0].to_float()
	Engine.time_scale = scale
	print_to_console("Time scale set to: " + str(scale))

func _command_log(args: Array):
	if args.size() < 1:
		print_to_console("Usage: log <message>")
		return
	
	var message = " ".join(args)
	print_to_console("[LOG] " + message)

func _command_list_nodes(args: Array):
	var nodes = get_tree().current_scene.get_children()
	print_to_console("Nodes in current scene:")
	for node in nodes:
		print_to_console("  - " + node.name)

func _command_debug(args: Array):
	debug_mode = not debug_mode
	print_to_console("Debug mode: " + ("enabled" if debug_mode else "disabled"))

func _command_list_commands(args: Array):
	print_to_console("Commands:")
	for cmd in commands:
		print_to_console("  - " + cmd)

func _command_set_font_size(args: Array):
	if args.size() != 1 or not args[0].is_valid_int():
		print_to_console("Usage: font_size <size>")
		return
	
	var font_size = args[0].to_int()
	if font_size < 8 or font_size > 48:
		print_to_console("Font size must be between 8 and 48.")
		return
	
	# Set the font size for the input and output
	output_text_edit.add_theme_font_size_override("font_size", font_size)
	input_text_edit.add_theme_font_size_override("font_size", font_size)
	print_to_console("Font size set to: " + str(font_size))
