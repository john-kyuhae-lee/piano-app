extends Node2D
## Main scene — composes keyboard, note renderer, and MIDI status display.

var _keyboard: PianoKeyboard
var _note_renderer: NoteRenderer
var _status_label: Label


func _ready() -> void:
	# Dark background
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.1))

	_keyboard = PianoKeyboard.new()
	_keyboard.name = "Keyboard"
	add_child(_keyboard)

	_note_renderer = NoteRenderer.new()
	_note_renderer.name = "NoteRenderer"
	add_child(_note_renderer)

	# Wire up after keyboard is ready
	_note_renderer.setup.call_deferred(_keyboard)

	# MIDI connection status
	_status_label = Label.new()
	_status_label.name = "MidiStatus"
	_status_label.position = Vector2(20.0, 16.0)
	_status_label.add_theme_font_size_override(&"font_size", 20)
	_status_label.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))
	_status_label.text = "No MIDI device"
	add_child(_status_label)

	Events.midi_device_connected.connect(_on_device_connected)
	Events.midi_device_disconnected.connect(_on_device_disconnected)


func _on_device_connected(device_name: String) -> void:
	_status_label.text = "Connected: " + device_name
	_status_label.add_theme_color_override(&"font_color", Color(0.4, 0.9, 0.5))


func _on_device_disconnected() -> void:
	_status_label.text = "No MIDI device"
	_status_label.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))
