# Splash screen: one red splash with a short animation

Date: 2026-11-25 · Size: small change (short design)

## Why

Opening the app today shows two different splashes and then cuts hard to the next page:

1. Android 12+ draws its system splash first: white, with the launcher icon, which is cropped
   ("Telkom Universi…") because the adaptive icon foreground fills its whole canvas.
2. The Flutter `SplashPage` then appears in red, with the Telkom University logo in dark grey on
   red (hard to read), a spinner, and a fixed 1 second wait. The app name MyTelU is not shown.
3. Login or Beranda replaces it without a transition.

The team wants the opening to feel like one polished moment in the app's red identity, with a
short animation that leads into the app (option B, chosen over A and C below).

## Goals

- One continuous red splash from the moment the app is tapped: no white flash between the system
  splash and the Flutter splash.
- MyTelU is named on the splash; the Telkom University logo is readable.
- A short intro animation, then an exit that turns the red splash into the red header of the
  next page (Login or Beranda).
- The launcher icon is no longer cropped.

## Non-goals

- iOS launch screen (cannot be built or checked here; left as is).
- New packages (Lottie, flutter_native_splash, flutter_launcher_icons): resources are written by
  hand.
- A dark-mode variant: the splash is red in both modes.

## Anti-goals

- A splash that lasts longer than today's. The animation runs while the login check runs; it
  never adds a fixed wait.
- An animation that keeps playing after the destination is known and the intro is done.
- Breaking the cold start from a notification (`NotificationNavigator.openPending`).

## Approaches

- **A. One red splash, no animation.** Native splash red, Flutter splash matches it, fade to the
  next page. Least work, fixes the flash and the contrast.
- **B. A plus a short intro and a "becomes the header" exit. Chosen.** Same fixes as A, and the
  opening feels designed rather than a loading screen.
- **C. White splash.** Matches Android's default and shows the full-colour logo best, but breaks
  with the red headers everywhere else in the app.

## Design

**Launch (native, Android).**
- Android 12+ (`values-v31/styles.xml`, also `values-night-v31`): `LaunchTheme` gets
  `windowSplashScreenBackground` = `#E63946`, `windowSplashScreenIconBackgroundColor` = white,
  and `windowSplashScreenAnimatedIcon` = the Telkom University symbol (red book over the grey U,
  without the "Telkom University" text, which is unreadable at icon size), sized for the splash
  icon safe area.
- Older Android (`drawable/launch_background.xml`, `drawable-v21`): red background with the same
  white circle and symbol, centred, as a bitmap.
- Launcher icon: the adaptive foreground is regenerated with the symbol inside the safe zone
  (the visible circle); legacy `mipmap-*` icons regenerated to match. Background stays white.

**Flutter `SplashPage`.**
- First frame equals the native splash: red background, white circle with the symbol, same size
  and position, so the handoff is invisible.
- Intro (about 700 ms, ease-out): the circle shrinks a little and moves up; the white "MyTelU"
  wordmark fades in and slides up below it; a small "Telkom University" line sits near the bottom.
- The login check starts in `initState`, in parallel with the intro. No fixed delay. If the check
  is still running when the intro ends, a thin white indeterminate line appears under the
  wordmark; it is never shown for a check that finishes during the intro.
- Exit (about 450 ms) once the intro is done and the destination is known: the splash content
  fades out while a white sheet with the app's 30 px rounded top rises from the bottom to where
  the destination's white sheet starts on its first frame (Login, and Beranda while its schedule
  is loading). Then the destination appears with a short cross-fade, so the red that stays on top
  reads as the page's header.
- Reduced motion (`MediaQuery.disableAnimations`): no intro or sheet; the splash shows its end
  state and fades to the destination.
- Behaviour kept: valid token goes to Beranda and then opens a pending notification; anything
  else clears credentials and the pending notification and goes to Login.

## Left to the builder

- Exact sizes of the splash icon and circle per density, measured so the native and Flutter first
  frames line up on the emulator.
- The exact sheet target for each destination, measured from Login's and Beranda's first frame.
- Curves and the precise timings within the ranges above.

## Checks

- Widget tests: no token goes to Login, a valid token goes to Beranda, neither waits for a fixed
  delay, reduced motion skips the animation.
- On the emulator: a screen recording of a cold start (logged out and logged in) shows no white
  frame, no jump at the native-to-Flutter handoff, and the exit landing on the header.
