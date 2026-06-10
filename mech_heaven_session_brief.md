# Mech Heaven — Claude Code Session Brief

## Context

You are building a **Vampire Survivors-style bullet heaven autobattler** in **Godot 4.x (GDScript)** with a MechWarrior / BattleTech Inner Sphere theme. The GDAI MCP plugin is active — use it for verify loops after each significant implementation step (create scene, add script, run scene to check for errors).

This is a **Proof of Concept** build. Scope is constrained. Do not add features not listed here. Do not gold-plate. Get it running.

---

## Project name

`mech_heaven`

---

## Architecture overview

Four layers:

1. **Meta layer** — persists between runs (save file, credits, unlocked mechs, mission select)
2. **Run layer** — initialized on mission start, discarded on end (mech instance, weapon loadout, XP/level, timer)
3. **Core loop** — real-time top-down arena (player mech, autofire weapons, enemy spawner, projectiles, level-up offers)
4. **Data layer** — Godot `.tres` resource files (MechDef, WeaponDef, EnemyDef, MissionDef) — **all game data lives here, zero hardcoding**

---

## File structure

```
mech_heaven/
├── resources/
│   ├── mechs/
│   ├── weapons/
│   ├── enemies/
│   └── missions/
├── scenes/
│   ├── ui/
│   ├── game/
│   └── fx/
├── scripts/
│   ├── autoloads/
│   └── components/
└── assets/
    ├── sprites/
    └── audio/
```

---

## Custom Resource definitions

Create these as standalone GDScript class files first. They are the foundation everything else loads from.

### `MechDef.gd`
```gdscript
class_name MechDef extends Resource

@export var mech_name: String = ""
@export var weight_class: String = ""        # "Light" / "Medium" / "Heavy" / "Assault"
@export var max_speed: float = 80.0
@export var max_armor: float = 100.0
@export var heat_capacity: float = 30.0      # cosmetic bar only in PoC
@export var starting_weapons: Array[WeaponDef] = []
@export var unlock_cost: int = 0             # 0 = starter (Jenner)
@export var sprite: Texture2D
```

### `WeaponDef.gd`
```gdscript
class_name WeaponDef extends Resource

@export var weapon_name: String = ""
@export var weapon_type: String = ""         # "autocannon" / "laser" / "missile"
@export var manufacturer: String = "Standard"
@export var tier: int = 1                    # 1-5
@export var damage: float = 10.0
@export var range: float = 300.0
@export var cooldown: float = 2.0
@export var projectile_speed: float = 400.0
@export var aoe_radius: float = 0.0          # 0 = no AoE
@export var projectile_scene: PackedScene
@export var icon: Texture2D
```

### `EnemyDef.gd`
```gdscript
class_name EnemyDef extends Resource

@export var enemy_name: String = ""
@export var archetype: String = ""           # "scout" / "brawler" / "artillery" / "boss"
@export var base_armor: float = 50.0
@export var base_speed: float = 60.0
@export var base_weapons: Array[WeaponDef] = []
@export var xp_value: int = 10
@export var credits_value: int = 0           # small bonus credits on kill
@export var sprite: Texture2D
```

### `MissionDef.gd`
```gdscript
class_name MissionDef extends Resource

@export var mission_name: String = ""
@export var duration_seconds: float = 300.0
@export var base_difficulty: int = 1         # 1-3, sets enemy stat floor multiplier
@export var credit_reward: int = 300
@export var bonus_wave_reward: int = 150
@export var wave_schedule: Array[Dictionary] = []
# wave_schedule entry format:
# { "time": 30.0, "archetype": "scout", "count": 2, "tier_mult": 1.0 }
```

---

## Autoloads

Register both in Project > Autoloads before any scene work.

### `GameState.gd`
Tracks all run-scoped state. Reset on mission start.

```gdscript
extends Node

# Run state
var current_mech: MechDef = null
var active_weapons: Array[WeaponDef] = []
var current_xp: int = 0
var current_level: int = 1
var mission_timer: float = 0.0
var is_bonus_wave: bool = false

# XP thresholds per level (expandable array)
var xp_thresholds: Array[int] = [100, 250, 450, 700, 1000, 1400, 1900, 2500]

signal level_up(new_level: int)
signal mission_complete(credits_earned: int)
signal player_died

func reset_run(mech: MechDef) -> void:
    current_mech = mech
    active_weapons = mech.starting_weapons.duplicate()
    current_xp = 0
    current_level = 1
    mission_timer = 0.0
    is_bonus_wave = false

func add_xp(amount: int) -> void:
    current_xp += amount
    var threshold_index = current_level - 1
    if threshold_index < xp_thresholds.size() and current_xp >= xp_thresholds[threshold_index]:
        current_level += 1
        emit_signal("level_up", current_level)

func add_weapon(weapon: WeaponDef) -> void:
    # Check if weapon of same type+manufacturer already exists → upgrade tier
    for i in active_weapons.size():
        if active_weapons[i].weapon_name == weapon.weapon_name and \
           active_weapons[i].manufacturer == weapon.manufacturer:
            active_weapons[i] = weapon  # replace with higher-tier version
            return
    active_weapons.append(weapon)
```

