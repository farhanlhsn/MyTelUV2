# UI refinement following the original design

The user rejected the uncommitted 18 October redesign and requested restrained improvements to the existing MyTelUV2 interface. The reference is commit `4f9752c25`.

## Design retained

- `AppTheme` and its colors, typography, radii and component defaults are restored verbatim.
- Authentication retains the red header, rounded white panel, existing illustrations and original wording.
- Home retains the greeting pill, avatar, notification bell, class carousel, decorated class cards, curved service area, icon grid and existing navigation appearance.
- Profile, account, settings and notifications retain their original page structures.
- The new authentication shell, replacement navigation component, redesign-specific tests and outdated preview images/report were removed. The rejected staged changes were saved in a local temporary patch before replacement.

## Small usability changes

- Reserve space below content for the original navigation and the device safe area.
- Improve touch targets and accessible labels without changing the existing icons.
- Support autofill and keyboard submission; guard duplicate submissions and navigation after disposal.
- Keep errors, profile content and notification preferences scrollable; let supporting text wrap.
- Distinguish an unavailable schedule from an empty day, and offer retry.
- Preserve the account form while marking unsupported email/phone edits read-only; remove the inactive camera affordance.
- Prevent repeated logout dialogs and cancel the registration redirect timer when leaving.

## Checks

- Source comparison confirms `AppTheme` and `KelasHariIniCard` are identical to the original reference; existing test files are unchanged.
- Independent source review found no remaining actionable issues, including the short-screen scrolling fallback.
- Final static analysis of `lib`: exit 0, zero errors, zero warnings, 169 informational notices. `git diff --check` passed.
- The initial refinement was checked by source/static analysis only. A subsequent user-requested emulator session exercised the screens before login, applied two small authentication corrections, and built/installed a local debug APK; see [runtime review](2026-10-20-mobile-runtime-review.md). No automated tests were run. The previous redesign's test results do not validate the corrected interface.

No backend, service, controller, route, dependency or secret changes. Existing untracked files were preserved. Changes remain local and uncommitted, with no push or merge.
