# BSR Feature Spec — Manufacturer, Trait & Corp Rep Systems
Generated: 2026-06-22. Source: design doc v0.1 conversation.

---

## OPEN DECISIONS — RESOLVED (2026-06-22)

**OD-1: Trait inheritance — LOCKED**
Tier number = max traits on the resulting weapon.
- 4x T1 → T2: player picks **up to 2 traits** from the combined pool of all source weapons' traits
- 4x T2 → T3: player picks **up to 3 traits** from the combined pool of all source weapons' traits
- Traits must come from weapons in the scrap pool being consumed — no external pool
- Skipping is allowed (choose fewer than the max — intentional design, player may not want certain traits)
- Duplicate traits from different sources are shown once in the picker

**OD-2: Traits vs mods — LOCKED**
Same concept. A "trait" is a manufacturer's signature modification to that weapon type — e.g. Corp X lasers always have slightly more range and slightly longer cooldown. Terms "trait" and "mod" are interchangeable in design conversation. Implementation uses `traits: Array[String]` on WeaponDef. Modifier magnitudes: meaningful but not destabilizing (~±10–15% on one stat per trait).

---

## Phase 0 — Name Genericization
*~1 session. No architecture changes. Just rename resources and strings.*

IP-adjacent terms to replace before the manufacturer system adds more attachment points:

| Current | Replace with | Where |
|---------|-------------|-------|
| `AC/5`, `AC/20` | `Autocannon-5`, `Autocannon-20` | weapon .tres display names |
| `PPC` | `Particle Cannon` or `Plasma Cannon` | weapon .tres display names |
| `SRM 4` | `Short-Range Missiles` / `SRM-4` | display name |
| `LRM 15` | `Long-Range Missiles` / `LRM-15` | display name |
| `Jenner JR7-D`, `Centurion CN9-A`, etc. | Original names TBD | mech/enemy .tres |
| `Atlas AS7-D`, `Catapult CPLT-C1` | Original names TBD | enemy .tres |
| `Locust LCT-1V` | Original name TBD | enemy .tres |

**Action:** Audit `resources/` for any remaining Battletech IP strings and replace with original names. Confirm replacement names with human before committing.

---

## Phase 1 — Data Model
*~1 session. Extends existing resources, adds new ones. No UI yet.*

### 1a. Extend WeaponDef (`scripts/WeaponDef.gd`)
Add:
```gdscript
@export var manufacturer: String = ""       # corp name, "" = generic/salvage
@export var traits: Array[String] = []      # e.g. ["range_bonus", "weight_reduction"]
```
Existing weapon `.tres` files get `manufacturer = ""` and `traits = []` — fully backwards-compatible.

### 1b. New CorpDef resource (`scripts/CorpDef.gd`)
```gdscript
extends Resource
class_name CorpDef

@export var corp_name: String = ""
@export var philosophy: String = ""         # one-liner shown in UI
@export var trait_pool: Array[String] = []  # traits this corp can express
@export var availability: float = 1.0      # base weight on mission board draw
@export var price_multiplier: float = 1.0  # affects corp store pricing
@export var color: Color = Color.WHITE      # logo tint for UI
```

### 1c. TraitResolver singleton or static class (`scripts/autoloads/TraitResolver.gd`)
Maps trait String → stat delta Dictionary. Applied by `WeaponDef` or `CraftingSystem` when computing effective stats.
```gdscript
const TRAITS: Dictionary = {
    "range_bonus":        {"fire_range": 1.20},
    "cooldown_reduction": {"cooldown":   0.85},
    "weight_reduction":   {"weight":     0.80},
    "damage_bonus":       {"damage":     1.20},
    "damage_penalty":     {"damage":     0.85},
    "weight_penalty":     {"weight":     1.25},
    # etc.
}

static func apply(weapon_def: WeaponDef) -> Dictionary:
    # returns effective stats dict with all traits applied
```

### 1d. Corp data files (`resources/corps/`)
One `.tres` per corp. 10 corps:

