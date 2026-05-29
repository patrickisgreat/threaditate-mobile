# Algorithm — FFI Contract

The string-art algorithm is implemented in Rust ([web repo: src/services/string-art-wasm/](https://github.com/patrickisgreat/threaditate/tree/main/src/services/string-art-wasm)). The web app calls it via WebAssembly; the mobile app calls it via [`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge) FFI bindings. **Same crate, same algorithm, two integration paths.**

This doc covers the user-facing contract — what knobs exist, what they do, what the function signatures look like. The internals (greedy pin selection, penalty calculation, preprocessing decision tree, etc.) are the algorithm's business and don't need to be re-implemented on mobile.

**Web references:**
- [src/services/string-art-wasm/src/lib.rs](https://github.com/patrickisgreat/threaditate/blob/main/src/services/string-art-wasm/src/lib.rs) — crate root, `wasm_bindgen` entry
- [src/services/string-art-wasm/src/types.rs](https://github.com/patrickisgreat/threaditate/blob/main/src/services/string-art-wasm/src/types.rs) — `StringArtGenerator` struct, `StringArtState`, enums
- [src/services/string-art-wasm/src/string_art.rs](https://github.com/patrickisgreat/threaditate/blob/main/src/services/string-art-wasm/src/string_art.rs) — main algorithm (~2000 lines)
- [src/services/string-art.service.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/services/string-art.service.ts) — JS wrapper, singleton, EventEmitter

---

## What the user controls

| Parameter | Range | Default | Who sets it |
|---|---|---|---|
| `pin_count` | 1 to ~600 | 240 | Admin only (per-tenant config) |
| `max_lines` | `MIN_LINES`–`MAX_LINES` (100–8000 typical) | 4000 | **User**, via the circular slider on planning |
| `line_weight` | 1–50 | 10 | **User**, via advanced controls |
| `min_distance` | 1–pin_count/2 | 40 | **User**, via advanced controls |
| `lightness_penalty` | 0.0–2.0 | 0.7 | Admin only |
| `line_norm` | `TotalSum / PixelCount / WeightedSum` | `PixelCount` | Admin only |
| `attenuation_mode` | `Subtraction / Halving` | `Subtraction` | Admin only |
| `auto_stop_threshold` | 0.0+ or null | null | Admin only |
| `quality_mode` | `standard / enhanced / multipass / parallel` | `enhanced` | Admin only |

**On mobile, expose only the user-facing knobs** (`max_lines`, `line_weight`, `min_distance`). The admin-only knobs come from a config read from Supabase at app start; the mobile user has no UI to change them.

There's also the **importance mask** (RGBA `Uint8List`) and the **toon filter** settings (`toon_enabled`, `toon_mode`, `toon_strength`) — but those are passed as part of image preprocessing, not algorithm config. See [image-editor.md](image-editor.md).

---

## Public function signatures (Rust → Dart)

`flutter_rust_bridge_codegen` will translate the Rust functions into Dart. The signatures you'll care about:

### Generate

```rust
pub fn generate_string_art(
    image_rgba: Vec<u8>,
    width: u32,
    height: u32,
    params: AlgorithmParams,
    importance_mask: Option<Vec<u8>>,
) -> StringArtResult;

pub struct AlgorithmParams {
    pub pin_count: u32,
    pub max_lines: u32,
    pub line_weight: u32,
    pub min_distance: u32,
    pub lightness_penalty: f32,
    pub line_norm: LineNorm,
    pub attenuation_mode: AttenuationMode,
    pub auto_stop_threshold: Option<f32>,
    pub quality_mode: QualityMode,
    pub toon: Option<ToonSettings>,
}

pub struct StringArtResult {
    pub line_sequence: Vec<u32>,  // flattened pairs: [from, to, from, to, ...]
    pub total_lines: u32,
    pub pin_count: u32,
    pub elapsed_ms: u64,
}
```

(These signatures are illustrative — confirm against the actual Rust crate when wiring up FFI. The crate may have evolved.)

Dart side (after codegen):

```dart
final result = await api.generateStringArt(
  imageRgba: imageBytes,
  width: 300,
  height: 300,
  params: AlgorithmParams(
    pinCount: 240,
    maxLines: 4000,
    lineWeight: 10,
    minDistance: 40,
    lightnessPenalty: 0.7,
    lineNorm: LineNorm.pixelCount,
    attenuationMode: AttenuationMode.subtraction,
    autoStopThreshold: null,
    qualityMode: QualityMode.enhanced,
    toon: null,
  ),
  importanceMask: null,
);

final lineSequence = result.lineSequence;
// Pass lineSequence to StringCircle for rendering.
```

### Image preprocessing

```rust
pub fn analyze_image(image_rgba: Vec<u8>, width: u32, height: u32) -> ImageAnalysis;

pub struct ImageAnalysis {
    pub luminance_min: f32,
    pub luminance_max: f32,
    pub luminance_avg: f32,
    pub luminance_std_dev: f32,
    pub is_low_contrast: bool,
    pub is_backlit: bool,
    pub is_dark: bool,
    pub is_bright: bool,
}

pub fn apply_image_settings(
    image_rgba: Vec<u8>,
    width: u32,
    height: u32,
    settings: ImageSettings,
) -> Vec<u8>;
```

(See [image-editor.md](image-editor.md) for the `ImageSettings` field semantics.)

If the crate doesn't currently expose `analyze_image` / `apply_image_settings` — and at time of writing it likely doesn't, the web app ports them in [src/services/imageProcessor.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/services/imageProcessor.ts) — then either:

1. **Port to Dart** (~150 lines of pure math, easiest).
2. **Add to the Rust crate** and re-generate bindings (best long-term, since the web app would benefit too).

Pick (1) for v1; revisit later.

---

## Input image size

The web app **resizes the image to 300 px** before passing it to the algorithm (the `IMAGE_SIZE` constant in [src/services/string-art.service.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/services/string-art.service.ts)). Mirror this on mobile — don't pass 4 MP photos straight to FFI.

```dart
// Resize via the `image` package
final resized = img.copyResize(decoded, width: 300, height: 300);
final bytes = img.encodePng(resized);
// Or skip encoding and pass the raw RGBA bytes directly:
final rgba = resized.toUint8List(format: img.Format.uint8, numChannels: 4);
```

---

## Threading

The web app runs WASM in a Web Worker to keep the main thread free for UI. If the worker fails to initialize, it falls back to main-thread execution.

On Flutter, run FFI calls in a **separate isolate** via `compute()`:

```dart
final result = await compute(_runFFI, params);

StringArtResult _runFFI(_Params p) {
  return api.generateStringArt(...);  // blocking call on the isolate
}
```

If the algorithm takes > 100 ms (it will, on most images), the UI should show a "Rendering..." indicator. The web app uses `isProcessing` state for this; mirror it on mobile.

---

## Cross-compilation targets

The Rust crate must be compiled for:

| Platform | Targets |
|---|---|
| iOS device | `aarch64-apple-ios` |
| iOS simulator (Apple Silicon) | `aarch64-apple-ios-sim` |
| iOS simulator (Intel) | `x86_64-apple-ios` |
| Android device (modern) | `aarch64-linux-android` |
| Android device (older) | `armv7-linux-androideabi` |
| Android emulator | `x86_64-linux-android` |

The `flutter_rust_bridge` workflow with `cargo-ndk` (Android) and the Xcode build phase (iOS) handles this; see the [flutter_rust_bridge book](https://cjycode.com/flutter_rust_bridge/) for the canonical setup.

The web app's crate uses `getrandom` with the `js` feature. **For non-wasm targets that won't apply** — confirm the `Cargo.toml` doesn't lock the wasm-only features when compiling for native.

---

## What NOT to expose to the mobile user

Even if `flutter_rust_bridge` codegens bindings for every public Rust function, **don't surface these in the mobile UI**:

- `lightness_penalty`, `line_norm`, `attenuation_mode`, `auto_stop_threshold`, `quality_mode` — admin-only.
- `pin_count` — fixed per Supabase config; don't let users change it on the device.
- Any "test mode" / snapshot capture entry points — web-only dev tooling.

Read the algorithm settings from Supabase at app start (a single row in `algorithm_settings` keyed by tenant) and use the values to call FFI. Don't subscribe to changes for live admin-tuning — that's a SKIP feature.

---

## Algorithm output shape

`line_sequence` is a flat `Vec<u32>` where consecutive pairs define lines:

```
[0, 50, 50, 120, 120, 180, ...]
 |   |   |    |    |    |
 line 0    line 1    line 2
```

So `connectionIndexes[i]` and `connectionIndexes[i+1]` are the pins for line `i`, where each line shares an endpoint with the next (a continuous thread).

`total_lines = line_sequence.length / 2 + 1` (or whatever the actual count is — verify with the crate's docs).

When rendering, walk pairwise from index 0.

---

## Performance expectations

On the web:

- 300×300 image, 4000 lines, default params: **~2–4 seconds** on a modern laptop.
- On a 2018-era iPhone, expect 6–10 seconds via FFI.
- The "enhanced" quality mode adds ~30 % runtime over "standard"; "multipass" can double it.

For mobile, **default to `quality_mode: enhanced`** (same as web) and surface a "Standard / Enhanced" toggle only if admin-config indicates it should be exposed.

---

## Where to learn more

The web repo's [CLAUDE.md § The String Art Algorithm (Rust/WASM)](https://github.com/patrickisgreat/threaditate/blob/main/CLAUDE.md) has a longer write-up: the penalty formula, the greedy main loop, recency buffer, preprocessing decision tree, and known areas for improvement (beam search, simulated annealing, anti-aliased rasterization).

Fetch it directly when you need it:

```bash
gh api repos/patrickisgreat/threaditate/contents/CLAUDE.md \
  --jq '.content' | base64 -d
```
