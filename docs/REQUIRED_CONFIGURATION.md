# Required Android Configuration

## Toolchain

- .NET 8 SDK
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

## Automation rule

Any failed build/package/parity gate must be diagnosed, repaired, and rerun. Do not remove a feature to obtain a green build.
