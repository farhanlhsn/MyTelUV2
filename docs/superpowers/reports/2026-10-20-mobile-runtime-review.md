# Mobile runtime review — 20 October 2026

The user asked to run the revised application and explicitly chose inspection of screens before login. The application was built and launched on the existing Pixel 10 Pro XL emulator (`emulator-5554`, Android API 37, x86_64). The user handled Android's notification permission dialog directly.

## Observed in the running app

| Screen / interaction | Observation |
| --- | --- |
| Login | Original red header, white curved panel and illustration are present. Empty submission shows both required-field errors. |
| Login keyboard | Next moves focus from username to password; Done dismisses the keyboard and shows validation. A whitespace-only username is rejected inline after the fix. |
| Registration | Form scrolls to the registration action. Empty submission shows name, username, password, confirmation and terms errors. No account was created. |
| Terms | Dialog opens from the form, its text and close action are visible, and closing returns to the form. |
| Forgot password | Blank submission shows the required-field error. The existing token link opens reset password. No reset request was sent. |
| Reset password | Empty submission shows all three required-field errors. With confirmation focused and the keyboard open, the submit action remains reachable. Back returns to recovery, then login. No password was changed. |

No Flutter exception or RenderFlex overflow was found in the inspected runtime log for these paths. This is one emulator at its default text size, not a physical-device or performance assessment. Enlarged text and authenticated screens were not exercised in this session.

## Small corrections made during review

- Explicit white AppBar title text on recovery/reset: the inherited global title style was visibly dark against the red header. Existing font metrics and layout remain intact.
- Trim whitespace in the login username validator, preventing a silent rejection by the controller.
- Hot reload applied the three changed files successfully. Focused static analysis of authentication sources finished with zero errors, zero warnings and two existing deprecation notices.
- The final local debug APK was rebuilt successfully in 55 seconds and reinstalled. The Flutter debugger was detached, and the updated app was launched directly again so the corrections survive reopening.

## Local build setup and limits

- The existing AVD referenced an old SDK skin path. It was launched with the current SDK skin directory, cold boot and software GPU. No AVD data was wiped or configuration file changed.
- Gradle's Java loopback failure was resolved with process-local JDK 17 and `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\Windows\Temp`.
- The available ignored Firebase configuration and Kotlin activity use `com.example.mobile`, while the checked-in Android namespace/application ID are `com.mytelu.mobile`. An ignored Gradle init script overrides namespace/application ID only for this local debug inspection. Android source and Firebase credentials were not edited. The normal production identity/build remains unverified and needs matching configuration and activity package resolution.
- Builds and Flutter execution use the established C: NTFS mirror. UI source hashes were compared with the repository before the build.
- No local backend environment/database was configured. No authenticated service flow, account creation, reset request or password change was performed. No automated tests were added or run.

Build/analysis diagnostics and the local-only init script are in `.superpowers/ui-ux-2026-10-18/`. Changes remain local and uncommitted.
