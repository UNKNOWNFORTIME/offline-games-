# AdMob integration (Phase 6)

The game only talks to ads through `AdService` (`autoload/ad_service.gd`):
`show_rewarded(callback)`, `show_interstitial()`, `is_rewarded_ready()`,
`should_show_interstitial(level)` (frequency rules: ≥ level 3, 90 s cooldown,
never twice without gameplay). Today it runs a **mock** (2-second overlay) so every
flow works offline and in CI.

## Swapping in real AdMob (Google test IDs)
1. Install the Godot AdMob plugin matching Godot 4.4 (Poing Studios
   "godot-admob-plugin", via Asset Library or its GitHub releases) and its Android
   plugin. Enable it in Project ▸ Project Settings ▸ Plugins.
2. Project ▸ Install Android Build Template (AdMob needs a Gradle build).
3. In the "Android" and "Android Release" presets set **Use Gradle Build = on**.
4. Use Google's official **test** IDs until release:
   - App ID: `ca-app-pub-3940256099942544~3347511713`
   - Interstitial: `ca-app-pub-3940256099942544/1033173712`
   - Rewarded: `ca-app-pub-3940256099942544/5224354917`
   (Constants are already in `AdService`. Replace with your real IDs before release.)
5. In `AdService`, replace the body of `_show_mock(...)` calls with the plugin's
   load/show calls; call `callback.call(true)` from the plugin's
   *user earned reward* signal and `callback.call(false)` when the ad fails or is
   closed early. Keep the frequency rules as they are.
6. When offline, ads simply fail to load → `is_rewarded_ready()` returns false and
   the rewarded buttons are disabled; gameplay is unaffected.

> Note: this step could not be built/tested in this environment (the plugin is a
> third-party download that needs a Gradle build). Everything else ships ready.
