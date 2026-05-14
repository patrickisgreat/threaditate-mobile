# Mobile UX — Tray, Safe Area, Responsive Layout

A collection of mobile-specific behaviors the web app already handles. Most of these map cleanly to Flutter primitives — this doc captures what each one is supposed to do so the mobile version doesn't drift.

**Web references:**
- [src/components/MobileControlsTray/MobileControlsTray.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/components/MobileControlsTray/MobileControlsTray.tsx)
- [src/components/MobileControlsTray/MobileControlsTray.module.css](https://github.com/patrickisgreat/threaditate/blob/main/src/components/MobileControlsTray/MobileControlsTray.module.css)
- [src/hooks/useResponsiveDiameter.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/hooks/useResponsiveDiameter.ts)
- [src/hooks/useIsMobile.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/hooks/useIsMobile.tsx)
- [src/hooks/useSwipeGestures.ts](https://github.com/patrickisgreat/threaditate/blob/main/src/hooks/useSwipeGestures.ts)
- [src/app/string.module.css](https://github.com/patrickisgreat/threaditate/blob/main/src/app/string.module.css) — planning page mobile CSS
- [src/app/player/player.module.css](https://github.com/patrickisgreat/threaditate/blob/main/src/app/player/player.module.css) — player page mobile CSS

---

## The mobile breakpoint

The web app uses **768 px** as the desktop/mobile cutoff and **480 px** as a "small mobile" sub-breakpoint. Match this on Flutter:

```dart
extension Breakpoint on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < 768;
  bool get isSmallMobile => MediaQuery.of(this).size.width < 480;
}
```

Use it directly in widgets that need to branch. Don't proliferate `if (isMobile)` checks across feature code — wrap the divergent behavior in a layout widget once at the screen level.

---

## Mobile controls tray

A bottom sheet that exposes secondary planning-page controls (Focus Areas, Image Adjustments, crop sliders, advanced controls). Triggered from a gear FAB.

### Gear FAB

- Positioned at `bottom-right`, **above the home indicator**: `bottom: 76px + env(safe-area-inset-bottom)`.
- Has a pulsing green-glow animation that runs continuously (`@keyframes gearGlow`, 5 s, infinite).
- Tap to toggle tray open/closed.
- ARIA: `aria-label="Open controls"` / `"Close controls"`.

### Tray bottom sheet

- Animates from `translateY(100%)` (off-screen) to `translateY(0)` over 300 ms with `cubic-bezier(0.4, 0, 0.2, 1)` easing (Material standard).
- Max height **50 vh** so the StringCircle preview stays visible above. Content scrolls internally with `-webkit-overflow-scrolling: touch` if it exceeds.
- Backdrop fades in (0 → 0.5 opacity) behind the tray. Tapping the backdrop closes the tray.
- Children stagger-animate in with `slideUp` keyframes; delays cascade from 0.08 s on the first child to 0.26 s on the last (8 × 0.045 s).
- Internal padding includes `env(safe-area-inset-bottom)` so the last action button doesn't sit on the home indicator.

### Flutter equivalent

`showModalBottomSheet`:

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,        // so we can constrain max height
  backgroundColor: Colors.transparent,
  builder: (ctx) => DraggableScrollableSheet(
    initialChildSize: 0.5,
    minChildSize: 0.3,
    maxChildSize: 0.5,
    builder: (_, scroll) => ControlsTrayContent(scrollController: scroll),
  ),
);
```

For the FAB glow, use a `TweenAnimationBuilder` with a `BoxShadow` tweening green opacity, or hand-roll with an `AnimationController` that runs `repeat()`.

---

## Safe areas

iOS notch / dynamic island / home indicator must not occlude UI. The web app reads `env(safe-area-inset-*)` CSS variables (which only return non-zero values when `viewportFit=cover` is set — see [src/app/layout.tsx](https://github.com/patrickisgreat/threaditate/blob/main/src/app/layout.tsx)).

Mobile-side, use `SafeArea` at the root of each scaffold and `MediaQuery.of(context).padding` when you need the values directly:

```dart
final bottomInset = MediaQuery.of(context).padding.bottom;
// e.g., for the FAB offset
```

Common safe-area pitfalls to avoid:

- **Don't wrap modal bottom sheets in `SafeArea` blindly** — Flutter's `showModalBottomSheet` already respects `useSafeArea`. Use that parameter instead of nesting.
- **The Controller on the player page** needs `padding-bottom: max(8px, safe-area-bottom)` so the home indicator doesn't cover play/pause. (This was item #6 in user feedback, fixed in web PR [#100](https://github.com/patrickisgreat/threaditate/pull/100).)
- **The gear FAB on planning page** sits above both the mobileFooter buttons AND the home indicator — compose both offsets.

---

## Responsive circle diameter

Different page variants need different circle sizes. The web hook returns a single number; the Flutter equivalent should be a Riverpod provider or extension method on `MediaQuery`.

| Variant | Mobile (< 768 px) | Tablet (768–1024 px) | Laptop (1024–1200 px) | Desktop (≥ 1200 px) | Ultra-wide (≥ 1920 px) |
|---|---|---|---|---|---|
| `planning` (canChangeMax=true) | `min(width - 32, 315)` | 450 | 450 | 640 | 640 |
| `player` (canChangeMax=false) | `min(width - 32, 340)` | 500 | 500 | 640 | 700 |
| `upload` | `min(width - 32, 315)` | 450 | 450 | 640 | 640 |

The web hook used to apply a "height-aware cap" on tall narrow phones (iPhone 16 Pro) to fit two stacked circles in the viewport, but that made circles too small on real Safari (innerHeight ~734 with URL bar visible). PR [#98](https://github.com/patrickisgreat/threaditate/pull/98) removed the height-aware cap and made the page scroll on mobile instead. **Mirror that behavior on Flutter:** size by width only, let `SingleChildScrollView` handle overflow.

### Flutter provider

```dart
final responsiveDiameterProvider = Provider.family<double, DiameterVariant>((ref, variant) {
  final width = ref.watch(screenWidthProvider);
  final widthCap = width - 32;
  return switch (variant) {
    DiameterVariant.planning => min(widthCap, 315),
    DiameterVariant.player => min(widthCap, 340),
    DiameterVariant.upload => min(widthCap, 315),
  };
  // ... extend with tablet/desktop branches
});
```

---

## Mobile layout reflow

The planning page on mobile uses `flex-direction: column-reverse` so the UploadCircle (DOM order 1) renders **above** the StringCircle (DOM order 2). The DOM order matches desktop's left-to-right; CSS does the visual flip.

Flutter equivalent: a `Column` with `verticalDirection: VerticalDirection.up` if you want to keep DOM order matching desktop. Or just swap the children's order in a `Column` — your call. The visual outcome is the same.

The player page is column-only on mobile already, no flip needed.

---

## Tray-open / controls-open mode

When ANY of the bottom-sheet-style overlays are open on planning (`isTrayOpen || isAdvancedExpanded || isPainterActive`), the `.page_screen` gets a `.controlsOpen` class that:

- **Hides the StringCircle** (the rendered output preview). The user is editing the source; they don't need to see the result simultaneously.
- **Hides the mobileFooter** (the lineInfo + action buttons). Clears the home indicator and prevents accidental taps.
- **Flips `page_screen_upload` to `flex-direction: row` and `justify-content: center`** so the UploadCircle pins to the top of the visible area above the sheet.
- **Aligns `contentWrapper` to flex-start** with `padding-top: 8px`.

On Flutter, model this as a single `bool isAnyOverlayActive` derived from the three flags. Use it to conditionally render the relevant children:

```dart
if (!isAnyOverlayActive) StringCirclePreview(),
if (!isAnyOverlayActive) MobileFooter(),
```

The CSS row-flex flip translates to: when `isAnyOverlayActive`, swap the `Column` for a `Row` (or just constrain the UploadCircle's max height so it doesn't push the bottom sheet out of view).

---

## Swipe gestures (player page)

`useSwipeGestures` on web computes:

```ts
{
  onSwipeLeft: ()=> handleNext(),
  onSwipeRight: ()=> handlePrev(),
  onSwipeUp: ()=> handleSpeedUp(),
  onSwipeDown: ()=> handleSlowDown(),
}
```

Threshold: ~50 px. The hook listens for `touchstart` + `touchend` and picks the dominant axis by `|dx| vs |dy|`.

Flutter:

```dart
GestureDetector(
  onHorizontalDragEnd: (details) {
    if (details.primaryVelocity == null) return;
    if (details.primaryVelocity! < -50) handleNext();
    else if (details.primaryVelocity! > 50) handlePrev();
  },
  onVerticalDragEnd: (details) {
    if (details.primaryVelocity == null) return;
    if (details.primaryVelocity! < -50) handleSpeedUp();
    else if (details.primaryVelocity! > 50) handleSlowDown();
  },
  child: stringCircleWidget,
);
```

Note that `GestureDetector` will only fire one of the two callbacks per gesture — Flutter picks whichever direction has higher velocity. That matches the web behavior.

---

## Header (top app bar)

Mobile uses `--header-height: 36px` (a thin bar — just enough for the logo and the burger menu). Desktop uses 115 px.

For Flutter, use a `Material 3 AppBar` with `toolbarHeight: 36`. Apply safe-area-top padding via `SafeArea(top: true)`.

---

## Burger menu

Mobile-only menu trigger in the header. Web app dispatches custom events to open Tips (`stringring:tips`) — keep the UX simpler on mobile by routing menu items directly to their actions via `Navigator` or a Riverpod state change.

---

## Pull-to-refresh

The web app doesn't have pull-to-refresh; the planning page is locked to the current state. Don't add it on mobile either — the "draft" state is fragile and pulling to refresh would discard the cropped image + adjustments.

For the My Designs gallery, **do** add pull-to-refresh (`RefreshIndicator`) — that's expected on a list screen.
