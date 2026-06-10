# Placeholder Visual Reference

All sprites are currently `ColorRect` nodes named `Sprite`. This file documents the
color/shape conventions so they can be swapped for real art later without
hunting through scripts.

## Player mech (by `weight_class`)
Set in `scripts/components/PlayerMech.gd` (`_color_for_weight_class`).

| Weight Class | Color (RGB) | Swatch |
|---|---|---|
| Light    | (0.3, 0.6, 1.0) | blue |
| Medium   | (0.3, 0.9, 0.6) | teal/green |
| Heavy    | (0.9, 0.7, 0.2) | gold |
| Assault  | (0.85, 0.2, 0.55) | crimson/magenta |

Sprite size: 36x36 (`scenes/game/PlayerMech.tscn`).

## Enemy mech (by `archetype`)
Set in `scripts/components/EnemyMech.gd` (`_apply_visuals`).

| Archetype  | Color (RGB) | Notes |
|---|---|---|
| scout      | (0.8, 0.8, 0.9) | pale blue-gray |
| brawler    | (0.9, 0.3, 0.2) | red-orange |
| artillery  | (0.6, 0.3, 0.9) | purple |
| boss       | (0.5, 0.0, 0.0) | dark red, scaled 2.5x |

Base sprite size: 32x32 (`scenes/game/EnemyMech.tscn`).

## Projectiles (by `weapon_type`)
Set in `scripts/components/Projectile.gd` (`_apply_color`), mirrored in
`scripts/ui/HUD.gd` (`_color_for_weapon_type`) for the weapon icon row.

| Weapon Type | Color (RGB) |
|---|---|
| autocannon | (1.0, 0.7, 0.1) | orange |
| laser      | (1.0, 0.15, 0.15) | red |
| missile    | (0.3, 1.0, 0.4) | green |

Sprite size: 8x8 (`scenes/game/Projectile.tscn`).

## Explosion FX
`scenes/fx/ExplosionFX.tscn` - 40x40 gold ColorRect (1, 0.8, 0.2) that fades out.

## Swapping in real art
Each `MechDef` / `WeaponDef` / `EnemyDef` resource already has a `sprite: Texture2D`
export. To use real art: replace the `ColorRect` named `Sprite` in the relevant
`.tscn` with a `Sprite2D`/`TextureRect`, and in the corresponding script's setup
function assign `texture = def.sprite` (falling back to the placeholder color
logic above when `sprite` is null).
