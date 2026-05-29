# Importance Painter — Focus Areas

A brush tool that lets the user paint regions of the image to emphasize ("Focus", blue) or de-emphasize ("Lighten", red). The painted mask is passed to the algorithm as a per-pixel importance weight, biasing line selection toward focused regions.

**Web references:**
- [src/components/ImportancePainter/ImportancePainter.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/ImportancePainter/ImportancePainter.tsx) — paint canvas + state
- [src/components/ImportancePainter/ImportancePainter.module.css](https://github.com/patrickisgreat/threaditate/blob/main/src/components/ImportancePainter/ImportancePainter.module.css) — overlay + toolbar styles
- [src/app/page.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/app/page.tsx) — integration (`isPainterActive`, `setImportanceMask`)

---

## User flow

1. On the planning page, user has uploaded + cropped an image. `croppedImage` is non-null.
2. User opens the mobile controls tray and taps **Focus Areas** (or clicks the equivalent desktop button).
3. The painter activates: a semi-transparent canvas overlays the UploadCircle. A small toolbar appears at `bottom: -50px` of the upload circle (i.e., below it) with brush controls.
4. The user paints on the image. Strokes accumulate in an in-memory mask buffer (one stroke per `mousedown → mouseup` / `touchstart → touchend`).
5. User taps **Apply & Render** → the mask is committed and passed to the algorithm. Re-processing fires immediately (no debounce).
6. User taps Focus Areas again (or "Close Painter") → exits painter mode without applying further changes.

---

## Brush modes

Three modes, mutually exclusive:

| Mode | Visual | Effect |
|---|---|---|
| **Focus** | Blue stroke | Increases importance weight. Algorithm draws more lines through these regions. |
| **Lighten** | Red stroke | Decreases importance weight. Algorithm avoids these regions. |
| **Erase** | Transparent | Removes previously-painted strokes. |

Selected mode is indicated visually (the active button has a colored background — blue for focus, red for lighten, white for erase).

---

## Brush parameters

| Param | Range | Default |
|---|---|---|
| Brush size | 2–80 px | ~20 |
| Brush strength | 0.1–1.0 | ~0.5 |

- **Size** is the brush radius in pixels (rendered at canvas scale; needs to be scaled to mask resolution if those differ).
- **Strength** is the opacity of each stroke — multiple strokes over the same region accumulate.

The toolbar layout (from the CSS):

```
┌───────────────────────────────────────────────────────────────┐
│ Size [────●──] 20    Strength [──●─────] 0.5                  │
│ [Focus] [Lighten] [Erase]  [Undo] [Clear] [ Apply & Render ] │
└───────────────────────────────────────────────────────────────┘
```

---

## Undo / Clear

- **Undo** — pops the last stroke from a stack. Stack capacity: **20**. Past 20 the oldest stroke is dropped.
- **Clear** — empties the entire mask. Cannot be undone (no clear-undo).
- **Apply & Render** — commits the current mask state.

For Flutter, store strokes as a `List<Stroke>` where `Stroke` is a `freezed` class holding mode, points, size, strength. Render by walking the list. Undo is `list.removeLast()`.

---

## Mask data shape

The web app passes the mask to the algorithm as an `ImageData` (`Uint8ClampedArray`, RGBA, same dimensions as the cropped image). RGB encodes the mode (R for lighten, B for focus, etc.); alpha encodes strength.

For Flutter FFI to Rust, marshal the mask as a `Uint8List` with the same RGBA layout. The Rust crate's importance-mask API accepts it directly (check the `flutter_rust_bridge` signature for the algorithm entry point).

---

## Toolbar positioning (the bug that caused user feedback)

The toolbar CSS:

```css
.toolbar {
  position: absolute;
  bottom: -50px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 20;
  ...
}
```

That `bottom: -50px` positions the toolbar 50 px **below** the UploadCircle, where the mobileFooter (lineInfo + buttons) sits on the planning page. Without intervention, the toolbar overlaps the lineInfo readout — **this was item #7 in the user's feedback** and was fixed in PR [#100](https://github.com/patrickisgreat/threaditate/pull/100) by adding `isPainterActive` to the `.controlsOpen` condition, which hides the mobileFooter while painting.

On Flutter, **don't replicate the `bottom: -50px` hack.** Instead, render the toolbar inline below the canvas in a `Column`, or pin it to the bottom of the painter screen with `Align(alignment: Alignment.bottomCenter)`. The mobileFooter conflict goes away.

---

## Apply button behavior

When **Apply & Render** is tapped:

1. Convert the mask state (stroke list) → `ImageData` buffer.
2. Set `importanceMask` on the planning-page state.
3. The auto-processing effect detects the change and re-runs the algorithm.
4. The painter does NOT auto-close — the user can paint more, then re-Apply.

If the user closes painter mode without applying, the previous applied mask is retained (don't discard it).

---

## Performance

- The mask canvas runs at a reduced resolution (e.g., 200×200 or the algorithm's working image size) — not the device's full DPR canvas. This keeps stroke rendering cheap.
- A stroke is sampled at the gesture's `move` events; interpolate between sample points if they're more than `brushSize/2` apart so strokes don't show a "dotted" pattern.
- Repaint the canvas after each move event — `CustomPainter.shouldRepaint` returning true is fine; Flutter handles this at 60 fps for thousand-stroke masks.

---

## Mobile deviations

- **Toolbar location**: inline below the canvas, not absolutely positioned. (Per above.)
- **Pointer events** are touch only (no mouse) — `GestureDetector.onPanStart/Update/End`.
- **Apply button styling**: full-width primary button at the bottom of the painter screen, not a small inline button. Easier thumb reach.
- **Brush size + strength** sliders are stacked vertically on mobile (the web app puts them side-by-side, which is too tight for thumbs at ≤ 480 px width).

---

## Open items

- **Item #8** in the user's feedback: "Close Painter" label is confusing as a sibling of "Focus Areas". Options:
  - Rename to a clearer toggle ("Painting Focus Areas — Tap to Exit").
  - Use a distinct UI affordance (a chip with a close × icon at the top of the screen) instead of relabeling the trigger button.
  - Keep the toggle but show painter UI in a sheet with a clear close affordance so the trigger doesn't need to flip labels.

  Discuss with the user before locking in.
