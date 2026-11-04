# GAME_SPEC.md — Master Build Prompt for Claude Code

> **How to use:** Put this file in the root of an empty project folder. Open Claude Code there and say:
> *"Read GAME_SPEC.md fully. Summarize your understanding and your plan for Phase 0 and Phase 1, list anything you need from me, then wait for my go-ahead."*
> After that, work one phase at a time.

---

## 0. Role and working rules (read first)

You are a senior mobile game developer and technical artist working in **Godot 4 (latest stable 4.x, GDScript)**. You are building an offline Android game app that bundles several small, polished arcade games, each inspired by a popular mechanic seen in mobile game ads, but **fully original** in art, names and content.

Working rules:
1. **Work in phases** (Section 10). Never start the next phase until I confirm the current one works on my phone.
2. At the end of every phase: commit to git with a clear message, then tell me **exactly how to test it** (what to tap, what I should see) and list any known issues.
3. Use **static typing in GDScript** everywhere (`var speed: float = 5.0`, typed function signatures).
4. Keep scenes small and reusable. One script per scene, attached to its root.
5. **No third-party plugins** except the AdMob plugin in Phase 6. No paid assets.
6. **Everything visual must work with zero downloaded assets** (procedural meshes, materials, shaders, particles). External CC0 assets are optional upgrades later (Section 5.8).
7. Prioritize **game feel** (Section 6) over feature count. A small game that feels great beats a big game that feels flat.
8. Performance is a hard requirement (Section 7). Target phones are low-to-mid-range Android devices.
9. Do not copy names, logos, characters, UI layouts or art from any existing game. Copy **mechanics only**.
10. If something in this spec is ambiguous, ask me before building it. If something in this spec is technically a bad idea, tell me and propose a better option.
11. Maintain a `CLAUDE.md` file in the repo with project conventions, folder structure and current phase status, so future sessions have context.

---

## 1. Product overview

- **Working title:** `Arcade Rush` (placeholder; keep the name in one constant so it is easy to change).
- **Platform:** Android first (portrait). iOS possible later; do not use Android-only APIs outside the ad/haptics wrappers.
- **Orientation:** Portrait, base resolution 1080×1920, stretch mode `canvas_items`, aspect `expand`. Must look correct on 18:9, 19.5:9 and 20:9 screens and respect safe areas / notches.
- **Offline:** All games fully playable without internet. Ads simply don't show when offline.
- **Structure:** A **Hub** screen with game cards. Each card opens one mini-game. A shared coin currency and shared progression tie them together.

### The games (original names)

| # | Name | Inspired mechanic | Build phase |
|---|------|-------------------|-------------|
| 1 | **Crowd Rush** | Run through math gates that grow your crowd, then clash with an enemy crowd and a boss | Phase 1–2 |
| 2 | **Stack Skater** | Skate down a sky-high track collecting coin stacks; spikes shrink the stack; multiplier finish ramp | Phase 3 |
| 3 | **Overtake** | Weave through highway traffic at speed; between runs, upgrade Stamina / Power / Income | Phase 4 |
| 4 | **Last Barricade** | Hold a forest barricade against waves of shambling enemies; pick up better weapons | Phase 5 |

---

## 2. Tech stack and project setup

- Godot 4.x stable, **Mobile renderer** (not Forward+, not Compatibility unless Mobile fails on target device; ask before switching).
- Git repo with a Godot `.gitignore` (`.godot/`, `*.import` handled correctly, `export_presets.cfg` committed but **no keystore files**).
- Android export preset configured (I will provide the debug keystore path; explain what to install: Android SDK/JDK versions required by the Godot version you use).
- Enable **one-click deploy** / remote debug instructions so I can test on my phone over USB.

### Folder structure

```
res://
  autoload/          # singletons
  core/              # shared systems: input, camera, juice, pooling, ui widgets
  shaders/
  materials/
  hub/
  games/
    crowd_rush/
    stack_skater/
    overtake/
    last_barricade/
  ui/                # theme, fonts, shared UI scenes
  audio/
  data/              # level definitions (.tres or JSON)
```

### Autoloads (singletons)

