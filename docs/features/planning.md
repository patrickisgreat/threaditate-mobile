# Planning — Upload → Adjust → Generate

The planning screen is the entry point for creating a new string-art pattern. The user picks an image, crops it, optionally tunes adjustments and focus areas, watches the live preview, then taps "Start" to persist the project and move to the Player.

**Web references:**
- [src/app/page.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/app/page.tsx) — page root (large file; the heart of the app)
- [src/app/useStringPage.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/app/useStringPage.ts) — state coordination hook
- [src/components/UploadCircle/UploadCircle.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/UploadCircle/UploadCircle.tsx) — upload + cropper
- [src/components/StringCircle/StringCircle.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/StringCircle/StringCircle.tsx) — live preview (see [string-circle.md](string-circle.md))
- [src/components/MobileControlsTray/](https://github.com/patrickisgreat/threaditate/tree/main/src/components/MobileControlsTray) — gear FAB + bottom sheet
- [src/components/ImageEditor/ImageEditor.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/ImageEditor/ImageEditor.tsx) — adjustments panel ([image-editor.md](image-editor.md))
- [src/components/ImportancePainter/ImportancePainter.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/ImportancePainter/ImportancePainter.tsx) — focus brush ([importance-painter.md](importance-painter.md))

---

## User flow

1. **Land on planning page.** Two circles visible: UploadCircle on top (mobile) / left (desktop) showing "Drop or Choose an image", and StringCircle on bottom / right showing an empty pin ring.
2. **Pick an image.** User taps the upload circle → native image picker opens. Selection populates the cropper with the image; user can pan + pinch-zoom inside the circular frame.
3. **Auto-crop fires.** When the cropper finishes its initial render (i.e., `croppedAreaPixels` is set _and_ `minZoom > 1`), a square crop is generated as a base64 data URL. This crop is what feeds the algorithm.
4. **Image analysis runs.** `analyzeImage()` ([src/services/imageProcessor.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/services/imageProcessor.ts)) scans the cropped image for low contrast / backlit / dark / bright signals. If any flag fires, a "Suggested settings" badge appears with an "Apply" button.
5. **Algorithm runs.** The cropped image → WASM (web) / Rust FFI (mobile). Output is a line sequence (`number[]`). The StringCircle re-renders to show the result.
6. **Live tweaking.** User can:
   - Drag the **circular slider** around the StringCircle to change line count (debounced 200 ms).
   - Open **Image Adjustments** (a panel on desktop, the gear tray on mobile) to fine-tune brightness / contrast / etc. — see [image-editor.md](image-editor.md).
   - Open **Focus Areas** (the ImportancePainter) to paint regions of emphasis — see [importance-painter.md](importance-painter.md).
   - Adjust **Min Distance** / **Line Weight** in advanced controls.
7. **Press Start** → the project is persisted to Supabase, a preview WebP is uploaded, and the router pushes `/player?projectId=<uuid>`.

---

## Layout

### Desktop (≥ 1024 px)

```
┌────────────────────────────────────────────┐
│  Header                                    │
├────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────────┐  │
│  │ UploadCircle │    │ StringCircle     │  │
│  │              │    │  (with slider)   │  │
│  └──────────────┘    └──────────────────┘  │
│         Image Adjustments panel            │
│                  Start button              │
└────────────────────────────────────────────┘
```

### Mobile (≤ 768 px)

```
┌──────────────────────┐
│ Header               │
├──────────────────────┤
│   ┌────────────┐     │
│   │ UploadCircle│   │  ← user is editing this
│   │             │   │
│   └────────────┘     │
│   ┌────────────┐     │
│   │ StringCircle│   │  ← live result preview
│   │ (no slider) │   │
│   └────────────┘     │
│   {lines} • {time}   │
│   [Choose] [Start]   │  ← mobileFooter
│                  🛠️ │  ← gear FAB → tray
└──────────────────────┘
```

CSS uses `flex-direction: column-reverse` so UploadCircle (DOM order 1) renders **above** StringCircle (DOM order 2). The `.page` scrolls if content overflows the viewport.

---

## State (`useStringPage` + `useStringArtService`)

Key state slices the planning page tracks:

| State | Type | Purpose |
|---|---|---|
| `originalImage` | `string \| null` | Raw uploaded image (base64 data URL) |
| `croppedImage` | `string \| null` | Square-cropped version, what the algorithm sees |
| `imageSettings` | `ImageSettings` | All adjustment sliders (see [image-editor.md](image-editor.md)) |
| `importanceMask` | `ImageData \| null` | Painter output |
| `localLineSequence` | `number[]` | Algorithm output |
| `lineCount` | `number` | User-selected max lines |
| `parameters` | `AlgorithmParams` | min distance, line weight, thread thickness, etc. |
| `isImageProcessed` | `bool` | Has the algorithm produced output? |
| `isProcessing` | `bool` | Currently re-running? |
| `cropControls` | `CropControlsData \| null` | Exposed crop slider data for the mobile tray |
| `isTrayOpen` | `bool` | Mobile gear tray open? |
| `isAdvancedExpanded` | `bool` | "Image Adjustments" overlay open? |
| `isPainterActive` | `bool` | Focus-areas painter active? |

The `.controlsOpen` CSS class is applied to `.page_screen` when `isMobile && (isTrayOpen || isAdvancedExpanded || isPainterActive)`. This hides the StringCircle and the mobileFooter so the user focuses on whatever they're editing.

For Flutter, model this as a Riverpod `freezed` state class.

---

## Auto-processing effect

Re-renders fire when:

- `croppedImage` changes (debounced 800 ms).
- `imageSettings` changes (debounced 1200 ms — the slider release).
- `lineCount` changes (debounced 200 ms).
- `importanceMask` changes (no debounce — the user explicitly tapped Apply).
- Admin's `settingsVersion` in Supabase increments (live-tuning; SKIP on mobile).

Use Riverpod's `autoDispose` + `Debouncer` utility, or hand-roll with `Timer`.

---

## Generate button (Start)

Disabled until ALL of:

- `croppedImage != null`
- `isInitialized` (FFI/WASM ready)
- `!isProcessing`
- `isImageReady` (algorithm has produced an output)
- `localLineSequence.length > 0`

On tap (`startSessionNext` in [src/app/page.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/app/page.tsx)):

1. Generate a project name (default `String Art <YYYY-MM-DD>`).
2. Call `projectService.createProject({...})` → returns new project row.
3. Upload the source image to Supabase storage with `image_type='source'`.
4. Render a WebP preview (canvas → `getCanvasDataUrl()`) and upload with `image_type='preview'`.
5. Store the new project ID in `sessionStorage.currentProjectId`.
6. Set a saving spinner during the network calls (`setIsSaving(true)`).
7. Navigate to `/player?projectId=<uuid>`.

Edge cases:

- **Network failure** during the project create or image upload — show an error toast and let the user retry. Don't navigate.
- **User is anonymous** (auth disabled) — there's no `user_id`; the web app currently can't save projects in this mode. For mobile, decide whether to:
  - Allow local-only sessions (cache in `SharedPreferences` and never sync)
  - Or require sign-in before saving
  Pick local-only for simplicity; document the limitation.

---

## Mobile controls tray (gear FAB → bottom sheet)

Triggered by the gear FAB in the bottom-right. Opens a `Modal` bottom sheet with secondary controls:

- **Focus Areas** button (only when `croppedImage` is set) — toggles `isPainterActive`. See [importance-painter.md](importance-painter.md).
- **Image Adjustments** button (only when `cropControls` is set) — sets `isAdvancedExpanded = true` (full-screen overlay) and closes the tray.
- **Crop sliders** (zoom, rotation) — live sliders.
- **Advanced controls** — min distance, line weight, thread thickness.

The tray is capped at 50 vh so the StringCircle preview stays visible above. Children stagger-animate on open with 0.08–0.26 s delays.

For Flutter, use `showModalBottomSheet(isScrollControlled: true, ...)` and limit the sheet's max height to 50% of `MediaQuery.size.height`.

---

## Live-suggestion badge

When `analyzeImage()` flags any issue:

```
┌────────────────────────────────────────┐
│ 💡 Suggestions: backlit subject       │
│    [ Apply ]                          │
└────────────────────────────────────────┘
```

Tapping Apply merges the suggested settings into `imageSettings`. Suggestions are advisory; the user can ignore them.

Specific suggestion rules live in [src/services/imageProcessor.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/services/imageProcessor.ts) — `suggestSettings(analysis)`. Read it before implementing the equivalent on mobile.

---

## Tips modal

Triggered from a Tips button or the burger menu. Two tabs: "Photo" (image-selection tips) and "Capture" (string-art capture tips). On mobile, this should be a `showModalBottomSheet`.

See [src/components/Tips/](https://github.com/patrickisgreat/threaditate/tree/main/src/components/Tips) for content.

---

## Mobile deviations

- **Native image picker** (`image_picker` package), not drag-and-drop.
- **No `sessionStorage`** — pass the new project ID via `go_router` extra or persist in `SharedPreferences`.
- **No live admin-settings subscription** — the planning page never knows about admin changes (the algorithm settings are baked at app start).
- **The "Drop or Choose" prompt copy** is web-specific. On mobile, change to "Tap to choose an image" or use a camera/photos split (button to pick from photos, button to take a new photo).
- **`.page` is a `Scrollable`** on Flutter — use `SingleChildScrollView` to mirror the web's `overflow-y: auto` behavior so the second circle doesn't get clipped when Safari's URL bar shrinks the viewport.

---

## Open items from user feedback

- **Item #2**: max-image-size note is missing from the upload UI. Add a hint like "Max 8 MB" near the picker.
- **Item #5**: a 2000×1500 image can't be zoomed enough to fill the ring. The cropper's `maxZoom` may be too restrictive — investigate before shipping the mobile version.
- **Item #8**: the "Focus Areas" button rename to "Close Painter" while painting is confusing. The button is a toggle; maybe label it consistently as "Focus Areas" with a checked state instead of swapping copy.
