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
games/crowd_rush/  crowd_rush.tscn/gd (state machine), crowd (MultiMesh swarm), runner_mesh,
            gate_pair, boss, track (world builder), levels (JSON + generator), hud
ui/         ui_theme (code-built theme), icon_draw, coin_pill, end_screen, pause_menu,
            settings_panel, confetti, fonts/
data/       crowd_rush_levels.json
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

## Status
- [x] Phase 0 — Foundation (autoloads, touch input, juice, palette, shaders, UI kit,
      hub, settings, save/load, transitions, debug overlay, Android preset)
- [x] Phase 1 — Crowd Rush core (track, steering, 4 gate ops, MultiMesh spiral crowd,
      counter, clash, boss + HP, win/fail, end screen + coins, 3 hand-made levels;
      levels 4+ come from the generator already)
- [ ] Phase 2 — Crowd Rush polish (obstacles, 10 hand levels, start-crowd upgrade UI,
      revive, remaining VFX)
- [ ] Phase 3 Stack Skater · [ ] Phase 4 Overtake · [ ] Phase 5 Last Barricade · [ ] Phase 6 Release

## Known gaps / notes
- Scripts were written without running the Godot editor in the authoring
  environment; first open in the editor may surface small API issues — fix forward.
- The auto-quality probe measures the 2D Hub (per spec); a 3D in-game probe may be
  a better signal later.
