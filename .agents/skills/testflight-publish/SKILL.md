---
name: testflight-publish
description: Prepare, archive, validate, and publish the StoryTrail iOS app to TestFlight from this repository. Use for TestFlight readiness checks or an explicitly requested upload; do not use for App Store production submission.
---

# Publish StoryTrail to TestFlight

Operate from this project’s root. This skill is specific to the native iOS app in this project.

## Authorization boundary

- Treat an explicit request to “publish,” “upload,” or “send this build to TestFlight” as authorization to create/update signing assets as needed and upload one build to App Store Connect.
- A request to check, prepare, validate, or explain is read-only with respect to Apple services. Stop before provisioning changes or upload.
- Uploading a build does not authorize adding testers, changing groups, submitting Beta App Review, releasing to the App Store, committing, tagging, or pushing source changes.
- Never retry an upload whose result is uncertain. First determine whether App Store Connect accepted the delivery.

## Project facts

- Xcode project: `StoryTrail.xcodeproj`
- Scheme and application target: `StoryTrail`
- Expected bundle ID: `com.storytrailguide.app`
- Expected Apple team: `9JY5CE8B5H`
- Deployment target: iOS 17+
- `project.yml` is the XcodeGen specification, but the checked-in Xcode project can contain newer settings. Inspect both. Do not regenerate the project or reconcile their differences unless the user asks.
- `ITSAppUsesNonExemptEncryption` is currently `false` in `StoryTrail/Info.plist`; verify it has not changed.

Do not trust these facts blindly. Confirm the effective Release build settings before archiving and stop if the bundle ID or team differs unexpectedly.

## Workflow

1. Establish whether the request is readiness-only or an authorized upload.
2. Read [references/release-workflow.md](references/release-workflow.md) and follow its current-toolchain checks.
3. Inspect repository state without discarding or overwriting user changes. If Git is unavailable, say so and continue with file-level checks.
4. Run the proportional preflight: list the scheme, inspect effective Release settings, run the unit tests on an available iOS simulator, and confirm the archive destination.
5. Confirm signing/authentication without displaying secrets. Prefer an App Store Connect API key; an Xcode account already configured on the Mac is acceptable. Never print a `.p8` file, password, keychain secret, or the full environment.
6. Build a fresh Release archive in a unique temporary directory outside the repository. Do not reuse `DerivedData` or a prior archive.
7. For readiness-only work, report results and stop here. Validation that contacts Apple or creates provisioning state requires the same authorization boundary as an upload.
8. For an authorized publish request, upload exactly once using Xcode’s `app-store-connect` export method with `destination=upload` and `manageAppVersionAndBuildNumber=true`. This lets Xcode choose a valid build number without editing source files.
9. Capture the delivery result. Distinguish “upload accepted” from “processed and available in TestFlight.” If processing status cannot be verified with the available authenticated tooling, state that clearly rather than claiming publication is complete.
10. Report the marketing version, uploaded build number if returned, bundle ID, archive path, validation/test outcome, and any remaining App Store Connect action.

## Failure handling

- Diagnose build, signing, entitlement, version, export-compliance, or upload errors from the actual command output.
- Fix repository code/config only when it is plainly within the user’s publish request and low risk. Explain any source change and retest.
- Stop for missing Apple agreements, insufficient App Store Connect roles, an unknown app record, a bundle/team mismatch, or credentials that require the user to log in or provide access.
- Do not weaken signing, disable tests, suppress validation failures, or switch bundle identifiers to force an upload.