- `GameState` — current game, session data, scene transitions (with a fade).
- `SaveSystem` — saves to `user://save.json`; versioned schema with migration; autosave on pause/quit and after each level.
- `Economy` — coin balance, earning, spending, upgrade costs. Emits signals on change.
- `AudioManager` — SFX pool (8 voices), music player with crossfade, master/SFX/music volume, mute.
- `Haptics` — wrapper around `Input.vibrate_handheld()`; respects a settings toggle; light/medium/heavy presets (15ms / 30ms / 60ms).
- `AdService` — interface with `show_interstitial()`, `show_rewarded(callback)`, `is_rewarded_ready()`. **Phase 0–5 uses a MockAdService** that shows a fake 2-second overlay. Real AdMob in Phase 6.
- `Settings` — sound, music, haptics, graphics quality (Low/High), language placeholder.

---

## 3. Shared controls

- **Runner games (1, 2):** Touch-and-drag horizontally anywhere on screen. Character X position follows finger delta (not absolute position), with smoothing (`lerp` factor ~12 * delta) and clamped to track width. Forward movement is automatic.
- **Overtake (3):** Swipe left/right to change lanes (3 lanes, lane change takes ~0.18s with a slight car tilt). Hold anywhere to boost (drains stamina).
- **Last Barricade (4):** Drag to aim (crosshair follows finger with smoothing); weapon auto-fires while a finger is down. Tap a floating weapon pickup to grab it.
- Every game: a **pause button** top-left, a big **"Tap to start"** state before the run begins, and a **level counter** top-center.
- Implement input in a shared `core/touch_input.gd` so all games read the same drag/swipe/hold signals. Also support mouse for desktop testing.

---

## 4. Game designs

### 4.1 Crowd Rush (Phase 1–2)

**Loop:** Start with 1 runner → drag left/right through gate pairs → crowd grows or shrinks → reach the end → crowd clashes with enemy crowd → survivors attack a boss → coins awarded based on result.

**Track:** Straight, ~120–200m long, 8m wide, with low side rails. Camera behind and above, looking down at ~45°.

**Gates:** Come in pairs (left half / right half of the track). Operations: `+N`, `−N`, `×N`, `÷N`. Display the operation in big bold text on a translucent panel.
- Positive gates (`+`, `×`): blue tint.
- Negative gates (`−`, `÷`): red tint.
- A gate is consumed when the crowd's center passes through; the other gate of the pair is disabled.
- Results always rounded down; crowd never drops below 0 (0 = fail).

**Crowd:**
- Rendered with a **MultiMeshInstance3D** (not individual nodes) for performance.
- Formation: sunflower / Fibonacci spiral packing around the leader so the crowd forms a natural blob that grows outward.
- Max **visible** units: 300 (High) / 120 (Low). Actual count can go higher; show the exact number on a floating label above the crowd.
- New units pop in with a scale tween (0 → 1.15 → 1.0 over 0.2s). Lost units pop out with a small particle puff.
- Units bob slightly while running (sine on Y with random phase per instance).

**Obstacles (from level 3+):** Spinning bars, saw blades, side pushers. Units that touch them are removed individually.

**End clash:** Enemy crowd (red team) stands at the end. On contact, units annihilate 1:1 with a quick pop effect, staggered over ~1.5s so it feels like a fight, not an instant subtraction.
- If you have units left: they rush a **boss** (big red brute built from primitives) with an HP bar. Each surviving unit deals damage. Boss HP scales with level.
- Win: boss defeated. Fail: crowd reaches 0.

**Rewards:** Base coins + bonus per surviving unit. End screen shows coins with a counting-up animation and a **"×3 coins (watch ad)"** rewarded button plus a "No thanks" link that appears after 1.5s.

**Levels:** Data-driven. Each level is a resource/JSON defining track length, gate list (position, left op, right op), obstacles, enemy crowd size, boss HP. Hand-design levels 1–10, then generate procedurally with a difficulty curve so the game never runs out of levels. Generator must guarantee each level is winnable.

### 4.2 Stack Skater (Phase 3)

**Loop:** Skater auto-rides down an elevated track high above a foggy city → collect gold coin stacks → spikes cut the stack → multiplier walls boost it → finish ramp converts stack into coins.

- The skater **holds a horizontal bar of stacked coins** in both hands. The bar's length grows/shrinks with the stack count (visually: a row of coin cylinders, extending both sides).
- Pickups: coin stacks with labels `×3`, `×5`, `+10` etc. on the track (gold, glowing slightly).
- Spike strips: any coins on the side that hits spikes break off and fall off the track (physics or tweened falling coins, then pooled back).
- Narrow sections where a wide stack scrapes the side rails and loses coins, so the player must think about width.
- Finish: a ramp with steps labeled `×1` to `×10`; the skater climbs as far as the stack allows, dropping coins on each step. Final step reached = multiplier.
- Same end screen pattern as Crowd Rush.

