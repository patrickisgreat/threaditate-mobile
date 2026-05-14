# StringCircle — Shared Rendering Primitive

The StringCircle is the visual centerpiece of the app — both the planning page (live preview) and the player page (step-by-step playback) render it. **Both surfaces must produce visually identical output.** Build it once as a reusable widget.

**Web references:**
- [src/components/StringCircle/StringCircle.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/StringCircle/StringCircle.tsx) — wrapper component
- [src/components/StringCircle/CanvasStringCircle.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/StringCircle/CanvasStringCircle.tsx) — canvas paint loop
- [src/components/StringCircle/CanvasStringUtils.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/components/StringCircle/CanvasStringUtils.ts) — pin geometry + draw helpers

---

## Geometry

- **Total pins:** 240 (constant; same as the algorithm).
- **Pin layout:** evenly spaced around the perimeter, starting at the top (angle = `-π/2`).
- **Pin coordinates:**
  ```
  centerX = centerY = diameter / 2 + padding   // padding = 10
  angleStep = 2π / 240
  angle_i = -π/2 + i * angleStep
  x_i = centerX + (diameter / 2) * cos(angle_i)
  y_i = centerY + (diameter / 2) * sin(angle_i)
  ```
- **Canvas size:** `diameter + padding * 2` (so a 340 px diameter renders inside a 360 px canvas, leaving 10 px gutter all around).

Pin index `i = 0` is at 12 o'clock. Index advances clockwise.

---

## Rendering pass

For each repaint:

1. **Clear the canvas.**
2. **Draw the background fill** — a solid circle filling the diameter. Color is grayscale; brightness is a 0.5–1.0 parameter (default **0.7** → `#B3B3B3`). Web rule: `colorValue = round(brightness * 255)`.
3. **Clip subsequent draws to the circle.** `ctx.save()` + `ctx.beginPath()` + `ctx.arc(...)` + `ctx.clip()`.
4. **Draw the 240 pins** — small filled circles at each pin coordinate. Pin radius is `max(1, diameter / 260)`. Color: `#5d5858f0`.
5. **Draw the visible lines** from the connection sequence:
   - Inputs: `connectionIndexes: number[]` (the algorithm output — a flat array where consecutive pairs define lines), `visibleCount: number` (how many lines to render).
   - For each line `i` from 0 to `normalLineCount - 1`: draw a line from pin `connectionIndexes[i]` to `connectionIndexes[i+1]` with the configured `lineColor` and `lineWidth`.
6. **Apply highlight overlay** (player mode only — see below).
7. **Restore** the canvas state (`ctx.restore()`).

---

## Highlight modes

The `highlightMode` prop controls how the most-recent line(s) are emphasized during playback. Three values:

| Mode | Behavior |
|---|---|
| `'none'` | All visible lines drawn with the same color/width. No emphasis. Used when playback is paused at completion or for screenshots. |
| `'one'` | The last drawn line (`visibleCount - 1`) is rendered in **red** at `width = 1` with `cap: round`. |
| `'two'` | The second-to-last line is **red** (`width = 0.5`, `round`) and the last line is the special "lookahead" rendering — `drawLastLine` — typically a brighter accent. The web app uses this mode by default during active playback. |

When `visibleCount` equals `connectionIndexes.length / 2` (i.e., the pattern is complete), highlight is suppressed regardless of mode. The last few lines render with the normal line color so the final image looks clean.

---

## Line style — desktop vs. mobile

The component takes both `lineThickness` / `lineOpacity` (desktop) and `mobileLineThickness` / `mobileLineOpacity`. At runtime, the web app selects based on `window.innerWidth < 768`.

| Setting | Desktop default | Mobile default |
|---|---|---|
| `lineThickness` | 0.14 | 0.08 |
| `lineOpacity` | 1.0 | 0.65 |

The lower mobile values prevent visual clutter when thousands of lines stack at small sizes. Line color is `'rgba(0, 0, 0, opacity)'` when opacity < 1, otherwise `'#000000'`.

For Flutter, replicate this via a `bool isMobile` check on `MediaQuery`.

---

## Jitter

`jitterAmount` (default 0) is a per-line random offset added to the line endpoints. The web app exposes this as an admin setting; **users don't change it**. Implement it on the Flutter side but expose it the same way (admin-only).

---

## On the planning page — circular slider overlay

When `canChangeMax = true` (planning mode only):

- A **CircularSlider** is rendered on top of the canvas. Source: [src/components/StringCircle/CircularSlider.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/StringCircle/CircularSlider.tsx).
- It's a transparent overlay that captures drag gestures around the perimeter and reports a line-count value (`MIN_LINES` to `maxLines`).
- The visual feedback (which lines are drawn) is driven by the `currentLine` prop on the parent — the slider changes the count, the parent re-paints.
- Slider color: `#ffffff` (white).

Player mode (`canChangeMax = false`) hides the slider — the canvas is interaction-free except for swipe gestures handled at a parent level.

---

## Sizing & DPR

- The CSS size (`canvas.style.width / height`) is set to `canvasSize` in logical pixels.
- The backing store (`canvas.width / height`) is multiplied by `window.devicePixelRatio` so retina displays render crisply.
- `imageSmoothingEnabled = false` — line anti-aliasing comes from the browser's native stroke renderer; bitmap smoothing would blur it.

For Flutter, `CustomPainter` paints in logical pixels and the framework handles DPR automatically — no equivalent setup needed.

---

## Exposing canvas data

The web component exposes an imperative ref:

```ts
interface ICanvas {
  getCanvasDataUrl: (quality?: number) => string | null;
}
```

This is used to upload a preview image (`type='preview'`) when the user creates a project. Format: WebP, quality 0.8 default. Returns a data URL.

On Flutter, replicate by exposing a `GlobalKey<MyCustomPainterState>` and a `Future<Uint8List?> capturePreview({double quality = 0.8})` method using `RepaintBoundary` + `toImage()`.

---

## Performance notes

- Repaints happen on every `visibleCount` change. During playback at 4× speed (0.25 s/line), that's 4 repaints per second; at 1× it's ~10/s.
- Each repaint redraws **all visible lines** — not just the newest. The web canvas handles 8000 lines per frame without dropping.
- Flutter `CustomPainter` with `shouldRepaint` returning `true` should handle this comfortably. Cache the pin coordinate list (it only changes with diameter).
- Don't `setState` on each tick — drive playback through an `AnimationController` or `Ticker` and let the painter read the current line from a `ValueListenable`.

---

## Mobile deviations

- **No `window.innerWidth` check** — use `MediaQuery.of(context).size.width < 768`.
- **No DPR setup** — Flutter handles it.
- **No data URLs** — use `RepaintBoundary` + `Image.toByteData(format: ImageByteFormat.png)`.
- **Touch gestures on the circular slider** — `GestureDetector.onPanUpdate` with angle calculation, same math as the web version.