### `SaveManager.gd`
Single pilot profile. Extend to multi-profile later by wrapping in a pilot dict.

```gdscript
extends Node

const SAVE_PATH = "user://save.cfg"

var credits: int = 0
var unlocked_mechs: Array[String] = ["Jenner JR7-D"]  # mech_name strings

func save() -> void:
    var config = ConfigFile.new()
    config.set_value("pilot", "credits", credits)
    config.set_value("pilot", "unlocked_mechs", unlocked_mechs)
    config.save(SAVE_PATH)

func load_save() -> void:
    var config = ConfigFile.new()
    if config.load(SAVE_PATH) != OK:
        save()  # first run — write defaults
        return
    credits = config.get_value("pilot", "credits", 0)
    unlocked_mechs = config.get_value("pilot", "unlocked_mechs", ["Jenner JR7-D"])

func add_credits(amount: int) -> void:
    credits += amount
    save()

func spend_credits(amount: int) -> bool:
    if credits < amount:
        return false
    credits -= amount
    save()
    return true

func unlock_mech(mech_name: String) -> void:
    if mech_name not in unlocked_mechs:
        unlocked_mechs.append(mech_name)
        save()

func is_unlocked(mech_name: String) -> bool:
    return mech_name in unlocked_mechs
```

---

## Core scenes

### Arena scene (`scenes/game/Arena.tscn`)

Node structure:
```
Arena (Node2D)
├── TileMapLayer (flat ground, simple tiling texture — placeholder color is fine)
├── PlayerSpawn (Marker2D, center of map)
├── EnemySpawner (Node2D + EnemySpawner.gd)
├── ProjectileContainer (Node2D — all projectiles instantiate here)
├── Camera2D (follows player, limit set large enough to never hit edge)
└── HUD (CanvasLayer — see HUD section)
```

Arena is infinite — no borders. Enemies spawn from a circle of radius 800 around the player's current position.

### PlayerMech scene (`scenes/game/PlayerMech.tscn`)

```
PlayerMech (CharacterBody2D + PlayerMech.gd)
├── Sprite2D (top-down mech silhouette — use ColorRect placeholder if no art)
├── CollisionShape2D (capsule or circle)
├── HealthComponent (Node + HealthComponent.gd)
└── WeaponMount (Node2D — WeaponComponent children added here at runtime)
```

**`PlayerMech.gd`:**
- On `_ready`: read `GameState.current_mech`, set speed, instantiate one `WeaponComponent` per weapon in `GameState.active_weapons`
- On `_physics_process`: move away from nearest enemy cluster (auto-movement) — simple: find centroid of all enemies within 300px, move opposite direction. If no enemies nearby, orbit slowly
- Listen for `GameState.level_up` signal → pause and show level-up offer

**Movement note:** Player movement is *automatic* (this is a bullet heaven, not a twin-stick shooter). The mech navigates to avoid dying, not from player input. Keep the avoidance logic simple for PoC — pure vector repulsion is fine.

### WeaponComponent (`scripts/components/WeaponComponent.gd`)

Attach one per weapon. Manages its own cooldown independently.

```gdscript
class_name WeaponComponent extends Node

var weapon_def: WeaponDef = null
var cooldown_timer: float = 0.0
var projectile_container: Node2D  # set by PlayerMech on instantiation

func setup(def: WeaponDef, container: Node2D) -> void:
    weapon_def = def
    projectile_container = container
    cooldown_timer = 0.0

func _process(delta: float) -> void:
    cooldown_timer -= delta
    if cooldown_timer <= 0.0:
        _try_fire()

func _try_fire() -> void:
    var target = _find_nearest_enemy()
    if target == null:
        return
    var dist = global_position.distance_to(target.global_position)
    if dist > weapon_def.range:
        return
    _spawn_projectile(target)
    cooldown_timer = weapon_def.cooldown

func _find_nearest_enemy() -> Node2D:
    # Get all nodes in "enemies" group, return closest
    var enemies = get_tree().get_nodes_in_group("enemies")
    var nearest = null
    var nearest_dist = INF
    for e in enemies:
        var d = global_position.distance_to(e.global_position)
        if d < nearest_dist:
            nearest_dist = d
            nearest = e
    return nearest

func _spawn_projectile(target: Node2D) -> void:
    if weapon_def.projectile_scene == null:
        return
    var proj = weapon_def.projectile_scene.instantiate()
    projectile_container.add_child(proj)
    proj.global_position = global_position
    proj.setup(weapon_def, target)
```

