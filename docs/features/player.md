# Player — Playback Flow

The player visualizes a generated string-art pattern one line at a time. It's the second of the two primary screens (planning is the first). Loaded with a `projectId`; reads project data from Supabase.

**Web references:**
- [src/app/player/page.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/app/player/page.tsx) — page root
- [src/components/Player/Controller/Controller.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/Player/Controller/Controller.tsx) — play/pause/prev/next + speed buttons
- [src/components/Player/SettingsWrapper/SettingsWrapper.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/Player/SettingsWrapper/SettingsWrapper.tsx) — sidebar / mobile-controls container
- [src/components/Player/StepSlider/StepSlider.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/Player/StepSlider/StepSlider.tsx) — animated step numbers
- [src/components/Player/JumpToStep/JumpToStep.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/Player/JumpToStep/JumpToStep.tsx) — modal input
- [src/components/Player/VoiceSelector/VoiceSelector.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/Player/VoiceSelector/VoiceSelector.tsx) — voice dropdown
- [src/hooks/Player/useLinePlayer.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/hooks/Player/useLinePlayer.tsx) — playback state machine
- [src/hooks/Player/useSoundPlayer.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/hooks/Player/useSoundPlayer.tsx) — per-pin audio
- [src/hooks/Player/useProjectData.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/hooks/Player/useProjectData.tsx) — Supabase load + save progress

---

## User flow

