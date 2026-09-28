# RAIN

RAIN is a Flutter app that displays an animated rain-on-glass scene with a rain sound bed. Touch and hold to intensify the rain; drag a finger across the screen to wipe condensation from the glass.

> This repository contains a sensory ambience app. It does not provide medical advice or make health claims.

## Features

- Full-screen, portrait-oriented rain scene with a dark city background.
- Animated water beads, sliding rivulets, refraction, highlights and soft background blur rendered with a Flutter fragment shader.
- Falling rain streaks, impact ripples and splashes painted on a separate canvas.
- Condensation gradually appears over the scene. Touch and drag to clear it; cleared areas slowly fog again.
- Rain audio starts during the entry flow. Two audio players overlap near the end of the sound file to crossfade between plays.
- Long-pressing the screen raises the visual rain intensity and ramps up audio volume and playback rate. Releasing returns them toward baseline.
- A short “Just listen.” message is shown on first launch only.
- No account, network service, analytics or cloud storage is used by the app code.

## Interaction and controls

| Action | Result |
| --- | --- |
| Open the app | Starts the entry sequence and rain audio; then opens the rain scene. |
| First launch | Shows “Just listen.” briefly. Later launches skip the message. |
| Press and hold | Increases rain intensity and adjusts audio volume/playback rate. |
| Drag | Clears a path through the condensation. The drag can also influence nearby rain particles. |
| Release | Rain intensity and audio move back toward their baseline. Wiped areas gradually fog over again. |

There is no in-app settings screen, mute button, intensity slider, theme selector or session timer. Audio can be silenced with the device’s volume controls.

## Rendering and performance

The active screen combines several renderers:

1. `RainUltra` loads `shaders/rain_composite.glsl` and the background image (`assets/images/bg_calm.png`). The single-pass fragment shader draws multiple scales of beads and rivulets, finger interaction, background blur/refraction, highlights, color grading and a vignette. The shader is driven by a `Ticker` and `ValueNotifier`.
2. `RainCanvas` uses a `CustomPainter` for falling rain streaks, impact ripples and small splashes. An `AnimationController` advances the particles; the painter listens directly to it to avoid rebuilding the widget tree on every frame.
3. `FoggedGlass` paints a translucent condensation layer and uses a `dstOut` blend inside a canvas layer to erase the finger’s wipe path. Fog strength and wipe recovery respond to elapsed time and rain intensity.
4. `FilmGrainOverlay` paints a subtle static grain pattern inside a `RepaintBoundary`.

The shader is rendered at the display’s full logical resolution. Shader complexity, display resolution, GPU and Flutter build mode affect frame rate. A debug build can be less representative of release performance. Smoothness has been tuned on Android, but performance has not been benchmarked across a device matrix.

## Audio and local data

- Playback uses [`audioplayers`](https://pub.dev/packages/audioplayers) and the bundled `assets/audio/rain.mp3` file.
- `rain1.mp3` and `rain2.mp3` are also in the asset folder but are not selected by the current sound service.
- Two players overlap for a roughly two-second crossfade, started about three seconds before the active clip ends. This is intended to make the loop continuous; a perfectly seamless result depends on the audio file’s edit and has not been measured on every device.
- The baseline and peak volume values are `0.60` and `0.85`. A long press also changes playback rate slightly (from `1.00` to `1.02`). There is no in-app mute or volume slider.
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) stores one boolean, `rain_first_launch_complete`, so the intro message is shown once. No other app settings or session history are persisted.
- The app code does not call a backend or make network requests. Audio and image files are bundled locally.

## Project structure