### 4.3 Overtake (Phase 4)

**Loop:** Drive an open-wheel race car on a two-way country highway → traffic cars and trucks ahead → swipe between lanes to overtake → near misses pay money → crash ends the run → spend money on upgrades → drive again further.

- Speed shown as a big number in mph at the bottom center (stylized digital font look).
- **Stamina bar:** holding to boost drains it; it recharges when not boosting.
- **Near miss:** passing within a small distance of a vehicle without touching it gives `$` floating text and a speed-line flash.
- **Upgrades panel** (shown between runs, 3 cards side by side): **Stamina** (bar length), **Power** (top speed and acceleration), **Income** (money per near miss/second). Each card shows level, effect value and cost. Cost grows with a curve (e.g. `cost = base * 1.15^level`, rounded).
- Traffic: pooled vehicles of 3–4 procedural types (sedan, van, container truck, pickup), varied colors, spawned ahead at increasing density.
- Environment: endless road segments recycled (object pooling), roadside trees/rocks, rolling green hills.
- This game uses idle-progression feel: every run should end with "I can afford one more upgrade."

### 4.4 Last Barricade (Phase 5)

**Loop:** First-person, fixed position behind a wooden barricade on a forest dirt road → waves of shambling enemies approach → drag to aim, auto-fire → pick up stronger weapons floating in the scene → survive waves.

- Keep it **non-gory and stylized**: enemies are chunky primitive-built figures with a desaturated green-grey palette; when defeated they burst into a puff of particles and dissolve. No blood.
- Some enemies carry wooden plank shields (absorb hits from the front).
- Barricade has HP; enemies that reach it damage it. Barricade at 0 = fail.
- Weapons: pistol (start) → SMG → shotgun → rifle. Weapon pickups float with a glowing green outline and slow rotation. Each weapon differs in fire rate, damage, spread.
- First-person weapon view model built from primitives, with recoil kick (position + rotation tween) and muzzle flash (short-lived emissive quad + light).
- Waves defined in data; endless mode after wave 10.

---

## 5. Art direction and graphics (all procedural first)

### 5.1 Overall style

Bright, clean, **stylized low-poly with soft cel shading**, chunky readable shapes, saturated colors, strong silhouettes. It must read clearly on a small phone screen in sunlight. Think toy-like, not realistic.

### 5.2 Palette (define in `core/palette.gd` as constants)

| Use | Hex |
|-----|-----|
| Player team / positive | `#2F80FF` |
| Player team light | `#7DB7FF` |
| Enemy team / negative | `#FF3B3B` |
| Enemy light | `#FF8A80` |
| Gold / coins | `#FFC531` (shadow `#E09A00`) |
| Track / concrete | `#D9D4CC` |
| Rails / metal | `#8C96A3` |
| Grass | `#5DBB63` |
| Forest dark | `#2E5E3A` |
| Sky top / horizon | `#6EC6FF` / `#DFF3FF` |
| Fog (Stack Skater city) | `#B8C4D6` |
| UI dark | `#1B1F2A` |
| UI accent / success | `#36D399` |

### 5.3 Shaders (`res://shaders/`)

1. **toon.gdshader** — 2–3 band cel lighting, configurable base color, shadow color tint (not black; a darker, slightly blue-shifted version of the base), **rim light** (fresnel) for that glossy toy look, optional emission.
2. **outline.gdshader** — inverted-hull outline (grow along normals, cull front) as a `next_pass` material; outline width set per object, disabled on Low quality.
3. **gate_panel.gdshader** — translucent colored panel with soft animated vertical shimmer and brighter edges.
4. **coin.gdshader** — gold with fake specular highlight that sweeps over time.
5. **speed_lines.gdshader** — full-screen overlay for Overtake boost and near-miss.
6. **dissolve.gdshader** — noise-based dissolve for defeated enemies in Last Barricade.

All shaders must be mobile-friendly (no expensive loops, no screen-space tricks beyond the speed-lines overlay).

### 5.4 Characters (procedural)

