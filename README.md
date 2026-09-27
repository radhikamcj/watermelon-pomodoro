# 🍉 Watermelon Pomodoro

A tiny, hand-drawn pomodoro timer for macOS that floats on top of every app.

<img src="docs/screenshot.png" width="360" alt="Watermelon Pomodoro widget">

## Features

- Floats above all windows, on every desktop, even over full-screen apps
- Drag it anywhere, and it remembers where you left it
- Starts at **00:00**. **– / +** change the time in 15-minute steps, up to 180 minutes (even while it's running)
- **▶ / ❚❚** to start and pause
- The watermelon sways while you focus. When time's up it shakes, hops and pops seeds 🎉
- Right-click for presets, **Reset**, **Preview celebration** and **Quit**

## Build & run

Requires macOS 14+ and the Swift toolchain (Xcode or the Command Line Tools: `xcode-select --install`).

```bash
./build.sh
open build/Watermelon.app
```

To keep it around, drag `build/Watermelon.app` into your **Applications** folder.

## Artwork

All the art is hand-drawn. The layers in `PNGs/` are full 1000 × 560 canvases (the Figma frame).
`scripts/export_art.swift` turns them into the images the app uses in `Resources/Art/`:
it copies the backgrounds, crops each digit and control tight, and makes their strokes a bit bolder.
After changing any drawing, run:

```bash
swift scripts/export_art.swift
./build.sh
```

## Project layout

```
Sources/WatermelonPomodoro/
  main.swift            app entry point (no Dock icon)
  AppDelegate.swift     the floating widget window and the click-through seed overlay
  PomodoroTimer.swift   timer logic
  WidgetView.swift      the widget UI, laid out on the design's 1000 x 560 canvas
  SeedBurst.swift       the popping-seeds animation
  Snapshot.swift        dev helper: renders the widget to a PNG
PNGs/                   source artwork layers
Resources/              Info.plist, app icon, exported art
scripts/                icon + art export scripts
build.sh                builds build/Watermelon.app
```
