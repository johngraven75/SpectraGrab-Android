# SpectraGrab Android

Android companion repository for the SpectraGrab product family.

The Android app includes app-scoped direct/HLS live capture with progress and safe stop/finalization. It also ships verified defaults for five providers and the Emby, Jellyfin, Plex, Local AI, and QuickConnect add-ins. Writable JSON copies live in the app data directory, are upgraded by merging missing fields, and survive APK/AAB upgrades. Credentials remain in Android Secure Storage and are referenced by key name rather than written into JSON.

## Product relationship

- Windows reference: `johngraven75/SpectraGrab`
- Android: this repository
- iOS peer: `johngraven75/SpectraGrab-iOS`
- Windows defines accepted product features. Android must preserve feature parity unless a platform API makes a feature impossible; any exception must be documented and explicitly approved.

## Release contract

A release is not green until:

1. restore/build succeeds from a clean checkout;
2. regression/parity checks pass;
3. the release APK and AAB are produced;
4. artifacts are retained by CI;
5. runtime/UI-critical paths are verified;
6. settings/state migrations are validated;
7. matching Windows and iOS release/parity gates are satisfied or a hard external blocker is documented.

Any build/workflow failure must be repaired and rerun. Do not accept regressions or silently remove, hide, or disable existing features.

See `REPO_RULES.md` and `docs/CROSS_PLATFORM_SYNC.md` for binding repository policy.
