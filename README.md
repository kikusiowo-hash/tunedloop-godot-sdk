# TunedLoop Godot SDK

Adaptive difficulty telemetry for Godot games: track gameplay events, receive difficulty modifiers, and keep sessions balanced in real time.

## Installation

1. Copy the `addons/` folder from this repository into the root of your Godot project.
2. In Godot, open **Project Settings > Plugins** and enable the TunedLoop plugin.
3. Add `TunedLoop` as an Autoload singleton so it is available from your game scripts.

## Quick Start

### Setup

In your main scene's `_ready()` method, set your API key and game ID:

```gdscript
func _ready() -> void:
    TunedLoop.api_key = "tl_live_YOUR_KEY"
    TunedLoop.game_id = "your-game-name"
```

### Track an Event

```gdscript
TunedLoop.track_event("player_died", {
    "level": current_level,
    "time_alive": survival_seconds
})
```

### Listen for Difficulty Adjustments

```gdscript
func _ready() -> void:
    TunedLoop.difficulty_adjusted.connect(_on_difficulty_adjusted)

func _on_difficulty_adjusted(modifiers: Dictionary) -> void:
    # modifiers is a Dictionary, e.g. {"enemy_speed": 1.2, "damage_multiplier": 0.8}
    enemy_speed = base_speed * modifiers.get("enemy_speed", 1.0)
```

## Full API Reference

### Properties

All properties are `@export` values and can be set in the Godot Inspector or in code.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `TunedLoop.api_key` | `String` | `""` | Your TunedLoop API key. |
| `TunedLoop.game_id` | `String` | `""` | Unique identifier for your game. |
| `TunedLoop.game_version` | `String` | `""` | Version string for your game build. |
| `TunedLoop.environment` | `String` | `"production"` | Runtime environment label. |
| `TunedLoop.auto_start` | `bool` | `true` | Starts the SDK automatically when enabled. |
| `TunedLoop.debug_logging` | `bool` | `false` | Enables console logging when set to `true`. |

### Methods

#### `TunedLoop.track_event(event_name: String, properties: Dictionary)`

Queues a gameplay event with optional metadata.

```gdscript
TunedLoop.track_event("player_died", {
    "level": current_level,
    "time_alive": survival_seconds
})
```

#### `TunedLoop.flush_now()`

Force-send queued events immediately.

```gdscript
TunedLoop.flush_now()
```

#### `TunedLoop.get_session_id()`

Returns the current session ID string.

```gdscript
var session_id := TunedLoop.get_session_id()
```

### Signals

#### `TunedLoop.difficulty_adjusted`

Emitted when TunedLoop provides updated difficulty modifiers.

```gdscript
func _ready() -> void:
    TunedLoop.difficulty_adjusted.connect(_on_difficulty_adjusted)

func _on_difficulty_adjusted(modifiers: Dictionary) -> void:
    # modifiers is a Dictionary, e.g. {"enemy_speed": 1.2, "damage_multiplier": 0.8}
    enemy_speed = base_speed * modifiers.get("enemy_speed", 1.0)
```

### Debug Logging

Enable console logging by setting `debug_logging` to `true`:

```gdscript
TunedLoop.debug_logging = true
```

## Pricing

TunedLoop pricing is available at [tunedloop.com/pricing](https://tunedloop.com/pricing).

| Plan | Price |
| --- | --- |
| Indie | $19/mo |
| Studio | $79/mo |
| Pro | $299/mo |
| Founding Member (Early Access) | $9 one-time |

## License

MIT
