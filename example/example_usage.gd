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
	# TunedLoop emits this signal after the cloud AI analyzes queued telemetry.
	# Clamp values locally so unexpected payloads never destabilize gameplay.
	enemy_speed_multiplier = clampf(float(modifiers.get("enemy_speed_multiplier", enemy_speed_multiplier)), 0.5, 2.0)
	enemy_spawn_rate_multiplier = clampf(float(modifiers.get("enemy_spawn_rate_multiplier", enemy_spawn_rate_multiplier)), 0.4, 2.5)
	enemy_health_multiplier = clampf(float(modifiers.get("enemy_health_multiplier", enemy_health_multiplier)), 0.5, 3.0)
	reward_drop_multiplier = clampf(float(modifiers.get("reward_drop_multiplier", reward_drop_multiplier)), 0.5, 3.0)

	_apply_enemy_speed(enemy_speed_multiplier)
	_apply_spawn_rate(enemy_spawn_rate_multiplier)
	_apply_enemy_health(enemy_health_multiplier)
	_apply_reward_drops(reward_drop_multiplier)


func _apply_enemy_speed(multiplier: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.speed = enemy.base_speed * multiplier


func _apply_spawn_rate(multiplier: float) -> void:
	$EnemySpawner.spawn_interval = $EnemySpawner.base_spawn_interval / multiplier


func _apply_enemy_health(multiplier: float) -> void:
	$EnemySpawner.enemy_health_multiplier = multiplier


func _apply_reward_drops(multiplier: float) -> void:
	$LootDirector.reward_drop_multiplier = multiplier
