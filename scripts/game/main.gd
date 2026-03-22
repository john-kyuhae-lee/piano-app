extends Node2D
## Main scene — composes keyboard and note renderer.

var _keyboard: PianoKeyboard
var _note_renderer: NoteRenderer


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
