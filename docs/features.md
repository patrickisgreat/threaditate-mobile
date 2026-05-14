# Threaditate — Feature Catalog

This is the master inventory of every user-facing feature in the [threaditate web app](https://github.com/patrickisgreat/threaditate). It exists so a Claude session working in this repo can understand WHAT to build without having access to the web source tree.

**How to use this doc:**

1. Find the feature you're about to implement in the section below.
2. If it has a detailed spec at [docs/features/<name>.md](features/), read that for user flow + edge cases.
3. If you need to confirm a detail against the web source, fetch it via `gh`:
   ```bash
   gh api repos/patrickisgreat/threaditate/contents/<path> --jq '.content' | base64 -d
   ```
4. When you ship a mobile feature, **update the status in this doc in the same PR.**

**Priority legend:**

- **MUST** — core user experience; mobile is incomplete without it.
- **SHOULD** — strong parity goal; ship for v1.
- **COULD** — nice-to-have; defer if time-constrained.
- **SKIP** — admin/dev-only or web-specific; do not port without asking.

---

## Status tracker

| Feature area | Web | Mobile status | Notes |
|---|---|---|---|
| Auth — sign in / up / Google / session | ✅ | 🟡 In progress | Email/password + reset + sign out shipped. Google OAuth still TODO. AUTH_ENABLED=false guest mode wired. |
| Projects — list, open, create, delete, save progress | 🟡 In progress | 🟡 In progress | List + repository scaffolded with empty state. Open/create/delete/save-progress still TODO. |
| Planning — upload, crop, adjust, generate | ✅ | ⬜ Not started | Native image picker, not drag-drop |
| Player — playback, controller, voices, swipe | ✅ | ⬜ Not started | CustomPainter for StringCircle |
| Image editor — sliders + presets | ✅ | ⬜ Not started | Reuse Dart-side processing or call Rust |
| Importance painter — focus areas | ✅ | ⬜ Not started | Touch-driven brush |
| Audio / voice playback | ✅ | ⬜ Not started | `just_audio` (probably) |
| Mobile UX — tray, safe area, responsive | ✅ | ⬜ Not started | Flutter has native equivalents |
| Algorithm / FFI bindings | ✅ (WASM) | ⬜ Not started | `flutter_rust_bridge` |
| Admin algorithm tuning | ✅ | 🚫 SKIP | Web-only |
| Test mode / snapshot capture | ✅ | 🚫 SKIP | Dev-only |
| Tips / help modal | ✅ | ⬜ Not started | Map to bottom sheet |

When you start a feature, change ⬜ to 🟡 (in progress). When it ships, change to ✅.

---

## 1. Authentication & Session

### Sign In

**What the user sees:** Email/password form with "Sign in" button. Option to sign in with Google. Link to create a new account or reset password.

**Implementation files:**
- `src/components/Auth/AuthForm.tsx`
- `src/context/AuthContext.tsx`

**Key behaviors / edge cases:**
- Email validation enforced by Supabase; no custom client-side check.
- Google OAuth redirects to the provider; no callback handling in the form itself.
- Passwords must be ≥ 6 characters.
- On successful sign-in, router redirects to `/` and calls `router.refresh()` to clear cached state.
- Auth can be disabled via `NEXT_PUBLIC_AUTH_ENABLED=false` env var for local dev; when disabled, no auth UI shows and the user is treated as anonymous with limited features.

**Mobile-port priority:** MUST

### Sign Up

**What the user sees:** Email / password / confirm-password form with password-validation feedback.

**Implementation files:**
- `src/components/Auth/AuthForm.tsx`
- `src/context/AuthContext.tsx`

**Key behaviors / edge cases:**
- Confirms password matches client-side (server doesn't re-validate).
- Minimum 6 characters enforced.
- Supabase sends an email confirmation link; the user must confirm before the account is active.
- Success message tells the user to check their email.

**Mobile-port priority:** MUST

### Password Reset

**What the user sees:** Email form with a "Reset" button. Success message says "Check your email for a password reset link."

**Implementation files:**
- `src/components/Auth/AuthForm.tsx`

**Key behaviors / edge cases:**
- No client-side check that the email exists; always shows success to prevent user enumeration.
- Supabase sends the reset link via email.

**Mobile-port priority:** SHOULD

### Session Persistence

**What the user sees:** User stays logged in across page reloads and app restarts.

**Implementation files:**
- `src/context/AuthContext.tsx`

**Key behaviors / edge cases:**
- Supabase manages the session via HTTP-only cookie (web). On mobile, Supabase Flutter persists tokens to secure storage automatically.
- `useAuth()` reads auth state synchronously on mount.
- `isLoading` indicates whether auth is still being determined.
- If auth is disabled, the user is always considered authenticated as a guest.

**Mobile-port priority:** MUST

### Sign Out

**What the user sees:** Sign-out button (header or settings). User is logged out and redirected to login/home.

**Implementation files:**
- `src/context/AuthContext.tsx` (contains `signOut()`)

**Key behaviors / edge cases:**
- Clears the Supabase session.
- Router redirects to login or home after sign-out.

**Mobile-port priority:** MUST

### Auth-Disabled Mode (Local Dev)

**What the user sees:** When `NEXT_PUBLIC_AUTH_ENABLED=false`, auth UI is bypassed. The user can access all pages without logging in.

**Implementation files:**
- `src/context/AuthContext.tsx` (checks the `authEnabled` flag)

**Key behaviors / edge cases:**
- Useful for local dev without Supabase configured.
- User object is null but protected features still work.
- No session persistence (treated as a guest on each reload).

**Mobile-port priority:** COULD

---

## 2. Projects (My Designs)

### List Projects

**What the user sees:** Gallery grid of past string-art designs, sorted by creation date (newest first). Each card shows a preview image, current progress line count, and total lines.

**Implementation files:**
- `src/app/my-designs/page.tsx`
- `src/app/my-designs/useGallery.tsx`
- `src/components/Gallery/GalleryCard/GalleryCard.tsx`

**Key behaviors / edge cases:**
- Fetches the user's projects via `projectService.getUserProjects()`.
- Loads preview images (or source images as fallback) in parallel.
- Renders `GalleryCard` for each project with the image base64 as a data URL.
- Empty state: blank gallery if the user has no projects.
- Loading state while data fetches.

**Mobile-port priority:** MUST

### Open Project

**What the user sees:** Tap a gallery card to load that project in the Player page.

**Implementation files:**
- `src/app/my-designs/useGallery.tsx` (`handlePressOpenPic`)
- `src/app/player/page.tsx` (loads project via `projectId` param)

**Key behaviors / edge cases:**
- Project ID is stored in `sessionStorage.currentProjectId` (mobile: use `SharedPreferences` or pass via routing).
- Player page reads `projectId` from the URL param or sessionStorage.
- Project data includes line sequence, source image, current playback position, max lines.

**Mobile-port priority:** MUST

### Create Project

**What the user sees:** User generates a string-art pattern on the planning page and presses "Start" (or "Begin"). A project is created and saved to Supabase with metadata.

**Implementation files:**
- `src/app/page.tsx` (`startSessionNext()`)
- `src/services/project.service.ts` (`createProject`)

**Key behaviors / edge cases:**
- Project metadata includes `pinCount` (200, hardcoded), `maxLines` (from the line-count slider), `minDistance`, `lineWeight`.
- Line sequence (array of pin indices) is saved.
- Source image is uploaded to storage with `type='source'`.
- Project name defaults to `String Art [date]`.
- `current_line` is initialized to 0.

**Mobile-port priority:** MUST

### Delete Project

**What the user sees:** Tap the "delete" icon on a gallery card; confirmation modal appears; confirm to delete.

**Implementation files:**
- `src/app/my-designs/useGallery.tsx` (`handleDelete`)
- `src/components/InfoModal/InfoModal.tsx` (confirmation UI)

**Key behaviors / edge cases:**
- Soft-delete via Supabase RLS (project is marked deleted, not purged).
- Images associated with the project are deleted as well.
- Gallery list updates immediately on the client after delete succeeds.

**Mobile-port priority:** SHOULD

### Save Progress

**What the user sees:** As the user plays the string art in the Player, the current line number is automatically saved to the project.

**Implementation files:**
- `src/app/player/page.tsx`
- `src/hooks/Player/useProjectData.tsx` (`saveProgress`)

**Key behaviors / edge cases:**
- Saves on every `currentLine` change (debounced in the service).
- Allows resuming playback from where the user left off.
- Also saves a rendered preview image (`type='preview'`) so the gallery card has a thumbnail.

**Mobile-port priority:** MUST

### Project Data Model

**What the user sees:** _(Developer-facing)_ Projects have this structure.

**Implementation files:**
- `supabase/migrations/` (schema)
- `src/services/project.service.ts`

**Key fields:**

- `id` (UUID, primary key)
- `user_id` (FK to `auth.users`)
- `name` (string)
- `pin_count` (int, typically 240 or 200)
- `max_lines` (int)
- `min_distance` (int)
- `line_weight` (int)
- `line_sequence` (int[], the pin indices)
- `current_line` (int, playback position)
- `created_at` (timestamp)
- `updated_at` (timestamp)
- `images` (relation to `project_images`; each has `type='source'` or `type='preview'`)

**Mobile-port priority:** MUST (for understanding persistence)

---

## 3. Planning Flow

### Upload Image

**What the user sees:** A large circular "upload" area on the planning page with "Tap to Upload" text. User taps or drag-drops an image.

**Implementation files:**
- `src/components/UploadCircle/UploadCircle.tsx`
- `src/components/UploadCircle/ImageDropzone.tsx`
- `src/app/page.tsx` (integration)

**Key behaviors / edge cases:**
- Accepts JPG, PNG, WebP. Max 8MB.
- Image is loaded into a preview canvas; the user sees it immediately.
- The cropper is initialized with the image; the user can zoom/pan.
- On mobile, the upload circle is positioned at the top via `flex-direction: column-reverse` in CSS.
- Uploads are client-side only; the image is not sent to the server until the project is created.
- **Mobile deviation:** use the platform image picker (`image_picker` package), not drag-and-drop.

**Mobile-port priority:** MUST

### Crop & Zoom

**What the user sees:** Interactive image cropper overlaid on the upload circle. User can drag to pan, pinch to zoom, or use sliders to adjust the crop area.

**Implementation files:**
- `src/components/UploadCircle/UploadCircle.tsx`
- `src/components/UploadCircle/CropperControls.tsx`
- Library: [`react-easy-crop`](https://www.npmjs.com/package/react-easy-crop)

**Key behaviors / edge cases:**
- Crop area is always square (1:1).
- Min zoom prevents zooming out beyond image bounds.
- Crop values are stored in state and passed to StringCircle via the `cropControls` object.
- User can tap "Apply Crop" to render with the new crop.
- Cropped image is generated as a base64 data URL.
- **Mobile equivalent:** Flutter has [`crop_your_image`](https://pub.dev/packages/crop_your_image) or [`image_cropper`](https://pub.dev/packages/image_cropper).

**Mobile-port priority:** MUST

### Image Adjustments

**What the user sees:** "Image Adjustments" panel (collapsed by default on mobile, expanded on desktop). Contains preset buttons ("Default", "High Contrast", "Portrait", etc.) and an "Advanced" section with slider controls.

**Implementation files:**
- `src/components/ImageEditor/ImageEditor.tsx`
- `src/services/imageProcessor.ts`

**Sliders in the Advanced section:**

- **Brightness** (-100 to 100): shifts overall luminance.
- **Contrast** (-100 to 100): expands or compresses tonal range.
- **Shadows** (-100 to 100): lifts or crushes dark areas.
- **Highlights** (-100 to 100): lifts or crushes bright areas.
- **Gamma** (0.2 to 3.0): nonlinear brightness curve.
- **Vignette** (0 to 100): edge darkening, ramping toward corners.
- **Output Min / Max** (0 to 255): clamps output grayscale range; allows crushing blacks/whites.
- **Toon Filter** (toggle): posterization or smoothing with a mode selector (posterize / smooth / bold) and a strength slider (0.0 to 1.0).

**Key behaviors / edge cases:**

- Presets are one-tap; most users only use these.
- Image analysis runs on load and suggests adjustments if the image is backlit, dark, bright, or low-contrast.
- Sliders are debounced (1200 ms) to avoid re-processing on every tick; re-renders on slider release.
- Toon-mode switches persist across presets.
- Adjustments are applied to the cropped image before the string-art algorithm runs.

**Mobile-port priority:** MUST → see [docs/features/image-editor.md](features/image-editor.md) for full slider table.

### Focus Areas / Importance Painter

**What the user sees:** Optional brush tool to paint areas of focus (blue = more detail) or areas to lighten (red = less detail). Canvas overlays the StringCircle preview. Three brush modes: Focus, Lighten, Erase.

**Implementation files:**
- `src/components/ImportancePainter/ImportancePainter.tsx`
- `src/app/page.tsx` (integration via `isPainterActive`)

**Key behaviors / edge cases:**

- Brush size 2–80 px.
- Brush strength 0.1–1.0 (stroke opacity).
- Undo stack up to 20 steps.
- "Clear" erases the entire mask.
- "Apply & Render" commits the mask and triggers re-processing.
- Mask is passed to WASM as an `ImageData`; the algorithm weights importance sampling by mask values.
- **Note for mobile:** the painter toolbar in the web app is positioned `bottom: -50px` from the upload circle and overlaps the mobileFooter — see PR #100 for that fix.

**Mobile-port priority:** SHOULD → see [docs/features/importance-painter.md](features/importance-painter.md).

### Generate Button (Start Session)

**What the user sees:** Large "Start" button at the bottom of the planning page. Disabled until the image is processed and the line count is set. On tap, creates a project and navigates to the Player.

**Implementation files:**
- `src/app/page.tsx` (`canClick` logic + `startSessionNext`)

**Key behaviors / edge cases:**

- Button is disabled until ALL of:
  - `croppedImage` is set (image uploaded and cropped)
  - `isInitialized` is true (WASM module loaded)
  - `!isProcessing` (no algorithm run in progress)
  - `isImageReady` is true (line sequence computed)
  - `localLineSequence.length > 0` (at least one line generated)
- On tap: creates a Supabase project, uploads the source image, stores `projectId`, navigates to `/player?projectId=...`.

**Mobile-port priority:** MUST

### Line Count Slider

**What the user sees:** Circular slider around the StringCircle preview on the planning page. User drags to select 0–8000 lines (or the configured max). The number is displayed below the circle.

**Implementation files:**
- `src/components/StringCircle/CircularSlider.tsx`
- `src/app/page.tsx` (`changeLinesAmount`)

**Key behaviors / edge cases:**

- Minimum is `MIN_LINES` (typically 100); maximum is `MAX_LINES` (typically 8000) or admin-configured.
- Slider changes are debounced 200 ms.
- Visual feedback: the circle renders only the selected number of lines.
- Display shows count + estimated time below (e.g., `4000 Lines • 2m 45s`).

**Mobile-port priority:** MUST

### Advanced Controls

**What the user sees:** On desktop, a collapsible section below the image editor. On mobile, lives in the MobileControlsTray. Contains:

- **Min Distance** slider (pin-separation constraint)
- **Line Weight** slider (thread thickness in the algorithm)

**Implementation files:**
- `src/app/page.tsx` (`settingsVersion` tracking)
- `src/hooks/useStringArtService.ts` (`updateConfig`)

**Key behaviors / edge cases:**

- Min Distance prevents short lines between nearby pins; higher → fewer, longer lines.
- Line Weight controls how much brightness each line subtracts; higher → fewer lines needed.
- Changes trigger immediate re-processing.
- On mobile, these live in the gear-FAB tray.

**Mobile-port priority:** SHOULD

### Real-Time Preview

**What the user sees:** The StringCircle preview updates automatically as the user adjusts crop, zoom, image settings, or line count. A small "Rendering..." indicator appears during processing.

**Implementation files:**
- `src/app/page.tsx` (auto-processing effect)
- `src/components/StringCircle/StringCircle.tsx` (`isRendering`)

**Key behaviors / edge cases:**

- Processing is debounced 800 ms after crop/zoom changes.
- Importance-painter changes trigger immediate re-processing (no debounce).
- Line-count changes are debounced 200 ms.
- The "Rendering..." indicator animates while `isProcessing` is true.

**Mobile-port priority:** MUST

### Admin Settings Live-Tuning

**What the user sees:** _(Admin-only)_ Real-time updates to algorithm parameters in the planning-page preview. When the admin changes a setting, all active planning sessions re-process immediately.

**Implementation files:**
- `src/app/admin/`
- `src/app/page.tsx` (`settingsVersion` tracking)
- `src/services/algorithm-settings.service.ts` (Supabase subscription)

**Mobile-port priority:** SKIP (admin feature)

---

## 4. Player Flow

### StringCircle Rendering

**What the user sees:** Large circular canvas with white pins around the perimeter. Colored lines drawn between pins, step-by-step, showing the pattern being "stitched."

**Implementation files:**
- `src/components/StringCircle/StringCircle.tsx`
- `src/components/StringCircle/CanvasStringCircle.tsx`
- `src/components/StringCircle/CanvasStringUtils.ts`

**Key behaviors / edge cases:**

- Diameter is responsive (`useResponsiveDiameter`).
- Lines drawn as the user advances through the sequence (`currentLine`).
- Pins rendered as small circles (radius ~2–3 px).
- Lines colored by progress: completed are white/opaque; the next line is highlighted in a brighter color (two-line lookahead).
- On mobile, lines are thinner (0.08 width vs. 0.14 desktop) and lower-opacity (0.65 vs. 1.0).
- Canvas background is slightly gray (0.7 brightness) for contrast.
- On the planning page, the circular slider overlays the canvas; on the player page, the slider is hidden.

**Mobile-port priority:** MUST → see [docs/features/string-circle.md](features/string-circle.md).

### Controller (Play / Pause / Prev / Next)

**What the user sees:** Three-button control: left arrow (previous line), center play/pause, right arrow (next line). Mobile adds + / − speed buttons on top.

**Implementation files:**
- `src/components/Player/Controller/Controller.tsx`
- `src/app/player/page.tsx` (integration)

**Key behaviors / edge cases:**

- Play/Pause toggles playback; on pause, the user can adjust via slider or jump-to.
- Prev/Next change `currentLine` by ±1 and stop playback.
- On mobile, speed controls (Slower/Faster) appear above the main buttons.
- All buttons are ≥ 44 px touch targets.

**Mobile-port priority:** MUST → see [docs/features/player.md](features/player.md).

### Speed Control

**What the user sees:** Speed slider or dropdown with options from 0.25 s to 4 s delay per line. Selected speed is persisted. On mobile, ± buttons on the Controller adjust speed.

**Implementation files:**
- `src/components/Player/SpeedController/SpeedController.tsx`
- `src/app/player/page.tsx` (`timeOptions`, `handleTimeChange`)
- `src/utils/constants.ts` (`PLAYER_SPEED` constants)

**Key behaviors / edge cases:**

- `PLAYER_SPEED`: MIN = 0.25, MAX = 4.0, STEP = 0.1 seconds per line.
- Persisted to localStorage under `STORAGE_KEYS.PLAYBACK_SPEED`.
- Stored as a string (`.toFixed(2)`) to avoid float precision issues.
- `useLinePlayer` converts `selectedTime` to ms delay used in playback `setTimeout`.
- Speed up = decrease delay; slow down = increase delay.

**Mobile-port priority:** MUST

### Voice Selection

**What the user sees:** Dropdown with voice options ("Voice 1", "Voice 2"). Selection is persisted.

**Implementation files:**
- `src/components/Player/VoiceSelector/VoiceSelector.tsx`
- `src/hooks/Player/useSoundPlayer.tsx`

**Key behaviors / edge cases:**

- Voice files are stored in `/sounds/Voice 1/` and `/sounds/Voice 2/`.
- Each voice has a `.wav` per pin (e.g. `00000.wav` … `00239.wav` if `pinCount = 240`).
- Voice selection is broadcast via a custom event (`voiceChanged`) so `SettingsSounds` can react.
- Default voice is Voice 1.
- **Known issue:** the "Zero" voice option is reported as much quieter than the others (item #10 in the user's feedback list).

**Mobile-port priority:** SHOULD

### Per-Pin Sound Playback

**What the user sees:** When audio is enabled, a short sound plays as each line is drawn. Volume can be adjusted.

**Implementation files:**
- `src/components/Player/SettingsSounds/SettingsSounds.tsx`
- `src/hooks/Player/useSoundPlayer.tsx`

**Key behaviors / edge cases:**

- `useSoundPlayer` manages a single audio element; loads and plays sequential sounds.
- Sound path: `/sounds/{voice}/{pinNumber}.wav` (zero-padded to 5 digits).
- If the same sound is already playing, the request is skipped (no overlap).
- Volume from localStorage (`STORAGE_KEYS.SOUND_VOLUME`, 0–100).
- Async load/play; errors (e.g., `AbortError` from gesture restrictions) are silently caught.

**Mobile-port priority:** SHOULD

### Step Slider

**What the user sees:** Five numbers around the StringCircle showing current and adjacent step numbers, scaled to the circle diameter.

**Implementation files:**
- `src/components/Player/StepSlider/StepSlider.tsx`

**Key behaviors / edge cases:**

- Displays five numbers centered around `currentStep` (e.g., `[3998, 3999, 4000, 4001, 4002]`).
- Numbers are absolutely positioned and scale with circle diameter (`scale = diameter / 640px`, clamped 0.35–1.0).
- The center number is large, ±1 medium, ±2 small.
- Numbers overlay the canvas with `pointer-events: none` so they don't block interaction.

**Mobile-port priority:** SHOULD

### Jump-To-Step Modal

**What the user sees:** Modal with a "Jump to #" text input and a "Search" button. User enters a step number and taps to jump.

**Implementation files:**
- `src/components/Player/JumpToStep/JumpToStep.tsx`
- `src/components/Player/SettingsWrapper/SettingsWrapper.tsx` (integration)

**Key behaviors / edge cases:**

- Input accepts only positive integers ≤ `maxStep`.
- Pressing Enter submits.
- On submit, `onSubmit(stepNumber)` is called.
- Input is cleared after submit.
- Invalid input is silently rejected.
- **Open UX question:** the user has asked whether jump-to-step should jump by line index or by pin number — see item #11 in the feedback list. Not yet resolved.

**Mobile-port priority:** SHOULD

### Completion Celebration

**What the user sees:** When `currentLine === pinNumbers.length`, confetti animates across the screen and a victory sound plays.

**Implementation files:**
- `src/hooks/Player/useLinePlayer.tsx` (`playVictory`)
- `src/app/player/page.tsx` (`handleCompletion`)
- `src/utils/celebrate.ts` (`triggerConfetti`)

**Key behaviors / edge cases:**

- Victory sound: `/sounds/victory.mp3`; uses the same volume setting as per-pin sounds.
- Confetti is triggered only once per completion.
- Confetti uses a canvas-based library ([`canvas-confetti`](https://github.com/catdad/canvas-confetti)).
- Playback is paused on completion.
- Respects `prefers-reduced-motion`.

**Mobile-port priority:** SHOULD

### Swipe Gestures

**What the user sees:** On mobile, swiping left/right advances/reverses the line. Swiping up/down adjusts speed.

**Implementation files:**
- `src/hooks/useSwipeGestures.ts`
- `src/app/player/page.tsx` (integration)

**Key behaviors / edge cases:**

- Swipe left = next line.
- Swipe right = previous line.
- Swipe up = speed up (decrease delay).
- Swipe down = slow down (increase delay).
- `useSwipeGestures` computes distance and direction from `touchstart`/`touchend`.
- Callbacks fire only if the swipe distance exceeds a threshold (~50 px).

**Mobile-port priority:** SHOULD

### Save Progress

(See Projects → Save Progress above.)

**Mobile-port priority:** MUST

---

## 5. Audio & Voice

### Available Voices

**What the user sees:** Two voice options in the selector dropdown.

**Implementation files:**
- `src/components/Player/VoiceSelector/VoiceSelector.tsx`

**Key behaviors / edge cases:**

- Voices are "Voice 1" and "Voice 2" (human-readable names).
- Voice files live in `/sounds/Voice 1/` and `/sounds/Voice 2/`.
- Typically TTS-generated or recorded audio.

**Mobile-port priority:** SHOULD

### Volume Control

**What the user sees:** Volume slider in settings, 0–100 %. Default is 70 %.

**Implementation files:**
- `src/app/player/page.tsx` (localStorage `SOUND_VOLUME`)
- `src/hooks/Player/useSoundPlayer.tsx` (`setVolumePlayer`)

**Key behaviors / edge cases:**

- Persisted in localStorage (survives page refresh).
- Slider value is a percentage (0–100); internally converted to 0.0–1.0.
- Both per-pin sounds and the victory sound use the same volume.

**Mobile-port priority:** SHOULD

---

## 6. Mobile-Specific UX

### MobileControlsTray

**What the user sees:** Gear button (FAB) in the bottom-right corner (above the home indicator on iOS). Tapping opens a bottom sheet with image adjustments and advanced controls. Tap on the handle or backdrop to close.

**Implementation files:**
- `src/components/MobileControlsTray/MobileControlsTray.tsx`
- `src/components/MobileControlsTray/MobileControlsTray.module.css`
- `src/app/page.tsx` (`isTrayOpen` state, `controlsOpen` class)

**Key behaviors / edge cases:**

- Mobile-only (`display: none` on desktop; `display: flex` ≤ 768 px).
- Gear FAB has a pulsing green-glow animation (5 s infinite).
- Bottom sheet animates from `translateY(100%)` to `translateY(0)` (300 ms cubic-bezier).
- Max height 50 vh so the StringCircle preview stays visible above for real-time feedback.
- Content scrolls internally if it overflows (`-webkit-overflow-scrolling: touch`).
- Backdrop fades 0 → 0.5 opacity.
- Children stagger-animate on open (`slideUp`, 0.08 s–0.26 s delays).
- Safe-area insets applied: gear button sits above the home indicator (`bottom: 76px + env(safe-area-inset-bottom)`); tray content padding includes `env(safe-area-inset-bottom)`.

**Mobile-port priority:** MUST → see [docs/features/mobile-ux.md](features/mobile-ux.md).

### Safe Area Handling

**What the user sees:** On devices with notches, home indicators, or landscape side bars, UI respects safe areas. Text and buttons don't sit under notches/indicators.

**Implementation files:**
- `src/app/string.module.css` (`page_screen_top` uses `safe-area-inset-top`)
- `src/components/MobileControlsTray/MobileControlsTray.module.css` (`safe-area-inset-bottom`/`-right`)

**Key behaviors / edge cases:**

- CSS `env()` reads `safe-area-inset-*` values from the browser.
- iOS notch/home-indicator offsets are applied automatically.
- Landscape side notches via `safe-area-inset-right` (e.g., FAB uses `max(16px, env(safe-area-inset-right))`).

**Mobile-port priority:** MUST (Flutter equivalent: `SafeArea` widget + `MediaQuery.padding`)

### Responsive Circle Diameter

**What the user sees:** StringCircle size adapts to screen width (and historically height too — see PR #98). On narrow portrait phones, the circle is sized to fit two circles vertically on the planning page.

**Implementation files:**
- `src/hooks/useResponsiveDiameter.ts`

**Key behaviors / edge cases:**

- Planning page (`variant='planning'`, `canChangeMax=true`):
  - Mobile (< 480 px): `min(screenWidth - 32, 315)`. Page is allowed to scroll if content overflows.
  - Tablet (480–1024 px): 450.
  - Desktop (≥ 1024 px): 640.
- Player page (`variant='player'`, `canChangeMax=false`):
  - Mobile: `min(screenWidth - 32, 340)`.
  - Tablet: 500.
  - Desktop (1200–1920 px): 640.
  - Ultra-wide (≥ 1920 px): 700.
- Upload variant is similar but slightly smaller on mobile (max 315).

**Mobile-port priority:** MUST — Flutter side: compute from `MediaQuery.of(context).size` in the equivalent hook/provider.

### Layout Reflow on Mobile

**What the user sees:** On the planning page, UploadCircle is above StringCircle on mobile (vertical stack). On desktop, they sit side-by-side horizontally.

**Implementation files:**
- `src/app/string.module.css`

**Key behaviors / edge cases:**

- `page_screen` uses `flex-direction: column-reverse` on ≤ 1024 px.
- Gap between circles: 16 px mobile, 80 px desktop.
- Centered controls between circles have a desktop-only offset.

**Mobile-port priority:** MUST

### Tray-Open Chrome Hiding

**What the user sees:** When the MobileControlsTray is open on the planning page (or the painter is active, or Image Adjustments is expanded), the StringCircle preview hides and the action footer is hidden so the user focuses on the UploadCircle they're editing.

**Implementation files:**
- `src/app/page.tsx` (`controlsOpen` class)
- `src/app/string.module.css` (`.controlsOpen` rules)

**Key behaviors / edge cases:**

- `controlsOpen` is applied when `isTrayOpen || isAdvancedExpanded || isPainterActive`.
- `controlsOpen` hides the StringCircle (2nd child of `page_screen_upload`) and the mobileFooter, and switches the layout from column-reverse to row so the UploadCircle stays pinned at the top.

**Mobile-port priority:** SHOULD

---

## 7. Algorithm / WASM (mobile: FFI)

### WASM Module Loading

**What the user sees:** _(Transparent)_ On page load, the WASM module initializes. If the Web Worker fails, it falls back to main-thread execution.

**Implementation files:**
- `src/services/wasm-loader.ts`
- `src/services/wasm-worker-loader.ts`
- `src/services/wasm.worker.ts`

**Key behaviors / edge cases:**

- WASM is compiled from Rust in `src/services/string-art-wasm/`.
- Loaded dynamically (SSR-safe).
- If the worker init fails, automatic fallback to the main thread.
- No visual feedback; on hard failure, the app shows a graceful error or disables processing.

**Mobile-port priority:** MUST (mobile uses FFI via [`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge); no worker, just an isolate if needed for off-UI-thread work)

### User-Visible Algorithm Knobs

#### Pin Count

- **Default:** 240 pins evenly arranged around the circle.
- **Control:** Admin-set; not directly user-adjustable per session.
- **Purpose:** More pins = finer detail; fewer pins = blockier.

#### Max Lines (Line Count Slider)

- **Default:** 8000.
- **Control:** Circular slider on planning page.
- **Purpose:** More lines = more detail; fewer = lighter pattern.

#### Min Distance

- **Default:** 40 pins (admin-configurable).
- **Control:** Advanced-controls slider.
- **Purpose:** Higher = longer, sparser lines.

#### Line Weight

- **Default:** 10 (admin-configurable).
- **Control:** Advanced-controls slider.
- **Purpose:** Higher = fewer lines needed.

#### Admin-only knobs (SKIP for mobile)

- **Lightness Penalty** — default 0.7.
- **Line Norm Mode** — TotalSum / PixelCount (default) / WeightedSum.
- **Attenuation Mode** — Subtraction (default) / Halving.
- **Auto-Stop Threshold** — default null (disabled).
- **Quality Modes** — standard / enhanced (default) / multipass / parallel.

#### Toon Filter

- **Control:** Toggle in image editor (advanced section). Modes: posterize / smooth / bold. Strength 0.0–1.0.
- **Purpose:** Reduces tonal gradients to discrete bands.

**Mobile-port priority:** MUST (mirror user-facing knobs); SKIP admin-only knobs.

### Image Preprocessing

**What the user sees:** _(Transparent)_ Image is analyzed for contrast, brightness, edges, and noise. Preprocessing is applied automatically based on the image.

**Implementation files:**
- `src/services/imageProcessor.ts` (`analyzeImage`, `suggestSettings`)
- Rust: `src/services/string-art-wasm/src/image_processing.rs`

**Key behaviors / edge cases:**

- Analysis flags: `isLowContrast`, `isBacklit`, `isDark`, `isBright`.
- Suggested adjustments appear in a badge + "Apply Suggestions" button.
- Algorithm applies contrast stretch, histogram equalization (CLAHE-like), edge enhancement, bilateral filtering based on content.
- User can override via sliders or presets.

**Mobile-port priority:** MUST (the user sees UI for it)

### Recency Buffer

**What the user sees:** _(Transparent)_ The algorithm avoids oscillating between the same pin pairs. A `VecDeque<u32>` of the 20 most-recent pins is maintained.

**Implementation files:**
- `src/services/string-art-wasm/src/string_art.rs`

**Mobile-port priority:** SKIP (internal optimization — exposed via FFI naturally)

---

## 8. Admin / Test Mode (mobile: SKIP)

### Admin Settings

**What the user sees:** _(Admin-only)_ `/admin` page with live controls for algorithm parameters. Changes update Supabase and trigger live re-processing.

**Mobile-port priority:** SKIP

### Test Mode

**What the user sees:** _(Dev/QA)_ Auto-captures rendering snapshots to Supabase for regression testing.

**Mobile-port priority:** SKIP

### Snapshot Service

**What the user sees:** _(Dev/QA)_ Snapshots stored for query/regression comparison.

**Mobile-port priority:** SKIP

---

## 9. Tips / Help / Onboarding

### Tips Modal

**What the user sees:** Modal with two tabs: "Photo" (image-selection tips) and "Capture" (string-art capture tips). Triggered from the Tips button or burger menu on the planning page.

**Implementation files:**
- `src/components/Tips/Tips.tsx`
- `src/components/Tips/TipsPhoto.tsx`
- `src/components/Tips/TipsCapture.tsx`

**Key behaviors / edge cases:**

- Opens/closes via `setIsOpenTips`.
- Two tab sections (text + images).
- "Continue" button closes the modal.
- Can be triggered via burger menu (custom event `stringring:tips`) or the Tips button.

**Mobile-port priority:** SHOULD (Flutter: `showModalBottomSheet` or `Dialog`)

---

## 10. Shared Components Worth Knowing

### StringCircle

**Purpose:** Renders the circular string-art pattern on both planning and player pages. Includes the circular slider on the planning page.

**File:** `src/components/StringCircle/StringCircle.tsx`

**Props:** `connectionIndexes` (number[]), `currentLine` / `onLineChange`, `canChangeMax`, `origImg`, `lineThickness`, `lineOpacity`, `canvasBackground`, `isRendering`.

**Mobile-port priority:** MUST → see [docs/features/string-circle.md](features/string-circle.md).

### UploadCircle

**Purpose:** Drop zone + interactive cropper for image upload on the planning page.

**File:** `src/components/UploadCircle/UploadCircle.tsx`

**Props:** `imageUrl`, `onCropResult`, `imageSettings`, `onCropInteractionEnd`.

**Mobile-port priority:** MUST

### ImageEditor

**Purpose:** Image-adjustments panel with presets and advanced sliders.

**File:** `src/components/ImageEditor/ImageEditor.tsx`

**Props:** `settings`, `analysis`, `onSettingChange`, `isExpanded`.

**Mobile-port priority:** MUST → see [docs/features/image-editor.md](features/image-editor.md).

### BgPage, Btn, Icon, Gallery / GalleryCard, Controller

- **BgPage** (gradient background) — `src/components/bg/bgPage/BgPage.tsx`. Priority: COULD.
- **Btn** (reusable button) — `src/components/Btns/Btn/Btn.tsx`. Priority: COULD (utility).
- **Icon** (SVG renderer w/ registry) — `src/icons/Icon.tsx`. Priority: COULD (utility).
- **Gallery / GalleryCard** — `src/components/Gallery/GalleryCard/GalleryCard.tsx`. Priority: MUST.
- **Controller** — `src/components/Player/Controller/Controller.tsx`. Priority: MUST → see [docs/features/player.md](features/player.md).

---

## 11. Key Hooks

| Hook | Purpose | File |
|---|---|---|
| `useStringArtService` | Orchestrates WASM string-art generation | `src/hooks/useStringArtService.ts` |
| `useResponsiveDiameter` | Responsive circle size by variant + viewport | `src/hooks/useResponsiveDiameter.ts` |
| `useWasmWorker` | Worker + main-thread fallback | `src/hooks/useWasmWorker.ts` |
| `useIsMobile` | Mobile breakpoint detection | `src/hooks/useIsMobile.tsx` |
| `useSwipeGestures` | Swipe direction + magnitude | `src/hooks/useSwipeGestures.ts` |
| `useLinePlayer` | Playback state + auto-advance | `src/hooks/Player/useLinePlayer.tsx` |
| `useSoundPlayer` | Per-pin sound loading + playback | `src/hooks/Player/useSoundPlayer.tsx` |
| `useProjectData` | Loads project + `saveProgress` | `src/hooks/Player/useProjectData.tsx` |
| `useAppSettings` | App-wide settings from localStorage | `src/hooks/useAppSettings.ts` |

For Flutter, these mostly map to Riverpod providers (state + side effects) or plain widgets (the responsive logic moves into a `Theme.of(context)` / `MediaQuery`-driven utility).

---

## 12. Breakpoints & Responsive Design

### Web breakpoints (`src/utils/constants.ts`)

| Token | Pixels |
|---|---|
| `MOBILE_SMALL` | 320 |
| `MOBILE_LARGE` | 480 |
| `TABLET` | 768 |
| `DESKTOP_SMALL` | 1024 |
| `DESKTOP` | 1200 |
| `DESKTOP_LARGE` | 1920 |
| `ULTRA_WIDE` | 2560 |

### Key CSS Modules

- `src/app/string.module.css` — planning page layout, flex reflow, safe-area insets
- `src/app/player/player.module.css` — player page layout
- `src/components/MobileControlsTray/MobileControlsTray.module.css` — tray positioning, animations, safe-area
- `src/components/StringCircle/StringCircle.module.css`
- `src/components/UploadCircle/UploadCircle.module.css`
- `src/components/ImageEditor/ImageEditor.module.css` — preset grid, advanced disclosure

### Patterns to mirror on Flutter

- **Safe areas:** wrap top-level scaffolds in `SafeArea`; for partial control, use `MediaQuery.of(context).padding`.
- **Two-circle layout on mobile:** `Column` with `verticalDirection: VerticalDirection.up` (Flutter's equivalent of `column-reverse`).
- **Tray animations:** `showModalBottomSheet` with custom `transitionAnimationController`, or a hand-rolled `AnimatedPositioned`.
- **Responsive diameters:** read `MediaQuery.of(context).size` once at the top of the screen and pass down — don't sprinkle `MediaQuery.of` calls everywhere.

---

## Implementation notes for the Flutter port

1. **Authentication:** Supabase Flutter SDK (`supabase_flutter`). Same project URL + anon key as the web app; same RLS policies apply.
2. **Projects:** Same Supabase schema. Store the active project ID in `SharedPreferences` (or pass via `go_router` extra).
3. **Image Processing:** Two viable approaches — port `imageProcessor.ts` to Dart (slow path; fast to implement) or call into Rust via FFI alongside the algorithm itself (faster; consolidates code). Defer the decision to the first image-editor sprint.
4. **WASM Algorithm:** Call the Rust crate via `flutter_rust_bridge`. The crate must be cross-compiled for `aarch64-apple-ios`, `aarch64-apple-ios-sim`, `aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android` (emulator). See [ARCHITECTURE.md](../ARCHITECTURE.md).
5. **StringCircle Rendering:** `CustomPainter` over `CustomPaint`. Cache the pin-coordinate list once per diameter change.
6. **Responsive Layout:** Build a small `BreakpointTheme` extension on `ThemeData` so widgets read the breakpoint the same way the web app does.
7. **Gestures:** `GestureDetector` (`onHorizontalDragEnd`, `onVerticalDragEnd`) with the same ~50 px threshold.
8. **Persistence:** `SharedPreferences` for non-sensitive prefs; `flutter_secure_storage` for auth tokens (Supabase SDK handles this internally).
9. **Safe Areas:** `SafeArea` widget at the scaffold level; use `MediaQuery.of(context).padding.bottom` for the FAB offset.
10. **Audio:** [`just_audio`](https://pub.dev/packages/just_audio) for the per-pin clips. Preload nearby clips into memory; reuse one player instance.
11. **UI State:** Mirror localStorage keys (`SOUND_VOLUME`, `PLAYBACK_SPEED`, `selectedVoice`) in `SharedPreferences`.
12. **Dialogs/Modals:** `showDialog`, `showModalBottomSheet`.
13. **Testing:** Unit-test the algorithm wrapper and services; widget-test UI components; integration-test critical flows (upload → generate → play).