1. User taps a project on My Designs. Project ID is stashed in `sessionStorage.currentProjectId` and the router pushes `/player?projectId=<uuid>`.
2. Player loads project data from Supabase: source image, line sequence, `currentLine`, `maxLines`.
3. While loading, a spinner or skeleton state shows. (On the web app, the StringCircle just doesn't render until `isDataReady` is true.)
4. Once loaded, the StringCircle renders at the saved `currentLine` position. Playback is paused by default.
5. User taps **Play**. Lines render one-by-one at the configured speed. The current line index is auto-saved to Supabase (debounced).
6. User can **pause**, scrub via the **step slider**, **jump** to a specific step, **swipe** to advance/reverse or change speed, or change the **voice**.
7. On reaching the final line, playback stops automatically; **confetti fires**, the **victory sound** plays.

---

## Layout

### Desktop

A horizontal flexbox:

- **Left**: `SettingsWrapper.desktop_controls` — back button, sidebar metrics (line / speed / progress), `SpeedController`, `JumpToStep`, `VoiceSelector`.
- **Right**: `.page_screen` — the StringCircle + `Controller` below it.

### Mobile

A vertical flexbox:

- **Top**: `SettingsWrapper.mobile_controls` — a thin row with two buttons: **Jump to Line** and **Voice**. Both open modal bottom sheets.
- **Middle/bottom**: `.page_screen` — StringCircle + mobile metrics row + Controller.

The `.page_screen` is a scroll container on mobile (`overflow-y: auto`); content stacks vertically and the user scrolls if it exceeds the viewport. Bottom padding includes `env(safe-area-inset-bottom)` so the Controller clears the iOS home indicator.

---

## Playback state machine (`useLinePlayer`)

State variables:

- `currentLine: number | undefined` — the active line index.
- `isPlaying: boolean` — playing or paused.
- `selectedTime: string` — delay per line, in seconds (string for precision).
- `volume: string` — 0–100 percent, persisted.

Effects:

1. **On `currentLine` change**, if `currentLine === pinNumbers.length`, pause + play victory sound + fire `onComplete` (the page triggers confetti).
2. **On `isPlaying` change**, if true and we're not yet at the end, schedule a `setTimeout(advance, delay)`. Cleanup cancels the timeout.
3. `delay = parseFloat(selectedTime) * 1000` ms. So speed `"0.25"` → 250 ms between lines.

On mobile (Flutter), use `Ticker`/`AnimationController` for the advance loop — `Future.delayed` works but a `Ticker` integrates better with `vsync`.

---

## Controller (play / pause / prev / next)

Three round buttons in a horizontal row, all ≥ 44 px touch target:

- **Previous** — left arrow icon. Decrements `currentLine` by 1 (clamped at 0). Pauses playback.
- **Play/Pause** — toggles `isPlaying`. Icon is `PlayerPlay` when paused, `PlayerPause` when playing.
- **Next** — right arrow icon. Increments `currentLine` by 1 (clamped at `maxLines`). Pauses playback.

On mobile, the Controller renders an additional speed-control row **above** the main row:

- **Slower** — decrements the speed (increases delay). `Minus` icon + "Slower" caption.
- **Faster** — increments the speed (decreases delay). `Plus` icon + "Faster" caption.

Both speed buttons are 44 × 44 px minimum, with the caption labeled in 9 px uppercase white text below the icon.

---

## Speed control

`selectedTime` is one of a discrete set of values:

```
PLAYER_SPEED.MIN = 0.25
PLAYER_SPEED.MAX = 4.0
PLAYER_SPEED.STEP = 0.1
PLAYER_SPEED.DEFAULT = 1.0   // or whatever the constants file says; check it
```

The options are generated as `.toFixed(2)` strings: `"0.25", "0.35", "0.45", ..., "4.00"`.

- **Desktop**: a dedicated `SpeedController` component — likely a slider or numeric input.
- **Mobile**: ± buttons on the Controller; tapping `+` finds the current index in `timeOptions` and moves to the previous (faster) value, `−` moves to the next (slower).

Persisted to `localStorage` under `STORAGE_KEYS.PLAYBACK_SPEED`. On mobile, mirror in `SharedPreferences`.

---

## Step slider

Five numbers, scaled to the canvas, displayed near the StringCircle:

- Centered around `currentLine` (e.g., `[3998, 3999, 4000, 4001, 4002]`).
- Center number is the biggest; ±1 are medium; ±2 are smallest.
- Positioned absolutely with `pointer-events: none` — purely visual.
- `scale = circleDiameter / 640px`, clamped 0.35–1.0.

Use a `Stack` with `IgnorePointer` and a `Positioned.fill` on Flutter. Render the numbers in a `Row` with a transform.

---

## Jump-to-step

A modal triggered from the desktop sidebar or the mobile "Jump to Line" button.

- Single text input that accepts positive integers up to `maxStep`.
- "Search" button + Enter key both submit.
- On submit: calls `onSubmit(stepNumber)` which sets `currentLine` to that value. Input clears.
- Invalid input (non-numeric, > maxStep, ≤ 0) is silently rejected — no error toast.

**Open UX question** _(from the user's feedback, item #11)_: should jump-to-step jump by **line index** (current behavior — the Nth line in the sequence) or by **pin number** (the literal pin label the user is currently winding around)? Discuss with the user before locking in. The current line-index interpretation is the web app's behavior.

---

## Voice selection

Two options today: "Voice 1" and "Voice 2".

- Each voice has a folder under `/sounds/<voice>/` containing one `.wav` per pin (`00000.wav` ... `00239.wav` for 240 pins).
- Voice is persisted in `localStorage` (key: voice name). Mirror in `SharedPreferences` for mobile.
- The web component dispatches a custom event `voiceChanged` so the sound player can swap files; on Flutter, just rebuild the `SoundPlayer` with the new voice.

**Known issue:** the "Zero" voice (which the user mentioned in feedback) has noticeably lower amplitude than the others. Possible fixes: per-voice gain normalization in the player, or re-recording the files. Not yet fixed.

---

## Per-pin sound playback

When playback advances a line:

- The destination pin's `.wav` is fetched from `/sounds/<voice>/<pinNumber>.wav` (zero-padded to 5 digits).
- A single audio element is reused (`useSoundPlayer`); the source URL is reassigned and `play()` is called.
- If the same sound is currently playing, the request is skipped.
- Volume comes from `STORAGE_KEYS.SOUND_VOLUME` (0–100, converted to 0.0–1.0).
- Errors (e.g., `AbortError` from gesture restrictions on iOS Safari) are silently swallowed.

For Flutter, use [`just_audio`](https://pub.dev/packages/just_audio):

```dart
final player = AudioPlayer();
await player.setAsset('assets/sounds/${voice}/${pinIndex.toString().padLeft(5, '0')}.wav');
await player.play();
```

Preload nearby clips into memory (LRU cache, ~20 entries) to avoid disk reads on every step.

---

## Swipe gestures (mobile)

On the StringCircle container, listen for swipes:

- **Left** → next line (`handleNext`).
- **Right** → previous line (`handlePrev`).
- **Up** → speed up.
- **Down** → slow down.

Threshold: ~50 px. The web hook (`useSwipeGestures`) listens for `touchstart` + `touchend` and computes `dx`, `dy`, picking the larger axis.

Flutter: `GestureDetector(onHorizontalDragEnd: ..., onVerticalDragEnd: ...)` with a velocity threshold (e.g., 50 px/s).

---

## Save progress

Every `currentLine` change fires `saveProgress(currentLine)`. The service debounces the actual Supabase write (200 ms typical) so the user doesn't trigger a write per playback tick.

```dart
ref.listen<int?>(currentLineProvider, (prev, next) {
  if (next != null) saveProgressDebounced(next);
});
```

On project resume, set `currentLine` to the saved value.

---

## Completion celebration

When `currentLine === pinNumbers.length`:

- Pause playback (`setIsPlaying(false)`).
- Play `/sounds/victory.mp3` at the configured volume.
- Fire `onComplete()` which the page handler turns into a confetti burst via `triggerConfetti()` ([src/utils/celebrate.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/utils/celebrate.ts)). Confetti uses [`canvas-confetti`](https://github.com/catdad/canvas-confetti); Flutter equivalent is [`confetti`](https://pub.dev/packages/confetti).
- **Honor `prefers-reduced-motion`** — the web app already does this; on mobile use `MediaQuery.disableAnimations`.

---

## Mobile deviations

- No web worker; FFI runs on the main isolate (the player doesn't recompute anything heavy — the algorithm output is already stored).
- Native modal bottom sheet (`showModalBottomSheet`) for Jump to Line and Voice Selection.
- `SafeArea` wrapping the scaffold; `MediaQuery.padding.bottom` for the Controller offset.
- `flutter_dotenv` or compile-time const for the Supabase URL/anon key.

---

## Known bugs to fix (also in the web app's TODO)

1. **Item #6** in the user's feedback: play/next/prev buttons clipped on iPhone 16 Pro. Fixed on web in PR [#100](https://github.com/patrickisgreat/threaditate/pull/100). Don't replicate the bug on Flutter — the `flex: 1 + min-height: 0` CSS hack is web-specific; Flutter's column flex handles this naturally with proper `SafeArea` + `Expanded`.
2. **Item #7**: not a player bug (it's the planning-page painter overlay). See [docs/features/importance-painter.md](importance-painter.md).
3. **Item #10**: Zero voice volume balance. Apply a per-voice gain when loading the audio source.
4. **Item #11**: jump-to-step disambiguation. Pending user decision.
