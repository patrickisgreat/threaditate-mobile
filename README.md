# Threaditate Mobile

Native iOS and Android client for [Threaditate](https://github.com/patrickisgreat/threaditate) — string art from photos. Same algorithm as the web app, packaged as a native mobile experience.

## Stack

- **Flutter** (Dart, latest stable) — single codebase, iOS + Android
- **Rust** via `flutter_rust_bridge` — the string-art algorithm is shared with the web app and called from Dart through FFI
- **Riverpod** for state management _(decision pending — see ARCHITECTURE.md)_
- **Supabase Flutter SDK** for auth, storage, and project sync — same backend as the web app

## Status

Bootstrap phase. The Flutter app is not scaffolded yet — this repo currently contains only the design documents (`CLAUDE.md`, `ARCHITECTURE.md`).

## Quick start

```bash
flutter pub get
flutter run            # picks an attached device or simulator
flutter test           # unit + widget tests
flutter test integration_test/   # integration tests
flutter build ios      # iOS release build
flutter build apk      # Android APK
flutter build appbundle  # Android Play Store bundle
```

_(These commands assume the Flutter project has been created with `flutter create .` and dependencies wired up. See [ARCHITECTURE.md](ARCHITECTURE.md) for the planned structure.)_

## Documentation

- [CLAUDE.md](CLAUDE.md) — project conventions, code standards, testing strategy
- [ARCHITECTURE.md](ARCHITECTURE.md) — design decisions, Rust-sharing strategy, state management

## Related repos

- [threaditate](https://github.com/patrickisgreat/threaditate) — web app (Next.js + Rust/WASM)
