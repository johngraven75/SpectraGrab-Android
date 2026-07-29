# Repository Agent / Automation Operating Rules

All automated or AI-assisted repository work must follow `REPO_RULES.md` and `docs/CROSS_PLATFORM_SYNC.md`.

## Required execution loop

1. Inspect the current repository state and existing workflows before changing code.
2. Preserve accepted functionality; do not remove features to make CI pass.
3. Implement the smallest maintainable correction that addresses root cause.
4. Run/trigger clean validation after each meaningful change.
5. If validation fails, inspect the actual failing step/log, repair it, and rerun.
6. Do not report green until the current commit has current green evidence.
7. Produce and retain release artifacts when packaging is part of the task.
8. Keep Android parity with Windows and iOS tracked explicitly.

## Android toolchain baseline

- Git / GitHub Actions
- JDK 17 or later as required by the selected Android Gradle Plugin
- Android SDK / command-line tools
- Gradle wrapper committed to the repository
- Android build-tools and platform matching compileSdk
- lint + unit tests + Release assemble/bundle
- APK and AAB artifact retention
- signing only through GitHub Secrets or secure environment variables; never commit signing secrets

## Downloader/media baseline

Use supported platform APIs/libraries for HTTP, HLS/DASH, background transfers, persistent queue state, and user-authorized session handling. Do not implement DRM or access-control circumvention.
