# Required Android Configuration

## Toolchain

- .NET 10 SDK (`10.0.100` baseline)
- .NET MAUI Android workload (`dotnet workload install maui-android`)
- Android SDK / command-line tools
- JDK compatible with the installed Android workload
- Git / GitHub Actions

CI is defined in `.github/workflows/android-ci-release.yml` and produces Release APK and AAB artifacts.

## Product settings

- Application ID: `com.johngraven75.spectragrab`
- Display title: `SpectraGrab`
- Version source: `ApplicationDisplayVersion` + `ApplicationVersion` in `SpectraGrab.Android.csproj`
- Windows reference repository: `johngraven75/SpectraGrab`
- iOS peer repository: `johngraven75/SpectraGrab-iOS`

## Required signing secrets for production publication

Configure repository/environment secrets; never commit them:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Store publication credentials separately as GitHub environment secrets for the selected distribution target. Unsigned CI build artifacts may be used for validation, but a production release is not considered published until signing/distribution succeeds.

The release workflow fails closed when any signing secret is missing, verifies that the certificate is not an Android Debug identity, compares the packaged APK signer with the configured keystore, and publishes only the explicitly selected `*-Signed.apk` and `*-Signed.aab` outputs. Never replace the production keystore after users install a production release; changing the key prevents in-place upgrades.

## Runtime release gate

Pushes to `main` and the release-candidate branch build production-signed packages and run the APK on an Android API 35 emulator. GitHub release publication on `main` occurs only after launch, direct/HLS download, Live Capture completion/stop, five add-in configuration, persistence, and same-key upgrade checks pass.

## Automation rule

Any failed build/package/parity gate must be diagnosed, repaired, and rerun. Do not remove a feature to obtain a green build.
