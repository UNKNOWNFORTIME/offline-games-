# Arcade Rush

Offline Android arcade bundle built with Godot 4 (GDScript). See `GAME_SPEC.md`.
Everything visual and every placeholder sound is generated in code — no assets needed.

## What you need
| Tool | Version |
|---|---|
| Godot | **4.4.x stable** or newer 4.x (standard build, not .NET) |
| Godot Android export templates | same version as the editor (Editor ▸ Manage Export Templates ▸ Download) |
| JDK | **OpenJDK 17** (e.g. Eclipse Temurin 17) |
| Android SDK | via Android Studio or cmdline-tools: Platform-Tools, Build-Tools **34.0.0**, Platform **android-34**, CMake 3.10.2, NDK r23c (only needed for custom Gradle builds) |

Editor ▸ Editor Settings ▸ Export ▸ Android:
- **Java SDK Path** → your JDK 17 folder
- **Android SDK Path** → your SDK folder
- **Debug Keystore** → the debug keystore path (user `androiddebugkey`, password `android`).
  Keystores are never committed (see `.gitignore`).

## Run on your phone (USB)
1. Phone: Settings ▸ About ▸ tap *Build number* 7× → Developer options ▸ enable **USB debugging**.
2. Plug in via USB, accept the "Allow USB debugging" prompt.
3. Open the project in Godot. Top-right of the editor an **Android** one-click-deploy
   button appears (Remote Debug ▸ "Deploy with Remote Debug" is on by default).
   Click it → the app builds, installs and launches; errors show in the editor Debugger.
4. Or export an APK: Project ▸ Export ▸ Android ▸ Export Project → `build/ArcadeRush-debug.apk`.

Desktop testing: press F5. Mouse drag = finger drag. Arrow keys / A-D also steer,
Space = tap, F3 = debug overlay.

## Phase 0 + 1 test checklist
**Hub**
- App opens with a fade on a blue gradient Hub: gear (top-left), coin pill (top-right),
  bobbing "ARCADE RUSH" title, 4 animated game cards. Crowd Rush has a wiggling PLAY
  button; the other 3 show "COMING SOON".
- Gear → Settings: toggle Sound / Music / Vibration and LOW / HIGH graphics.
  Close the app fully and reopen → settings are kept.
- 3-finger tap anywhere → debug overlay (FPS, draw calls, tris, nodes, pooled objects).

**Crowd Rush**
- Tap PLAY → fade into a floating track over water with islands and clouds.
  "HOLD & DRAG TO RUN" + animated finger.
- Touch and drag left/right → the runner starts running and follows your finger.
- Pass through gates: blue (+ / ×) grow the crowd, red (− / ÷) shrink it. The chosen
  gate flashes and bursts, the other greys out; the counter above the crowd ticks to
  the new number; new runners "bloom" outward in a spiral; big multipliers kick the FOV.
- Reach the arena: your crowd and the red crowd annihilate 1:1 over ~1.5 s with puffs.
- "BOSS FIGHT!" → survivors pour into the red brute, its HP bar drains with damage
  numbers, it stomps every 1.6 s (shake + vibration) killing a few runners.
- Win: boss falls, crowd celebrates, camera orbits, LEVEL COMPLETE drops in, confetti,
  coins count up. Tap **x3 COINS** (2-second mock ad) or wait 1.5 s for **No thanks**;
  coins fly to the coin pill and the next level loads.
- Fail (crowd hits 0): FAILED screen with RETRY / Back to games.
- Pause button (top-left) → Resume / Restart / Home and quick sound toggles.
  Switching apps mid-run auto-pauses.
- Levels 1–3 are hand-made; level 4+ are generated (always winnable).

## Short-video moments
1. Level 3, gate 3: take **×4** at 12 → crowd blooms to 48 with a FOV punch.
2. Clash in level 3: 160 blue vs 64 red annihilating in a wave of puffs.
3. The boss stomp + fall: hit flashes, damage numbers, slam, confetti end screen.
