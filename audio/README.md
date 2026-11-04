# Audio slots

Every SFX below already plays a **synthesized placeholder** (see `core/sfx_synth.gd`).
Drop a real file with the same name into `audio/sfx/` (`.ogg` preferred, `.wav` ok)
and it automatically replaces the placeholder — no code changes.

| File name (audio/sfx/) | Used for | Good CC0 source |
|---|---|---|
| ui_click | every button | Kenney "Interface Sounds" (click_001) |
| gate_good | positive gate | Kenney "Digital Audio" (powerUp*) |
| gate_bad | negative gate | Kenney "Digital Audio" (lowDown / phaserDown*) |
| unit_pop | crowd unit lost | Kenney "Interface Sounds" (drop_00*) |
| coin_pick | coin collected | Kenney "Casino Audio" / "RPG Audio" (coins) |
| coin_count_tick | coin count-up | Kenney "Interface Sounds" (tick_00*) |
| boss_hit | boss takes damage | Kenney "Impact Sounds" (impactPunch_*) |
| boss_die | boss defeated | Kenney "Impact Sounds" (impactHeavy*) |
| win | level complete | Kenney "Music Jingles" (jingles_NES / pizzi) |
| fail | level failed | Kenney "Music Jingles" (lose jingle) |
| spike_break | Stack Skater spikes | Kenney "Impact Sounds" (impactMetal_*) |
| engine_loop | Overtake engine (loop) | jsfxr: "Explosion" preset, slow, loop |
| boost | Overtake boost | Kenney "Sci-fi Sounds" (thrusterFire*) |
| near_miss | Overtake near miss | Kenney "Sci-fi Sounds" (laserLarge) / whoosh |
| crash | Overtake crash | Kenney "Impact Sounds" (impactPlate_heavy*) |
| gun_pistol / gun_smg / gun_shotgun / gun_rifle | Last Barricade | Kenney "Sci-fi Sounds" / jsfxr "Hit/Hurt" + "Explosion" |
| enemy_pop | enemy defeated | Kenney "Interface Sounds" (pluck_*) |
| barricade_hit | barricade damaged | Kenney "Impact Sounds" (impactWood_heavy*) |
| pickup | weapon pickup | Kenney "Digital Audio" (powerUp*) |
| whoosh | run start / transitions | Kenney "Sci-fi Sounds" |
| stomp | boss stomp | Kenney "Impact Sounds" (impactHeavy*) |

jsfxr (https://sfxr.me) also works: pick a preset, tweak, export WAV, save under the name above.

## Music (audio/music/)

`hub.ogg`, `crowd_rush.ogg`, `stack_skater.ogg`, `overtake.ogg`, `last_barricade.ogg`.
Missing music = silence. Set the import option **Loop = on** for each track.
Record every file's source + license in `ATTRIBUTION.md`.