| File | Corp | Philosophy | Traits |
|------|------|-----------|--------|
| `vantage_arms.tres` | Vantage Arms | Precision & range | range_bonus, weight_penalty, accuracy |
| `quickfire_industries.tres` | Quickfire Industries | Lightweight volume fire | cooldown_reduction, weight_reduction, damage_penalty |
| `ironforge_munitions.tres` | Ironforge Munitions | Durability & reliability | damage_bonus, weight_penalty |
| `continental_defense.tres` | Continental Defense | Budget, no frills | (no traits — but always available, lowest price_multiplier) |
| `kovacs_arms.tres` | Kovacs Arms | Ex-military, over-engineered | damage_bonus, weight_penalty, rare (low availability) |
| `helix_energy.tres` | Helix Energy Systems | Thermal efficiency | cooldown_reduction, range_bonus (energy weapons only) |
| `salvo_systems.tres` | Salvo Systems | Missiles & indirect | splash_bonus, damage_bonus (missiles only) |
| `axiom_dynamics.tres` | Axiom Dynamics | Experimental prototype | wildcard_strong_bonus + wildcard_penalty |
| `crucible_heavy.tres` | Crucible Heavy | Industrial conversion | ammo_efficiency, damage_bonus, weight_penalty |
| `redline_surplus.tres` | Redline Surplus | Black market salvage | low_cost, trait_wildcard (any corp's pool) |

**Note:** Exact trait values are placeholders — tune in playtesting. Corp names are working names; confirm with human before locking.

---

## Phase 2 — Rep Tracker
*~1 session. GameState + save system changes.*

### 2a. GameState additions (`scripts/autoloads/GameState.gd`)
```gdscript
var corp_reputation: Dictionary = {}        # corp_name (String) → rep (int)
signal rep_changed(corp: String, new_val: int)

func get_rep(corp: String) -> int:
    return corp_reputation.get(corp, 0)

func modify_rep(corp: String, delta: int) -> void:
    var old := get_rep(corp)
    corp_reputation[corp] = clamp(old + delta, -100, 100)
    if corp_reputation[corp] != old:
        rep_changed.emit(corp, corp_reputation[corp])
```

### 2b. Save/load (`scripts/autoloads/SaveManager.gd`)
Add `[reputation]` section to save.cfg. Keys = corp names, values = rep ints. Load into `GameState.corp_reputation` on game start.

### 2c. Rep mutation points (wire up later with mission results)
- Mission success for corp sponsor: `+10` rep
- Mission failure for corp sponsor: `-20` rep
- Hard-dark threshold: `<= -50` (corp removed from board pool permanently)

---

## Phase 3 — Mission Board Weighting
*~1 session. Replaces static mission list with rep-weighted draw.*

### 3a. MissionBoard logic (new `scripts/autoloads/MissionBoard.gd` or extend existing)
Draw pool:
```
base_weight = corp.availability
rep_bonus   = get_rep(corp) * 0.02   # ±2% per rep point
final_weight = max(0.0, base_weight + rep_bonus)
```
Corps at hard-dark (`rep <= -50`) get `final_weight = 0` and are excluded.

3-4 missions drawn per refresh (on game start, after each mission).
20% baseline chance any slot is corp-sponsored (increases with positive rep per corp).

### 3b. Corp-sponsored mission structure
- Corp-sponsored missions always T2/T3 difficulty
- Reward: rep gain + store access token (used in Phase 4)
- Failure: rep loss (no reward, no token)

---

## Phase 4 — Corp Store
*~1-2 sessions. New UI scene.*

### 4a. Store access token
After successful corp mission: `GameState.corp_store_access = corp_name` (String, cleared after one inter-mission cycle).

### 4b. Corp store scene (`scenes/ui/CorpStore.tscn` + `scripts/ui/CorpStore.gd`)
- Shows ~5 T1 weapons branded with that corp's manufacturer
- Each weapon has corp traits pre-applied
- Priced by `corp.price_multiplier * base_price`
- T2 store unlocks when rep >= threshold (TBD — suggest 40)
- Access token clears on leaving store

### 4c. Store entry point
Add "Corp Store" button to the between-mission hub (wherever mission select lives). Button visible and enabled only when `corp_store_access != ""`.

---

## Phase 5 — Upgrade UI with Trait Selection
*~2 sessions. Reworks MechLab upgrade flow.*

### 5a. Current state
`CraftingSystem.gd` handles 4x T1 → T2 combining. No trait selection step. No manufacturer awareness.

### 5b. Changes needed
- `CraftingSystem.combine_weapons(sources: Array[WeaponDef]) -> Array[Dictionary]`: returns the de-duplicated trait pool from all source weapons for the picker to display
- `CraftingSystem.finalize_upgrade(base_weapon: WeaponDef, chosen_traits: Array[String]) -> WeaponDef`: builds the output weapon with the chosen traits applied
- Max selectable traits = output tier (T2 → 2, T3 → 3). Player may select fewer or none.
- New UI step in MechLab: "Inherit Traits" panel — shows each available trait as a card (name + one-line effect + which source weapon it came from). Player taps to toggle selection, confirm button active at 0–max selections.
- Output weapon: `manufacturer = ""` (salvage — it's a field-built amalgam), traits = chosen array
- Trait display: trait name + one-line effect shown in weapon tooltip everywhere the weapon appears

---

## Deferred — Not blocking, design intent only

| Feature | Dependency | Notes |
|---------|-----------|-------|
| Elevation (range/LoS bonus) | Map system rework | Needs procedural map gen first |
| Water terrain (speed penalty, cooldown bonus) | Map system | Same dependency |
| Fog of war | Map + sensor equipment | Sensor stat needed on EquipmentDef |
| Torso/weapon aiming independent of body | PlayerMech.gd rewrite | Meaningful movement change — flag before touching |
| Loan mechanic | Economy system | Not yet designed at implementation level |
| Destructible buildings | Map system | Urban map type prerequisite |
| Second boss per mission | MissionDef + EnemySpawner | EnemySpawner already handles bosses, low-effort extension |
| Find-the-Thing mission type | Fog of war + sensor | Blocked on fog of war |

---

## Relationship to existing code

| Area | Existing file | Change needed |
|------|--------------|--------------|
| Weapon data | `scripts/WeaponDef.gd` | Add manufacturer + traits fields |
| Upgrade combining | `scripts/autoloads/CraftingSystem.gd` | Add trait selection step |
| Save/load | `scripts/autoloads/SaveManager.gd` | Add reputation section |
| Game state | `scripts/autoloads/GameState.gd` | Add rep dict + API |
| Mission board | Currently static in `scenes/ui/` | New dynamic draw logic |
| Mech Lab UI | `scripts/ui/MechLab.gd` | Add trait selection flow |
| New files | CorpDef.gd, TraitResolver.gd, CorpStore.gd | Create |
| New resources | `resources/corps/*.tres` | 10 corp files |
