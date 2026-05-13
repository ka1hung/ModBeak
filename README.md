# ModBeak

A modern, cross-platform Modbus toolbox for industrial automation engineers — a contemporary alternative to ModScan.

Built with Flutter for **macOS** and **Windows** desktop. Connect to PLCs, VFDs, IO modules, and smart meters to read/write registers in real time, watch values change, and diagnose communication issues.

> **Status:** early / testing. Expect rough edges.

---

## Features

- Multi-device, multi-watch real-time polling
- Per-table format switching (UInt16 / Int16 / Hex / Float32 / ...) — change the column header, the whole table re-decodes instantly
- Configurable poll interval per watch
- Multi-window layout — pop a watch into its own window, drag it to a second monitor
- Save and reload setups as JSON
- Modern dark/light themes with high information density (designed for engineers used to dense data tables)

See [GUI.md](GUI.md) for the full UX spec.

---

## Install (for testers)

Grab the latest build from the [Releases page](https://github.com/ka1hung/modbeak/releases).

### macOS

1. Download `modbeak-macos-vX.Y.Z.zip`, unzip to get `ModBeak.app`
2. First launch will be blocked by Gatekeeper (the build is unsigned). Either:
   - Go to **System Settings → Privacy & Security**, scroll down, click **Open Anyway**, or
   - Run once: `xattr -cr /path/to/ModBeak.app`

### Windows

1. Download `modbeak-windows-vX.Y.Z.zip` and unzip the whole folder
2. Double-click `ModBeak.exe` (keep the surrounding files — they're required dlls)
3. SmartScreen may warn you — click **More info → Run anyway**

---

## Build from source

Requires [Flutter 3.41.9](https://docs.flutter.dev/release/archive) (stable).

```bash
git clone https://github.com/ka1hung/modbeak.git
cd modbeak
flutter pub get

# Run in dev mode
flutter run -d macos        # or: -d windows

# Release build
flutter build macos --release
flutter build windows --release
```

Build outputs:
- macOS: `build/macos/Build/Products/Release/ModBeak.app`
- Windows: `build\windows\x64\runner\Release\` (whole folder)

---

## Releasing

Release builds are produced automatically by GitHub Actions on tag push:

```bash
git tag v0.1.0
git push origin v0.1.0
```

This kicks off [.github/workflows/release.yml](.github/workflows/release.yml), which builds on `macos-latest` + `windows-latest` in parallel, packages each, and attaches both zips to a new GitHub Release.

---

## Tech stack

Flutter • Riverpod • freezed • pluto_grid • go_router
