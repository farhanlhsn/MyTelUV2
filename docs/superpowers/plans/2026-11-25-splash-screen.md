# Splash Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One continuous red splash (native → Flutter) with a short intro, an exit that turns into the destination's red header, and a launcher icon that is no longer cropped.

**Architecture:** Brand images are generated once from `mobile/assets/images/telyu.png` by a committed script; native Android splash/launcher resources point at them. The routing decision moves out of `SplashPage` into a testable `resolveSplashDestination`; `SplashPage` becomes an animated widget that runs the intro and the login check in parallel and calls an injectable `navigate` when both are done.

**Tech Stack:** Flutter (GetX routing), Android resources (API 31 splash attributes), Python + Pillow for asset generation (dev-time only).

**Spec:** `docs/superpowers/specs/2026-11-25-splash-screen-design.md`

## Global Constraints

- Brand red `#E63946` (`AppColors.primary`); circle and sheet white.
- No new Dart or Gradle packages (no Lottie, flutter_native_splash, flutter_launcher_icons).
- No fixed delay: intro ≈ 700 ms, exit ≈ 450 ms, destination cross-fade ≈ 250 ms; the progress line appears only if the login check is still running when the intro ends.
- Reduced motion (`MediaQuery.disableAnimations`): no intro, no sheet; end state, then fade.
- Keep: valid token (`AuthMiddleware.isTokenValid`) → `AppRoutes.home`, then `NotificationNavigator.openPending()` after the first frame; anything else (including an exception) → `clearPending()`, `clearCredentials()`, `AppRoutes.login`.
- iOS untouched. Splash red in light and dark mode.
- Dart files in this repo use CRLF in the working tree; keep the line endings of files you edit. Run Flutter in a scratch copy (the repo's `.dart_tool`/`build` belong to a Windows setup).

## Review Focus

- A login check that throws (corrupt secure storage) must still reach Login, never hang on the splash. → Task 2 test `storage error goes to login`.
- A slow check (slow device, first launch) must keep the splash up with the progress line, then leave once. → Task 3 test `slow check shows the progress line and navigates once`.
- `navigate` must be called exactly once even if the intro and the check finish in the same frame. → asserted in every Task 3 navigation test (`calls.length == 1`).
- The page must not navigate after it is disposed (route replaced by a notification tap). → Task 3 test `disposed splash never navigates`.
- Dark mode must not bring back a white/black first frame. → Task 1 verification on the emulator with dark theme on.

---

### Task 1: Brand assets and native splash/launcher resources

**Files:**
- Create: `mobile/tool/brand_assets.py` (Pillow; run with `python3 -I mobile/tool/brand_assets.py`)
- Create: `mobile/assets/images/telyu_symbol.png` (book + U only, transparent, cropped tight, ~600 px tall)
- Create: `mobile/android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/splash_icon.png` (Android 12 icon: 240 dp canvas, symbol 96 dp tall centred; densities ×1, 1.5, 2, 3, 4)
- Create: `mobile/android/app/src/main/res/drawable-{…}/splash_mark.png` (pre-12: white 160 dp circle with the 96 dp symbol)
- Replace: `mobile/android/app/src/main/res/drawable-{…}/ic_launcher_foreground.png` (108 dp canvas, symbol 52 dp tall centred) and `mipmap-{…}/ic_launcher.png` (48 dp, white circle with symbol)
- Modify: `mobile/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (inset `0%`: the padding is in the image now)
- Modify: `mobile/android/app/src/main/res/drawable/launch_background.xml`, `drawable-v21/launch_background.xml` (red item `@color/splash_background` + centred `@drawable/splash_mark` bitmap)
- Modify: `mobile/android/app/src/main/res/values/colors.xml` (add `splash_background` = `#E63946`)
- Create: `mobile/android/app/src/main/res/values-v31/styles.xml`, `values-night-v31/styles.xml` (`LaunchTheme`: `windowSplashScreenBackground` `@color/splash_background`, `windowSplashScreenIconBackgroundColor` `#FFFFFF`, `windowSplashScreenAnimatedIcon` `@drawable/splash_icon`; `NormalTheme` as in `values/styles.xml`)
- Modify: `mobile/android/app/src/main/res/values-night/styles.xml` (same launch background as light)
- Modify: `mobile/pubspec.yaml` only if `assets/images/` is not already declared as a folder

**Interfaces:**
- Produces: asset `assets/images/telyu_symbol.png`; Flutter-side sizes that match native: circle diameter `160`, symbol height `96` (logical px), centred on the full screen (not the safe area).

- [ ] **Step 1:** Write `brand_assets.py`: crop the symbol from `telyu.png` (alpha bbox of the part above the "Telkom" text), then render every file above at its sizes.
- [ ] **Step 2:** Run it; open `splash_icon.png` (xxxhdpi) and `ic_launcher_foreground.png` (xxxhdpi) and check the symbol fits inside the centred circle of diameter 160/240 resp. 66/108 of the canvas.
- [ ] **Step 3:** Write the resource XML above.
- [ ] **Step 4:** Build the debug APK, install, cold start with `screenrecord`; expected: every frame before Flutter is red with a white circle and the symbol (no white frame); launcher icon on the home screen shows the whole symbol. Repeat once with `adb shell cmd uimode night yes` (then `no`).
- [ ] **Step 5:** Commit (`feat(android): red launch splash and an uncropped launcher icon`).

### Task 2: Splash destination resolver

**Files:**
- Create: `mobile/lib/pages/splash/splash_destination.dart`
- Test: `mobile/test/splash_destination_test.dart`

**Interfaces:**
- Produces: `Future<String> resolveSplashDestination({FlutterSecureStorage storage = const FlutterSecureStorage()})` → `AppRoutes.home` or `AppRoutes.login`. On the login path it calls `NotificationNavigator.clearPending()` and `AuthMiddleware.clearCredentials()`. Never throws.

- [ ] **Step 1: Write the failing tests** (mock storage as in `test/auth_middleware_test.dart`):
  - `valid token goes to home`: storage `token` = JWT with `exp` = now + 1 h → `AppRoutes.home`.
  - `no token goes to login and clears the session`: → `AppRoutes.login`; `AuthMiddleware.cachedToken == null`.
  - `expired token goes to login`: `exp` = now − 1 h → `AppRoutes.login`.
  - `storage error goes to login`: `storage.read` throws → `AppRoutes.login`.
- [ ] **Step 2:** Run `flutter test test/splash_destination_test.dart` → FAIL (file missing).
- [ ] **Step 3:** Implement with `AuthMiddleware.loadCredentials(storage: storage)` and `AuthMiddleware.isTokenValid`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit (`refactor(mobile): splash routing decision as a testable function`).

### Task 3: Animated SplashPage

**Files:**
- Modify (rewrite): `mobile/lib/pages/splash_page.dart`
- Test: `mobile/test/splash_page_test.dart`

**Interfaces:**
- Consumes: `resolveSplashDestination` (Task 2); `telyu_symbol.png`, circle `160`, symbol `96` (Task 1).
- Produces:
  - `typedef SplashNavigate = void Function(String route);`
  - `const SplashPage({Key? key, Future<String> Function() resolve = resolveSplashDestination, SplashNavigate navigate = splashNavigate})`
  - top-level `void splashNavigate(String route)`: `Get.offAllNamed(route)`; for `AppRoutes.home` also `NotificationNavigator.openPending()` in a post-frame callback.
  - `double splashSheetTop(BuildContext context, String route)`: y (from screen top) where the destination's white sheet starts on its first frame; values measured in Task 4 (start with `MediaQuery.paddingOf(context).top + 54` for login).
  - Keys for tests: `Key('splash-sheet')`, `Key('splash-progress')`.

Behaviour: first frame = red, white circle (160) with the symbol (96) at screen centre. Intro 700 ms easeOutCubic: circle scales to 0.8 and moves up 56 px; "MyTelU" (white, w800, 40) fades and slides up 16 px below it; "Telkom University" (white 70 %, 14) fixed near the bottom safe area. Check runs from `initState`. When intro done and route known: exit 450 ms easeInOutCubic (content fades out, `splash-sheet` with 30 px top radius rises from below the screen to `splashSheetTop`), then `navigate(route)` once. `splash-progress` (thin white `LinearProgressIndicator`) is shown only if the check is unresolved when the intro ends. Reduced motion: build the intro end state immediately, no sheet, `navigate` as soon as the route is known. No navigation after `dispose`.

- [ ] **Step 1: Write the failing tests** (`navigate` records calls into a list; `resolve` controlled by a `Completer<String>`):
  - `shows the mark and the MyTelU wordmark`: `find.text('MyTelU')` after `pump(700 ms)`.
  - `instant check: navigates once after intro and exit, without a fixed delay`: complete with login at t=0; at 1100 ms `calls == []` is allowed, by 1250 ms `calls == [AppRoutes.login]`.
  - `slow check shows the progress line and navigates once`: at 600 ms no `splash-progress`; at 800 ms `splash-progress` present; complete at 2000 ms with home; after +500 ms `calls == [AppRoutes.home]`.
  - `fast check never shows the progress line`: complete at 300 ms; pump in 50 ms steps to 1250 ms; `splash-progress` never found.
  - `exit raises the sheet`: during exit (complete at 0, pump 900 ms) `splash-sheet` found.
  - `reduced motion skips intro and sheet`: `MediaQuery(data: …copyWith(disableAnimations: true))`; complete at 0; by 300 ms `calls == [AppRoutes.login]`; `splash-sheet` never found.
  - `disposed splash never navigates`: replace the widget at 200 ms, complete, pump 2 s → `calls == []`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement (one `AnimationController` for intro, one for exit; `mounted` checks before navigating; a `_navigated` flag).
- [ ] **Step 4:** Run `flutter test test/splash_page_test.dart` → PASS; then the whole suite and `flutter analyze` (issue count must not rise above 169).
- [ ] **Step 5:** Commit (`feat(mobile): animated splash that hands over to the header`).

### Task 4: Fade into the destination and line up with the real pages

**Files:**
- Modify: `mobile/lib/app/routes.dart` (GetPages `login` and `home`: `transition: Transition.fadeIn`, `transitionDuration: Duration(milliseconds: 250)`)
- Modify: `mobile/lib/pages/splash_page.dart` (`splashSheetTop` values)

- [ ] **Step 1:** Install the build; take a screenshot of the first frame of Login, and of Beranda (logged in as `mhs_test` while the schedule loads, and as `admin_test`); read the y of each white sheet's top edge in logical px (divide by `adb shell wm density`/160).
- [ ] **Step 2:** Put the values in `splashSheetTop` (login; home by `AuthMiddleware.cachedRole`: ADMIN vs others).
- [ ] **Step 3:** Cold-start screen recordings (logged out, `mhs_test`, `admin_test`), frames at 10 fps: no white frame, no jump at the native → Flutter handoff, the sheet's edge lands within ~8 px of the destination's sheet, one cross-fade.
- [ ] **Step 4:** Whole test suite and analyzer as in Task 3.
- [ ] **Step 5:** Commit (`feat(mobile): splash exit lands on the destination header`).
