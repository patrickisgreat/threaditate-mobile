# CLAUDE.md — Threaditate Mobile

## What is this project?

Threaditate Mobile is the native iOS and Android client for [Threaditate](https://github.com/patrickisgreat/threaditate) — an app that converts photos into string art patterns. Users upload an image, an optimized sequence of thread connections is generated, and a player visualizes each line being drawn.

This repo is the **mobile client only**. The web app lives in `threaditate`. Both share the same string-art algorithm (a Rust crate compiled to WASM on web, called via FFI on mobile) and the same Supabase backend.

## Tech Stack

- **Flutter** (latest stable, Dart 3.x, sound null safety)
- **Rust** via [`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge) — the string-art algorithm is called from Dart through FFI bindings
- **Riverpod** for state management (`flutter_riverpod` + `riverpod_generator`)
- **`freezed`** for immutable data classes + sealed unions
- **`go_router`** for routing
- **Supabase Flutter SDK** (`supabase_flutter`) — auth, storage, Postgres
- **Testing**: Flutter's built-in `test` (unit + widget), `integration_test` (E2E)

See [ARCHITECTURE.md](ARCHITECTURE.md) for the why behind each choice.

## Common Commands

```bash
flutter pub get                     # Install dependencies
flutter run                         # Run on attached device / simulator
flutter test                        # Run unit + widget tests
flutter test integration_test/      # Run integration tests
flutter analyze                     # Static analysis (must pass in CI)
dart format .                       # Format code (must pass in CI)
dart format . --output=none --set-exit-if-changed .   # Check formatting

# Codegen (when freezed/riverpod/flutter_rust_bridge models change)
dart run build_runner build --delete-conflicting-outputs

# Builds
flutter build ios --release
flutter build apk --release
flutter build appbundle --release   # Play Store
flutter build ipa                   # iOS for App Store
```

### Regenerating Rust ↔ Dart bindings

```bash
flutter_rust_bridge_codegen generate
```

Run this after touching the Rust crate's public API. The generated Dart bindings live in `lib/services/string_art_ffi.dart` (or whatever path is set in the codegen config). Commit generated files.

## Project Structure

```
lib/
├── main.dart                   # Entry point — wraps app in ProviderScope
├── app/                        # App shell — routing, theme, top-level providers
├── features/                   # Vertical feature slices
│   ├── auth/                   # Sign in / up / session
│   ├── projects/               # Project list, create, open
│   ├── editor/                 # Image picker, crop, adjustments
│   ├── player/                 # Pin-to-pin playback visualizer
│   └── settings/               # Voice, speed, theme
├── services/                   # Stateful side-effectful (FFI, Supabase, audio)
├── models/                     # Plain data classes (freezed)
├── widgets/                    # Reusable across features
└── utils/                      # Pure helpers

test/                           # Unit + widget tests
integration_test/               # E2E with Flutter's integration_test package
ios/                            # Xcode project (rarely touched directly)
android/                        # Gradle project (rarely touched directly)
rust/                           # flutter_rust_bridge entry + Cargo manifest
```

Vertical feature folders: a `features/player/` directory contains its widgets, controllers, providers, and feature-local models together. Don't scatter a feature across `lib/widgets/` + `lib/providers/` + `lib/models/`.

## Environment

- A `.env` file is read by `flutter_dotenv` at startup. Required keys:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- For local dev with auth disabled (mirrors `NEXT_PUBLIC_AUTH_ENABLED=false` on web): set `AUTH_ENABLED=false` in `.env`.
- `.env` is gitignored. CI sets these via GitHub Secrets.

## Conventions

- **Sound null safety** throughout. No `// ignore: ...` for nullability issues — fix the type.
- **`dart format` + `flutter analyze`** enforced in CI. No exceptions.
- **`flutter_lints` + `very_good_analysis`** for opinionated linting.
- **`freezed` classes for state.** Use sealed unions for state machines (loading / data / error).
- **One widget per file** for non-trivial widgets. Tiny private widgets can live in the same file as their parent.
- **Folder naming**: `snake_case`. **File naming**: `snake_case.dart`. **Class naming**: `PascalCase`.

---

## Code Standards

### Clean Code

- **DRY**: Do not repeat yourself. Extract shared logic into widgets, mixins, or utility functions. If you see duplication, refactor it.
- **SRP (Single Responsibility Principle)**: Every widget, function, and class should do one thing. If a function needs an "and" to describe it, split it.
- **Small, focused widgets**: A widget's `build` method should be readable in one screen of editor space. Composition over inheritance — extract sub-widgets rather than letting `build` grow unbounded.
- **Never over-engineer**: Write the minimum code needed to solve the problem correctly. No speculative abstractions, premature generalization, or "just in case" code. Simple and clear beats clever.
- **Naming**: Use descriptive, intention-revealing names. Code should read like prose — minimize the need for comments by making the code self-documenting.
- **No dead code**: Remove unused imports, variables, classes, and commented-out code. `dart analyze` flags most of this — fix the warnings rather than suppressing them.

---

## Testing

No PR is mergeable without tests that cover the behavior introduced or changed in that PR.

This is not negotiable. If the code is worth shipping, it is worth testing. If it is too hard to test, that is a signal the code needs to be restructured, not that the test can be skipped.

### The Testing Pyramid

Follow the testing pyramid. Violations of the pyramid's proportions are a code smell.

```
        /\
       /  \
      /E2E \
     /------\
    /  Widget\
   / / Integ. \
  /-------------\
 /     Unit      \
/-----------------\
```

- **Unit tests** form the base — pure Dart logic, no Flutter, no I/O. Use Dart's built-in `test` package. They should be _fast_ — running the full unit suite should feel instant.
- **Widget tests** sit in the middle — Flutter's `flutter_test` package renders a widget tree without a real device. Verify widget behavior, callbacks, and rendering. Significantly faster than integration tests.
- **Integration tests** at the top — `integration_test` package runs the full app on a device/simulator. Reserve these for critical user journeys (sign in, generate a pattern, play back, sign out).

### Unit & Widget Tests

- Every new function, class, and widget gets tests.
- Test **behavior**, not implementation. If your test breaks when you rename an internal variable, it is testing the wrong thing.
- Use **mocks** at integration boundaries: Supabase client, file system, FFI calls, audio playback. Use [`mocktail`](https://pub.dev/packages/mocktail) — no codegen, type-safe, the de-facto Flutter mocking library.
- Do **not** mock your own logic. If you find yourself mocking an internal collaborator, the design needs work.
- A test that cannot fail is not a test. After writing a test, verify it can fail by temporarily breaking the implementation.

### Integration Tests

- Use the [`integration_test`](https://docs.flutter.dev/cookbook/testing/integration/introduction) package — bundled with Flutter, no extra setup.
- Run on a real simulator/device in CI. Headless emulation works fine for Android; iOS needs a real simulator on a macOS runner.
- Test the **critical paths** a real user would take: auth flow, project creation, the full upload → generate → play sequence. Don't write integration tests for every screen.
- No `Future.delayed(Duration(seconds: …))` for timing. Use `tester.pumpAndSettle()` or wait on a specific finder. Sleeps create flaky tests.
- Tests must be **deterministic**. A test that passes 9 times out of 10 is broken. Flaky tests erode trust and eventually get ignored.

### Coverage

- `flutter test --coverage` produces `coverage/lcov.info`. Track it in CI.
- Coverage is a floor, not a goal. 100% coverage with meaningless tests is worthless. 80% coverage with tests that actually verify behavior is valuable.
- New code should not lower coverage. CI should enforce this.

### What is not an acceptable excuse

- **"It's just a small change."** Small changes break things. Small tests are also small.
- **"It's hard to test."** Make it testable. Difficulty testing is almost always a design signal.
- **"I'll add tests in a follow-up PR."** You won't. No one ever does. Tests go in the same PR or the PR does not merge.
- **"The existing tests cover it."** Show that they do — call out the existing test in the PR description. If they don't, add tests.
- **"It's just a UI change."** New UI gets widget tests. Visually-meaningful changes get integration tests.

---

## Security

- **Security is a priority, not an afterthought.**
- Never commit secrets, tokens, or credentials. Use `.env` for local dev; CI injects via secrets.
- **Validate user input** at boundaries — file pickers (size, mime type), text fields (length, format), URL params (deep links).
- **Supabase RLS policies** are the authoritative authorization layer. Trust them — don't duplicate ACL logic on the client.
- **FFI from Dart to Rust** is a trust boundary going _into_ Rust. The Rust crate already validates array lengths, dimensions, and parameter ranges — keep it that way.
- **Image picker permissions**: request photo library / camera permissions only when needed, explain why with a clear `NSPhotoLibraryUsageDescription` (iOS) and runtime rationale (Android).
- **Deep link handlers** are an attack surface. Sanitize any URL params before acting on them. Never `eval`/`Function.apply`-style construct on user-controlled strings.
- **`flutter pub outdated --mode=null-safety` and `flutter pub upgrade --dry-run`** regularly. Audit transitive dependencies before bumping major versions.

---

## Git Workflow

- **Always work from a feature branch.** Never commit directly to `main`. Use descriptive names like `feat/player-swipe-gestures` or `fix/ios-keyboard-overlap`.
- **Commit often.** Small, frequent commits, each a logical unit of work. Don't batch unrelated changes.
- **Conventional commit messages.** Use prefixes:
  - `feat:` — New feature or capability
  - `fix:` — Bug fix
  - `refactor:` — Code restructuring with no behavior change
  - `test:` — Adding or updating tests
  - `chore:` — Build, CI, dependency updates, tooling
  - `docs:` — Documentation changes
  - `perf:` — Performance improvements
  - `style:` — Formatting only
- **Submit PRs back to `main` using `gh pr create`.** PRs need clear titles using the same conventional prefixes. Include a summary and a test plan in the body.
- **The user reviews all PRs before merge.** Do not merge PRs autonomously.
- **NEVER add `Co-Authored-By` or "Generated with Claude Code" to commits or PRs.**

---

## Dart & Flutter

### Tooling & CI Enforcement

- `flutter analyze` must pass — no warnings, no infos suppressed without a good comment.
- `dart format --set-exit-if-changed .` must pass.
- `flutter test` must pass on every PR.
- Run iOS and Android builds in CI to catch platform-specific breakage.
- `flutter pub outdated` weekly; don't let dependencies drift more than a minor version behind.

### Type Discipline

- **Never use `dynamic`.** Use `Object?` and narrow it properly with `is` checks, or define a concrete type. `dynamic` is a silent type hole — it defeats the analyzer's purpose entirely.
- **Lean on `freezed`** for data classes, unions, and `copyWith`. Hand-written equality / hashcode / serialization is error-prone and noisy.
- **Use `sealed class` for state machines.** Pattern-match exhaustively; the analyzer will flag missing cases.
- **`required`** named parameters whenever a field has no sensible default. Don't paper over missing values with default `null`s.
- **Prefer `const` constructors.** They enable widget identity preservation and prevent rebuilds. The analyzer suggests them; accept its suggestions.

### Async

- **Every `Future` must be awaited, returned, or explicitly handled with `unawaited(…)`.** Don't drop futures on the floor — `flutter_lints` will flag this.
- **Prefer `async/await` over `.then()`** for readability.
- **Catch errors at boundaries**, not at every `await`. Wrap the boundary (e.g. a controller method that handles a user action) in a single try/catch.
- **Cancel work on widget dispose.** `StreamSubscription`s and `Timer`s should be cancelled in `dispose()`. Riverpod's `ref.onDispose` covers provider cleanup automatically.

### Widgets & State

- **Stateless > Stateful.** Reach for `StatefulWidget` only when local widget state is genuinely needed (animation controllers, focus nodes, text editing controllers). Anything else goes in a provider.
- **Riverpod providers** for app/feature state. Avoid `InheritedWidget` directly — Riverpod is the better abstraction.
- **`ConsumerWidget` and `HookConsumerWidget`** instead of manually wiring up Riverpod inside `build`.
- **Pass data down, callbacks up.** Don't reach across the widget tree with global state for things that have a clear local owner.

### Performance

- Default to **`const` widgets** wherever the analyzer suggests. Each one avoids a rebuild.
- For lists, use **`ListView.builder`** (lazy) not `ListView(children: ...)` (eager).
- Profile with **DevTools** when a frame drop happens. Don't guess.

### Iteration Workflow

- Write the feature the straightforward way first. Use `setState` and local state if it lets you ship a working slice faster.
- Once it works, refactor: pull state into a Riverpod provider, extract sub-widgets, tighten types.
- Run `flutter analyze` and `dart format` before committing. CI will reject anything that fails them.

### Reviewer Empathy

- `dart format`, no suppressed lints, explicit types on public APIs, and `const`-where-possible all serve the same purpose: they let a reviewer spend their attention on _what_ your code does, not _how_ it's written.
- The Dart analyzer is a communication tool as much as a correctness tool. Write with the reviewer (and future you) in mind.

---

## Rust (shared crate)

The Rust string-art crate lives in a shared location consumed by both this mobile client and the web client. **See [ARCHITECTURE.md](ARCHITECTURE.md) for the sharing strategy.** When you edit the Rust crate, the existing standards in the web repo's [CLAUDE.md](https://github.com/patrickisgreat/threaditate/blob/main/CLAUDE.md#rust) apply:

- `cargo fmt --check` and `cargo clippy -- -D clippy::pedantic` in CI.
- `// SAFETY:` comments on every `unsafe` and `as` cast.
- No bare `.unwrap()` in production code.
- Bubble errors up; log at the call site.

After modifying the Rust crate's public API, regenerate the Dart bindings with `flutter_rust_bridge_codegen generate` and commit the generated `lib/services/string_art_ffi.dart` (or wherever your codegen target is).

---

## Implementing a feature — read these first

This repo is the mobile port of a web app that already exists. **Every user-facing feature has a canonical implementation in the web repo.** Before building a feature here, read the spec for it and cross-check against the web source so you don't miss subtle behaviors.

### Process

1. **Start at [docs/features.md](docs/features.md).** It's the catalog of every user-facing feature in the web app, grouped by area, with mobile-port priorities (MUST / SHOULD / COULD / SKIP) and a status tracker showing what's already been ported.

2. **Read the per-feature spec** at `docs/features/<feature-name>.md` if one exists. These cover the complex flows (player, image editor, planning, painter, etc.) with user flows, edge cases, error states, and references to the web implementation.

3. **Fetch the web implementation** when the spec is ambiguous or when you need to confirm a detail. The web repo is public at `patrickisgreat/threaditate`. Use the `gh` CLI:

   ```bash
   # Read a specific file
   gh api repos/patrickisgreat/threaditate/contents/src/components/Player/Controller/Controller.tsx \
     --jq '.content' | base64 -d

   # Search the web repo for a symbol or string
   gh search code --repo patrickisgreat/threaditate "useResponsiveDiameter"

   # Read the web repo's CLAUDE.md (root-level project standards)
   gh api repos/patrickisgreat/threaditate/contents/CLAUDE.md \
     --jq '.content' | base64 -d
   ```

   These work without cloning the repo. Use them freely — round-tripping to GitHub is cheaper than guessing at a feature's behavior.

4. **Don't assume the spec is authoritative when it conflicts with the web source.** The web code is the source of truth for behavior; docs/features can drift. If you spot a discrepancy, update the spec in the same PR that implements the feature.

### What goes in docs/features/ specs

Each spec captures, for one feature:

- **User flow** — what the user does, step by step
- **Inputs** — fields, controls, gestures
- **Outputs** — what changes on screen, what's persisted
- **Edge cases** — empty state, error state, network failure, oversized image, etc.
- **Mobile deviations** — where the mobile UX intentionally differs from web (e.g. native image picker instead of drag-and-drop)
- **Web references** — file paths in threaditate that implement this feature

When you ship a new mobile feature, **update docs/features.md's status tracker** in the same PR so the next session knows it's done.

### What's intentionally NOT in the mobile port

The catalog marks several features `SKIP` — they're admin-only or web-development conveniences and don't belong on the mobile app. Don't port them without asking. Examples include the admin algorithm-tuning panel and the test-mode snapshot capture.

---

## Things to know before making changes

- The Supabase schema is shared with the web app. **Schema migrations live in the web repo.** Coordinate.
- The string-art algorithm contract (`generate_lines(image, params) -> Vec<(u32, u32)>`) is shared. If you need to change its signature, update both clients in the same week — don't leave the web app on an old API.
- iOS code signing requires an Apple Developer account ($99/year). Android code signing for Play Store requires a Google Play Console account (one-time $25).
- Flutter version drift between team members causes mystery bugs. Pin the version in `pubspec.yaml`'s `environment.flutter` and use [`fvm`](https://fvm.app) locally.
