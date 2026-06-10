# Code Review Findings — Mech Survivor PoC

Reviewed 2026-06-10 (all 20 scripts in `scripts/`). Issues ordered by impact.
Each item has the file/line, the problem, and a suggested fix so they can be
worked through one at a time.

---

## High priority (gameplay correctness)

### 1. Enemies can die twice — duplicate XP, credits, and explosions

**File:** `scripts/components/EnemyMech.gd:44` (`take_damage`)

`take_damage()` has no "already dead" guard (note that `HealthComponent.take_damage`
*does* have one — copy that pattern). After `_die()` calls `queue_free()`, the enemy
remains in the scene tree (and the `"enemies"` group) until end of frame. If two
projectiles hit on the same frame — very likely with an AoE blast plus a direct
hit — `_die()` runs twice: double XP, double credits, two explosion FX, and the
`defeated` signal emitted twice.

**Fix:** add a guard at the top of `take_damage`:

```gdscript
func take_damage(amount: float) -> void:
    if current_armor <= 0.0:
        return
    current_armor -= amount
    ...
```

### 2. Projectiles cull by distance from world origin, not the player

**File:** `scripts/components/Projectile.gd:44`

```gdscript
if position.length() > 2000.0:
    queue_free()
```

`position` is relative to `ProjectileContainer`, which sits at the world origin.
The player roams freely, so once the player wanders ~2000px from spawn, every
projectile spawns already "out of range" and frees itself on its first physics
frame — all weapons silently stop working.

**Fix:** track distance traveled instead, e.g. accumulate
`traveled += speed * delta` in `_physics_process` and cull when
`traveled > 2000.0`. (Or compare distance to the player.)

### 3. Level-up cards can downgrade owned weapons

**Files:** `scripts/autoloads/GameState.gd:51` (`add_weapon`) and
`scripts/ui/LevelUpOffer.gd:20` (`_build_offers`)

- The comment on `add_weapon` says "replace with higher-tier version" but there
  is **no tier check** — it replaces unconditionally.
- `_build_offers()` only filters `w.tier > max_tier`, so it can offer tier 1 of
  a weapon the player already owns at tier 3. Picking that card makes the
  weapon **worse**. Same-tier offers are also possible (a fully wasted pick).

**Fix (both ends):**
- In `_build_offers`, skip weapons where `owned != null and w.tier <= owned.tier`.
- In `add_weapon`, only replace when `weapon.tier > active_weapons[i].tier`.

### 4. XP bar only updates on level-up

**File:** `scripts/ui/HUD.gd`

`_update_xp_bar()` is only called from `_ready()` and `_on_level_up()`. Nothing
updates it when XP is gained mid-level, so the bar sits stale until the next
level-up.

**Fix:** simplest is to call `_update_xp_bar()` from `_process()`. Cleaner:
add an `xp_changed` signal to `GameState.add_xp` and connect to it.

### 5. Crossing two XP thresholds loses a level-up pick

**Files:** `scripts/autoloads/GameState.gd:29` (`add_xp`) and
`scripts/ui/LevelUpOffer.gd`

Two related problems:
- `add_xp` uses `if`, not `while`, so a single big XP gain that crosses two
  thresholds only grants one level (minor — the next kill catches up).
- If two kills in the same frame each trigger a level-up, `level_up` fires
  twice, `_build_offers()` runs twice (the second overwrites the first), and
  the player gets only **one** card pick for two levels.

**Fix:** loop in `add_xp` (`while threshold_index < size and xp >= threshold`),
and in `LevelUpOffer` queue pending picks (e.g. a `pending_levels` counter:
after a card is picked, if more levels are pending, rebuild offers and stay
visible instead of unpausing).

### 6. Potential runtime error loading the save file

**File:** `scripts/autoloads/SaveManager.gd:23`

```gdscript
unlocked_mechs = config.get_value("pilot", "unlocked_mechs", ["Jenner JR7-D"])
```

`unlocked_mechs` is declared `Array[String]`, but `get_value()` returns an
untyped `Array` (and the fallback literal is untyped too). In Godot 4 assigning
an untyped array to a typed variable is a **runtime error**.

**Fix:**

```gdscript
unlocked_mechs.assign(config.get_value("pilot", "unlocked_mechs", ["Jenner JR7-D"]))
```

---

## Lower priority

### 7. Soft-lock if level-up offer pool is empty

**File:** `scripts/ui/LevelUpOffer.gd` (`_on_level_up` / `_build_offers`)

If the pool ever comes up empty, all three cards hide but the screen still
shows (invisible) and the tree stays paused — no way to resume. Guard: if
`current_offers.is_empty()`, skip showing and unpause (the pause is set in
`PlayerMech._on_level_up`).

### 8. Save file written to disk on every enemy kill

**Files:** `scripts/components/EnemyMech.gd:53` → `scripts/autoloads/SaveManager.gd:25`

`_die()` → `SaveManager.add_credits()` → `save()` writes `user://save.cfg` per
kill. Works, but batching kill credits into run state (GameState) and awarding
them once at mission end is cleaner — and resolves the ambiguity that abandoned
missions currently still bank kill credits. (Related to the planned bounty-credits
feature.)

### 9. Difficulty scaling multiplies enemy speed linearly

**File:** `scripts/components/EnemyMech.gd:19` (`setup`)

`speed = base_speed * diff_mult` with `diff_mult` growing `1.15^n` per minute
(`EnemySpawner.gd`) means late-game scouts move several times base speed and can
outrun every mech. Usual pattern: scale armor/damage fully, scale speed gently
or not at all.

### 10. Camera follows in `_process` while player moves in `_physics_process`

**File:** `scripts/components/Arena.gd:28`

Can cause visible stutter when render and physics rates diverge. Move the camera
update to `_physics_process`, or make the Camera2D a child of the player (with
position smoothing).

### 11. Ground grid never redraws on resize

**File:** `scripts/components/Ground.gd`

`_draw()` runs once; if the ColorRect is ever resized nothing calls
`queue_redraw()`. Connect `resized` → `queue_redraw` (only matters if the
arena/window size changes).

### 12. Unused fields (probably intentional / planned)

`GameState.is_bonus_wave` and `MissionDef.bonus_wave_reward` are defined but
never used. Matches the planned bonus-wave / bounty-credits work — leave or
implement, just don't let them rot.

---

## Suggested order of attack

1, 2, 3 first (direct gameplay bugs), then 6 (crash risk), then 4–5 (UX),
then the lower-priority items as polish.
