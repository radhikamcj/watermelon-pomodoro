# 🍉 Watermelon Pomodoro

A tiny, cute pomodoro timer for macOS that floats on top of every app.

<img src="docs/screenshot.png" width="360" alt="Watermelon Pomodoro widget">

## Features

- Floats above all windows, on every desktop, even over full-screen apps
- Drag it anywhere — it remembers where you left it
- Hover while paused to change the length with **– / +**
- Right-click for quick presets (25 / 50 min focus, 5 / 15 min break) and **Quit**
- The watermelon sleeps while paused and wiggles while you focus
- Plays a chime and switches to a break when a session ends, counting slices done 🍉

## Build & run

Requires macOS 13+ and the Swift toolchain (Xcode or the Command Line Tools: `xcode-select --install`).

```bash
./build.sh
open build/Watermelon.app
```

To keep it around, drag `build/Watermelon.app` into your **Applications** folder.

## Project layout

```
Sources/WatermelonPomodoro/
  main.swift            app entry point (no Dock icon)
  AppDelegate.swift     the floating, always-on-top window
  PomodoroTimer.swift   timer logic and saved settings
  WidgetView.swift      the watermelon UI (SwiftUI)
Resources/              Info.plist and app icon
scripts/make_icon.swift generates the app icon
build.sh                builds build/Watermelon.app
```