### Projectile scene (`scenes/game/Projectile.tscn`)

```
Projectile (Area2D + Projectile.gd)
├── Sprite2D (small colored rect placeholder per weapon type)
└── CollisionShape2D (small circle)
```

**`Projectile.gd`:**
```gdscript
extends Area2D

var damage: float = 0.0
var speed: float = 400.0
var aoe_radius: float = 0.0
var target: Node2D = null
var weapon_type: String = ""
var direction: Vector2 = Vector2.ZERO

func setup(def: WeaponDef, target_node: Node2D) -> void:
    damage = def.damage
    speed = def.projectile_speed
    aoe_radius = def.aoe_radius
    weapon_type = def.weapon_type
    target = target_node
    # Direction set at fire time — missiles track, others don't
    if weapon_type != "missile":
        direction = global_position.direction_to(target_node.global_position)

func _physics_process(delta: float) -> void:
    match weapon_type:
        "laser", "autocannon":
            position += direction * speed * delta
        "missile":
            if is_instance_valid(target):
                direction = global_position.direction_to(target.global_position)
            position += direction * speed * delta
    # Cull if out of range (2000px from origin — adjust as needed)
    if position.length() > 2000.0:
        queue_free()

func _on_area_entered(area: Area2D) -> void:
    if area.is_in_group("enemies"):
        if aoe_radius > 0.0:
            _apply_aoe()
        else:
            area.take_damage(damage)
        queue_free()

func _apply_aoe() -> void:
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if global_position.distance_to(enemy.global_position) <= aoe_radius:
            enemy.take_damage(damage)
```

### EnemyMech scene (`scenes/game/EnemyMech.tscn`)

```
EnemyMech (CharacterBody2D + EnemyMech.gd)
├── Sprite2D
├── CollisionShape2D
└── HealthBar (ProgressBar — small, above sprite)
```

**`EnemyMech.gd`:**
- Added to group `"enemies"` on ready
- Moves toward player at `base_speed * difficulty_mult`
- Has `take_damage(amount)` method
- On death: emit `xp_value` to `GameState.add_xp()`, drop credits, queue_free, spawn ExplosionFX

### EnemySpawner (`scripts/components/EnemySpawner.gd`)

- Reads `MissionDef.wave_schedule` passed in at mission start
- On each wave entry's `time`, spawns `count` enemies of `archetype` with stats multiplied by `tier_mult * base_difficulty`
- Additional in-mission scaling: every 60 seconds after wave 1, all new enemies get +15% speed and armor
- Spawns from random point on a circle of radius 800 around the player

---

## Level-up offer system

On `GameState.level_up` signal:
1. Pause game (`get_tree().paused = true`)
2. Build offer pool: all `WeaponDef` resources from `resources/weapons/` folder
   - Filter to weapons the mech can theoretically use (for PoC: all weapons are available — add per-mech filtering later)
   - Filter to tier ≤ current_level + 1, minimum tier 1
   - Prefer weapons not currently in loadout (weight × 3 vs weight × 1 for duplicates)
   - Duplicates of owned weapons show as "Upgrade to Tier X" if a higher tier version exists in resources
3. Show 3 offer cards (LevelUpOffer UI scene)
4. On pick: call `GameState.add_weapon(chosen_def)`, rebuild WeaponComponent array on PlayerMech, unpause

---

## HUD

Minimal for PoC:
- Top left: armor bar (red), XP bar (green)
- Top right: mission timer (MM:SS)
- Bottom: weapon icons row — one per active weapon, cooldown shown as fill overlay draining down

---

## Starting data — `.tres` files to create

### Mechs (create all 5, only Jenner unlocked)

| mech_name | weight_class | max_speed | max_armor | unlock_cost |
|---|---|---|---|---|
| Jenner JR7-D | Light | 110 | 60 | 0 |
| Hunchback HBK-4G | Medium | 60 | 160 | 400 |
| Catapult CPLT-C1 | Medium | 65 | 120 | 600 |
| Warhammer WHM-6R | Heavy | 55 | 180 | 900 |
| Atlas AS7-D | Assault | 35 | 320 | 1800 |

### Weapons — Standard Tier 1 (create all 6)

| weapon_name | weapon_type | damage | range | cooldown | projectile_speed | aoe_radius |
|---|---|---|---|---|---|---|
| AC/5 | autocannon | 8 | 400 | 1.2 | 600 | 0 |
| AC/20 | autocannon | 35 | 200 | 3.5 | 500 | 0 |
| Medium Laser | laser | 12 | 300 | 1.8 | 800 | 0 |
| PPC | laser | 28 | 500 | 4.0 | 700 | 0 |
| SRM 4 | missile | 16 | 250 | 2.0 | 350 | 40 |
| LRM 15 | missile | 22 | 550 | 3.0 | 300 | 30 |

