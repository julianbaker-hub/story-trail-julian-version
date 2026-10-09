# StoryTrail TestFlight release workflow

Read this reference when preparing or publishing a TestFlight build. Adapt command details to the installed Xcode version; the local `xcodebuild -help` and `xcrun altool --help` output is the source of truth.

## Preflight

From the repository root:

```sh
xcodebuild -version
xcodebuild -list -project StoryTrail.xcodeproj
xcodebuild -showBuildSettings \
  -project StoryTrail.xcodeproj \
  -scheme StoryTrail \
  -configuration Release \
  -destination 'generic/platform=iOS'
```

From the effective application-target settings, record `PRODUCT_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM`, `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `CODE_SIGN_STYLE`, and the Release signing identity. Confirm `StoryTrail/Info.plist` still declares the expected encryption answer.

Use `xcodebuild -showdestinations -project StoryTrail.xcodeproj -scheme StoryTrail` to select an installed iPhone simulator, boot one if necessary, and run the `StoryTrailTests` test plan/scheme action. Do not hard-code a simulator model that is not installed.

If Git metadata exists, inspect `git status --short --branch` and summarize relevant changes. A dirty tree is not an automatic blocker: the archive must reflect the exact working tree the user requested.

## Authentication and signing

Preferred authentication is an App Store Connect API key with:

- issuer ID;
- key ID;
- a readable local `AuthKey_<key-id>.p8` file kept outside the repository.

Pass those to `xcodebuild` using the locally documented `-authenticationKeyPath`, `-authenticationKeyID`, and `-authenticationKeyIssuerID` options. Do not expose private-key contents or embed credentials in an export plist.

If the Mac already has the correct Apple developer account and signing certificate configured in Xcode, `-allowProvisioningUpdates` may use that account. Do not enumerate or print unrelated keychain data. If neither route is available, stop and tell the user exactly which credential setup is missing.

## Archive

Create a unique work directory with `mktemp -d /tmp/storytrail-testflight.XXXXXX`. Put the archive, export plist, logs, and any exported IPA there. Run a fresh archive, conceptually:

```sh
xcodebuild archive \
  -project StoryTrail.xcodeproj \
  -scheme StoryTrail \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath '<work-dir>/StoryTrail.xcarchive' \
  -derivedDataPath '<work-dir>/DerivedData' \
  -allowProvisioningUpdates
```

Add the three API-key authentication options when using API-key authentication. Use `-hideShellScriptEnvironment` where supported. Do not place secrets in filenames or shell history.

Inspect the archive’s application metadata before upload. Confirm the archived bundle ID, short version, build version, signing team, and entitlements. A successful simulator build is not evidence that distribution signing works.

## Upload

Generate the temporary export-options plist outside the repository with at least these values, while honoring any changed requirements reported by `xcodebuild -help`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>9JY5CE8B5H</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><true/>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
```

Upload with `xcodebuild -exportArchive`, the archive path, and this plist. Pass API-key authentication options when applicable. The command performs the external mutation; execute it only for an explicitly authorized publish/upload request.

Xcode’s managed build-number option defaults to enabled in the currently installed toolchain, but keep it explicit and inspect the upload response for the assigned build number. Do not edit `CURRENT_PROJECT_VERSION` merely to make the upload unique unless the user asks for persistent version changes.

If a separately exported IPA is useful for diagnosis, export with `destination=export`. `xcrun altool --validate-app` and `--upload-app` are fallbacks when supported by the installed toolchain, but prefer the Xcode export/upload path because it can manage the build number. Never upload the same archive through both paths.

## Completion criteria

An upload command succeeding means Apple accepted the delivery. It may still be processing and therefore not yet selectable by testers. Report one of these precise states:

- archive/test failed — nothing uploaded;
- upload failed or rejected — nothing accepted;
- upload outcome uncertain — verify before any retry;
- upload accepted — processing status unknown or pending;
- processed in App Store Connect — available for the next authorized tester/group action.

Do not claim testers received the build unless the relevant TestFlight group assignment and processing state were actually verified.