- **Runner unit (Crowd Rush):** capsule body + sphere head + small helmet (flattened sphere) in team color. Low poly (≤ 300 tris). One shared mesh for the MultiMesh; team color via instance color.
- **Boss:** 3–4× scale brute made from boxes/capsules, enemy red, with a simple idle stomp animation (tween) and hit-flash (white flash for 0.06s on damage).
- **Skater:** body, limbs from capsules, helmet, backpack box, skateboard (flattened box + 4 small cylinder wheels). Subtle lean when moving sideways.
- **Car (Overtake):** open-wheel racer built from boxes and cylinders, rusty-brown/bronze body color option, visible spinning wheels, small rear wing.
- **Enemies (Last Barricade):** hunched capsule body, sphere head, mismatched arm lengths, shuffle walk via tweened bob/sway.

Build each character in a dedicated scene with a script that constructs or arranges meshes, so they can later be swapped for imported models without touching gameplay code.

### 5.5 Environments

- **Sky:** `ProceduralSkyMaterial` tuned per game (sunny blue for Crowd Rush and Overtake, hazy grey-blue for Stack Skater, misty green-grey for Last Barricade).
- **Fog:** depth fog enabled on all games for depth and to hide spawning.
- **Lighting:** one `DirectionalLight3D` per scene, soft, slight warm tint. Shadows **only** on the player character/crowd and big objects, short shadow distance; shadows off on Low quality.
- **Crowd Rush:** floating track over water or grass, side rails, distant low-poly hills.
- **Stack Skater:** narrow concrete track high above a city of simple box skyscrapers fading into fog.
- **Overtake:** two-lane asphalt road with white edge lines and dashed center line, grass verges, pine trees (cone + cylinder), rocks.
- **Last Barricade:** dirt road through tall pine trees, rocky cliff on one side, light ground mist (particle quads).
- Use instanced/MultiMesh scenery for trees and buildings.

### 5.6 VFX (GPUParticles3D, or CPUParticles3D if GPU particles cause issues on test device)

- Gate pass: burst of small cubes in gate color.
- Unit pop: tiny white/team-color puff.
- Coin collect: sparkle + coin flies toward the UI counter (2D overlay tween along a curve).
- Boss hit: impact spark + floating damage number.
- Near miss: speed-line flash + `$` text.
- Enemy defeat: dissolve + puff.
- Muzzle flash: emissive quad, 2 frames.
- Level complete: confetti burst from both screen sides (2D particles).

### 5.7 UI

