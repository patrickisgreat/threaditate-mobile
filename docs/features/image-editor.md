# Image Editor — Adjustments & Presets

The image editor is the user's tool for tuning the source image before it hits the string-art algorithm. It exposes one-tap presets for common cases and a collapsible "Advanced" section with individual sliders. On mobile it lives in the gear-tray bottom sheet (or a full-screen overlay when "Image Adjustments" is tapped).

**Web references:**
- [src/components/ImageEditor/ImageEditor.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/ImageEditor/ImageEditor.tsx) — UI
- [src/services/imageProcessor.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/services/imageProcessor.ts) — pure functions: types, defaults, presets, analysis, processing pipeline

---

## The `ImageSettings` shape

The full state object the editor mutates:

```ts
interface ImageSettings {
  brightness: number;   // -100 to 100,  default 0
  contrast: number;     // -100 to 100,  default 0
  shadows: number;      // -100 to 100,  default 0   (lifts/crushes dark areas)
  highlights: number;   // -100 to 100,  default 0   (lifts/crushes bright areas)
  gamma: number;        //  0.2 to 5.0,  default 1.0 (nonlinear brightness curve)
  vignette: number;     //    0 to 100,  default 0   (edge darkening)
  outputMin: number;    //    0 to 255,  default 0   (darkest output)
  outputMax: number;    //    0 to 255,  default 255 (lightest output)
  toonEnabled: boolean; // toggle
  toonMode: 'posterize' | 'smooth' | 'bold';  // default 'smooth'
  toonStrength: number; // 0.0 to 1.0, default 0.7   (blend with original)
}
```

Default settings are `DEFAULT_SETTINGS` in `imageProcessor.ts`. Mirror this exactly in Dart — preferably as a `freezed` class so equality and `copyWith` come for free.

---

## Presets

Tap a preset → its settings shallow-merge into the current `ImageSettings` (i.e., `{...current, ...preset.settings}`). Presets only set the fields they care about; everything else stays.

| Name | Description | Settings |
|---|---|---|
| **Default** | Standard processing for most images | `{}` (resets nothing — just identity) |
| **High Contrast** | Boost contrast for flat images | `contrast: 30, shadows: -20, highlights: 20` |
| **Portrait** | Optimized for faces — softer shadows + subtle vignette | `contrast: 15, shadows: 20, highlights: -10, gamma: 1.1, vignette: 25` |
| **Low Light** | Brighten dark photos | `brightness: 25, shadows: 40, gamma: 0.8` |
| **Backlit** | Fix silhouettes from backlit photos | `brightness: 15, shadows: 50, highlights: -30` |
| **Dramatic** | High contrast, deep blacks, strong vignette | `contrast: 50, shadows: -30, outputMax: 160, vignette: 40` |

There are exactly 6 presets. They render as a 2×3 grid on mobile or a horizontal scroll-snap row, with the preset name + description + selected indicator.

---

## Suggestions (auto-analysis)

When a new image is loaded, `analyzeImage(imageData)` computes:

- `luminanceMin`, `luminanceMax`, `luminanceAvg`, `luminanceStdDev`
- `histogramPeaks` — local maxima in the luminance histogram
- Flags: `isLowContrast`, `isBacklit`, `isDark`, `isBright`

Luminance uses ITU-R BT.709: `0.2126*R + 0.7152*G + 0.0722*B`.

If any flag is true, the UI shows a **Suggestions** badge above the preset row with a one-tap "Apply" button. Apply merges the suggested settings into the current state.

The exact `suggestSettings(analysis)` rules live in [src/services/imageProcessor.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/services/imageProcessor.ts). **Re-read that function when implementing the mobile equivalent** — the thresholds and merged settings are detailed and worth getting right.

For Flutter, you have two options:

1. **Port the analysis to Dart.** All pure math; ~150 lines. Use `image` package to decode and iterate pixels.
2. **Call into Rust via FFI.** The Rust crate doesn't currently expose `analyze_image`, but it could — and it'd be faster on large images.

Pick (1) first for v1 simplicity; revisit if it's a bottleneck on 12MP+ images.

---

## Slider semantics

Each slider applies a transform to the cropped image. The pipeline order matters — apply them in this sequence:

1. **Brightness** — linear shift. `pixel + brightness * 1.5` (web scales -100..100 to roughly ±150 luminance units).
2. **Contrast** — pivot around 128. `(pixel - 128) * factor + 128` where `factor = 1 + contrast / 100`.
3. **Shadows** — lift or crush the lower half of the tonal range. Negative values push darks toward black; positive lift them toward gray.
4. **Highlights** — symmetric, applied to the upper half of the range.
5. **Gamma** — nonlinear curve. `pixel = 255 * pow(pixel / 255, 1 / gamma)`. Values < 1 brighten midtones; > 1 darken.
6. **Output min/max** — clamp range. `pixel = remap(pixel, [0, 255] → [outputMin, outputMax])`. Used to crush blacks (outputMin > 0) or whites (outputMax < 255) for stylistic effect.
7. **Vignette** — radial darkening multiplier centered on the cropped image. Strength scales 0–1 from `vignette / 100`.
8. **Toon filter** — if enabled, apply a posterize/smooth/bold variant and blend with the un-tooned result by `toonStrength`.

**Important:** the algorithm consumes a **grayscale** image. The image editor's job is to produce the best possible single-channel input. Color shifts (saturation, temperature, tint) don't exist in the web app's settings — earlier feedback may have mentioned them but they aren't in `ImageSettings` today. **Don't add them to mobile without confirming with the user first.**

The exact slider math is in `imageProcessor.ts` — refer to it directly:

```bash
gh api repos/patrickisgreat/threaditate/contents/src/services/imageProcessor.ts \
  --jq '.content' | base64 -d > /tmp/imageProcessor.ts
```

---

## UI layout

### Desktop

```
┌────────────────────────────────────────┐
│ Image Adjustments                      │
├────────────────────────────────────────┤
│ [Default][High Contrast][Portrait]     │
│ [Low Light][Backlit][Dramatic]         │
├────────────────────────────────────────┤
│ ▼ Advanced                             │
│  Brightness   [─────●─────] 0          │
│  Contrast     [─────●─────] 0          │
│  Shadows      [─────●─────] 0          │
│  ...                                   │
│  ▢ Toon Filter                         │
└────────────────────────────────────────┘
```

### Mobile

Lives in the gear-tray bottom sheet OR a full-screen "Image Adjustments" overlay (`isAdvancedExpanded`). The overlay design lets the user see the preview circle above while sliders are pinned to the bottom.

---

## Debounce

Adjustments are expensive — every change re-runs the algorithm. The web app debounces slider changes by **1200 ms** (release-time, not on every value change). Use the same value on mobile to keep the UX predictable.

Implementation: on `onChangeEnd` of a slider (Flutter's `Slider` widget exposes this directly), schedule the re-process. Don't reprocess on `onChanged`.

---

## Persistence

Image settings are NOT persisted to Supabase. They live only on the planning page and are baked into the rendered output via the algorithm. The project row records the algorithm parameters (pin count, min distance, line weight, max lines) — not the image-editor sliders. If a user revisits a project, the line sequence is already final; the source image is stored as-is.

For Flutter, mirror this: `ImageSettings` is local UI state, never serialized.

---

## Mobile deviations

- **Sliders use Material's `Slider`** with `divisions: 200` so users can land on exact integer values without fiddling.
- **Presets** render as a horizontal `ListView.builder` with a `SnapPhysics` so they feel like a carousel.
- **Toon mode selector** is a `SegmentedButton` (Material 3) with three options.
- **Image preprocessing runs on a Dart isolate** (`compute()`) so the UI doesn't freeze during the 1200 ms reprocess.
- **No `Apply Suggestions` flash** — show the suggestion badge as a `Banner` widget at the top of the screen, not inline above the presets.

---

## Open items from user feedback

- **Item #9**: the upload UI has a min-size hint ("must be at least 200×200") but no max-size hint. Adding "(max 8 MB)" to the file picker dialog or upload card is trivial.
- **Item #5**: a 2000×1500 photo can't be zoomed enough to fill the crop ring. Investigate `maxZoom` calculation in the cropper — likely the formula doesn't account for non-square source aspect ratios properly. Confirm and fix before shipping mobile.
