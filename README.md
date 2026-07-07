# TunedLoop Godot SDK
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

Real-time AI difficulty balancing for Godot 4.x — your players never rage-quit again.

## What It Does

TunedLoop streams gameplay telemetry from your Godot game to cloud AI that detects frustration, boredom, mastery spikes, and difficulty cliffs. It returns real-time difficulty modifiers you can apply to enemy speed, spawn rates, rewards, health, timers, or any balancing variable you control. The SDK is free up to 1,000 monthly active users, so small teams can ship adaptive balancing before they scale.

## Quick Start

1. Copy `addons/tuned_loop/` into your Godot 4.x project.
2. Enable the plugin in `Project Settings > Plugins`.
3. Set your API key from your game startup code:
   ```gdscript
   func _ready() -> void:
       TunedLoop.api_key = "tl_live_your_api_key_here"
       TunedLoop.game_id = "your-game-id"
       TunedLoop.game_version = "1.0.0"
   ```
4. Call `track_event()` anywhere gameplay friction happens:
   ```gdscript
   TunedLoop.track_event("player_died", {"level_id": "forest_01", "time_alive": 42.8})
   ```
5. Connect the `difficulty_adjusted` signal and apply returned modifiers to your game variables.

## API Reference

### `track_event(event_type: String, data: Dictionary = {}) -> void`

Queues a gameplay event for the next batched upload. Events flush every 10 seconds, or sooner when the queue reaches the SDK batch size.

- `event_type`: Snake-case event name such as `player_died`, `level_completed`, or `enemy_killed`.
- `data`: JSON-safe dictionary of gameplay context, stats, level IDs, build version, current modifiers, or player state.

### `difficulty_adjusted(modifiers: Dictionary)`

Emitted after TunedLoop receives AI difficulty adjustments from the cloud. The payload is a dictionary of modifier names and numeric values, for example:

```gdscript
{
    "enemy_speed_multiplier": 0.9,
    "enemy_spawn_rate_multiplier": 0.8,
    "reward_drop_multiplier": 1.2
}
```

### Config Vars

Set these on the `TunedLoop` Autoload singleton before sending events:

- `api_key: String` — required API key from TunedLoop.
- `game_id: String` — optional stable game identifier; falls back to the Godot project name.
- `game_version: String` — optional version string for release-level analysis.
- `environment: String` — defaults to `production`; useful for `development`, `staging`, or playtests.
- `auto_start: bool` — defaults to `true`; starts the 10-second flush timer in `_ready()`.
- `debug_logging: bool` — defaults to `false`; keeps runtime silent unless you opt in.

## Pricing

Start at [https://tunedloop.nanocorp.app](https://tunedloop.nanocorp.app). TunedLoop is free up to 1,000 MAU, then starts at a $0.99/month base subscription. The Revenue Cap Safety Net keeps pricing capped at 5% of your game revenue so adaptive balancing never becomes a scaling tax.

## Example

```gdscript
# Example player/game controller integration for the TunedLoop Autoload singleton.
# Assumes addons/tuned_loop/tuned_loop_plugin.gd is registered as an Autoload named `TunedLoop`.
extends Node

var enemy_speed_multiplier: float = 1.0
var enemy_spawn_rate_multiplier: float = 1.0
var enemy_health_multiplier: float = 1.0
var reward_drop_multiplier: float = 1.0


func _ready() -> void:
    TunedLoop.api_key = "tl_live_your_api_key_here"
    TunedLoop.game_id = "space-rift"
    TunedLoop.game_version = "1.0.0"
    TunedLoop.difficulty_adjusted.connect(_on_difficulty_adjusted)


func _on_player_died(level_id: String, time_alive: float, enemies_killed: int) -> void:
    TunedLoop.track_event("player_died", {
        "level_id": level_id,
        "time_alive": time_alive,
        "enemies_killed": enemies_killed,
        "enemy_speed_multiplier": enemy_speed_multiplier,
    })


func _on_level_completed(level_id: String, completion_time: float, deaths: int) -> void:
    TunedLoop.track_event("level_completed", {
        "level_id": level_id,
        "completion_time": completion_time,
        "deaths": deaths,
        "spawn_rate_multiplier": enemy_spawn_rate_multiplier,
    })


func _on_enemy_killed(enemy_type: String, weapon_id: String, combo_count: int) -> void:
    TunedLoop.track_event("enemy_killed", {
        "enemy_type": enemy_type,
        "weapon_id": weapon_id,
        "combo_count": combo_count,
    })


func _on_difficulty_adjusted(modifiers: Dictionary) -> void:
    enemy_speed_multiplier = clampf(float(modifiers.get("enemy_speed_multiplier", enemy_speed_multiplier)), 0.5, 2.0)
    enemy_spawn_rate_multiplier = clampf(float(modifiers.get("enemy_spawn_rate_multiplier", enemy_spawn_rate_multiplier)), 0.4, 2.5)
    enemy_health_multiplier = clampf(float(modifiers.get("enemy_health_multiplier", enemy_health_multiplier)), 0.5, 3.0)
    reward_drop_multiplier = clampf(float(modifiers.get("reward_drop_multiplier", reward_drop_multiplier)), 0.5, 3.0)

    _apply_enemy_speed(enemy_speed_multiplier)
    _apply_spawn_rate(enemy_spawn_rate_multiplier)
    _apply_enemy_health(enemy_health_multiplier)
    _apply_reward_drops(reward_drop_multiplier)
```

See `example/example_usage.gd` for a fuller integration sketch.

## License

MIT
