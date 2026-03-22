# Godot 4.x / GDScript Project Conventions

Verified best practices for building a rhythm game in Godot 4.x with GDScript. Every rule here is actionable and specific. If a rule has a code example, follow the example literally.

---

## 1. GDScript Style Guide

Based on the [official Godot GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

### 1.1 Naming Conventions

| Thing               | Convention         | Example                          |
|---------------------|--------------------|----------------------------------|
| File names          | `snake_case.gd`    | `note_renderer.gd`              |
| Class names         | `PascalCase`       | `class_name NoteRenderer`       |
| Node names          | `PascalCase`       | `FallingNote`, `ScoreLabel`      |
| Functions           | `snake_case`       | `func spawn_note():`            |
| Variables           | `snake_case`       | `var scroll_speed: float`       |
| Signals             | `snake_case`, past tense | `signal note_hit`          |
| Constants           | `SCREAMING_SNAKE`  | `const MAX_NOTES := 128`        |
| Enum names          | `PascalCase` (singular) | `enum Judgment`             |
| Enum members        | `SCREAMING_SNAKE`  | `PERFECT, GREAT, GOOD, MISS`    |
| Private members     | `_leading_underscore` | `var _internal_timer: float`  |

### 1.2 File Encoding & Indentation

- **Tabs** for indentation (not spaces). This is non-negotiable in Godot.
- **UTF-8** encoding, no BOM.
- **LF** line endings.
- **One blank line** to separate logical sections within a function.
- **Two blank lines** between function definitions.
- **Line length**: aim for 80 characters, hard max 100.
- **Trailing commas** in multiline arrays, dicts, and enums. No trailing commas in single-line lists.

### 1.3 Code Ordering Within a File

Follow this exact order. No exceptions:

```
 1. @tool / @icon / @static_unload
 2. class_name
 3. extends
 4. ## Doc comment (class-level)
 5. Signals
 6. Enums
 7. Constants
 8. Static variables
 9. @export variables
10. Regular member variables
11. @onready variables
12. _static_init()
13. Other static methods
14. Built-in virtual methods (_init, _enter_tree, _ready, _process, _physics_process, etc.)
15. Overridden custom methods
16. Remaining public methods
17. Private methods (prefixed with _)
18. Inner classes
```

Example skeleton:

```gdscript
class_name FallingNote
extends Node2D
## A single note block that falls toward the hit line.

signal note_hit(judgment: Judgment)
signal note_missed

enum Judgment { PERFECT, GREAT, GOOD, MISS }

const HIT_LINE_Y := 600.0
const PERFECT_WINDOW := 0.033  # seconds

@export var speed: float = 400.0
@export var midi_pitch: int = 60

var _active := true
var _spawn_time: float

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $FingeringLabel


func _ready() -> void:
	_spawn_time = Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	if not _active:
		return
	position.y += speed * delta


func hit(timing_offset: float) -> Judgment:
	_active = false
	var judgment := _evaluate_timing(timing_offset)
	note_hit.emit(judgment)
	return judgment


func _evaluate_timing(offset: float) -> Judgment:
	var abs_offset := absf(offset)
	if abs_offset <= PERFECT_WINDOW:
		return Judgment.PERFECT
	elif abs_offset <= 0.066:
		return Judgment.GREAT
	elif abs_offset <= 0.1:
		return Judgment.GOOD
	else:
		return Judgment.MISS
```

### 1.4 Formatting Rules

```gdscript
# Use `and` / `or` / `not` — never `&&` / `||` / `!`
if is_alive and not is_stunned:
	take_action()

# Multiline conditions: wrap in parens, `and`/`or` at start of continuation
if (
		position.x > left_bound
		and position.x < right_bound
		and position.y > top_bound
):
	pass

# Continuation lines: 2 indent levels (not 1)
var tween := create_tween().set_trans(
		Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT)

# Ternary is fine on one line
var state := "grounded" if is_on_floor() else "airborne"

# Double quotes by default. Single quotes only to avoid escaping.
print("Player hit a note")
print('She said "perfect!"')

# Leading zeros required. Lowercase hex.
var opacity := 0.5      # not .5
var color := 0xff8800   # not 0xFF8800

# Underscores in large numbers
var score_target := 1_000_000
```

---

## 2. Scene Architecture Patterns

### 2.1 "Call Down, Signal Up"

This is the foundational architecture rule. Violating it creates unmaintainable code.

- **Parent calls child methods directly** (parent knows its children).
- **Child emits signals** (child does NOT call `get_parent()` or reference siblings).
- **Siblings never reference each other directly** — the common parent wires them together.

```gdscript
# GOOD: Parent wires siblings together in _ready()
func _ready() -> void:
	$Player.note_hit.connect($ScoreBoard.on_note_hit)
	$Player.health_changed.connect($UI/HealthBar.update_display)

# BAD: Child reaches up
func _ready() -> void:
	get_parent().get_node("ScoreBoard").add_score(100)  # Don't do this
```

### 2.2 Composition Over Inheritance

Build entities from small, focused child nodes (components), not deep inheritance trees.

```
# GOOD: Composition
Player (CharacterBody2D)
  |- Sprite2D
  |- CollisionShape2D
  |- HealthComponent (Node)       # health.gd
  |- HitboxComponent (Area2D)     # hitbox.gd
  |- AudioStreamPlayer2D

# BAD: Inheritance chain
BaseEntity → Character → Player → PlayerWithInventory → PlayerWithInventoryAndCombat
```

**Rules:**
- One script per node. If a script exceeds 200-300 lines, split into child nodes.
- Scenes should be runnable independently for testing (no assumed parent structure).
- Use `@export` to inject dependencies from the Inspector instead of hardcoded paths.

### 2.3 When to Use Autoloads

Autoloads are globals. Use them sparingly — only for **truly global, stateless** services:

**Acceptable autoloads:**
- `Events` — signal bus (see 2.4)
- `AudioManager` — background music crossfading
- `Config` — user settings (audio volume, key bindings)

**Not acceptable as autoloads:**
- Game state (score, combo, health) — pass via signals or inject via `@export`
- Scene-specific logic — belongs in the scene tree
- Anything that only one scene needs

### 2.4 Signal Bus Pattern

One autoload script that holds signals for cross-system communication:

```gdscript
# events.gd (registered as Autoload named "Events")
extends Node

signal song_started(song_data: SongData)
signal song_ended(final_score: int)
signal note_hit(judgment: FallingNote.Judgment, pitch: int)
signal note_missed(pitch: int)
signal combo_changed(new_combo: int)
signal midi_note_on(pitch: int, velocity: int)
signal midi_note_off(pitch: int)
```

**Emitting** (from anywhere):
```gdscript
Events.note_hit.emit(judgment, pitch)
```

**Listening** (from anywhere):
```gdscript
func _ready() -> void:
	Events.note_hit.connect(_on_note_hit)

func _on_note_hit(judgment: FallingNote.Judgment, pitch: int) -> void:
	_update_score(judgment)
```

**Rules for the signal bus:**
- Keep it to 10-15 signals max. If it grows larger, your architecture has problems.
- Only use it for events that genuinely cross system boundaries.
- Direct signal connections between parent/child are always preferred over the bus.
- Never put methods or state on the Events autoload. Signals only.

---

## 3. Performance Patterns for a Rhythm Game

### 3.1 `_process()` vs `_physics_process()`

| Use `_process(delta)`             | Use `_physics_process(delta)`        |
|-----------------------------------|--------------------------------------|
| Visual updates (note scrolling)   | Physics body movement (move_and_slide) |
| Animation control                 | Collision detection                  |
| UI updates                        | Raycasts                             |
| Input polling                     | Anything that needs fixed timestep   |

For a rhythm game specifically:
- **Note rendering/scrolling**: `_process()` — needs to be smooth, frame-rate dependent is fine since we multiply by delta.
- **Timing evaluation**: Neither — evaluate on input events, comparing against audio playback position.
- **Audio sync**: Use `AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()` for precise audio time, not delta accumulation.

### 3.2 Object Pooling

Godot 4 improved node creation performance significantly. Profile before pooling. But for rhythm games with hundreds of notes appearing/disappearing per song, pooling is worth it.

```gdscript
class_name NotePool
extends Node

var _pool: Array[FallingNote] = []
var _scene: PackedScene

func _init(note_scene: PackedScene, initial_size: int = 50) -> void:
	_scene = note_scene
	for i in initial_size:
		var note := _scene.instantiate() as FallingNote
		note.set_process(false)   # Disable processing while pooled
		note.visible = false
		_pool.append(note)
		add_child(note)


func acquire() -> FallingNote:
	var note: FallingNote
	if _pool.is_empty():
		note = _scene.instantiate() as FallingNote
		add_child(note)
	else:
		note = _pool.pop_back()
	note.visible = true
	note.set_process(true)
	return note


func release(note: FallingNote) -> void:
	note.visible = false
	note.set_process(false)
	note.set_physics_process(false)
	_pool.append(note)
```

**Key rules:**
- `set_process(false)` on pooled objects so they don't run `_process()` while idle.
- Never `queue_free()` pooled objects. Hide + disable + return to pool.
- Profile with Godot's built-in profiler first. Only pool if instantiation shows up as a bottleneck.

### 3.3 Expensive Operations to Avoid Per-Frame

- **`get_node()` / `$NodePath`** in `_process()` — cache with `@onready` instead.
- **`String` comparisons** — use `StringName` (`&"action_name"`) for input actions and dictionary keys.
- **`distance_to()`** — use `distance_squared_to()` when only comparing distances.
- **Creating/freeing nodes** — pool them (see 3.2).
- **Large GDScript loops** — if iterating 1000+ items per frame, consider moving to `_draw()` or a shader.
- **Unnecessary `queue_redraw()`** — `_draw()` results are cached. Only call `queue_redraw()` when state actually changes.

### 3.4 `_draw()` vs Scene Nodes for Rendering Many Rectangles

For a rhythm game with potentially hundreds of falling note blocks:

**Use `_draw()` when:**
- You have 50+ similar visual elements (falling notes).
- The elements are simple shapes (rectangles, lines).
- You need maximum rendering performance.

**Use scene nodes (ColorRect, Sprite2D) when:**
- You have fewer than ~30 elements.
- Elements need individual collision, input handling, or animation.
- You need Inspector-editable properties.

```gdscript
# Single node draws ALL visible notes — much faster than 200 ColorRect nodes
extends Node2D

var _visible_notes: Array[NoteData] = []

func _draw() -> void:
	for note in _visible_notes:
		var rect := Rect2(note.x, note.y, note.width, note.height)
		draw_rect(rect, note.color)
		# Draw fingering number
		draw_string(
			_font, Vector2(note.x + 4, note.y + 16),
			str(note.finger), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 14, Color.WHITE
		)

func _process(delta: float) -> void:
	# Update positions
	for note in _visible_notes:
		note.y += _scroll_speed * delta
	# Only redraw when something changed
	queue_redraw()
```

**The `_draw()` function is called once and cached.** Subsequent calls only happen when you explicitly call `queue_redraw()`. This means a single node drawing 200 rectangles produces far fewer draw calls than 200 separate nodes.

### 3.5 Node Count Guidelines

- **Under 1,000 nodes**: No concern.
- **1,000-5,000 nodes**: Monitor performance, disable processing on inactive nodes.
- **5,000+ nodes**: Redesign. Use `_draw()`, object pooling, or MultiMeshInstance2D.

---

## 4. Input Handling Best Practices

### 4.1 Event-Driven vs Polling

| Approach | Method | When to Use |
|----------|--------|-------------|
| Event-driven | `_input(event)`, `_unhandled_input(event)` | Discrete actions: jump, pause, note hit |
| Polling | `Input.is_action_pressed()` in `_process()` | Continuous actions: holding, scrolling |

For a rhythm game, **event-driven is primary** — note hits are discrete events.

```gdscript
# Event-driven for discrete input (preferred for rhythm games)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"hit_note"):
		_evaluate_hit()
		get_viewport().set_input_as_handled()
```

### 4.2 InputMap

Always use InputMap actions, never hardcode keys:

```gdscript
# GOOD: Uses action name (remappable)
if event.is_action_pressed(&"pause"):
	_toggle_pause()

# BAD: Hardcoded key
if event is InputEventKey and event.keycode == KEY_ESCAPE:
	_toggle_pause()
```

Use `&"string_name"` syntax (StringName) for action names — it's a pointer comparison instead of string comparison.

### 4.3 MIDI Input Handling

Godot provides `InputEventMIDI` natively. Handle in `_input()`:

```gdscript
func _input(event: InputEvent) -> void:
	if event is InputEventMIDI:
		match event.message:
			MIDI_MESSAGE_NOTE_ON:
				if event.velocity > 0:
					Events.midi_note_on.emit(event.pitch, event.velocity)
				else:
					Events.midi_note_off.emit(event.pitch)
			MIDI_MESSAGE_NOTE_OFF:
				Events.midi_note_off.emit(event.pitch)
```

### 4.4 Input Buffering for Rhythm Games

Store inputs for a short window so near-misses still register:

```gdscript
const BUFFER_WINDOW := 0.1  # seconds

var _buffered_inputs: Array[Dictionary] = []

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMIDI and event.message == MIDI_MESSAGE_NOTE_ON:
		_buffered_inputs.append({
			"pitch": event.pitch,
			"time": _get_audio_time(),
			"velocity": event.velocity,
		})

func _process(_delta: float) -> void:
	# Expire old buffered inputs
	var now := _get_audio_time()
	_buffered_inputs = _buffered_inputs.filter(
		func(input: Dictionary) -> bool:
			return now - input["time"] < BUFFER_WINDOW
	)
```

---

## 5. Resource Management

### 5.1 `preload()` vs `load()`

| | `preload()` | `load()` |
|---|---|---|
| **When** | Script parse time (startup) | Runtime |
| **Path** | Must be string literal | Can be dynamic variable |
| **Caching** | Loaded once, cached | Cached by path automatically |
| **Use for** | Scenes, textures, fonts you always need | Dynamic/conditional resources |
| **Blocks** | Startup (brief) | Main thread when called |

```gdscript
# preload: known at compile time, always needed
const NoteScene := preload("res://scenes/game/falling_note.tscn")
const HitSound := preload("res://assets/audio/hit.ogg")

# load: dynamic path, conditionally needed
func load_song(path: String) -> SongData:
	return load(path) as SongData
```

**Rules:**
- `preload()` requires a **string literal** path. You cannot use variables.
- Godot caches `load()` results by path — calling `load("res://foo.tscn")` twice returns the same object.
- For heavy resources (large audio files, textures), use `ResourceLoader.load_threaded_request()` for background loading.
- Never `preload()` resources that are only needed in rare scenarios — it inflates startup time.

### 5.2 Custom Resource Classes

Use `Resource` subclasses for data objects (song metadata, note charts, settings):

```gdscript
# song_data.gd
class_name SongData
extends Resource

@export var title: String
@export var artist: String
@export var bpm: float
@export var notes: Array[NoteEvent]
@export var difficulty: int
```

**Why Resource over Dictionary:**
- Type-safe properties with autocomplete.
- Saveable/loadable with `ResourceSaver` / `ResourceLoader`.
- Editable in the Inspector when `@export`-ed.
- Sharable by reference (multiple nodes can reference the same Resource).

### 5.3 Resource Caching

```gdscript
# Godot caches automatically by path:
var a := load("res://song.tres")
var b := load("res://song.tres")
assert(a == b)  # Same object, no duplicate load

# For programmatic resources (not from disk), cache manually:
var _cache: Dictionary = {}

func get_note_texture(color: Color) -> Texture2D:
	var key := color.to_html()
	if key not in _cache:
		_cache[key] = _generate_texture(color)
	return _cache[key]
```

---

## 6. State Management Patterns

### 6.1 Simple Enum State Machine

For straightforward state logic (game flow, UI screens):

```gdscript
enum GameState { LOADING, COUNTDOWN, PLAYING, PAUSED, RESULTS }

var _state: GameState = GameState.LOADING:
	set(new_state):
		var old_state := _state
		_state = new_state
		_on_state_changed(old_state, new_state)

func _on_state_changed(old: GameState, new: GameState) -> void:
	match new:
		GameState.COUNTDOWN:
			$CountdownTimer.start()
		GameState.PLAYING:
			$AudioStreamPlayer.play()
		GameState.PAUSED:
			get_tree().paused = true
		GameState.RESULTS:
			_show_results_screen()
```

**When to use:** Fewer than 5-6 states, simple transition logic, no per-state `_process()`.

### 6.2 Node-Based State Machine

For complex entities with per-state processing (e.g., a player character with many behaviors):

```gdscript
# state.gd — Base class
class_name State
extends Node

signal finished(next_state_path: String, data: Dictionary)

func enter(_previous_state: String, _data := {}) -> void:
	pass

func exit() -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
```

```gdscript
# state_machine.gd
class_name StateMachine
extends Node

@export var initial_state: State

@onready var state: State = initial_state if initial_state else get_child(0)

func _ready() -> void:
	for state_node: State in find_children("*", "State"):
		state_node.finished.connect(_transition)
	await owner.ready
	state.enter("")

func _unhandled_input(event: InputEvent) -> void:
	state.handle_input(event)

func _process(delta: float) -> void:
	state.update(delta)

func _physics_process(delta: float) -> void:
	state.physics_update(delta)

func _transition(target_path: String, data := {}) -> void:
	if not has_node(target_path):
		push_error("%s: invalid state path '%s'" % [owner.name, target_path])
		return
	var previous := state.name
	state.exit()
	state = get_node(target_path)
	state.enter(previous, data)
```

**When to use:** 6+ states, each with its own `_process()` logic, states need enter/exit behavior, states are reusable across entities.

---

## 7. Testing in Godot 4

### 7.1 GUT (Godot Unit Test)

[GUT](https://github.com/bitwes/Gut) is the most mature testing framework. Version 9.x supports Godot 4.x.

**Installation:** Godot Asset Library, search "GUT".

```gdscript
# test/test_scoring.gd
extends GutTest

func test_perfect_timing() -> void:
	var note := FallingNote.new()
	var judgment := note.hit(0.01)  # 10ms offset
	assert_eq(judgment, FallingNote.Judgment.PERFECT)

func test_miss_timing() -> void:
	var note := FallingNote.new()
	var judgment := note.hit(0.2)   # 200ms offset
	assert_eq(judgment, FallingNote.Judgment.MISS)
```

**Features:**
- `assert_eq`, `assert_ne`, `assert_gt`, `assert_lt`, `assert_between`
- `assert_signal_emitted`, `assert_signal_not_emitted`
- `watch_signals(object)` to track signal emissions
- `double()` for mocking/stubbing
- Inner test classes for grouping
- JUnit XML output for CI
- VSCode extension (`gut-extension`)

### 7.2 gdUnit4

[gdUnit4](https://github.com/MikeSchulze/gdUnit4) is a newer alternative with some additional features:

- Built-in scene runner for integration testing
- Parameterized tests
- Embedded test inspector in the Godot editor
- Supports both GDScript and C#

### 7.3 Testing Strategy for This Project

- **Unit test** scoring logic, timing windows, note parsing — pure functions with no scene dependencies.
- **Integration test** with gdUnit4's scene runner for gameplay flow (song load -> notes spawn -> input -> scoring).
- **Keep game logic separable from rendering.** If your scoring function needs a Node2D to test, your architecture is wrong.

---

## 8. Common GDScript Anti-Patterns

### 8.1 Uncached Node Lookups in Hot Paths

```gdscript
# BAD: Tree traversal 60 times per second
func _process(delta: float) -> void:
	$Sprite2D.rotation += delta
	get_node("UI/ScoreLabel").text = str(score)

# GOOD: Cache with @onready
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _score_label: Label = $UI/ScoreLabel

func _process(delta: float) -> void:
	_sprite.rotation += delta
	_score_label.text = str(score)
```

### 8.2 Fragile Node Paths

```gdscript
# BAD: Breaks when you restructure the scene tree
get_node("../../World/Enemies/Boss")
get_parent().get_parent().get_node("SomeNode")

# GOOD: Use @export to inject from Inspector
@export var boss: Node2D

# GOOD: Use groups for loose coupling
get_tree().get_nodes_in_group("enemies")
get_tree().call_group("enemies", "take_damage", 10)
```

### 8.3 Signals Going the Wrong Direction

```gdscript
# BAD: Child references parent
func _ready() -> void:
	get_parent().score += 100  # child should not know about parent

# GOOD: Child emits signal, parent listens
signal scored(points: int)

func _on_hit() -> void:
	scored.emit(100)
```

### 8.4 Missing Delta Multiplication

```gdscript
# BAD: Frame-rate dependent movement
position.x += 5  # 300px/s at 60fps, 500px/s at 100fps

# GOOD: Frame-rate independent
position.x += speed * delta
```

### 8.5 God Scripts

If a script is doing movement, input, scoring, audio, and animation — it's doing too much. Split into child nodes with focused scripts.

### 8.6 Reading `@export` in `_init()`

```gdscript
# BAD: @export values aren't set yet in _init()
func _init() -> void:
	health = max_health  # max_health is still default value

# GOOD: Read @export values in _ready()
func _ready() -> void:
	health = max_health  # Now it has the Inspector value
```

### 8.7 String Action Names Without StringName

```gdscript
# BAD: String comparison every frame
Input.is_action_pressed("jump")

# GOOD: StringName uses pointer comparison
Input.is_action_pressed(&"jump")
```

### 8.8 Autoload Abuse

```gdscript
# BAD: Everything is an autoload
# GameManager, AudioManager, UIManager, SceneManager, DataManager, ...
# You now have 8 globals and zero encapsulation

# GOOD: One Events bus, maybe one Config, everything else is scene-local
```

### 8.9 Type-Unsafe Node Access

```gdscript
# BAD: No type info, no autocomplete
var player = get_node("Player")
player.health -= 10  # Editor can't verify this property exists

# GOOD: Typed access
var player := get_node("Player") as Player
player.health -= 10  # Full autocomplete, compile-time checking

# ALSO GOOD: @export
@export var player: Player
```

### 8.10 Using `is_instance_valid()` Incorrectly

```gdscript
# BAD: Accessing a potentially freed node without checking
_target.position  # Crashes if _target was queue_free'd

# GOOD: Guard with validity check
if is_instance_valid(_target):
	_target.position
```

---

## 9. 2D Rendering Optimization

### 9.1 Draw Call Consolidation

Every CanvasItem (Node2D, Control) is a separate draw call. Minimize node count for rendered objects.

```gdscript
# BAD: 200 ColorRect nodes = 200 draw calls
for i in 200:
	var rect := ColorRect.new()
	add_child(rect)

# GOOD: 1 node with _draw() = far fewer draw calls
func _draw() -> void:
	for note in visible_notes:
		draw_rect(note.rect, note.color)
```

### 9.2 `queue_redraw()` Discipline

`_draw()` is called once and cached. Only call `queue_redraw()` when visual state actually changed:

```gdscript
# BAD: Redrawing every frame unconditionally
func _process(_delta: float) -> void:
	queue_redraw()  # Even if nothing changed

# GOOD: Redraw only when state changes
var scroll_speed: float:
	set(value):
		if scroll_speed != value:
			scroll_speed = value
			queue_redraw()
```

For a rhythm game where notes constantly scroll, you will call `queue_redraw()` every frame in `_process()` — that's acceptable because the visual state genuinely changes every frame. But for static UI elements, avoid it.

### 9.3 CanvasGroup

`CanvasGroup` merges all children into a single draw operation. Use it when:
- You have a group of nodes that need a shared shader effect (e.g., fading out a group).
- You want to apply opacity to a group without each child blending individually.

```
CanvasGroup (opacity = 0.5)  # All children render as one unit at 50% opacity
  |- Sprite2D
  |- Label
  |- ColorRect
```

### 9.4 Minimize Overdraw

- Avoid overlapping transparent nodes. Each layer of transparency is a separate blend operation.
- Use `CanvasItem.visible = false` (or `hide()`) instead of setting alpha to 0.
- For off-screen nodes, `visible = false` skips rendering entirely.
- Godot's Compatibility renderer (OpenGL) supports 2D batching for draw calls with the same texture/material. The Vulkan renderers (Forward+, Mobile) do not batch 2D yet.

### 9.5 Rendering Strategy for This Project

Since we're building a rhythm game with many falling rectangles:

1. **Use a single `_draw()` node** for all falling notes. One node, one `_draw()` call, hundreds of `draw_rect()` primitives.
2. **Use scene nodes** for the static keyboard display, UI elements, and anything that needs interaction.
3. **Profile** with the Godot profiler (Debugger > Profiler) before optimizing further.

---

## 10. Godot 4 Specific Features

### 10.1 Type Hints — Use Them Everywhere

Static typing in GDScript generates faster bytecode (benchmarked at 28-59% speedup depending on operation) and catches errors at parse time.

```gdscript
# Explicit type
var health: int = 100
var velocity: Vector2 = Vector2.ZERO

# Inferred type (use when type is obvious from right side)
var speed := 200.0              # float
var direction := Vector2.UP     # Vector2
var notes := [] as Array[NoteData]  # Typed array

# Function signatures — always type parameters and return
func calculate_score(judgment: Judgment, combo: int) -> int:
	return BASE_POINTS[judgment] * combo

# Return void explicitly
func reset() -> void:
	score = 0
	combo = 0
```

**Rule: every variable, parameter, and return type must have a type hint.** Enable these editor warnings to enforce it:
- `UNTYPED_DECLARATION`
- `UNSAFE_PROPERTY_ACCESS`
- `UNSAFE_CAST`

### 10.2 `@export` Annotations

```gdscript
# Basic exports
@export var speed: float = 200.0
@export var note_color: Color = Color.CYAN
@export var note_scene: PackedScene

# Organized exports (show in Inspector groups)
@export_category("Gameplay")

@export_group("Timing")
@export var perfect_window: float = 0.033
@export var great_window: float = 0.066

@export_subgroup("Advanced")
@export var input_offset_ms: float = 0.0

# Range constraints
@export_range(0.0, 1000.0, 10.0) var scroll_speed: float = 400.0

# Enums
@export var difficulty: Difficulty = Difficulty.NORMAL

# File paths
@export_file("*.mid", "*.musicxml") var song_path: String

# Node references (safer than $NodePath)
@export var score_label: Label
@export var hit_line: Node2D
```

### 10.3 `@onready`

Variables initialized just before `_ready()` runs. Use for node references:

```gdscript
# Safe: explicit type with cast
@onready var _sprite := $Sprite2D as Sprite2D

# Also safe: explicit type annotation
@onready var _label: Label = $FingeringLabel

# UNSAFE: compiler infers Node, not the actual type
@onready var _sprite := $Sprite2D  # Type is Node, no Sprite2D autocomplete
```

**Rule:** Always cast or annotate `@onready` variables with their specific type.

### 10.4 `class_name` Registration

```gdscript
class_name NoteRenderer
extends Node2D
```

**What it does:**
- Registers the type globally — usable anywhere without `preload()`.
- Enables `is` type checking: `if node is NoteRenderer:`
- Provides autocomplete for the type's members.
- Shows up in the "Create New Node" dialog.

**When NOT to use:**
- One-off scripts that are only attached to a single scene node.
- Inner classes (they register automatically under their parent).
- Test scripts.

### 10.5 Typed Arrays and Dictionaries

```gdscript
# Typed arrays — catch type errors at parse time
var notes: Array[NoteData] = []
var scores: Array[int] = [100, 200, 300]

# Typed dictionaries (Godot 4.4+)
var pitch_to_finger: Dictionary[int, int] = { 60: 1, 62: 2, 64: 3 }

# Typed array as function parameter
func process_notes(active_notes: Array[NoteData]) -> void:
	for note in active_notes:
		note.update()  # Full autocomplete on NoteData
```

### 10.6 Lambdas and Callables

```gdscript
# Lambda for signal connections
button.pressed.connect(func() -> void: _start_game())

# Lambda for array operations
var active := notes.filter(func(n: NoteData) -> bool: return n.active)
var positions := notes.map(func(n: NoteData) -> float: return n.y_position)

# Callable.bind() for passing extra data
for i in buttons.size():
	buttons[i].pressed.connect(_on_button_pressed.bind(i))
```

---

## Sources

- [GDScript style guide (Godot stable docs)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Static typing in GDScript (Godot 4.4 docs)](https://docs.godotengine.org/en/4.4/tutorials/scripting/gdscript/static_typing.html)
- [Custom drawing in 2D (Godot stable docs)](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)
- [GPU optimization (Godot 4.4 docs)](https://docs.godotengine.org/en/4.4/tutorials/performance/gpu_optimization.html)
- [Idle and Physics Processing (Godot stable docs)](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)
- [Node communication - the right way (Godot 4 Recipes)](https://kidscancode.org/godot_recipes/4.x/basics/node_communication/index.html)
- [GDQuest: Finite State Machine](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
- [GDQuest: Event Bus Singleton](https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/)
- [GDScript Best Practices (SyntaxCache)](https://www.syntaxcache.com/gdscript/best-practices)
- [GUT - Godot Unit Test](https://github.com/bitwes/Gut)
- [gdUnit4](https://github.com/MikeSchulze/gdUnit4)
- [Godot Input Handling (DeepWiki)](https://deepwiki.com/godotengine/godot-docs/6.2-input-handling-system)
- [Godot Object Pooling Guide](https://uhiyama-lab.com/en/notes/godot/godot-object-pooling-basics/)
