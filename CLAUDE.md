# CLAUDE.md — Arcade Rush project context

Read `GAME_SPEC.md` for the full product spec. This file = conventions + status.

## Stack
- Godot **4.4+** (GDScript, static typing everywhere), **Mobile renderer**,
  `rendering_device/fallback_to_opengl3=true` so phones without Vulkan still run.
- Portrait 1080x1920, stretch `canvas_items`, aspect `expand`.
- No plugins (AdMob comes in Phase 6). No downloaded assets: every mesh, material,
  icon, illustration and placeholder SFX is generated in code.

## Folder structure
```
autoload/   SaveSystem, Settings, Economy, AudioManager, Haptics, AdService (mock), GameState
core/       palette, toon (material factory), ui_kit, pool, touch_input (autoload TouchInput),
            juice (autoload Juice), debug_overlay (autoload), follow_camera, env_builder,
            safe_area, sfx_synth, app_info (name + game registry)
shaders/    toon_light.gdshaderinc (shared cel lighting), toon, outline, crowd_unit,
            gate_panel, track, water, badge, particle
hub/        hub.tscn/gd, game_card, card_art (code-drawn animated illustrations), hub_background
games/crowd_rush/      state machine, crowd (MultiMesh swarm), runner_mesh, gate_pair, obstacle,
                       boss, track (world), levels (JSON + generator)
games/stack_skater/    skater (rig + MultiMesh coin bar), world (city/track/features/ramp), levels
games/overtake/        overtake (state machine), road (recycled strips + MultiMeshes),
                       vehicles (player car + baked 1-draw-call traffic), garage (upgrades UI)
games/last_barricade/  last_barricade (aim/fire/waves), shambler (pooled enemy), weapons, world
ui/         ui_theme (code-built theme), game_hud (shared HUD), icon_draw, coin_pill, end_screen,
            pause_menu, settings_panel, daily_reward, confetti, fonts/
data/       crowd_rush_levels.json, barricade_waves.json
docs/       PRIVACY_POLICY.md, STORE_LISTING.md, ADMOB.md
.github/workflows/build.yml  CI: real Godot 4.4.1 smoke test (autopilot, screenshots,
            draw-call telemetry) + signed debug APK artifact
audio/      sfx/ music/ (drop-in files override synth placeholders; see audio/README.md)
```

## Conventions
- Scenes are tiny (`.tscn` = root node + script); scripts build their children in code.
  One script per scene root. Characters/props are built by their own class
  (`RunnerMesh`, `CrowdBoss`, ...) so imported models can replace them later
  without touching gameplay code.
- All colors come from `Palette`. All lit materials come from `Toon` (cached by key).
  Toon lighting normalizes light energy (consistent on Vulkan + GL fallback).
- Input only via `TouchInput` signals (`pressed/released/dragged/tapped/swiped`,
  `is_holding()`). Controls in group `touch_block` swallow touches (buttons, modals).
- Feedback only via `Juice` (shake, hit_stop, punch_scale, floating_text, flash,
  burst, puff), `AudioManager.play(name, pitch_var)` and `Haptics.light/medium/heavy`.
- Pool anything spawned repeatedly (`Pool`). No instantiate/queue_free in hot loops,
  no per-frame allocations in `_process`.
- Quality: `Settings.is_high()`, `shadows_enabled()`, `outlines_enabled()`,
  `max_crowd_visible()`, `particle_scale()`. Low = no shadows/outlines/glow,
  120 units, half particles, render scale 0.75, no MSAA.
- Save: `SaveSystem.data` (versioned; add a branch in `_migrate` when bumping VERSION).
  Call `SaveSystem.mark_dirty()` for coalesced saves, `save_game()` at level end.
- Theme is built in code (`UiTheme`) rather than `ui/theme.tres`, so it always matches
  `Palette`; applied to the root window by `GameState`.
- Fonts: drop `LilitaOne-Regular.ttf` (or Baloo 2) into `ui/fonts/` → used automatically.
- Name lives in `AppInfo.GAME_NAME` (+ project.godot + export preset package name).

## CI / verification
Every push runs `.github/workflows/build.yml`: imports the project with Godot 4.4.1,
runs `godot -- --smoke` under xvfb + lavapipe (real Mobile/Vulkan rendering) which plays
every game on autopilot (`smoke_start()` in each game scene), saves screenshots, logs
`SMOKE perf` lines (draw calls/tris/nodes), fails on any SCRIPT/SHADER error, then
exports a signed debug APK (artifact "ArcadeRush-debug-apk").
Each game scene must implement `smoke_start()` and put its end screen in group `end_screen`.

## Status
- [x] Phase 0 — Foundation
- [x] Phase 1 — Crowd Rush core
- [x] Phase 2 — Crowd Rush polish (obstacles, 10 hand levels, generator, revive, upgrade)
- [x] Phase 3 — Stack Skater
- [x] Phase 4 — Overtake
- [x] Phase 5 — Last Barricade
- [~] Phase 6 — daily reward, docs, release preset, perf telemetry done;
      real AdMob plugin integration pending (see docs/ADMOB.md), icon PNG set optional.

## Known gaps / notes
- AdMob is still the mock (plugin needs a Gradle build; see docs/ADMOB.md).
- The auto-quality probe measures the 2D Hub (per spec).
