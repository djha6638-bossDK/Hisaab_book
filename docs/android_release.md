# Android release checklist

The release build reads signing values from `android/key.properties`. Keep that
file and the referenced keystore outside version control.

Required keys:

```properties
storeFile=C:\\secure\\hisaab-book-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Before publishing:

1. Register `com.hisaabbook.hisaab_book` in Firebase.
2. Add debug and release SHA-1/SHA-256 fingerprints.
3. Download the resulting `google-services.json`.
4. Enable Google Sign-In in Firebase Authentication.
5. Deploy `firestore.rules`.
6. Run `flutter build apk --release` and test login, Firestore, PDF preview,
   printing, sharing, and download on a physical Android device.

Without signing credentials Gradle can still compile an unsigned release
artifact for verification. It never falls back to the debug signing key.

## Publishing an update (GitHub Releases)

The app checks `djha6638-bossDK/Hisaab_book` public releases for updates. Only
release builds published through `scripts/release.ps1` are visible to installed
apps, so normal development builds never leak to users.

```powershell
# Patch bump + next build number (1.1.0+2 -> 1.1.1+3)
.\scripts\release.ps1

# Explicit version and release notes
.\scripts\release.ps1 -Version 1.2.0 -Notes "Naya feature aur bug fixes."
```

The script:

1. Runs `flutter analyze` and `flutter test`.
2. Builds the universal release APK.
3. Copies `hisaab-book-<version>+<build>.apk` and its `.sha256` checksum.
4. Commits the `pubspec.yaml` version bump and pushes tag `v<version>+<build>`.
5. Creates a public GitHub Release with the APK, checksum, and notes.

Keep `versionCode` (the `+N` part) strictly increasing. Android installs an
update only when it is signed with the same key as the installed app and the
new `versionCode` is higher.

The first build that includes the in-app updater has to be installed manually;
later releases can be installed from the update card.
