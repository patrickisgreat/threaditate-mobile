# Architecture

This document captures the high-level design decisions for the Threaditate mobile client. Update it when a decision is revisited — don't let it drift from reality.

---

## Why Flutter, not React Native

- **Single codebase, two platforms.** Same reason React Native would have been considered.
- **No JavaScript bridge.** Flutter compiles to native ARM code; React Native ships a JS runtime and shuttles UI updates over a serialized bridge. For a thread-art visualizer that animates pin-to-pin lines, the difference matters.
- **Better Rust FFI story.** [`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge) is the most mature and ergonomic Dart ↔ Rust bridge generator. It lets us call the existing string-art crate directly from Dart with type-safe bindings. React Native's Rust story (Turbomodules + manual bridging) is workable but rougher.
- **Dart's analyzer and null safety** give a TypeScript-like experience without the looseness of `any` escape hatches.

The trade-off vs. **native Swift + Kotlin** is one fewer codebase at the cost of Flutter's rendering layer (skia/impeller). The trade-off was deemed worth it for a small team.

---

## Sharing the Rust algorithm

The string-art algorithm lives in the web repo today at [`src/services/string-art-wasm/`](https://github.com/patrickisgreat/threaditate/tree/main/src/services/string-art-wasm) and is compiled to WASM for the web. The mobile app needs to call the **same Rust crate** through FFI.

There are three viable approaches. **The decision is pending.** Pick one early — switching later is more painful than it sounds.

### Option A — Extract the crate to its own repo

Move the Rust crate out of `threaditate` into a new repo `threaditate-string-art`. Both the web app (as a git dependency or via a built artifact) and the mobile app (via `flutter_rust_bridge`) consume it.

**Pros:** clean separation, both client repos are equal consumers, the crate can have its own versioning and CI (cargo test, cargo bench, audit).
**Cons:** one more repo to maintain; the web app needs a build step to fetch/compile the crate; coordinating breaking changes across two consumers takes discipline.

### Option B — Git submodule pointing at threaditate

The mobile repo adds the web repo as a submodule and references `threaditate/src/services/string-art-wasm` from `flutter_rust_bridge` config.

**Pros:** zero changes to the web repo; the crate stays where it is today.
**Cons:** submodules are fragile and unfamiliar to most contributors; coupling the mobile repo to the entire web repo means every web commit changes the submodule pointer; CI cache stories get awkward.

### Option C — Private crate registry

Publish the crate to a private registry (e.g. [`cargo-quickregistry`](https://crates.io/crates/cargo-quickregistry), Cloudsmith, or a self-hosted alt-registry) and consume from both client repos with `cargo` dependencies.

**Pros:** the most "production"-grade option — proper versioned releases, semver, deprecation paths.
**Cons:** infrastructure to set up; overkill if you're a small team; not free if you go with a managed registry.

### Recommendation

**Option A** is the cleanest long-term. The web repo's Rust crate is already self-contained — extracting it is mostly a `git filter-repo` plus a small refactor of the build script. Both consumers benefit from a clear contract at the crate boundary.

**Option B** is fine for the first month if you want to ship a Flutter prototype before committing to the split. Plan to migrate to A when the mobile app exits prototype.

---

## State management

**Provisional choice: [Riverpod](https://riverpod.dev) (`flutter_riverpod` package).**

Reasons:

- Compile-time-safe dependency injection.
- No `BuildContext` coupling — providers can be read from anywhere, including async logic and FFI callbacks.
- Mature, well-documented, very common in modern Flutter codebases.
- Pairs well with `freezed` for immutable state classes.

Alternatives considered:

- **BLoC** — heavier, more boilerplate, stream-based. Excellent for very complex async flows but overkill here.
- **Provider** — older, simpler, lacks Riverpod's compile-time safety.
- **Plain `ChangeNotifier`** — too primitive for app-level state once auth + active project + playback all coexist.

Confirm this choice in the first week of scaffolding. Once `freezed`/`riverpod` codegen is wired up, switching is non-trivial.

---

## Project structure (planned)

```
lib/
├── main.dart                   # Entry point, ProviderScope setup
├── app/                        # App shell — routing, theme, top-level providers
│   ├── router.dart             # go_router config (or similar)
│   ├── theme.dart
│   └── app.dart
├── features/                   # Vertical feature slices
│   ├── auth/                   # Sign in, sign up, session
│   ├── projects/               # List, create, open existing
│   ├── editor/                 # Image picker + crop + adjustments (Threaditate's "planning" flow)
│   ├── player/                 # Pin-to-pin playback visualizer
│   └── settings/               # Voice, speed, theme, etc.
├── services/                   # Stateful, side-effectful
│   ├── string_art_ffi.dart     # flutter_rust_bridge generated bindings (Rust core)
│   ├── supabase_client.dart    # Auth + storage wrapper
│   └── project_repository.dart # CRUD around Supabase
├── models/                     # Plain data classes (freezed)
├── widgets/                    # Reusable across features
└── utils/                      # Pure helpers

test/                           # Unit + widget tests (fast)
integration_test/               # Full-app integration (Flutter's integration_test package)
ios/                            # Xcode project — touched rarely
android/                        # Gradle project — touched rarely
rust/                           # flutter_rust_bridge entry point + Cargo manifest pointing at the shared crate
```

### Why feature folders, not type folders

A `features/player/` folder containing its widgets, controllers, and providers together is easier to reason about than a `widgets/` directory with every screen's widgets jumbled. Keep feature folders small enough to fit in your head; if one grows past ~10 files, split it.

---

## Routing

**Provisional choice: [`go_router`](https://pub.dev/packages/go_router).**

Declarative, deep-linking-friendly, Riverpod-compatible. The alternative (`auto_route`) generates code but adds a build step; `go_router` is the simpler default.

---

## Networking and persistence

- **Supabase Flutter SDK** ([`supabase_flutter`](https://pub.dev/packages/supabase_flutter)) — same auth + Postgres + storage backend as the web app.
- **`flutter_secure_storage`** for tokens that must survive app restart.
- **`shared_preferences`** for non-sensitive prefs (last selected voice, playback speed, etc.).
- **`path_provider` + filesystem** for caching cropped images locally.

RLS policies on Supabase tables apply equally to mobile clients — there's no second API surface to maintain.

---

## Rendering the StringCircle

The web app uses an HTML `<canvas>`. Flutter's equivalent is `CustomPainter` over a `CustomPaint` widget — direct access to the underlying skia/impeller canvas with no per-frame allocation overhead.

The Rust crate returns a sequence of `(from_pin, to_pin)` pairs and the canvas geometry parameters. Dart side draws lines between pin coordinates using `Canvas.drawLine` inside `CustomPainter.paint`. For the playback animation, advance a current-line index in a `Ticker` and repaint each frame.

Expect the per-frame painter to handle thousands of line draws cheaply — Flutter's skia backend is well-tuned for this kind of workload.

---

## Audio (voice playback)

The web app uses the Web Audio API for the per-pin voice clips. On Flutter, [`audioplayers`](https://pub.dev/packages/audioplayers) or [`just_audio`](https://pub.dev/packages/just_audio) — `just_audio` is the more capable of the two and handles concurrent playback better. Confirm with a small spike before committing.

---

## CI / CD

- **CI**: GitHub Actions, two parallel jobs — `flutter test` + `flutter analyze` + iOS build + Android build.
- **Distribution (iOS)**: TestFlight via Fastlane or `flutter build ipa` + manual upload initially.
- **Distribution (Android)**: Internal track on Play Console via Fastlane or manual upload.
- **Code signing**: store certificates in 1Password or GitHub Secrets; never commit them. Apple certificates expire — set a calendar reminder.

---

## Decisions to make in the first week

In rough priority order:

1. **Rust-sharing strategy** — A, B, or C above.
2. **Confirm Riverpod** or pick an alternative.
3. **Choose audio package** — `just_audio` vs `audioplayers`.
4. **Apple Developer enrollment** if not already done (paid).
5. **Google Play Console enrollment** if not already done (one-time fee).
6. **Set up Fastlane** _(or commit to manual builds for the first few releases)_.

---

## Things we deliberately punted

- **No analytics** in the first ship. Add later via a privacy-respecting tool (Plausible-style, or self-hosted PostHog) — don't reach for Firebase reflexively.
- **No crash reporting** in the first ship. `flutter test` + manual TestFlight QA is enough for a v1.
- **No web target from Flutter.** The Next.js web app already exists; we don't need two web frontends.
- **No desktop targets.** Flutter supports them but it's a distraction.