- Create one shared `ui/theme.tres` used everywhere.
- Font: **Lilita One** or **Baloo 2** (both free under the Open Font License, from Google Fonts). I will download the font file and place it in `res://ui/fonts/`; until then use the default font. Credit the license in an `ATTRIBUTION.md`.
- Buttons: rounded (corner radius 28px), thick bottom shadow for a pressable 3D look, press animation (scale 0.94, 0.08s) + haptic light + click SFX.
- Big floating numbers use outlined text (dark outline 8px).
- Hub: vertical scroll of large game cards (each card has a live mini 3D preview or a stylized 2D illustration rendered from the game's scene), coin balance top-right, settings gear top-left.
- End screens: big "LEVEL COMPLETE" / "FAILED" banner dropping in with an overshoot tween, coin count-up, primary button "Next", secondary rewarded button.
- All UI must respect safe areas.

### 5.8 Optional asset upgrade path (later, not now)

When I ask, replace procedural meshes with free **CC0** models from Kenney (kenney.nl) or Quaternius, keeping the same scene interfaces. Always record source and license in `ATTRIBUTION.md`.

### 5.9 Graphics quality setting

- **High:** shadows on, outlines on, 300 crowd units visible, full particles, MSAA 2x.
- **Low:** no shadows, no outlines, 120 crowd units, half particles, render scale 0.75.
- Auto-pick Low on first launch if the device's average frame time in the first 5 seconds of the Hub is above 25ms.

---

## 6. Game feel ("juice") — required everywhere

Implement as a shared `core/juice.gd`:
- `screen_shake(intensity, duration)` with trauma-based decay.
- `hit_stop(duration)` — brief time scale drop (e.g. 0.05s at 0.1×) on big impacts.
- `punch_scale(node, amount)` tween.
- `floating_text(world_pos, text, color)` — rises and fades.
- `flash(node)` — white flash via shader parameter.
- Camera: smooth follow with slight lag, FOV kick (+6°) on boost and on big crowd growth.
- Every player action gets at least two kinds of feedback (visual + sound, or visual + haptic).
- Numbers that change (coins, crowd count) never jump; they tick quickly to the new value.

---

## 7. Performance requirements

- Target **60 fps on mid-range** Android, **stable 30 fps minimum on low-end** (around 3GB RAM).
- Draw calls under ~120 per frame in gameplay. Use MultiMesh for crowds, coins, trees, buildings, traffic where possible.
- **Object pooling** for everything spawned repeatedly (gates, coins, cars, enemies, particles, floating text). No `queue_free()` / `instantiate()` in the hot loop during gameplay.
- No per-frame allocations in `_process` / `_physics_process` (reuse arrays and vectors).
- Prefer simple Area3D overlap checks over full physics bodies for runners.
- Add a debug overlay (toggle with 3-finger tap) showing FPS, draw calls, node count, active pooled objects.
- APK size target: under 80MB.

---

## 8. Economy, progression and monetization

- Single currency: **coins**, shared across all games.
- Each game has its own level counter saved separately.
- Upgrades: Overtake has its own upgrade tree; Crowd Rush gets a global "Starting crowd +1" upgrade purchasable from its end screen.
- **Daily reward:** 7-day streak calendar on the Hub; streak resets if a day is missed.
- **Ads (via AdService only):**
  - Rewarded: ×3 coins on end screen; revive once per level in Crowd Rush and Last Barricade.
  - Interstitial: only after a completed level, not before level 3, at most once every 90 seconds, and never twice in a row without gameplay in between.
  - **No banner ads.**
  - Phase 6: integrate Google AdMob using the Godot AdMob plugin compatible with our Godot version, using **Google's official test ad unit IDs only**. I will swap in real IDs myself before release.
- Later (not now): "Remove Ads" in-app purchase.

---

## 9. Audio

- Music: one upbeat loop for Hub, one per game (I will add royalty-free/CC0 tracks; build the system with placeholder silence and clear file names).
- SFX list (create placeholder slots, file names in `audio/sfx/`): `ui_click`, `gate_good`, `gate_bad`, `unit_pop`, `coin_pick`, `coin_count_tick`, `boss_hit`, `boss_die`, `win`, `fail`, `spike_break`, `engine_loop`, `boost`, `near_miss`, `crash`, `gun_pistol`, `gun_smg`, `gun_shotgun`, `gun_rifle`, `enemy_pop`, `barricade_hit`, `pickup`.
- Tell me which free CC0 sound packs (e.g. Kenney audio packs) cover these, or how to generate them with jsfxr, and which file names to save them under.
- Pitch randomization (±8%) on repeated SFX like coin pickups and pops.

---

## 10. Build phases

**Phase 0 — Foundation**
Project setup, Mobile renderer, Android export preset, folder structure, all autoloads (with MockAdService), touch input, juice system, palette, toon + outline shaders, UI theme, Hub with 4 locked/placeholder cards, settings screen, save/load, scene transitions, debug overlay. Deliverable: app installs on my phone, Hub works, settings persist.

**Phase 1 — Crowd Rush core**
Track, runner control, gates with all 4 operations, MultiMesh crowd with spiral formation, crowd counter, end clash with enemy crowd, boss with HP, win/fail, end screen with coins. 3 hand-made levels.

**Phase 2 — Crowd Rush polish**
Obstacles, all VFX and juice for this game, 10 hand-made levels, procedural level generator with difficulty curve, starting-crowd upgrade, sound hooks. **Stop here; I will test with real players before continuing.**

**Phase 3 — Stack Skater**
**Phase 4 — Overtake**
**Phase 5 — Last Barricade**

**Phase 6 — Release prep**
Real AdMob integration (test IDs), app icon and splash (procedural/vector, in our palette), privacy policy placeholder text, Play Store listing text draft, release export settings, final performance pass on Low quality.

At the end of each phase also give me **2–3 short screen-recordable moments** from that phase (e.g. "crowd jumps from 12 to 96 through a ×8 gate") that would make good short videos.

---

## 11. Definition of done (every phase)

- Runs on my Android phone with no errors in the debugger.
- Meets the performance targets in Section 7 on Low quality.
- No placeholder pink/missing materials.
- Saves survive app restart.
- Git committed, `CLAUDE.md` updated.
- Clear testing instructions given to me.
