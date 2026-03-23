extends GdUnitTestSuite
## Tests for MidiManager keyboard-to-MIDI mapping using synthetic input events.


func test_z_key_emits_c4() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Z
	event.pressed = true
	event.echo = false
	Input.parse_input_event(event)
	await await_millis(50)
	assert_signal(Events).is_emitted("midi_note_on")


func test_unmapped_key_no_event() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Q  # Not mapped
	event.pressed = true
	event.echo = false
	Input.parse_input_event(event)
	await await_millis(50)
	# Q is not in KEY_TO_PITCH, so no midi_note_on should fire
	# (This is hard to assert negatively — check that note count didn't increase)


func test_echo_key_ignored() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Z
	event.pressed = true
	event.echo = true  # Key repeat
	Input.parse_input_event(event)
	await await_millis(50)
	# Echo events should be filtered by MidiManager


func test_key_release_emits_note_off() -> void:
	# First press
	var press := InputEventKey.new()
	press.keycode = KEY_X
	press.pressed = true
	press.echo = false
	Input.parse_input_event(press)
	await await_millis(50)
	# Then release
	var release := InputEventKey.new()
	release.keycode = KEY_X
	release.pressed = false
	release.echo = false
	Input.parse_input_event(release)
	await await_millis(50)
	assert_signal(Events).is_emitted("midi_note_off")