### Mech starting loadouts
- **Jenner**: SRM 4 × 2, Medium Laser × 2
- **Hunchback**: AC/20, Medium Laser × 2
- **Catapult**: LRM 15 × 2, Medium Laser × 2
- **Warhammer**: PPC × 2, Medium Laser × 2, SRM 4
- **Atlas**: AC/20, LRM 15, SRM 4, Medium Laser × 4

### Enemies — create 4 EnemyDef resources

| enemy_name | archetype | base_armor | base_speed | xp_value |
|---|---|---|---|---|
| Locust LCT-1V | scout | 20 | 120 | 8 |
| Centurion CN9-A | brawler | 80 | 55 | 25 |
| Catapult CPLT-C1 (enemy) | artillery | 60 | 40 | 30 |
| Atlas AS7-D (enemy) | boss | 300 | 25 | 150 |

### Missions — create 3 MissionDef resources

**Mission 1 — Recon in Force**
- duration: 180s, base_difficulty: 1, credit_reward: 250, bonus_wave_reward: 100
- Wave schedule: scouts at 0s (1), 30s (2), 60s (3), 90s (4 scouts + 1 brawler), 120s (boss)

**Mission 2 — Defensive Action**
- duration: 300s, base_difficulty: 2, credit_reward: 500, bonus_wave_reward: 200
- Heavier mix from the start, brawlers earlier, first artillery at 90s

**Mission 3 — Maximum Attrition**
- duration: 420s, base_difficulty: 3, credit_reward: 900, bonus_wave_reward: 350
- Relentless escalation, multiple bosses, this is the ridonk run

---

## Implementation order

Work through these steps in order. After each numbered step, use the GDAI MCP verify loop to confirm no errors before proceeding.

1. Create project structure (folders as specified)
2. Create the 4 resource class scripts (`MechDef.gd`, `WeaponDef.gd`, `EnemyDef.gd`, `MissionDef.gd`)
3. Create `GameState.gd` and `SaveManager.gd`, register as autoloads
4. Create all `.tres` resource files (5 mechs, 6 weapons, 4 enemies, 3 missions) — use placeholder `null` for sprites and projectile scenes for now
5. Create `Projectile.tscn` + `Projectile.gd` (use a simple ColorRect as placeholder sprite)
6. Create `EnemyMech.tscn` + `EnemyMech.gd`
7. Create `WeaponComponent.gd`
8. Create `Arena.tscn` (flat ground, spawner node, projectile container, camera)
9. Create `PlayerMech.tscn` + `PlayerMech.gd` — movement only first, verify it runs
10. Wire `WeaponComponent` into `PlayerMech`, test one weapon (Medium Laser) firing at a manually placed enemy
11. Create `EnemySpawner.gd`, hook into Arena, test spawning scouts
12. Implement XP gain on enemy death + `GameState.add_xp()`
13. Create `LevelUpOffer` UI scene (3 card buttons, pause/unpause)
14. Create `HUD` (armor bar, XP bar, timer, weapon icons)
15. Create mission start/end flow — mission select feeds MissionDef into Arena, end screen shows credits
16. Create `MechSelect` scene — shows roster, locked/unlocked state, credits display
17. Create `MainMenu` scene — connects to MechSelect
18. Hook `SaveManager` into credits flow end-to-end
19. Smoke test full loop: main menu → mech select → mission select → arena → death/win → credits → back to menu
20. Polish pass: placeholder sprites replaced with colored shapes per weight class/weapon type if no real art available

---

## Important constraints

- **No terrain, obstacles, or pathfinding** — flat arena only for PoC
- **No player input for movement** — fully automatic
- **No sound** — placeholder silence is fine
- **No particle effects** — simple ColorRect flash on hit is sufficient
- **Manufacturer variants are future content** — `manufacturer = "Standard"` on all weapon `.tres` files for now, architecture already supports them
- **Campaign mode** is future scope — `MissionDef` array is the hook, don't implement the wrapper
- **Multi-profile saves** are future scope — single pilot only, but `SaveManager` structure supports it

---

## Notes on expandability

- **New mech**: create a new `MechDef.tres`, assign starting weapons, done
- **New weapon / manufacturer variant**: create a new `WeaponDef.tres`, it automatically enters the level-up offer pool
- **New enemy**: create a new `EnemyDef.tres`, reference it in wave schedules
- **New mission**: create a new `MissionDef.tres`, it appears in mission select
- **Weapon tiers 2-5**: duplicate existing `WeaponDef.tres`, increment tier, scale stats — naming convention: `medium_laser_t2.tres`, `medium_laser_t2_defiance.tres` etc.

Zero code changes required for any of the above. That's the whole point of the data layer.