```text
lib/
├── main.dart                         # Flutter initialization and app entry point
├── app/
│   └── rain_app.dart                 # MaterialApp, fixed dark theme, entry route
├── core/
│   ├── constants/
│   │   ├── app_colors.dart           # Shared palette
│   │   └── app_durations.dart        # Animation and audio values
│   └── services/
│       ├── first_launch_service.dart # One-time intro flag in SharedPreferences
│       └── sound_service.dart        # Dual-player rain playback and crossfade
└── features/rain/
    ├── screens/
    │   ├── entry_screen.dart         # Intro audio/text/fade sequence
    │   └── rain_screen.dart          # Main screen, gestures and layer composition
    └── widgets/
        ├── film_grain_overlay.dart  # Static grain texture
        ├── fogged_glass.dart        # Condensation and touch-to-wipe layer
        ├── ground_ripples.dart      # Separate ripple widget
        ├── offscreen_buffer.dart    # Offscreen shader helper retained in the project
        ├── rain_on_glass.dart       # Separate CPU glass-drop implementation
        ├── rain_painter.dart        # Falling streaks, ripples and splashes
        ├── rain_shader.dart         # Alternate shader overlay
        └── rain_ultra.dart          # Active background and glass shader

assets/
├── audio/                           # Bundled rain audio files
└── images/                          # App icon and background images

shaders/
├── rain.glsl                        # Shader source retained in the repository
├── rain_buffer_a.glsl               # Offscreen-buffer shader source
└── rain_composite.glsl              # Active single-pass rain-on-glass shader

test/
└── widget_test.dart                 # Flutter widget-test entry point
```

The active `RainScreen` uses `rain_ultra.dart`, `rain_painter.dart`, `fogged_glass.dart` and `film_grain_overlay.dart`. The other shader/drop/ripple widgets and offscreen buffer are retained alternatives and are not part of the active screen flow.

## Tech stack

| Area | Implementation |
| --- | --- |
| UI and rendering | Flutter, Dart, `CustomPainter`, Flutter fragment shaders (GLSL) |
| State | Widget-local state with `StatefulWidget`, `AnimationController`, `Ticker` and `ValueNotifier` |
| Audio | `audioplayers` |
| Local persistence | `shared_preferences` |
| Backend | None |

### Dependencies

Runtime dependencies from `pubspec.yaml`:

- `audioplayers: ^6.0.0`
- `shared_preferences: ^2.2.2`

Development dependencies:

- `flutter_test` (Flutter SDK)
- `flutter_lints: ^6.0.0`
- `flutter_launcher_icons: ^0.14.3`

## Requirements and setup

- Flutter SDK with Dart `^3.10.3` (the constraint in `pubspec.yaml`).
- Android Studio or another Flutter-compatible IDE and an Android SDK for Android builds.
- A connected Android device or emulator to run the app.

```bash
git clone https://github.com/Maher-Tec/RAIN.git
cd RAIN
flutter pub get
flutter run
```

Run static analysis and the widget tests with:

```bash
flutter analyze
flutter test
```

Build Android artifacts with:

```bash
flutter build apk --release
flutter build appbundle --release
```

The Android Gradle configuration currently uses the debug signing configuration for release builds and the application ID `com.example.rain`. Set a unique application ID and configure release signing before distributing a production build. The project has other Flutter platform folders, but they have not been validated as supported release targets.

## Licensing and third-party assets

The repository includes a root [MIT License](LICENSE) for the project and a [third-party notices file](THIRD_PARTY_NOTICES.md) for the Rain-on-Glass adaptation. Keep the required upstream copyright and permission notice when distributing that adapted material.

**Before publishing this repository as open source, verify the redistribution rights for every bundled media file.** The repository does not currently document the authors, source URLs or licenses for `assets/audio/rain.mp3`, `rain1.mp3`, `rain2.mp3`, the background images, or the app icon. A code license does not automatically grant rights to those files. For each asset, record its source, author and license in `THIRD_PARTY_NOTICES.md`, or replace/remove it if its terms do not allow redistribution. Also confirm that the copyright holder named in `LICENSE` (`RAIN`) is the correct owner for the code you are licensing.

Flutter packages have their own licenses; review their license notices when redistributing a built application. The `publish_to: 'none'` setting prevents publication to pub.dev; it does not prevent hosting the source repository on GitHub.

## Contributing

Issues and pull requests are welcome. Please describe the device/platform tested and whether the change affects rendering, audio or bundled assets. New third-party code, images, sounds and fonts should include their source and license in `THIRD_PARTY_NOTICES.md`.

## Acknowledgements

- Rain-drop interaction is adapted in part from [Rain on Glass by Hixly](https://github.com/Hixly/rain-on-glass); see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
- Flutter and the packages listed above provide the app framework and audio/persistence plugins.
